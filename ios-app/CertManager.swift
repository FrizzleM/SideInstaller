import Foundation
import SideInstallerFFI

/// One iOS development certificate, decoded from `si_cert_list`'s JSON, where
/// Apple's optionals arrive flattened to "".
struct DevCert: Identifiable, Decodable, Equatable {
    let name: String
    let serialNumber: String
    let machineName: String
    let machineId: String
    let certificateId: String
    let platform: String
    let status: String
    /// RFC3339 expiry (e.g. `2027-01-01T00:00:00Z`), or "" if Apple omitted it.
    let expiration: String

    enum CodingKeys: String, CodingKey {
        case name
        case serialNumber = "serial_number"
        case machineName = "machine_name"
        case machineId = "machine_id"
        case certificateId = "certificate_id"
        case platform
        case status
        case expiration
    }

    /// Stable identity: the serial revocation keys on, or the certificate id.
    var id: String { serialNumber.isEmpty ? certificateId : serialNumber }

    var displayName: String { name.isEmpty ? L("Unnamed certificate") : name }

    /// The machine Apple tagged the certificate with, if any.
    var machineLabel: String? {
        machineName.isEmpty ? nil : machineName
    }

    /// `expiration` parsed to a `Date`, if present and well-formed.
    var expiresAt: Date? {
        guard !expiration.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: expiration)
            ?? ISO8601DateFormatter().date(from: expiration)
    }

    /// True once the expiry date is in the past.
    var isExpired: Bool {
        guard let date = expiresAt else { return false }
        return date < Date()
    }
}

/// What `si_cert_import` reports: the team's certificate SideInstaller now signs
/// with, and whether that took a new key.
private struct CertImportResult: Decodable {
    let certificate: DevCert
    let replacedKey: Bool

    enum CodingKeys: String, CodingKey {
        case certificate
        case replacedKey = "replaced_key"
    }
}

/// Lists and revokes the Apple ID's development certificates, using the engine's
/// credentials and 2FA prompt. Developer-portal only (no device); blocking FFI
/// calls run on a background queue.
final class CertManager: ObservableObject {

    @Published private(set) var certs: [DevCert] = []
    @Published private(set) var isSignedIn = false
    @Published private(set) var teamSummary: String?
    /// Sign-in or list in progress.
    @Published private(set) var isWorking = false
    /// `id` of the certificate currently being revoked, if any.
    @Published private(set) var revokingID: String?
    @Published var lastError: String?
    /// What the last certificate import did.
    @Published var lastSuccess: String?
    /// True once a list has been fetched (tells "not loaded" apart from "empty").
    @Published private(set) var hasLoaded = false
    /// True while a certificate SideStore sent is checked and put in place.
    @Published private(set) var isImporting = false

    /// Busy with any certificate work (guard for the SideStore-certificate
    /// request). Fork has no per-cert export, so unlike upstream's version
    /// this does not OR in an exportingID.
    var isBusy: Bool { isWorking || isImporting || revokingID != nil }

    private var session: OpaquePointer?            // CertSession*
    /// A2：登录代际号——signOut 递增；signIn 完成后核对，未变才写会话。
    private var signInGeneration = 0
    private let queue = DispatchQueue(label: "sideinstaller.certs")

    private var engine: Engine { Engine.shared }

    /// Limits `autoLoad` to one attempt, so a failed sign-in or dismissed 2FA
    /// prompt doesn't come back every time the page opens.
    private var didAutoLoad = false

    deinit {
        if let session { si_cert_session_free(session) }
    }

    // MARK: - Popups

    /// What went wrong last, as a popup `RootView` stacks over the app.
    var popups: [ToolPopup] { lastError.map { [.error($0)] } ?? [] }

    func closePopup(_ popup: ToolPopup) { lastError = nil }

    // MARK: - Public actions

    /// Loads certificates when the page opens. Does nothing if no Apple ID is
    /// saved.
    @MainActor
    func autoLoad() {
        guard !didAutoLoad, !hasLoaded, !isWorking, revokingID == nil else { return }
        guard !engine.normalizedAppleID.isEmpty, !engine.applePassword.isEmpty else { return }
        didAutoLoad = true
        loadCerts()
    }

    /// Sign in if needed and reload the list; `then` runs only if it arrived.
    @MainActor
    func loadCerts(then: (() -> Void)? = nil) {
        guard !isWorking, revokingID == nil else { return }
        let id = engine.normalizedAppleID, pw = engine.applePassword
        guard !id.isEmpty, !pw.isEmpty else {
            lastError = L("No Apple ID saved. Add one in Settings › Account.")
            return
        }
        isWorking = true
        lastError = nil
        engine.log("=== Certificates: loading ===")
        Task { @MainActor in
            do {
                if session == nil { try await signIn(id: id, pw: pw) }
                let list = try await onQueue { try self.performList() }
                certs = list
                hasLoaded = true
                engine.log("Certificates: \(list.count) iOS development certificate(s).")
                isWorking = false
                then?()
                return
            } catch is CancellationError {
                // Not currently cancellable; handled for consistency with Engine.
                // C10：取消也跑 then——等回调的是用户已点过的动作
                // （吊销 chooser），不跑界面就永远没反应；先把
                // isWorking 复位，再跑 then，顺序与成功路一致。
                engine.log("Certificates: load cancelled.")
                isWorking = false
                then?()
                return
            } catch {
                lastError = short(error)
                engine.log("⛔️ Certificates: \(lastError ?? "failed")")
            }
            isWorking = false
        }
    }

    /// Revokes a certificate and refreshes the list. `onSuccess` (e.g. retrying
    /// the install) runs only if Apple accepted the revocation.
    @MainActor
    func revoke(_ cert: DevCert, onSuccess: (() -> Void)? = nil) {
        guard session != nil, revokingID == nil, !isWorking else { return }
        let serial = cert.serialNumber
        guard !serial.isEmpty else {
            lastError = L("This certificate has no serial number, so it can't be revoked.")
            return
        }
        revokingID = cert.id
        lastError = nil
        engine.log("Certificates: revoking \(cert.displayName) (\(serial)) …")
        Task { @MainActor in
            var revoked = false
            do {
                try await onQueue { try self.performRevoke(serial: serial) }
                revoked = true
                engine.log("Certificates: revoked \(cert.displayName).")
                do {
                    let list = try await onQueue { try self.performList() }
                    certs = list
                } catch {
                    // C9：吊销成功了，只是列表没刷出来——先把这张从
                    // 列表里拿掉，别让用户再点一次吊销；再告诉他
                    // 列表可能还是旧的，重新加载会刷新。
                    certs.removeAll { $0.id == cert.id }
                    lastError = L("Revoked, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.")
                    engine.log("⛔️ Certificates: revoked \(cert.displayName), but the list refresh failed: \(short(error))")
                }
            } catch {
                lastError = short(error)
                engine.log("⛔️ Revoke failed: \(lastError ?? "")")
            }
            revokingID = nil
            // Run `onSuccess` if the revoke succeeded, even if the refresh failed.
            if revoked { onSuccess?() }
        }
    }

    // MARK: - SideStore's certificate

    /// True when there's a SideStore certificate to ask for (see
    /// `Engine.canUseSideStoreCertificate`).
    var canUseSideStoreCertificate: Bool { engine.canUseSideStoreCertificate }

    /// Asks SideStore for its certificate. SideStore asks whether to export it,
    /// then opens a `sideinstaller://certificate` link, which `RootView` hands
    /// to `importCertificate`. Inside LiveContainer, where that link can't come
    /// back, the certificate LiveContainer holds is imported instead.
    /// `retryInstall` runs the install again after.
    @MainActor
    func requestSideStoreCertificate(retryInstall: Bool) {
        guard !isBusy else { return }
        lastError = nil
        lastSuccess = nil
        if Engine.runsInLiveContainer {
            importFromLiveContainer(retryInstall: retryInstall)
            return
        }
        engine.requestSideStoreCertificate(retryInstall: retryInstall) { [weak self] in
            self?.lastError = ErrorHelp.explained(L("SideStore isn't installed on this iPhone, so there's no certificate to get from it."))
            self?.engine.log("⛔️ Certificates: \(self?.lastError ?? "")")
        }
    }

    /// Imports SideStore's certificate from where LiveContainer keeps it
    /// (issue #95, see `LiveContainerCertificate`).
    @MainActor
    private func importFromLiveContainer(retryInstall: Bool) {
        engine.log("Certificates: inside LiveContainer, SideStore can't send its certificate back, so SideInstaller reads the one LiveContainer holds.")
        let found = LiveContainerCertificate.find { engine.log($0) }
        guard !found.isEmpty else {
            lastError = ErrorHelp.explained(L("Inside LiveContainer, SideStore can't send its certificate back to SideInstaller, and LiveContainer doesn't hold one yet. In LiveContainer's Settings, tap “Import Certificate From SideStore” (sign in to SideStore first if it has no certificate), then try again here."))
            engine.log("⛔️ Certificates: \(lastError ?? "")")
            return
        }
        runImport(found.map { ImportCandidate(certificate: $0.certificate, source: $0.source) },
                  title: "the certificate LiveContainer holds for SideStore",
                  retryInstall: retryInstall,
                  notOnTeam: L("The certificate LiveContainer holds for SideStore isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID. Nothing was changed. If SideStore has made a new one since, tap “Refresh Certificate from SideStore” in LiveContainer's Settings, then try again here."))
    }

    /// Signs with the certificate a link brought from now on, once the Apple
    /// ID's own certificates include it: its key becomes the one isideload
    /// signs with, so SideInstaller stops asking Apple for a certificate of its
    /// own (error 7460 on a free account) and revoking SideStore's.
    @MainActor
    func importCertificate(_ request: CertificateImport) {
        let cert = request.certificate
        let source = cert.fromSideStore ? "SideStore's certificate" : "the certificate from the link"
        runImport([ImportCandidate(certificate: cert, source: source)], title: source,
                  retryInstall: request.retryInstall,
                  notOnTeam: L("That certificate isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID (SideStore may be signed in with a different one). Nothing was changed."))
    }

    /// A certificate to check, and where it came from, for the log.
    private struct ImportCandidate {
        let certificate: LinkedCertificate
        let source: String
    }

    /// Signs with the first of `candidates` that the Apple ID's own
    /// certificates include. `notOnTeam` is the error when none is.
    @MainActor
    private func runImport(_ candidates: [ImportCandidate], title: String,
                           retryInstall: Bool, notOnTeam: String) {
        guard !isImporting, !candidates.isEmpty else { return }
        let id = engine.normalizedAppleID, pw = engine.applePassword
        guard !id.isEmpty, !pw.isEmpty else {
            lastError = ErrorHelp.explained(L("No Apple ID saved. Add one in Settings › Account."))
            return
        }
        isImporting = true
        lastError = nil
        lastSuccess = nil
        engine.log("=== Certificates: checking \(title) ===")
        Task { @MainActor in
            defer { isImporting = false }
            do {
                if session == nil { try await signIn(id: id, pw: pw) }
                let result = try await importFirstOnTeam(candidates)
                let name = result.certificate.machineLabel ?? result.certificate.displayName
                engine.log(result.replacedKey
                    ? "Certificates: signing with \(name) (\(result.certificate.serialNumber)) from now on; nothing was revoked."
                    : "Certificates: \(name) is the certificate SideInstaller signs with already.")
                do {
                    let list = try await onQueue { try self.performList() }
                    certs = list
                    hasLoaded = true
                } catch {
                    // C17：导入成功了，只是列表没刷出来——告诉他
                    // 列表可能还是旧的，重新加载会刷新。
                    lastError = L("Imported, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.")
                    engine.log("⛔️ Certificates: imported \(name), but the list refresh failed: \(short(error))")
                }
                if retryInstall {
                    engine.log("Retrying the install with \(name).")
                    engine.runOneClick()
                } else {
                    lastSuccess = result.replacedKey
                        ? L("SideInstaller signs with “%@” from now on. Nothing was revoked, so the apps already signed with it keep working.", name)
                        : L("SideInstaller already signs with “%@”.", name)
                }
            } catch is CancellationError {
                // A2：切账号后本次导入作废，不记错（isImporting 由外层 defer 复位）。
                engine.log("Certificates: import cancelled (account changed).")
            } catch {
                lastError = error is ImportNotOnTeam ? notOnTeam : short(error)
                engine.log("⛔️ Certificates: \(lastError ?? "import failed")")
            }
        }
    }

    /// Imports the first of `candidates` that is one of the Apple ID's
    /// certificates. One that isn't is passed over while others are left; any
    /// other failure stops.
    @MainActor
    private func importFirstOnTeam(_ candidates: [ImportCandidate]) async throws -> CertImportResult {
        for (index, candidate) in candidates.enumerated() {
            if candidates.count > 1 { engine.log("Certificates: trying \(candidate.source) …") }
            do {
                return try await onQueue {
                    try self.performImport(p12: candidate.certificate.data,
                                           password: candidate.certificate.password)
                }
            } catch is ImportNotOnTeam where index < candidates.count - 1 {
                engine.log("Certificates: \(candidate.source) isn't one of this Apple ID's.")
            }
        }
        throw ImportNotOnTeam()
    }

    /// Loads the list if needed, then runs `then`. Used by the Install screen's
    /// revoke chooser.
    @MainActor
    func ensureLoaded(then: @escaping () -> Void) {
        guard !isWorking, revokingID == nil else { return }
        if hasLoaded, session != nil {
            then()
            return
        }
        loadCerts(then: then)
    }

    /// Frees the session and clears the list (e.g. when the Apple ID changes).
    /// No-op if not signed in.
    @MainActor
    func signOut() {
        // A2：世代递增放 guard 之前——登录在途时 session 还是 nil，早退会漏递增。
        signInGeneration += 1
        guard let session else { return }
        // C18：释放排进证书队列（与在途的 FFI 调用串行），不在主线程直接
        // 释放；抓调用时那一个指针，块内不再重读当前 session（C19 的教训）。
        let freed = session
        queue.async { si_cert_session_free(freed) }
        self.session = nil
        isSignedIn = false
        teamSummary = nil
        certs = []
        hasLoaded = false
        didAutoLoad = false
        lastError = nil
        engine.log("Certificates: signed out.")
    }

    // MARK: - Sign-in

    @MainActor
    private func signIn(id: String, pw: String) async throws {
        // One Apple ID sign-in at a time (`AppleSignInQueue`).
        // A2：排队等待期间切账号同样作废本次尝试，世代在等位前抓。
        let generation = signInGeneration
        let ticket = try await engine.appleSignIns.waitForTurn(.certificates, appleID: id)
        defer { engine.appleSignIns.finished(ticket) }
        // A load and an import can both have been waiting; the first signed in.
        if session != nil { return }

        // Try each anisette server (only the one picked in Settings with Auto
        // off); a credential or 2FA error stops the loop.
        let servers = anisetteCandidates()
        let dir = storageDir
        var lastError = "no anisette servers configured"
        var appleRefusals = AnisetteServer.AppleRefusals(servers: engine.anisetteServers)
        var appleUnreachable = 0

        for (idx, ani) in servers.enumerated() {
            // A3：循环头查世代——切账号后不再拿旧 id/pw 试下一台服务器。
            guard generation == signInGeneration else { throw CancellationError() }
            if appleRefusals.rulesOut(ani) {
                engine.log("Certificates: skipping anisette \(idx + 1)/\(servers.count): Apple has refused the device sign-in reports through it.")
                continue
            }
            do {
                let summary = try await onQueue {
                    try self.performSignIn(id: id, pw: pw, ani: ani, dir: dir, ticket: ticket)
                }
                // A2：切账号后完成的旧登录作废——刚登好的会话在队列上放掉再报取消。
                guard generation == signInGeneration else {
                    if let stale = self.session {
                        self.session = nil
                        queue.async { si_cert_session_free(stale) }
                    }
                    throw CancellationError()
                }
                engine.anisetteURL = ani               // stick with what worked
                teamSummary = summary
                isSignedIn = true
                engine.log("Certificates: signed in (\(summary)).")
                return
            } catch let error as EngineError {
                // A3：旧登录在 2FA 取消等失败时也不写新账号的 lastError。
                if generation != signInGeneration { throw CancellationError() }
                lastError = error.errorDescription ?? "sign-in failed"
                if ticket.twoFactorWasCancelled {
                    engine.log("Two-factor verification cancelled — stopping.")
                    throw EngineError.message(L("Two-factor verification was cancelled."))
                }
                if Engine.isAccountLocked(lastError) {
                    engine.log("Apple has locked this Apple Account: \(lastError)")
                    throw EngineError.accountLocked
                }
                if Engine.isEmailUnverifiedError(lastError) {
                    engine.log("Apple wants this Apple Account's email address verified first: \(lastError)")
                    throw EngineError.emailUnverified
                }
                if Engine.isCredentialError(lastError) {
                    engine.log("Apple ID credentials rejected: \(lastError)")
                    throw EngineError.message(Engine.credentialErrorMessage)
                }
                engine.log("Certificates: anisette \(idx + 1)/\(servers.count) failed: \(lastError)")
                if Engine.isAppleRateLimit(lastError) {
                    engine.log("Certificates: Apple is rate-limiting sign-in (HTTP 429) — stopping.")
                    throw EngineError.message(Engine.appleRateLimitMessage)
                }
                // Apple refuses a reported device through every server alike;
                // see `AnisetteServer.AppleRefusals`.
                if Engine.isAppleServiceRefusal(lastError) {
                    appleRefusals.record(ani)
                    if appleRefusals.endsSignIn(remaining: servers[(idx + 1)...]) {
                        engine.log("Certificates: Apple's sign-in server refused \(appleRefusals.count) attempts with HTTP 503 — stopping.")
                        throw EngineError.message(Engine.appleServiceRefusalMessage)
                    }
                }
                // Every anisette server starts with the same request to Apple, so
                // when that can't even be sent, more of them won't help.
                if Engine.isAppleUnreachable(lastError) {
                    appleUnreachable += 1
                    if let message = await engine.appleUnreachableStop(
                        failures: appleUnreachable, logPrefix: "Certificates: ") {
                        throw EngineError.message(message)
                    }
                } else {
                    appleUnreachable = 0
                }
            }
        }
        let tried = servers.count == 1
            ? L("the anisette server")
            : L("all %d anisette servers", servers.count)
        throw EngineError.message(L("Apple ID sign-in failed on %@. Last error: %@", tried, lastError))
    }

    /// One sign-in attempt against a specific anisette server.
    private func performSignIn(id: String, pw: String, ani: String, dir: String,
                               ticket: AppleSignInTicket) throws -> String {
        defer { engine.endTwoFactor(for: ticket) }
        var newSession: OpaquePointer?
        var summary: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_cert_signin(id, pw, ani, "SideInstaller", dir,
                                appleSignInTwoFactorCallback, ticket.context,
                                &newSession, &summary, &error)
        if rc == 0 {
            if let old = self.session { si_cert_session_free(old) }
            self.session = newSession
            let s = summary.map { String(cString: $0) } ?? ""
            summary.map { si_string_free($0) }
            return s
        } else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message(msg)
        }
    }

    // MARK: - List / revoke FFI

    private func performList() throws -> [DevCert] {
        guard let session = self.session else { throw EngineError.message("Not signed in.") }
        var json: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_cert_list(session, &json, &error)
        if rc == 0 {
            let s = json.map { String(cString: $0) } ?? "[]"
            json.map { si_string_free($0) }
            do {
                return try JSONDecoder().decode([DevCert].self, from: Data(s.utf8))
            } catch {
                throw EngineError.message("Couldn't read the certificate list: \(error)")
            }
        } else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message("Listing certificates failed: \(msg)")
        }
    }

    private func performRevoke(serial: String) throws {
        guard let session = self.session else { throw EngineError.message("Not signed in.") }
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_cert_revoke(session, serial, &error)
        if rc != 0 {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message("Revoke failed: \(msg)")
        }
    }

    private static let importNotOnTeam: Int32 = 3

    /// Thrown for error 3, which the import explains for where the
    /// certificate came from.
    private struct ImportNotOnTeam: Error {}

    private func performImport(p12: Data, password: String) throws -> CertImportResult {
        guard let session = self.session else { throw EngineError.message("Not signed in.") }
        var json: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = p12.withUnsafeBytes { bytes in
            si_cert_import(session, bytes.bindMemory(to: UInt8.self).baseAddress, bytes.count,
                           password, &json, &error)
        }
        if rc == 0 {
            let s = json.map { String(cString: $0) } ?? "{}"
            json.map { si_string_free($0) }
            do {
                return try JSONDecoder().decode(CertImportResult.self, from: Data(s.utf8))
            } catch {
                throw EngineError.message("Couldn't read what the import did: \(error)")
            }
        }
        let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
        error.map { si_string_free($0) }
        engine.log("Certificate import: \(msg)")
        if rc == Self.importNotOnTeam { throw ImportNotOnTeam() }
        throw EngineError.message(L("Couldn't use that certificate: %@", msg))
    }

    /// Makes sure there is a live Apple sign-in session, signing in first
    /// if needed — the same auto-login `loadCerts` and the import flow do.
    /// Export used to just guard on the session, so opening the app detail
    /// page without ever visiting the certificates page always failed with
    /// "Not signed in." Throws the sign-in error itself when login fails.
    func ensureSignedIn() async throws {
        let id = engine.normalizedAppleID, pw = engine.applePassword
        guard !id.isEmpty, !pw.isEmpty else {
            throw EngineError.message(L("No Apple ID saved. Add one in Settings › Account."))
        }
        if session == nil { try await signIn(id: id, pw: pw) }
    }

    /// Export the signing certificate as p12 (base64) + password.
    /// Returns (p12Data, password).
    func exportP12() throws -> (Data, String) {
        guard let session = self.session else { throw EngineError.message("Not signed in.") }
        let email = engine.appleID
        // Machine name: use the first cert's machineName, or fallback
        let machineName = certs.first?.machineName ?? "SideInstaller"
        let storageDir = PrivateStore.isideload.path

        var outJson: UnsafeMutablePointer<CChar>?
        var outError: UnsafeMutablePointer<CChar>?
        let rc = si_cert_export_p12(
            session,
            email, machineName, storageDir,
            &outJson, &outError
        )
        if rc == 0 {
            let jsonStr = outJson.map { String(cString: $0) } ?? "{}"
            outJson.map { si_string_free($0) }
            guard let jsonData = jsonStr.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
                  let b64 = obj["p12_b64"],
                  let password = obj["password"],
                  let p12Data = Data(base64Encoded: b64) else {
                throw EngineError.message("Couldn't parse p12 export result.")
            }
            return (p12Data, password)
        } else {
            let msg = outError.map { String(cString: $0) } ?? "rc=\(rc)"
            outError.map { si_string_free($0) }
            throw EngineError.message("Export failed: \(msg)")
        }
    }

    // MARK: - Helpers

    /// Anisette addresses to try, in the engine's order.
    private func anisetteCandidates() -> [String] {
        engine.anisetteCandidates()
    }

    /// Same isideload storage as the install flow.
    private var storageDir: String {
        PrivateStore.isideload.path
    }

    private func short(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    /// Bridge a blocking FFI body on the cert queue to async.
    private func onQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { cont.resume(returning: try work()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}
