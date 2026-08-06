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

/// Lists and revokes the Apple ID's development certificates, reusing the
/// engine's credentials and 2FA prompt. Purely a developer-portal API call, so
/// no device or tunnel is involved, and the blocking FFI runs off the main queue.
final class CertManager: ObservableObject {

    @Published private(set) var certs: [DevCert] = []
    @Published private(set) var isSignedIn = false
    @Published private(set) var teamSummary: String?
    /// Sign-in or list in progress.
    @Published private(set) var isWorking = false
    /// `id` of the certificate currently being revoked, if any.
    @Published private(set) var revokingID: String?
    @Published var lastError: String?
    /// True once a list has been fetched, so the empty state can tell them apart.
    @Published private(set) var hasLoaded = false

    private var session: OpaquePointer?            // CertSession*
    private let queue = DispatchQueue(label: "sideinstaller.certs")

    private var engine: Engine { Engine.shared }

    deinit {
        if let session { si_cert_session_free(session) }
    }

    // MARK: - Public actions

    /// Sign in if needed and reload the list; `then` runs only if it arrived.
    @MainActor
    func loadCerts(then: (() -> Void)? = nil) {
        guard !isWorking, revokingID == nil else { return }
        let id = engine.normalizedAppleID, pw = engine.applePassword
        guard !id.isEmpty, !pw.isEmpty else {
            lastError = L("Enter your Apple ID email and password first.")
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
                // not cancellable today, but keep parity with Engine
            } catch {
                lastError = short(error)
                engine.log("⛔️ Certificates: \(lastError ?? "failed")")
            }
            isWorking = false
        }
    }

    /// Revoke one certificate and refresh the list. `onSuccess` — which resumes
    /// a stopped install — runs only once Apple has accepted the revocation.
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
                let list = try await onQueue { try self.performList() }
                certs = list
            } catch {
                lastError = short(error)
                engine.log("⛔️ Revoke failed: \(lastError ?? "")")
            }
            revokingID = nil
            // The refresh can fail on its own; the revoke is what's awaited.
            if revoked { onSuccess?() }
        }
    }

    /// Load the list if that hasn't happened yet, then run `then` — for the
    /// Install screen, which must name a certificate before revoking it.
    @MainActor
    func ensureLoaded(then: @escaping () -> Void) {
        guard !isWorking, revokingID == nil else { return }
        if hasLoaded, session != nil {
            then()
            return
        }
        loadCerts(then: then)
    }

    /// Forget the session and clear the list, to switch Apple ID.
    @MainActor
    func signOut() {
        if let session { si_cert_session_free(session) }
        session = nil
        isSignedIn = false
        teamSummary = nil
        certs = []
        hasLoaded = false
        lastError = nil
        engine.log("Certificates: signed out.")
    }

    // MARK: - Sign-in

    @MainActor
    private func signIn(id: String, pw: String) async throws {
        // Try each anisette server; a credential or 2FA error stops the loop.
        let servers = anisetteCandidates()
        let dir = storageDir
        engine.twoFactorWasCancelled = false
        var lastError = "no anisette servers configured"

        for (idx, ani) in servers.enumerated() {
            do {
                let summary = try await onQueue {
                    try self.performSignIn(id: id, pw: pw, ani: ani, dir: dir)
                }
                engine.anisetteURL = ani               // stick with what worked
                teamSummary = summary
                isSignedIn = true
                engine.log("Certificates: signed in (\(summary)).")
                return
            } catch let error as EngineError {
                lastError = error.errorDescription ?? "sign-in failed"
                if engine.twoFactorWasCancelled {
                    engine.log("Two-factor verification cancelled — stopping.")
                    throw EngineError.message(L("Two-factor verification was cancelled."))
                }
                if Engine.isCredentialError(lastError) {
                    engine.log("Apple ID credentials rejected: \(lastError)")
                    throw EngineError.message(Engine.credentialErrorMessage)
                }
                engine.log("Certificates: anisette \(idx + 1)/\(servers.count) failed: \(lastError)")
            }
        }
        let tried = servers.count == 1
            ? L("the anisette server")
            : L("all %d anisette servers", servers.count)
        throw EngineError.message(L("Apple ID sign-in failed on %@. Last error: %@", tried, lastError))
    }

    /// One sign-in attempt against a specific anisette server.
    private func performSignIn(id: String, pw: String, ani: String, dir: String) throws -> String {
        var newSession: OpaquePointer?
        var summary: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_cert_signin(id, pw, ani, "SideInstaller", dir,
                                certTwoFactorCallback, nil,
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

    // MARK: - Helpers

    /// Anisette addresses to try, the engine's current pick first.
    private func anisetteCandidates() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for addr in [engine.anisetteURL] + engine.anisetteServers.map(\.address) {
            let a = addr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty, seen.insert(a).inserted { out.append(a) }
        }
        return out
    }

    /// The install flow's storage, so provisioning isn't re-bootstrapped.
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

// MARK: - C 2FA callback

/// Bridges a 2FA request during cert sign-in to the engine's shared prompt.
private let certTwoFactorCallback: SITwoFactorCb = { _, outBuf, bufLen in
    guard let outBuf = outBuf else { return 0 }
    return Engine.shared.provideTwoFactorCode(outBuf, Int(bufLen))
}
