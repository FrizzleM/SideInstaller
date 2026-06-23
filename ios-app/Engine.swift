import Foundation
import SideInstallerFFI

/// One ordered step of the one-click install. The denominator for the progress
/// bar and the rows of the step checklist.
enum Step: Int, CaseIterable, Identifiable {
    case network, pair, connect, signIn, download, sign, install, writePairing

    var id: Int { rawValue }

    /// The checklist label. The download/install rows name the chosen build so
    /// the timeline matches what the user picked (e.g. "SS + LiveContainer")
    /// rather than always saying "SideStore".
    func title(for source: InstallSource) -> String {
        switch self {
        case .network:      return "Connect the VPN"
        case .pair:         return "Pair with this iPhone"
        case .connect:      return "Open the device link"
        case .signIn:       return "Sign in to Apple ID"
        case .download:     return "Download \(source.shortName)"
        case .sign:         return "Sign the app"
        case .install:      return "Install \(source.shortName)"
        case .writePairing: return "Finish setup"
        }
    }
}

enum StepState {
    case pending   // not started
    case active    // running
    case waiting   // running, but blocked on something the user must do
    case done      // finished OK
    case failed    // stopped here
}

/// A contextual instruction card shown to the user (open this app, go here,
/// paste that). Kept data-only so the View can render it however it likes.
struct Guide: Equatable {
    var title: String
    var systemImage: String
    var steps: [String]
    var actionLabel: String?
    var actionURLString: String?

    var actionURL: URL? { actionURLString.flatMap(URL.init(string:)) }
}

/// A small typed error so step failures carry a friendly, user-facing sentence
/// (the raw FFI error is always also written to the log).
enum EngineError: LocalizedError {
    case message(String)
    /// Apple's free-account cap of 3 signing certificates is already used up.
    case certLimit

    var errorDescription: String? {
        switch self {
        case let .message(m):
            return m
        case .certLimit:
            return "Apple allows only 3 signing certificates per Apple ID and this one already has 3, so a new one can't be made. Sign in with a different Apple ID, or revoke an old certificate — see the steps above."
        }
    }
}

/// The single place all business logic lives. SwiftUI's views only read
/// `@Published` state and call these methods — zero logic in the views.
///
/// A singleton because the C logging callback (a bare `@convention(c)` function
/// pointer that can't capture context) routes lines to `Engine.shared`.
final class Engine: ObservableObject {

    static let shared = Engine()

    // MARK: Log console

    struct LogEntry: Identifiable {
        let id = UUID()
        let stamp: String
        let text: String
    }

    @Published private(set) var lines: [LogEntry] = []

    // MARK: Inputs

    @Published var appleID: String = ""
    @Published var applePassword: String = ""
    @Published var anisetteURL: String = AnisetteServer.fallback.address
    /// Servers the user can pick from. Seeded with a bundled snapshot so the
    /// picker is populated instantly, then refreshed from the live list on
    /// launch (see `loadAnisetteServers`).
    @Published private(set) var anisetteServers: [AnisetteServer] = AnisetteServer.bundledDefaults
    // LocalDevVPN's default device (target) IP; configurable in Advanced.
    @Published var deviceIP: String = "10.7.0.1"
    // Which build to install (plain SideStore vs LiveContainer + SideStore).
    @Published var installSource: InstallSource = .sideStore

    // MARK: Plain-text status readouts

    /// Live LocalDevVPN loopback state, polled (see `startStatusMonitor`) so the
    /// UI banner + the Install gate always reflect the current tunnel.
    @Published var vpnConnected: Bool = false
    @Published var vpnStatus: String = "unknown"
    @Published var wifiStatus: String = "unknown"
    @Published var pairingStatus: String = "not paired"
    @Published var signInStatus: String = "signed out"

    // Path to the pairing file produced by RPPairing (STEP 2).
    @Published var pairingFilePath: String?

    // MARK: One-click orchestration state

    /// Per-step status, the backbone of the checklist + progress bar.
    @Published var stepStates: [Step: StepState] = Dictionary(
        uniqueKeysWithValues: Step.allCases.map { ($0, .pending) })

    /// Install percentage (0…1) streamed from installation_proxy; also feeds the
    /// fractional part of the overall progress bar while installing.
    @Published var installProgress: Double = 0

    /// The pairing PIN to display prominently, when one has been issued.
    @Published var pairingPIN: String?

    /// Short human summary of the connected device, e.g. "iPhone · iOS 17.5".
    @Published var deviceSummary: String?

    /// The current contextual instruction card (nil = none).
    @Published var guide: Guide?

    /// True while the one-click pipeline is running.
    @Published var isRunning: Bool = false

    /// Set when the pipeline stops on an error; cleared on a new run.
    @Published var lastError: String?

    /// Set once the whole pipeline has completed successfully.
    @Published var finished: Bool = false

    private var pipelineTask: Task<Void, Never>?
    /// Repeating poll that keeps `vpnConnected` live for the UI banner. A timer
    /// (not NWPathMonitor) because LocalDevVPN is a local-only tunnel with no
    /// default route, so a path monitor never fires when it comes up or down.
    private var statusTimer: Timer?

    /// True when the build that was actually installed is the LiveContainer +
    /// SideStore bundle (falls back to the current selection before any
    /// download). Drives the post-install "import the certificate into
    /// LiveContainer" card, which only applies to that build.
    var installedIsLiveContainer: Bool {
        (downloadedSource ?? installSource) == .liveContainer
    }

    /// Name of the build that was installed (or is selected, before any
    /// download) — used so post-install copy names the right app.
    var installedSourceName: String {
        (downloadedSource ?? installSource).displayName
    }

    /// Overall fraction across all steps (0…1). Computed from the published
    /// step states + install sub-progress, so the bar updates automatically.
    var overallProgress: Double {
        let total = Double(Step.allCases.count)
        let done = Double(Step.allCases.filter { stepStates[$0] == .done }.count)
        let frac = (stepStates[.install] == .active || stepStates[.install] == .waiting)
            ? installProgress : 0
        return min(1, (done + frac) / total)
    }

    // Loopback connection over LocalDevVPN (idevice FFI). Long-lived; reused
    // across device-info / list-apps / install. Serialized on deviceQueue.
    let connection = DeviceConnection()
    private let deviceQueue = DispatchQueue(label: "sideinstaller.device")

    // Apple ID sign-in / signing (isideload via FFI). Serialized on signQueue.
    private let signQueue = DispatchQueue(label: "sideinstaller.sign")
    private var signSession: OpaquePointer?          // SignSession*
    @Published var downloadedIPAPath: String?
    // Which source the current download corresponds to (so switching the
    // selection forces a re-download rather than reusing the other build).
    private var downloadedSource: InstallSource?
    @Published var signedAppPath: String?

    // 2FA bridge: the FFI 2FA callback (on a Rust worker thread) blocks on this
    // semaphore until the UI submits/cancels a code.
    @Published var pendingTwoFactor = false
    private let twoFactorSem = DispatchSemaphore(value: 0)
    private var twoFactorResult: String?
    /// Set when the user taps Cancel on the 2FA prompt. Lets the sign-in loop
    /// stop instead of re-prompting for every remaining anisette server. Shared
    /// with `CertManager`, which drives the same 2FA prompt.
    var twoFactorWasCancelled = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {
        installLogging()
        log("SideInstaller ready.")
        // Launch self-test: exercises si_ping (which logs via tracing::info!),
        // proving the full Rust-tracing -> FFI callback -> console path at start.
        ping()
        // Show the loopback/Wi-Fi status on launch so the user knows whether to
        // start LocalDevVPN before running, then keep it live for the banner.
        checkVPNAndWifi()
        startStatusMonitor()
        // Refresh the anisette server picker from the live community list.
        loadAnisetteServers()
    }

    // MARK: - Anisette servers

    /// Pull the live anisette server list (the one SideStore/iLoader share) and
    /// swap it in for the bundled snapshot. Silently keeps the snapshot on any
    /// failure — the picker stays usable offline.
    func loadAnisetteServers() {
        Task { @MainActor in
            do {
                let servers = try await AnisetteServer.fetchList()
                guard !servers.isEmpty else { return }
                self.anisetteServers = servers
                log("Loaded \(servers.count) anisette servers.")
            } catch {
                log("Couldn't refresh anisette servers (\(short(error))); using \(self.anisetteServers.count) bundled.")
            }
        }
    }

    // MARK: - Logging

    private func installLogging() {
        let rc = si_log_init(siLogCallback, nil)
        if rc == 0 {
            log("si_log_init: OK — idevice tracing is now piped into this console.")
        } else {
            log("si_log_init: already initialised (rc=\(rc)).")
        }
    }

    /// Append a line from Swift. Safe to call from any thread.
    func log(_ message: String) {
        appendLine(message)
    }

    /// Append a line that originated in the Rust core's tracing output.
    func appendRustLine(_ message: String) {
        appendLine("[rust] " + message)
    }

    private func appendLine(_ message: String) {
        let stamp = dateFormatter.string(from: Date())
        let entry = LogEntry(stamp: stamp, text: message)
        if Thread.isMainThread {
            lines.append(entry)
        } else {
            DispatchQueue.main.async { [weak self] in self?.lines.append(entry) }
        }
    }

    func clearLog() {
        lines.removeAll()
    }

    /// One big string for the “Copy logs” button.
    func logText() -> String {
        lines.map { "\($0.stamp)  \($0.text)" }.joined(separator: "\n")
    }

    // MARK: - Step / guide helpers

    private func setStep(_ step: Step, _ state: StepState) {
        setMain { self.stepStates[step] = state }
    }

    private func setGuide(_ guide: Guide?) {
        setMain { self.guide = guide }
    }

    private func resetRun() {
        setMain {
            for s in Step.allCases { self.stepStates[s] = .pending }
            self.installProgress = 0
            self.pairingPIN = nil
            self.guide = nil
            self.deviceSummary = nil
            self.lastError = nil
            self.finished = false
        }
    }

    /// Move whichever step is currently active/waiting into a terminal state
    /// (used when the pipeline stops or is cancelled).
    private func failActiveStep(to state: StepState) {
        setMain {
            for s in Step.allCases where self.stepStates[s] == .active || self.stepStates[s] == .waiting {
                self.stepStates[s] = state
            }
        }
    }

    // MARK: - One-click pipeline (the default flow)

    /// Run every step needed to install SideStore, in order, stopping at the
    /// first failure with a clear message. This is the app's primary action.
    @MainActor
    func runOneClick() {
        guard !isRunning else { return }
        guard !appleID.isEmpty, !applePassword.isEmpty else {
            setGuide(Guides.credentials)
            log("Enter your Apple ID email + password first.")
            return
        }
        // Pre-flight gate: the entire install runs over LocalDevVPN's loopback
        // tunnel, so don't even begin until it's connected — show how instead.
        // (ensureNetwork() below still waits too, as a mid-run safety net in case
        // the tunnel drops after this check passes.)
        refreshNetworkStatus()
        guard vpnConnected else {
            setGuide(Guides.vpn)
            log("⛔️ LocalDevVPN isn't connected. Turn it on, then tap Install again.")
            return
        }
        resetRun()
        isRunning = true
        log("=== Starting one-click install ===")

        pipelineTask = Task { @MainActor in
            do {
                try await ensureNetwork()
                try await pairAndConnect()
                try await signIn()
                try await download()
                try await signApp()
                try await install()
                try await writePairing()
                finishSuccess()
            } catch is CancellationError {
                log("Install cancelled.")
                failActiveStep(to: .pending)
                setGuide(nil)
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                lastError = msg
                log("⛔️ Stopped: \(msg)")
                failActiveStep(to: .failed)
            }
            isRunning = false
            pairingPIN = nil
        }
    }

    /// Stop the pipeline at the next safe point.
    @MainActor
    func cancelOneClick() {
        pipelineTask?.cancel()
        PairingController.shared.softCancel()   // unblock a pending pairing wait
    }

    // MARK: Step 1 — network (waits for LocalDevVPN)

    @MainActor
    private func ensureNetwork() async throws {
        setStep(.network, .active)
        var announced = false
        while true {
            try Task.checkCancellation()
            let (vpn, wifi, detail) = NetworkStatus.summarize(deviceIP: deviceIP)
            vpnConnected = vpn
            vpnStatus = vpn ? "tunnel up" : "no tunnel"
            wifiStatus = wifi ? "on" : "off"
            if vpn {
                log("Network OK: \(detail)")
                setStep(.network, .done)
                setGuide(nil)
                return
            }
            if !announced {
                log("Waiting for LocalDevVPN tunnel… open LocalDevVPN and tap Connect.")
                announced = true
            }
            setStep(.network, .waiting)
            setGuide(Guides.vpn)
            try await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }

    // MARK: Step 2+3 — pair, then connect (with a one-shot re-pair fallback)

    @MainActor
    private func pairAndConnect() async throws {
        let path = PairingController.pairingFilePath()
        let reused = fileExistsNonEmpty(path)
        if reused {
            log("Found an existing pairing file — trying it first.")
            pairingFilePath = path
            setStep(.pair, .done)
        } else {
            try await pair()
        }

        do {
            try await connect()
        } catch {
            // A reused pairing file can be stale (re-paired device, old file).
            // Pair fresh once, then retry the connection.
            guard reused else { throw error }
            log("Saved pairing didn't work (\(short(error))). Pairing fresh…")
            try await pair()
            try await connect()
        }
    }

    @MainActor
    private func pair() async throws {
        setStep(.pair, .waiting)
        setGuide(Guides.pairing)
        log("Pairing: starting on-device pairing service…")
        let path = try await PairingController.shared.startAndWait()
        pairingFilePath = path
        pairingPIN = nil
        setStep(.pair, .done)
        setGuide(nil)
    }

    @MainActor
    private func connect() async throws {
        setStep(.connect, .active)
        setGuide(nil)
        let ip = deviceIP
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        let summary = try await onDeviceQueue { try self.performConnect(ip: ip, pairingPath: path) }
        deviceSummary = summary
        pairingStatus = "connected"
        setStep(.connect, .done)
    }

    private func performConnect(ip: String, pairingPath path: String) throws -> String {
        // Gate: never attempt a connect with a missing/zero-byte pairing file —
        // idevice maps the file-read error to a confusing Socket(ENOENT).
        let size = fileSize(path)
        guard FileManager.default.fileExists(atPath: path), size > 0 else {
            throw EngineError.message("Pairing didn't finish — no pairing file yet.")
        }
        log("Pairing file OK (\(size) bytes). Connecting over TCP/RSD \(ip):\(DeviceConnection.rsdPort) …")
        try connection.connect(deviceIP: ip, pairingFilePath: path)
        log("Tunnel + RSD handshake established.")
        log(try connection.rsdSummary())
        let info = try connection.deviceInfo()
        var dict: [String: String] = [:]
        if info.isEmpty {
            log("Device info: (lockdownd returned no values)")
        } else {
            log("Device info:")
            for (k, v) in info { dict[k] = v; log("  \(k) = \(v)") }
        }
        let name = dict["DeviceName"] ?? "device"
        if let version = dict["ProductVersion"] { return "\(name) · iOS \(version)" }
        return name
    }

    // MARK: Step 4 — Apple ID sign-in

    @MainActor
    private func signIn() async throws {
        if signSession != nil {
            log("Already signed in this session — skipping.")
            setStep(.signIn, .done)
            return
        }
        guard !appleID.isEmpty, !applePassword.isEmpty else {
            throw EngineError.message("Enter your Apple ID email + password.")
        }
        setStep(.signIn, .active)

        // Anisette servers are flaky and go down often, so don't fail on the
        // first one — try the user's pick, then every other known server, and
        // only give up once they've all failed. (Apple ID errors that no server
        // could fix, like a wrong password or a cancelled 2FA prompt, stop the
        // loop early — see below.)
        let servers = anisetteCandidates()
        let id = appleID, pw = applePassword, dir = storageDir
        twoFactorWasCancelled = false
        var lastError = "no anisette servers configured"

        for (idx, ani) in servers.enumerated() {
            try Task.checkCancellation()
            let name = anisetteName(for: ani)
            signInStatus = servers.count > 1
                ? "signing in via \(name) (\(idx + 1)/\(servers.count))…"
                : "signing in…"
            if servers.count > 1 {
                log("Sign-in attempt \(idx + 1)/\(servers.count) — anisette \(name).")
            }
            do {
                let summary = try await onSignQueue {
                    try self.performSignIn(id: id, pw: pw, ani: ani, dir: dir)
                }
                // Worked — remember the server that succeeded so the rest of the
                // app (and any re-run) sticks with it.
                anisetteURL = ani
                signInStatus = "signed in (\(summary))"
                setStep(.signIn, .done)
                return
            } catch let error as EngineError {
                lastError = error.errorDescription ?? "sign-in failed"

                // A cancelled 2FA prompt isn't the server's fault — bail now
                // rather than re-prompting for every remaining server.
                if twoFactorWasCancelled {
                    log("Two-factor verification cancelled — stopping.")
                    signInStatus = "signed out"
                    throw EngineError.message("Two-factor verification was cancelled.")
                }
                // A bad Apple ID / password fails the same way on every server,
                // and hammering Apple with repeated bad logins risks locking the
                // account — so stop instead of cycling through the whole list.
                if Self.isCredentialError(lastError) {
                    signInStatus = "sign-in failed"
                    throw EngineError.message("Apple ID sign-in failed: \(lastError)")
                }
                log("Anisette \(name) failed: \(lastError)")
                if idx < servers.count - 1 { log("Trying the next anisette server…") }
            }
        }

        signInStatus = "sign-in failed"
        let tried = servers.count == 1 ? "the anisette server" : "all \(servers.count) anisette servers"
        throw EngineError.message("Apple ID sign-in failed on \(tried). Last error: \(lastError)")
    }

    /// One sign-in attempt against a specific anisette server. Returns the
    /// account summary on success; throws `EngineError.message` with the raw
    /// failure text (so the caller can classify it) otherwise.
    private func performSignIn(id: String, pw: String, ani: String, dir: String) throws -> String {
        log("Apple ID sign-in for \(id) via anisette \(ani) …")
        var session: OpaquePointer?
        var summary: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_apple_signin(id, pw, ani, "SideInstaller", dir,
                                 twoFactorCallback, nil,
                                 &session, &summary, &error)
        if rc == 0 {
            if let old = self.signSession { si_sign_session_free(old) }
            self.signSession = session
            let s = summary.map { String(cString: $0) } ?? ""
            summary.map { si_string_free($0) }
            log("Sign-in OK. \(s)")
            return s
        } else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message(msg)
        }
    }

    /// Anisette servers to try, in order: the user's current pick first, then
    /// every other known server. De-duplicated; addresses only.
    private func anisetteCandidates() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for addr in [anisetteURL] + anisetteServers.map(\.address) {
            let a = addr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty, seen.insert(a).inserted { out.append(a) }
        }
        return out
    }

    /// Friendly name for an anisette address (falls back to the address itself).
    private func anisetteName(for address: String) -> String {
        anisetteServers.first { $0.address == address }?.name ?? address
    }

    /// Detect a definitive Apple ID credential failure (vs. a flaky anisette
    /// server). Switching anisette servers can't fix these, so the sign-in loop
    /// stops on them instead of trying every server.
    static func isCredentialError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("apple id or password")
            || m.contains("password was incorrect")
            || m.contains("incorrect apple id")
            || m.contains("-20101")          // GSA: invalid username/password
            || (m.contains("password") && m.contains("incorrect"))
    }

    // MARK: Step 5 — download SideStore

    @MainActor
    private func download() async throws {
        let src = installSource
        if let p = downloadedIPAPath, downloadedSource == src, FileManager.default.fileExists(atPath: p) {
            log("\(src.displayName) IPA already downloaded — skipping.")
            setStep(.download, .done)
            return
        }
        setStep(.download, .active)
        log("Fetching latest \(src.displayName) release…")
        let path = try await SideStoreDownloader.downloadLatest(source: src) { line in self.log(line) }
        downloadedIPAPath = path
        downloadedSource = src
        log("\(src.displayName) IPA ready at \(path)")
        setStep(.download, .done)
    }

    // MARK: Step 6 — sign the IPA

    @MainActor
    private func signApp() async throws {
        guard let session = signSession else { throw EngineError.message("Not signed in.") }
        guard let ipa = downloadedIPAPath else { throw EngineError.message("No SideStore IPA downloaded.") }
        setStep(.sign, .active)
        do {
            let path = try await onSignQueue { try self.performSign(session: session, ipa: ipa) }
            signedAppPath = path
            setStep(.sign, .done)
        } catch {
            // The "max certificates" failure has a concrete, user-fixable cause —
            // show the explanatory card alongside the stopped step.
            if case EngineError.certLimit = error { setGuide(Guides.certLimit) }
            throw error
        }
    }

    private func performSign(session: OpaquePointer, ipa: String) throws -> String {
        log("Signing \(ipa) …")
        var signed: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_sign_ipa(session, ipa, &signed, &error)
        if rc == 0 {
            let path = signed.map { String(cString: $0) } ?? ""
            signed.map { si_string_free($0) }
            log("Signed bundle at \(path)")
            return path
        } else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            log("Sign FAILED: \(msg)")
            if Self.isCertLimitError(msg) { throw EngineError.certLimit }
            throw EngineError.message("Signing failed: \(msg)")
        }
    }

    /// Detect Apple's "max certificates" rejection in a raw signing error.
    /// Apple returns e.g. "Developer error 7460: Maximum number of certificates
    /// reached" (surfaced by isideload as "sign_app failed: …").
    static func isCertLimitError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("7460")
            || m.contains("maximum number of certificates")
            || (m.contains("certificate") && (m.contains("maximum") || m.contains("limit")))
    }

    // MARK: Step 7 — install over AFC + installation_proxy

    @MainActor
    private func install() async throws {
        guard let bundle = signedAppPath else { throw EngineError.message("No signed bundle to install.") }
        setStep(.install, .active)
        installProgress = 0
        try await onDeviceQueue {
            guard self.connection.isConnected else { throw EngineError.message("Device link dropped — reconnect.") }
            self.log("Installing signed bundle via AFC + installation_proxy …")
            try self.connection.installSignedApp(bundlePath: bundle)
            self.log("Install request completed.")
        }
        installProgress = 1
        setStep(.install, .done)
    }

    // MARK: Step 8 — write the pairing file into SideStore

    @MainActor
    private func writePairing() async throws {
        setStep(.writePairing, .active)
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        // Use the build that was actually installed (falls back to the current
        // selection) — it decides the host app and the path the file lands at.
        let source = downloadedSource ?? installSource
        try await onDeviceQueue { try self.performWritePairing(path: path, source: source) }
        setStep(.writePairing, .done)
    }

    private func performWritePairing(path: String, source: InstallSource) throws {
        guard connection.isConnected else { throw EngineError.message("Device link dropped — reconnect.") }
        let size = fileSize(path)
        guard FileManager.default.fileExists(atPath: path), size > 0 else {
            throw EngineError.message("Pairing file missing — pairing must run first.")
        }
        // Resolve the *installed* host app's bundle id. installation_proxy is the
        // source of truth — match by display name (survives the bundle id rewrite
        // isideload performs), then by base bundle id; fall back to the signed
        // bundle's id only if the lookup is empty. For LiveContainer the host app
        // is LiveContainer (com.kdt.livecontainer.<teamID>), not SideStore.
        let appName = source.pairingAppDisplayName
        let bundleID: String
        if let found = try connection.resolveInstalledBundleID(
            displayName: appName, bundleIDBase: source.pairingBundleIDBase) {
            bundleID = found
        } else if let signed = signedAppBundleID() {
            bundleID = signed
            log("\(appName) not found via installation_proxy; using signed bundle id \(signed).")
        } else {
            throw EngineError.message("\(source.displayName) isn't installed yet — install must run first.")
        }
        // Plain SideStore reads the file at its Documents root; the LiveContainer
        // guest reads it from a nested folder. The source picks the right path.
        let remoteRel = source.pairingRemoteRelativePath
        log("Resolved \(appName) bundle id: \(bundleID)")
        log("Writing pairing file into \(bundleID) /Documents/\(remoteRel) …")
        let written = try connection.writePairingFile(intoBundleID: bundleID,
                                                       remoteRelativePath: remoteRel,
                                                       pairingFilePath: path)
        log("Pairing file written into \(appName) and read-back VERIFIED (\(written) bytes).")
    }

    // MARK: Success

    @MainActor
    private func finishSuccess() {
        finished = true
        setGuide(Guides.trust)
        log("✅ Done — \(installedSourceName) is installed. One trust step left (see the card).")
    }

    // MARK: - STEP 1: liveness

    func ping() {
        runInBackground("ping") {
            guard let raw = si_ping() else {
                self.log("si_ping returned null")
                return
            }
            let msg = String(cString: raw)
            si_string_free(raw)
            self.log("si_ping -> \(msg)")
        }
    }

    // MARK: - Advanced section: individual steps
    //
    // Each thin wrapper runs the same async core as the one-click flow, so the
    // two paths can never drift. They log their own failures (the one-click
    // orchestrator instead surfaces failures as a stopped step + guide).

    func checkVPNAndWifi() {
        let (vpn, wifi, detail) = NetworkStatus.summarize(deviceIP: deviceIP)
        vpnConnected = vpn
        vpnStatus = vpn ? "tunnel up" : "no tunnel (start LocalDevVPN)"
        wifiStatus = wifi ? "on" : "off"
        log("Network: \(detail)")
        log("VPN(loopback)=\(vpnStatus), Wi-Fi=\(wifiStatus). RSD target \(deviceIP):\(DeviceConnection.rsdPort).")
        if !vpn { log("⚠️ No LocalDevVPN tunnel on \(deviceIP)'s subnet — open LocalDevVPN and tap Connect.") }
    }

    /// Poll the interface list so `vpnConnected` (and the plain-text readouts)
    /// track LocalDevVPN coming up / dropping while the app is open. Added to the
    /// run loop in `.common` mode so it keeps firing during scrolling.
    private func startStatusMonitor() {
        statusTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshNetworkStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
    }

    /// One quiet (non-logging) re-scan of the LocalDevVPN/Wi-Fi state. Used by the
    /// poll above and as the authoritative check inside the Install gate.
    func refreshNetworkStatus() {
        let (vpn, wifi, _) = NetworkStatus.summarize(deviceIP: deviceIP)
        vpnConnected = vpn
        vpnStatus = vpn ? "tunnel up" : "no tunnel (start LocalDevVPN)"
        wifiStatus = wifi ? "on" : "off"
    }

    /// RPPairing host (fire-and-forget; reports back through the shared engine).
    func generatePairingFile() {
        Task { @MainActor in PairingController.shared.start() }
    }

    func connectAndReadDeviceInfo() {
        Task { @MainActor in
            do { try await connect() } catch { log("Connect FAILED: \(short(error))") }
        }
    }

    func listInstalledApps() {
        deviceQueue.async { [weak self] in
            guard let self else { return }
            guard self.connection.isConnected else {
                self.log("Not connected — run “Connect + read device info” first.")
                return
            }
            do {
                let apps = try self.connection.listApps()
                self.log("installation_proxy reachable — \(apps.count) apps:")
                for a in apps.prefix(200) { self.log("  \(a)") }
            } catch {
                self.log("List apps FAILED: \(error)")
            }
        }
    }

    func appleSignIn() {
        Task { @MainActor in
            do { try await signIn() } catch { log("Sign-in FAILED: \(short(error))") }
        }
    }

    func fetchCertAndProfile() {
        log("Cert + App ID + provisioning profile are fetched/registered automatically during “Sign IPA” (isideload's sign_app handles them).")
    }

    func downloadLatestSideStore() {
        Task { @MainActor in
            do { try await download() } catch { log("Download FAILED: \(short(error))") }
        }
    }

    func signIPA() {
        Task { @MainActor in
            do { try await signApp() } catch { log("Sign FAILED: \(short(error))") }
        }
    }

    func installSideStore() {
        Task { @MainActor in
            do { try await install() } catch { log("Install FAILED: \(short(error))") }
        }
    }

    func writePairingIntoSideStore() {
        Task { @MainActor in
            do { try await writePairing() } catch { log("Write pairing FAILED: \(short(error))") }
        }
    }

    /// Read CFBundleIdentifier from the signed .app's Info.plist.
    private func signedAppBundleID() -> String? {
        guard let app = signedAppPath else { return nil }
        let plistPath = (app as NSString).appendingPathComponent("Info.plist")
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleIdentifier"] as? String
    }

    // MARK: 2FA bridge

    /// Called from a Rust worker thread; blocks until the UI submits/cancels.
    func provideTwoFactorCode(_ outBuf: UnsafeMutablePointer<CChar>, _ len: Int) -> Int32 {
        setMain {
            self.pendingTwoFactor = true
            self.log("2FA required — enter the code from your trusted device.")
        }
        twoFactorSem.wait()
        let code = twoFactorResult
        twoFactorResult = nil
        setMain { self.pendingTwoFactor = false }
        guard let code, !code.isEmpty, len > 1 else { return 0 }
        let bytes = Array(code.utf8.prefix(len - 1))
        outBuf.withMemoryRebound(to: UInt8.self, capacity: len) { dst in
            for (i, b) in bytes.enumerated() { dst[i] = b }
            dst[bytes.count] = 0
        }
        return 1
    }

    func submitTwoFactor(_ code: String) {
        twoFactorWasCancelled = false
        twoFactorResult = code
        twoFactorSem.signal()
    }

    func cancelTwoFactor() {
        twoFactorWasCancelled = true
        twoFactorResult = nil
        twoFactorSem.signal()
    }

    // MARK: - Storage

    private var storageDir: String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("isideload")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    // MARK: - Helpers

    private func fileSize(_ path: String) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int) ?? 0
    }

    private func fileExistsNonEmpty(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path) && fileSize(path) > 0
    }

    private func short(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    /// Bridge a blocking deviceQueue body to async.
    private func onDeviceQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            deviceQueue.async {
                do { cont.resume(returning: try work()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    /// Bridge a blocking signQueue body to async.
    private func onSignQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            signQueue.async {
                do { cont.resume(returning: try work()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    private func runInBackground(_ label: String, _ work: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            work()
        }
    }

    /// Run a closure on the main queue (for @Published mutations off-thread).
    func setMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}

// MARK: - Predefined instruction cards

enum Guides {
    static let credentials = Guide(
        title: "Enter your Apple ID",
        systemImage: "person.crop.circle",
        steps: [
            "Type your Apple ID email and password in the fields above.",
            "A spare / secondary Apple ID is best — a free signing certificate is created on it.",
            "Then tap the Install button.",
        ],
        actionLabel: nil, actionURLString: nil)

    static let vpn = Guide(
        title: "Turn on LocalDevVPN",
        systemImage: "network",
        steps: [
            "Open the LocalDevVPN app (install it first if you haven't).",
            "Tap Connect so the toggle turns on.",
            "Keep Wi-Fi on, then come back here — this continues automatically.",
        ],
        actionLabel: "Get LocalDevVPN",
        actionURLString: "https://apps.apple.com/app/id6755608044")

    static let pairing = Guide(
        title: "Pair this iPhone in Settings",
        systemImage: "lock.iphone",
        steps: [
            "Open the Settings app, then go to Privacy & Security › Developer Mode.",
            "Tap “Pair with SideInstaller”.",
            "Enter your iPhone’s passcode if it asks for it.",
            "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.",
        ],
        actionLabel: nil, actionURLString: nil)

    static let certLimit = Guide(
        title: "Too many signing certificates",
        systemImage: "exclamationmark.shield",
        steps: [
            "Apple allows only 3 signing certificates per Apple ID, and this one already has 3 — usually from setting up AltStore / SideStore on other devices.",
            "Easiest fix: change the Apple ID email above to a different (or spare) account, then tap Install again.",
            "Or revoke an old certificate from another device that has AltStore / SideStore (use its reset / revoke option), then retry here. Revoking stops apps signed with that certificate from launching on those devices.",
        ],
        actionLabel: nil, actionURLString: nil)

    static let trust = Guide(
        title: "Last step: trust SideStore",
        systemImage: "checkmark.seal",
        steps: [
            "Open Settings › General › VPN & Device Management.",
            "Tap your Apple ID under “Developer App”, then tap Trust.",
            "Open SideStore from your Home Screen — you're done.",
        ],
        actionLabel: nil, actionURLString: nil)

    /// Shown only after a LiveContainer + SideStore install: LiveContainer needs
    /// SideStore's signing certificate, which you pull in from its settings.
    static let liveContainerImport = Guide(
        title: "Import the certificate into LiveContainer",
        systemImage: "arrow.down.doc",
        steps: [
            "Open LiveContainer from your Home Screen.",
            "Tap the Settings tab.",
            "Tap “Import Certificate From SideStore”.",
        ],
        actionLabel: nil, actionURLString: nil)
}

// MARK: - C logging callback

/// Bare C function pointer (no captures) — forwards Rust log lines to the
/// singleton engine on the main queue.
private let siLogCallback: SILogCallback = { _, msg in
    guard let msg = msg else { return }
    let text = String(cString: msg)
    DispatchQueue.main.async {
        Engine.shared.appendRustLine(text)
    }
}

/// Bare C function pointer — bridges isideload's 2FA request to the engine's
/// blocking prompt. Runs on a Rust worker thread.
private let twoFactorCallback: SITwoFactorCb = { _, outBuf, bufLen in
    guard let outBuf = outBuf else { return 0 }
    return Engine.shared.provideTwoFactorCode(outBuf, Int(bufLen))
}
