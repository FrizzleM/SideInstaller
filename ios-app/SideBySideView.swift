import SwiftUI
import UIKit
import SideInstallerFFI

// MARK: - What goes on their iPhone

/// What Side by Side can put on another iPhone, the choice iLoader offers:
/// SideInstaller itself, or one of the two SideStore builds the Install tab
/// sets up.
enum SideBySideApp: String, CaseIterable, Identifiable {
    case sideInstaller
    case sideStore
    case liveContainer

    var id: String { rawValue }

    /// The Install tab's build, for the two SideStore builds: downloaded from
    /// the same place, and handed the pairing file the same way. Nil for
    /// SideInstaller, which comes from its own latest release and pairs itself.
    var source: InstallSource? {
        switch self {
        case .sideInstaller: return nil
        case .sideStore:     return .sideStore
        case .liveContainer: return .liveContainer
        }
    }

    /// Full name, for titles and the log.
    var displayName: String {
        source?.displayName ?? "SideInstaller"
    }

    /// What it's called on their Home Screen.
    var homeScreenName: String {
        source?.pairingAppDisplayName ?? "SideInstaller"
    }

    /// One line on what it's for.
    var summary: String {
        switch self {
        case .sideInstaller:
            return L("This app. Their iPhone pairs itself, then installs SideStore, LiveContainer and more on its own.")
        case .sideStore:
            return L("Installs and refreshes apps right on their iPhone. It gets its pairing file from this iPhone, ready to go.")
        case .liveContainer:
            return L("Runs apps without installing them, with SideStore built in — past the three-app limit of a free Apple ID.")
        }
    }

    /// What their iPhone needs for it.
    var requirement: String {
        switch self {
        case .sideInstaller:             return L("Needs iOS %@ on their iPhone", Engine.minimumOSText)
        case .sideStore, .liveContainer: return L("Needs LocalDevVPN on their iPhone")
        }
    }

    var requirementSymbol: String {
        self == .sideInstaller ? "iphone" : "network"
    }

    /// The app's own icon: SideInstaller's, and the official SideStore and
    /// LiveContainer icons from their repositories (AGPL-3.0), at 256 px.
    var image: String? {
        switch self {
        case .sideInstaller: return "AppLogo"
        case .sideStore:     return "SideStoreLogo"
        case .liveContainer: return "LiveContainerLogo"
        }
    }

    /// SF Symbol drawn on `tint` if the icon art is missing.
    var symbol: String {
        switch self {
        case .sideInstaller: return "arrow.down.app.fill"
        case .sideStore:     return "storefront.fill"
        case .liveContainer: return "shippingbox.fill"
        }
    }

    var tint: Color {
        switch self {
        case .sideInstaller: return Theme.accent
        case .sideStore:     return Color(red: 0.56, green: 0.36, blue: 0.96)
        case .liveContainer: return Color(red: 0.10, green: 0.68, blue: 0.64)
        }
    }
}

// MARK: - Steps

/// Steps of a Side by Side install, in run order.
///
/// Fewer than the Install tab's `Step`: the link goes straight over Wi-Fi (no
/// VPN), and their iPhone is paired as it opens. `setUp` hands a SideStore
/// build its pairing file; SideInstaller pairs itself instead, so it has none.
enum SideBySideStep: Int, CaseIterable, Identifiable {
    case connect, signIn, download, sign, install, setUp

    var id: Int { rawValue }

    func title(for app: SideBySideApp) -> String {
        switch self {
        case .connect:  return L("Pair with their iPhone")
        case .signIn:   return L("Sign in to Apple ID")
        case .download: return L("Download %@", app.displayName)
        case .sign:     return L("Sign the app")
        case .install:  return L("Install on their iPhone")
        case .setUp:    return L("Finish setup")
        }
    }

    /// The steps a run installing `app` goes through.
    static func steps(for app: SideBySideApp) -> [SideBySideStep] {
        app.source == nil ? allCases.filter { $0 != .setUp } : allCases
    }
}

// MARK: - Manager

/// Installs SideInstaller, SideStore or LiveContainer + SideStore onto
/// *another* iPhone on the same Wi-Fi network, one page at a time.
///
/// The pages (`Stage`) gather what to install, their address (optional) and
/// the Apple ID, then have their iPhone made ready before the run starts. The
/// run is the Install tab's flow over the LAN:
///
/// 1. **Pair.** With an IP address typed in, a record saved by an earlier run
///    goes first. Otherwise run the lockdown `Pair` handshake directly against
///    `<their IP>:62078`: their iPhone shows a Trust prompt and returns a
///    lockdown pair record, which CoreDeviceProxy (`tunnel_create_usb`) uses to
///    open the tunnel. iOS 27's lockdownd won't pair over Wi-Fi — it resets the
///    connection at the first request, before any Trust prompt — so when
///    lockdownd answers but won't pair, their iPhone pairs from its own
///    Settings instead (Remote Pairing): this iPhone advertises a pairing host,
///    they pick it under Developer Mode and type the code shown here, and the
///    RPPairing file that produces opens the tunnel
///    (`tunnel_create_rppairing`). With no address typed in, the run goes
///    straight to Remote Pairing, and their iPhone is reached at the address
///    it connected from.
/// 2. **Sign in, download, sign, install** as in the one-click flow, using the
///    Apple ID picked here and the target's UDID. The SideStore builds come
///    from the same releases as on the Install tab.
/// 3. **Set up** (the SideStore builds): the pair record goes into SideStore on
///    their iPhone, as the Install tab hands this iPhone's over, so it opens
///    ready to use. It gets an identifier of its own on their iPhone, so a
///    later Side by Side pairing can't replace it.
///
/// Credentials are kept in memory only, never saved to `AccountStore` or the
/// keychain. Pair records with their iPhone are forgotten once the app is on
/// it, or on Clear: from then on only what was handed to SideStore holds one.
final class SideBySideManager: ObservableObject {

    /// Unsigned IPA from SideInstaller's latest GitHub release.
    static let releaseIPA = URL(string:
        "https://github.com/FrizzleM/SideInstaller/releases/latest/download/SideInstaller.ipa")!

    /// What the release asset is called, and what the download is saved as.
    static let ipaFileName = "SideInstaller.ipa"

    // MARK: Pages

    /// The page showing: a welcome, four numbered setup steps, then the run
    /// and how it ended.
    enum Stage: Int, Comparable {
        case welcome, app, address, account, ready, run

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }

        /// How many numbered steps the setup has before the run.
        static let numberedCount = 4

        /// The setup step's number, 1 to 4; nil for the welcome and the run.
        var number: Int? {
            (1...Self.numberedCount).contains(rawValue) ? rawValue : nil
        }

        /// The page Back leads to.
        var previous: Stage? {
            switch self {
            case .welcome: return nil
            case .app:     return .welcome
            case .address: return .app
            case .account: return .address
            case .ready:   return .account
            case .run:     return .ready
            }
        }
    }

    @Published private(set) var stage: Stage = .welcome
    /// True when the latest move was forward, so pages slide the right way.
    @Published private(set) var movingForward = true

    // MARK: Choices

    /// What to install. Remembered, as it's usually the same each time.
    @Published var app: SideBySideApp = SideBySideManager.savedApp {
        didSet { UserDefaults.standard.set(app.rawValue, forKey: Self.appKey) }
    }
    /// Which release of a SideStore build, as on the Install tab.
    @Published var channel: ReleaseChannel = .stable
    /// The other iPhone's address on this Wi-Fi network. Optional: pairing from
    /// their Settings reports it, and fills it in so a retry finds the record.
    @Published var targetIP = ""
    /// Sign with the Apple ID saved on this iPhone instead of one typed in.
    @Published var usesSavedAccount = false
    /// The Apple ID the app is signed with. Never persisted — see the note above.
    @Published var appleID = ""
    @Published var password = ""

    private static let appKey = "sideBySideApp"
    private static var savedApp: SideBySideApp {
        UserDefaults.standard.string(forKey: appKey).flatMap(SideBySideApp.init(rawValue:)) ?? .sideInstaller
    }

    // MARK: Run state

    @Published private(set) var stepStates: [SideBySideStep: StepState] = Dictionary(
        uniqueKeysWithValues: SideBySideStep.allCases.map { ($0, .pending) })
    @Published private(set) var isRunning = false
    /// True from a cancel until the run stops, which waits for the step in
    /// flight to reach a safe point.
    @Published private(set) var isCancelling = false
    @Published private(set) var finished = false
    /// What the current or last run installs, as it was when it started.
    @Published private(set) var runApp: SideBySideApp = .sideInstaller
    /// The far device's name and iOS version, once the link is open.
    @Published private(set) var targetSummary: String?
    /// Their iPhone's iOS version ("27.1"), once the link is open.
    @Published private(set) var targetOSVersion: String?
    /// How much of the download has arrived (0…1), while that step is running.
    @Published private(set) var downloadProgress: Double = 0
    /// Home-screen name of what landed on their iPhone.
    @Published private(set) var installedAppName: String?
    /// True while their iPhone has to pair from its own Settings, which it
    /// never prompts for by itself.
    @Published private(set) var pairingInSettings = false
    /// The code to type into their iPhone, once it has asked for one.
    @Published private(set) var pairingPIN: String?
    /// True while their iPhone shows a Trust prompt that has been up a moment.
    @Published private(set) var waitingForTrust = false
    /// Why the run stopped, or couldn't start.
    @Published private(set) var lastError: String?
    /// True while a pair record with someone else's iPhone is saved here.
    @Published private(set) var remembersTheirIPhone = PrivateStore.hasPeerPairings

    private var task: Task<Void, Never>?

    /// This tool's own link, so a run here never disturbs the Install tab's
    /// connection to the loopback tunnel (or the other way round).
    private let connection = DeviceConnection()
    private let deviceQueue = DispatchQueue(label: "sideinstaller.sidebyside.device")
    private let signQueue = DispatchQueue(label: "sideinstaller.sidebyside.sign")

    private var signSession: OpaquePointer?          // SignSession*
    /// The Apple ID `signSession` belongs to, so another one signs out.
    private var signedInAs: String?
    /// Where the pair record for the current target lives: a lockdown record,
    /// or an RPPairing file from Remote Pairing.
    private var pairRecordPath: String?
    /// The downloaded IPA, kept between runs so a retry doesn't fetch it again.
    private var downloadedIPA: URL?
    /// Which build `downloadedIPA` is, so only a retry for the same one skips
    /// the download.
    private var downloadedKey: String?
    /// True when `downloadedIPA` is this page's own copy, whose staging folder
    /// is ours to delete; a SideStore build lives in Documents, shared with the
    /// Install tab, and stays.
    private var ownsDownload = false
    private var signedAppPath: String?
    private var signedBundleID: String?
    private var targetUDID: String?
    private var targetName: String?
    /// True once the Local Network prompt has been raised, so it asks once.
    private var askedLocalNetwork = false
    /// Counts Trust waits, so a delayed "show" for one that has ended does
    /// nothing. Main thread only.
    private var trustWaits = 0

    private var engine: Engine { Engine.shared }

    deinit {
        if let signSession { si_sign_session_free(signSession) }
        connection.disconnect()
        discardDownload()
    }

    // MARK: - Moving between pages

    /// Shows `next`. The direction is published a beat before the page
    /// changes, so the page leaving is drawn with it and slides the right way.
    @MainActor
    func go(to next: Stage) {
        guard next != stage else { return }
        let forward = next > stage
        guard forward != movingForward else {
            stage = next
            return
        }
        movingForward = forward
        DispatchQueue.main.async { self.stage = next }
    }

    /// One page back; nothing while a run goes.
    @MainActor
    func goBack() {
        guard !isRunning, let previous = stage.previous else { return }
        if stage == .run { lastError = nil }
        go(to: previous)
    }

    /// From a stopped run back to the summary, to change what it uses.
    @MainActor
    func editDetails() {
        guard !isRunning else { return }
        lastError = nil
        go(to: .ready)
    }

    /// From a finished run back to the choice of app, for another one on the
    /// same iPhone. The Apple ID stays.
    @MainActor
    func installAnother() {
        guard !isRunning else { return }
        resetRun()
        go(to: .app)
    }

    /// Ends with a finished run: clears their details and goes back to the
    /// start.
    @MainActor
    func finishAndReset() {
        guard !isRunning else { return }
        clear()
        go(to: .welcome)
    }

    // MARK: - Derived

    /// What's wrong with the address typed in; nil when it's usable or empty,
    /// since it's optional (see `targetIP`).
    var addressProblem: String? {
        let ip = Self.tidy(targetIP)
        guard !ip.isEmpty else { return nil }
        guard Self.isIPv4(ip) else {
            return L("“%@” isn't an IPv4 address. It should look like 192.168.1.42.", ip)
        }
        // Pointed at this iPhone, the whole run would talk to itself.
        guard !NetworkStatus.isOwnAddress(ip) else {
            return L("%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.", ip)
        }
        return nil
    }

    /// True when the Apple ID saved on this iPhone is the one picked, and
    /// there still is one.
    var signsWithSavedAccount: Bool {
        usesSavedAccount && AccountStore.shared.active != nil
    }

    /// The Apple ID and password the run signs with; nil until there are both.
    var credentials: (id: String, password: String)? {
        if signsWithSavedAccount {
            let store = AccountStore.shared
            let id = store.activeAppleID, pw = store.activePassword
            return id.isEmpty || pw.isEmpty ? nil : (id, pw)
        }
        let id = Self.tidy(appleID)
        return id.isEmpty || password.isEmpty ? nil : (id, password)
    }

    var hasCredentials: Bool { credentials != nil }

    /// This iPhone's Wi-Fi address, shown as an example of what theirs looks like.
    var ownWiFiAddress: String? {
        NetworkStatus.interfaces().first { $0.name == "en0" }?.ipv4
    }

    /// Fraction across the run's steps, for the progress bar. The download and
    /// install steps also fill their own share as they go.
    var overallProgress: Double {
        let steps = SideBySideStep.steps(for: runApp)
        let done = Double(steps.filter { stepStates[$0] == .done }.count)
        var partial = 0.0
        if stepStates[.download] == .active { partial = downloadProgress }
        if stepStates[.install] == .active { partial = engine.installProgress }
        return min(1, (done + partial) / Double(steps.count))
    }

    /// Their iOS version, when SideInstaller went onto an iPhone too old to
    /// pair itself; it then needs a pairing file made on a computer.
    var versionTooOldToSelfPair: String? {
        guard runApp == .sideInstaller, let version = targetOSVersion,
              !Self.version(version, isAtLeast: Engine.minimumOSMajorVersion) else { return nil }
        return version
    }

    // MARK: - The run

    /// Starts the run from the summary, or again after it stopped. Checks what
    /// it can first, and says why it can't start instead of starting.
    @MainActor
    func start() {
        guard !isRunning else { return }
        let typed = Self.tidy(targetIP)
        let ip = typed.isEmpty ? nil : typed
        if let problem = addressProblem {
            lastError = ErrorHelp.explained(problem)
            return
        }
        guard let credentials else {
            lastError = ErrorHelp.explained(L("Enter the Apple ID to sign with, and its password."))
            return
        }
        engine.refreshNetworkStatus()
        guard engine.wifiConnected else {
            lastError = ErrorHelp.explained(L("Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work."))
            return
        }
        // A different Apple ID than the session was opened with invalidates it.
        if let signedInAs, signedInAs.caseInsensitiveCompare(credentials.id) != .orderedSame {
            signOut()
        }

        let app = self.app
        let channel = self.channel
        resetRun()
        runApp = app
        isRunning = true
        // Their iPhone has the user's attention while it pairs, and a locked
        // screen would stop the run, with the code on it.
        UIApplication.shared.isIdleTimerDisabled = true
        go(to: .run)
        let build = app.source == nil ? app.displayName : "\(channel.displayName) \(app.displayName)"
        engine.log("=== Side by Side: installing \(build) onto \(ip ?? "the iPhone that pairs from its Settings") ===")

        task = Task { @MainActor in
            do {
                await ensureLocalNetwork()
                let address = try await connectToTarget(typedIP: ip, app: app)
                try checkCompatibility(of: app)
                try await signIn(id: credentials.id, pw: credentials.password)
                try await download(app, channel: channel)
                try await signApp(app)
                try await install(ip: address)
                try await setUp(app, ip: address, appleID: credentials.id)
                finishSuccess()
            } catch let error where error is CancellationError || Task.isCancelled {
                // A blocking call that was under way when Cancel was tapped can
                // still end in its own error; the run was cancelled all the same.
                engine.log("Side by Side: cancelled\(error is CancellationError ? "" : " (\(short(error)))").")
                // Back to the summary it started from, as if it hadn't run.
                for step in SideBySideStep.allCases { stepStates[step] = .pending }
                downloadProgress = 0
                go(to: .ready)
            } catch {
                let message = short(error)
                lastError = message
                engine.log("⛔️ Side by Side stopped: \(message)")
                failActiveStep(to: .failed)
            }
            pairingInSettings = false
            pairingPIN = nil
            setTrustWait(false)
            remembersTheirIPhone = PrivateStore.hasPeerPairings
            isRunning = false
            isCancelling = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    /// Cancels the run at the next step boundary. Blocking FFI calls (e.g.
    /// waiting on the Trust prompt) can't be interrupted, so it takes effect once
    /// the current call returns. Waiting for them to pair from Settings stops
    /// straight away.
    @MainActor
    func cancel() {
        guard isRunning, !isCancelling else { return }
        isCancelling = true
        task?.cancel()
    }

    /// Frees the Apple ID session so the next run signs in again. Called when
    /// the Apple ID changes and by Clear, so another person's session isn't kept.
    ///
    /// Not main-actor isolated: the work runs on `signQueue`, and the session
    /// pointer isn't `Sendable`.
    func signOut() {
        signedInAs = nil
        // Freed on `signQueue`, which owns `signSession`. It's serial, so this
        // can't race the next sign-in.
        signQueue.async { [weak self] in
            guard let self, let session = self.signSession else { return }
            si_sign_session_free(session)
            self.signSession = nil
        }
    }

    /// Closes the link to their iPhone and deletes every pair record saved with
    /// someone else's, so this iPhone can't reach theirs again without pairing
    /// anew. Their address goes too: it was kept to find those records.
    @MainActor
    private func forgetTheirIPhone() {
        disconnectTheirIPhone()
        PrivateStore.forgetPeerPairings()
        pairRecordPath = nil
        targetIP = ""
        remembersTheirIPhone = false
    }

    /// Closes the link to their iPhone on `deviceQueue`, which owns the
    /// connection.
    ///
    /// Not main-actor isolated, like `signOut`: the queued closure holds
    /// `self`, which isn't `Sendable`, and only reads `connection`, a `let`.
    private func disconnectTheirIPhone() {
        deviceQueue.async { [weak self] in self?.connection.disconnect() }
    }

    /// Clears their details: credentials, pairings and the download. What to
    /// install is kept.
    @MainActor
    func clear() {
        guard !isRunning else { return }
        signOut()
        forgetTheirIPhone()
        discardDownload()
        signedAppPath = nil
        signedBundleID = nil
        targetUDID = nil
        targetName = nil
        appleID = ""
        password = ""
        usesSavedAccount = false
        resetRun()
    }

    @MainActor
    private func resetRun() {
        for step in SideBySideStep.allCases { stepStates[step] = .pending }
        downloadProgress = 0
        lastError = nil
        finished = false
        pairingInSettings = false
        pairingPIN = nil
        setTrustWait(false)
        targetSummary = nil
        targetOSVersion = nil
        installedAppName = nil
    }

    @MainActor
    private func setStep(_ step: SideBySideStep, _ state: StepState) {
        stepStates[step] = state
    }

    @MainActor
    private func failActiveStep(to state: StepState) {
        for step in SideBySideStep.allCases
        where stepStates[step] == .active || stepStates[step] == .waiting {
            stepStates[step] = state
        }
    }

    @MainActor
    private func finishSuccess() {
        finished = true
        let name = installedAppName ?? runApp.displayName
        engine.log("✅ Side by Side done — \(name) is on their iPhone. One trust step left, on their side.")
        // Theirs pairs itself, or SideStore now holds the record: this iPhone
        // has no more use for it.
        forgetTheirIPhone()
        engine.log("Side by Side: forgot the pairing with their iPhone.")
    }

    // MARK: - Step 0: Local Network permission

    /// Triggers the Local Network prompt before the first connect. iOS silently
    /// blocks local-network connections until it's granted.
    @MainActor
    private func ensureLocalNetwork() async {
        guard !askedLocalNetwork else { return }
        askedLocalNetwork = true
        engine.log("Checking Local Network permission — reaching their iPhone needs it…")
        let localNetwork = LocalNetworkAuthorization()
        if await localNetwork.request(timeout: 8) {
            engine.log("Local Network OK.")
        } else {
            engine.log("⚠️ Local Network didn't confirm. If nothing connects, turn it on in Settings › SideInstaller › Local Network.")
        }
    }

    // MARK: - Step 1: pair with the target and open the link

    /// Opens the link to their iPhone, and returns the address it's reached at:
    /// the one typed in, or the one it paired from.
    @MainActor
    private func connectToTarget(typedIP: String?, app: SideBySideApp) async throws -> String {
        try Task.checkCancellation()
        setStep(.connect, .active)
        // A pairing their SideStore keeps gets a record of its own on their
        // iPhone, which no later Side by Side pairing can replace.
        let identifier = app.source == nil ? nil : UUID().uuidString.lowercased()
        // With no address there's no saved record to find and no lockdownd to
        // ask, so their iPhone pairs from its Settings.
        var outcome = ConnectOutcome.needsRemotePairing
        if let typedIP {
            outcome = try await onDeviceQueue { try self.performConnect(ip: typedIP) }
        }
        let target: ConnectedTarget
        switch outcome {
        case let .connected(connected):
            target = connected
        case .needsRemotePairing:
            target = try await connectByRemotePairing(typedIP: typedIP, identifier: identifier)
        }
        targetSummary = target.summary
        targetOSVersion = target.osVersion
        targetUDID = target.udid
        targetName = target.name
        // Filled in so a retry finds the record saved for it.
        targetIP = target.address
        remembersTheirIPhone = true
        setStep(.connect, .done)
        return target.address
    }

    private struct ConnectedTarget {
        let summary: String
        let osVersion: String?
        let udid: String?
        let name: String?
        let address: String
    }

    /// How far connecting got without their iPhone's Settings.
    private enum ConnectOutcome {
        case connected(ConnectedTarget)
        /// lockdownd answered but won't pair over Wi-Fi, so their iPhone has to
        /// pair from its own Settings.
        case needsRemotePairing
    }

    /// Opens the link with a record saved by an earlier run, or by pairing over
    /// lockdown. Runs on `deviceQueue`.
    private func performConnect(ip: String) throws -> ConnectOutcome {
        // Whether anything answers there at all, in seconds: lockdownd's own
        // connect waits out the system's minute-long timeout first. Silence is
        // the address or the network, which no pairing gets past; a refusal is
        // their iPhone, there but not listening on Wi-Fi.
        let reach = NetworkStatus.probeConnect(host: ip, port: DeviceConnection.lockdownPort, timeout: 6000)
        engine.log("Their iPhone at \(ip), lockdownd's port \(DeviceConnection.lockdownPort): \(reach).")
        guard reach.answered else { throw EngineError.message(Self.unreachableAdvice(ip: ip)) }

        // Records saved by an earlier run first: pairing needs them at their
        // iPhone, and uses one of its pairing slots.
        if try connectWithSavedRecord(PrivateStore.peerRemotePairing(host: ip), ip: ip) {
            return .connected(try describeTarget(ip: ip))
        }
        let record = PrivateStore.peerPairRecord(host: ip)
        if try connectWithSavedRecord(record, ip: ip) {
            return .connected(try describeTarget(ip: ip))
        }
        guard reach == .connected else {
            engine.log("lockdownd on \(ip) refuses connections over Wi-Fi — iOS 27 only pairs over a network from its own Settings. Switching to Remote Pairing.")
            return .needsRemotePairing
        }

        engine.log("Asking \(ip) to pair — their iPhone has to be unlocked, and they have to tap Trust …")
        let data: Data
        do {
            // Shown once their iPhone answers, which is when it can prompt, and
            // over once the prompt is answered, before the link opens.
            defer { showTrustWait(false) }
            data = try connection.lockdownPairRecordDirect(
                hosts: [ip],
                hostID: CompositePairingFile.hostID,
                systemBUID: CompositePairingFile.systemBUID,
                hostName: "SideInstaller",
                onConnected: { [weak self] in self?.showTrustWait(true) })
        } catch let error as DeviceConnection.LockdownPairError {
            if error.userDeclined {
                throw EngineError.message(L("They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust."))
            }
            // No answer at all is the address or the network, which pairing
            // another way can't get past. A refusal comes from their iPhone:
            // it's there, and lockdownd just isn't listening on Wi-Fi.
            if error.stage == .connect, !DeviceConnection.wasRefused(error.underlying) {
                throw EngineError.message(Self.unreachableAdvice(ip: ip))
            }
            engine.log("lockdownd on \(ip) won't pair over Wi-Fi (\(error)) — iOS 27 only pairs over a network from its own Settings. Switching to Remote Pairing.")
            return .needsRemotePairing
        }
        try data.write(to: record, options: .atomic)
        engine.log("Paired with \(ip) (\(data.count)-byte record). Opening the tunnel over CoreDeviceProxy …")
        try connection.connect(deviceIP: ip, pairingFilePath: record.path, allowLockdownMinting: false)
        pairRecordPath = record.path
        return .connected(try describeTarget(ip: ip))
    }

    /// Opens the link with `record`, saved by an earlier run. False when there
    /// is none, or it didn't open a link and pairing again might.
    private func connectWithSavedRecord(_ record: URL, ip: String) throws -> Bool {
        guard fileSize(record.path) > 0 else { return false }
        engine.log("Trying the pair record already saved for \(ip) (\(record.lastPathComponent)) …")
        do {
            try connection.connect(deviceIP: ip, pairingFilePath: record.path, allowLockdownMinting: false)
        } catch let error as DeviceConnection.TunnelError where !error.repairingCouldHelp {
            // The link never reached their iPhone, so pairing again won't either.
            throw EngineError.message(Self.tunnelAdvice(error, ip: ip))
        } catch {
            engine.log("That record didn't open a link (\(error)). Pairing again…")
            return false
        }
        pairRecordPath = record.path
        return true
    }

    /// Shows the Trust card while their iPhone may be showing its prompt.
    /// Called from `deviceQueue`. A lockdownd that won't pair answers at once,
    /// so only a wait that lasts a moment shows the card, and it never flashes.
    private func showTrustWait(_ waiting: Bool) {
        DispatchQueue.main.async {
            self.trustWaits += 1
            guard waiting else {
                self.setTrustWait(false)
                return
            }
            let wait = self.trustWaits
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard self.trustWaits == wait else { return }
                self.setTrustWait(true)
            }
        }
    }

    /// Main thread only.
    private func setTrustWait(_ waiting: Bool) {
        waitingForTrust = waiting
        let state = stepStates[.connect]
        guard state == .active || state == .waiting else { return }
        stepStates[.connect] = waiting ? .waiting : .active
    }

    /// Has their iPhone pair from its own Settings — the way iOS 27 pairs over
    /// a network — then opens the link with the RPPairing file that produces,
    /// at the address their iPhone connected from. That's where it is, even if
    /// a different address was typed in.
    @MainActor
    private func connectByRemotePairing(typedIP: String?, identifier: String?) async throws -> ConnectedTarget {
        let pairingFile: URL
        if let typedIP {
            pairingFile = PrivateStore.peerRemotePairing(host: typedIP)
        } else {
            pairingFile = PrivateStore.unaddressedPeerRemotePairing
            // A leftover would lend this pairing its keys.
            try? FileManager.default.removeItem(at: pairingFile)
        }
        let paired = try await pairFromSettings(record: pairingFile, identifier: identifier)
        let ip = paired.address
        // Their own Settings lists this iPhone's host too.
        guard !NetworkStatus.isOwnAddress(ip) else {
            try? FileManager.default.removeItem(atPath: paired.path)
            throw EngineError.message(L("The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab."))
        }
        if let typedIP, typedIP != ip {
            engine.log("Their iPhone paired from \(ip), not \(typedIP) — reaching it there.")
        }
        // Filed under the address it's reached at, where a retry looks for it.
        let recordPath = Self.move(paired.path, to: PrivateStore.peerRemotePairing(host: ip).path)
        setStep(.connect, .active)
        engine.log("Paired with their \(paired.deviceModel) at \(ip). Opening the tunnel over Remote Pairing …")
        return try await onDeviceQueue {
            do {
                try self.connection.connect(deviceIP: ip, pairingFilePath: recordPath,
                                            allowLockdownMinting: false)
            } catch let error as DeviceConnection.TunnelError {
                throw EngineError.message(Self.tunnelAdvice(error, ip: ip))
            }
            self.pairRecordPath = recordPath
            return try self.describeTarget(ip: ip)
        }
    }

    /// Advertises this iPhone as a pairing host and waits until their iPhone
    /// has paired with it from Settings, showing the code it asks for. The
    /// instructions stay up until then; Cancel stops the wait.
    @MainActor
    private func pairFromSettings(record: URL, identifier: String?) async throws -> PairingController.PairedDevice {
        try Task.checkCancellation()
        pairingInSettings = true
        setStep(.connect, .waiting)
        defer {
            pairingInSettings = false
            pairingPIN = nil
        }
        engine.log("Waiting for them to pair: on their iPhone, Settings › Privacy & Security › Developer Mode › “Pair with \(PairingController.peerHostName)”, then the code shown here.")
        do {
            return try await withTaskCancellationHandler {
                try await PairingController.shared.pairPeer(outPath: record.path,
                                                            identifier: identifier) { [weak self] pin in
                    self?.pairingPIN = pin
                }
            } onCancel: {
                Task { @MainActor in PairingController.shared.cancelPeer() }
            }
        } catch PairingController.PairingError.busy {
            throw EngineError.message(L("SideInstaller is already waiting for an iPhone to pair with it — from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again."))
        } catch let PairingController.PairingError.failed(message) {
            throw EngineError.message(L("Pairing with their iPhone didn't finish: %@", message))
        }
    }

    /// Their iPhone's name, iOS version and UDID, read over the open link.
    private func describeTarget(ip: String) throws -> ConnectedTarget {
        engine.log("Tunnel + RSD handshake established with \(ip).")
        engine.log(try connection.rsdSummary())

        var values: [String: String] = [:]
        let info = try connection.deviceInfo()
        if info.isEmpty {
            engine.log("Device info: (lockdownd returned no values)")
        } else {
            engine.log("Device info:")
            for (key, value) in info { values[key] = value; engine.log("  \(key) = \(value)") }
        }
        let name = values["DeviceName"] ?? L("device")
        let version = values["ProductVersion"]
        let summary = version.map { "\(name) · iOS \($0)" } ?? name
        return ConnectedTarget(summary: summary,
                               osVersion: version,
                               udid: values["UniqueDeviceID"],
                               name: values["DeviceName"],
                               address: ip)
    }

    /// Stops before anything is signed when what's being installed can't work
    /// with the pairing their iPhone gave: from iOS 26.4 on, lockdownd hangs up
    /// on a lockdown record that SideStore brings through LocalDevVPN, and only
    /// iOS 27 pairs from its Settings, which gives the RPPairing record that
    /// works. SideInstaller pairs itself, so it isn't stopped here.
    @MainActor
    private func checkCompatibility(of app: SideBySideApp) throws {
        guard app.source != nil, let version = targetOSVersion, let path = pairRecordPath else { return }
        let kind = PairingFileKind.of(path: path)
        guard kind.hasLockdown, !kind.hasRemotePairing, Self.version(version, isAtLeast: 26, 4) else { return }
        engine.log("Their iPhone runs iOS \(version) and paired over lockdown only: from iOS 26.4 on, lockdownd hangs up on that record when \(app.displayName) brings it through LocalDevVPN. Stopping before anything is signed.")
        throw EngineError.message(ErrorHelp.explained(L("Their iPhone runs iOS %@. From iOS 26.4 on, %@ can't use the pairing their iPhone gives over Wi-Fi. iOS 27 pairs from its own Settings instead, which works: update their iPhone, then try again with the IP address left empty.", version, app.displayName)))
    }

    /// What to say when the link to their iPhone didn't come up. The error's
    /// own advice is about the Install tab's loopback VPN, which Side by Side
    /// doesn't use.
    private static func tunnelAdvice(_ error: DeviceConnection.TunnelError, ip: String) -> String {
        switch error.kind {
        case TunnelFailureRsdUnreachable where DeviceConnection.wasRefused(error.underlying):
            return L("Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.", ip)
        case TunnelFailureRsdUnreachable:
            return unreachableAdvice(ip: ip)
        default:
            return L("The link to their iPhone didn't come up: %@", error.underlying.description)
        }
    }

    private static func unreachableAdvice(ip: String) -> String {
        L("Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.", ip)
    }

    // MARK: - Step 2: Apple ID sign-in

    @MainActor
    private func signIn(id: String, pw: String) async throws {
        if signSession != nil, signedInAs?.caseInsensitiveCompare(id) == .orderedSame {
            engine.log("Already signed in as \(LogRedactor.maskAppleID(id)) — skipping.")
            setStep(.signIn, .done)
            return
        }
        setStep(.signIn, .active)

        // Anisette servers go down often, so with Auto on try each one before
        // giving up. A server picked in Settings is the only one tried.
        let servers = engine.anisetteCandidates()
        let dir = PrivateStore.isideload.path
        engine.twoFactorWasCancelled = false
        var failures = AnisetteServer.SignInFailures()
        var appleRefusals = AnisetteServer.AppleRefusals(servers: engine.anisetteServers)
        var appleUnreachable = 0

        for (index, anisette) in servers.enumerated() {
            try Task.checkCancellation()
            if appleRefusals.rulesOut(anisette) {
                engine.log("Side by Side: skipping anisette \(index + 1)/\(servers.count): Apple has refused the device sign-in reports through it.")
                failures.skip()
                continue
            }
            do {
                let summary = try await onSignQueue {
                    try self.performSignIn(id: id, pw: pw, anisette: anisette, dir: dir)
                }
                engine.anisetteSignedIn(anisette)
                signedInAs = id
                engine.log("Side by Side: signed in (\(summary)).")
                setStep(.signIn, .done)
                return
            } catch let error as EngineError {
                let failure = error.errorDescription ?? "sign-in failed"
                // A cancelled 2FA prompt isn't the server's fault.
                if engine.twoFactorWasCancelled {
                    throw EngineError.message(L("Two-factor verification was cancelled."))
                }
                // A locked account fails everywhere, and retrying keeps it locked.
                if Engine.isAccountLocked(failure) {
                    engine.log("Apple has locked this Apple Account: \(failure)")
                    throw EngineError.accountLocked
                }
                if Engine.isEmailUnverifiedError(failure) {
                    engine.log("Apple wants this Apple Account's email address verified first: \(failure)")
                    throw EngineError.emailUnverified
                }
                // Bad credentials fail everywhere, and retrying risks a lockout.
                if Engine.isCredentialError(failure) {
                    engine.log("Apple ID credentials rejected: \(failure)")
                    throw EngineError.message(Engine.credentialErrorMessage)
                }
                // Not logged in through an Android-ADI server (-80046).
                if Engine.isAndroidADISkip(failure) {
                    engine.log("Side by Side: skipping anisette \(index + 1)/\(servers.count): Apple refuses the sign-in token for anisette from its Android library (-80046).")
                    appleRefusals.recordTokenRefusal(anisette)
                    failures.skip()
                    if failures.tried == 0, appleRefusals.rulesOutAll(servers[(index + 1)...]) {
                        throw EngineError.message(engine.androidADIRefusalMessage(server: anisette))
                    }
                    continue
                }
                engine.log("Side by Side: anisette \(index + 1)/\(servers.count) failed: \(failure)")
                failures.failed(anisette, error: failure)
                engine.anisetteFailed(anisette, error: failure)
                if Engine.isAppleRateLimit(failure) {
                    engine.log("Side by Side: Apple is rate-limiting sign-in (HTTP 429) — stopping.")
                    throw EngineError.message(Engine.appleRateLimitMessage)
                }
                // Apple refuses a reported device through every server alike;
                // see `AnisetteServer.AppleRefusals`.
                if Engine.isAppleOutdatedMacRefusal(failure) {
                    appleRefusals.recordOutdated(anisette)
                }
                if Engine.isAppleTokenRefusal(failure) {
                    appleRefusals.recordTokenRefusal(anisette)
                    if appleRefusals.rulesOutAll(servers[(index + 1)...]) {
                        engine.log("Side by Side: Apple refused the sign-in token (-80046) — stopping.")
                        throw EngineError.message(engine.appleTokenRefusalMessage(through: anisette))
                    }
                }
                if Engine.isAppleServiceRefusal(failure) {
                    appleRefusals.record(anisette)
                    if appleRefusals.endsSignIn(remaining: servers[(index + 1)...]) {
                        engine.log("Side by Side: Apple's sign-in server refused \(appleRefusals.count) attempts with HTTP 503 — stopping.")
                        throw EngineError.message(Engine.appleServiceRefusalMessage)
                    }
                }
                // Every anisette server starts with the same request to Apple, so
                // when that can't even be sent, more of them won't help.
                if Engine.isAppleUnreachable(failure) {
                    appleUnreachable += 1
                    if let message = await engine.appleUnreachableStop(
                        failures: appleUnreachable, logPrefix: "Side by Side: ") {
                        throw EngineError.message(message)
                    }
                } else {
                    appleUnreachable = 0
                }
            }
        }
        throw EngineError.message(engine.anisetteSignInFailure(failures))
    }

    /// One sign-in attempt against a specific anisette server. Uses the machine
    /// name `SideInstaller`, so an existing certificate is recognized as reusable.
    private func performSignIn(id: String, pw: String, anisette: String, dir: String) throws -> String {
        defer { engine.endTwoFactor() }
        engine.log("Apple ID sign-in for \(LogRedactor.maskAppleID(id)) via anisette \(Engine.oneLine(anisette)) …")
        var session: OpaquePointer?
        var summary: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        // 0 = don't save the session: it may be someone else's Apple ID.
        let rc = si_apple_signin(id, pw, anisette, "SideInstaller", dir, 0,
                                 sideBySideTwoFactorCallback, nil,
                                 &session, &summary, &error)
        if rc == 0 {
            if let old = signSession { si_sign_session_free(old) }
            signSession = session
            let text = summary.map { String(cString: $0) } ?? ""
            summary.map { si_string_free($0) }
            return text
        } else {
            let message = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message(message)
        }
    }

    // MARK: - Step 3: download the build

    @MainActor
    private func download(_ app: SideBySideApp, channel: ReleaseChannel) async throws {
        try Task.checkCancellation()
        let key = app.source == nil ? app.rawValue : "\(app.rawValue)-\(channel.rawValue)"
        if let existing = downloadedIPA, downloadedKey == key,
           FileManager.default.fileExists(atPath: existing.path) {
            engine.log("\(app.displayName) IPA already downloaded — skipping.")
            setStep(.download, .done)
            return
        }
        discardDownload()
        setStep(.download, .active)
        downloadProgress = 0
        let file: URL
        if let source = app.source {
            file = try await downloadBuild(source, channel: channel)
        } else {
            file = try await downloadSideInstaller()
        }
        downloadedIPA = file
        downloadedKey = key
        ownsDownload = app.source == nil
        downloadProgress = 1
        engine.log("\(app.displayName) IPA ready at \(file.path) (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize(file.path)), countStyle: .file))).")
        setStep(.download, .done)
    }

    /// SideInstaller's latest release, into a staging folder of its own.
    @MainActor
    private func downloadSideInstaller() async throws -> URL {
        engine.log("Fetching the latest SideInstaller release from \(Self.releaseIPA.absoluteString) …")
        do {
            let file = try await SideStoreDownloader.fetchDirect(
                Self.releaseIPA, named: Self.ipaFileName) { fraction in
                    Task { @MainActor in self.downloadProgress = fraction }
                }
            // Validate now, so an error page or truncated download doesn't fail
            // later during signing.
            guard IPALibrary.looksLikeIPA(file) else {
                try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
                throw EngineError.message(L("The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute."))
            }
            return file
        } catch let error as SideStoreDownloader.DownloadError {
            throw EngineError.message(L("Couldn't download the latest SideInstaller release: %@", error.description))
        }
    }

    /// A SideStore build's latest release on `channel`, as the Install tab
    /// fetches it: into Documents, skipped when the copy there is still the one
    /// GitHub serves, and an IPA the user put there themselves is used as it is.
    @MainActor
    private func downloadBuild(_ source: InstallSource, channel: ReleaseChannel) async throws -> URL {
        let onDisk = IPALibrary.entry(source: source, channel: channel)
        if let onDisk, onDisk.isImported {
            engine.log("Using \(onDisk.url.lastPathComponent), which you put in Documents, as the Install tab does.")
            return onDisk.url
        }
        engine.log("Fetching the \(channel.displayName) \(source.displayName) release …")
        let report: @Sendable (Double) -> Void = { [weak self] fraction in
            Task { @MainActor in self?.downloadProgress = fraction }
        }
        do {
            let path = try await SideStoreDownloader.$reportProgress.withValue(report) {
                try await SideStoreDownloader.downloadLatest(source: source, channel: channel) { [weak self] line in
                    self?.engine.log(line)
                }
            }
            return URL(fileURLWithPath: path)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            // Offline or blocked: a copy an earlier run left behind will do.
            if let onDisk {
                engine.log("⚠️ Download failed (\(short(error))) — using \(onDisk.url.lastPathComponent) already in Documents instead.")
                return onDisk.url
            }
            throw EngineError.message(L("Couldn't download %@: %@", source.displayName, short(error)))
        }
    }

    /// Delete the downloaded IPA when it's this page's own copy, with the
    /// staging folder it lives in.
    private func discardDownload() {
        if ownsDownload, let file = downloadedIPA {
            try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
        }
        downloadedIPA = nil
        downloadedKey = nil
        ownsDownload = false
    }

    // MARK: - Step 4: sign for their device

    @MainActor
    private func signApp(_ app: SideBySideApp) async throws {
        try Task.checkCancellation()
        guard let session = signSession else { throw EngineError.message(L("Not signed in.")) }
        guard let ipa = downloadedIPA else {
            throw EngineError.message(app.source == nil ? L("No SideInstaller IPA downloaded.")
                                                        : L("No SideStore IPA downloaded."))
        }
        // Their UDID is registered with the team before the profile is asked
        // for, or Apple refuses it with error 8220.
        let udid = targetUDID ?? ""
        let name = targetName ?? ""
        if udid.isEmpty {
            engine.log("⚠️ No UDID captured from their iPhone — signing may fail with error 8220.")
        }
        setStep(.sign, .active)
        let path = try await onSignQueue {
            try self.performSign(session: session, ipa: ipa.path, udid: udid, deviceName: name)
        }
        signedAppPath = path
        let info = Self.bundleInfo(at: path)
        signedBundleID = info?.id
        installedAppName = info?.name ?? app.homeScreenName
        setStep(.sign, .done)
    }

    private func performSign(session: OpaquePointer, ipa: String,
                             udid: String, deviceName: String) throws -> String {
        engine.log("Signing \(ipa) for \(udid.isEmpty ? "their iPhone" : udid) …")
        var signed: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        // No bundled pairing file (only AltStore takes one), and no Increased
        // Memory Limit: SideInstaller has no use for it, and the SideStore
        // builds re-register their App IDs without it. Every app gets its app
        // group, as on the Install tab.
        let rc = si_sign_ipa(session, ipa, udid, deviceName, nil, 0, 1, &signed, &error)
        if rc == 0 {
            let path = signed.map { String(cString: $0) } ?? ""
            signed.map { si_string_free($0) }
            engine.log("Signed bundle at \(path)")
            return path
        } else {
            let message = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            engine.log("Sign FAILED: \(message)")
            // Same errors as the Install tab, worded for another person's
            // account and iPhone.
            if Engine.isCertExistsError(message) {
                throw EngineError.message(L("Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise."))
            }
            if Engine.isAppIDLimitError(message) { throw Self.explained(.appIDLimit) }
            if Engine.isUnderageError(message) { throw Self.explained(.underage) }
            if Engine.isEmailUnverifiedError(message) { throw Self.explained(.emailUnverified) }
            if Engine.isDeviceRegistrationError(message) {
                throw EngineError.message(L("Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@", message))
            }
            throw EngineError.message(L("Signing failed: %@", message))
        }
    }

    /// `error`'s message, marked as one that says how to fix it.
    private static func explained(_ error: EngineError) -> EngineError {
        .message(ErrorHelp.explained(error.errorDescription ?? String(describing: error)))
    }

    /// The bundle id and Home Screen name (display name, else bundle name) of
    /// the signed `.app`.
    private static func bundleInfo(at path: String) -> (id: String?, name: String?)? {
        let plist = (path as NSString).appendingPathComponent("Info.plist")
        guard let data = FileManager.default.contents(atPath: plist),
              let dict = (try? PropertyListSerialization.propertyList(from: data, options: [],
                                                                      format: nil)) as? [String: Any]
        else { return nil }
        let name = (dict["CFBundleDisplayName"] as? String) ?? (dict["CFBundleName"] as? String)
        return (dict["CFBundleIdentifier"] as? String, name?.isEmpty == false ? name : nil)
    }

    // MARK: - Step 5: install over AFC + installation_proxy

    @MainActor
    private func install(ip: String) async throws {
        try Task.checkCancellation()
        guard let bundle = signedAppPath else { throw EngineError.message(L("No signed bundle to install.")) }
        guard let record = pairRecordPath else { throw EngineError.message(L("No pair record for their iPhone.")) }
        setStep(.install, .active)
        engine.installProgress = 0
        do {
            try await onDeviceQueue {
                // iOS drops the idle tunnel during sign-in and signing, and
                // `isConnected` doesn't detect it, so reconnect first.
                self.engine.log("Refreshing the link to \(ip) before installing …")
                do {
                    try self.connection.connect(deviceIP: ip, pairingFilePath: record,
                                                allowLockdownMinting: false)
                } catch let error as DeviceConnection.TunnelError {
                    throw EngineError.message(Self.tunnelAdvice(error, ip: ip))
                }
                guard self.connection.isConnected else {
                    throw EngineError.message(L("The link to their iPhone dropped — start again."))
                }
                self.engine.log("Installing the signed bundle via AFC + installation_proxy …")
                try self.connection.installSignedApp(bundlePath: bundle)
                self.engine.log("Install request completed.")
            }
        } catch where Engine.isAppLimitError(String(describing: error)) {
            engine.log("installd on their iPhone refused the app: \(error)")
            throw EngineError.message(ErrorHelp.explained(L("Their iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. They need to delete one, then you can try again.")))
        }
        engine.installProgress = 1
        setStep(.install, .done)
    }

    // MARK: - Step 6: hand SideStore its pairing file

    /// Puts the pair record into SideStore on their iPhone, the way the
    /// Install tab hands over this iPhone's (`Engine.performWritePairing`): the
    /// file older builds read, the split files and settings newer ones need,
    /// the anisette settings that get past Apple's -80046, and the signing
    /// certificate, so it opens ready to go. Only the first is required;
    /// failing the others only logs. Nothing for SideInstaller, which pairs
    /// itself.
    @MainActor
    private func setUp(_ app: SideBySideApp, ip: String, appleID: String) async throws {
        guard let source = app.source, let home = source.sideStoreHome else { return }
        try Task.checkCancellation()
        guard let record = pairRecordPath else { throw EngineError.message(L("No pair record for their iPhone.")) }
        guard let bundleID = signedBundleID else { throw EngineError.message(L("No signed bundle to install.")) }
        setStep(.setUp, .active)
        let udid = targetUDID
        let appName = app.homeScreenName
        // Built on the sign queue, where every isideload call runs.
        let certificate = await certificateHandOff(for: app, appleID: appleID)
        do {
            try await onDeviceQueue {
                if !self.connection.isConnected {
                    try self.connection.connect(deviceIP: ip, pairingFilePath: record,
                                                allowLockdownMinting: false)
                }
                let pairing = try Self.pairingFileForSideStore(at: record, udid: udid)
                let rel = source.pairingRemoteRelativePath
                self.engine.log("Writing the pairing file into \(bundleID) /Documents/\(rel) …")
                let written = try self.connection.writeFile(intoBundleID: bundleID,
                                                            remoteRelativePath: rel, data: pairing)
                self.engine.log("Pairing file written into \(appName) on their iPhone and read back VERIFIED (\(written) bytes).")
                self.handOffSplitPairing(pairing, bundleID: bundleID, appName: appName, home: home, udid: udid)
                self.handOffAnisette(bundleID: bundleID, appName: appName, home: home)
                if let certificate {
                    self.handOffCertificate(certificate, bundleID: bundleID, appName: appName, home: home)
                }
            }
        } catch {
            throw EngineError.message(L("%@ is on their iPhone, but its pairing file couldn't be added (%@). Run Side by Side again, or import a pairing file in %@.",
                                        app.displayName, short(error), appName))
        }
        setStep(.setUp, .done)
    }

    /// The pair record as SideStore reads it: an XML plist, since it reads the
    /// file as text, and a lockdown record with their UDID in it, which the
    /// `Pair` answer leaves out and minimuxer needs. An RPPairing record goes
    /// as it is, as the Install tab hands one over.
    private static func pairingFileForSideStore(at path: String, udid: String?) throws -> Data {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let kind = PairingFileKind.of(data: data)
        guard kind.isUsable,
              var dict = (try PropertyListSerialization.propertyList(from: data, options: [],
                                                                     format: nil)) as? [String: Any]
        else { throw EngineError.message(L("No pair record for their iPhone.")) }
        if kind.hasLockdown, let udid, !udid.isEmpty, (dict["UDID"] as? String)?.isEmpty != false {
            dict["UDID"] = udid
        }
        return try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    /// Hands the pairing over the way SideStore nightlies from 20 September
    /// 2026 on read it, as `Engine.handOffSplitPairing` does: one file per
    /// protocol, and the two settings its own import writes. Runs on
    /// `deviceQueue`; failures only log.
    private func handOffSplitPairing(_ pairing: Data, bundleID: String, appName: String,
                                     home: SideStoreHome, udid: String?) {
        do {
            let records = try SideStorePairingHandoff.split(pairing, udid: udid)
            if !records.missingLockdownKeys.isEmpty {
                engine.log("⚠️ The lockdown record lacks \(records.missingLockdownKeys.joined(separator: ", ")), which newer SideStore builds require — leaving it out of their files.")
            }
            guard let active = records.activeProtocol else {
                engine.log("⚠️ Nothing in the pairing file that newer \(appName) builds can load.")
                return
            }
            for (name, data) in [(SideStorePairingHandoff.lockdownFileName, records.lockdown),
                                 (SideStorePairingHandoff.remoteFileName, records.remote)] {
                guard let data else { continue }
                let rel = home.documentsPrefix + name
                let written = try connection.writeFile(intoBundleID: bundleID,
                                                       remoteRelativePath: rel, data: data)
                engine.log("Wrote /Documents/\(rel) into \(appName) (\(written) bytes, read back VERIFIED).")
            }
            let prefsPath = home.preferencesPath(hostBundleID: bundleID)
            try connection.updatePlist(inBundleID: bundleID, containerPath: prefsPath) { prefs in
                SideStorePairingHandoff.applySettings(to: &prefs, activeProtocol: active)
            }
            engine.log("Set \(appName) to load its \(active) pairing file (/\(prefsPath)), as its own import does.")
        } catch {
            engine.log("⚠️ Couldn't hand \(appName) its pairing in the newer format (\(short(error))). SideStore nightlies from 20 September 2026 on may ask for the pairing file; older builds are set.")
        }
    }

    /// Sets SideStore up to sign in the way its users got past Apple's -80046,
    /// as `Engine.handOffSideStoreAnisette` does. Runs on `deviceQueue`;
    /// failures only log.
    private func handOffAnisette(bundleID: String, appName: String, home: SideStoreHome) {
        let prefsPath = home.preferencesPath(hostBundleID: bundleID)
        do {
            var changes: [String] = []
            try connection.updatePlist(inBundleID: bundleID, containerPath: prefsPath) { prefs in
                changes = SideStoreAnisetteHandoff.applySettings(to: &prefs)
            }
            guard !changes.isEmpty else { return }
            engine.log("Set \(appName)'s anisette the way SideStore's users get past Apple's -80046: \(changes.joined(separator: ", ")) (/\(prefsPath)).")
        } catch {
            engine.log("⚠️ Couldn't set \(appName)'s anisette settings (\(short(error))). If its sign-in fails with -80046, turn off On-device Anisette and Auto Rotation in its settings and pick “SideStore (New)”.")
        }
    }

    /// The signing certificate as SideStore's `Account.sideconf`, so its first
    /// sign-in with the same Apple ID reuses it instead of asking to resign
    /// itself, as on the Install tab. Not for an Apple ID saved on this iPhone:
    /// the file carries the certificate's private key, which would stay on
    /// their iPhone. Nil, with the reason logged, when nothing is handed over.
    @MainActor
    private func certificateHandOff(for app: SideBySideApp, appleID: String) async -> String? {
        guard let session = signSession, let signed = signedAppPath else { return nil }
        let savedHere = AccountStore.shared.accounts.contains {
            $0.normalized.caseInsensitiveCompare(appleID) == .orderedSame
        }
        if savedHere {
            engine.log("Not handing \(app.displayName) the signing certificate: it belongs to an Apple ID saved on this iPhone, and its private key shouldn't stay on theirs. \(app.displayName) asks to resign itself the first time it signs in.")
            return nil
        }
        guard Self.importsAccountConfigSilently(signedApp: signed) else {
            engine.log("This SideStore build asks for a file password before importing Account.sideconf, so nothing is handed over, the same as iLoader. It offers to resign itself on first sign-in instead.")
            return nil
        }
        do {
            return try await onSignQueue { try Self.accountConfig(session: session) }
        } catch {
            engine.log("⚠️ Couldn't build the certificate hand-off (\(short(error))). SideStore will ask to resign itself on first sign-in.")
            return nil
        }
    }

    /// Writes `config` where SideStore imports it on first launch, then deletes
    /// it. Runs on `deviceQueue`; failures only log.
    private func handOffCertificate(_ config: String, bundleID: String, appName: String, home: SideStoreHome) {
        let rel = home.documentsPrefix + "Account.sideconf"
        do {
            let written = try connection.writeFile(intoBundleID: bundleID, remoteRelativePath: rel,
                                                   data: Data(config.utf8))
            engine.log("Certificate handed to \(appName): /Documents/\(rel) written and read back VERIFIED (\(written) bytes). SideStore imports and deletes it on first launch.")
        } catch {
            engine.log("⚠️ Couldn't hand \(appName) the signing certificate (\(short(error))). It's installed and ready, but will ask to resign itself on first sign-in.")
        }
    }

    private static func accountConfig(session: OpaquePointer) throws -> String {
        var json: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_account_config(session, &json, &error)
        guard rc == 0 else {
            let message = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message(message)
        }
        let payload = json.map { String(cString: $0) } ?? ""
        json.map { si_string_free($0) }
        guard !payload.isEmpty else { throw EngineError.message("empty account config") }
        return payload
    }

    /// String found only in SideStore builds whose account importer asks for
    /// a password (`Engine.promptingImporterMarker`).
    private static let promptingImporterMarker = Data("acctFileChecksum".utf8)

    /// Whether the signed SideStore imports `Account.sideconf` without asking
    /// for a password, as `Engine.importsAccountConfigSilently` checks: by
    /// looking for the prompting importer in its binary.
    private static func importsAccountConfigSilently(signedApp app: String) -> Bool {
        let framework = (app as NSString).appendingPathComponent("Frameworks/SideStoreApp.framework")
        guard let exec = sideStoreExecutable(inBundle: framework) ?? sideStoreExecutable(inBundle: app),
              let binary = try? Data(contentsOf: URL(fileURLWithPath: exec), options: .mappedIfSafe)
        else { return false }
        return binary.range(of: promptingImporterMarker) == nil
    }

    private static func sideStoreExecutable(inBundle path: String) -> String? {
        let plistPath = (path as NSString).appendingPathComponent("Info.plist")
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = (try? PropertyListSerialization.propertyList(from: data, options: [],
                                                                       format: nil)) as? [String: Any],
              let id = plist["CFBundleIdentifier"] as? String,
              id.hasPrefix("com.SideStore.SideStore"),
              let name = plist["CFBundleExecutable"] as? String
        else { return nil }
        let exec = (path as NSString).appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: exec) ? exec : nil
    }

    // MARK: - Helpers

    private static func tidy(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True for a dotted-quad IPv4 address. Checked early for a clear error.
    private static func isIPv4(_ value: String) -> Bool {
        let octets = value.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }
        return octets.allSatisfy { UInt8($0) != nil }
    }

    /// True when `version` ("26.4.1") is `major`.`minor` or later.
    static func version(_ version: String, isAtLeast major: Int, _ minor: Int = 0) -> Bool {
        let parts = version.split(separator: ".").map { Int($0) ?? 0 }
        let have = (parts.first ?? 0, parts.count > 1 ? parts[1] : 0)
        return have.0 != major ? have.0 > major : have.1 >= minor
    }

    /// Moves the file at `path` to `destination`, replacing anything there, and
    /// returns where it is: still at `path` if it couldn't be moved.
    private static func move(_ path: String, to destination: String) -> String {
        guard path != destination else { return path }
        let fm = FileManager.default
        try? fm.removeItem(atPath: destination)
        return (try? fm.moveItem(atPath: path, toPath: destination)) != nil ? destination : path
    }

    private func fileSize(_ path: String) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int) ?? 0
    }

    private func short(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    /// Bridge a blocking device call to async, serialized on this tool's queue.
    private func onDeviceQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            deviceQueue.async {
                do { cont.resume(returning: try work()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    /// The same, on the signing queue: isideload's session isn't thread-safe.
    private func onSignQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            signQueue.async {
                do { cont.resume(returning: try work()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}

// MARK: - C 2FA callback

/// Bridges a 2FA request during a Side by Side sign-in to the engine's shared
/// prompt, which `RootView` presents over whichever tab is showing.
private let sideBySideTwoFactorCallback: SITwoFactorCb = { _, request, outBuf, bufLen in
    Engine.shared.answerTwoFactor(request: request, outBuf: outBuf, len: Int(bufLen))
}

// MARK: - View

/// Side by Side, one page at a time: a welcome, what to install, their
/// address, the Apple ID, getting their iPhone ready, then the run, with what
/// their iPhone asks for shown as it comes up, and what's left on their side
/// once it's done. Pushed from Tools, whose `NavigationStack` this relies on.
struct SideBySideView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// Read for Wi-Fi and the install step's progress, which installd reports
    /// globally.
    @EnvironmentObject private var engine: Engine
    /// Observed so the Apple ID choice follows the saved account.
    @EnvironmentObject private var accounts: AccountStore
    @ObservedObject var manager: SideBySideManager

    @State private var showSettings = false
    @State private var showReport = false
    @State private var confirmingCancel = false
    /// Set by Continue on the address page while what's typed isn't usable.
    @State private var showsAddressProblem = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case address, email, password }
    private typealias Stage = SideBySideManager.Stage

    /// The scroll position each page starts from.
    private static let top = "top"

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 0).id(Self.top)
                    // Pages overlap while one gives way to the next.
                    ZStack(alignment: .top) {
                        page(for: manager.stage)
                            .id(manager.stage)
                            .transition(pageTransition)
                    }
                }
                .padding(20)
                .pageColumn()
            }
            .onChange(of: manager.stage) { _, _ in
                focus = nil
                showsAddressProblem = false
                withAnimation(.smooth(duration: 0.3)) { scroller.scrollTo(Self.top, anchor: .top) }
            }
        }
        .animation(.smooth(duration: 0.4), value: manager.stage)
        .background(AppBackground())
        .navigationBarBackButtonHidden(hidesSystemBack)
        .toolbar {
            if showsPageBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        SoundEffects.play(.tick)
                        manager.goBack()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text(L("Back"))
                        }
                    }
                    .tint(.primary)
                }
            }
            settingsToolbarItem(isPresented: $showSettings)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showReport) { ReportProblemView() }
        .scrollDismissesKeyboard(.interactively)
        .alert(L("Cancel the install?"), isPresented: $confirmingCancel) {
            Button(L("Yes"), role: .destructive) { manager.cancel() }
            Button(L("No"), role: .cancel) { }
        }
        .onChange(of: manager.isRunning) { _, running in
            // A run that ended by itself leaves nothing to cancel.
            if !running { confirmingCancel = false }
        }
        // What the run needs from them, and how it ended, as the other pages'
        // popups sound.
        .onChange(of: manager.pairingInSettings) { _, waiting in
            if waiting { SoundEffects.play(.attention) }
        }
        .onChange(of: manager.pairingPIN) { old, pin in
            if pin != nil, old == nil { SoundEffects.play(.attention) }
        }
        .onChange(of: manager.waitingForTrust) { _, waiting in
            if waiting { SoundEffects.play(.attention) }
        }
        .onChange(of: manager.finished) { _, done in
            if done { SoundEffects.play(.success) }
        }
        .onChange(of: manager.lastError) { _, error in
            if error != nil { SoundEffects.play(.error) }
        }
    }

    // MARK: Pages

    @ViewBuilder
    private func page(for stage: Stage) -> some View {
        switch stage {
        case .welcome: welcomePage
        case .app:     appPage
        case .address: addressPage
        case .account: accountPage
        case .ready:   readyPage
        case .run:
            ZStack(alignment: .top) {
                if manager.finished {
                    donePage.transition(.opacity)
                } else {
                    runPage.transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.45), value: manager.finished)
        }
    }

    /// The setup steps' own pages: pushed in from the side they're headed.
    private var pageTransition: AnyTransition {
        let shift: CGFloat = manager.movingForward ? 36 : -36
        return .asymmetric(insertion: .opacity.combined(with: .offset(x: shift)),
                           removal: .opacity.combined(with: .offset(x: -shift)))
    }

    /// The setup pages step back one at a time, so the bar's own Back to Tools
    /// gives way to theirs. A run in flight has neither.
    private var showsPageBack: Bool {
        !manager.isRunning && manager.stage.number != nil
    }

    private var hidesSystemBack: Bool {
        manager.isRunning || manager.stage.number != nil
    }

    // MARK: Welcome

    private var welcomePage: some View {
        VStack(spacing: 18) {
            BrandHeader(icon: "iphone.gen3.radiowaves.left.and.right",
                        image: "SideBySideLogo",
                        title: L("Side by Side"),
                        subtitle: L("Set up someone else's iPhone")) {
                StatusPill(text: L("Same Wi-Fi network"), systemImage: "wifi", color: .secondary, glass: true)
            }
            .cascadeItem(0)

            PanelCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionTitle(L("How it works"), systemImage: "sparkles")
                    FeatureRow(symbol: "square.grid.2x2.fill",
                               title: L("Pick an app"),
                               detail: L("SideInstaller, SideStore, or LiveContainer with SideStore built in."))
                    FeatureRow(symbol: "lock.iphone",
                               title: L("Pair their iPhone"),
                               detail: L("They open their Settings and type in a code this iPhone shows."))
                    FeatureRow(symbol: "wifi",
                               title: L("Install over Wi-Fi"),
                               detail: L("This iPhone signs the app and sends it across. No computer needed."))
                }
            }
            .cascadeItem(1)

            PanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(L("What you need"), systemImage: "checklist")
                    CheckRow(symbol: "wifi", text: L("Both iPhones on the same Wi-Fi network"))
                    CheckRow(symbol: "iphone",
                             text: L("Their iPhone on iOS %@ or later, unlocked and nearby", Engine.minimumOSText))
                    CheckRow(symbol: "person.crop.circle", text: L("An Apple ID to sign with — ideally theirs"))
                }
            }
            .cascadeItem(2)

            if manager.remembersTheirIPhone {
                rememberedCard.cascadeItem(3)
            }

            Button { manager.go(to: .app) } label: { continueLabel(L("Get started")) }
                .buttonStyle(PrimaryButtonStyle())
                .cascadeItem(4)
        }
    }

    /// A pairing kept from a run that stopped, which Clear forgets.
    private var rememberedCard: some View {
        CalloutCard(tint: Theme.accent) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "link")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("This iPhone is still paired with theirs. Clearing forgets it."))
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L("Clear their details")) { manager.clear() }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent2)
                        .buttonStyle(.plain, sound: .tap)
                }
            }
        }
    }

    // MARK: 1. What to install

    private var appPage: some View {
        VStack(spacing: 18) {
            stageHeader(.app,
                        title: L("What should go on their iPhone?"),
                        subtitle: L("Pick one. You can come back for another one later."))
                .cascadeItem(0)
            VStack(spacing: 12) {
                ForEach(Array(SideBySideApp.allCases.enumerated()), id: \.element) { index, app in
                    AppChoiceCard(app: app, selected: manager.app == app) {
                        manager.app = app
                    }
                    .cascadeItem(index + 1)
                }
            }
            if manager.app.source != nil {
                channelCard.transition(.cardAppear)
            }
            Button { manager.go(to: .address) } label: { continueLabel(L("Continue")) }
                .buttonStyle(PrimaryButtonStyle())
                .cascadeItem(5)
        }
        .animation(.smooth(duration: 0.3), value: manager.app)
    }

    /// Stable or Nightly, for the SideStore builds, as on the Install tab.
    private var channelCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L("Release"), systemImage: "tag.fill")
                Picker(L("Release"), selection: $manager.channel) {
                    ForEach(ReleaseChannel.allCases) { channel in
                        Text(channel.displayName).tag(channel)
                    }
                }
                .pickerStyle(.segmented)
                Text(L("Stable is the release most people use. Nightly is built from the newest code."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 2. Their address

    private var addressPage: some View {
        VStack(spacing: 18) {
            stageHeader(.address,
                        title: L("Do you know their iPhone's IP address?"),
                        subtitle: L("Optional: leave it empty, and it fills in when their iPhone pairs."))
                .cascadeItem(0)

            PanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(L("IP address (optional)"), text: $manager.targetIP)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        // Not `.decimalPad`: its separator is a comma in many regions.
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.plain)
                        .submitLabel(.continue)
                        .focused($focus, equals: .address)
                        .onSubmit(continueFromAddress)
                        .fieldBackground()
                    if showsAddressProblem, let problem = manager.addressProblem {
                        Label(problem, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                    Text(addressHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .cascadeItem(1)

            PanelCard {
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(symbol: "gearshape.fill",
                               title: L("Without it"),
                               detail: L("Their iPhone pairs from its own Settings, the way iOS %@ pairs over Wi-Fi.",
                                         Engine.minimumOSText))
                    FeatureRow(symbol: "network",
                               title: L("With it"),
                               detail: L("SideInstaller asks their iPhone directly first, and reuses the pairing from an earlier try."))
                }
            }
            .cascadeItem(2)

            Button(action: continueFromAddress) {
                continueLabel(manager.targetIP.trimmingCharacters(in: .whitespaces).isEmpty
                              ? L("Skip") : L("Continue"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .cascadeItem(3)
        }
        .onChange(of: manager.targetIP) { _, _ in showsAddressProblem = false }
        .animation(.smooth(duration: 0.25), value: showsAddressProblem)
    }

    /// How to find their address, with this iPhone's as an example.
    private var addressHint: String {
        let route = L("On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.")
        guard let own = manager.ownWiFiAddress else { return route }
        return route + " " + L("This iPhone is %@, so theirs will look similar.", own)
    }

    private func continueFromAddress() {
        guard manager.addressProblem == nil else {
            showsAddressProblem = true
            SoundEffects.play(.error)
            return
        }
        focus = nil
        manager.go(to: .account)
    }

    // MARK: 3. The Apple ID

    private var accountPage: some View {
        VStack(spacing: 18) {
            stageHeader(.account,
                        title: L("Which Apple ID signs it?"),
                        subtitle: L("The app is signed with it, and needs it again every 7 days to keep opening. Use the iPhone owner's."))
                .cascadeItem(0)

            if let saved = accounts.active {
                VStack(spacing: 10) {
                    OptionRow(symbol: "person.2.fill",
                              title: L("Their Apple ID"),
                              detail: L("Recommended — they keep their apps signed with it."),
                              selected: !manager.usesSavedAccount) {
                        manager.usesSavedAccount = false
                    }
                    OptionRow(symbol: "person.crop.circle.fill",
                              title: L("My Apple ID"),
                              detail: saved.normalized,
                              selected: manager.usesSavedAccount) {
                        focus = nil
                        manager.usesSavedAccount = true
                    }
                }
                .cascadeItem(1)
            }

            if manager.signsWithSavedAccount {
                CalloutCard(tint: .orange) {
                    Label {
                        Text(L("Only if you'll keep their apps signed yourself: they won't have this Apple ID's password."))
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .transition(.cardAppear)
            } else {
                credentialsCard
                    .cascadeItem(2)
                    .transition(.cardAppear)
            }

            Button(action: continueFromAccount) { continueLabel(L("Continue")) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!manager.hasCredentials)
                .opacity(manager.hasCredentials ? 1 : 0.35)
                .animation(.snappy(duration: 0.25), value: manager.hasCredentials)
                .cascadeItem(3)
        }
        .animation(.smooth(duration: 0.3), value: manager.signsWithSavedAccount)
    }

    private var credentialsCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                TextField(L("Email"), text: $manager.appleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    // No `.username`/`.password` content types here: these are
                    // someone else's credentials, so don't offer to save them
                    // to the keychain.
                    .textFieldStyle(.plain)
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
                    .fieldBackground()
                SecureField(L("Password"), text: $manager.password)
                    .textFieldStyle(.plain)
                    .submitLabel(.continue)
                    .focused($focus, equals: .password)
                    .onSubmit(continueFromAccount)
                    .fieldBackground()
                VStack(alignment: .leading, spacing: 8) {
                    CheckRow(symbol: "lock.fill", text: L("Used for this install only, and never saved."))
                    CheckRow(symbol: "bell.badge.fill",
                             text: L("Apple may send a code to their devices — keep their iPhone close."))
                }
                .padding(.top, 2)
            }
        }
    }

    private func continueFromAccount() {
        guard manager.hasCredentials else { return }
        focus = nil
        manager.go(to: .ready)
    }

    // MARK: 4. Their iPhone, ready

    private var readyPage: some View {
        VStack(spacing: 18) {
            stageHeader(.ready,
                        title: L("Get their iPhone ready"),
                        subtitle: L("Do this on their iPhone, then start."))
                .cascadeItem(0)

            PanelCard {
                NumberedSteps(steps: [
                    L("Connect their iPhone to the same Wi-Fi network as this one."),
                    L("Turn on Developer Mode under Settings › Privacy & Security › Developer Mode, and confirm it after the restart."),
                    L("Unlock their iPhone and keep it next to this one."),
                ])
            }
            .cascadeItem(1)

            PanelCard {
                VStack(spacing: 14) {
                    summaryRow(L("Install"), value: appSummary, symbol: "square.grid.2x2.fill", edit: .app)
                    hairline
                    summaryRow(L("Their iPhone"), value: addressSummary, symbol: "iphone", edit: .address)
                    hairline
                    summaryRow(L("Apple ID to sign with"), value: manager.credentials?.id ?? "—",
                               symbol: "person.crop.circle.fill", edit: .account)
                }
            }
            .cascadeItem(2)

            if !engine.wifiConnected {
                CalloutCard(tint: .orange) {
                    Label {
                        Text(L("Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work."))
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "wifi.slash").foregroundStyle(.orange)
                    }
                }
                .transition(.cardAppear)
            }
            if let problem = manager.lastError, !manager.isRunning {
                CalloutCard(tint: .red) { ErrorMessage(message: problem) }
                    .transition(.cardAppear)
            }

            Button {
                focus = nil
                manager.start()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "iphone.and.arrow.forward")
                    Text(L("Start the install"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .cascadeItem(3)
        }
        .animation(.smooth(duration: 0.35), value: engine.wifiConnected)
        .animation(.smooth(duration: 0.35), value: manager.lastError)
    }

    private var appSummary: String {
        guard manager.app.source != nil else { return manager.app.displayName }
        return "\(manager.app.displayName) · \(manager.channel.displayName)"
    }

    private var addressSummary: String {
        let ip = manager.targetIP.trimmingCharacters(in: .whitespaces)
        return ip.isEmpty ? L("Pairs from its Settings") : ip
    }

    /// One line of the summary, which opens its page to change it.
    private func summaryRow(_ label: String, value: String, symbol: String, edit stage: Stage) -> some View {
        Button { manager.go(to: stage) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(L("Edit"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain, sound: .tap)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.6))
            .frame(height: 1)
    }

    // MARK: The run

    private var runPage: some View {
        VStack(spacing: 18) {
            runHeader.cascadeItem(0)
            if manager.isRunning {
                if manager.pairingInSettings || manager.pairingPIN != nil {
                    pairingCard.transition(.cardAppear)
                } else if manager.waitingForTrust {
                    trustCard.transition(.cardAppear)
                }
            }
            if !manager.isRunning, let message = manager.lastError {
                failureCard(message).transition(.cardAppear)
            }
            progressCard.cascadeItem(1)
        }
        .animation(.smooth(duration: 0.35), value: manager.pairingInSettings)
        .animation(.smooth(duration: 0.35), value: manager.pairingPIN)
        .animation(.smooth(duration: 0.35), value: manager.waitingForTrust)
        .animation(.smooth(duration: 0.35), value: manager.isRunning)
        .animation(.smooth(duration: 0.35), value: manager.targetSummary)
    }

    private var runHeader: some View {
        VStack(spacing: 14) {
            AppGlyph(app: manager.runApp, size: 76)
                .shadow(color: Theme.glow, radius: 20, x: 0, y: 12)
                .scaleEffect(manager.isRunning ? 1.04 : 1)
                .animation(manager.isRunning
                           ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default,
                           value: manager.isRunning)
            Text(runTitle)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            Group {
                if let summary = manager.targetSummary {
                    StatusPill(text: summary, systemImage: "iphone", color: .green)
                } else {
                    StatusPill(text: L("Same Wi-Fi network"), systemImage: "wifi", color: .secondary, glass: true)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var runTitle: String {
        if manager.lastError != nil, !manager.isRunning { return L("Install stopped") }
        return L("Installing %@ on their iPhone", manager.runApp.displayName)
    }

    /// What their iPhone asks for while it pairs from Settings: the steps to
    /// get there, and the code once it wants one. Nothing appears on it by
    /// itself, so without this the run just looks stuck.
    private var pairingCard: some View {
        CalloutCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 16) {
                actionHeader(L("Pair their iPhone in Settings"),
                             detail: L("Their iPhone won't ask by itself — pairing starts from its Settings."),
                             symbol: "lock.iphone")
                if let pin = manager.pairingPIN {
                    VStack(spacing: 6) {
                        Text(pin)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .tracking(8)
                            .accessibilityLabel(pin.map(String.init).joined(separator: " "))
                        Text(L("Type this into the prompt on their iPhone."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.07)))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                NumberedSteps(steps: [
                    L("On their iPhone, open Settings › Privacy & Security › Developer Mode."),
                    L("Tap “Pair with %@”.", PairingController.peerHostName),
                    L("Enter their iPhone’s passcode if it asks for it."),
                    L("Type the code that appears here into the prompt on their iPhone."),
                ])
                if manager.pairingPIN == nil {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(L("Waiting for their iPhone…"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    /// Their iPhone shows a Trust prompt, on an iOS that still pairs that way.
    private var trustCard: some View {
        CalloutCard(tint: .orange) {
            actionHeader(L("Tap Trust on their iPhone"),
                         detail: L("Unlock their iPhone, then tap Trust in the prompt that comes up."),
                         symbol: "hand.tap.fill")
        }
    }

    private func actionHeader(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.orange.opacity(0.16)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var progressCard: some View {
        let steps = SideBySideStep.steps(for: manager.runApp)
        return PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Text(progressTitle)
                        .font(.headline)
                        .contentTransition(.opacity)
                    Spacer(minLength: 4)
                    Text("\(Int(manager.overallProgress * 100))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(progressTint)
                        .contentTransition(.numericText(value: manager.overallProgress))
                        .animation(.smooth(duration: 0.3), value: manager.overallProgress)
                    if manager.isRunning {
                        cancelButton
                            .transition(.opacity.combined(with: .scale(scale: 0.6)))
                    }
                }
                InstallProgressBar(progress: manager.overallProgress,
                                   tint: progressTint,
                                   gradient: progressGradient,
                                   animating: manager.isRunning)
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                        SideBySideStepRow(title: step.title(for: manager.runApp),
                                          state: manager.stepStates[step] ?? .pending,
                                          detail: detail(for: step),
                                          isLast: index == steps.count - 1)
                    }
                }
            }
        }
    }

    /// The header says the run stopped, so then the card says where.
    private var progressTitle: String {
        if manager.isCancelling { return L("Cancelling") }
        let steps = SideBySideStep.steps(for: manager.runApp)
        if let failed = steps.firstIndex(where: { manager.stepStates[$0] == .failed }) {
            return L("Step %@ of %@", "\(failed + 1)", "\(steps.count)")
        }
        return L("Installing")
    }

    private var runFailed: Bool {
        manager.stepStates.values.contains(.failed)
    }

    private var progressTint: Color { runFailed ? .red : Theme.accent }

    private var progressGradient: LinearGradient {
        runFailed ? Theme.gradient(.red) : Theme.brand
    }

    /// The X in the card's corner, which stops the run after asking. It dims
    /// once the run is stopping, which waits for the step in flight.
    private var cancelButton: some View {
        Button {
            confirmingCancel = true
        } label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(7)
                .background(Circle().fill(.white.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain, sound: .tap)
        .disabled(manager.isCancelling)
        .opacity(manager.isCancelling ? 0.4 : 1)
        .accessibilityLabel(L("Cancel"))
    }

    /// The extra line a step carries while it is the one in flight.
    private func detail(for step: SideBySideStep) -> String? {
        let state = manager.stepStates[step] ?? .pending
        guard state == .active || state == .waiting else { return nil }
        switch step {
        case .connect:
            if manager.pairingPIN != nil { return L("Waiting for them to enter the code…") }
            if manager.pairingInSettings { return L("Waiting for them to pair in Settings…") }
            if manager.waitingForTrust { return L("Waiting for them to tap Trust…") }
            return L("Looking for their iPhone…")
        case .download:
            return L("%d%% downloaded", Int(manager.downloadProgress * 100))
        case .install:
            return L("%d%% uploaded", Int(engine.installProgress * 100))
        case .setUp:
            return L("Handing over the pairing file…")
        case .signIn, .sign:
            return nil
        }
    }

    /// Why the run stopped, and the ways on: again as it was, or with
    /// something changed. Untitled: the header above says it stopped.
    private func failureCard(_ message: String) -> some View {
        CalloutCard(tint: .red) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { retryButtons }
                    VStack(alignment: .leading, spacing: 10) { retryButtons }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { reportButtons(message) }
                    VStack(alignment: .leading, spacing: 10) { reportButtons(message) }
                }
            }
        }
    }

    @ViewBuilder
    private var retryButtons: some View {
        Button { manager.start() } label: {
            Label(L("Try again"), systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent, sound: .press)
        .tint(Theme.accent)
        Button { manager.editDetails() } label: {
            Label(L("Change details"), systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered, sound: .tap)
        .tint(Theme.accent2)
    }

    /// Report this problem, and Copy logs unless the message says how to fix it.
    @ViewBuilder
    private func reportButtons(_ message: String) -> some View {
        Button { showReport = true } label: {
            Label(L("Report this problem"), systemImage: "exclamationmark.bubble")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered, sound: .tap)
        .tint(.red)
        if !ErrorHelp.isExplained(message) {
            CopyLogsButton()
        }
    }

    // MARK: Done

    private var donePage: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.16))
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, options: .nonRepeating, value: manager.finished)
                }
                Text(L("%@ is on their iPhone", manager.installedAppName ?? manager.runApp.displayName))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary = manager.targetSummary {
                    StatusPill(text: summary, systemImage: "iphone", color: .green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .cascadeItem(0)

            PanelCard {
                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle(L("Finish on their iPhone"), systemImage: "hand.tap.fill")
                    NumberedSteps(steps: finishSteps)
                }
            }
            .cascadeItem(1)

            if let version = manager.versionTooOldToSelfPair {
                CalloutCard(tint: .orange) {
                    Label {
                        Text(L("Their iPhone runs iOS %@. SideInstaller pairs itself only from iOS %@, so there it needs a pairing file made on a computer.",
                               version, Engine.minimumOSText))
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                .cascadeItem(2)
            }

            Label(L("This iPhone no longer keeps a pairing with theirs."), systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .cascadeItem(3)

            VStack(spacing: 14) {
                Button { manager.finishAndReset() } label: { Text(L("Done")) }
                    .buttonStyle(PrimaryButtonStyle(sound: .tap))
                Button(L("Install another app")) { manager.installAnother() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                    .buttonStyle(.plain, sound: .tap)
            }
            .cascadeItem(4)
        }
    }

    /// What's left on their iPhone: trusting the Apple ID, then what the app
    /// needs before it's ready.
    private var finishSteps: [String] {
        var steps = [
            L("On their iPhone: Settings › General › VPN & Device Management."),
            L("Tap the Apple ID under “Developer App”, then tap Trust."),
        ]
        switch manager.runApp {
        case .sideInstaller:
            steps.append(L("Open it from their Home Screen — they're set up."))
        case .sideStore:
            steps.append(L("Get LocalDevVPN from the App Store and connect it: SideStore works through it."))
            steps.append(L("Open SideStore and sign in with the same Apple ID. Its pairing file is already in place."))
        case .liveContainer:
            steps.append(L("Get LocalDevVPN from the App Store and connect it: SideStore works through it."))
            steps.append(L("Open LiveContainer, go to its Settings tab, and tap “Import Certificate From SideStore”."))
        }
        return steps
    }

    // MARK: Pieces

    /// A setup page's heading: where it is in the setup, the question, and why.
    private func stageHeader(_ stage: Stage, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let number = stage.number {
                HStack(spacing: 10) {
                    StageDots(current: number, total: Stage.numberedCount)
                    Text(L("Step %@ of %@", "\(number)", "\(Stage.numberedCount)"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            Text(title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func continueLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Image(systemName: "arrow.right")
                .font(.subheadline.weight(.bold))
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.brand)
        }
    }
}

// MARK: - Pieces

/// An app's tile: SideInstaller's own icon, or a symbol on the app's tint.
private struct AppGlyph: View {
    let app: SideBySideApp
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let image = app.image {
                Image(image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Theme.gradient(app.tint))
                    // A lit top edge, as on the app's other glyphs.
                    LinearGradient(colors: [.white.opacity(0.22), .clear],
                                   startPoint: .top, endPoint: .center)
                    Image(systemName: app.symbol)
                        .font(.system(size: size * 0.44, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 23 / 86, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// One of the apps to pick from, ticked when picked.
private struct AppChoiceCard: View {
    let app: SideBySideApp
    let selected: Bool
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                AppGlyph(app: app, size: 52)
                VStack(alignment: .leading, spacing: 5) {
                    Text(app.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(app.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(app.requirement, systemImage: app.requirementSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? Theme.accent2 : .secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent2 : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Theme.accent.opacity(selected ? 0.14 : 0)))
            .cardSurface(in: shape)
            .overlay(shape.strokeBorder(Theme.accent2.opacity(selected ? 0.75 : 0), lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain, sound: .tick)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One of two choices, ticked when picked.
private struct OptionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.brand))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent2 : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Theme.accent.opacity(selected ? 0.14 : 0)))
            .cardSurface(in: shape)
            .overlay(shape.strokeBorder(Theme.accent2.opacity(selected ? 0.75 : 0), lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain, sound: .tick)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A line of the welcome page: a glyph on the brand gradient, a title, a line.
private struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.brand))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A requirement or a reassurance, with a small glyph.
private struct CheckRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent2)
                .frame(width: 22)
            Text(text.keepingWiFiWhole)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Where a page is in the setup: a dot per step, the current one drawn out.
private struct StageDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.white.opacity(0.14)))
                    .frame(width: index == current ? 24 : 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One row of the run's timeline: the Install tab's status node, the title,
/// and the line the step adds while it is the one in flight.
private struct SideBySideStepRow: View {
    let title: String
    let state: StepState
    var detail: String?
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                StepNode(state: state)
                if !isLast {
                    Rectangle()
                        .fill(state == .done ? Color.green.opacity(0.5) : Color(.tertiarySystemFill))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(state == .pending ? .regular : .medium))
                        .foregroundStyle(state == .pending ? .secondary : .primary)
                    Spacer(minLength: 4)
                    if state == .waiting {
                        Text(L("Action needed"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange.opacity(0.16)))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .frame(minHeight: 28)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                }
                if !isLast { Spacer(minLength: 14) }
            }
        }
        .animation(.smooth(duration: 0.3), value: state)
        .animation(.smooth(duration: 0.3), value: detail)
    }
}

private extension String {
    /// The text with "Wi-Fi" held together by a non-breaking hyphen, so a line
    /// never ends in "Wi-".
    var keepingWiFiWhole: String {
        replacingOccurrences(of: "Wi-Fi", with: "Wi\u{2011}Fi")
    }
}
