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

    /// Active Apple ID credentials, read from `AccountStore` (entered during
    /// setup, switched in Settings › Account). Views observe the store directly.
    var appleID: String { AccountStore.shared.activeAppleID }
    var applePassword: String { AccountStore.shared.activePassword }
    /// Anisette server in use. Persisted, and updated to whichever server the
    /// last successful sign-in used.
    @Published var anisetteURL: String =
        UserDefaults.standard.string(forKey: Engine.anisetteURLKey) ?? AnisetteServer.fallback.address {
        didSet {
            guard anisetteURL != oldValue else { return }
            UserDefaults.standard.set(anisetteURL, forKey: Engine.anisetteURLKey)
        }
    }

    static let anisetteURLKey = "anisetteServerURL"
    /// Servers for the picker; a bundled snapshot until the live list loads.
    @Published private(set) var anisetteServers: [AnisetteServer] = AnisetteServer.bundledDefaults
    /// "Start LocalDevVPN when SideInstaller opens" setting. On by default, since
    /// every page needs the tunnel. Stored here (not `@AppStorage`) so the launch
    /// hook and the Settings toggle share one value.
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
    /// `deviceIP` normalized to a dialable host, e.g. `10.7.0.1/32` → `10.7.0.1`.
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

    /// Minimum iOS that can create its own pairing file (RPPairing host and the
    /// Settings pairing prompt).
    static let minimumOSMajorVersion = 27
    /// The same number as text, for UI copy.
    static var minimumOSText: String { "\(minimumOSMajorVersion)" }

    /// Minimum iOS for everything after pairing. The RSD tunnel needs iOS 17+
    /// (CoreDeviceProxy); the UI needs 18.
    static let minimumTunnelOSMajorVersion = 18
    static var minimumTunnelOSText: String { "\(minimumTunnelOSMajorVersion)" }

    /// True when this iPhone can pair with itself, so no computer-made pairing
    /// file is needed. Static so non-isolated code can read it.
    static var deviceCanSelfPair: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: minimumOSMajorVersion,
                                   minorVersion: 0, patchVersion: 0))
    }

    var canSelfPair: Bool { Engine.deviceCanSelfPair }

    /// False when iOS is too old for the install tunnel, even with an imported
    /// pairing file.
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

    /// Filename of the imported pairing file, if the one on disk was imported.
    /// Persisted across launches.
    @Published private(set) var importedPairingName: String? =
        UserDefaults.standard.string(forKey: Engine.importedPairingNameKey)
    /// True while a picked pairing file is being read in.
    @Published private(set) var isImportingPairing = false

    static let importedPairingNameKey = "importedPairingFileName"
    @Published var pairingStatus: String = L("not paired")
    @Published var signInStatus: String = "signed out"

    // Path to the pairing file in use (generated by RPPairing or imported).
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
    /// The IPA download a run starts as soon as the network is up, so it runs
    /// alongside pairing and sign-in instead of after them.
    private var prefetch: (source: InstallSource, channel: ReleaseChannel, task: Task<String, Error>)?
    /// The Apple ID sign-in a run starts once pairing is settled, so it runs
    /// while the device link opens.
    private var backgroundSignIn: Task<Void, Error>?
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
    /// Team ID of the signed-in account, parsed from the sign-in summary. Only
    /// apps signed by this team can be refreshed in place.
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
    /// Download progress of a link import (0…1); nil for file imports.
    @Published private(set) var importProgress: Double?

    // 2FA bridge: the FFI callback blocks on this semaphore until the UI answers.
    /// What the two-factor sheet shows; nil while no sign-in is asking.
    @Published private(set) var twoFactor: TwoFactorPhase?
    private let twoFactorSem = DispatchSemaphore(value: 0)
    /// Guards the answer handed from the main thread to the waiting Rust worker.
    private let twoFactorLock = NSLock()
    private var twoFactorAnswer: TwoFactorAnswer?
    private var awaitingTwoFactor = false
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

    /// True when launched with `SIDEINSTALLER_LOG_STDOUT` set, which mirrors every
    /// line to stdout so a run on an iPhone can be followed and timed from a Mac
    /// (`xcrun devicectl device process launch --console`).
    private static let mirrorsLogToStdout =
        ProcessInfo.processInfo.environment["SIDEINSTALLER_LOG_STDOUT"] != nil

    private func appendLine(_ message: String) {
        let stamp = dateFormatter.string(from: Date())
        if Self.mirrorsLogToStdout {
            fputs("\(stamp)  \(message)\n", stdout)
            fflush(stdout)
        }
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
                // The download needs neither the device nor the Apple ID, so it
                // starts now and runs while those steps do.
                startPrefetch()
                try await pairAndConnect()
                try await signInStep()
                try await download()
                try await signApp()
                // The certificate hand-off is built on the sign queue, which the
                // install doesn't use, so it's ready once the install is done.
                let accountConfig = startAccountConfig()
                try await install()
                try await writePairing(accountConfig: accountConfig)
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
            stopBackgroundWork()
            isRunning = false
            pairingPIN = nil
        }
    }

    /// Stop the pipeline at the next safe point.
    @MainActor
    func cancelOneClick() {
        pipelineTask?.cancel()
        prefetch?.task.cancel()                 // stop the download now, not at its step
        PairingController.shared.softCancel()   // unblock a pending pairing wait
    }

    /// Cancel whatever the run started early and never got to use.
    @MainActor
    private func stopBackgroundWork() {
        prefetch?.task.cancel()
        prefetch = nil
        backgroundSignIn?.cancel()
        backgroundSignIn = nil
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

        // Pairing is settled, so sign in while the link opens.
        startBackgroundSignIn()

        do {
            try await connect()
        } catch {
            // A reused pairing file may be stale: re-pair once and retry.
            // Only possible when this iPhone can self-pair (iOS 27+).
            guard reused, canSelfPair else { throw error }
            // Don't re-pair if the tunnel never reached the device: the pairing
            // file isn't the problem, and a new PIN wouldn't fix it.
            if let tunnel = error as? DeviceConnection.TunnelError,
               !tunnel.repairingCouldHelp {
                throw error
            }
            log("Saved pairing didn't work (\(short(error))). Pairing fresh…")
            // Pairing has the user type a code into Settings. Let a sign-in that
            // may be asking for a 2FA code finish first, so the two never overlap.
            if let signingIn = backgroundSignIn { _ = await signingIn.result }
            try Task.checkCancellation()
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

    /// Triggers the Local Network permission prompt when an imported pairing
    /// file is used (below iOS 27).
    ///
    /// Connecting to lockdownd over the tunnel counts as local-network access,
    /// which iOS silently blocks until granted. On iOS 27 the RPPairing host
    /// already triggers the prompt. Best-effort: if denied, the connect still
    /// runs and reports its own error.
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

    /// Frees the cached sign-in session so the next run signs in as the active
    /// account. Called when credentials change. Runs on `signQueue`, which owns
    /// `signSession`.
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

    /// The checklist's sign-in step: waits for the sign-in started alongside the
    /// device link, or signs in now when none was.
    @MainActor
    private func signInStep() async throws {
        guard let started = backgroundSignIn else { return try await signIn() }
        backgroundSignIn = nil
        try Task.checkCancellation()
        setStep(.signIn, .active)
        try await withTaskCancellationHandler {
            try await started.value
        } onCancel: {
            started.cancel()
        }
        setStep(.signIn, .done)
    }

    /// Starts the Apple ID sign-in without touching the checklist, unless this
    /// session is already signed in. It runs on the sign queue, apart from the
    /// device link.
    @MainActor
    private func startBackgroundSignIn() {
        guard backgroundSignIn == nil, signSession == nil else { return }
        backgroundSignIn = Task { @MainActor in
            try await self.signIn(updatingChecklist: false)
        }
    }

    /// Signs in to the Apple ID, trying each anisette server in turn.
    /// Pass `updatingChecklist: false` from flows outside the Install tab (e.g.
    /// app refresh) so they don't change its checklist.
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
        var appleRefusals = 0

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
                if Self.isAppleRateLimit(lastError) {
                    signInStatus = "sign-in failed"
                    log("Apple is rate-limiting sign-in (HTTP 429) — not trying more anisette servers.")
                    throw EngineError.message(Self.appleRateLimitMessage)
                }
                // Apple refusing the request looks the same through every
                // anisette server, so a second refusal ends the loop.
                if Self.isAppleServiceRefusal(lastError) {
                    appleRefusals += 1
                    if appleRefusals >= 2 {
                        signInStatus = "sign-in failed"
                        log("Apple's sign-in server refused \(appleRefusals) attempts with HTTP 503 — not trying more anisette servers.")
                        throw EngineError.message(Self.appleServiceRefusalMessage)
                    }
                }
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
        defer { endTwoFactor() }
        log("Apple ID sign-in for \(Self.oneLine(id)) via anisette \(Self.oneLine(ani)) …")
        var session: OpaquePointer?
        var summary: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        // 1 = save and reuse the developer session, so repeat sign-ins skip
        // Apple authentication until the token expires.
        let rc = si_apple_signin(id, pw, ani, "SideInstaller", dir, 1,
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

    /// Parses the 10-character team ID from a summary like "team: Name (ABCDE12345)".
    /// Returns nil if it can't be read, so the refresh flow doesn't skip any apps.
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

    /// Shown when Apple rejects the credentials. Includes a rate-limit hint because
    /// Apple can also return -22406 for a correct password while throttling.
    static var credentialErrorMessage: String {
        L("Incorrect Apple ID or password. Check your Apple Account email and password, then try again.")
            + " " + L("If you're sure the password is right, Apple may be limiting sign-in attempts: wait a while before trying again.")
    }

    /// What the user sees when Apple is throttling sign-ins.
    static var appleRateLimitMessage: String {
        L("Apple is temporarily limiting sign-ins for this Apple ID or network (HTTP 429). Trying other servers won't help, and every attempt can extend the wait, so leave it a while before signing in again.")
    }

    /// Detects an HTTP 429 from Apple (GrandSlam or the developer portal).
    /// Switching anisette servers doesn't avoid Apple's limit, so sign-in stops.
    /// 429s from anisette servers don't mention apple.com and still fall through.
    static func isAppleRateLimit(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("apple.com") && m.contains("429 too many requests")
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

    /// What the user sees when Apple's sign-in server refuses the request itself.
    static var appleServiceRefusalMessage: String {
        L("Apple's sign-in server refused the request (HTTP 503). It isn't your password or the anisette server, so trying more servers won't help. Try again later, or update SideInstaller.")
    }

    /// Detects an HTTP 503 from gsa.apple.com. Apple rejects the request before
    /// checking anisette data, so other anisette servers would fail the same way.
    static func isAppleServiceRefusal(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("gsa.apple.com") && m.contains("503")
    }

    // MARK: Step 5 — download the IPA

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

        do {
            let path = try await fetchLatest(source: src, channel: channel)
            adopt(URL(fileURLWithPath: path), source: src, channel: channel)
            log("\(src.displayName) IPA ready at \(path)")
            setStep(.download, .done)
        } catch {
            // Stopping the install isn't a failed download: no cached copy stands in.
            if Task.isCancelled { throw CancellationError() }
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

    /// Starts downloading the selected build when the download step would fetch
    /// it from GitHub, so the transfer overlaps pairing and sign-in. A build
    /// already at hand (this session's download, an imported or custom IPA) is
    /// left to the download step, exactly as before.
    @MainActor
    private func startPrefetch() {
        prefetch?.task.cancel()
        prefetch = nil
        let src = installSource
        let channel = releaseChannel
        guard src != .custom else { return }
        if let p = downloadedIPAPath, downloadedSource == src, downloadedChannel == channel,
           FileManager.default.fileExists(atPath: p) {
            return
        }
        if let onDisk = IPALibrary.entry(source: src, channel: channel), onDisk.isImported { return }

        log("Fetching \(channel.displayName.lowercased()) \(src.displayName) release in the background…")
        let task = Task {
            try await SideStoreDownloader.downloadLatest(source: src, channel: channel) { line in
                self.log(line)
            }
        }
        prefetch = (src, channel, task)
    }

    /// The selected build's download: the one this run started early when there
    /// is one, otherwise a new one. Cancelling the caller cancels either.
    @MainActor
    private func fetchLatest(source: InstallSource, channel: ReleaseChannel) async throws -> String {
        guard let started = prefetch, started.source == source, started.channel == channel else {
            log("Fetching \(channel.displayName.lowercased()) \(source.displayName) release…")
            return try await SideStoreDownloader.downloadLatest(source: source, channel: channel) { line in
                self.log(line)
            }
        }
        prefetch = nil
        let task = started.task
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
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
        // Delete the picker's temporary copy once the import is done.
        defer { isImportingIPA = false; Self.discardInboxCopy(url) }
        lastError = nil
        log("Importing \(url.lastPathComponent) …")
        do {
            let dest = try await Self.copyImport(from: url)
            customIPAName = dest.lastPathComponent
            // Clear the cached path so the next run uses the new file.
            if downloadedSource == .custom { downloadedIPAPath = nil }
            setGuide(nil)
            log("Imported \(dest.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize(dest.path)), countStyle: .file))).")
        } catch IPALibrary.ImportError.notAnIPA {
            // The picker accepts any file. Validation runs on a staged copy, so
            // the previous import is kept.
            refreshCustomIPA()
            lastError = L("%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.",
                          url.lastPathComponent)
            log("⛔️ Import: \(lastError ?? "")")
        } catch {
            // Re-read the import from disk to update the button label.
            refreshCustomIPA()
            lastError = L("Couldn't import %@: %@", url.lastPathComponent, error.localizedDescription)
            log("⛔️ Import: \(lastError ?? "")")
        }
    }

    /// Downloads an IPA from a pasted link and stores it as the custom import.
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
            // The download lives in its own staging directory; remove all of it.
            defer { try? FileManager.default.removeItem(at: downloaded.deletingLastPathComponent()) }
            let dest = try await Self.copyImport(from: downloaded)
            customIPAName = dest.lastPathComponent
            // Clear the cached path so the next run uses the new file.
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

    /// Turns pasted text into a download URL: trims whitespace and adds `https://`
    /// when no scheme is given. Returns nil for non-http(s) schemes.
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
        // Without an explicit scheme, require a dotted hostname to reject plain
        // text. With one, allow bare hosts like `http://nas/App.ipa`.
        guard hadScheme || (host.contains(".") && !host.hasPrefix(".") && !host.hasSuffix("."))
        else { return nil }
        return url
    }

    /// Filename for a linked IPA: the URL's last path component (without its
    /// extension) plus `.ipa`, or the host name when that component is empty.
    static func importFileName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
        let name = base.isEmpty ? (url.host ?? "Custom") : base
        return name + ".ipa"
    }

    /// Deletes a picked file only if it's in this app's temp directory (the
    /// picker's copy). Files opened in place are left alone.
    private static func discardInboxCopy(_ url: URL) {
        let tmp = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path
        guard url.resolvingSymlinksInPath().path.hasPrefix(tmp + "/") else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Copies a picked IPA into the custom import slot on a background queue.
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
            // Read the app's name from the signed bundle (imported IPAs have none before this).
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
            // iOS drops the idle tunnel during sign-in and signing, and
            // `isConnected` doesn't detect it, so reconnect first.
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
    private func writePairing(accountConfig handOff: Task<String?, Never>? = nil) async throws {
        setStep(.writePairing, .active)
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        // The installed build decides the host app and where the file lands.
        let source = downloadedSource ?? installSource
        // Built on the sign queue, where all isideload calls run, before the
        // device-queue write below; a run starts it during the install.
        let accountConfig: String?
        if let handOff {
            accountConfig = await handOff.value
        } else {
            accountConfig = await accountConfigJSON(source: source)
        }
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
        // Add a lockdown record so AltStore-family apps can read the file.
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

        // Give SideStore the signing certificate so its first sign-in reuses it
        // instead of creating a new one and asking to resign. Failures only log.
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

    /// Starts building the certificate hand-off for the build just signed.
    @MainActor
    private func startAccountConfig() -> Task<String?, Never> {
        let source = downloadedSource ?? installSource
        return Task { @MainActor in await self.accountConfigJSON(source: source) }
    }

    /// The `Account.sideconf` JSON for this install, or nil to skip the
    /// certificate hand-off. Errors are logged, never thrown.
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

    /// String found only in SideStore binaries whose account importer prompts
    /// for a password (the `UserDefaults.acctFileChecksum` key).
    private static let promptingImporterMarker = Data("acctFileChecksum".utf8)

    /// Whether the SideStore build being installed imports `Account.sideconf`
    /// silently.
    ///
    /// Silent builds read the file, adopt the certificate, and delete it on first
    /// launch. Builds with `ImportAccountAlertController` instead ask for a file
    /// password, accept only their own encrypted format, and keep the file, so
    /// our plaintext JSON would trigger that alert on every launch. Those builds
    /// get no file (same as iLoader).
    ///
    /// Detected by scanning the binary for `promptingImporterMarker`, because
    /// version numbers don't reliably tell the two apart.
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

    /// Path to the SideStore executable in the signed bundle: the
    /// `Frameworks/SideStoreApp.framework` copy under LiveContainer, otherwise the
    /// .app itself. Nil unless the bundle ID starts with `com.SideStore.SideStore`
    /// (isideload only appends ".<teamID>").
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

    /// Container-relative path for `Account.sideconf`, or nil if the install isn't
    /// SideStore. LiveContainer nests SideStore's Documents folder; a custom IPA
    /// counts only if its signed bundle ID starts with `com.SideStore.SideStore`.
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

    // MARK: - FFI liveness check

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
    // Run single pipeline steps on demand. Errors are logged instead of stopping
    // a run or showing a guide.

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
    // An app can't enable another app's VPN. Instead we open
    // `localdevvpn://enable?scheme=sideinstaller`; LocalDevVPN connects its tunnel
    // and then opens `sideinstaller://` to return here.

    private static let localDevVPNScheme = "localdevvpn"
    /// The scheme LocalDevVPN is asked to return to, registered in Info.plist.
    private static let callbackScheme = "sideinstaller"

    /// True when LocalDevVPN is installed. Only answerable because Info.plist
    /// lists its scheme under `LSApplicationQueriesSchemes`.
    var localDevVPNInstalled: Bool {
        guard let url = URL(string: "\(Self.localDevVPNScheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Time of the last handover, so returning from LocalDevVPN doesn't trigger another.
    private var lastVPNStartAttempt: Date?

    /// Opens LocalDevVPN to connect its tunnel and return. Returns false if it
    /// isn't installed; whether the tunnel connects isn't visible from here.
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

    /// Starts LocalDevVPN when the setting is on and no tunnel is up. Called on
    /// every app activation, so a tunnel dropped while backgrounded is caught too.
    @MainActor
    func autoStartVPNIfWanted() {
        guard autoStartVPN else { return }
        // Wait until onboarding (terms and account setup) is finished.
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "hasAcceptedTOS"),
              defaults.bool(forKey: "hasCompletedAccountSetup") else { return }
        // Skip for 30s after a handover, so returning from LocalDevVPN doesn't
        // immediately open it again.
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
    // Pairing-file management outside the one-click install: generate or import
    // the file, then write it into installed apps via house_arrest/AFC.

    /// Imports a pairing file made elsewhere (jitterbugpair, pymobiledevice3,
    /// idevicepair, …), replacing the one on disk. Required below iOS 27.
    @MainActor
    func importPairingFile(from url: URL) async {
        guard !isImportingPairing else { return }
        isImportingPairing = true
        // Delete the picker's temporary copy once the import is done.
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
            // Drop the cached merged file; it was built from the old record.
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

    /// Reads a picked file while holding its security-scoped access.
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

    /// Installed apps and all provisioning profiles on the device, fetched
    /// together so the caller can match each app to its profile.
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
    // Free provisioning profiles expire after seven days. A refresh re-signs the
    // app and installs it over itself, reusing the pipeline's sign and install
    // steps without touching the one-click checklist.

    /// Prepares for a refresh: checks iOS and credentials, opens the device link
    /// (which provides the UDID for signing), and signs in.
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

    /// Re-signs `ipaPath` (issuing a new provisioning profile) and installs it
    /// over the existing copy. Bundle ID, team and certificate are unchanged, so
    /// installd treats it as an upgrade and app data is kept.
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
            // Don't set `certConflict`: its retry button starts a full install
            // from the Install tab. Point to the Certificates page instead.
            throw EngineError.message(L("Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Revoke it under Tools › Certificates, then refresh again."))
        }
        defer { Self.discardSignedBundle(at: signed) }
        installProgress = 0
        let ip = deviceHost
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        try await onDeviceQueue {
            // iOS may drop the tunnel during signing and `isConnected` doesn't
            // detect it, so reconnect first (same as install).
            try self.connection.connect(deviceIP: ip, pairingFilePath: path)
            guard self.connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
            try self.connection.installSignedApp(bundlePath: signed)
        }
        installProgress = 1
        log("\(name) refreshed — its seven days start again now.")
    }

    /// Deletes a signed bundle after it's installed. A refresh extracts one
    /// bundle per app, so each is removed right away to save space.
    private static func discardSignedBundle(at path: String) {
        // isideload extracts to <temp>/<ipa file name>_extracted/Payload/X.app.
        // Remove that `_extracted` directory; leave any other path alone.
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
    // Location simulation is a DVT service. It needs a mounted developer disk
    // image and a session kept open while the location is simulated. Same
    // approach as StikDebug, over the RPPairing tunnel.

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

    /// Returns the path of the pairing file to write into other apps.
    ///
    /// SideInstaller pairs via RPPairing, but minimuxer (SideStore, LiveContainer)
    /// and Feather need a classic lockdown record. This creates one over the open
    /// tunnel and merges both records into one file, as iLoader does.
    ///
    /// Runs on `deviceQueue`. Never throws: on failure it returns the RPPairing
    /// file alone, which StikDebug can still use.
    private func placementPairingFile(rpPairingPath: String, udid: String?) -> String {
        // Imported files usually already contain a lockdown record: use them
        // as-is instead of pairing again.
        let kind = PairingFileKind.of(path: rpPairingPath)
        if kind.hasLockdown {
            // pymobiledevice3 and idevicepair omit the UDID, which minimuxer
            // needs, so add it when known.
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

    /// Called from a Rust worker thread with isideload's request as JSON; blocks
    /// until the sheet answers. Writes the JSON answer into `outBuf` and returns
    /// 1, or returns 0 to cancel.
    func answerTwoFactor(request: UnsafePointer<CChar>?, outBuf: UnsafeMutablePointer<CChar>?, len: Int) -> Int32 {
        guard let outBuf, len > 1 else { return 0 }
        let prompt = request.flatMap { TwoFactorPrompt(json: String(cString: $0)) } ?? .deviceOnly
        twoFactorLock.lock()
        twoFactorAnswer = nil
        awaitingTwoFactor = true
        twoFactorLock.unlock()
        setMain {
            // A cancel can land between the lock above and this block running.
            self.twoFactorLock.lock()
            let stillWaiting = self.awaitingTwoFactor
            self.twoFactorLock.unlock()
            guard stillWaiting else { return }
            self.twoFactor = .asking(prompt)
            self.log(prompt.logLine)
        }
        twoFactorSem.wait()
        twoFactorLock.lock()
        let answer = twoFactorAnswer
        twoFactorAnswer = nil
        twoFactorLock.unlock()
        guard let bytes = answer?.json.map({ Array($0.utf8) }), bytes.count < len else { return 0 }
        outBuf.withMemoryRebound(to: UInt8.self, capacity: len) { dst in
            for (i, b) in bytes.enumerated() { dst[i] = b }
            dst[bytes.count] = 0
        }
        return 1
    }

    /// Hand the sheet's choice to the waiting sign-in. The sheet stays up showing
    /// progress until the next prompt arrives or the sign-in returns.
    func answerTwoFactor(_ answer: TwoFactorAnswer) {
        twoFactorLock.lock()
        guard awaitingTwoFactor else {
            twoFactorLock.unlock()
            return
        }
        awaitingTwoFactor = false
        twoFactorAnswer = answer
        twoFactorLock.unlock()
        twoFactorWasCancelled = false
        if case .asking(let prompt) = twoFactor { twoFactor = .working(prompt, answer) }
        log(answer.logLine)
        twoFactorSem.signal()
    }

    /// Close the sheet. While Apple waits on the user this cancels the sign-in;
    /// mid-request it only hides, and a further prompt brings it back.
    func cancelTwoFactor() {
        // Already closed because the sign-in returned: nothing to cancel.
        guard twoFactor != nil else { return }
        twoFactor = nil
        twoFactorLock.lock()
        let waiting = awaitingTwoFactor
        awaitingTwoFactor = false
        twoFactorAnswer = nil
        twoFactorLock.unlock()
        guard waiting else { return }
        twoFactorWasCancelled = true
        twoFactorSem.signal()
    }

    /// Close the sheet once a sign-in attempt returns, however it went. Safe from
    /// any thread.
    func endTwoFactor() {
        setMain { self.twoFactor = nil }
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

/// Computed so text is localized when read and follows language changes.
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

    /// Shown when no tunnel is up. Recommends LocalDevVPN, but any VPN on the
    /// device subnet works.
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

    /// Shown when no Apple ID is saved; points to Settings › Account.
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
private let twoFactorCallback: SITwoFactorCb = { _, request, outBuf, bufLen in
    Engine.shared.answerTwoFactor(request: request, outBuf: outBuf, len: Int(bufLen))
}

// MARK: - Two-factor prompt

/// What a sign-in is waiting for, decoded from the request Rust hands the 2FA
/// callback. `SITwoFactorCb` in sideinstaller.h documents the JSON.
struct TwoFactorPrompt: Decodable, Equatable {
    enum Method: String, Decodable {
        /// A code went to the account's trusted Apple devices.
        case device
        /// A code was texted to the selected number.
        case sms
        /// Apple is calling the selected number to read a code out.
        case voice
        /// The last method failed and nothing is pending, so the user picks one.
        case choose
    }

    struct Number: Decodable, Equatable, Identifiable {
        let id: UInt32
        /// Masked by Apple, as in "+39 ••• ••• ••89".
        let number: String
        /// "sms" or "voice", or empty when Apple doesn't say. A voice-only
        /// number, such as a landline, can't take a text.
        let pushMode: String

        var takesTexts: Bool { pushMode != "voice" }
    }

    let method: Method
    let selectedNumberId: UInt32?
    let lastError: String?
    let numbers: [Number]

    /// For a request that can't be read: the one prompt that always makes sense.
    static let deviceOnly = TwoFactorPrompt(method: .device, selectedNumberId: nil, lastError: nil, numbers: [])

    var selectedNumber: Number? { numbers.first { $0.id == selectedNumberId } }

    /// Whether a code is on its way, so the sheet should ask for it.
    var expectsCode: Bool { method != .choose }

    var logLine: String {
        let what = switch method {
        case .device: "2FA required — a code was sent to your trusted devices."
        case .sms:    "2FA: a code was texted to \(selectedNumber?.number ?? "your phone")."
        case .voice:  "2FA: Apple is calling \(selectedNumber?.number ?? "your phone") with a code."
        case .choose: "2FA: that method didn't work — choose another."
        }
        return lastError.map { "\(what) Apple said: \($0)" } ?? what
    }
}

extension TwoFactorPrompt {
    init?(json: String) {
        guard let prompt = try? JSONDecoder().decode(TwoFactorPrompt.self, from: Data(json.utf8)) else {
            return nil
        }
        self = prompt
    }
}

/// The sheet's reply, encoded as the JSON Rust's `TwoFactorAnswer` reads.
enum TwoFactorAnswer: Equatable {
    case code(String)
    case sms(UInt32)
    case voice(UInt32)
    case devices
    case resend

    var json: String? {
        struct Wire: Encodable {
            let action: String
            var code: String?
            var id: UInt32?
        }
        let wire = switch self {
        case .code(let code): Wire(action: "code", code: code)
        case .sms(let id):    Wire(action: "sms", id: id)
        case .voice(let id):  Wire(action: "voice", id: id)
        case .devices:        Wire(action: "devices")
        case .resend:         Wire(action: "resend")
        }
        return (try? JSONEncoder().encode(wire)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// For the console, which must never carry the code itself.
    var logLine: String {
        switch self {
        case .code:    "2FA: checking the code…"
        case .sms:     "2FA: asking Apple to text a code…"
        case .voice:   "2FA: asking Apple to call with a code…"
        case .devices: "2FA: asking Apple to send a code to your devices…"
        case .resend:  "2FA: asking Apple for a new code…"
        }
    }
}

/// The two-factor sheet's state.
enum TwoFactorPhase: Equatable {
    /// Apple is waiting on the user.
    case asking(TwoFactorPrompt)
    /// The user answered and the sign-in is acting on it.
    case working(TwoFactorPrompt, TwoFactorAnswer)

    var prompt: TwoFactorPrompt {
        switch self {
        case .asking(let prompt), .working(let prompt, _): prompt
        }
    }
}
