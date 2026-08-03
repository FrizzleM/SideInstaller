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
        case .network:      return L("Connect the VPN")
        case .pair:         return L("Pair with this iPhone")
        case .connect:      return L("Open the device link")
        case .signIn:       return L("Sign in to Apple ID")
        // Nothing is fetched for an imported IPA — the row still runs, it just
        // reads the file off disk, so name it for what it actually does.
        case .download:     return source == .custom ? L("Use your imported IPA")
                                                     : L("Download %@", source.shortName)
        case .sign:         return L("Sign the app")
        case .install:      return L("Install %@", source.shortName)
        case .writePairing: return L("Finish setup")
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
    /// The connected device's UDID couldn't be registered with the developer
    /// team, so the provisioning profile can't be issued (Apple error 8220).
    /// Carries the UDID and the raw error so both the message and the guide can
    /// show the UDID for manual entry.
    case deviceRegistration(udid: String, raw: String)

    var errorDescription: String? {
        switch self {
        case let .message(m):
            return m
        case .certLimit:
            return L("Apple allows only 3 signing certificates per Apple ID and this one already has 3, so a new one can't be made. Open the Certificates tab, tap “Load certificates”, and revoke an old or expired one to free a slot — then tap Install again. See the steps above.")
        case let .deviceRegistration(udid, raw):
            let tail = udid.isEmpty ? "" : L(" (UDID %@)", udid)
            return L("Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.",
                     tail, raw)
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
    // LocalDevVPN's default device (target) IP, and the one other loopback VPN
    // apps follow; configurable in Advanced.
    @Published var deviceIP: String = "10.7.0.1"
    // Which build to install (plain SideStore vs LiveContainer + SideStore).
    @Published var installSource: InstallSource = .sideStore
    // Which release track that build is pulled from (stable tag vs nightly
    // pre-release). Independent of the source — both repos publish both.
    @Published var releaseChannel: ReleaseChannel = .stable

    // MARK: Plain-text status readouts

    /// Live loopback-tunnel state, polled (see `startStatusMonitor`) so the
    /// UI banner + the Install gate always reflect the current tunnel.
    @Published var vpnConnected: Bool = false
    /// Live Wi-Fi (`en0`) state, polled alongside `vpnConnected`. The tunnel runs
    /// over Wi-Fi, so Wi-Fi is the first precondition the Install gate checks —
    /// without it, the tunnel can't come up in the first place.
    @Published var wifiConnected: Bool = false
    @Published var vpnStatus: String = "unknown"
    @Published var wifiStatus: String = "unknown"

    /// Lowest iOS the install pipeline supports. The on-device pairing service
    /// and the loopback tunnel it drives only exist from this release on, so an
    /// older iPhone is gated off up front rather than failing mid-run.
    static let minimumOSMajorVersion = 27
    /// The same number as text, for interpolation into UI copy.
    static var minimumOSText: String { "\(minimumOSMajorVersion)" }

    /// False when this iPhone is older than `minimumOSMajorVersion`.
    var osSupported: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: Engine.minimumOSMajorVersion,
                                   minorVersion: 0, patchVersion: 0))
    }

    /// This iPhone's iOS version, e.g. "18.5" — named in the callout so the
    /// user can see what they're actually on.
    var osVersionText: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)"
    }
    @Published var pairingStatus: String = L("not paired")
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

    /// The connected iPhone's UDID + name, captured from the lockdown handshake
    /// during `connect`. The UDID is registered with the developer team before
    /// signing (Apple rejects the provisioning profile with error 8220 if the
    /// team has no devices), and is shown to the user if registration fails.
    private(set) var deviceUDID: String?
    private(set) var deviceName: String?

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
    /// (not NWPathMonitor) because the loopback tunnel is local-only with no
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
    /// download) — used so post-install copy names the right app. An imported
    /// IPA has no name but the one inside it, known once it's been signed.
    var installedSourceName: String {
        let source = downloadedSource ?? installSource
        if source == .custom, let signed = signedDisplayName { return signed }
        return source.displayName
    }

    /// Home-screen app name of what actually landed on the device — the app the
    /// user taps to open (LiveContainer, not "LiveContainer + SideStore"). Used
    /// for the trust card so it names the right icon to open. An imported IPA
    /// only reveals its name once signed, hence the fallback chain.
    var installedAppName: String {
        (downloadedSource ?? installSource).pairingAppDisplayName
            ?? signedDisplayName
            ?? L("your app")
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

    // Connection over the loopback tunnel (idevice FFI). Long-lived; reused
    // across device-info / list-apps / install. Serialized on deviceQueue.
    let connection = DeviceConnection()
    private let deviceQueue = DispatchQueue(label: "sideinstaller.device")

    // Apple ID sign-in / signing (isideload via FFI). Serialized on signQueue.
    private let signQueue = DispatchQueue(label: "sideinstaller.sign")
    private var signSession: OpaquePointer?          // SignSession*
    @Published var downloadedIPAPath: String?
    // Which source + channel the current download corresponds to (so changing
    // either forces a re-download rather than reusing the other build).
    private var downloadedSource: InstallSource?
    private var downloadedChannel: ReleaseChannel?
    @Published var signedAppPath: String?
    /// CFBundleDisplayName read off the signed bundle. The only way to learn
    /// what an imported IPA actually calls itself, so post-install copy and the
    /// pairing-file write can name it.
    @Published private(set) var signedDisplayName: String?
    /// Filename of the IPA imported for `InstallSource.custom`, or nil if none.
    /// Published so the import button can show what's loaded.
    @Published private(set) var customIPAName: String?
    /// True while a picked IPA is being copied in. The copy can be slow (iCloud
    /// Drive, a USB drive), so the button says so rather than looking dead.
    @Published private(set) var isImportingIPA = false

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
        // start the loopback VPN before running, then keep it live for the banner.
        checkVPNAndWifi()
        startStatusMonitor()
        // Refresh the anisette server picker from the live community list.
        loadAnisetteServers()
        // An import survives relaunches, so the button reflects it from the off.
        customIPAName = IPALibrary.customImport()?.url.lastPathComponent
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

    /// How many log lines to keep. The console is a debugging aid, not a record:
    /// rust tracing plus the install's per-percent callbacks run to thousands of
    /// entries in a session, every one of which is retained forever and
    /// invalidates every view observing the engine. The oldest go first, since
    /// what someone copies out for a bug report is always the recent end.
    private static let maxLogLines = 2000

    private func appendLine(_ message: String) {
        let stamp = dateFormatter.string(from: Date())
        let entry = LogEntry(stamp: stamp, text: message)
        if Thread.isMainThread {
            store(entry)
        } else {
            DispatchQueue.main.async { [weak self] in self?.store(entry) }
        }
    }

    private func store(_ entry: LogEntry) {
        lines.append(entry)
        if lines.count > Self.maxLogLines {
            lines.removeFirst(lines.count - Self.maxLogLines)
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
            self.deviceUDID = nil
            self.deviceName = nil
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
        // Hard gate: nothing downstream works on an older iOS, and unlike Wi-Fi
        // or the tunnel there's nothing the user can do about it here.
        guard osSupported else {
            log("⛔️ iOS \(osVersionText) isn't supported — SideInstaller needs iOS \(Engine.minimumOSText) or later.")
            return
        }
        guard !normalizedAppleID.isEmpty, !applePassword.isEmpty else {
            log("Enter your Apple ID email + password first.")
            return
        }
        // Custom installs nothing until there's something to install. Catch it
        // here rather than five steps in, after a sign-in the user can't undo.
        if installSource == .custom, IPALibrary.customImport() == nil {
            setGuide(Guides.customIPA)
            log("⛔️ No IPA imported yet. Tap “Import .ipa” and pick one, then tap Install again.")
            return
        }
        // Pre-flight gate: the entire install runs over the loopback
        // tunnel, which itself rides on Wi-Fi — so require Wi-Fi first, then the
        // tunnel, showing how instead of just failing. (ensureNetwork() below
        // still waits too, as a mid-run safety net in case either drops after
        // this check passes.)
        refreshNetworkStatus()
        guard wifiConnected else {
            setGuide(Guides.wifi)
            log("⛔️ Wi-Fi is off. Connect to a Wi-Fi network, then tap Install again.")
            return
        }
        guard vpnConnected else {
            setGuide(Guides.vpn)
            log("⛔️ No loopback VPN is connected. Turn one on, then tap Install again.")
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

    // MARK: Step 1 — network (waits for the loopback tunnel)

    @MainActor
    private func ensureNetwork() async throws {
        setStep(.network, .active)
        // Track which blocker we last logged so we announce each stage once, yet
        // still re-announce when the user clears one (Wi-Fi → tunnel) and the
        // next comes into view.
        var announced: String?
        while true {
            try Task.checkCancellation()
            let (vpn, wifi, detail) = NetworkStatus.summarize(deviceIP: deviceIP)
            publishNetwork(vpn: vpn, wifi: wifi, vpnText: vpn ? "tunnel up" : "no tunnel")
            if wifi && vpn {
                log("Network OK: \(detail)")
                setStep(.network, .done)
                setGuide(nil)
                return
            }
            setStep(.network, .waiting)
            if !wifi {
                // Wi-Fi is the prerequisite for the tunnel, so surface it first —
                // even if a stale tunnel interface still reads as up.
                if announced != "wifi" {
                    log("Waiting for Wi-Fi… connect to a Wi-Fi network.")
                    announced = "wifi"
                }
                setGuide(Guides.wifi)
            } else {
                if announced != "vpn" {
                    log("Waiting for the loopback tunnel… connect LocalDevVPN, ClashMi, or whichever VPN app you use.")
                    announced = "vpn"
                }
                setGuide(Guides.vpn)
            }
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
        let device = try await onDeviceQueue { try self.performConnect(ip: ip, pairingPath: path) }
        deviceSummary = device.summary
        deviceUDID = device.udid
        deviceName = device.name
        pairingStatus = L("connected")
        setStep(.connect, .done)
    }

    /// The connected device's summary line plus the identifiers needed to
    /// register it with the developer team before signing.
    private struct ConnectedDevice {
        let summary: String
        let udid: String?
        let name: String?
    }

    private func performConnect(ip: String, pairingPath path: String) throws -> ConnectedDevice {
        // Gate: never attempt a connect with a missing/zero-byte pairing file —
        // idevice maps the file-read error to a confusing Socket(ENOENT).
        let size = fileSize(path)
        guard FileManager.default.fileExists(atPath: path), size > 0 else {
            throw EngineError.message(L("Pairing didn't finish — no pairing file yet."))
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
        let name = dict["DeviceName"] ?? L("device")
        let summary: String
        if let version = dict["ProductVersion"] {
            summary = "\(name) · iOS \(version)"
        } else {
            summary = name
        }
        return ConnectedDevice(summary: summary,
                               udid: dict["UniqueDeviceID"],
                               name: dict["DeviceName"])
    }

    // MARK: Step 4 — Apple ID sign-in

    /// The Apple ID as it should be sent to Apple. iOS keyboards happily leave a
    /// trailing space behind autocomplete or a paste, and the field gives no
    /// visual hint that it's there — but the username is mixed into the SRP
    /// proof, so that invisible space comes back as a wrong-password error.
    /// (The password is deliberately *not* trimmed: spaces can be part of it.)
    var normalizedAppleID: String {
        appleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func signIn() async throws {
        if signSession != nil {
            log("Already signed in this session — skipping.")
            setStep(.signIn, .done)
            return
        }
        guard !normalizedAppleID.isEmpty, !applePassword.isEmpty else {
            throw EngineError.message(L("Enter your Apple ID email + password."))
        }
        setStep(.signIn, .active)

        // Anisette servers are flaky and go down often, so don't fail on the
        // first one — try the user's pick, then every other known server, and
        // only give up once they've all failed. (Apple ID errors that no server
        // could fix, like a wrong password or a cancelled 2FA prompt, stop the
        // loop early — see below.)
        let servers = anisetteCandidates()
        let id = normalizedAppleID, pw = applePassword, dir = storageDir
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
                    throw EngineError.message(L("Two-factor verification was cancelled."))
                }
                // A bad Apple ID / password fails the same way on every server,
                // and hammering Apple with repeated bad logins risks locking the
                // account — so stop instead of cycling through the whole list.
                if Self.isCredentialError(lastError) {
                    signInStatus = "sign-in failed"
                    log("Apple ID credentials rejected: \(lastError)")
                    throw EngineError.message(Self.credentialErrorMessage)
                }
                log("Anisette \(name) failed: \(lastError)")
                if idx < servers.count - 1 { log("Trying the next anisette server…") }
            }
        }

        signInStatus = "sign-in failed"
        let tried = servers.count == 1
            ? L("the anisette server")
            : L("all %d anisette servers", servers.count)
        throw EngineError.message(L("Apple ID sign-in failed on %@. Last error: %@", tried, lastError))
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

    /// GrandSlam status codes that mean the credentials themselves are the
    /// problem. Apple localises the accompanying message, so the numeric code is
    /// the only reliable signal — match on it first and treat the wording as a
    /// fallback for servers that don't echo the code.
    private static let credentialErrorCodes = [
        "-20101",   // invalid username/password
        "-22406",   // "Enter the correct password for this Apple Account."
    ]

    /// What the user sees when Apple rejects the credentials themselves. Apple's
    /// own wording arrives localised by *its* servers (so it can land in a
    /// language the user didn't pick) and is often just a bare GrandSlam code —
    /// that raw text goes to the log, and this replaces it on screen.
    static var credentialErrorMessage: String {
        L("Incorrect Apple ID or password. Check your Apple Account email and password, then try again.")
    }

    /// Detect a definitive Apple ID credential failure (vs. a flaky anisette
    /// server). Switching anisette servers can't fix these, so the sign-in loop
    /// stops on them instead of trying every server.
    static func isCredentialError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        if credentialErrorCodes.contains(where: m.contains) { return true }
        // Wording fallbacks. Apple now brands the account an "Apple Account"
        // rather than an "Apple ID", so both spellings have to be covered.
        return m.contains("apple id or password")
            || m.contains("apple account or password")
            || m.contains("password was incorrect")
            || m.contains("incorrect apple id")
            || m.contains("correct password")
            || (m.contains("password") && m.contains("incorrect"))
    }

    // MARK: Step 5 — download SideStore

    @MainActor
    private func download() async throws {
        let src = installSource
        let channel = releaseChannel
        // The cache is keyed on source *and* channel, so flipping either one
        // re-fetches instead of reusing the other build's IPA.
        if let p = downloadedIPAPath, downloadedSource == src, downloadedChannel == channel,
           FileManager.default.fileExists(atPath: p) {
            log("\(channel.displayName) \(src.displayName) IPA already downloaded — skipping.")
            setStep(.download, .done)
            return
        }
        setStep(.download, .active)

        let onDisk = IPALibrary.entry(source: src, channel: channel)

        // Custom has nothing to fall back on: the imported file is the whole
        // input, so a missing one is a dead end rather than a reason to fetch.
        if src == .custom {
            guard let imported = onDisk else {
                setGuide(Guides.customIPA)
                throw EngineError.message(L("No IPA imported yet. Tap “Import .ipa” and pick one."))
            }
            try adoptImported(imported, source: src, channel: channel)
            return
        }

        // An IPA the user put in Documents themselves is the whole reason that
        // folder is visible in Files: it's how you install where GitHub is
        // unreachable. Take it as given — don't go to the network behind it, and
        // don't overwrite it. Deleting it in Settings › Downloads is what opts
        // back into downloading.
        if let imported = onDisk, imported.isImported {
            try adoptImported(imported, source: src, channel: channel)
            return
        }

        log("Fetching \(channel.displayName.lowercased()) \(src.displayName) release…")
        do {
            let path = try await SideStoreDownloader.downloadLatest(source: src, channel: channel) { line in
                self.log(line)
            }
            adopt(URL(fileURLWithPath: path), source: src, channel: channel)
            log("\(src.displayName) IPA ready at \(path)")
            setStep(.download, .done)
        } catch {
            // Blocked or offline, but an earlier run already left a copy here:
            // installing that beats failing the whole pipeline over a network we
            // can't reach.
            if let cached = onDisk {
                log("⚠️ Download failed (\(short(error))) — using \(cached.url.lastPathComponent) already in Documents instead.")
                adopt(cached.url, source: src, channel: channel)
                setStep(.download, .done)
                return
            }
            logImportHint(source: src, channel: channel)
            throw error
        }
    }

    /// Point the rest of the pipeline at an IPA on disk, whatever its origin.
    @MainActor
    private func adopt(_ url: URL, source: InstallSource, channel: ReleaseChannel) {
        downloadedIPAPath = url.path
        downloadedSource = source
        downloadedChannel = channel
    }

    /// Take a user-supplied IPA as the download step's result, after checking
    /// it's actually an IPA — see `IPALibrary.looksLikeIPA` for why that's worth
    /// doing before the file reaches the signer.
    @MainActor
    private func adoptImported(_ entry: IPALibrary.Entry,
                               source: InstallSource,
                               channel: ReleaseChannel) throws {
        guard IPALibrary.looksLikeIPA(entry.url) else {
            throw EngineError.message(
                L("%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.",
                  entry.url.lastPathComponent))
        }
        adopt(entry.url, source: source, channel: channel)
        log("Using your own \(entry.url.lastPathComponent) — skipping the download.")
        setStep(.download, .done)
    }

    /// Copy a picked IPA in as the custom import, replacing any previous one.
    /// `url` comes from the document picker, so it needs security-scoped access
    /// while it's read.
    ///
    /// The copy runs off the main actor. The guide points people at iCloud Drive
    /// and USB drives, and a hundred-megabyte read from either takes seconds to
    /// minutes — long enough that doing it inline would freeze the UI and invite
    /// the watchdog to kill the app. `isImportingIPA` is what the button reads
    /// to show that it's working.
    @MainActor
    func importCustomIPA(from url: URL) async {
        guard !isImportingIPA else { return }
        isImportingIPA = true
        defer { isImportingIPA = false }
        lastError = nil
        log("Importing \(url.lastPathComponent) …")
        do {
            let dest = try await Self.copyImport(from: url)
            customIPAName = dest.lastPathComponent
            // A new file invalidates whatever the previous run resolved, or the
            // install would sign the IPA that was just replaced.
            if downloadedSource == .custom { downloadedIPAPath = nil }
            setGuide(nil)
            log("Imported \(dest.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize(dest.path)), countStyle: .file))).")
        } catch IPALibrary.ImportError.notAnIPA {
            // The picker accepts any file — iOS has no `.ipa` type to filter on
            // that every storage provider agrees with — so this is where a wrong
            // pick is caught. An IPA is a zip; anything that isn't one is either
            // the wrong file or a broken copy. A previous import is still there:
            // the check runs on a staged copy, before anything is replaced.
            refreshCustomIPA()
            lastError = L("%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.",
                          url.lastPathComponent)
            log("⛔️ Import: \(lastError ?? "")")
        } catch {
            // Re-read rather than assume: whatever failed, disk is the only
            // honest answer for what the button should now say.
            refreshCustomIPA()
            lastError = L("Couldn't import %@: %@", url.lastPathComponent, error.localizedDescription)
            log("⛔️ Import: \(lastError ?? "")")
        }
    }

    /// The blocking half of an import, on a background queue. Security-scoped
    /// access is taken and released around the copy itself — it's a per-process
    /// claim on the URL, not a per-thread one, so it holds for the copy wherever
    /// that runs.
    private static func copyImport(from url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do { cont.resume(returning: try IPALibrary.replaceCustomImport(with: url)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    /// Re-read the custom import from disk — on launch, and after the downloads
    /// screen deletes it.
    @MainActor
    func refreshCustomIPA() {
        customIPAName = IPALibrary.customImport()?.url.lastPathComponent
    }

    /// Spell out the way past a failed download: the Documents folder is visible
    /// in Files, so an IPA fetched anywhere else installs from there. Named
    /// misses get called out too — a misnamed import is indistinguishable, from
    /// the user's side, from one that was ignored for no reason.
    @MainActor
    private func logImportHint(source: InstallSource, channel: ReleaseChannel) {
        let strays = IPALibrary.unrecognized()
        if !strays.isEmpty {
            log("Found \(strays.joined(separator: ", ")) in Documents, but the name doesn't say which build it is.")
        }
        log("Can't reach GitHub? Download \(source.displayName) on another device or through a proxy, rename it to \(source.fileName(channel)), copy it into Files › On My iPhone › SideInstaller, then tap Install again.")
    }

    // MARK: Step 6 — sign the IPA

    @MainActor
    private func signApp() async throws {
        guard let session = signSession else { throw EngineError.message(L("Not signed in.")) }
        guard let ipa = downloadedIPAPath else { throw EngineError.message(L("No SideStore IPA downloaded.")) }
        // The signer registers this UDID with the developer team before asking
        // Apple for a provisioning profile — a fresh/free team has no devices, so
        // the profile download fails with error 8220 unless the device is added
        // first (the step Sideloadly/AltStore do transparently).
        let udid = deviceUDID ?? ""
        let name = deviceName ?? ""
        if udid.isEmpty {
            log("⚠️ No device UDID captured — run the Connect step first, or signing may fail with error 8220.")
        }
        setStep(.sign, .active)
        do {
            let path = try await onSignQueue {
                try self.performSign(session: session, ipa: ipa, udid: udid, deviceName: name)
            }
            signedAppPath = path
            // First point at which an imported IPA says what it is; everything
            // downstream that names the app reads this.
            signedDisplayName = signedAppName()
            setStep(.sign, .done)
        } catch {
            // Failures with a concrete, user-fixable cause get an explanatory
            // card alongside the stopped step.
            if case EngineError.certLimit = error { setGuide(Guides.certLimit) }
            if case let EngineError.deviceRegistration(udid, raw) = error {
                setGuide(Guides.deviceRegistration(udid: udid, raw: raw))
            }
            throw error
        }
    }

    private func performSign(session: OpaquePointer, ipa: String, udid: String, deviceName: String) throws -> String {
        log("Signing \(ipa) …")
        var signed: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_sign_ipa(session, ipa, udid, deviceName, &signed, &error)
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
            // Device-registration / "team has no devices" (8220) failures: carry
            // the UDID so the error and its guide can show it for manual entry.
            if Self.isDeviceRegistrationError(msg) {
                throw EngineError.deviceRegistration(udid: udid, raw: msg)
            }
            throw EngineError.message(L("Signing failed: %@", msg))
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

    /// Detect a device-registration failure: either our pre-sign registration
    /// step failed (Rust prefixes "device registration failed for UDID …"), or
    /// the profile download itself hit Apple error 8220 ("Your team has no
    /// devices …") because no device was registered.
    static func isDeviceRegistrationError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("device registration failed")
            || m.contains("8220")
            || m.contains("no devices")
            || m.contains("has no devices")
    }

    /// Distinguish a device *limit* rejection (free accounts can only register a
    /// limited number of devices per year, and can't remove old ones) from other
    /// registration failures — so the guide can give the right advice.
    static func isDeviceLimitError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("maximum number of devices")
            || (m.contains("device") && (m.contains("maximum") || m.contains("too many")
                || (m.contains("limit") && !m.contains("no devices"))))
    }

    // MARK: Step 7 — install over AFC + installation_proxy

    @MainActor
    private func install() async throws {
        guard let bundle = signedAppPath else { throw EngineError.message(L("No signed bundle to install.")) }
        setStep(.install, .active)
        installProgress = 0
        let ip = deviceIP
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        try await onDeviceQueue {
            // The RSD tunnel opened during Connect (step 3) has been held but
            // sitting idle ever since — through sign-in (2FA), the IPA download,
            // and signing, routinely 1–2 minutes. iOS tears down an idle tunnel,
            // which kills the in-process software TCP adapter, so the next
            // service connect fails "adapter closed" (NetworkUnreachable) even
            // though our handles are still non-null (`isConnected` can't see it).
            // Re-establish a fresh tunnel from the saved pairing file right
            // before pushing bytes: it's a cheap pair-verify (no PIN), and
            // DeviceConnection.connect() frees the stale adapter before swapping
            // in the new one. The upload keeps the link busy from here, so
            // install and the pairing-file write that follows stay on a live
            // tunnel.
            self.log("Refreshing device link before install (tunnel was idle during sign-in/download/sign) …")
            try self.connection.connect(deviceIP: ip, pairingFilePath: path)
            guard self.connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
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
        do {
            try await onDeviceQueue { try self.performWritePairing(path: path, source: source) }
        } catch {
            // For SideStore this file is the point of the whole run, so a failure
            // is a failure. An imported IPA might not be an AltStore-family app
            // at all — seeding it is a courtesy — and the app is already
            // installed by now, so don't fail the run over the courtesy.
            guard source == .custom else { throw error }
            log("⚠️ Couldn't seed the pairing file into \(installedAppName) (\(short(error))). It's installed and ready — only AltStore-family apps need that file.")
        }
        setStep(.writePairing, .done)
    }

    private func performWritePairing(path: String, source: InstallSource) throws {
        guard connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
        let size = fileSize(path)
        guard FileManager.default.fileExists(atPath: path), size > 0 else {
            throw EngineError.message(L("Pairing file missing — pairing must run first."))
        }

        // Resolve the *installed* host app's bundle id. installation_proxy is the
        // source of truth — match by display name (survives the bundle id rewrite
        // isideload performs), then by base bundle id; fall back to the signed
        // bundle's id only if the lookup is empty. For LiveContainer the host app
        // is LiveContainer (com.kdt.livecontainer.<teamID>), not SideStore.
        //
        // An imported IPA has no known name or id to look up, so it skips
        // straight to the signed bundle — which is what was just installed, and
        // therefore already the answer the lookup would return.
        let appName = source.pairingAppDisplayName ?? signedAppName() ?? source.displayName
        let bundleID: String
        if let displayName = source.pairingAppDisplayName,
           let base = source.pairingBundleIDBase,
           let found = try connection.resolveInstalledBundleID(displayName: displayName, bundleIDBase: base) {
            bundleID = found
        } else if let signed = signedAppBundleID() {
            bundleID = signed
            if source.pairingAppDisplayName != nil {
                log("\(appName) not found via installation_proxy; using signed bundle id \(signed).")
            }
        } else {
            throw EngineError.message(L("%@ isn't installed yet — install must run first.", source.displayName))
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
        setGuide(Guides.trust(appName: installedAppName))
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
        publishNetwork(vpn: vpn, wifi: wifi,
                       vpnText: vpn ? "tunnel up" : "no tunnel (start a loopback VPN)")
        log("Network: \(detail)")
        log("VPN(loopback)=\(vpnStatus), Wi-Fi=\(wifiStatus). RSD target \(deviceIP):\(DeviceConnection.rsdPort).")
        if !vpn { log("⚠️ No tunnel on \(deviceIP)'s subnet — connect a loopback VPN (LocalDevVPN, ClashMi, …).") }
    }

    /// Poll the interface list so `vpnConnected` (and the plain-text readouts)
    /// track the tunnel coming up / dropping while the app is open. Added to the
    /// run loop in `.common` mode so it keeps firing during scrolling.
    private func startStatusMonitor() {
        statusTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshNetworkStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
    }

    /// One quiet (non-logging) re-scan of the tunnel/Wi-Fi state. Used by the
    /// poll above and as the authoritative check inside the Install gate.
    func refreshNetworkStatus() {
        let (vpn, wifi, _) = NetworkStatus.summarize(deviceIP: deviceIP)
        publishNetwork(vpn: vpn, wifi: wifi,
                       vpnText: vpn ? "tunnel up" : "no tunnel (start a loopback VPN)")
    }

    /// Publish network state, but only what actually changed.
    ///
    /// `@Published` fires `objectWillChange` on every assignment, changed or
    /// not, and the engine is the app-wide `@EnvironmentObject` — so an
    /// unguarded write from a 2-second timer re-runs the body of every view
    /// observing it thirty times a minute, for as long as the app is open,
    /// whether or not anything moved.
    private func publishNetwork(vpn: Bool, wifi: Bool, vpnText: String) {
        let wifiText = wifi ? "on" : "off"
        if vpnConnected != vpn { vpnConnected = vpn }
        if wifiConnected != wifi { wifiConnected = wifi }
        if vpnStatus != vpnText { vpnStatus = vpnText }
        if wifiStatus != wifiText { wifiStatus = wifiText }
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
        signedAppPlist()?["CFBundleIdentifier"] as? String
    }

    /// The signed app's home-screen name. `CFBundleName` is the fallback — an
    /// app is only required to carry one of the two.
    private func signedAppName() -> String? {
        guard let plist = signedAppPlist() else { return nil }
        return (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String)
    }

    private func signedAppPlist() -> [String: Any]? {
        guard let app = signedAppPath else { return nil }
        let plistPath = (app as NSString).appendingPathComponent("Info.plist")
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist
    }

    // MARK: - Pairing tab
    //
    // Standalone pairing-file management (the "Pairing" tab), independent of the
    // one-click install. Mirrors iLoader's "Manage Pairing files": the file is
    // produced by the same RPPairing host the install uses (PairingController),
    // then written into a chosen installed app the same way SideStore receives
    // it — over the loopback tunnel via house_arrest/AFC.

    /// List the supported pairing-target apps actually installed on the device.
    /// Brings the device link up first (using the saved pairing file) if needed.
    @MainActor
    func installedPairingTargets() async throws -> [InstalledPairingTarget] {
        try await ensurePairingConnection()
        let apps = try await onDeviceQueue { try self.connection.installedApps() }
        let targets = PairingTargets.match(installed: apps)
        log("Pairing: \(targets.count) supported app(s) installed\(targets.isEmpty ? "." : ": \(targets.map(\.name).joined(separator: ", "))")")
        return targets
    }

    /// Write the current pairing file into one installed target app's container.
    @MainActor
    func installPairing(into target: InstalledPairingTarget) async throws {
        try await ensurePairingConnection()
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        let bundleID = target.bundleID
        let rel = target.remoteRelativePath
        try await onDeviceQueue {
            try self.performInstallPairing(bundleID: bundleID, remoteRelativePath: rel, path: path)
        }
    }

    /// Bring up the device link for a standalone pairing operation: reuse an
    /// existing connection, else connect with the saved pairing file. Unlike the
    /// install pipeline's `connect()`, this touches no step states.
    @MainActor
    private func ensurePairingConnection() async throws {
        if connection.isConnected { return }
        refreshNetworkStatus()
        guard wifiConnected else {
            throw EngineError.message(L("Wi-Fi is off. Connect to a Wi-Fi network, then try again."))
        }
        guard vpnConnected else {
            throw EngineError.message(L("No loopback VPN is connected. Turn one on, then try again."))
        }
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        guard fileExistsNonEmpty(path) else {
            throw EngineError.message(L("No pairing file yet — tap “Generate pairing file” first."))
        }
        pairingFilePath = path
        let ip = deviceIP
        let device = try await onDeviceQueue { try self.performConnect(ip: ip, pairingPath: path) }
        deviceSummary = device.summary
        deviceUDID = device.udid
        deviceName = device.name
        pairingStatus = L("connected")
    }

    /// Write `path` into `bundleID`'s Documents at `remoteRelativePath`, verifying
    /// the read-back (the bundle-id-based sibling of `performWritePairing`, which
    /// resolves the id from an `InstallSource`).
    private func performInstallPairing(bundleID: String, remoteRelativePath: String, path: String) throws {
        guard connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
        let size = fileSize(path)
        guard FileManager.default.fileExists(atPath: path), size > 0 else {
            throw EngineError.message(L("Pairing file missing — generate it first."))
        }
        log("Writing pairing file into \(bundleID) /Documents/\(remoteRelativePath) …")
        let written = try connection.writePairingFile(intoBundleID: bundleID,
                                                       remoteRelativePath: remoteRelativePath,
                                                       pairingFilePath: path)
        log("Pairing file written into \(bundleID) and read-back VERIFIED (\(written) bytes).")
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

    /// isideload's storage — the anisette machine provisioning and the developer
    /// signing certificate. Deliberately not in Documents, which file sharing
    /// exposes; `PrivateStore` explains the move and handles the migration.
    private var storageDir: String {
        PrivateStore.isideload.path
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

/// Every card is a computed `var`, not a stored `let`: the copy is translated at
/// the moment it's read, so a language change picks up on the next redraw.
enum Guides {
    static var wifi: Guide {
        Guide(
            title: L("Connect to Wi-Fi"),
            systemImage: "wifi",
            steps: [
                L("Open Settings › Wi-Fi and join a network."),
                L("The loopback tunnel — and the whole install — run over Wi-Fi."),
                L("Then come back here — this continues automatically."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    /// Any VPN app that puts this iPhone on the device subnet works — the check
    /// behind this card tests the subnet, not the app. Worth spelling out,
    /// because the choice decides whether the SideStore download can succeed:
    /// iOS runs one VPN at a time, so a local-only tunnel like LocalDevVPN
    /// leaves nothing to reach a blocked GitHub through, while a proxying client
    /// that also exposes the loopback covers both jobs at once.
    static var vpn: Guide {
        Guide(
            title: L("Turn on a loopback VPN"),
            systemImage: "network",
            steps: [
                L("Open a VPN app that tunnels to this iPhone — LocalDevVPN, ClashMi, or another. Any of them works."),
                L("If GitHub is blocked where you are, pick one that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through."),
                L("Tap Connect so the toggle turns on."),
                L("Keep Wi-Fi on, then come back here — this continues automatically."),
            ],
            actionLabel: L("Get LocalDevVPN"),
            actionURLString: "https://apps.apple.com/app/id6755608044")
    }

    /// Shown when Custom .ipa is selected but nothing has been imported yet.
    static var customIPA: Guide {
        Guide(
            title: L("Import an .ipa first"),
            systemImage: "square.and.arrow.down.on.square",
            steps: [
                L("Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive."),
                L("Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it."),
                L("This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    static var pairing: Guide {
        Guide(
            title: L("Pair this iPhone in Settings"),
            systemImage: "lock.iphone",
            steps: [
                L("Open the Settings app, then go to Privacy & Security › Developer Mode."),
                L("Tap “Pair with SideInstaller”."),
                L("Enter your iPhone’s passcode if it asks for it."),
                L("Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    static var certLimit: Guide {
        Guide(
            title: L("Too many signing certificates"),
            systemImage: "exclamationmark.shield",
            steps: [
                L("Apple allows only 3 signing certificates per Apple ID, and this one already has 3 — usually left over from setting up AltStore / SideStore on other devices."),
                L("Open the Certificates tab at the bottom of the screen, make sure your Apple ID is filled in, and tap “Load certificates”."),
                L("Tap “Revoke” on an old or expired certificate to free up a slot. Revoking stops apps already signed with that certificate from launching on other devices, so pick one you no longer use."),
                L("Come back to the Install tab and tap Install again."),
                L("Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    /// Shown when the device UDID couldn't be registered with the developer
    /// team before signing (Apple error 8220 / a registration rejection). The
    /// UDID is included as its own step so it's easy to copy. The advice adapts
    /// to a device-*limit* rejection, which a free account can't clear by
    /// deleting devices (they don't reset until the membership year rolls over).
    static func deviceRegistration(udid: String, raw: String) -> Guide {
        var steps: [String] = []
        if Engine.isDeviceLimitError(raw) {
            steps.append(L("Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets."))
            steps.append(L("Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again."))
        } else {
            steps.append(L("SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable."))
        }
        if !udid.isEmpty {
            steps.append(L("If it keeps failing, add the device by hand. Its UDID is:"))
            steps.append(udid)
            steps.append(L("Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again."))
        }
        return Guide(
            title: L("Couldn't register this device"),
            systemImage: "iphone.badge.exclamationmark",
            steps: steps,
            actionLabel: udid.isEmpty ? nil : L("Open device list"),
            actionURLString: udid.isEmpty ? nil : "https://developer.apple.com/account/resources/devices/list")
    }

    static func trust(appName: String) -> Guide {
        Guide(
            title: L("Last step: trust %@", appName),
            systemImage: "checkmark.seal",
            steps: [
                L("Open Settings › General › VPN & Device Management."),
                L("Tap your Apple ID under “Developer App”, then tap Trust."),
                L("Open %@ from your Home Screen — you're done.", appName),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    /// Shown only after a LiveContainer + SideStore install: LiveContainer needs
    /// SideStore's signing certificate, which you pull in from its settings.
    static var liveContainerImport: Guide {
        Guide(
            title: L("Import the certificate into LiveContainer"),
            systemImage: "arrow.down.doc",
            steps: [
                L("Open LiveContainer from your Home Screen."),
                L("Tap the Settings tab."),
                L("Tap “Import Certificate From SideStore”."),
            ],
            actionLabel: nil, actionURLString: nil)
    }
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
