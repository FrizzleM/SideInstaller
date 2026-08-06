import Foundation
import SideInstallerFFI

/// One ordered step of the one-click install.
enum Step: Int, CaseIterable, Identifiable {
    case network, pair, connect, signIn, download, sign, install, writePairing

    var id: Int { rawValue }

    /// Checklist label for this step, naming the chosen build.
    func title(for source: InstallSource) -> String {
        switch self {
        case .network:      return L("Connect the VPN")
        case .pair:         return L("Pair with this iPhone")
        case .connect:      return L("Open the device link")
        case .signIn:       return L("Sign in to Apple ID")
        // An imported IPA is read off disk rather than downloaded.
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

/// A contextual instruction card shown to the user.
struct Guide: Equatable {
    var title: String
    var systemImage: String
    var steps: [String]
    var actionLabel: String?
    var actionURLString: String?

    var actionURL: URL? { actionURLString.flatMap(URL.init(string:)) }
}

/// A step failure carrying a user-facing message.
enum EngineError: LocalizedError {
    case message(String)
    /// Apple error 7460: a signing certificate already exists or is pending.
    case certExists
    /// Apple error 8220: the device UDID couldn't be registered with the team.
    case deviceRegistration(udid: String, raw: String)

    var errorDescription: String? {
        switch self {
        case let .message(m):
            return m
        case .certExists:
            return L("Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.")
        case let .deviceRegistration(udid, raw):
            let tail = udid.isEmpty ? "" : L(" (UDID %@)", udid)
            return L("Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.",
                     tail, raw)
        }
    }
}

/// All install logic. A singleton so the C log callback can reach it.
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
    /// Servers for the picker; a bundled snapshot until the live list loads.
    @Published private(set) var anisetteServers: [AnisetteServer] = AnisetteServer.bundledDefaults
    // The loopback VPN's device-side IP; configurable in Advanced.
    @Published var deviceIP: String = "10.7.0.1"
    // Which build to install (SideStore, or LiveContainer + SideStore).
    @Published var installSource: InstallSource = .sideStore
    // Which release track to pull that build from (stable or nightly).
    @Published var releaseChannel: ReleaseChannel = .stable

    // MARK: Plain-text status readouts

    /// Loopback-tunnel state, polled by `startStatusMonitor`.
    @Published var vpnConnected: Bool = false
    /// Wi-Fi (`en0`) state, polled alongside the tunnel.
    @Published var wifiConnected: Bool = false
    @Published var vpnStatus: String = "unknown"
    @Published var wifiStatus: String = "unknown"

    /// Lowest iOS the install pipeline supports.
    static let minimumOSMajorVersion = 27
    /// The same number as text, for UI copy.
    static var minimumOSText: String { "\(minimumOSMajorVersion)" }

    /// False when this iPhone is older than `minimumOSMajorVersion`.
    var osSupported: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: Engine.minimumOSMajorVersion,
                                   minorVersion: 0, patchVersion: 0))
    }

    /// This iPhone's iOS version, e.g. "18.5".
    var osVersionText: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)"
    }
    @Published var pairingStatus: String = L("not paired")
    @Published var signInStatus: String = "signed out"

    // Path to the pairing file produced by RPPairing.
    @Published var pairingFilePath: String?

    // MARK: One-click orchestration state

    /// Per-step status, behind the checklist and progress bar.
    @Published var stepStates: [Step: StepState] = Dictionary(
        uniqueKeysWithValues: Step.allCases.map { ($0, .pending) })

    /// Install percentage (0…1) streamed from installation_proxy.
    @Published var installProgress: Double = 0

    /// The pairing PIN to display prominently, when one has been issued.
    @Published var pairingPIN: String?

    /// Short human summary of the connected device, e.g. "iPhone · iOS 17.5".
    @Published var deviceSummary: String?

    /// The connected iPhone's UDID and name, from the lockdown handshake.
    private(set) var deviceUDID: String?
    private(set) var deviceName: String?

    /// The current contextual instruction card (nil = none).
    @Published var guide: Guide?

    /// True when signing stopped on error 7460; offers revoke-and-retry.
    @Published var certConflict: Bool = false

    /// True while the one-click pipeline is running.
    @Published var isRunning: Bool = false

    /// Set when the pipeline stops on an error; cleared on a new run.
    @Published var lastError: String?

    /// Set once the whole pipeline has completed successfully.
    @Published var finished: Bool = false

    private var pipelineTask: Task<Void, Never>?
    /// Poll that keeps `vpnConnected` live; NWPathMonitor never fires for a
    /// loopback tunnel, which carries no default route.
    private var statusTimer: Timer?

    /// True when the installed build is LiveContainer + SideStore.
    var installedIsLiveContainer: Bool {
        (downloadedSource ?? installSource) == .liveContainer
    }

    /// Name of the build that was installed, or is selected.
    var installedSourceName: String {
        let source = downloadedSource ?? installSource
        if source == .custom, let signed = signedDisplayName { return signed }
        return source.displayName
    }

    /// Home-screen name of the app that landed on the device.
    var installedAppName: String {
        (downloadedSource ?? installSource).pairingAppDisplayName
            ?? signedDisplayName
            ?? L("your app")
    }

    /// Overall fraction across all steps (0…1).
    var overallProgress: Double {
        let total = Double(Step.allCases.count)
        let done = Double(Step.allCases.filter { stepStates[$0] == .done }.count)
        let frac = (stepStates[.install] == .active || stepStates[.install] == .waiting)
            ? installProgress : 0
        return min(1, (done + frac) / total)
    }

    // Long-lived device link over the loopback tunnel, serialized on deviceQueue.
    let connection = DeviceConnection()
    private let deviceQueue = DispatchQueue(label: "sideinstaller.device")

    // Apple ID sign-in and signing (isideload), serialized on signQueue.
    private let signQueue = DispatchQueue(label: "sideinstaller.sign")
    private var signSession: OpaquePointer?          // SignSession*
    @Published var downloadedIPAPath: String?
    // Source and channel the current download corresponds to.
    private var downloadedSource: InstallSource?
    private var downloadedChannel: ReleaseChannel?
    @Published var signedAppPath: String?
    /// CFBundleDisplayName read off the signed bundle.
    @Published private(set) var signedDisplayName: String?
    /// Filename of the IPA imported for `InstallSource.custom`, if any.
    @Published private(set) var customIPAName: String?
    /// True while a picked IPA is being copied in.
    @Published private(set) var isImportingIPA = false

    // 2FA bridge: the FFI callback blocks on this semaphore until the UI answers.
    @Published var pendingTwoFactor = false
    private let twoFactorSem = DispatchSemaphore(value: 0)
    private var twoFactorResult: String?
    /// Set when the user cancels the 2FA prompt, so sign-in stops re-prompting.
    var twoFactorWasCancelled = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {
        installLogging()
        log("SideInstaller ready.")
        // Self-test of the Rust tracing -> FFI callback -> console path.
        ping()
        // Show the tunnel/Wi-Fi status on launch, then keep it live.
        checkVPNAndWifi()
        startStatusMonitor()
        // Refresh the anisette server picker from the live community list.
        loadAnisetteServers()
        // Reflect an IPA imported in an earlier run.
        customIPAName = IPALibrary.customImport()?.url.lastPathComponent
    }

    // MARK: - Anisette servers

    /// Swap the bundled anisette list for the live one, keeping it on failure.
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

    /// How many log lines to keep; the oldest are dropped first.
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
            self.certConflict = false
        }
    }

    /// Move whichever step is active or waiting into a terminal state.
    private func failActiveStep(to state: StepState) {
        setMain {
            for s in Step.allCases where self.stepStates[s] == .active || self.stepStates[s] == .waiting {
                self.stepStates[s] = state
            }
        }
    }

    // MARK: - One-click pipeline (the default flow)

    /// Run every install step in order, stopping at the first failure.
    @MainActor
    func runOneClick() {
        guard !isRunning else { return }
        // Nothing downstream works on an older iOS.
        guard osSupported else {
            log("⛔️ iOS \(osVersionText) isn't supported — SideInstaller needs iOS \(Engine.minimumOSText) or later.")
            return
        }
        guard !normalizedAppleID.isEmpty, !applePassword.isEmpty else {
            log("Enter your Apple ID email + password first.")
            return
        }
        // A custom install needs its IPA before anything else runs.
        if installSource == .custom, IPALibrary.customImport() == nil {
            setGuide(Guides.customIPA)
            log("⛔️ No IPA imported yet. Tap “Import .ipa” and pick one, then tap Install again.")
            return
        }
        // The install runs over the loopback tunnel, so require it up front.
        refreshNetworkStatus()
        guard !needsFreshPairing || wifiConnected else {
            setGuide(Guides.wifi)
            log("⛔️ Wi-Fi is off, and pairing this iPhone needs it. Connect to a Wi-Fi network, then tap Install again.")
            return
        }
        guard vpnConnected else {
            setGuide(Guides.vpn)
            log("⛔️ No loopback VPN is connected. Turn one on, then tap Install again.")
            return
        }
        // A tunnel pointed at this iPhone's own address can never connect.
        if NetworkStatus.isOwnAddress(deviceIP) {
            setGuide(Guides.deviceIPMismatch)
            log("⛔️ Device IP \(deviceIP) is an address this iPhone already holds — that's the tunnel's own end, not the one to connect to. Check Settings › Advanced › Device IP (the default is 10.7.0.1).")
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

    /// True when this run must pair from scratch, the one step needing Wi-Fi.
    var needsFreshPairing: Bool {
        !fileExistsNonEmpty(pairingFilePath ?? PairingController.pairingFilePath())
    }

    @MainActor
    private func ensureNetwork() async throws {
        setStep(.network, .active)
        // The blocker last logged, so each one is announced once.
        var announced: String?
        while true {
            try Task.checkCancellation()
            let (vpn, wifi, detail) = NetworkStatus.summarize(deviceIP: deviceIP)
            publishNetwork(vpn: vpn, wifi: wifi, vpnText: vpn ? "tunnel up" : "no tunnel")
            // Only a run that pairs needs Wi-Fi; the tunnel is always required.
            let wifiSatisfied = wifi || !needsFreshPairing
            if wifiSatisfied && vpn {
                log("Network OK: \(detail)")
                setStep(.network, .done)
                setGuide(nil)
                return
            }
            setStep(.network, .waiting)
            if !wifiSatisfied {
                // Wi-Fi is the prerequisite for pairing, so surface it first.
                if announced != "wifi" {
                    log("Waiting for Wi-Fi… pairing this iPhone needs it. Connect to a Wi-Fi network.")
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
            // A reused pairing file can be stale: pair fresh once, then retry.
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

    /// A connected device's summary line and identifiers.
    private struct ConnectedDevice {
        let summary: String
        let udid: String?
        let name: String?
    }

    private func performConnect(ip: String, pairingPath path: String) throws -> ConnectedDevice {
        // A missing or empty pairing file surfaces as a confusing Socket(ENOENT).
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

    /// The Apple ID as sent to Apple; a stray space breaks the SRP proof.
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

        // Anisette servers go down often, so try each one before giving up.
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
                // Stick with the server that worked.
                anisetteURL = ani
                signInStatus = "signed in (\(summary))"
                setStep(.signIn, .done)
                return
            } catch let error as EngineError {
                lastError = error.errorDescription ?? "sign-in failed"

                // A cancelled 2FA prompt isn't the server's fault.
                if twoFactorWasCancelled {
                    log("Two-factor verification cancelled — stopping.")
                    signInStatus = "signed out"
                    throw EngineError.message(L("Two-factor verification was cancelled."))
                }
                // Bad credentials fail everywhere, and retrying risks a lockout.
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

    /// One sign-in attempt against a specific anisette server.
    private func performSignIn(id: String, pw: String, ani: String, dir: String) throws -> String {
        log("Apple ID sign-in for \(Self.oneLine(id)) via anisette \(Self.oneLine(ani)) …")
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

    /// Squeeze a value onto one line, since the console renders one per entry.
    static func oneLine(_ value: String) -> String {
        value.split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Anisette addresses to try, the current pick first, de-duplicated.
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

    /// GrandSlam codes meaning the credentials themselves were rejected.
    private static let credentialErrorCodes = [
        "-20101",   // invalid username/password
        "-22406",   // "Enter the correct password for this Apple Account."
    ]

    /// What the user sees when Apple rejects the credentials.
    static var credentialErrorMessage: String {
        L("Incorrect Apple ID or password. Check your Apple Account email and password, then try again.")
    }

    /// Detect a credential failure, which no anisette server can fix.
    static func isCredentialError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        if credentialErrorCodes.contains(where: m.contains) { return true }
        // Wording fallbacks, covering both "Apple ID" and "Apple Account".
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
        // Keyed on source and channel, so changing either re-fetches.
        if let p = downloadedIPAPath, downloadedSource == src, downloadedChannel == channel,
           FileManager.default.fileExists(atPath: p) {
            log("\(channel.displayName) \(src.displayName) IPA already downloaded — skipping.")
            setStep(.download, .done)
            return
        }
        setStep(.download, .active)

        let onDisk = IPALibrary.entry(source: src, channel: channel)

        // A custom install has no fallback: the imported file is the input.
        if src == .custom {
            guard let imported = onDisk else {
                setGuide(Guides.customIPA)
                throw EngineError.message(L("No IPA imported yet. Tap “Import .ipa” and pick one."))
            }
            try adoptImported(imported, source: src, channel: channel)
            return
        }

        // An IPA the user placed in Documents is used as-is, never overwritten.
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
            // Offline or blocked: fall back to a copy an earlier run left behind.
            if let cached = onDisk {
                log("⚠️ Download failed (\(short(error))) — using \(cached.url.lastPathComponent) already in Documents instead.")
                adopt(cached.url, source: src, channel: channel)
                setStep(.download, .done)
                return
            }
            logImportHint(for: error, source: src, channel: channel)
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

    /// Take a user-supplied IPA as the download step's result, if it is one.
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
            // A new file invalidates whatever the previous run resolved.
            if downloadedSource == .custom { downloadedIPAPath = nil }
            setGuide(nil)
            log("Imported \(dest.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize(dest.path)), countStyle: .file))).")
        } catch IPALibrary.ImportError.notAnIPA {
            // The picker accepts any file, so a wrong pick is caught here. The
            // check runs on a staged copy, leaving any previous import intact.
            refreshCustomIPA()
            lastError = L("%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.",
                          url.lastPathComponent)
            log("⛔️ Import: \(lastError ?? "")")
        } catch {
            // Re-read from disk for what the button should now say.
            refreshCustomIPA()
            lastError = L("Couldn't import %@: %@", url.lastPathComponent, error.localizedDescription)
            log("⛔️ Import: \(lastError ?? "")")
        }
    }

    /// The blocking half of an import, on a background queue.
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

    /// Re-read the custom import from disk.
    @MainActor
    func refreshCustomIPA() {
        customIPAName = IPALibrary.customImport()?.url.lastPathComponent
    }

    /// Log the way past a failed download: rename a stray IPA, or fetch one
    /// elsewhere when the network is the obstacle.
    @MainActor
    private func logImportHint(for error: Error, source: InstallSource, channel: ReleaseChannel) {
        let wanted = source.fileName(channel)
        let strays = IPALibrary.unrecognized()
        if !strays.isEmpty {
            log("Found \(strays.joined(separator: ", ")) in Documents, but the name doesn't say which build it is. Rename it to \(wanted) and tap Install again.")
            return
        }
        guard (error as? SideStoreDownloader.DownloadError)?.manualSideloadHelps ?? true else { return }
        log("Can't reach GitHub? Download \(source.displayName) on another device or through a proxy, rename it to \(wanted), copy it into Files › On My iPhone › SideInstaller, then tap Install again.")
    }

    // MARK: Step 6 — sign the IPA

    @MainActor
    private func signApp() async throws {
        guard let session = signSession else { throw EngineError.message(L("Not signed in.")) }
        guard let ipa = downloadedIPAPath else { throw EngineError.message(L("No SideStore IPA downloaded.")) }
        // The signer registers this UDID with the team first, or Apple refuses
        // the provisioning profile with error 8220.
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
            // The first point at which an imported IPA says what it is.
            signedDisplayName = signedAppName()
            setStep(.sign, .done)
        } catch {
            // User-fixable failures get an explanatory card. A certificate that
            // already exists offers revoke-and-retry, never revoked automatically.
            if case EngineError.certExists = error {
                setGuide(Guides.certExists)
                certConflict = true
            }
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
            if Self.isCertExistsError(msg) { throw EngineError.certExists }
            // Carry the UDID so the guide can show it for manual entry.
            if Self.isDeviceRegistrationError(msg) {
                throw EngineError.deviceRegistration(udid: udid, raw: msg)
            }
            throw EngineError.message(L("Signing failed: %@", msg))
        }
    }

    /// Detect Apple error 7460 in a raw signing error, by code or wording.
    static func isCertExistsError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("7460")
            || m.contains("maximum number of certificates")
            || (m.contains("certificate") && (m.contains("maximum") || m.contains("limit")))
    }

    /// Detect a failed device registration, or the 8220 it leads to.
    static func isDeviceRegistrationError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("device registration failed")
            || m.contains("8220")
            || m.contains("no devices")
            || m.contains("has no devices")
    }

    /// Tell a device-limit rejection from other registration failures.
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
            // iOS tears down the tunnel while it sits idle through sign-in and
            // signing, and `isConnected` can't see that, so rebuild it here.
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
        // The installed build decides the host app and where the file lands.
        let source = downloadedSource ?? installSource
        do {
            try await onDeviceQueue { try self.performWritePairing(path: path, source: source) }
        } catch {
            // Only AltStore-family apps need this file, so an imported IPA
            // failing here doesn't fail the run.
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

        // Resolve the host app's bundle id from installation_proxy, by display
        // name then base id, falling back to the signed bundle's own id.
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
        // SideStore reads the file at its Documents root, LiveContainer deeper.
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
    // Wrappers around the same async core the one-click flow runs, logging
    // their own failures instead of raising a stopped step and guide.

    func checkVPNAndWifi() {
        let (vpn, wifi, detail) = NetworkStatus.summarize(deviceIP: deviceIP)
        publishNetwork(vpn: vpn, wifi: wifi,
                       vpnText: vpn ? "tunnel up" : "no tunnel (start a loopback VPN)")
        log("Network: \(detail)")
        log("VPN(loopback)=\(vpnStatus), Wi-Fi=\(wifiStatus). RSD target \(deviceIP):\(DeviceConnection.rsdPort).")
        if !vpn { log("⚠️ No tunnel on \(deviceIP)'s subnet — connect a loopback VPN (LocalDevVPN, ClashMi, …).") }
    }

    /// Poll the interface list so the readouts track the tunnel while the app is
    /// open. Runs in `.common` mode so it keeps firing during scrolling.
    private func startStatusMonitor() {
        statusTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshNetworkStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
    }

    /// One quiet re-scan of the tunnel and Wi-Fi state.
    func refreshNetworkStatus() {
        let (vpn, wifi, _) = NetworkStatus.summarize(deviceIP: deviceIP)
        publishNetwork(vpn: vpn, wifi: wifi,
                       vpnText: vpn ? "tunnel up" : "no tunnel (start a loopback VPN)")
    }

    /// Publish only what changed, so the poll doesn't redraw every view.
    private func publishNetwork(vpn: Bool, wifi: Bool, vpnText: String) {
        let wifiText = wifi ? "on" : "off"
        if vpnConnected != vpn { vpnConnected = vpn }
        if wifiConnected != wifi { wifiConnected = wifi }
        if vpnStatus != vpnText { vpnStatus = vpnText }
        if wifiStatus != wifiText { wifiStatus = wifiText }
    }

    /// Start the RPPairing host; it reports back through the shared engine.
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

    /// The signed app's home-screen name; an app carries only one of the two.
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
    // Standalone pairing-file management, independent of the one-click install:
    // the same RPPairing host produces the file, which is then written into a
    // chosen installed app over the tunnel via house_arrest/AFC.

    /// List the supported pairing-target apps installed on the device.
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

    /// Bring up the device link for a standalone pairing operation, always with
    /// a fresh tunnel: `isConnected` still reads true after iOS tears one down.
    @MainActor
    private func ensurePairingConnection() async throws {
        refreshNetworkStatus()
        // No Wi-Fi check: this all runs over the loopback tunnel.
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

    /// Write `path` into `bundleID`'s Documents, verifying the read-back.
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

    /// isideload's storage, kept out of the file-sharing-visible Documents.
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

/// Computed so the copy is translated when read, picking up a language change.
enum Guides {
    /// Shown only for a run that has to pair, the one step needing Wi-Fi.
    static var wifi: Guide {
        Guide(
            title: L("Connect to Wi-Fi"),
            systemImage: "wifi",
            steps: [
                L("Open Settings › Wi-Fi and join a network."),
                L("Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find."),
                L("Then come back here — this continues automatically."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    /// Shown when no tunnel is up. Any VPN app on the device subnet works.
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

    /// Shown when Device IP holds an address this iPhone already has, usually
    /// the tunnel's own end copied off the VPN app's status line.
    static var deviceIPMismatch: Guide {
        Guide(
            title: L("Wrong device IP"),
            systemImage: "arrow.triangle.branch",
            steps: [
                L("The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to."),
                L("Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end."),
                L("If you changed LocalDevVPN's addresses, put its Device IP here, and make sure its Tunnel IP and subnet mask cover it."),
            ],
            actionLabel: nil, actionURLString: nil)
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

    /// Shown when Apple refuses a certificate because one exists (error 7460).
    static var certExists: Guide {
        Guide(
            title: L("A signing certificate already exists"),
            systemImage: "exclamationmark.shield",
            steps: [
                L("Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending."),
                L("SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone."),
                L("Use “Revoke and retry” above, or open the Certificates tab, tap “Load certificates”, and revoke it there."),
                L("Revoking is permanent: every app already signed with that certificate stops launching, on every device."),
                L("Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    /// Shown when the UDID couldn't be registered with the developer team, with
    /// separate advice for a device-limit rejection.
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

    /// Shown after a LiveContainer install, which needs SideStore's certificate.
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

/// Forwards Rust log lines to the engine on the main queue.
private let siLogCallback: SILogCallback = { _, msg in
    guard let msg = msg else { return }
    let text = String(cString: msg)
    DispatchQueue.main.async {
        Engine.shared.appendRustLine(text)
    }
}

/// Bridges isideload's 2FA request to the engine's blocking prompt.
private let twoFactorCallback: SITwoFactorCb = { _, outBuf, bufLen in
    guard let outBuf = outBuf else { return 0 }
    return Engine.shared.provideTwoFactorCode(outBuf, Int(bufLen))
}
