import Foundation
import UIKit
import SideInstallerFFI

/// One ordered step of the one-click install.
enum Step: Int, CaseIterable, Identifiable {
    case network, pair, connect, signIn, download, sign, install, writePairing

    var id: Int { rawValue }

    /// Checklist label for this step, naming the chosen build.
    func title(for source: InstallSource) -> String {
        switch self {
        case .network:      return L("Connect the VPN")
        case .pair:         return L("Get pairing file")
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

    /// The credentials in use, owned by `AccountStore` rather than typed on each
    /// screen: they are entered once during setup and switched in Settings ›
    /// Account. Views observe the store, so these need no `@Published`.
    var appleID: String { AccountStore.shared.activeAppleID }
    var applePassword: String { AccountStore.shared.activePassword }
    @Published var anisetteURL: String = AnisetteServer.fallback.address
    /// Servers for the picker; a bundled snapshot until the live list loads.
    @Published private(set) var anisetteServers: [AnisetteServer] = AnisetteServer.bundledDefaults
    /// "Start LocalDevVPN when SideInstaller opens". On unless it has been
    /// turned off: every page here needs the tunnel, so opening the app without
    /// one is never what somebody meant. Persisted here rather than with
    /// `@AppStorage`, so the launch hook and the Settings toggle read the one
    /// value.
    @Published var autoStartVPN: Bool =
        (UserDefaults.standard.object(forKey: Engine.autoStartVPNKey) as? Bool) ?? true {
        didSet {
            guard autoStartVPN != oldValue else { return }
            UserDefaults.standard.set(autoStartVPN, forKey: Engine.autoStartVPNKey)
            log(autoStartVPN
                ? "LocalDevVPN will be started when SideInstaller opens."
                : "LocalDevVPN will no longer be started when SideInstaller opens.")
        }
    }

    static let autoStartVPNKey = "autoStartLocalDevVPN"

    // The loopback VPN's device-side IP; configurable in Advanced.
    @Published var deviceIP: String = "10.7.0.1"
    /// `deviceIP` as an address to dial, kept apart from the field's own text so
    /// that a pasted `10.7.0.1/32` — which is how LocalDevVPN prints it now —
    /// still resolves instead of failing in `inet_pton` several layers down.
    var deviceHost: String { NetworkStatus.host(deviceIP) }
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

    /// Lowest iOS that can produce its own pairing file: the RPPairing host and
    /// the Settings prompt that answers it are iOS 27 features.
    static let minimumOSMajorVersion = 27
    /// The same number as text, for UI copy.
    static var minimumOSText: String { "\(minimumOSMajorVersion)" }

    /// Lowest iOS the rest of the pipeline works on. Everything after pairing
    /// runs over an RSD tunnel, which needs CoreDeviceProxy — iOS 17 and later —
    /// and this build's interface needs 18.
    static let minimumTunnelOSMajorVersion = 18
    static var minimumTunnelOSText: String { "\(minimumTunnelOSMajorVersion)" }

    /// True when this iPhone can pair with itself, so no pairing file has to be
    /// brought in from a computer. Static as well, for the non-isolated callers
    /// that pick a tunnel route.
    static var deviceCanSelfPair: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: minimumOSMajorVersion,
                                   minorVersion: 0, patchVersion: 0))
    }

    var canSelfPair: Bool { Engine.deviceCanSelfPair }

    /// False when this iPhone is too old for the tunnel the install runs over,
    /// where an imported pairing file wouldn't help either.
    var osSupported: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: Engine.minimumTunnelOSMajorVersion,
                                   minorVersion: 0, patchVersion: 0))
    }

    /// True when there's a pairing file on disk to connect with.
    var hasPairingFile: Bool {
        fileExistsNonEmpty(pairingFilePath ?? PairingController.pairingFilePath())
    }

    /// This iPhone's iOS version, e.g. "18.5".
    var osVersionText: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)"
    }

    /// Filename of the pairing file the user imported, when the one on disk came
    /// in that way. Persisted, so it survives a relaunch like the file does.
    @Published private(set) var importedPairingName: String? =
        UserDefaults.standard.string(forKey: Engine.importedPairingNameKey)
    /// True while a picked pairing file is being read in.
    @Published private(set) var isImportingPairing = false

    static let importedPairingNameKey = "importedPairingFileName"
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

    /// True once the Local Network prompt has been raised this launch, so the
    /// imported-pairing path asks at most once.
    private var askedLocalNetwork = false

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
    /// The team the signer is working under, read off the sign-in summary. An
    /// app has to already be signed under this team for a refresh to land on it
    /// rather than install a second copy beside it.
    @Published private(set) var signingTeamID: String?
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
    /// How much of a link import has arrived (0…1). Nil for a file import,
    /// where the copy reports nothing to show.
    @Published private(set) var importProgress: Double?

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
            log("⛔️ iOS \(osVersionText) isn't supported — SideInstaller needs iOS \(Engine.minimumTunnelOSText) or later.")
            return
        }
        // Below iOS 27 this iPhone can't pair with itself, so the run needs a
        // pairing file made elsewhere and imported.
        guard canSelfPair || hasPairingFile else {
            setGuide(Guides.importPairing)
            log("⛔️ iOS \(osVersionText) can't create its own pairing file. Import one under “Pairing file”, then tap Install again.")
            return
        }
        guard !normalizedAppleID.isEmpty, !applePassword.isEmpty else {
            setGuide(Guides.account)
            log("⛔️ No Apple ID saved. Add one in Settings › Account, then tap Install again.")
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
        if NetworkStatus.isOwnAddress(deviceHost) {
            setGuide(Guides.deviceIPMismatch)
            log("⛔️ Device IP \(deviceHost) is an address this iPhone already holds — that's the tunnel's own end, not the one to connect to. Check Settings › Advanced › Device IP (the default is 10.7.0.1).")
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
            let (vpn, wifi, detail) = NetworkStatus.summarize(deviceIP: deviceHost)
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
            log(importedPairingName == nil
                ? "Found an existing pairing file — trying it first."
                : "Using the pairing file you imported (\(importedPairingName ?? "")).")
            pairingFilePath = path
            setStep(.pair, .done)
        } else {
            try await pair()
        }

        await ensureLocalNetworkForImportedPairing()

        do {
            try await connect()
        } catch {
            // A reused pairing file can be stale: pair fresh once, then retry.
            // Only iOS 27 can, though — below it there's nothing to fall back on
            // but the user importing a fresh file.
            guard reused, canSelfPair else { throw error }
            // A route that never reached the device says nothing about the
            // pairing file, and re-pairing it costs the user a PIN to fail the
            // same way a second time.
            if let tunnel = error as? DeviceConnection.TunnelError,
               !tunnel.repairingCouldHelp {
                throw error
            }
            log("Saved pairing didn't work (\(short(error))). Pairing fresh…")
            try await pair()
            try await connect()
        }
    }

    @MainActor
    private func pair() async throws {
        guard canSelfPair else {
            setGuide(Guides.importPairing)
            throw EngineError.message(
                L("iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.",
                  osVersionText, Engine.minimumOSText))
        }
        setStep(.pair, .waiting)
        setGuide(Guides.pairing)
        log("Pairing: starting on-device pairing service…")
        let path = try await PairingController.shared.startAndWait()
        pairingFilePath = path
        pairingPIN = nil
        setStep(.pair, .done)
        setGuide(nil)
    }

    /// Raise the Local Network prompt on the imported-pairing-file path.
    ///
    /// Reaching lockdownd at the tunnel's far end counts as a local-network
    /// connection, and iOS refuses it silently until the permission is granted.
    /// On iOS 27 the RPPairing host asks for it as a matter of course; below 27
    /// nothing does, so a first run would fail with an unexplained socket error.
    /// Best-effort: a denial still lets the connection attempt speak for itself.
    @MainActor
    private func ensureLocalNetworkForImportedPairing() async {
        guard !canSelfPair, !askedLocalNetwork else { return }
        askedLocalNetwork = true
        log("Checking Local Network permission — the device link needs it…")
        // Held only for the call; the browser and listener die with it.
        let localNetwork = LocalNetworkAuthorization()
        if await localNetwork.request(timeout: 8) {
            log("Local Network OK.")
        } else {
            log("⚠️ Local Network didn't confirm. If the link won't open, turn it on in Settings › SideInstaller › Local Network.")
        }
    }

    @MainActor
    private func connect() async throws {
        setStep(.connect, .active)
        setGuide(nil)
        let ip = deviceHost
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

    /// Drop the cached sign-in, so the next run authenticates as whichever
    /// account is active now. Called when the credentials change under it.
    /// Freed on `signQueue`, the only queue that touches `signSession`.
    func forgetAppleSession() {
        signQueue.async { [weak self] in
            guard let self, let session = self.signSession else { return }
            si_sign_session_free(session)
            self.signSession = nil
            self.setMain {
                self.signInStatus = "signed out"
                self.signingTeamID = nil
            }
            self.log("Apple ID changed — signed out of the previous account.")
        }
    }

    /// `updatingChecklist` is false for the refresh flow on the Sideloaded apps
    /// page, which reuses this sign-in but has no business moving the Install
    /// tab's checklist — a failure there would leave that step spinning forever.
    @MainActor
    private func signIn(updatingChecklist: Bool = true) async throws {
        if signSession != nil {
            log("Already signed in this session — skipping.")
            if updatingChecklist { setStep(.signIn, .done) }
            return
        }
        guard !normalizedAppleID.isEmpty, !applePassword.isEmpty else {
            throw EngineError.message(L("No Apple ID saved. Add one in Settings › Account."))
        }
        if updatingChecklist { setStep(.signIn, .active) }

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
                if updatingChecklist { setStep(.signIn, .done) }
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
            let team = Self.teamID(inSummary: s)
            setMain { self.signingTeamID = team }
            log("Sign-in OK. \(s)")
            return s
        } else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message(msg)
        }
    }

    /// The team id out of a sign-in summary, which reads "team: Name (ABCDE12345)".
    /// Nil rather than a guess when it doesn't: the refresh flow only uses this
    /// to *skip* apps, so an unreadable summary must not exclude anything.
    static func teamID(inSummary summary: String) -> String? {
        guard let open = summary.lastIndex(of: "("),
              let close = summary.lastIndex(of: ")"), open < close else { return nil }
        let id = summary[summary.index(after: open)..<close]
        guard id.count == 10, id.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return String(id)
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
        // The picker copies the file into this app's Inbox before handing it
        // over; once it's imported, that copy is dead weight.
        defer { isImportingIPA = false; Self.discardInboxCopy(url) }
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

    /// Fetch an IPA from a link the user pasted and adopt it as the custom
    /// import. The way in for a build that isn't on GitHub, and the one that
    /// needs no second device to download it on.
    @MainActor
    func importCustomIPA(fromLink text: String) async {
        guard !isImportingIPA else { return }
        guard let url = Self.downloadLink(text) else {
            lastError = L("That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.")
            log("⛔️ Import: \(lastError ?? "")")
            return
        }
        isImportingIPA = true
        importProgress = 0
        defer { isImportingIPA = false; importProgress = nil }
        lastError = nil
        log("Downloading \(url.absoluteString) …")
        do {
            let downloaded = try await SideStoreDownloader.fetchDirect(
                url, named: Self.importFileName(for: url)) { fraction in
                    Task { @MainActor in self.importProgress = fraction }
                }
            // Its own staging directory, so removing it takes the file too.
            defer { try? FileManager.default.removeItem(at: downloaded.deletingLastPathComponent()) }
            let dest = try await Self.copyImport(from: downloaded)
            customIPAName = dest.lastPathComponent
            // A new file invalidates whatever the previous run resolved.
            if downloadedSource == .custom { downloadedIPAPath = nil }
            setGuide(nil)
            log("Imported \(dest.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize(dest.path)), countStyle: .file))).")
        } catch IPALibrary.ImportError.notAnIPA {
            refreshCustomIPA()
            lastError = L("That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.")
            log("⛔️ Import: \(lastError ?? "")")
        } catch is CancellationError {
            refreshCustomIPA()
            log("Import cancelled.")
        } catch {
            refreshCustomIPA()
            lastError = L("Couldn't download that link: %@", short(error))
            log("⛔️ Import: \(lastError ?? "")")
        }
    }

    /// A pasted address, tidied into something downloadable: whitespace off, and
    /// a missing scheme filled in, since an address copied out of a message
    /// often arrives bare. Anything that isn't http(s) is refused rather than
    /// repaired — a `file://` or an app scheme is a different mistake.
    static func downloadLink(_ text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        let hadScheme = lowered.hasPrefix("http://") || lowered.hasPrefix("https://")
        if !hadScheme {
            guard !trimmed.contains("://") else { return nil }
            trimmed = "https://" + trimmed
        }
        guard let url = URL(string: trimmed), let host = url.host, !host.isEmpty else { return nil }
        // A dot is what separates a hostname from a sentence, but only worth
        // insisting on where the scheme was inferred: `http://nas/App.ipa` is a
        // deliberate address, and typing one is saying so.
        guard hadScheme || (host.contains(".") && !host.hasPrefix(".") && !host.hasSuffix("."))
        else { return nil }
        return url
    }

    /// What to call what a link points at. Its own last path component when that
    /// names a file, and the host otherwise — a link ending in `/download` still
    /// has to land somewhere with a name on it.
    static func importFileName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
        let name = base.isEmpty ? (url.host ?? "Custom") : base
        return name + ".ipa"
    }

    /// Delete a copy the picker left in this app's own temporary directory.
    /// Guarded on the path, so a file picked where it lives — or one handed
    /// over in place from the share sheet — is never touched.
    private static func discardInboxCopy(_ url: URL) {
        let tmp = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path
        guard url.resolvingSymlinksInPath().path.hasPrefix(tmp + "/") else { return }
        try? FileManager.default.removeItem(at: url)
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
        let ip = deviceHost
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
        // Built here, on the sign queue every other isideload call is
        // serialized on, rather than inside the device-queue write below.
        let accountConfig = await accountConfigJSON(source: source)
        let udid = deviceUDID
        do {
            try await onDeviceQueue {
                try self.performWritePairing(path: path, udid: udid,
                                             source: source, accountConfig: accountConfig)
            }
        } catch {
            // Only AltStore-family apps need this file, so an imported IPA
            // failing here doesn't fail the run.
            guard source == .custom else { throw error }
            log("⚠️ Couldn't seed the pairing file into \(installedAppName) (\(short(error))). It's installed and ready — only AltStore-family apps need that file.")
        }
        setStep(.writePairing, .done)
    }

    private func performWritePairing(path: String, udid: String?,
                                     source: InstallSource, accountConfig: String?) throws {
        guard connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
        let size = fileSize(path)
        guard FileManager.default.fileExists(atPath: path), size > 0 else {
            throw EngineError.message(L("Pairing file missing — pairing must run first."))
        }
        // AltStore-family apps can't read the RPPairing record on its own.
        let placement = placementPairingFile(rpPairingPath: path, udid: udid)

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
                                                       pairingFilePath: placement)
        log("Pairing file written into \(appName) and read-back VERIFIED (\(written) bytes).")

        // Hand SideStore the certificate it was signed with, so its first
        // sign-in doesn't revoke ours, mint its own, and put up "Resign
        // SideStore". Never fails the run: the install is complete either way.
        if let accountConfig, let remoteRel = accountConfigRemoteRelativePath(source: source) {
            do {
                let handed = try connection.writeFile(intoBundleID: bundleID,
                                                      remoteRelativePath: remoteRel,
                                                      data: Data(accountConfig.utf8))
                log("Certificate handed to \(appName): /Documents/\(remoteRel) written and read-back VERIFIED (\(handed) bytes). SideStore imports and deletes it on first launch.")
            } catch {
                log("⚠️ Couldn't hand \(appName) the signing certificate (\(short(error))). It's installed and ready, but it will ask to resign itself on first sign-in.")
            }
        }
    }

    /// The `Account.sideconf` payload for this install, or nil when there's
    /// nothing to hand over. Never throws — a failure here costs the automatic
    /// hand-off, not the install.
    @MainActor
    private func accountConfigJSON(source: InstallSource) async -> String? {
        guard accountConfigRemoteRelativePath(source: source) != nil else { return nil }
        guard let session = signSession else {
            log("No Apple ID session to build the account config from — skipping the certificate hand-off.")
            return nil
        }
        do {
            return try await onSignQueue { () -> String? in
                guard self.importsAccountConfigSilently() else {
                    self.log("This SideStore build asks for a file password before importing Account.sideconf, "
                             + "and re-asks on every launch until one decrypts — so nothing is handed over, "
                             + "the same as iLoader. It will offer to resign itself on first sign-in instead.")
                    return nil
                }
                return try self.buildAccountConfig(session: session)
            }
        } catch {
            log("⚠️ Couldn't build the certificate hand-off (\(short(error))). SideStore will ask to resign itself on first sign-in.")
            return nil
        }
    }

    /// Marker for SideStore's password-prompting account importer: the
    /// `UserDefaults.acctFileChecksum` key added in the same change, present in
    /// the binary as both a `#function` literal and an `@objc` accessor name.
    private static let promptingImporterMarker = Data("acctFileChecksum".utf8)

    /// Whether the SideStore build being installed imports `Account.sideconf`
    /// without asking anything.
    ///
    /// Builds up to 2026-08 read the file, adopt the certificate and delete it
    /// on first launch. From `ImportAccountAlertController` (2026-08-10) on,
    /// `detectAndImportAccountFile` instead puts up an "Import Account" alert
    /// asking for a file password, only accepts the AES-GCM format
    /// `ImportExport.exportAccount` writes, and never deletes the file — and it
    /// records the file's checksum only once a decryption succeeds. Our
    /// plaintext JSON can never decrypt, so handing it to such a build means
    /// that alert on *every* launch, forever. iLoader never writes the file at
    /// all, which is why it never shows the alert; when we can't hand over
    /// silently we don't hand over either.
    ///
    /// Read off the binary rather than the version, because the two don't track
    /// each other: LiveContainer's stable IPA bundles SideStore
    /// 0.6.4-20260714, which still imports silently, while its nightly bundles
    /// 0.6.4-20260816, which doesn't.
    private func importsAccountConfigSilently() -> Bool {
        guard let exec = sideStoreExecutablePath() else {
            log("Couldn't find SideStore's binary in the signed bundle to check how it imports Account.sideconf.")
            return false
        }
        guard let binary = try? Data(contentsOf: URL(fileURLWithPath: exec), options: .mappedIfSafe) else {
            log("Couldn't read \(exec) to check how SideStore imports Account.sideconf.")
            return false
        }
        return binary.range(of: Engine.promptingImporterMarker) == nil
    }

    /// The SideStore executable inside the signed bundle. Under LiveContainer
    /// that is the guest copy, moved into `Frameworks/SideStoreApp.framework`
    /// and dylibified by LiveContainer's `build_github.sh`; otherwise it is the
    /// signed .app itself. Either way the bundle has to really be SideStore, so
    /// a build that isn't can't be mistaken for one that imports silently —
    /// isideload only ever suffixes the id with ".<teamID>", so the prefix holds.
    private func sideStoreExecutablePath() -> String? {
        guard let app = signedAppPath else { return nil }
        let framework = (app as NSString).appendingPathComponent("Frameworks/SideStoreApp.framework")
        return sideStoreExecutable(inBundle: framework) ?? sideStoreExecutable(inBundle: app)
    }

    private func sideStoreExecutable(inBundle bundlePath: String) -> String? {
        guard let plist = bundlePlist(at: bundlePath),
              let id = plist["CFBundleIdentifier"] as? String,
              id.hasPrefix("com.SideStore.SideStore"),
              let name = plist["CFBundleExecutable"] as? String
        else { return nil }
        let exec = (bundlePath as NSString).appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: exec) ? exec : nil
    }

    /// Where `Account.sideconf` goes, or nil if this install isn't SideStore.
    /// Under LiveContainer, SideStore is a guest with a nested Documents folder;
    /// a custom IPA qualifies only when it really is a SideStore build — its
    /// bundle id is the signed one, which isideload suffixes with ".<teamID>".
    private func accountConfigRemoteRelativePath(source: InstallSource) -> String? {
        switch source {
        case .sideStore:     return "Account.sideconf"
        case .liveContainer: return "SideStore/Documents/Account.sideconf"
        case .custom:
            guard signedAppBundleID()?.hasPrefix("com.SideStore.SideStore") == true else { return nil }
            return "Account.sideconf"
        }
    }

    private func buildAccountConfig(session: OpaquePointer) throws -> String {
        var json: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_account_config(session, &json, &error)
        guard rc == 0 else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message(msg)
        }
        let payload = json.map { String(cString: $0) } ?? ""
        json.map { si_string_free($0) }
        guard !payload.isEmpty else { throw EngineError.message("empty account config") }
        return payload
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
        let (vpn, wifi, detail) = NetworkStatus.summarize(deviceIP: deviceHost)
        publishNetwork(vpn: vpn, wifi: wifi,
                       vpnText: vpn ? "tunnel up" : "no tunnel (start a loopback VPN)")
        log("Network: \(detail)")
        log("VPN(loopback)=\(vpnStatus), Wi-Fi=\(wifiStatus). RSD target \(deviceHost):\(DeviceConnection.rsdPort).")
        if !vpn { log("⚠️ No tunnel on \(deviceHost)'s subnet — connect a loopback VPN (LocalDevVPN, ClashMi, …).") }
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
        let (vpn, wifi, _) = NetworkStatus.summarize(deviceIP: deviceHost)
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

    // MARK: - Starting LocalDevVPN
    //
    // Nothing here starts a tunnel itself: a VPN configuration belongs to the
    // app that created it, and no app can switch on another's. What LocalDevVPN
    // does offer is a URL scheme — `localdevvpn://enable?scheme=<ours>` connects
    // its tunnel and, a second later, opens `<ours>://` to hand the screen
    // straight back. That round trip is the whole mechanism.

    private static let localDevVPNScheme = "localdevvpn"
    /// The scheme LocalDevVPN is asked to return to, registered in Info.plist.
    private static let callbackScheme = "sideinstaller"

    /// True when LocalDevVPN is installed. Only answerable because Info.plist
    /// lists its scheme under `LSApplicationQueriesSchemes`.
    var localDevVPNInstalled: Bool {
        guard let url = URL(string: "\(Self.localDevVPNScheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// When the last handover fired, so the trip back can't set off another.
    private var lastVPNStartAttempt: Date?

    /// Hand over to LocalDevVPN, asking it to connect and come back. False means
    /// it isn't installed — the only outcome this app can see, since everything
    /// after the handover happens over there.
    @MainActor
    @discardableResult
    func startLocalDevVPN() -> Bool {
        guard localDevVPNInstalled,
              let url = URL(string: "\(Self.localDevVPNScheme)://enable?scheme=\(Self.callbackScheme)")
        else {
            log("⛔️ LocalDevVPN isn't installed — nothing to start.")
            return false
        }
        lastVPNStartAttempt = Date()
        log("Handing over to LocalDevVPN to connect the tunnel …")
        UIApplication.shared.open(url)
        return true
    }

    /// The launch hook behind the setting. Runs on every activation, not just a
    /// cold start: iOS resumes this app far more often than it launches it, and
    /// a tunnel dropped while it was away is exactly the case worth catching.
    @MainActor
    func autoStartVPNIfWanted() {
        guard autoStartVPN else { return }
        // The setting is on by default, so a first run would otherwise be
        // yanked into another app before the terms have even been read.
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "hasAcceptedTOS"),
              defaults.bool(forKey: "hasCompletedAccountSetup") else { return }
        // Covers the handover and the seconds the tunnel needs to come up, so
        // LocalDevVPN's own trip back can't bounce the user straight out again.
        if let last = lastVPNStartAttempt, Date().timeIntervalSince(last) < 30 { return }
        refreshNetworkStatus()
        guard !vpnConnected else { return }
        guard localDevVPNInstalled else {
            log("⚠️ “Start LocalDevVPN on launch” is on, but LocalDevVPN isn't installed.")
            return
        }
        startLocalDevVPN()
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
        return bundlePlist(at: app)
    }

    /// Read the Info.plist of any bundle directory, not just the signed .app —
    /// LiveContainer carries SideStore as a nested framework with its own.
    private func bundlePlist(at bundlePath: String) -> [String: Any]? {
        let plistPath = (bundlePath as NSString).appendingPathComponent("Info.plist")
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

    /// Adopt a pairing file the user made elsewhere, replacing whatever is on
    /// disk. The way in for an iPhone older than iOS 27, which can't pair with
    /// itself: the file comes from jitterbugpair, pymobiledevice3, idevicepair
    /// or another app that already holds one for this device.
    @MainActor
    func importPairingFile(from url: URL) async {
        guard !isImportingPairing else { return }
        isImportingPairing = true
        // The picker copies the file into this app's Inbox before handing it
        // over; once it's read, that copy is dead weight.
        defer { isImportingPairing = false; Self.discardInboxCopy(url) }
        lastError = nil
        log("Importing pairing file \(url.lastPathComponent) …")
        do {
            let data = try Self.readImport(from: url)
            let kind = PairingFileKind.of(data: data)
            guard kind.isUsable else {
                lastError = L("%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.",
                              url.lastPathComponent)
                log("⛔️ Pairing import: \(lastError ?? "")")
                return
            }
            try data.write(to: PrivateStore.pairingFile, options: .atomic)
            // The merged file was built from the record this just replaced.
            CompositePairingFile.invalidateMerged()
            pairingFilePath = PrivateStore.pairingFile.path
            importedPairingName = url.lastPathComponent
            UserDefaults.standard.set(url.lastPathComponent, forKey: Engine.importedPairingNameKey)
            connection.disconnect()
            deviceSummary = nil
            pairingStatus = L("imported pairing file")
            setGuide(nil)
            let records = [kind.hasLockdown ? "lockdown" : nil,
                           kind.hasRemotePairing ? "remote-pairing" : nil]
                .compactMap { $0 }.joined(separator: " + ")
            log("Imported \(url.lastPathComponent) (\(data.count) bytes, \(records) record\(records.contains("+") ? "s" : "")\(kind.udid.map { ", UDID \($0)" } ?? "")).")
            if !kind.hasLockdown {
                log("⚠️ No lockdown record in that file — SideStore and Feather can't read it, though the install itself will work.")
            }
        } catch {
            lastError = L("Couldn't import %@: %@", url.lastPathComponent, error.localizedDescription)
            log("⛔️ Pairing import: \(lastError ?? "")")
        }
    }

    /// Forget that the pairing file was imported, once a fresh one has been
    /// paired on this iPhone and overwritten it.
    @MainActor
    func clearImportedPairingMark() {
        importedPairingName = nil
        UserDefaults.standard.removeObject(forKey: Engine.importedPairingNameKey)
    }

    /// Read a picked file off the main thread, taking the security-scoped handle
    /// an "Open with" hand-off comes with.
    private static func readImport(from url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }

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
        let udid = deviceUDID
        try await onDeviceQueue {
            let placement = try self.resolvePlacement(rpPairingPath: path, udid: udid)
            try self.performInstallPairing(bundleID: bundleID, remoteRelativePath: rel,
                                           placementPath: placement)
        }
    }

    /// Write the pairing file into every scanned target, as iLoader's
    /// "Place In All Apps" does. Connects once, then writes each in turn.
    @MainActor
    func installPairing(intoAll targets: [InstalledPairingTarget]) async throws {
        try await ensurePairingConnection()
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        let udid = deviceUDID
        // Resolved once for the whole run: minting the lockdown record can ask
        // the user to tap Trust, and every app is handed the same file anyway.
        let placement = try await onDeviceQueue {
            try self.resolvePlacement(rpPairingPath: path, udid: udid)
        }
        var failures: [String] = []
        for target in targets {
            let bundleID = target.bundleID
            let rel = target.remoteRelativePath
            do {
                try await onDeviceQueue {
                    try self.performInstallPairing(bundleID: bundleID, remoteRelativePath: rel,
                                                   placementPath: placement)
                }
            } catch {
                // One app refusing the write shouldn't cost the rest.
                log("⚠️ Couldn't write into \(target.name) (\(short(error))).")
                failures.append(target.name)
            }
        }
        guard failures.isEmpty else {
            throw EngineError.message(L("Couldn't write into %@.", failures.joined(separator: ", ")))
        }
    }

    /// Bring up the device link for a standalone pairing operation, always with
    /// a fresh tunnel: `isConnected` still reads true after iOS tears one down.
    @MainActor
    private func ensurePairingConnection() async throws {
        refreshNetworkStatus()
        // No Wi-Fi check: this all runs over the loopback tunnel.
        guard vpnConnected else {
            throw EngineError.message(L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        guard fileExistsNonEmpty(path) else {
            throw EngineError.message(canSelfPair
                ? L("No pairing file yet — tap “Generate pairing file” first.")
                : L("No pairing file yet — tap “Import pairing file” first."))
        }
        pairingFilePath = path
        let ip = deviceHost
        let device = try await onDeviceQueue { try self.performConnect(ip: ip, pairingPath: path) }
        deviceSummary = device.summary
        deviceUDID = device.udid
        deviceName = device.name
        pairingStatus = L("connected")
    }

    /// Write the resolved pairing file into `bundleID`'s Documents, verifying
    /// the read-back.
    private func performInstallPairing(bundleID: String, remoteRelativePath: String,
                                       placementPath: String) throws {
        guard connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
        log("Writing pairing file into \(bundleID) /Documents/\(remoteRelativePath) …")
        let written = try connection.writePairingFile(intoBundleID: bundleID,
                                                       remoteRelativePath: remoteRelativePath,
                                                       pairingFilePath: placementPath)
        log("Pairing file written into \(bundleID) and read-back VERIFIED (\(written) bytes).")
    }

    /// The file to hand over, once the RPPairing record it's built from is known
    /// to be there. Runs on `deviceQueue`.
    private func resolvePlacement(rpPairingPath: String, udid: String?) throws -> String {
        guard FileManager.default.fileExists(atPath: rpPairingPath), fileSize(rpPairingPath) > 0 else {
            throw EngineError.message(Engine.deviceCanSelfPair
                ? L("Pairing file missing — generate it first.")
                : L("Pairing file missing — import it first."))
        }
        return placementPairingFile(rpPairingPath: rpPairingPath, udid: udid)
    }

    // MARK: - Sideloaded apps tab

    /// What the device says is installed, and every provisioning profile it
    /// holds. Two round trips over the one tunnel, since matching an app to the
    /// profile that signed it can only be done with both in hand.
    @MainActor
    func sideloadedAppInventory() async throws -> (apps: [[String: Any]], profiles: [Data]) {
        try await ensurePairingConnection()
        let apps = try await onDeviceQueue { try self.connection.installedAppPlists() }
        let profiles = try await onDeviceQueue { try self.connection.provisioningProfiles() }
        log("Apps: \(apps.count) installed, \(profiles.count) provisioning profile(s) on the device.")
        return (apps, profiles)
    }

    // MARK: Refreshing what's already installed
    //
    // A free provisioning profile lasts seven days, and the only way to put
    // seven back on the clock is to sign the app again and install it over
    // itself — which is what SideStore's "Refresh" does. Nothing below is new
    // work: it is the install pipeline's sign and install steps, run per app and
    // kept off the one-click checklist.

    /// Everything a refresh needs before the first app is signed: the loopback
    /// tunnel up, the device link open — which is also where the UDID the signer
    /// registers comes from — and the Apple ID signed in.
    @MainActor
    func prepareRefresh() async throws {
        guard osSupported else {
            throw EngineError.message(L("iOS %@ isn't supported — SideInstaller needs iOS %@ or later.",
                                        osVersionText, Engine.minimumTunnelOSText))
        }
        guard !normalizedAppleID.isEmpty, !applePassword.isEmpty else {
            throw EngineError.message(L("No Apple ID saved. Add one in Settings › Account."))
        }
        try await ensurePairingConnection()
        try await signIn(updatingChecklist: false)
    }

    /// Sign `ipaPath` again and install it over the copy already on the device.
    /// Signing issues a new provisioning profile, and installing is what puts it
    /// on the app — neither half is a refresh on its own. The bundle id, team
    /// and certificate are unchanged, so installd treats this as an upgrade and
    /// the app keeps its data.
    @MainActor
    func refreshInstalledApp(named name: String, ipaPath: String) async throws {
        guard let session = signSession else { throw EngineError.message(L("Not signed in.")) }
        let udid = deviceUDID ?? ""
        let device = deviceName ?? ""
        log("=== Refreshing \(name) from \((ipaPath as NSString).lastPathComponent) ===")
        let signed: String
        do {
            signed = try await onSignQueue {
                try self.performSign(session: session, ipa: ipaPath, udid: udid, deviceName: device)
            }
        } catch EngineError.certExists {
            // Not `certConflict`: that raises the Install tab's revoke-and-retry
            // card, whose retry runs a whole install of whatever that tab has
            // selected. Point at the Certificates page instead, which revokes
            // without starting anything.
            throw EngineError.message(L("Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Revoke it under Tools › Certificates, then refresh again."))
        }
        defer { Self.discardSignedBundle(at: signed) }
        installProgress = 0
        let ip = deviceHost
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        try await onDeviceQueue {
            // Signing takes long enough for iOS to tear the tunnel down, and
            // `isConnected` can't see that — rebuild the link, as install does.
            try self.connection.connect(deviceIP: ip, pairingFilePath: path)
            guard self.connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
            try self.connection.installSignedApp(bundlePath: signed)
        }
        installProgress = 1
        log("\(name) refreshed — its seven days start again now.")
    }

    /// Delete a signed bundle once it is on the device. Refreshing a page full
    /// of apps unpacks one of these per app, at a few hundred megabytes each;
    /// the one-click install leaves its single copy for the OS to reap.
    private static func discardSignedBundle(at path: String) {
        // isideload unpacks into <temp>/<ipa file name>_extracted/Payload/X.app,
        // so the extraction directory is what's worth taking away. Anything not
        // shaped like that is left alone.
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL
        let extraction = URL(fileURLWithPath: path).standardizedFileURL
            .deletingLastPathComponent()        // Payload
            .deletingLastPathComponent()        // <ipa file name>_extracted
        guard extraction.deletingLastPathComponent().path == temp.path,
              extraction.lastPathComponent.hasSuffix("_extracted") else { return }
        try? FileManager.default.removeItem(at: extraction)
    }

    // MARK: - Location tab
    //
    // Location simulation is a DVT service, so it needs two things the install
    // flow never sets up: a mounted developer disk image, and a session held
    // open for as long as the fake location should stick. Both follow
    // StikDebug's path, over the same RPPairing tunnel used everywhere else.

    /// Connect, and mount the developer disk image unless the device already has
    /// one. Returns true when a mount actually ran, so the UI can say so.
    @MainActor
    @discardableResult
    func prepareLocationSimulation(imagePath: String,
                                   trustcachePath: String,
                                   manifestPath: String,
                                   progress: @escaping (Double) -> Void) async throws -> Bool {
        try await ensurePairingConnection()
        let mounted = try await onDeviceQueue { try self.connection.mountedDeveloperImageCount() }
        if mounted > 0 {
            log("Developer disk image already mounted (\(mounted) image(s)).")
            try await onDeviceQueue { try self.connection.beginLocationSimulation() }
            return false
        }
        log("No developer disk image mounted — mounting the personalized one…")
        try await onDeviceQueue {
            try self.connection.mountPersonalizedDeveloperImage(imagePath: imagePath,
                                                               trustcachePath: trustcachePath,
                                                               manifestPath: manifestPath,
                                                               progress: progress)
        }
        log("Developer disk image mounted.")
        try await onDeviceQueue { try self.connection.beginLocationSimulation() }
        return true
    }

    /// Push a coordinate to the device. The caller repeats this on a timer —
    /// iOS lets the simulated location lapse if nothing refreshes it.
    @MainActor
    func simulateLocation(latitude: Double, longitude: Double) async throws {
        guard connection.isSimulatingLocation else {
            throw EngineError.message(L("Location session closed — set it up again."))
        }
        try await onDeviceQueue {
            try self.connection.setSimulatedLocation(latitude: latitude, longitude: longitude)
        }
    }

    /// Give the device its real location back and close the session.
    @MainActor
    func stopSimulatingLocation() async throws {
        guard connection.isSimulatingLocation else { return }
        try await onDeviceQueue {
            try self.connection.clearSimulatedLocation()
            self.connection.endLocationSimulation()
        }
        log("Simulated location cleared.")
    }

    // MARK: The file other apps actually read

    /// The pairing file to hand to another app: the RPPairing record merged with
    /// a classic lockdown one, falling back to the RPPairing record alone.
    ///
    /// SideInstaller's own tunnel runs on RPPairing, but that's the only record
    /// it produces, and minimuxer — SideStore, LiveContainer + SideStore — and
    /// Feather all parse a classic lockdown record instead. iLoader's pairing
    /// file carries both; this mints the missing half over the tunnel that's
    /// already open and merges the two, exactly as iLoader does.
    ///
    /// Must run on `deviceQueue`: it talks to the device. Never throws — a
    /// failure costs the classic half, not the write, and the RPPairing record
    /// alone is what shipped before and still serves StikDebug's sideloaded
    /// build.
    private func placementPairingFile(rpPairingPath: String, udid: String?) -> String {
        // An imported file is usually a classic record already — exactly what
        // those apps parse — so hand it over as it stands rather than spending
        // a pairing slot and a Trust prompt minting a second one.
        let kind = PairingFileKind.of(path: rpPairingPath)
        if kind.hasLockdown {
            // Unless it names no device: pymobiledevice3 and idevicepair leave
            // UDID out, and minimuxer wants it.
            guard kind.udid == nil, let udid, !udid.isEmpty else {
                log("Pairing file already carries a lockdown record — handing it over as it is.")
                return rpPairingPath
            }
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: rpPairingPath))
                let path = try CompositePairingFile.store(
                    CompositePairingFile.stampingUDID(udid, into: data))
                log("Pairing file carries a lockdown record but no UDID — stamping in \(udid).")
                return path
            } catch {
                log("⚠️ Couldn't stamp the UDID into the pairing file (\(short(error))). Handing it over as it is.")
                return rpPairingPath
            }
        }
        do {
            let rpPairing = try Data(contentsOf: URL(fileURLWithPath: rpPairingPath))

            let lockdown: Data
            if let cached = CompositePairingFile.cachedLockdownRecord(forUDID: udid) {
                lockdown = cached
            } else {
                log("Pairing with lockdown as well, so AltStore-family apps can read the file. Tap Trust if this iPhone asks, and unlock it if it's locked …")
                let record = try connection.lockdownPairRecord(hostID: CompositePairingFile.hostID,
                                                               systemBUID: CompositePairingFile.systemBUID)
                if let problem = record.wirelessLockdownError {
                    // The record still goes in: the setting may already be on.
                    log("⚠️ Couldn't turn on wireless lockdown (\(problem)). Apps read this file over a loopback, so they may still refuse it.")
                } else {
                    log("Lockdown pairing done, wireless lockdown enabled.")
                }
                lockdown = record.data
                try CompositePairingFile.storeLockdownRecord(lockdown, forUDID: udid)
            }

            let merged = try CompositePairingFile.merge(lockdown: lockdown,
                                                        rpPairing: rpPairing,
                                                        udid: udid)
            let path = try CompositePairingFile.store(merged)
            log("Pairing file carries both records (\(merged.count) bytes) — readable by SideStore, LiveContainer and Feather as well as StikDebug.")
            return path
        } catch {
            log("⚠️ Couldn't add the lockdown record to the pairing file (\(short(error))). Writing the RPPairing record on its own — StikDebug (sideloaded) reads that, SideStore and Feather won't.")
            return rpPairingPath
        }
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

    /// Shown when no tunnel is up. The copy names LocalDevVPN, since offering a
    /// choice sent people looking for the "right" one; any VPN app on the device
    /// subnet still works, and `vpnConnected` never checks which one it is.
    static var vpn: Guide {
        Guide(
            title: L("Connect LocalDevVPN"),
            systemImage: "network",
            steps: [
                L("Install LocalDevVPN from the App Store and open it."),
                L("If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through."),
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
                L("If you changed LocalDevVPN's addresses, copy its Device IP here — including the /32, if it shows one."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    /// Shown when no Apple ID is saved. Since the credential fields left this
    /// screen, the empty state has to be spelt out rather than shown as a gap.
    static var account: Guide {
        Guide(
            title: L("Add your Apple ID"),
            systemImage: "person.crop.circle.badge.plus",
            steps: [
                L("Open Settings with the gear at the top right."),
                L("Under Account, tap “Add Apple ID” and enter your email and password."),
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
                L("Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself."),
                L("Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker."),
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

    /// Shown on an iPhone below iOS 27, where the pairing file has to be made
    /// somewhere else and brought over.
    static var importPairing: Guide {
        Guide(
            title: L("Import a pairing file"),
            systemImage: "lock.doc",
            steps: [
                L("iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.", Engine.minimumOSText),
                L("On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”)."),
                L("Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable."),
                L("Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.", Engine.minimumOSText),
            ],
            actionLabel: L("Get jitterbugpair"),
            actionURLString: "https://github.com/osy/Jitterbug/releases")
    }

    /// Shown when Apple refuses a certificate because one exists (error 7460).
    static var certExists: Guide {
        Guide(
            title: L("A signing certificate already exists"),
            systemImage: "exclamationmark.shield",
            steps: [
                L("Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending."),
                L("SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone."),
                L("Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there."),
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
