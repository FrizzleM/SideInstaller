import Foundation
import SideInstallerFFI

/// One iOS development certificate on the Apple ID, decoded from the Rust core's
/// JSON (`si_cert_list`). Every field is a plain string — the Rust side flattens
/// Apple's optionals to "" so the UI never has to unwrap.
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

    /// Stable identity for SwiftUI / revocation. Serial is the revoke key; fall
    /// back to the certificate id if Apple didn't send one.
    var id: String { serialNumber.isEmpty ? certificateId : serialNumber }

    var displayName: String { name.isEmpty ? "Unnamed certificate" : name }

    /// "Created on <machine>" label, or nil when Apple didn't tag a machine.
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

/// Drives the Apple-developer certificate manager: signs in (reusing the shared
/// `Engine`'s credentials, anisette servers, and 2FA prompt), lists the iOS
/// development certificates, and revokes them by serial number.
///
/// Independent of the install pipeline — revocation is a pure developer-portal
/// API call, so no device, pairing, or LocalDevVPN tunnel is involved.
///
/// Mirrors `Engine`'s threading: a plain `ObservableObject` (not `@MainActor`)
/// whose `@Published` state is mutated inside `Task { @MainActor in … }`, with
/// the BLOCKING FFI bridged onto a background queue.
final class CertManager: ObservableObject {

    @Published private(set) var certs: [DevCert] = []
    @Published private(set) var isSignedIn = false
    @Published private(set) var teamSummary: String?
    /// Sign-in or list in progress.
    @Published private(set) var isWorking = false
    /// `id` of the certificate currently being revoked, if any.
    @Published private(set) var revokingID: String?
    @Published var lastError: String?
    /// True once a list has been fetched at least once (drives the empty state).
    @Published private(set) var hasLoaded = false

    private var session: OpaquePointer?            // CertSession*
    private let queue = DispatchQueue(label: "sideinstaller.certs")

    private var engine: Engine { Engine.shared }

    deinit {
        if let session { si_cert_session_free(session) }
    }

    // MARK: - Public actions

    /// Sign in (if needed) and (re)load the certificate list. The primary action
    /// of the Certificates tab.
    @MainActor
    func loadCerts() {
        guard !isWorking, revokingID == nil else { return }
        let id = engine.appleID, pw = engine.applePassword
        guard !id.isEmpty, !pw.isEmpty else {
            lastError = "Enter your Apple ID email and password first."
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
            } catch is CancellationError {
                // not cancellable today, but keep parity with Engine
            } catch {
                lastError = short(error)
                engine.log("⛔️ Certificates: \(lastError ?? "failed")")
            }
            isWorking = false
        }
    }

    /// Revoke one certificate, then refresh the list to reflect it.
    @MainActor
    func revoke(_ cert: DevCert) {
        guard session != nil, revokingID == nil, !isWorking else { return }
        let serial = cert.serialNumber
        guard !serial.isEmpty else {
            lastError = "This certificate has no serial number, so it can't be revoked."
            return
        }
        revokingID = cert.id
        lastError = nil
        engine.log("Certificates: revoking \(cert.displayName) (\(serial)) …")
        Task { @MainActor in
            do {
                try await onQueue { try self.performRevoke(serial: serial) }
                engine.log("Certificates: revoked \(cert.displayName).")
                let list = try await onQueue { try self.performList() }
                certs = list
            } catch {
                lastError = short(error)
                engine.log("⛔️ Revoke failed: \(lastError ?? "")")
            }
            revokingID = nil
        }
    }

    /// Forget the signed-in session (e.g. to switch Apple ID). Clears the list.
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

    // MARK: - Sign-in (mirrors Engine's anisette-fallback loop)

    @MainActor
    private func signIn(id: String, pw: String) async throws {
        // Anisette servers are flaky, so try the user's pick first, then every
        // other known server. Credential/2FA-cancel errors stop the loop early.
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
                    throw EngineError.message("Two-factor verification was cancelled.")
                }
                if Engine.isCredentialError(lastError) {
                    throw EngineError.message("Apple ID sign-in failed: \(lastError)")
                }
                engine.log("Certificates: anisette \(idx + 1)/\(servers.count) failed: \(lastError)")
            }
        }
        let tried = servers.count == 1 ? "the anisette server" : "all \(servers.count) anisette servers"
        throw EngineError.message("Apple ID sign-in failed on \(tried). Last error: \(lastError)")
    }

    /// One sign-in attempt against a specific anisette server. Stores the session
    /// on success; throws `EngineError.message` with the raw failure otherwise.
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

    /// Anisette servers to try, in order: the engine's current pick first, then
    /// every other known server. De-duplicated; addresses only. (Same policy as
    /// `Engine.anisetteCandidates`.)
    private func anisetteCandidates() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for addr in [engine.anisetteURL] + engine.anisetteServers.map(\.address) {
            let a = addr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty, seen.insert(a).inserted { out.append(a) }
        }
        return out
    }

    /// Same on-disk anisette/account storage the install flow uses, so machine
    /// provisioning is shared rather than re-bootstrapped.
    private var storageDir: String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("isideload")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
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

/// Bare C function pointer — bridges isideload's 2FA request (during cert
/// sign-in) to the engine's shared blocking prompt. Runs on a Rust worker
/// thread. Same mechanism as the install flow's callback.
private let certTwoFactorCallback: SITwoFactorCb = { _, outBuf, bufLen in
    guard let outBuf = outBuf else { return 0 }
    return Engine.shared.provideTwoFactorCode(outBuf, Int(bufLen))
}
