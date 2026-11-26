import BackgroundTasks
import Foundation
import Network
import Observation
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
struct Guide: Hashable {
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
    /// GrandSlam error -20209: Apple locked the account until it's reset at iForgot.
    case accountLocked
    /// Apple developer error 1102: the account's owner is too young for
    /// developer services.
    case underage
    /// Apple developer error 2160: the Apple Account's email address isn't
    /// verified yet.
    case emailUnverified
    /// Apple error 9120, or the signer's own check: no App IDs left this week.
    case appIDLimit
    /// installd refused a fourth app signed by a free Apple ID.
    case appLimit

    var errorDescription: String? {
        switch self {
        case let .message(m):
            return m
        case .accountLocked:
            return L("Apple has locked this Apple Account for security reasons (error -20209), so every sign-in fails until it's unlocked. Reset its password at iforgot.apple.com, then sign in again with the new password.")
        case .underage:
            return L("Apple won't let this Apple Account use developer services because of its owner's age (error 1102). Sign in with an adult's Apple Account instead.")
        case .emailUnverified:
            return L("Apple won't let this Apple Account use developer services until its email address is verified (error 2160). Verify it at account.apple.com, then try again.")
        case .appIDLimit:
            return L("This Apple ID has no App IDs left (error 9120). A free Apple ID can register 10 a week, and each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.")
        case .appLimit:
            return L("This iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. Delete one of them, then try again.")
        case .certExists:
            return L("Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.")
        case let .deviceRegistration(udid, raw):
            let tail = udid.isEmpty ? "" : L(" (UDID %@)", udid)
            return L("Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.",
                     tail, friendlyRustError(raw))
        }
    }
}

/// All install logic. A singleton so the C log callback can reach it.
@Observable
final class Engine {

    static let shared = Engine()

    // MARK: Inputs

    /// Active Apple ID credentials, read from `AccountStore` (entered during
    /// setup, switched in Settings › Account). Views observe the store directly.
    var appleID: String { AccountStore.shared.activeAppleID }
    var applePassword: String { AccountStore.shared.activePassword }
    /// Anisette server in use: the one picked in Settings or, with Auto on,
    /// the one the last successful sign-in used. Persisted.
    var anisetteURL: String = Engine.savedAnisetteURL() {
        didSet {
            guard anisetteURL != oldValue else { return }
            UserDefaults.standard.set(anisetteURL, forKey: Engine.anisetteURLKey)
        }
    }

    static let anisetteURLKey = "anisetteServerURL"

    /// Settings › Anisette Server › Auto: sign-in tries the servers in order
    /// of how likely they are to work, from `anisetteURL` (see
    /// `anisetteCandidates`). Off, the server picked there is the only one
    /// tried. On by default, as every sign-in tried them all before 1.6.
    var anisetteAuto: Bool =
        (UserDefaults.standard.object(forKey: Engine.anisetteAutoKey) as? Bool) ?? true {
        didSet {
            guard anisetteAuto != oldValue else { return }
            UserDefaults.standard.set(anisetteAuto, forKey: Engine.anisetteAutoKey)
        }
    }

    static let anisetteAutoKey = "anisetteServerAuto"

    private(set) var appIDCost: AppIDCost?
    /// Resumed with the answer to `appIDCost`: true to sign and install.
    private var appIDCostReply: CheckedContinuation<Bool, Never>?
    /// A pairing file whose UDID differs from the connected iPhone, waiting for
    /// the user to confirm the switch.
    struct PairingImportMismatch: Hashable {
        let fileUDID: String
        let deviceUDID: String
    }
    private(set) var pairingImportMismatch: PairingImportMismatch?
    private var pairingImportMismatchReply: CheckedContinuation<Bool, Never>?

    /// F-G (0.9.156): a download the user asked for on cellular data, waiting
    /// for the go-ahead. Settings › Downloads › "Wi-Fi only downloads" asks
    /// first, so a big IPA doesn't eat mobile data unnoticed.
    struct CellularDownloadRequest: Hashable {
        /// What is being downloaded — the app or build name.
        let what: String
        /// The file's size in bytes, when the server stated one.
        let size: Int64?
    }
    private(set) var cellularDownloadRequest: CellularDownloadRequest?
    private var cellularDownloadReply: CheckedContinuation<Bool, Never>?
    /// B-1 (0.9.166): downloads waiting behind the cellular prompt on
    /// screen — one prompt at a time, but the rest queue instead of
    /// declining silently. Each waiter suspends on its own continuation;
    /// answering the prompt on screen presents the next one in turn.
    private struct QueuedCellularDownload {
        let id: UUID
        let size: Int64?
        let what: String
        let reply: CheckedContinuation<Bool, Never>
    }
    private var cellularDownloadQueue: [QueuedCellularDownload] = []
    /// B-1 (0.9.166): the queued waiter whose prompt is on screen now, if
    /// it got there from the queue rather than asking first — so cancelling
    /// it answers its own prompt, and a cancel landing before a waiter
    /// even queued can't decline somebody else's.
    private var presentedQueuedCellularDownloadID: UUID?

    /// The Settings switch for F-G. Off by default: the app's behaviour on
    /// cellular doesn't change until the user turns it on.
    static let wifiOnlyDownloadsKey = "SIDWifiOnlyDownloads"
    static var wifiOnlyDownloads: Bool {
        UserDefaults.standard.bool(forKey: wifiOnlyDownloadsKey)
    }

    /// The Settings switch for F-1 (0.9.159): delete the source IPA after a
    /// successful install. Off by default. The key lives on `Engine` so the
    /// success path reads the same value the Settings toggle writes.
    static let deleteAfterInstallKey = "SIDDeleteAfterInstall"
    static var deleteAfterInstall: Bool {
        UserDefaults.standard.bool(forKey: deleteAfterInstallKey)
    }

    /// A downloaded IPA was deleted by the F-1 post-install cleanup: the
    /// Downloads and Files lists rescan on it instead of waiting for the
    /// next time they're opened.
    static let downloadsChanged = Notification.Name("CZFDownloadsChanged")

    /// F-3 (0.9.164): a history row asked to reveal its IPA in Downloads
    /// (`userInfo["url"]` is the file path); RootView switches to the
    /// Downloads tab and DownloadsListView scrolls to it.
    static let revealDownload = Notification.Name("CZFRevealDownload")

    /// Answer the pairing-file mismatch popup: true replaces the pairing file.
    @MainActor
    func answerPairingImportMismatch(_ proceed: Bool) {
        guard let reply = pairingImportMismatchReply else { return }
        pairingImportMismatchReply = nil
        reply.resume(returning: proceed)
        pairingImportMismatch = nil
    }
    /// The `sideinstaller://` link waiting for the go-ahead.
    private(set) var pendingLink: DeepLink?
    /// An invalid `sideinstaller://` link that arrived mid-run: the run's own
    /// popups come first, so it waits here and shows once the run ends
    /// (B1, 0.9.152) instead of only landing in the log.
    private(set) var pendingInvalidLinkMessage: String?
    /// When SideStore was last asked for its pairing file, so the file it sends
    /// back can be told from one some other link brought.
    private var sideStorePairingRequestedAt: Date?
    /// When SideStore was last asked for its certificate, and whether the
    /// install that stopped on error 7460 runs again once it's in.
    private var sideStoreCertificateRequest: (at: Date, retryInstall: Bool)?
    /// A certificate a link brought, for `RootView` to hand to the Certificates
    /// manager, which checks it against the Apple ID's own before using it.
    var certificateToImport: CertificateImport?

    /// The saved anisette server, or the one to start with, saved.
    ///
    /// Until 1.5.2 the default was `AnisetteServer.legacyDefault`, and a pick
    /// that stayed the default wasn't saved. Someone who signed in through it
    /// has an anisette identity on its library, with a developer token that
    /// only works with that identity, so they stay on it: moving them to the
    /// new default would make a new identity, which Apple asks the second
    /// factor for, and sign in again. The start is saved either way, since
    /// from 1.5.2 on a stored identity no longer means an older install.
    static func savedAnisetteURL() -> String {
        if let saved = UserDefaults.standard.string(forKey: anisetteURLKey) { return saved }
        let identity = PrivateStore.isideload.appendingPathComponent("anisette_state").path
        let start = FileManager.default.fileExists(atPath: identity)
            ? AnisetteServer.legacyDefault : AnisetteServer.fallback
        UserDefaults.standard.set(start.address, forKey: anisetteURLKey)
        return start.address
    }
    /// Servers for the picker; a bundled snapshot until the live list loads.
    private(set) var anisetteServers: [AnisetteServer] = AnisetteServer.bundledDefaults
    /// "Start LocalDevVPN when needed" setting: whatever needs the tunnel starts
    /// LocalDevVPN when it's down, instead of asking for it. On by default.
    /// With an entitled signature the built-in tunnel is tried first and
    /// almost always wins, so this only ever fires for signatures whose
    /// profile can't run the built-in tunnel (personal ID etc.).
    /// Stored here (not `@AppStorage`) so the engine and the Settings toggle
    /// share one value.
    var autoStartVPN: Bool =
        (UserDefaults.standard.object(forKey: Engine.autoStartVPNKey) as? Bool) ?? true {
        didSet {
            guard autoStartVPN != oldValue else { return }
            UserDefaults.standard.set(autoStartVPN, forKey: Engine.autoStartVPNKey)
            log(autoStartVPN
                ? "LocalDevVPN will be started whenever something needs the tunnel."
                : "LocalDevVPN will no longer be started for you.")
        }
    }

    /// Kept from when the setting started LocalDevVPN at launch, so the choice
    /// carries over.
    static let autoStartVPNKey = "autoStartLocalDevVPN"

    /// Settings › Activity Log › Verbose logging: idevice's DEBUG lines, every
    /// plist, XPC message and pairing step exchanged with iOS, go into the log.
    /// Off by default, since they quickly fill it.
    var verboseLogging: Bool = UserDefaults.standard.bool(forKey: Engine.verboseLoggingKey) {
        didSet {
            guard verboseLogging != oldValue else { return }
            UserDefaults.standard.set(verboseLogging, forKey: Engine.verboseLoggingKey)
            si_log_set_verbose(verboseLogging ? 1 : 0)
            log(verboseLogging
                ? "Verbose logging on: idevice's DEBUG lines now go into this log."
                : "Verbose logging off.")
        }
    }

    static let verboseLoggingKey = "verboseLogging"

    // The loopback VPN's device-side IP; configurable in Advanced.
    var deviceIP: String = Engine.defaultDeviceIP
    /// Device IP's default: LocalDevVPN's far end of the tunnel.
    static let defaultDeviceIP = "10.7.0.1"
    /// `deviceIP` normalized to a dialable host, e.g. `10.7.0.1/32` → `10.7.0.1`.
    var deviceHost: String { NetworkStatus.host(deviceIP) }
    // Which build to install (SideStore, LiveContainer + SideStore, Madeira, or
    // an imported IPA).
    var installSource: InstallSource = .custom
    // Which release track to pull that build from (stable or nightly).
    var releaseChannel: ReleaseChannel = .stable
    /// The track the selected build is installed from: the picked one, or the
    /// only one the build offers.
    var selectedChannel: ReleaseChannel {
        let offered = channels(for: installSource)
        return offered.contains(releaseChannel) ? releaseChannel : offered[0]
    }
    /// The channels the picker offers for `source`.
    func channels(for source: InstallSource) -> [ReleaseChannel] {
        source.channels(stableReleased: source.firstStableVersion == nil || stableReleased.contains(source))
    }
    /// Builds whose stable channel waits for a first release (Madeira, until
    /// 0.2.0) that GitHub has shown is out. Remembered across launches and
    /// checked again whenever the build is picked (`checkStableRelease`).
    private(set) var stableReleased: Set<InstallSource> =
        Set((UserDefaults.standard.stringArray(forKey: Engine.stableReleasedKey) ?? [])
            .compactMap(InstallSource.init(rawValue:)))
    private static let stableReleasedKey = "stableReleased"
    /// Last time each build's stable channel was checked on GitHub
    /// (`checkStableRelease`); 15-minute TTL, same as `loadReleaseCatalog`,
    /// so switching builds doesn't HEAD the same release page every time.
    /// A failed check leaves the timestamp alone, so the next pick retries.
    private var lastStableCheck: [InstallSource: Date] = [:]
    /// Versions picked under Advanced, per build and channel; a missing entry
    /// installs the latest release. Not persisted, like the channel.
    private var pickedVersions: [InstallSource: [ReleaseChannel: ReleaseVersion]] = [:]

    /// The version picked for the selected build and channel; nil installs the
    /// latest release.
    var selectedVersion: ReleaseVersion? {
        get { pickedVersions[installSource]?[selectedChannel] }
        set { pickedVersions[installSource, default: [:]][selectedChannel] = newValue }
    }

    /// Each build's releases, listed by the version picker under Advanced.
    private(set) var releaseCatalogs: [InstallSource: ReleaseCatalog] = [:]
    /// The build whose releases are being fetched, if any.
    private(set) var loadingCatalog: InstallSource?
    /// Why the last fetch of a build's releases failed.
    private(set) var catalogErrors: [InstallSource: String] = [:]

    // MARK: Plain-text status readouts

    /// Loopback-tunnel state, polled by `startStatusMonitor`.
    var vpnConnected: Bool = false
    /// Wi-Fi (`en0`) state, polled alongside the tunnel.
    var wifiConnected: Bool = false
    var vpnStatus: String = "unknown"
    var wifiStatus: String = "unknown"

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

    /// True below iOS 27 on hardware that can update to it, where updating
    /// makes the computer-made pairing file unnecessary. iOS 27 runs on the
    /// same iPhones as iOS 26 (iPhone 11 and SE 2nd generation on); iPadOS 27
    /// drops the A12/A12X iPads (8th generation iPad, mini 5, Air 3, the 2018
    /// iPad Pros) but keeps the 2020 A12Z iPad Pros.
    static var canUpdateToSelfPairingOS: Bool {
        guard !deviceCanSelfPair else { return false }
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
            ?? ProblemReport.sysctlString("hw.machine")
        return model.map(supportsSelfPairingOS) ?? false
    }

    /// Whether a hardware model, e.g. "iPhone12,8", is on the iOS/iPadOS 27 list.
    static func supportsSelfPairingOS(model: String) -> Bool {
        let family = model.prefix { $0.isLetter }
        let numbers = model.dropFirst(family.count).split(separator: ",").compactMap { Int($0) }
        guard numbers.count == 2 else { return false }
        let (major, minor) = (numbers[0], numbers[1])
        switch family {
        case "iPhone": return major >= 12               // iPhone12,1 = iPhone 11
        case "iPad": return major >= 12                 // iPad12,1 = iPad (9th generation)
            || (major == 8 && minor >= 9)               // iPad8,9–8,12 = 2020 iPad Pros
        default: return false
        }
    }

    /// Whether Developer Mode is on, from the `security.mac.amfi.developer_mode_status`
    /// sysctl AMFI publishes; nil when this iOS won't let the app read it.
    /// Static so non-isolated code can read it.
    static var developerModeIsOn: Bool? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("security.mac.amfi.developer_mode_status", &value, &size, nil, 0) == 0,
              size == MemoryLayout<Int32>.size else { return nil }
        return value != 0
    }

    /// True when SideInstaller runs as a LiveContainer guest. iOS then applies
    /// LiveContainer's Info.plist to the process, not SideInstaller's.
    static var runsInLiveContainer: Bool { getenv("LC_HOME_PATH") != nil }

    /// False on iOS 27 and later, where this iPhone can't make itself a classic
    /// lockdown pair record: lockdownd answers `Pair` over the tunnel with
    /// `InvalidHostID` whatever the request carries, and resets every request
    /// on port 62078, so no app could use such a record there anyway. See
    /// NOTES.md ("lockdownd refuses it").
    static var canMintLockdownRecord: Bool {
        !ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
    }

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
    private(set) var importedPairingName: String? =
        UserDefaults.standard.string(forKey: Engine.importedPairingNameKey)
    /// True while a picked pairing file is being read in.
    private(set) var isImportingPairing = false

    static let importedPairingNameKey = "importedPairingFileName"
    var signInStatus: String = "signed out"

    // Path to the pairing file in use (generated by RPPairing or imported).
    var pairingFilePath: String?

    // MARK: One-click orchestration state

    /// Per-step status, behind the checklist and progress bar.
    var stepStates: [Step: StepState] = Dictionary(
        uniqueKeysWithValues: Step.allCases.map { ($0, .pending) })

    /// Install percentage (0…1) streamed from installation_proxy.
    var installProgress: Double = 0

    /// Download percentage (0…1) streamed from the downloader while that
    /// step is running; mirrors SideBySideView's own downloadProgress.
    var downloadProgress: Double = 0

    /// B1 (0.9.155): bytes arrived so far on a download whose total the
    /// server never stated — non-nil only then, so the progress card can
    /// switch to an indeterminate bar plus this byte count instead of a
    /// 0% that never moves. Reset with the run and at each download start.
    var downloadBytesWritten: Int64?

    /// F-2 (0.9.157): the download step's speed in bytes per second, and
    /// the estimated seconds left — the Install tab's progress card shows
    /// them like the source rows do (F-C). Speed is 0 until two samples
    /// arrive; the estimate is nil while the total is unknown or no speed
    /// is known yet. The total the server promised, -1 while unknown:
    /// drives the "x of y" in the card's detail line.
    var downloadSpeed: Double = 0
    var estimatedTimeRemaining: TimeInterval?
    var downloadTotalBytes: Int64 = -1
    /// The last sample `noteDownloadDetail` measured speed from.
    private var downloadSpeedSampler = DownloadSpeedSampler()

    /// The pairing PIN to display prominently, when one has been issued.
    var pairingPIN: String?

    /// Short human summary of the connected device, e.g. "iPhone · iOS 17.5".
    var deviceSummary: String?

    /// The connected iPhone's UDID and name, from the lockdown handshake.
    private(set) var deviceUDID: String?
    private(set) var deviceName: String?

    /// The current contextual instruction card (nil = none).
    var guide: Guide?

    /// True when signing stopped on error 7460; offers revoke-and-retry.
    var certConflict: Bool = false

    /// True while the one-click pipeline is running.
    var isRunning: Bool = false

    /// 本次安装会话的归属凭证：三条管线起跑时（resetRun 之后、
    /// isRunning = true 之前）各 mint 一个新 UUID，resetRun 先把
    /// 旧值清掉，旧凭证从此再匹配不上。Engine 是单管线，isRunning
    /// 只能说“有安装在跑”，说不出是谁的——企业页/文件页起跑后快照
    /// 它、结束时比对才认。跑完不清零（下一跑起跑时自然轮换；
    /// 清零会让结束时的比对永远对不上）。
    var installSessionID: UUID?

    /// B4 (0.9.158): the signer the history records for this run, when it
    /// isn't the Apple ID — the enterprise-cert and already-signed installs
    /// never sign in, so they set this to the active enterprise profile's
    /// name (see `enterpriseCertHistoryIdentity`); nil means the Apple ID
    /// path, which records `normalizedAppleID` as before. Set after
    /// `resetRun` (which clears it), read by `finishSuccess` and the two
    /// recordFailure sites of those two pipelines.
    var historyIdentityOverride: String?

    /// True from a cancel until the run stops, which waits for the step in
    /// flight to reach a safe point.
    private(set) var isCancelling: Bool = false

    /// Set when the pipeline stops on an error; cleared on a new run.
    var lastError: String?

    /// F-2 (0.9.160): the entitlements precheck's warning for this run
    /// (a free Apple ID certificate can't provide some capabilities the
    /// IPA asks for). A warning, not an error: the run goes on, and the
    /// Install tab shows it in an alert; cleared by `resetRun`.
    var installWarning: String?

    /// Set when a download falls back to a copy already in Documents; shown
    /// as a caption under the progress card, never a blocking error.
    var downloadFallbackNotice: String?

    /// C25：安装时配对/证书交接失败只记日志时留的提示（照抄 C23 的
    /// SideBySide 手法）：run 照常成功，但这句留在进度卡下方，几天后
    /// SideStore 索要配对文件/要求重签时能把因果连起来。resetRun 清掉。
    var handOffNotice: String?

    /// Set once the whole pipeline has completed successfully.
    var finished: Bool = false

    /// What this run put into Madeira, so the last steps can say what's there.
    private var madeiraHandoff = MadeiraHandoff()
    /// True once this run put the pairing file into AltStore, whose Remote
    /// AltServer setup then skips pairing.
    private var altStoreHoldsPairing = false

    /// Set when the success popup, or the LiveContainer certificate popup, is
    /// closed; a new run brings them back.
    private var successClosed = false
    private var liveContainerImportClosed = false

    /// True once the Local Network prompt has been raised this launch, so the
    /// imported-pairing path asks at most once.
    @ObservationIgnored private var askedLocalNetwork = false

    @ObservationIgnored private var pipelineTask: Task<Void, Never>?
    /// The IPA download a run starts as soon as the network is up, so it runs
    /// alongside pairing and sign-in instead of after them.
    @ObservationIgnored private var prefetch: (source: InstallSource, channel: ReleaseChannel, version: String?,
                           task: Task<String, Error>)?
    /// The Apple ID sign-in a run starts once pairing is settled, so it runs
    /// while the device link opens.
    @ObservationIgnored private var backgroundSignIn: Task<Void, Error>?
    /// Device work a run starts once the link is open, so it overlaps sign-in,
    /// download and signing; see `startDevicePreparation`.
    @ObservationIgnored private var devicePreparation: Task<PreparedPairing, Never>?
    /// The files signing won't change, copied to the device from the downloaded
    /// IPA while signing runs; see `startPrestage`.
    @ObservationIgnored private var prestage: Task<DeviceConnection.PrestagedBundle?, Never>?
    /// The certificate hand-off for the build just signed, built on the sign
    /// queue while the install runs; see `startAccountConfig`. Cancelled with
    /// the rest of the pipeline (B-C1) — a cancelled run used to leave it
    /// holding the sign queue.
    @ObservationIgnored private var accountConfigTask: Task<String?, Never>?
    /// Runs that have ended. A background sign-in carries the count from when it
    /// started, so a 2FA request it makes after its run stopped can be declined.
    /// Main thread only.
    @ObservationIgnored private var finishedRuns = 0
    /// Held while a Trust prompt has the user's attention, so a 2FA sheet waits
    /// instead of covering it.
    let attention = AttentionGate()
    /// Poll that keeps `vpnConnected` live; NWPathMonitor never fires for a
    /// loopback tunnel, which carries no default route.
    @ObservationIgnored private var statusTimer: Timer?
    /// The last probe of a full-tunnel VPN, and the one running, if any; see
    /// `fullTunnelAnswer`. Main thread only.
    @ObservationIgnored private var lastFullTunnelProbe: (key: String, result: NetworkStatus.ProbeResult, date: Date)?
    @ObservationIgnored private var fullTunnelProbe: (key: String, task: Task<NetworkStatus.ProbeResult, Never>)?

    /// The build installed, or being installed: the one picked, or the build
    /// of SideInstaller's own that a custom IPA turned out to be, which is set
    /// up just like that build's download.
    private var installedBuild: InstallSource {
        let source = downloadedSource ?? installSource
        guard source == .custom else { return source }
        return recognizedSource ?? .custom
    }

    /// True when the installed build is LiveContainer + SideStore.
    var installedIsLiveContainer: Bool {
        installedBuild == .liveContainer
    }

    /// Name of the build that was installed, or is selected.
    var installedSourceName: String {
        let source = installedBuild
        if source == .custom, let signed = signedDisplayName { return signed }
        return source.displayName
    }

    /// Home-screen name of the app that landed on the device.
    var installedAppName: String {
        installedBuild.pairingAppDisplayName
            ?? signedDisplayName
            ?? L("your app")
    }

    /// Overall fraction across all steps (0…1).
    var overallProgress: Double {
        let total = Double(Step.allCases.count)
        let done = Double(Step.allCases.filter { stepStates[$0] == .done }.count)
        // The download step fills its own share as bytes arrive (SideBySideView
        // does the same); the install step keeps its own fraction after it.
        var frac = 0.0
        if stepStates[.download] == .active { frac = downloadProgress }
        if stepStates[.install] == .active || stepStates[.install] == .waiting {
            frac = installProgress
        }
        return min(1, (done + frac) / total)
    }

    // Long-lived device link over the loopback tunnel, serialized on deviceQueue.
    let connection = DeviceConnection()
    private let deviceQueue = DispatchQueue(label: "sideinstaller.device")

    // Apple ID sign-in and signing (isideload), serialized on signQueue.
    private let signQueue = DispatchQueue(label: "sideinstaller.sign")
    @ObservationIgnored private var signSession: OpaquePointer?          // SignSession*
    /// Sign-in generation stamp (A21-1, mirrors CertManager.signInGeneration):
    /// bumped on every account switch, so a sign-in that waited through a
    /// switch is discarded instead of signing back into the old account.
    private var signInGeneration = 0
    /// Team ID of the signed-in account, parsed from the sign-in summary. Only
    /// apps signed by this team can be refreshed in place.
    private(set) var signingTeamID: String?
    /// UserDefaults key persisting the last signed-in team across launches,
    /// so the refresh list can leave other teams' apps out from a cold start,
    /// before any sign-in has happened this run.
    static let savedTeamKey = "CZFSavedSigningTeamID"
    var downloadedIPAPath: String?
    /// B2：两路已签名安装（企业证书 / 已签 IPA）在配对窗口期的源路径——
    /// 配对完成前 downloadedIPAPath 还没置位，isInstallingSource 认不出
    /// 源文件，删/移/改名会把安装读的文件弄没。起跑时（isRunning = true
    /// 之后、管线 Task 之前）登记，收尾（isRunning = false 处）注销；
    /// 只做守卫用，不进 download() 的“已下载”快路径（那是
    /// downloadedIPAPath 的事，提前置它会让后续 custom 一键安装误采
    /// 残留路径——importCustomIPA 只在新导入时清它）。
    var installingSourcePath: String?
    // Source, channel and picked version (nil: latest) the current download
    // corresponds to.
    private var downloadedSource: InstallSource?
    private var downloadedChannel: ReleaseChannel?
    private var downloadedVersion: String?
    /// For a custom IPA, the build of SideInstaller's own it is, if it is one
    /// (`IPALibrary.knownSource`).
    private var recognizedSource: InstallSource?
    var signedAppPath: String?
    /// CFBundleDisplayName read off the signed bundle.
    private(set) var signedDisplayName: String?
    /// Filename of the IPA imported for `InstallSource.custom`, if any.
    private(set) var customIPAName: String?
    /// Set by the share / “Open with” path after a successful IPA import.
    /// RootView jumps to the Install tab on it, so a run the share started
    /// (or the guide it stopped on) is in front instead of the user having
    /// to go to the Install tab by hand. Cleared when RootView consumes it.
    var sharedIPAReady = false
    /// The build of SideInstaller's own that the imported IPA is, if it is one.
    private(set) var customIPABuild: InstallSource?
    /// True while a picked IPA is being copied in.
    private(set) var isImportingIPA = false
    /// Download progress of a link import (0…1); nil for file imports.
    private(set) var importProgress: Double?
    /// B1 (0.9.155): bytes arrived so far on a link import whose total the
    /// server never stated — set only then (with `importProgress` cleared,
    /// so the link row goes indeterminate), so the row can show the byte
    /// count instead of a stuck 0%.
    private(set) var importBytes: Int?
    /// The link import's task, so the link row can cancel a download in
    /// progress (B1, 0.9.147). The file-copy import has no such task: it
    /// finishes too fast to need one.
    @ObservationIgnored private var linkImportTask: Task<Bool, Never>?

    /// Lets one Apple ID sign-in talk to Apple at a time, whichever feature
    /// started it.
    let appleSignIns = AppleSignInQueue { Engine.shared.log($0) }

    // 2FA bridge: a sign-in's FFI callback blocks until the sheet answers its
    // request.
    /// What the two-factor sheet shows; nil while no sign-in is asking.
    private(set) var twoFactor: TwoFactorPhase?
    private let twoFactorRequests = TwoFactorRequests(markingCancelled: { $0.markTwoFactorCancelled() })
    // Team bridge: likewise for which developer team signs, when the Apple ID
    // is on more than one and none of them was picked yet.
    /// What the team sheet shows; nil while no sign-in is asking.
    private(set) var teamQuestion: TeamQuestion?
    private let teamRequests = TeamRequests(markingCancelled: { $0.markTeamQuestionCancelled() })

    private init() {
        installLogging()
        // Restore the last signed-in team so refresh lists can exclude other
        // teams' apps (enterprise certificates etc.) from a cold start.
        signingTeamID = UserDefaults.standard.string(forKey: Self.savedTeamKey)
        log("SideInstaller ready.")
        // Self-test of the Rust tracing -> FFI callback -> console path.
        ping()
        // Show the tunnel/Wi-Fi status on launch, then keep it live.
        checkVPNAndWifi()
        startStatusMonitor()
        // Refresh the anisette server picker from the live community list.
        loadAnisetteServers()
        // What's installed may have changed while the app was away.
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.foregroundVisits += 1
        }
        // A-11：启动时三件磁盘活（自定义导入读盘 + 源识别 + Madeira CI
        // 搬家）移出主线程——以前在 init 里同步跑，进页第一帧就卡；
        // 算完回主线程一次写回。showCustomImport 的 build 参数接
        // 预计算值，不再主线程上重读 zip。
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let customURL = IPALibrary.customImport()?.url
            let build = customURL.flatMap { IPALibrary.knownSource(ofIPAAt: $0) }
            IPALibrary.moveMadeiraCIBuildsToNightly()
            await MainActor.run {
                self.showCustomImport(customURL, build: build)
            }
        }
    }

    // MARK: - Anisette servers

    /// Swap the bundled anisette list for the live one, keeping it on failure.
    /// The live list is cached for 24h (S5), so most launches don't re-fetch.
    func loadAnisetteServers() {
        Task { @MainActor in
            do {
                let servers = try await AnisetteServer.fetchListCached()
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
        // Before init, so the first idevice line is already filtered.
        si_log_set_verbose(verboseLogging ? 1 : 0)
        let rc = si_log_init(siLogCallback, nil)
        if rc == 0 {
            log("si_log_init: OK — idevice tracing is now piped into this console.")
        } else {
            log("si_log_init: already initialised (rc=\(rc)).")
        }
        if verboseLogging {
            log("Verbose logging is on: idevice's DEBUG lines are included.")
        }
    }

    /// Append a line from Swift to the activity log (`LogStore`). Safe to call
    /// from any thread.
    func log(_ message: String) {
        LogStore.shared.append(message)
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
            self.downloadProgress = 0
            self.downloadBytesWritten = nil
            self.clearDownloadSpeed()
            self.downloadFallbackNotice = nil
            self.handOffNotice = nil
            self.pairingPIN = nil
            self.guide = nil
            self.deviceSummary = nil
            self.deviceUDID = nil
            self.deviceName = nil
            // B-2：旧会话凭证在此过期——三个入口在 resetRun 之后、
            // isRunning = true 之前各 mint 一个新 UUID；跑完不清零
            //（结束时的比对还要认它），下一跑起跑时自然轮换。
            self.installSessionID = nil
            // B4 (0.9.158): the history-signer override goes with it — the
            // Apple ID path reads nil, the other two set it after this.
            self.historyIdentityOverride = nil
            self.lastError = nil
            self.installWarning = nil
            self.pendingInvalidLinkMessage = nil
            self.finished = false
            self.successClosed = false
            self.liveContainerImportClosed = false
            self.certConflict = false
            self.madeiraHandoff = MadeiraHandoff()
            self.altStoreHoldsPairing = false
            // F-2 (0.9.159): the last run's downgrade decline goes with it —
            // a fresh run asks again, and the batch path must not read a
            // stale decline as this run's.
            self.downgradeDeclined = false
            self.downgradeDeclinedMessage = nil
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

    /// F-1 (0.9.158): nil when the IPA described by `info` runs on `os`,
    /// else the user-facing reason it can't — the IPA's own
    /// MinimumOSVersion, not the source's floor
    /// (`InstallSource.minimumOSMajorVersion`, which only covers
    /// SideInstaller/SideStore/LiveContainer's own builds). An IPA whose
    /// minimum can't be read never blocks: it signs ahead as before.
    static func minOSBlockReason(info: IPALibrary.AppInfo,
                                 runningOn os: OperatingSystemVersion, osText: String) -> String? {
        guard let minOS = info.minOS,
              !SideStoreDownloader.runs(on: os, from: minOS, to: nil) else { return nil }
        return L("%@ needs iOS %@ or later. This iPhone runs iOS %@.", info.name, minOS, osText)
    }

    /// F-2 (0.9.160): entitlement keys a free Apple ID certificate can't
    /// provide, mapped to the name the warning shows. Grounded in the
    /// repo, not from memory: `Entitlement.all`'s catalogue comment
    /// names Push, iCloud and Associated Domains as the paid-only ones
    /// left out of what a free account can be granted, and `SideloadedApp`
    /// notes `beta-reports-active` is granted only by App Store
    /// distribution profiles. Every other key is deliberately NOT here:
    /// the free catalogue (App Groups, Game Center, HealthKit, …) is
    /// grantable, and an unknown key may be harmless — warn only on
    /// what the code proves a free certificate can't give.
    private static let paidOnlyEntitlementNames: [String: String] = [
        "aps-environment": "Push Notifications",
        "com.apple.developer.icloud-container-identifiers": "iCloud",
        "com.apple.developer.ubiquity-container-identifiers": "iCloud",
        "com.apple.developer.icloud-services": "iCloud",
        "com.apple.developer.associated-domains": "Associated Domains",
        "beta-reports-active": "TestFlight beta reports",
    ]

    /// F-2 (0.9.160): the paid-only capabilities the IPA at `url` asks
    /// for, from the Entitlements in its `embedded.mobileprovision`
    /// (`IPALibrary.embeddedProvisionData` + `ProvisioningProfile`,
    /// the same single-entry read `provisionTeamID` uses — no full
    /// unpack). An unsigned IPA's profile is its original signing's,
    /// the only capability signal the file carries; no profile, or an
    /// unreadable one, means nothing is known, so no warning — never a
    /// guess. Boilerplate keys never reach here: `capabilityKeys`
    /// already filters `application-identifier`, the team id, the
    /// keychain groups and `get-task-allow`.
    static func unsupportedEntitlements(inIPA url: URL) -> [String] {
        guard let data = IPALibrary.embeddedProvisionData(inIPA: url),
              let profile = ProvisioningProfile(data: data) else { return [] }
        return Array(Set(profile.capabilityKeys.compactMap { paidOnlyEntitlementNames[$0] })).sorted()
    }

    /// B4 (0.9.158): the signer the history records for the two installs
    /// that never sign in with an Apple ID (enterprise-cert and
    /// already-signed): the active enterprise profile's name. No profile:
    /// the provisioning profile file's name when one is on disk, else
    /// empty — never the Apple ID saved in Settings.
    private static func enterpriseCertHistoryIdentity() -> String {
        if let name = EnterpriseCertStore.activeProfile()?.name, !name.isEmpty { return name }
        if EnterpriseCertStore.hasProvision { return EnterpriseCertStore.provisionURL.lastPathComponent }
        return ""
    }

    /// Run every install step in order, stopping at the first failure.
    /// `afterProbe` is set on the second pass, once a full-tunnel VPN's probe
    /// has answered.
    @MainActor
    func runOneClick(afterProbe: Bool = false) {
        guard !isRunning else { return }
        // F-2 (0.9.160): the last run's precheck warning goes with it —
        // the early guards below return before resetRun runs, so a stale
        // warning would otherwise pop on a run that never started.
        installWarning = nil
        // B-1 (0.9.163): a run the guards stop never reaches resetRun, so
        // a stale lastError/guide from the previous run would outlive it
        // — the batch and history readers below would report the old
        // failure as this run's. Clear both up front; every guard below
        // leaves its own fresh reason (a guide, or lastError), so nothing
        // real is lost.
        lastError = nil
        guide = nil
        // B-3 (0.9.163): a pairing file being generated drops the device
        // link when it finishes (`pairThisDevice`), so an install started
        // now would lose its link mid-run — refuse until generation is
        // done (`generateForPage` refuses the other way round, while an
        // install is running).
        guard !PairingManager.shared.isGenerating else {
            lastError = L("Pairing file is being generated. Wait for it to finish, then try again.")
            log("⛔️ Pairing file is being generated — install refused until it finishes, so the link isn't dropped mid-install.")
            return
        }
        // Nothing downstream works on an older iOS.
        guard osSupported else {
            // B-1 (0.9.163): the log-only branch left no reason behind —
            // the readers below would report the previous run's error.
            lastError = L("iOS %@ isn't supported — SideInstaller needs iOS %@ or later.",
                          osVersionText, Engine.minimumTunnelOSText)
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
        // Installing a build this iOS can't run would only use up an App ID.
        if let needed = installSource.minimumOSMajorVersion,
           !ProcessInfo.processInfo.isOperatingSystemAtLeast(
               OperatingSystemVersion(majorVersion: needed, minorVersion: 0, patchVersion: 0)) {
            lastError = L("%@ needs iOS %d or later. This iPhone runs iOS %@.",
                          installSource.displayName, needed, osVersionText)
            log("⛔️ \(installSource.displayName) needs iOS \(needed) or later; this iPhone runs iOS \(osVersionText).")
            return
        }
        // A custom install needs its IPA before anything else runs.
        if installSource == .custom, IPALibrary.customImport() == nil {
            setGuide(Guides.customIPA)
            log("⛔️ No IPA imported yet. Tap “Import .ipa” and pick one, then tap Install again.")
            return
        }
        // F-1 (0.9.158): the imported IPA's own minimum — the source floor
        // above only covers SideInstaller's own builds. Block before
        // signing, so a too-new IPA doesn't burn an App ID first.
        if installSource == .custom, let entry = IPALibrary.customImport(),
           let info = IPALibrary.appInfo(at: entry.url),
           let reason = Self.minOSBlockReason(info: info,
                                              runningOn: ProcessInfo.processInfo.operatingSystemVersion,
                                              osText: osVersionText) {
            lastError = reason
            log("⛔️ \(reason)")
            return
        }
        // F-2 (0.9.160): entitlements precheck — warn, don't block. A
        // free certificate signs the app either way, but capabilities it
        // can't provide fail silently after install (push never arrives,
        // iCloud never syncs), so say so up front while the run is
        // starting instead of letting the user find out later. Only the
        // custom path has an IPA to read; the built-in sources are
        // SideInstaller's own builds.
        if installSource == .custom, let entry = IPALibrary.customImport() {
            let missing = Self.unsupportedEntitlements(inIPA: entry.url)
            if !missing.isEmpty {
                installWarning = L("This IPA asks for %@, which a free Apple ID certificate can't provide. Those features will silently stop working after install.", missing.joined(separator: ", "))
                log("⚠️ Entitlements precheck: \(missing.joined(separator: ", ")) not available on a free certificate.")
            }
        }
        // The install runs over the loopback tunnel, so require it up front,
        // unless the run can start LocalDevVPN itself (see `ensureNetwork`).
        refreshNetworkStatus()
        guard !needsFreshPairing || wifiConnected else {
            setGuide(Guides.wifi)
            log("⛔️ Wi-Fi is off, and pairing this iPhone needs it. Connect to a Wi-Fi network, then tap Install again.")
            return
        }
        guard tunnelAvailable else {
            // A full-tunnel VPN counts as down until its probe answers, which
            // takes half a second at most: wait for it, then decide.
            if !afterProbe, awaitsFullTunnelProbe() {
                Task { @MainActor in
                    await self.settleNetworkStatus()
                    self.runOneClick(afterProbe: true)
                }
                return
            }
            if BuiltinTunnel.useBuiltinDirectly {
                // 内置隧道在包里就不再弹 LocalDevVPN 指引卡：
                // 自动启动关着时，装不成的原因是那个开关。
                // B-1 (0.9.163): the log-only branch left no reason
                // behind — say it in lastError too, so the callers that
                // read it report this run's cause, not the last run's.
                lastError = L("No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.")
                log("⛔️ No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.")
            } else {
                setGuide(Guides.vpn)
                log("⛔️ No loopback VPN is connected. Turn one on, then tap Install again.")
            }
            return
        }
        // A tunnel pointed at this iPhone's own address can never connect.
        // 0.9.140: a stale own-address falls back to the default first
        // (`deviceIPIsUsable` logs the same line below when it can't).
        if !deviceIPIsUsable() {
            setGuide(Guides.deviceIPMismatch)
            return
        }
        resetRun()
        // B-2：起跑前 mint 新会话凭证（resetRun 已清掉旧值）。
        installSessionID = UUID()
        isRunning = true
        log("=== Starting one-click install ===")
        // 切后台断安装的根因：InstallActivity（iOS 26 的
        // BGContinuedProcessingTask + 全程 UIKit 后台时间）写好了却
        // 从没被接进管线，runStarted/runEnded 全仓零调用。接上后，
        // 切后台由后台任务接着跑，没任务时也有半分钟 grace + 回前台续跑，
        // 而不是一离前台就被挂起、隧道断掉。
        InstallActivity.shared.runStarted()

        pipelineTask = Task { @MainActor in
            var outcome: InstallActivity.Outcome = .stopped
            var tunnelAcquired = false
            do {
                // F-2 (0.9.159): an older custom IPA asks first, before the
                // tunnel is taken — a decline stops here with
                // CancellationError (no failure history), a cancel answers
                // the prompt the same way.
                if let downgrade = downgradeCheckForCurrentRun(),
                   !(await confirmDowngrade(downgrade)) {
                    throw CancellationError()
                }
                // SIDE-2：隧道按需开——管线开始拿租约，收尾统一还；拿不到按
                // ensurePairingConnection 同款文案报错（入口 tunnelAvailable
                // 守卫已先拦过一轮，这里是竞态兜底）。
                guard await acquireTunnel() else {
                    if Task.isCancelled { throw CancellationError() }
                    throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                        ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                        : L("LocalDevVPN isn't connected. Connect it, then try again."))
                }
                tunnelAcquired = true
                try await ensureNetwork()
                // The download needs neither the device nor the Apple ID, so it
                // starts now and runs while those steps do.
                startPrefetch()
                try await pairAndConnect()
                // Device work that doesn't need the signed app starts on the fresh
                // link and runs through sign-in, download and signing.
                startDevicePreparation()
                try await signInStep()
                try await download()
                // Signing registers App IDs, which a free Apple ID has few of,
                // so an imported IPA waits for the go-ahead first, unless it's
                // one of SideInstaller's own builds, installed like its download.
                if installedBuild == .custom {
                    try await confirmAppIDCost()
                }
                // Most of the app is the same signed or not, so that part goes
                // to the device while signing runs.
                startPrestage()
                try await signApp()
                // The certificate hand-off is built on the sign queue, which the
                // install doesn't use, so it's ready once the install is done.
                accountConfigTask = startAccountConfig()
                // Both share the device queue with the install.
                let prepared = await devicePreparation?.value
                let staged = await prestage?.value
                try Task.checkCancellation()
                try await install(prestaged: staged)
                try await writePairing(accountConfig: accountConfigTask, prepared: prepared)
                finishSuccess()
                outcome = .installed
            } catch is CancellationError {
                outcome = .cancelled
                log("Install cancelled.")
                // A cancelled run leaves no progress behind, so the Install
                // tab goes back to its button.
                for s in Step.allCases { stepStates[s] = .pending }
                installProgress = 0
                downloadProgress = 0
                clearDownloadSpeed()
                deviceSummary = nil
                deviceUDID = nil
                deviceName = nil
                setGuide(nil)
            } catch {
                let msg = userFacingErrorMessage(error)
                let raw = String(describing: error)
                lastError = msg
                log("⛔️ Stopped: \(raw)")
                failActiveStep(to: .failed)
                // F-A (0.9.155): a failed run leaves a history entry too,
                // with the reason it stopped — the success path's
                // `finishSuccess` is the only other writer, so one run
                // writes exactly one entry, success or failure.
                InstallHistoryStore.recordFailure(appName: installedAppName,
                                                  version: signedAppVersion() ?? downloadedVersion,
                                                  identity: normalizedAppleID,
                                                  reason: msg,
                                                  bundleID: signedAppBundleID())
            }
            InstallActivity.shared.runEnded(outcome)
            if tunnelAcquired { releaseTunnel() }
            stopBackgroundWork()
            // C20：签好的包解在 tmp/<名>_<uuid>_extracted，收尾删掉它再置 nil；
            // 删失败静默（helper 内 try?）；目录名带唯一 UUID，下次签同名也不会复用它。
            if let signed = signedAppPath { Self.discardSignedBundle(at: signed) }
            signedAppPath = nil
            // B2：收尾注销配对窗口期的源路径登记（与起跑登记配对）。
            installingSourcePath = nil
            isRunning = false
            isCancelling = false
            pairingPIN = nil
        }
    }

    /// Stop the pipeline at the next safe point.
    @MainActor
    func cancelOneClick() {
        guard isRunning else { return }
        isCancelling = true
        pipelineTask?.cancel()
        prefetch?.task.cancel()                 // stop the download now, not at its step
        devicePreparation?.cancel()             // skip its ahead-of-install write
        prestage?.cancel()
        accountConfigTask?.cancel()             // B-C1：交接任务也随管线取消
        accountConfigTask = nil
        PairingController.shared.softCancel()   // unblock a pending pairing wait
    }

    // MARK: Popups

    /// One of the Install tab's popups. Each was a card under the progress
    /// before; they stack in this order, which the copy relies on ("Revoke and
    /// retry above", "see the steps above", "the trust step above"). Each
    /// carries what it shows, so it keeps its content while it closes.
    enum Popup: Hashable {
        /// The code Settings asks for while this iPhone pairs.
        case pairingCode(String)
        /// Revoke-and-retry, after Apple error 7460.
        case certConflict
        case guide(Guide)
        case error(String, stoppedRun: Bool)
        /// The build is on the device, named; `leads` when the trust step
        /// follows it instead of coming first.
        case success(String, leads: Bool)
        /// LiveContainer still needs SideStore's certificate imported.
        case liveContainerImport
        /// What signing an imported IPA costs in App IDs, before it's signed.
        case appIDCost(AppIDCost)
        /// A pairing file for another iPhone, asking before it replaces the one in use.
        case pairingImportMismatch(PairingImportMismatch)
        /// A `sideinstaller://` link, asking before it's acted on.
        case link(DeepLink)
        /// A big download on cellular data, asking before it starts (F-G, 0.9.156).
        case cellularDownload(CellularDownloadRequest)
        /// A custom IPA older than the copy on this iPhone, asking before it
        /// installs over it (F-2, 0.9.159).
        case downgrade(DowngradeRequest)
    }

    /// F-2 (0.9.159): what the downgrade prompt shows — the app, the version
    /// on this iPhone, and the version in the IPA about to install over it.
    struct DowngradeRequest: Hashable {
        let appName: String
        let installedVersion: String
        let ipaVersion: String
    }

    /// F-2 (0.9.159): a custom IPA older than the installed copy, waiting for
    /// the go-ahead. The pipeline asks before it takes the tunnel, so a
    /// declined downgrade burns nothing — no App ID, no signing.
    private(set) var downgradeRequest: DowngradeRequest?
    private var downgradeReply: CheckedContinuation<Bool, Never>?

    /// F-2 (0.9.159): true when the user declined the downgrade prompt for
    /// this run (as opposed to the run being cancelled). The batch path reads
    /// it so one declined item skips instead of stopping the whole batch;
    /// `downgradeDeclinedMessage` is the reason it reports for that item.
    private(set) var downgradeDeclined = false
    private(set) var downgradeDeclinedMessage: String?

    /// True while the run is held up on the user — joining Wi-Fi, connecting
    /// the tunnel, or pairing in Settings.
    var isWaitingOnUser: Bool {
        isRunning && stepStates.values.contains(.waiting)
    }

    /// The Install tab's popups up now, top to bottom. While the run goes, only
    /// what it's waiting on shows; the rest waits for it to end.
    var popups: [Popup] {
        if isRunning {
            // F-G (0.9.156): the cellular prompt is a waiting popup too, but
            // no step is `.waiting` while it asks — the download hasn't
            // started yet — so it joins this list on its own, or the run
            // would hang on an answer the user can't give.
            // F-2 (0.9.159): the downgrade prompt is the same shape — asked
            // before the tunnel is taken, while no step is `.waiting`.
            guard isWaitingOnUser || cellularDownloadRequest != nil || downgradeRequest != nil else { return [] }
            return [pairingPIN.map(Popup.pairingCode), guide.map(Popup.guide),
                    appIDCost.map(Popup.appIDCost),
                    cellularDownloadRequest.map(Popup.cellularDownload),
                    downgradeRequest.map(Popup.downgrade)].compactMap { $0 }
        }
        if finished { return finishedPopups }
        var shown: [Popup] = []
        if let mismatch = pairingImportMismatch { shown.append(.pairingImportMismatch(mismatch)) }
        if let link = pendingLink { shown.append(.link(link)) }
        // B1 (0.9.152): an invalid link that arrived mid-run also shows once
        // the run ends — on a failed run the finished list never appears.
        if let invalid = pendingInvalidLinkMessage { shown.append(.error(invalid, stoppedRun: false)) }
        if certConflict { shown.append(.certConflict) }
        if let guide { shown.append(.guide(guide)) }
        if let lastError {
            shown.append(.error(lastError, stoppedRun: stepStates.values.contains(.failed)))
        }
        if let cellular = cellularDownloadRequest { shown.append(.cellularDownload(cellular)) }
        return shown
    }

    /// A finished run's popups: the trust step, the news, and LiveContainer's
    /// certificate import. With all three up the news leads, so both steps
    /// follow it; otherwise it comes after the trust step it points to.
    private var finishedPopups: [Popup] {
        let trust = guide.map(Popup.guide)
        let certificate: Popup? = installedIsLiveContainer && !liveContainerImportClosed
            ? .liveContainerImport : nil
        let leads = trust != nil && certificate != nil
        let success: Popup? = successClosed ? nil : .success(installedSourceName, leads: leads)
        // B1 (0.9.152): a link that arrived mid-run used to sit in
        // `pendingLink` while `finished` made `popups` return only this
        // list — it never showed until a later run failed. It joins the
        // finished popups now, after the success/trust steps; an invalid
        // link from the same run shows as an error card instead of only
        // landing in the log.
        let link: Popup? = pendingLink.map(Popup.link)
        let invalid: Popup? = pendingInvalidLinkMessage.map { .error($0, stoppedRun: false) }
        // B-1 (0.9.157): a cellular prompt that arrived while the run was
        // finishing used to sit in `cellularDownloadRequest` while
        // `finished` made `popups` return only this list — it never
        // showed, and the next download sat at 0 with no explanation.
        // It joins the finished popups now, after the success/trust
        // steps (the 0.9.152 link fix's shape, one list over).
        let cellular: Popup? = cellularDownloadRequest.map(Popup.cellularDownload)
        return (leads ? [success, trust, certificate, link, invalid, cellular]
                      : [trust, success, certificate, link, invalid, cellular])
            .compactMap { $0 }
    }

    /// True for a popup the run is waiting on: closing it cancels the install.
    func blocks(_ popup: Popup) -> Bool {
        switch popup {
        case .pairingCode, .guide, .appIDCost: return isWaitingOnUser
        // F-G (0.9.156): the cellular prompt blocks while a run is in flight
        // (prefetch or the download step); with no run it just declines.
        case .cellularDownload:                return isRunning
        // F-2 (0.9.159): the downgrade prompt blocks the same way — the run
        // waits on its answer, and closing it stops the run.
        case .downgrade:                       return isRunning
        default:                               return false
        }
    }

    /// Closes one of the Install tab's popups. The run can't go on without one
    /// it's waiting on, so closing that cancels the install, taking the other
    /// popups it was waiting on along; any other just clears its message.
    @MainActor
    func closePopup(_ popup: Popup) {
        if blocks(popup) {
            cancelOneClick()
            pairingPIN = nil
            guide = nil
            // F-G (0.9.156): answer the cellular prompt directly too — the
            // waiter isn't always the pipeline (a source download can ask
            // while a run is in flight), and only the pipeline's cancel
            // reaches its `onCancel`. `answerCellularDownload` no-ops when
            // the handler already answered, so this can't resume twice.
            if case .cellularDownload = popup { answerCellularDownload(false) }
            // F-2 (0.9.159): the downgrade prompt's waiter is always the
            // pipeline, so its cancel reaches `onCancel` — but answering
            // here too is the same no-op guard as the cellular one above.
            if case .downgrade = popup { answerDowngrade(false) }
            return
        }
        switch popup {
        // The steps hang under the code and close with it.
        case .pairingCode:         pairingPIN = nil; guide = nil
        case .certConflict:        certConflict = false
        case .guide:               guide = nil
        case .error:               lastError = nil; pendingInvalidLinkMessage = nil
        case .success:             successClosed = true
        case .liveContainerImport: liveContainerImportClosed = true
        case .appIDCost:             appIDCost = nil
        case .pairingImportMismatch: answerPairingImportMismatch(false)
        case .link:                  pendingLink = nil
        case .cellularDownload:      answerCellularDownload(false)
        case .downgrade:             answerDowngrade(false)
        }
    }


    /// Cancel whatever the run started early and never got to use.
    @MainActor
    private func stopBackgroundWork() {
        prefetch?.task.cancel()
        prefetch = nil
        backgroundSignIn?.cancel()
        backgroundSignIn = nil
        devicePreparation?.cancel()
        devicePreparation = nil
        prestage?.cancel()
        prestage = nil
        accountConfigTask?.cancel()
        accountConfigTask = nil
        // A sign-in this run left running now declines any 2FA request.
        finishedRuns += 1
    }

    // MARK: Step 1 — network (waits for the loopback tunnel)

    /// True when this run must pair from scratch, the one step needing Wi-Fi.
    var needsFreshPairing: Bool {
        !fileExistsNonEmpty(pairingFilePath ?? PairingController.pairingFilePath())
    }

    @MainActor
    private func ensureNetwork() async throws {
        setStep(.network, .active)
        // With “Start LocalDevVPN when needed” on, a missing tunnel is started
        // now; if it still doesn't come up, the wait below asks for it.
        _ = await tunnelUp()
        // The blocker last logged, so each one is announced once.
        var announced: String?
        while true {
            try Task.checkCancellation()
            // Waits for a full-tunnel VPN's probe when there's no fresh answer.
            let (vpn, wifi, detail) = await readNetworkSettled()
            publishNetwork(vpn: vpn, wifi: wifi, vpnText: vpn ? "tunnel up" : "no tunnel")
            // Only a run that pairs needs Wi-Fi; the tunnel is always required.
            let wifiSatisfied = wifi || !needsFreshPairing
            if wifiSatisfied && vpn {
                // Install checks this too, but only while a tunnel is up, and
                // this run may have started it.
                // 0.9.140: a stale own-address falls back to the default first
                // (`deviceIPIsUsable` logs the same line below when it can't).
                if !deviceIPIsUsable() {
                    setGuide(Guides.deviceIPMismatch)
                    throw EngineError.message(L("Wrong device IP"))
                }
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
                    log("Waiting for the loopback tunnel…")
                    announced = "vpn"
                }
                // 签名能用内置隧道时不弹 LocalDevVPN 指引卡：隧道由
                // tunnelUp() 和打开 App 时自动连接，弹卡只会误导。
                if !BuiltinTunnel.useBuiltinDirectly {
                    setGuide(Guides.vpn)
                }
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

        // Pairing is settled, so sign in while the link opens. Not sooner: Apple
        // sends its own 2FA alert to this iPhone before SideInstaller is asked
        // for the code, and it would land on the user typing the pairing code.
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
    /// file is used (always below iOS 27, optionally from 27 on).
    ///
    /// Connecting to lockdownd over the tunnel counts as local-network access,
    /// which iOS silently blocks until granted. When the iPhone pairs itself the
    /// RPPairing host already triggers the prompt, but an imported file skips
    /// that step. Best-effort: if denied, the connect still runs and reports its
    /// own error.
    @MainActor
    private func ensureLocalNetworkForImportedPairing() async {
        guard !canSelfPair || importedPairingName != nil, !askedLocalNetwork else { return }
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

    /// Frees the in-memory sign session and waits for it, so a following
    /// signIn() really logs in as the newly activated account. The fire-and-
    /// forget `forgetAppleSession()` below can't be awaited: a signIn() issued
    /// right after it would still see the old session and skip (`signSession
    /// != nil`), silently signing with the wrong account. Runs the free on
    /// `signQueue`, which owns `signSession`, then clears the team on the
    /// main actor. Does NOT delete the saved developer-session token on disk:
    /// the next sign-in reuses it, so an account switch normally needs no
    /// fresh Apple authentication (2FA stays possible as a safety valve).
    @MainActor
    func dropSignSession() async {
        // A21-1：切账号时世代递增——等位中的登录靠它作废（同 forgetAppleSession）。
        signInGeneration += 1
        try? await onSignQueue {
            if let session = self.signSession { si_sign_session_free(session) }
            self.signSession = nil
        }
        signingTeamID = nil
        UserDefaults.standard.removeObject(forKey: Self.savedTeamKey)
        signInStatus = "signed out"
        log("In-memory sign session dropped for an account switch.")
    }

    /// Signs in as the currently active account, for flows outside the Install
    /// tab (e.g. a multi-account refresh switching groups). Thin wrapper over
    /// the private signIn(): no checklist changes, same 2FA/lock/rate-limit
    /// handling. Callers must have dropped the old session first, or this
    /// skips on the existing session.
    @MainActor
    func signInForRefresh() async throws {
        try await signIn(updatingChecklist: false)
    }

    /// Frees the cached sign-in session so the next run signs in as the active
    /// account. Called when credentials change. Runs on `signQueue`, which owns
    /// `signSession`.
    func forgetAppleSession() {
        // A21-1：世代递增放同步处——等位中的登录靠它作废；调用方是主线程的
        // onChange（RootView），与 dropSignSession 同款。
        signInGeneration += 1
        // C19：抓调用时那一个指针——释放块排在登录块后面时，块内重读
        // 当前 session 会把切账号后才登好的新 session 也释放掉（登录块
        // 换 session 时已把旧的释放了，见 performSignIn）。
        let freed = signSession
        signQueue.async { [weak self] in
            guard let self, let freed = freed else { return }
            guard self.signSession == freed else { return }
            si_sign_session_free(freed)
            self.signSession = nil
            self.setMain {
                self.signInStatus = "signed out"
                self.signingTeamID = nil
                UserDefaults.standard.removeObject(forKey: Self.savedTeamKey)
            }
            self.log("Apple ID or its team changed — signed out of the previous sign-in.")
        }
    }

    /// The checklist's sign-in step: waits for the sign-in started alongside the
    /// device link, or signs in now when none was.
    @MainActor
    private func signInStep() async throws {
        do {
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
        } catch {
            // Only the account's owner can unlock it, so show them how.
            if case EngineError.accountLocked = error {
                setGuide(Guides.accountLocked)
            }
            if case EngineError.underage = error {
                setGuide(Guides.underage)
            }
            if case EngineError.emailUnverified = error {
                setGuide(Guides.emailUnverified)
            }
            throw error
        }
    }

    /// Starts the Apple ID sign-in without touching the checklist, unless this
    /// session is already signed in. It runs on the sign queue, apart from the
    /// device link.
    @MainActor
    private func startBackgroundSignIn() {
        guard backgroundSignIn == nil, signSession == nil else { return }
        let run = finishedRuns
        backgroundSignIn = Task { @MainActor in
            try await self.signIn(updatingChecklist: false, run: run)
        }
    }

    /// Signs in to the Apple ID, trying each anisette server in turn, once the
    /// sign-ins queued ahead of it are done (`AppleSignInQueue`).
    /// Pass `updatingChecklist: false` from flows outside the Install tab (e.g.
    /// app refresh) so they don't change its checklist. `run` tags a run's
    /// background sign-in; see `finishedRuns`.
    @MainActor
    private func signIn(updatingChecklist: Bool = true, run: Int? = nil,
                        purpose: AppleSignInPurpose = .install) async throws {
        if signSession != nil {
            log("Already signed in this session — skipping.")
            if updatingChecklist { setStep(.signIn, .done) }
            return
        }
        guard !normalizedAppleID.isEmpty, !applePassword.isEmpty else {
            throw EngineError.message(L("No Apple ID saved. Add one in Settings › Account."))
        }
        if updatingChecklist { setStep(.signIn, .active) }

        let id = normalizedAppleID, pw = applePassword, dir = storageDir
        // A21-1：世代在等位前抓（同 CertManager.signIn 的 A2）。
        let generation = signInGeneration
        let ticket = try await appleSignIns.waitForTurn(purpose, appleID: id, run: run)
        defer { appleSignIns.finished(ticket) }
        // A21-1：等位期间切账号，作废本次尝试——不在旧会话上继续。
        // 放 signSession 检查之前：切账号后旧会话可能还没被释放块清掉，
        // 先看世代，不看会话在不在。
        guard generation == signInGeneration else { throw CancellationError() }
        // A sign-in that went first may have signed this session in.
        if signSession != nil {
            log("Already signed in this session — skipping.")
            if updatingChecklist { setStep(.signIn, .done) }
            return
        }
        // Read once its turn has come, since the one ahead may have picked it.
        let team = AccountStore.shared.team(for: id)?.teamId

        // Anisette servers go down often, so with Auto on try each one before
        // giving up. A server picked in Settings is the only one tried.
        let servers = anisetteCandidates()
        var lastError = L("No anisette servers are configured.")
        var appleRefusals = AnisetteServer.AppleRefusals(servers: anisetteServers)
        var appleUnreachable = 0

        for (idx, ani) in servers.enumerated() {
            try Task.checkCancellation()
            // A21-1（A3 同款）：循环头查世代——切账号后不再拿旧 id/pw 试下一台服务器。
            guard generation == signInGeneration else { throw CancellationError() }
            let name = anisetteName(for: ani)
            if appleRefusals.rulesOut(ani) {
                log("Skipping anisette \(name): Apple has refused the device sign-in reports through it.")
                continue
            }
            signInStatus = servers.count > 1
                ? "signing in via \(name) (\(idx + 1)/\(servers.count))…"
                : "signing in…"
            if servers.count > 1 {
                log("Sign-in attempt \(idx + 1)/\(servers.count) — anisette \(name).")
            }
            do {
                let summary = try await onSignQueue {
                    try self.performSignIn(id: id, pw: pw, ani: ani, dir: dir, team: team, ticket: ticket)
                }
                // A21-1：切账号后完成的旧登录作废——刚登好的会话放掉、清掉
                // performSignIn 已写回的旧团队，再报取消。
                guard generation == signInGeneration else {
                    if let stale = self.signSession {
                        self.signSession = nil
                        signQueue.async { si_sign_session_free(stale) }
                    }
                    signingTeamID = nil
                    UserDefaults.standard.removeObject(forKey: Self.savedTeamKey)
                    signInStatus = "signed out"
                    log("Apple ID changed — signed out of the previous account.")
                    throw CancellationError()
                }
                // Stick with the server that worked.
                anisetteURL = ani
                anisetteSignedIn(ani)
                AccountStore.shared.signedIn(id, withTeam: Self.teamID(inSummary: summary))
                signInStatus = "signed in (\(summary))"
                if updatingChecklist { setStep(.signIn, .done) }
                return
            } catch let error as EngineError {
                // A21-1（A3 同款）：旧登录在 2FA 取消等失败时也不写新账号的 lastError。
                if generation != signInGeneration { throw CancellationError() }
                lastError = error.errorDescription ?? L("Sign-in failed.")

                // A cancelled 2FA prompt isn't the server's fault.
                if ticket.twoFactorWasCancelled {
                    log("Two-factor verification cancelled — stopping.")
                    signInStatus = "signed out"
                    throw EngineError.message(L("Two-factor verification was cancelled."))
                }
                // Nor is a team question closed unanswered.
                if ticket.teamQuestionWasCancelled {
                    log("No developer team picked — stopping.")
                    signInStatus = "signed out"
                    throw EngineError.message(Self.noTeamPickedMessage)
                }
                // A locked account fails everywhere, and retrying keeps it locked.
                if Self.isAccountLocked(lastError) {
                    signInStatus = "sign-in failed"
                    log("Apple has locked this Apple Account: \(lastError)")
                    throw EngineError.accountLocked
                }
                // Apple turns the account down for its owner's age through
                // every anisette server alike.
                if Self.isUnderageError(lastError) {
                    signInStatus = "sign-in failed"
                    log("Apple won't let this Apple Account use developer services: \(lastError)")
                    throw EngineError.underage
                }
                // So does an email address Apple hasn't seen verified, and
                // signing in again only meets the same refusal.
                if Self.isEmailUnverifiedError(lastError) {
                    signInStatus = "sign-in failed"
                    log("Apple wants this Apple Account's email address verified first: \(lastError)")
                    throw EngineError.emailUnverified
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
                // Apple refusing the device sign-in reports looks the same
                // through every server reporting it: after two refusals those
                // are skipped, and the loop ends when no other server is left
                // (`AnisetteServer.AppleRefusals`).
                if Self.isAppleServiceRefusal(lastError) {
                    appleRefusals.record(ani)
                    if appleRefusals.endsSignIn(remaining: servers[(idx + 1)...]) {
                        signInStatus = "sign-in failed"
                        log("Apple's sign-in server refused \(appleRefusals.count) attempts with HTTP 503 — not trying more anisette servers.")
                        throw EngineError.message(Self.appleServiceRefusalMessage)
                    }
                }
                // Every anisette server starts with the same request to Apple, so
                // when that can't even be sent, more of them won't help.
                if Self.isAppleUnreachable(lastError) {
                    appleUnreachable += 1
                    if let message = await appleUnreachableStop(failures: appleUnreachable) {
                        signInStatus = "sign-in failed"
                        throw EngineError.message(message)
                    }
                } else {
                    appleUnreachable = 0
                }
                if idx < servers.count - 1 { log("Trying the next anisette server…") }
            }
        }

        signInStatus = "sign-in failed"
        let tried = servers.count == 1
            ? L("the anisette server")
            : L("all %d anisette servers", servers.count)
        let detail = (lastError == L("No anisette servers are configured."))
            ? lastError : friendlyRustError(lastError)
        throw EngineError.message(L("Apple ID sign-in failed on %@. Last error: %@", tried, detail))
    }

    /// One sign-in attempt against a specific anisette server. `team` is the
    /// team picked for this Apple ID, if one was; without it, or when the
    /// account is no longer on it, Rust asks (`answerTeam`) when there's more
    /// than one.
    private func performSignIn(id: String, pw: String, ani: String, dir: String,
                               team: String?, ticket: AppleSignInTicket) throws -> String {
        defer { endSignInQuestions(for: ticket) }
        log("Apple ID sign-in for \(LogRedactor.maskAppleID(id)) via anisette \(Self.oneLine(ani)) …")
        var session: OpaquePointer?
        var summary: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        // 1 = save and reuse the developer session, so repeat sign-ins skip
        // Apple authentication until the token expires.
        let rc = si_apple_signin(id, pw, ani, "SideInstaller", dir, 1, team ?? "",
                                 appleSignInTwoFactorCallback, appleSignInTeamCallback, ticket.context,
                                 &session, &summary, &error)
        if rc == 0 {
            if let old = self.signSession { si_sign_session_free(old) }
            self.signSession = session
            let s = summary.map { String(cString: $0) } ?? ""
            summary.map { si_string_free($0) }
            let team = Self.teamID(inSummary: s)
            setMain {
                self.signingTeamID = team
                // Remember which account owns this team, so a later
                // multi-account refresh can map an app's team back to the
                // Apple ID that can renew it without signing in first.
                if let team { AccountStore.shared.noteTeamID(team) }
            }
            if let team { UserDefaults.standard.set(team, forKey: Self.savedTeamKey) }
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

    /// Anisette addresses to try (`AnisetteServer.candidates`): the current
    /// pick first, then the Windows-ADI servers, then the rest, macOS-ADI last.
    func anisetteCandidates() -> [String] {
        AnisetteServer.candidates(pick: anisetteURL, servers: anisetteServers)
    }

    /// Friendly name for an anisette address (falls back to the address itself).
    private func anisetteName(for address: String) -> String {
        anisetteServers.first { $0.address == address }?.name ?? address
    }

    /// GrandSlam codes meaning the credentials themselves were rejected.
    private static let credentialErrorCodes = [
        "-20101",   // invalid username/password
        "-20970",   // "Your account information was entered incorrectly." (no such Apple ID, since 2026-10-15; was -20101)
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

    /// Detects GrandSlam -20209, "This Apple Account has been locked for security
    /// reasons. Visit iForgot to reset your account". Only a reset unlocks it.
    static func isAccountLocked(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("-20209")
            || m.contains("locked for security reasons")
            || m.contains("iforgot")
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

    /// Detects a sign-in that never reached Apple: sending GrandSlam's URL-bag
    /// request to gsa.apple.com failed. It's the first request of a sign-in and
    /// uses no anisette data, so every anisette server would fail it the same way.
    static func isAppleUnreachable(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("failed to fetch url bag") && m.contains("error sending request")
    }

    /// Called after `failures` sign-in attempts in a row that couldn't reach
    /// Apple. Logs how iOS sees this app's internet access, and returns the
    /// message to stop the sign-in with, or nil to try once more.
    @MainActor
    func appleUnreachableStop(failures: Int, logPrefix: String = "") async -> String? {
        let path = await NetworkStatus.internetPath()
        log("\(logPrefix)Couldn't reach Apple's sign-in server (gsa.apple.com). iOS reports this app's internet path as: \(path.debugDescription)")
        let message = Self.appleUnreachableMessage(
            satisfied: path.status == .satisfied, reason: path.unsatisfiedReason, failures: failures)
        if message != nil {
            log("\(logPrefix)Stopping: the anisette server isn't the problem, so trying more of them won't help.")
        }
        return message
    }

    /// iOS saying this app has no usable internet is conclusive, so that stops
    /// at the first failure. With internet up, the first failure may be a
    /// blip; a second means something is blocking Apple.
    static func appleUnreachableMessage(satisfied: Bool, reason: NWPath.UnsatisfiedReason,
                                        failures: Int) -> String? {
        guard !satisfied else {
            guard failures >= 2 else { return nil }
            return L("SideInstaller can't reach Apple's sign-in server (gsa.apple.com), though this iPhone has an internet connection. Something is blocking it: a firewall, a DNS filter or ad blocker, Screen Time content restrictions, or another VPN app. Turn it off or try another network, then try again.")
        }
        switch reason {
        case .cellularDenied:
            return L("SideInstaller can't reach Apple: Cellular Data is turned off for it. Turn SideInstaller on in Settings › Cellular, or join a Wi-Fi network with internet access, then try again.")
        case .wifiDenied:
            return L("SideInstaller can't reach Apple: iOS isn't letting it use Wi-Fi. In Settings › Apps › SideInstaller › Wireless Data, choose WLAN & Cellular Data, then try again.")
        case .vpnInactive:
            return L("SideInstaller can't reach Apple: a VPN set to carry all traffic is disconnected, so iOS is holding traffic back. Reconnect it, or turn off its kill switch or Connect On Demand, then try again.")
        default:
            return L("SideInstaller can't reach Apple: this iPhone has no internet connection. Connect to Wi-Fi or turn on cellular data, then try again.")
        }
    }

    // MARK: Step 5 — download the IPA

    @MainActor
    private func download() async throws {
        let src = installSource
        let channel = selectedChannel
        // A custom IPA has no versions to pick from.
        let version = src == .custom ? nil : selectedVersion
        // Keyed on source, channel and version, so changing any re-fetches.
        if let p = downloadedIPAPath, downloadedSource == src, downloadedChannel == channel,
           downloadedVersion == version?.tag, FileManager.default.fileExists(atPath: p),
           DownloadLedger.isManaged(URL(fileURLWithPath: p)) {
            log("\(buildName(src, channel, version)) IPA already downloaded — skipping.")
            setStep(.download, .done)
            return
        }
        setStep(.download, .active)

        // A picked version must be that exact release, so only the latest build
        // takes a file already in Documents.
        let onDisk = version == nil ? IPALibrary.entry(source: src, channel: channel) : nil

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
            let path = try await fetchBuild(source: src, channel: channel, version: version)
            adopt(URL(fileURLWithPath: path), source: src, channel: channel, version: version?.tag)
            log("\(src.displayName) IPA ready at \(path)")
            setStep(.download, .done)
        } catch {
            // Stopping the install isn't a failed download: no cached copy stands in.
            if Task.isCancelled { throw CancellationError() }
            // Offline or blocked: fall back to a copy an earlier run left behind,
            // which for a picked version must be that version.
            let cached: URL?
            if let version {
                cached = IPALibrary.pickedDownload(version.tag, source: src, channel: channel)
            } else {
                cached = (onDisk?.url).flatMap { IPALibrary.looksLikeIPA($0) ? $0 : nil }
            }
            if let cached {
                // C7: the install goes on with the older local copy — say so
                // under the progress card instead of silently succeeding.
                let when = (try? FileManager.default.attributesOfItem(atPath: cached.path))?[.modificationDate] as? Date
                let dateText = when?.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Localizer.locale)) ?? ""
                downloadFallbackNotice = L("Couldn't download %@: %@", src.displayName, short(error))
                    + " — " + cached.lastPathComponent
                    + (dateText.isEmpty ? "" : " (" + L("Downloaded %@", dateText) + ")")
                log("⚠️ Download failed (\(short(error))) — using \(cached.lastPathComponent) already in Documents instead.")
                adopt(cached, source: src, channel: channel, version: version?.tag)
                setStep(.download, .done)
                return
            }
            if let failure = error as? SideStoreDownloader.DownloadError {
                if failure.isRepoUnavailable {
                    // With the repository gone, the user's own copy is the only way in.
                    setGuide(Guides.repoUnavailable(source: src, saveAs: src.fileName(channel)))
                } else if failure.manualSideloadHelps,
                          let link = Self.manualDownloadLink(source: src, channel: channel, version: version) {
                    // Where GitHub can't be reached, a copy fetched another way
                    // goes in as a custom IPA.
                    setGuide(Guides.githubUnreachable(source: src, link: link))
                }
            }
            // Renaming a file to the build's name helps only the latest build.
            if version == nil { logImportHint(for: error, source: src, channel: channel) }
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
        let channel = selectedChannel
        guard src != .custom else { return }
        let version = selectedVersion
        if let p = downloadedIPAPath, downloadedSource == src, downloadedChannel == channel,
           downloadedVersion == version?.tag, FileManager.default.fileExists(atPath: p) {
            return
        }
        if version == nil, let onDisk = IPALibrary.entry(source: src, channel: channel),
           onDisk.isImported { return }

        log("Fetching \(buildName(src, channel, version)) release in the background…")
        let task = Task { try await self.downloadBuild(source: src, channel: channel, version: version) }
        prefetch = (src, channel, version?.tag, task)
    }

    /// The selected build's download: the one this run started early when there
    /// is one, otherwise a new one. Cancelling the caller cancels either.
    @MainActor
    private func fetchBuild(source: InstallSource, channel: ReleaseChannel,
                            version: ReleaseVersion?) async throws -> String {
        guard let started = prefetch, started.source == source, started.channel == channel,
              started.version == version?.tag else {
            log("Fetching \(buildName(source, channel, version)) release…")
            return try await downloadBuild(source: source, channel: channel, version: version)
        }
        prefetch = nil
        let task = started.task
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Downloads the picked version, or else the channel's latest release.
    @MainActor
    private func downloadBuild(source: InstallSource, channel: ReleaseChannel,
                               version: ReleaseVersion?) async throws -> String {
        let log: (String) -> Void = { line in self.log(line) }
        // C6: stream the transfer into downloadProgress, exactly as
        // SideBySideView does for its own downloads.
        let report: @Sendable (Double) -> Void = { [weak self] fraction in
            Task { @MainActor in self?.downloadProgress = fraction }
        }
        // B1 (0.9.155): the byte count for a transfer whose total the
        // server never stated — the downloader only calls this then, so a
        // non-nil value is itself the "total unknown" signal.
        downloadBytesWritten = nil
        let bytesReport: @Sendable (Int) -> Void = { [weak self] bytes in
            Task { @MainActor in self?.downloadBytesWritten = Int64(bytes) }
        }
        // F-2 (0.9.157): the (bytes, total) sample for the speed and the
        // time left — the fraction has no bytes, the byte count has no
        // total, so neither report above can sample it.
        clearDownloadSpeed()
        let detailReport: @Sendable (Int, Int) -> Void = { [weak self] bytes, total in
            Task { @MainActor in self?.noteDownloadDetail(bytes: bytes, total: total) }
        }
        // B1 (0.9.156): one exit, so the byte count is cleared on every
        // way out — the three `return try await …` sites this replaces used
        // to leave it set, and the progress card reads non-nil as "total
        // unknown", so signing/install kept showing the old byte count
        // plus a spinner and the % never came back until the next run.
        do {
            let path: String
            if let version {
                path = try await SideStoreDownloader.$reportProgress.withValue(report) {
                    try await SideStoreDownloader.$reportProgressBytes.withValue(bytesReport) {
                        try await SideStoreDownloader.$reportProgressDetail.withValue(detailReport) {
                            try await SideStoreDownloader.download(version, source: source, channel: channel, log: log)
                        }
                    }
                }
            } else if let catalog = releaseCatalogs[source],
                      Date().timeIntervalSince(catalog.fetched) < 15 * 60,
                      let latest = catalog.latest[channel],
                      source.feed != nil || source.actionsBuild(channel) != nil {
                // A5：开过版本选择器、内存目录新鲜时，直接取目录里“最新”那一项，
                // 不再为同一份目录多拉一次 feed JSON / artifacts 列表。只复用与
                // downloadLatest 同口径的两种情形（feed 源、Madeira nightly）；
                // GitHub 直链源（latestAsset 路）仍走 downloadLatest，不复用。
                path = try await SideStoreDownloader.$reportProgress.withValue(report) {
                    try await SideStoreDownloader.$reportProgressBytes.withValue(bytesReport) {
                        try await SideStoreDownloader.$reportProgressDetail.withValue(detailReport) {
                            try await SideStoreDownloader.download(latest, source: source, channel: channel, log: log)
                        }
                    }
                }
            } else {
                path = try await SideStoreDownloader.$reportProgress.withValue(report) {
                    try await SideStoreDownloader.$reportProgressBytes.withValue(bytesReport) {
                        try await SideStoreDownloader.$reportProgressDetail.withValue(detailReport) {
                            try await SideStoreDownloader.downloadLatest(source: source, channel: channel, log: log)
                        }
                    }
                }
            }
            downloadBytesWritten = nil
            clearDownloadSpeed()
            return path
        } catch {
            // A failed or cancelled download leaves no byte count behind either.
            downloadBytesWritten = nil
            clearDownloadSpeed()
            throw error
        }
    }

    /// F-2 (0.9.157): folds one (bytes, total) sample into the speed and
    /// the time left. Called on the main actor from the publish hop, so
    /// the sample state is never touched from the download's own queue.
    /// Same EMA as `IPADownloader.noteProgress`, via the shared sampler.
    private func noteDownloadDetail(bytes: Int, total: Int) {
        downloadSpeedSampler.note(bytes: Int64(bytes), total: Int64(total))
        downloadSpeed = downloadSpeedSampler.speed
        estimatedTimeRemaining = downloadSpeedSampler.estimatedTimeRemaining
        downloadTotalBytes = Int64(total)
    }

    /// F-2 (0.9.157): forget the last download's speed, estimate and
    /// total, for the next one.
    private func clearDownloadSpeed() {
        downloadSpeedSampler.reset()
        downloadSpeed = 0
        estimatedTimeRemaining = nil
        downloadTotalBytes = -1
    }

    /// A build as the log names it: "Nightly SideStore", or "SideStore 0.6.3".
    private func buildName(_ source: InstallSource, _ channel: ReleaseChannel,
                           _ version: ReleaseVersion?) -> String {
        guard let version else { return "\(channel.displayName) \(source.displayName)" }
        return "\(source.displayName) \(version.title)"
    }

    /// B-8（SIDE-36）：这个路径（或它的祖先目录）是不是正在安装的源文件——
    /// 文件页删 / 改名 / 移走它会打断签名步。判据：
    /// downloadedIPAPath 是管线记下的源路径；下载步还没跑到的窗口
    /// （配对 / 登录阶段）用自定义源兜底：仅 installSource == .custom
    /// 时比对当前导入文件。没在跑就不拦；祖先目录用 path + "/" 前缀，
    /// 不用裸 hasPrefix（Foo.ipa 与 Foo.ipa2 会撞车）。
    func isInstallingSource(path: String) -> Bool {
        guard isRunning else { return false }
        // B2：配对窗口期的源（downloadedIPAPath 还没置位那段）。
        if let installing = installingSourcePath,
           installing == path || installing.hasPrefix(path + "/") {
            return true
        }
        if let installing = downloadedIPAPath,
           installing == path || installing.hasPrefix(path + "/") {
            return true
        }
        guard installSource == .custom,
              let custom = IPALibrary.customImport()?.url.path,
              custom == path || custom.hasPrefix(path + "/") else { return false }
        return true
    }

    /// B1：正在签名的源文件路径集——ECV 单签（executeSign）与文件页批量签名
    /// （runBatchSign）在跑时登记，跑完注销。B5：正在续签的源文件路径集——
    /// 续签循环 .working 的那项登记，.done/.failed 注销。文件页/LAN/WebDAV
    /// 的删/移/改名入口只拦集里的路径，不拦无关文件；祖先目录语义同
    /// isInstallingSource（path + "/" 前缀），不用裸 hasPrefix。
    var signingSourcePaths: Set<String> = []
    var renewingSourcePaths: Set<String> = []

    func isSigningSource(path: String) -> Bool {
        signingSourcePaths.contains { $0 == path || $0.hasPrefix(path + "/") }
    }

    func isRenewingSource(path: String) -> Bool {
        renewingSourcePaths.contains { $0 == path || $0.hasPrefix(path + "/") }
    }

    /// Point the rest of the pipeline at an IPA on disk, whatever its origin.
    @MainActor
    private func adopt(_ url: URL, source: InstallSource, channel: ReleaseChannel,
                       version: String? = nil) {
        downloadedIPAPath = url.path
        downloadedSource = source
        downloadedChannel = channel
        downloadedVersion = version
        recognizedSource = source == .custom ? IPALibrary.knownSource(ofIPAAt: url) : nil
    }

    // MARK: Versions to pick from (Advanced)

    /// Disk cache for release catalogs, in SignedIPAStore's tolerant
    /// JSON-file shape: a missing or unreadable file just means "fetch
    /// fresh". Lets a catalog survive an app restart, so reopening the
    /// version picker within 15 minutes doesn't cost another GitHub call.
    private static var catalogCacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("releaseCatalogs.json")
    }

    /// A3+A4：与 SourcesStore 的源缓存同一条道理——磁盘缓存的编解码移出主
    /// 线程，读写走同一条串行队列（队列内 helper 后缀 Locked）。Engine 本
    /// 身不是 @MainActor，这两个 static func 天生非隔离，async 就能跳出
    /// 主线程（不必再标 nonisolated）。
    private static let catalogCacheQueue = DispatchQueue(label: "sideinstaller.catalog-cache")

    private static func loadCatalogCacheLocked() -> [InstallSource: ReleaseCatalog] {
        guard let data = try? Data(contentsOf: catalogCacheURL),
              let cached = try? JSONDecoder().decode([InstallSource: ReleaseCatalog].self, from: data)
        else { return [:] }
        return cached
    }

    private static func writeCatalogCacheLocked(_ catalogs: [InstallSource: ReleaseCatalog]) {
        if let data = try? JSONEncoder().encode(catalogs) {
            try? data.write(to: catalogCacheURL, options: .atomic)
        }
    }

    private static func loadCatalogCache() async -> [InstallSource: ReleaseCatalog] {
        catalogCacheQueue.sync { loadCatalogCacheLocked() }
    }

    private static func saveCatalogCache(_ catalogs: [InstallSource: ReleaseCatalog]) async {
        catalogCacheQueue.sync { writeCatalogCacheLocked(catalogs) }
    }

    // 上游 Madeira 稳定版检查（与 fork 目录缓存双留）。
    /// Asks GitHub whether `source`'s stable channel has its first release yet,
    /// for a build whose stable channel waits for one (Madeira). One request
    /// to the website, which has no hourly limit; no answer keeps what was
    /// known. Not applied during a run, which has already picked its channel.
    @MainActor
    func checkStableRelease(for source: InstallSource) async {
        guard source.firstStableVersion != nil else { return }
        // 15-minute TTL, same as loadReleaseCatalog: switching to Madeira
        // and back must not HEAD GitHub every time.
        if let last = lastStableCheck[source], Date().timeIntervalSince(last) < 15 * 60 { return }
        guard let released = await SideStoreDownloader.hasStableRelease(source) else { return }
        // A failed check leaves the timestamp alone, so the next pick retries.
        lastStableCheck[source] = Date()
        guard released != stableReleased.contains(source), !isRunning else { return }
        if released { stableReleased.insert(source) } else { stableReleased.remove(source) }
        UserDefaults.standard.set(stableReleased.map(\.rawValue).sorted(), forKey: Self.stableReleasedKey)
        log(released
            ? "\(source.displayName) has a stable release now — offering Stable and Nightly."
            : "\(source.displayName) has no stable release yet — offering its nightly builds only.")
    }

    /// Lists `source`'s releases for the version picker, unless a list from the
    /// last 15 minutes is at hand. One GitHub API call, which counts against the
    /// same hourly limit as the download's fallbacks.
    @MainActor
    func loadReleaseCatalog(for source: InstallSource, force: Bool = false) async {
        guard source != .custom, loadingCatalog != source else { return }
        if !force, let cached = releaseCatalogs[source],
           Date().timeIntervalSince(cached.fetched) < 15 * 60 { return }
        // Disk cache, same 15-minute rule: a catalog saved by an earlier
        // launch still counts, so reopening the picker doesn't refetch.
        if !force, let disk = await Self.loadCatalogCache()[source],
           Date().timeIntervalSince(disk.fetched) < 15 * 60 {
            releaseCatalogs[source] = disk
            log("Versions: using saved \(source.displayName) catalog.")
            return
        }
        loadingCatalog = source
        catalogErrors[source] = nil
        // Checked, since a newer load for another build may have started since.
        defer { if loadingCatalog == source { loadingCatalog = nil } }
        do {
            let catalog = try await SideStoreDownloader.releaseCatalog(source: source)
            releaseCatalogs[source] = catalog
            // Persist for the next launch (same 15-minute rule applies on read).
            await Self.saveCatalogCache(releaseCatalogs)
            log("Versions: \(source.displayName) has \(catalog.others[.stable]?.count ?? 0) stable and \(catalog.others[.nightly]?.count ?? 0) pre-release builds besides the latest.")
        } catch is CancellationError {
            // The picker closed mid-fetch; opening it again retries.
        } catch {
            catalogErrors[source] = short(error)
            log("⚠️ Couldn't list \(source.displayName) releases: \(short(error))")
        }
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
        if let known = recognizedSource {
            log("\(entry.url.lastPathComponent) is \(known.displayName): it's set up the same way as SideInstaller's own download.")
        }
        setStep(.download, .done)
    }

    /// Copy a picked IPA in as the custom import, replacing any previous one.
    /// Returns true only when this call really imported (C12): a call that
    /// finds an import already running returns false, so a chained caller
    /// can't mistake the previous import for this one.
    @MainActor
    func importCustomIPA(from url: URL) async -> Bool {
        // B3：安装进行中不换 custom 槽——replaceCustomImport 会清空 custom
        // 目录、置空 downloadedIPAPath，在途安装的源就没了。入口拒掉，
        // 调用方凭返回值不启动管线（C12）；inbox 拷贝照 N3(C) 同款删掉。
        guard !isRunning else {
            lastError = L("An install is already running. Wait for it to finish, then try again.")
            log("⛔️ Import: \(lastError ?? "")")
            Self.discardInboxCopy(url)
            return false
        }
        // B-38-B2：续签进行中不换 custom 槽——replaceCustomImport 会清空
        // Custom/ 、断掉在途续签的源。拒绝路照 B3 同款（丢 inbox 拷贝）。
        guard !SideloadedAppsManager.shared.isRefreshing else {
            lastError = L("A refresh is already running. Wait for it to finish, then try again.")
            log("⛔️ Import: \(lastError ?? "")")
            Self.discardInboxCopy(url)
            return false
        }
        guard !isImportingIPA else {
            lastError = L("An import is already running. Wait for it to finish, then try again.")
            log("⛔️ Import: \(lastError ?? "")")
            // N3(C)：defer 还没装上，竞态撞进来的这份 picker 拷贝不会被删，
            // 在这里显式删掉，不然整只 IPA 留在 tmp 里。
            Self.discardInboxCopy(url)
            return false
        }
        // B-50-B3: the import would delete the current custom import —
        // refuse while it's being signed (batch signing re-extracts it
        // per file, so the whole rest of the batch would fail).
        if let old = IPALibrary.customImport(), isSigningSource(path: old.url.path) {
            lastError = L("A signing is already running. Wait for it to finish, then try again.")
            log("⛔️ Import: \(lastError ?? "")")
            Self.discardInboxCopy(url)
            return false
        }
        isImportingIPA = true
        // Delete the picker's temporary copy once the import is done.
        defer { isImportingIPA = false; Self.discardInboxCopy(url) }
        lastError = nil
        log("Importing \(url.lastPathComponent) …")
        do {
            let dest = try await Self.copyImport(from: url)
            showCustomImport(dest)
            // Clear the cached path so the next run uses the new file.
            if downloadedSource == .custom { downloadedIPAPath = nil }
            setGuide(nil)
            log("Imported \(dest.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize(dest.path)), countStyle: .file))).")
            return true
        } catch IPALibrary.ImportError.notAnIPA {
            // The picker accepts any file. Validation runs on a staged copy, so
            // the previous import is kept.
            refreshCustomIPA()
            lastError = L("%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.",
                          url.lastPathComponent)
            log("⛔️ Import: \(lastError ?? "")")
            return false
        } catch {
            // Re-read the import from disk to update the button label.
            refreshCustomIPA()
            lastError = L("Couldn't import %@: %@", url.lastPathComponent, error.localizedDescription)
            log("⛔️ Import: \(lastError ?? "")")
            return false
        }
    }

    /// F-3 (0.9.160): the newest IPA in Downloads matching a history
    /// entry, or nil when there is none to reinstall from. The
    /// candidate search `reinstallFromHistory` used to inline; the
    /// reinstall-all loop needs the same answer up front to tell "skip,
    /// no IPA" apart from "tried and failed", so both call this one
    /// matcher — a file the single path finds is one the loop counts
    /// as present, and vice versa.
    /// F-1 (0.9.168): when the entry records a bundle ID, matching is
    /// by bundle ID first — two same-name clones (multi-open) share a
    /// name but never an ID. The recorded ID is the signed one:
    /// personal-ID signing appends `.<teamID>` to the installed ID
    /// (AppInfo 同款注释）, so a candidate IPA matches when its ID is
    /// the recorded one or the recorded one is its ID plus that suffix;
    /// enterprise signing rewrites nothing, so the exact match covers
    /// it. A recorded ID with no bundle-ID match returns nil — falling
    /// back to name matching here could reinstall the wrong clone,
    /// which is the bug this fixes. Entries with no bundle ID (written
    /// before 0.9.168, or failed runs that never reached signing) keep
    /// the old name matching, behaviour unchanged.
    @MainActor
    func historyIPAURL(for entry: InstallHistoryEntry) -> URL? {
        let needle = entry.appName.lowercased()
        guard !needle.isEmpty else { return nil }
        // Candidates: the library scan (known builds + the custom import)
        // plus any unrecognized IPA in Documents, whose filename is the
        // only name a hand-saved custom IPA has. Each candidate carries
        // the bundle ID its IPA declares (nil when it won't parse).
        var candidates: [(url: URL, modified: Date, rank: Int, bundleID: String?)] = []
        for item in IPALibrary.scan() {
            if let rank = Self.historyMatchRank(fileStem: item.url.deletingPathExtension().lastPathComponent.lowercased(),
                                                sourceName: item.source.displayName.lowercased(), needle: needle) {
                candidates.append((item.url, item.modified ?? .distantPast, rank,
                                   IPALibrary.appInfo(at: item.url)?.bundleID))
            }
        }
        for name in IPALibrary.unrecognized() {
            let url = IPALibrary.documentsDir.appendingPathComponent(name)
            let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
            if let rank = Self.historyMatchRank(fileStem: url.deletingPathExtension().lastPathComponent.lowercased(),
                                                sourceName: "", needle: needle) {
                candidates.append((url, modified, rank, IPALibrary.appInfo(at: url)?.bundleID))
            }
        }
        if let wanted = entry.bundleID, !wanted.isEmpty {
            let byID = candidates.filter { candidate in
                guard let id = candidate.bundleID else { return false }
                return id == wanted || wanted.hasPrefix(id + ".") || id.hasPrefix(wanted + ".")
            }
            return byID.sorted(by: { a, b in
                if a.rank != b.rank { return a.rank < b.rank }
                return a.modified > b.modified
            }).first?.url
        }
        return candidates.sorted(by: { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            return a.modified > b.modified
        }).first?.url
    }

    /// F1 (0.9.148): reinstall a history entry — find the newest IPA in the
    /// Downloads library whose filename names the same app, import it as the
    /// custom IPA and run the one-click pipeline. Returns false with
    /// `lastError` set when no IPA matches (the user has to download it
    /// again first) or the import refuses; a started run returns true.
    /// The history entry keeps no IPA path, so matching is by name only:
    /// the filename stem (or the build's display name) against the recorded
    /// app name, best rank first, newest within a rank. `installSource` is
    /// set to `.custom` only after the import succeeds (B-39-B2 同款）。
    @MainActor
    func reinstallFromHistory(_ entry: InstallHistoryEntry) async -> Bool {
        guard let matchURL = historyIPAURL(for: entry) else {
            lastError = L("Couldn't find %@ in Downloads. Download it again first.", entry.appName)
            log("⛔️ History reinstall: no IPA for \(entry.appName) in Downloads.")
            return false
        }
        guard await importCustomIPA(from: matchURL) else { return false }
        // B-1 (0.9.162): installOneCustomIPA 同款起跑前 guard — import
        // 期间另一路安装可能已起跑：这时 runOneClick 会因 isRunning 静默
        // 返回，而下面的等待循环会把别人的跑当成自己的等完、再拿它的
        // 成败当本次结果。守卫必须在 installSource = .custom 之前——
        // 别先改源再拦，管线中途读 installSource，改了就可能串源。
        // 两道检查到 runOneClick 之间没有 suspension 点，主 actor 上
        // 是原子的，拦完不可能再有人插进来。
        if Task.isCancelled {
            lastError = L("Install stopped")
            return false
        }
        guard !isRunning else {
            lastError = L("An install is already running. Wait for it to finish, then try again.")
            return false
        }
        // B-39-B2 同款：源赋值移到导入成功之后——导入被拒时在途管线
        // 读到的仍是旧源，不会被改装 custom 槽里的旧 IPA。
        installSource = .custom
        runOneClick()
        // B2 (0.9.156): installOneCustomIPA 同款——等管线起跑（全隧道探针
        // 最多拖半秒），3 秒还不起跑就是起跑守卫拦住了（无账号/无配对
        // 文件/系统版本过低），不是起跑慢。旧代码直接 return true，历史页
        // 毫无反馈：行内 spinner 停了，指引卡在用户没看的安装页。
        // B-2 (0.9.161): whether this call's run ever started — the wait
        // below also records a run that started and stopped inside one
        // 100 ms tick, so the downgrade check after it can tell this
        // run's decline from a stale one.
        var waited = 0.0
        var started = false
        while !isRunning, !Task.isCancelled, waited < 3.0 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 0.1
            started = started || isRunning
        }
        if isRunning { started = true }
        if Task.isCancelled {
            lastError = L("Install stopped")
            return false
        }
        // F-2 (0.9.159): the user declined this entry's downgrade — the run
        // never started, so say why instead of the generic "didn't start".
        // B-2 (0.9.161): only when this call's run actually started — the
        // flag is cleared in resetRun, which a run stopped by an early
        // guard never reaches, so a decline left over from an earlier run
        // would otherwise mask the guard's real reason (no account / no
        // pairing file) in the branch below.
        if started, downgradeDeclined {
            lastError = downgradeDeclinedMessage ?? L("Install stopped")
            return false
        }
        guard isRunning else {
            // B-1 (0.9.163): runOneClick 入口已清掉上一跑的 lastError/
            // guide，所以这里剩下的向导或错误就是这次起跑守卫拦住的
            // 原因——向导优先于 lastError，不再拿 guideBefore 比对
            // （旧向导与新向导相同时比对会漏掉真原因）。
            if let guide {
                lastError = ([guide.title] + guide.steps).joined(separator: "\n")
            } else if lastError == nil {
                lastError = L("The install didn't start. Open SideInstaller to see why.")
            }
            return false
        }
        return true
    }

    /// How well a library IPA's name matches a history entry's app name:
    /// exact filename stem, then a stem that starts with it or a build name
    /// that equals it, then a name that merely contains it. Nil means no
    /// match at all.
    private static func historyMatchRank(fileStem: String, sourceName: String, needle: String) -> Int? {
        if fileStem == needle { return 0 }
        if fileStem.hasPrefix(needle) { return 1 }
        if sourceName == needle { return 1 }
        if fileStem.contains(needle) { return 2 }
        if !sourceName.isEmpty, sourceName.contains(needle) { return 2 }
        return nil
    }

    /// One item of a batch install (`installOneCustomIPA`): `error` is nil
    /// when the IPA installed, otherwise the user-facing reason it didn't.
    /// `stopped` is true when the batch must not continue: the run never
    /// started (a systemic cause — account, pairing, tunnel — that would
    /// hit every remaining item the same way) or the run was stopped with
    /// no error (a cancel). A failed import or a failed run leaves
    /// `stopped` false: the batch skips that item and moves on.
    /// `declined` (B-3, 0.9.166) is true when the user declined this item's
    /// downgrade prompt — a skip, not a failure; the summary counts it
    /// apart from failures. It defaults to false in the initializer below
    /// (a property default alone doesn't give the memberwise initializer a
    /// default argument — the 0.9.166 first push went red on exactly that),
    /// so the other call sites keep their meaning.
    struct BatchInstallOutcome {
        let name: String
        let error: String?
        let stopped: Bool
        let declined: Bool

        init(name: String, error: String?, stopped: Bool, declined: Bool = false) {
            self.name = name
            self.error = error
            self.stopped = stopped
            self.declined = declined
        }
    }

    /// F2 (0.9.151): install one IPA through the single-install path
    /// (`importCustomIPA` + `installSource = .custom` + `runOneClick`,
    /// B-39-B2 同款：源只在导入成功后切）. The waits copy
    /// `Shortcuts.install` / AboutView's self-update: up to 3 s for the
    /// run to start, then until `isRunning` falls; `finished` decides
    /// success, `lastError` (or the changed guide) the reason. The
    /// batch's own Task is the cancel handle: cancelling it stops the
    /// wait after the current item (the run itself keeps going —
    /// Shortcuts.install 同款，停掉等待不等停掉安装）; cancelling the
    /// run as well (the view's Cancel button does both) stops it now.
    /// Renewal untouched: this only installs, never refreshes.
    @MainActor
    func installOneCustomIPA(_ url: URL) async -> BatchInstallOutcome {
        let name = url.deletingPathExtension().lastPathComponent
        if Task.isCancelled {
            return BatchInstallOutcome(name: name, error: L("Install stopped"), stopped: true)
        }
        guard await importCustomIPA(from: url) else {
            return BatchInstallOutcome(name: name, error: lastError ?? L("Install stopped"), stopped: false)
        }
        // 取消可能正落在 import 的等待里：import 本身不停，跑完才
        // 在这里刹住，不然取消后还会新起一跑。另一路安装也可能在
        // import 期间起跑：这时 runOneClick 会因 isRunning 直接返回，
        // 而下面的等待循环会把别人的跑当成自己的等完、再拿它的成败
        // 当这一项的成败——起跑前先拦一道。两道检查到 runOneClick
        // 之间没有 suspension 点，主 actor 上是原子的，拦完不可能
        // 再有人插进来。
        if Task.isCancelled {
            return BatchInstallOutcome(name: name, error: L("Install stopped"), stopped: true)
        }
        guard !isRunning else {
            return BatchInstallOutcome(name: name, error: L("An install is already running. Wait for it to finish, then try again."), stopped: true)
        }
        // F-1 (0.9.158): the IPA's own minimum — checked here, not left to
        // runOneClick's guard, so one too-new item skips (stopped: false)
        // instead of aborting the whole batch as a systemic failure.
        if let info = IPALibrary.appInfo(at: url),
           let reason = Self.minOSBlockReason(info: info,
                                              runningOn: ProcessInfo.processInfo.operatingSystemVersion,
                                              osText: osVersionText) {
            return BatchInstallOutcome(name: name, error: reason, stopped: false)
        }
        installSource = .custom
        runOneClick()
        // Shortcuts.install 同款：等管线起跑（全隧道探针最多拖半秒），
        // 3 秒还不起跑就是起跑守卫拦住了，不是起跑慢。
        var waited = 0.0
        while !isRunning, !Task.isCancelled, waited < 3.0 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 0.1
        }
        if Task.isCancelled {
            return BatchInstallOutcome(name: name, error: L("Install stopped"), stopped: true)
        }
        guard isRunning else {
            // 没起跑：守卫原因（账号/配对/隧道/向导）对剩下每项都一样，
            // 逐个重跑只会重复同一失败，整批到此为止。向导优先于
            // lastError——B-1 (0.9.163)：runOneClick 入口已清掉上一跑
            // 的 lastError/guide，所以这里剩下的就是这次的原因，不再
            // 拿 guideBefore 比对（旧向导与新向导相同时比对会漏掉
            // 真原因）。
            let reason: String
            if let guide {
                reason = ([guide.title] + guide.steps).joined(separator: "\n")
            } else if let lastError {
                reason = lastError
            } else {
                reason = L("The install didn't start. Open SideInstaller to see why.")
            }
            return BatchInstallOutcome(name: name, error: reason, stopped: true)
        }
        while isRunning, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
        }
        if Task.isCancelled {
            return BatchInstallOutcome(name: name, error: L("Install stopped"), stopped: true)
        }
        // F-2 (0.9.159): the user declined this item's downgrade — one item
        // skips, the batch goes on. The run itself ended as a cancel, so
        // without this the item would read as a systemic stop.
        if downgradeDeclined {
            return BatchInstallOutcome(name: name,
                                       error: downgradeDeclinedMessage ?? L("Install stopped"),
                                       stopped: false, declined: true)
        }
        if finished {
            return BatchInstallOutcome(name: name, error: nil, stopped: false)
        }
        if let error = lastError {
            return BatchInstallOutcome(name: name, error: error, stopped: false)
        }
        // 跑完了、没成功、没留错：只有取消走这条路（取消分支只记
        // 日志不置 lastError）——用户停了这跑，剩下的别再起。
        return BatchInstallOutcome(name: name, error: L("Install stopped"), stopped: true)
    }

    /// Starts a link import as a task the link row can cancel, instead of
    /// the fire-and-forget `Task` the view used to own (B1, 0.9.147).
    /// Returns immediately; the import itself runs in `importCustomIPA`.
    @MainActor
    func startLinkImport(_ text: String) {
        guard linkImportTask == nil else { return }
        linkImportTask = Task { @MainActor in
            defer { linkImportTask = nil }
            return await importCustomIPA(fromLink: text)
        }
    }

    /// Cancels a link import in progress. The download stops in
    /// `fetchDirect`; the import's `defer` clears `isImportingIPA`.
    @MainActor
    func cancelLinkImport() {
        linkImportTask?.cancel()
    }

    /// Downloads an IPA from a pasted link and stores it as the custom import.
    /// Returns true only when this call really imported (C12); see the `from:`
    /// overload.
    @MainActor
    func importCustomIPA(fromLink text: String) async -> Bool {
        // B3：同 from: ——安装进行中不换 custom 槽（链接下载那路同理）。
        guard !isRunning else {
            lastError = L("An install is already running. Wait for it to finish, then try again.")
            log("⛔️ Import: \(lastError ?? "")")
            return false
        }
        // B-38-B2：同 from: ——续签进行中不导入自定义 IPA。
        guard !SideloadedAppsManager.shared.isRefreshing else {
            lastError = L("A refresh is already running. Wait for it to finish, then try again.")
            log("⛔️ Import: \(lastError ?? "")")
            return false
        }
        guard !isImportingIPA else {
            lastError = L("An import is already running. Wait for it to finish, then try again.")
            log("⛔️ Import: \(lastError ?? "")")
            return false
        }
        // B-50-B3: same as from: — check before downloading, so a refused
        // import doesn't waste a download.
        if let old = IPALibrary.customImport(), isSigningSource(path: old.url.path) {
            lastError = L("A signing is already running. Wait for it to finish, then try again.")
            log("⛔️ Import: \(lastError ?? "")")
            return false
        }
        guard let url = Self.downloadLink(text) else {
            lastError = L("That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.")
            log("⛔️ Import: \(lastError ?? "")")
            return false
        }
        isImportingIPA = true
        importProgress = 0
        importBytes = nil
        defer { isImportingIPA = false; importProgress = nil; importBytes = nil }
        lastError = nil
        log("Downloading \(url.absoluteString) …")
        do {
            let downloaded = try await SideStoreDownloader.fetchDirect(
                url, named: Self.importFileName(for: url),
                // B1 (0.9.155): total unknown — the byte count arrives here
                // instead of a fraction, and the fraction is cleared so the
                // link row goes indeterminate instead of sitting at 0%.
                onBytes: { bytes in
                    Task { @MainActor in
                        self.importBytes = bytes
                        self.importProgress = nil
                    }
                }) { fraction in
                    Task { @MainActor in self.importProgress = fraction }
                }
            // The download lives in its own staging directory; remove all of it.
            defer { try? FileManager.default.removeItem(at: downloaded.deletingLastPathComponent()) }
            let dest = try await Self.copyImport(from: downloaded)
            showCustomImport(dest)
            // Clear the cached path so the next run uses the new file.
            if downloadedSource == .custom { downloadedIPAPath = nil }
            setGuide(nil)
            log("Imported \(dest.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize(dest.path)), countStyle: .file))).")
            return true
        } catch IPALibrary.ImportError.notAnIPA {
            refreshCustomIPA()
            lastError = L("That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.")
            log("⛔️ Import: \(lastError ?? "")")
            return false
        } catch is CancellationError {
            refreshCustomIPA()
            log("Import cancelled.")
            return false
        } catch {
            refreshCustomIPA()
            lastError = L("Couldn't download that link: %@", short(error))
            log("⛔️ Import: \(lastError ?? "")")
            return false
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
        // N3(C)：源页下载的 IPA 住在 ipa-source-<UUID>/ 里，只删文件会留
        // 一个空目录；顺手删掉空的父目录（前缀限定，配对导入等别的
        // picker 拷贝不受影响；非空目录 removeItem 会抛错，try? 天然只删空的）。
        let parent = url.deletingLastPathComponent()
        if parent.lastPathComponent.hasPrefix("ipa-source-") {
            try? FileManager.default.removeItem(at: parent)
        }
    }

    /// Copies a picked IPA into the custom import slot on a background queue.
    private static func copyImport(from url: URL) async throws -> URL {
        let box = CZFContinuationBox<URL>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                box.store(cont)
                // Cancelled before the block was queued: don't start work
                // the caller has already abandoned.
                guard !Task.isCancelled else { return }
                DispatchQueue.global(qos: .userInitiated).async {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let dest = try IPALibrary.replaceCustomImport(with: url)
                        // 0.9.150: keep a library copy of the import in
                        // Documents, so the next import — which evicts this
                        // Custom/ slot — doesn't take the app's renewal
                        // source with it. Runs here, on the import's own
                        // background queue while isImportingIPA still bars
                        // the next import, so the source can't vanish
                        // mid-copy; it never fails the import.
                        IPALibrary.archiveImportedIPA(dest)
                        box.resume(returning: dest)
                    } catch { box.resume(throwing: error) }
                }
            }
        } onCancel: {
            box.resume(throwing: CancellationError())
        }
    }

    /// Re-read the custom import from disk.
    @MainActor
    func refreshCustomIPA() {
        showCustomImport(IPALibrary.customImport()?.url)
    }

    /// Shows the custom import at `url`, or none, on the Install tab: its name,
    /// and the build of SideInstaller's own it is.
    /// A-11：build 参数接启动时预计算的源识别值；不传时照旧现算
    /// （导入完成 / 刷新走的老路，不动）。
    private func showCustomImport(_ url: URL?, build: InstallSource? = nil) {
        customIPAName = url?.lastPathComponent
        customIPABuild = build ?? url.flatMap(IPALibrary.knownSource(ofIPAAt:))
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
        if (error as? SideStoreDownloader.DownloadError)?.isRepoUnavailable == true {
            log("\(source.displayName)'s repository is gone from GitHub. Have its IPA from somewhere else? Save it as \(wanted) in Files › On My iPhone › SideInstaller, then tap Install again.")
            return
        }
        guard (error as? SideStoreDownloader.DownloadError)?.manualSideloadHelps ?? true else { return }
        log("Can't reach \(source.feed?.name ?? "GitHub")? Download \(source.displayName) on another device or through a proxy, then import it under Custom .ipa (it's recognized and set up the same way), or rename it to \(wanted) and copy it into Files › On My iPhone › SideInstaller. Then tap Install again.")
    }

    /// Where to get the build in a browser when SideInstaller can't download
    /// it: the file itself when it has a fixed link, otherwise the releases page.
    /// None for a build from an AltStore source: the card it's for is about
    /// reaching GitHub.
    private static func manualDownloadLink(source: InstallSource, channel: ReleaseChannel,
                                           version: ReleaseVersion?) -> URL? {
        guard source.feed == nil else { return nil }
        let releases = source.repo.flatMap { URL(string: "https://github.com/\($0)/releases") }
        // A GitHub Actions build comes zipped, so the releases page stands in.
        if let version { return version.artifactSHA256 == nil ? version.assetURL : releases }
        return source.downloadURL(channel) ?? releases
    }

    // MARK: Step 6 — sign the IPA

    /// Asks what signing this IPA costs in App IDs, before signing it.
    /// Copied from upstream (FrizzleM/SideInstaller @ 7d1cb04): the fork's
    /// popup and answer were restored in merge recovery, but this setter
    /// never was, so custom installs signed with no warning. A check that
    /// fails, or an IPA whose bundle ID can't be read, signs ahead anyway.
    @MainActor
    private func confirmAppIDCost() async throws {
        guard let session = signSession, let ipa = downloadedIPAPath else { return }
        guard let bundleID = IPALibrary.appInfo(at: URL(fileURLWithPath: ipa))?.bundleID else {
            log("⚠️ Couldn't read the IPA's bundle ID, so its App ID cost isn't known; signing goes ahead.")
            return
        }
        setStep(.sign, .active)
        let cost: AppIDCost
        do {
            cost = try await onSignQueue { try self.performAppIDQuota(session: session, bundleID: bundleID) }
        } catch {
            log("⚠️ Couldn't check this Apple ID's App IDs (\(short(error))); signing goes ahead.")
            return
        }
        try Task.checkCancellation()
        let left = cost.available.map(String.init) ?? "unknown"
        log("App IDs: this app needs \(cost.cost) new (\(cost.newIDs.joined(separator: ", "))); \(left) left. Installing directly, no confirmation popup.")
        // 2026-11-08：用户亲定去掉 App ID 确认弹窗，直接安装。
        // 之前这里置 appIDCost 弹确认框、等用户点安装才继续；
        // 现在只记账不等待，直接进签名安装。
    }

    /// Asks whether to replace the pairing file in use with one made for
    /// another iPhone. Suspends until the user answers the popup.
    @MainActor
    private func confirmPairingImportMismatch(_ mismatch: PairingImportMismatch) async -> Bool {
        pairingImportMismatch = mismatch
        return await withTaskCancellationHandler {
            await withCheckedContinuation { cont in
                pairingImportMismatchReply = cont
            }
        } onCancel: {
            // onCancel 是非隔离同步上下文：直接调 @MainActor 的 answer 只在 Swift 5 模式下
            // 报警告、且不跳回主线程（真竞态，见 AGENTS.md L413 教训）。必须经 Task 跳过去。
            Task { @MainActor in answerPairingImportMismatch(false) }
        }
    }

    /// F-G (0.9.156): asks before a big download runs on cellular data, when
    /// the "Wi-Fi only downloads" switch is on. Returns true to go ahead.
    /// No prompt on Wi-Fi, or with the switch off; a download that reuses
    /// the copy already on disk never reaches here, so no prompt for it.
    /// Suspends until the user answers the popup, like
    /// `confirmPairingImportMismatch`.
    @MainActor
    func confirmCellularDownload(size: Int64?, what: String) async -> Bool {
        guard Self.wifiOnlyDownloads else { return true }
        guard await NetworkStatus.internetPath().isExpensive else { return true }
        // B-1 (0.9.166): one prompt on screen at a time, but a second
        // download asking while one waits queues behind it instead of
        // declining silently — since 0.9.163 several rows can each start a
        // download task, so the old "the UI only ever starts one download
        // at a time anyway" premise no longer holds, and the declined row
        // just went idle with no word at all.
        if cellularDownloadReply != nil {
            log("Cellular data: \(what) is waiting behind the download confirmation already on screen.")
            let id = UUID()
            return await withTaskCancellationHandler {
                if Task.isCancelled { return false }
                return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                    cellularDownloadQueue.append(QueuedCellularDownload(id: id, size: size, what: what, reply: cont))
                }
            } onCancel: {
                // onCancel 是非隔离同步上下文，同 confirmPairingImportMismatch：
                // 必须经 Task 跳回主线程再处理。
                Task { @MainActor in cancelQueuedCellularDownload(id) }
            }
        }
        log("Cellular data: \(what) needs confirmation before downloading.")
        cellularDownloadRequest = CellularDownloadRequest(what: what, size: size)
        return await withTaskCancellationHandler {
            // Cancelled between the checks above and here: the handler
            // already ran with no continuation to resume, so don't suspend
            // — clear the request and decline instead of hanging.
            if Task.isCancelled {
                cellularDownloadRequest = nil
                return false
            }
            return await withCheckedContinuation { cont in
                cellularDownloadReply = cont
            }
        } onCancel: {
            // onCancel 是非隔离同步上下文，同 confirmPairingImportMismatch：
            // 必须经 Task 跳回主线程再 answer。
            Task { @MainActor in answerCellularDownload(false) }
        }
    }

    /// Answer the cellular-download popup: true downloads, false stops it.
    /// B-1 (0.9.166): answering presents the next queued download's prompt,
    /// if one waited behind this one.
    @MainActor
    func answerCellularDownload(_ proceed: Bool) {
        guard let reply = cellularDownloadReply else { return }
        cellularDownloadReply = nil
        presentedQueuedCellularDownloadID = nil
        reply.resume(returning: proceed)
        cellularDownloadRequest = nil
        presentNextCellularDownload()
    }

    /// B-1 (0.9.166): puts the next queued download's prompt on screen.
    /// Only runs when no prompt is up — the waiter keeps suspending on its
    /// own continuation until this prompt is answered.
    @MainActor
    private func presentNextCellularDownload() {
        guard cellularDownloadReply == nil, !cellularDownloadQueue.isEmpty else { return }
        let next = cellularDownloadQueue.removeFirst()
        presentedQueuedCellularDownloadID = next.id
        cellularDownloadRequest = CellularDownloadRequest(what: next.what, size: next.size)
        cellularDownloadReply = next.reply
    }

    /// B-1 (0.9.166): takes a queued waiter out of the queue and declines
    /// it — its download task was cancelled while it waited. When the waiter
    /// is already the prompt on screen, answering it declines it the same
    /// way; when it never queued at all (cancelled before suspending),
    /// nothing happens — its prompt was never this one.
    @MainActor
    private func cancelQueuedCellularDownload(_ id: UUID) {
        if let index = cellularDownloadQueue.firstIndex(where: { $0.id == id }) {
            let waiter = cellularDownloadQueue.remove(at: index)
            waiter.reply.resume(returning: false)
            return
        }
        if presentedQueuedCellularDownloadID == id {
            answerCellularDownload(false)
        }
    }

    /// F-2 (0.9.159): asks before a custom IPA older than the copy on this
    /// iPhone installs over it. Returns true to go ahead. No prompt when the
    /// IPA is newer, the same version, or the app isn't installed; the
    /// pipeline asks before it takes the tunnel, so a no burns nothing.
    /// Suspends until the user answers the popup, like
    /// `confirmCellularDownload`.
    @MainActor
    func confirmDowngrade(_ request: DowngradeRequest) async -> Bool {
        // One prompt at a time: a second run asking while one waits declines
        // instead of stacking a popup on top of it — the app only ever runs
        // one install at a time anyway.
        guard downgradeReply == nil else { return false }
        log("Downgrade: \\(request.appName) \\(request.ipaVersion) is older than the installed \\(request.installedVersion); asking first.")
        downgradeRequest = request
        return await withTaskCancellationHandler {
            if Task.isCancelled {
                downgradeRequest = nil
                return false
            }
            return await withCheckedContinuation { cont in
                downgradeReply = cont
            }
        } onCancel: {
            // onCancel 是非隔离同步上下文，同 confirmPairingImportMismatch：
            // 必须经 Task 跳回主线程再 answer。
            Task { @MainActor in answerDowngrade(false) }
        }
    }

    /// Answer the downgrade popup: true installs the older version, false
    /// stops this run. A no is a decline, not a failure — the pipeline
    /// throws `CancellationError` for it, so no failure history is written;
    /// the flag lets the batch and history paths tell a decline apart from
    /// a cancel and skip the item instead of stopping.
    @MainActor
    func answerDowngrade(_ proceed: Bool) {
        guard let reply = downgradeReply else { return }
        downgradeReply = nil
        reply.resume(returning: proceed)
        if !proceed, let request = downgradeRequest {
            downgradeDeclined = true
            downgradeDeclinedMessage = L("This version is older than the one on this iPhone (%@). Installed over it, it may not open data the newer version saved.", request.installedVersion)
        }
        downgradeRequest = nil
    }

    /// F-2 (0.9.159): the downgrade prompt for the custom IPA this run is
    /// about to install, or nil when there is nothing to ask about. The
    /// installed version comes from the Apps tab's device read, matched the
    /// Sources page's way (`ProfileMatcher.installed` — SideInstaller signs
    /// as `<bundle id>.<team id>`, so that counts as the same app).
    /// Unreadable IPA, missing version, or no installed copy all mean nil:
    /// nothing known, nothing to ask.
    @MainActor
    private func downgradeCheckForCurrentRun() -> DowngradeRequest? {
        guard installSource == .custom,
              let url = IPALibrary.customImport()?.url,
              let info = IPALibrary.appInfo(at: url),
              let ipaVersion = info.version, !ipaVersion.isEmpty,
              let installed = SideloadedAppsManager.shared.entries.first(where: {
                  ProfileMatcher.installed($0.app.bundleID, isBuiltFrom: info.bundleID, teamID: nil)
              })?.app.version,
              UpdateChecker.isNewer(installed, than: ipaVersion) else { return nil }
        return DowngradeRequest(appName: info.name, installedVersion: installed, ipaVersion: ipaVersion)
    }

    private func performAppIDQuota(session: OpaquePointer, bundleID: String) throws -> AppIDCost {
        struct Quota: Decodable {
            let new_ids: [String]
            let available: Int?
            let max: Int?
            let next_expiry: Double?
        }
        var json: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_appid_quota(session, bundleID, &json, &error)
        guard rc == 0 else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message(msg)
        }
        let text = json.map { String(cString: $0) } ?? ""
        json.map { si_string_free($0) }
        let quota = try JSONDecoder().decode(Quota.self, from: Data(text.utf8))
        return AppIDCost(newIDs: quota.new_ids, available: quota.available, limit: quota.max,
                         nextExpiry: quota.next_expiry.map(Date.init(timeIntervalSince1970:)))
    }

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
        // Bundled into AltStore for its Remote AltServer setup, which only
        // AltStore 2.3 reads there; 2.3.1 and later, like the other apps, get
        // the pairing file after the install instead.
        let pairingPath = pairingFilePath ?? PairingController.pairingFilePath()
        let source = downloadedSource ?? installSource
        setStep(.sign, .active)
        do {
            let path = try await onSignQueue {
                try self.performSign(session: session, ipa: ipa, udid: udid, deviceName: name,
                                     pairingFilePath: pairingPath,
                                     forMadeira: source == .madeira || Self.isMadeira(ipaPath: ipa))
            }
            signedAppPath = path
            // Read the app's name from the signed bundle (imported IPAs have none before this).
            signedDisplayName = signedAppName()
            setStep(.sign, .done)
        } catch {
            // A21-2：签名失败的解包目录由 Rust 自清；这里只扫 24 小时以上的陈旧目录。
            Self.discardExtraction(forIPA: ipa)
            // User-fixable failures get an explanatory card. A certificate that
            // already exists offers revoke-and-retry, never revoked automatically.
            if case EngineError.certExists = error {
                setGuide(Guides.certExists(sideStoreCertificate: canUseSideStoreCertificate))
                certConflict = true
            }
            if case let EngineError.deviceRegistration(udid, raw) = error {
                setGuide(Guides.deviceRegistration(udid: udid, raw: raw))
            }
            if case EngineError.appIDLimit = error {
                setGuide(Guides.appIDLimit)
            }
            if case EngineError.underage = error {
                setGuide(Guides.underage)
            }
            if case EngineError.emailUnverified = error {
                setGuide(Guides.emailUnverified)
            }
            throw error
        }
    }

    /// Every app gets Increased Memory Limit on its App ID before the profile is
    /// requested, as iLoader 2.4.1 does, unless it's an app store that refreshes
    /// itself, such as SideStore and LiveContainer + SideStore: SideStore registers
    /// their App IDs again each week without it, so their next profiles would grant
    /// less than they're signed with (isideload's `MemoryLimit`). A refusal from
    /// Apple only leaves it out.
    ///
    /// `forMadeira` signs the way Madeira needs: with that capability required,
    /// and without an app group. Madeira renews its own profile and registers
    /// its App ID again when it runs out; it can restore the first on a new App
    /// ID, not the second.
    private func performSign(session: OpaquePointer, ipa: String, udid: String, deviceName: String,
                             pairingFilePath: String, forMadeira: Bool) throws -> String {
        log("Signing \(ipa) …")
        if forMadeira {
            log("Signing for Madeira: Increased Memory Limit on its App ID (it shows as Memory+), and no app group.")
        }
        var signed: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        // Memory limit: 1 = required, 2 = where it's safe (see sideinstaller.h).
        let rc = si_sign_ipa(session, ipa, udid, deviceName, pairingFilePath,
                             forMadeira ? 1 : 2, forMadeira ? 0 : 1, &signed, &error)
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
            if Self.isAppIDLimitError(msg) { throw EngineError.appIDLimit }
            if Self.isUnderageError(msg) { throw EngineError.underage }
            if Self.isEmailUnverifiedError(msg) { throw EngineError.emailUnverified }
            // Carry the UDID so the guide can show it for manual entry.
            if Self.isDeviceRegistrationError(msg) {
                throw EngineError.deviceRegistration(udid: udid, raw: msg)
            }
            throw EngineError.message(L("Signing failed: %@", friendlyRustError(msg)))
        }
    }

    // MARK: - 企业证书签名安装（本地证书，不用 Apple ID）

    /// 用导入的企业证书（.p12 + 描述文件）给已导入的 IPA 本地
    /// 签名并安装：跳过登录/下载/苹果那套，配对、隧道、安装与
    /// 一键安装共用同一套。装完同样要去系统设置里信任该企业证书。
    @MainActor
    func runEnterpriseCertInstall() {
        guard let entry = IPALibrary.customImport() else {
            guard !isRunning else { return }
            // B-1 (0.9.163): runOneClick 同款——没起跑的路不经过
            // resetRun，旧 lastError 不能留给这次的调用方。
            lastError = nil
            setGuide(Guides.customIPA)
            log("⛔️ No IPA imported yet. Import an .ipa above first, then sign it with the enterprise certificate.")
            return
        }
        runEnterpriseCertInstall(ipaURL: entry.url, mods: CertSignMods())
    }

    /// 证书页入口：对指定 IPA 用企业证书签名（可带修改项）并安装。
    /// B-3 (0.9.164): @MainActor — the `isGenerating` guard below reads
    /// PairingManager's main-actor state, as runOneClick does. The only
    /// caller is the @MainActor no-arg entry above (which the cert page
    /// calls), so no call site changes.
    @MainActor
    func runEnterpriseCertInstall(ipaURL: URL, mods: CertSignMods) {
        guard !isRunning else {
            lastError = L("An install is already running. Wait for it to finish, then refresh.")
            return
        }
        // B-1 (0.9.163): runOneClick 同款——起跑守卫前先清掉上一跑
        // 的 lastError/guide，否则被拦住的这次会报上一次的错。
        lastError = nil
        guide = nil
        // B-3 (0.9.164): runOneClick refuses while a pairing file is being
        // generated, but this entry didn't — starting now would lose the
        // device link when generation disconnects at the end.
        guard !PairingManager.shared.isGenerating else {
            lastError = L("Pairing file is being generated. Wait for it to finish, then try again.")
            log("⛔️ Pairing file is being generated — enterprise-cert install refused until it finishes, so the link isn't dropped mid-install.")
            return
        }
        guard osSupported else {
            lastError = L("iOS %@ isn't supported — SideInstaller needs iOS %@ or later.",
                          osVersionText, Engine.minimumTunnelOSText)
            log("⛔️ iOS \(osVersionText) isn't supported — SideInstaller needs iOS \(Engine.minimumTunnelOSText) or later.")
            return
        }
        guard canSelfPair || hasPairingFile else {
            setGuide(Guides.importPairing)
            log("⛔️ A pairing file is needed: import a pairing file first, then sign with the enterprise certificate.")
            return
        }
        guard EnterpriseCertStore.ready else {
            lastError = L("企业证书材料不齐：需要 .p12、描述文件和证书密码。")
            log("⛔️ Enterprise certificate materials are incomplete: a .p12, a provisioning profile and the certificate password are needed.")
            return
        }
        refreshNetworkStatus()
        guard tunnelAvailable else {
            if BuiltinTunnel.useBuiltinDirectly {
                // B-1 (0.9.163): runOneClick 同款——只写日志不留原因，
                // 调用方会报上一跑的旧错。
                lastError = L("No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.")
                log("⛔️ No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.")
            } else {
                setGuide(Guides.vpn)
                log("⛔️ No loopback VPN is connected. Turn one on, then tap Install again.")
            }
            return
        }
        // 0.9.140: a stale own-address falls back to the default first
        // (`deviceIPIsUsable` logs the same line below when it can't).
        if !deviceIPIsUsable() {
            setGuide(Guides.deviceIPMismatch)
            return
        }
        resetRun()
        // B-2：起跑前 mint 新会话凭证（resetRun 已清掉旧值）。
        installSessionID = UUID()
        isRunning = true
        // B4 (0.9.158): this run never signs in — the history records the
        // enterprise profile's name, not the Apple ID from Settings.
        historyIdentityOverride = Self.enterpriseCertHistoryIdentity()
        // B2：配对窗口期先登记源路径，收尾再注销（见 isInstallingSource）。
        installingSourcePath = ipaURL.path
        log("=== Starting enterprise-cert install ===")

        pipelineTask = Task { @MainActor in
            // runStarted() 是 @MainActor（InstallActivity 类级隔离），
            // 本入口现也带 @MainActor（B-3，0.9.164）；Task 头一句仍在
            // 任何管线工作之前，写法不动。
            InstallActivity.shared.runStarted()
            var outcome: InstallActivity.Outcome = .stopped
            var tunnelAcquired = false
            do {
                // SIDE-2：隧道按需开——同 runOneClick，管线开始拿租约、收尾统一还。
                guard await acquireTunnel() else {
                    if Task.isCancelled { throw CancellationError() }
                    throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                        ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                        : L("LocalDevVPN isn't connected. Connect it, then try again."))
                }
                tunnelAcquired = true
                try await ensureNetwork()
                try await pairAndConnect()
                // SIDE-33 B-1：配对边界复核取消——取消落在配对等待期间时，
                // onDeviceQueue 跑完才返回，这里拦住，不再继续签名/安装。
                try Task.checkCancellation()
                downloadedIPAPath = ipaURL.path
                downloadedSource = .custom
                try await signAppWithCert(mods: mods)
                // SIDE-33 B-1：签名边界复核取消。
                try Task.checkCancellation()
                try await install(prestaged: nil)
                // SIDE-33 B-1：安装边界复核取消——拦在 finishSuccess() 之前，不谎报成功。
                try Task.checkCancellation()
                finishSuccess()
                outcome = .installed
            } catch is CancellationError {
                outcome = .cancelled
                log("Install cancelled.")
                for s in Step.allCases { stepStates[s] = .pending }
                installProgress = 0
                // B-1：照抄 runOneClick 取消分支——清掉设备摘要，
                // 否则状态 pill 还显示上一轮设备，盖住隧道状态。
                deviceSummary = nil
                deviceUDID = nil
                deviceName = nil
                setGuide(nil)
            } catch {
                let msg = userFacingErrorMessage(error)
                let raw = String(describing: error)
                lastError = msg
                log("⛔️ Stopped: \(raw)")
                failActiveStep(to: .failed)
                // F-A (0.9.155): 同 runOneClick——失败也记一条历史
                // （成功路的 `finishSuccess` 是另一出口，一跑只记一条）。
                InstallHistoryStore.recordFailure(appName: installedAppName,
                                                  version: signedAppVersion() ?? downloadedVersion,
                                                  identity: historyIdentityOverride ?? normalizedAppleID,
                                                  reason: msg,
                                                  bundleID: signedAppBundleID())
            }
            InstallActivity.shared.runEnded(outcome)
            if tunnelAcquired { releaseTunnel() }
            stopBackgroundWork()
            // C20：签好的包解在 tmp/<名>_<uuid>_extracted，收尾删掉它再置 nil；
            // 删失败静默（helper 内 try?）；目录名带唯一 UUID，下次签同名也不会复用它。
            if let signed = signedAppPath { Self.discardSignedBundle(at: signed) }
            signedAppPath = nil
            // B2：收尾注销配对窗口期的源路径登记（与起跑登记配对）。
            installingSourcePath = nil
            isRunning = false
            isCancelling = false
            pairingPIN = nil
        }
    }

    private func signAppWithCert(mods: CertSignMods = CertSignMods()) async throws {
        guard let ipa = downloadedIPAPath else { throw EngineError.message(L("No IPA imported.")) }
        setStep(.sign, .active)
        let path: String
        do {
            path = try await onSignQueue { try self.performCertSign(ipa: ipa, mods: mods) }
        } catch {
            // A21-2：企业签名失败的解包目录由 Rust 自清；这里只扫 24 小时以上的陈旧目录。
            Self.discardExtraction(forIPA: ipa)
            throw error
        }
        signedAppPath = path
        signedDisplayName = signedAppName()
        setStep(.sign, .done)
    }

    /// 在 Swift 侧用 Security 解开 .p12（证书 + 私钥 DER），交给
    /// Rust 侧 si_sign_ipa_with_cert_ex 本地签名（可带修改项）。
    private func performCertSign(ipa: String, mods: CertSignMods = CertSignMods()) throws -> String {
        try EnterpriseCertStore.validateForSigning()
        let (certDER, keyDER) = try EnterpriseCertStore.identityDERs()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("EnterpriseSign-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let certPath = tmp.appendingPathComponent("cert.der")
        let keyPath = tmp.appendingPathComponent("key.der")
        try certDER.write(to: certPath)
        try keyDER.write(to: keyPath)
        var iconPath: String? = nil
        if let icon = mods.pngIconData() {
            let path = tmp.appendingPathComponent("icon.png")
            try icon.write(to: path)
            iconPath = path.path
        }
        let json = mods.json(iconPath: iconPath, outIpaPath: nil)
        log("Signing \(ipa) with enterprise cert …")
        var signed: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_sign_ipa_with_cert_ex(ipa, certPath.path, keyPath.path,
                                          EnterpriseCertStore.provisionURL.path,
                                          json, &signed, &error)
        if rc == 0 {
            let path = signed.map { String(cString: $0) } ?? ""
            signed.map { si_string_free($0) }
            log("Signed bundle at \(path)")
            return path
        }
        let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
        error.map { si_string_free($0) }
        log("Enterprise cert sign FAILED: \(msg)")
        throw EngineError.message(L("企业证书签名失败：%@", friendlyRustError(msg)))
    }

    /// 已签名页入口：解包一个已签好的 IPA 直接安装（不再签一次）。
    /// B-3 (0.9.164): @MainActor — the `isGenerating` guard below reads
    /// PairingManager's main-actor state, as runOneClick does. All callers
    /// are main-actor (Files tab, signed-IPAs page), so no call site changes.
    @MainActor
    func runInstallSignedIPA(ipaURL: URL) {
        guard !isRunning else {
            lastError = L("An install is already running. Wait for it to finish, then refresh.")
            return
        }
        // B-1 (0.9.163): runOneClick 同款——起跑守卫前先清掉上一跑
        // 的 lastError/guide，否则被拦住的这次会报上一次的错。
        lastError = nil
        guide = nil
        // B-3 (0.9.164): runOneClick refuses while a pairing file is being
        // generated, but this entry didn't — starting now would lose the
        // device link when generation disconnects at the end.
        guard !PairingManager.shared.isGenerating else {
            lastError = L("Pairing file is being generated. Wait for it to finish, then try again.")
            log("⛔️ Pairing file is being generated — signed-IPA install refused until it finishes, so the link isn't dropped mid-install.")
            return
        }
        guard osSupported else {
            lastError = L("iOS %@ isn't supported — SideInstaller needs iOS %@ or later.",
                          osVersionText, Engine.minimumTunnelOSText)
            log("⛔️ iOS \(osVersionText) isn't supported — SideInstaller needs iOS \(Engine.minimumTunnelOSText) or later.")
            return
        }
        guard canSelfPair || hasPairingFile else {
            setGuide(Guides.importPairing)
            log("⛔️ A pairing file is needed: import a pairing file first, then install.")
            return
        }
        refreshNetworkStatus()
        guard tunnelAvailable else {
            if BuiltinTunnel.useBuiltinDirectly {
                // B-1 (0.9.163): runOneClick 同款——只写日志不留原因，
                // 调用方会报上一跑的旧错。
                lastError = L("No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.")
                log("⛔️ No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.")
            } else {
                setGuide(Guides.vpn)
                log("⛔️ No loopback VPN is connected. Turn one on, then tap Install again.")
            }
            return
        }
        // 0.9.140: a stale own-address falls back to the default first
        // (`deviceIPIsUsable` logs the same line below when it can't).
        if !deviceIPIsUsable() {
            setGuide(Guides.deviceIPMismatch)
            return
        }
        resetRun()
        // B-2：起跑前 mint 新会话凭证（resetRun 已清掉旧值；
        // 原先这句在 isRunning = true 之后，现并入统一 mint 点）。
        installSessionID = UUID()
        isRunning = true
        // B4 (0.9.158): this run installs an already-signed IPA and never
        // signs in — the history records the enterprise profile's name,
        // not the Apple ID from Settings.
        historyIdentityOverride = Self.enterpriseCertHistoryIdentity()
        // B2：配对窗口期先登记源路径，收尾再注销（见 isInstallingSource）。
        installingSourcePath = ipaURL.path
        log("=== Installing already-signed IPA ===")

        pipelineTask = Task { @MainActor in
            // 修法：同企业路——runStarted() 是 @MainActor，本入口现也带
            // @MainActor（B-3，0.9.164）；放进 Task 头一句，仍在任何管线
            // 工作之前，写法不动。
            InstallActivity.shared.runStarted()
            var outcome: InstallActivity.Outcome = .stopped
            var tunnelAcquired = false
            do {
                // SIDE-2：隧道按需开——同 runOneClick，管线开始拿租约、收尾统一还。
                guard await acquireTunnel() else {
                    if Task.isCancelled { throw CancellationError() }
                    throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                        ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                        : L("LocalDevVPN isn't connected. Connect it, then try again."))
                }
                tunnelAcquired = true
                try await ensureNetwork()
                try await pairAndConnect()
                // SIDE-33 B-1：配对边界复核取消——取消落在配对等待期间时，
                // onDeviceQueue 跑完才返回，这里拦住，不再继续解包/安装。
                try Task.checkCancellation()
                downloadedIPAPath = ipaURL.path
                downloadedSource = .custom
                setStep(.sign, .active)
                let bundle: String
                do {
                    bundle = try await onSignQueue { try self.performExtract(ipa: ipaURL.path) }
                } catch {
                    // A21-2：解包失败的解包目录由 Rust 自清；这里只扫 24 小时以上的陈旧目录。
                    Self.discardExtraction(forIPA: ipaURL.path)
                    throw error
                }
                signedAppPath = bundle
                signedDisplayName = signedAppName()
                setStep(.sign, .done)
                // SIDE-33 B-1：解包边界复核取消。
                try Task.checkCancellation()
                try await install(prestaged: nil)
                // SIDE-33 B-1：安装边界复核取消——拦在 finishSuccess() 之前，不谎报成功。
                try Task.checkCancellation()
                finishSuccess()
                outcome = .installed
            } catch is CancellationError {
                outcome = .cancelled
                log("Install cancelled.")
                for s in Step.allCases { stepStates[s] = .pending }
                installProgress = 0
                // B-1：照抄 runOneClick 取消分支——清掉设备摘要，
                // 否则状态 pill 还显示上一轮设备，盖住隧道状态。
                deviceSummary = nil
                deviceUDID = nil
                deviceName = nil
                setGuide(nil)
            } catch {
                let msg = userFacingErrorMessage(error)
                let raw = String(describing: error)
                lastError = msg
                log("⛔️ Stopped: \(raw)")
                failActiveStep(to: .failed)
                // F-A (0.9.155): 同 runOneClick——失败也记一条历史
                // （成功路的 `finishSuccess` 是另一出口，一跑只记一条）。
                InstallHistoryStore.recordFailure(appName: installedAppName,
                                                  version: signedAppVersion() ?? downloadedVersion,
                                                  identity: historyIdentityOverride ?? normalizedAppleID,
                                                  reason: msg,
                                                  bundleID: signedAppBundleID())
            }
            InstallActivity.shared.runEnded(outcome)
            if tunnelAcquired { releaseTunnel() }
            stopBackgroundWork()
            // C20：签好的包解在 tmp/<名>_<uuid>_extracted，收尾删掉它再置 nil；
            // 删失败静默（helper 内 try?）；目录名带唯一 UUID，下次签同名也不会复用它。
            if let signed = signedAppPath { Self.discardSignedBundle(at: signed) }
            signedAppPath = nil
            // B2：收尾注销配对窗口期的源路径登记（与起跑登记配对）。
            installingSourcePath = nil
            isRunning = false
            isCancelling = false
            pairingPIN = nil
        }
    }

    /// 用 Rust 侧解包 IPA，返回 .app 包目录。
    private func performExtract(ipa: String) throws -> String {
        var bundle: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_extract_ipa(ipa, &bundle, &error)
        if rc == 0 {
            let path = bundle.map { String(cString: $0) } ?? ""
            bundle.map { si_string_free($0) }
            return path
        }
        let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
        error.map { si_string_free($0) }
        log("Extract IPA FAILED: \(msg)")
        throw EngineError.message(L("IPA 解包失败：%@", friendlyRustError(msg)))
    }

    /// True when the IPA at `ipaPath` is Madeira, whichever way it got here: the
    /// download, an import, or a copy kept for refreshing.
    private static func isMadeira(ipaPath: String) -> Bool {
        IPALibrary.appInfo(at: URL(fileURLWithPath: ipaPath)).map {
            MadeiraPairingHandoff.isMadeira(bundleID: $0.bundleID)
        } ?? false
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

    /// Detect Apple developer error 1102, sent when the Apple Account's owner is
    /// under the age Apple requires for developer services.
    static func isUnderageError(_ raw: String) -> Bool {
        raw.lowercased().contains("developer error 1102")
    }

    /// Detect Apple developer error 2160, sent until the Apple Account's email
    /// address is verified.
    static func isEmailUnverifiedError(_ raw: String) -> Bool {
        raw.lowercased().contains("developer error 2160")
    }

    /// Detect running out of App IDs: Apple's error 9120 from `addAppId`, or the
    /// signer's check before it registers any.
    static func isAppIDLimitError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("developer error 9120")
            || m.contains("not enough available app ids")
    }

    /// Detect installd refusing an app because a free Apple ID's three are
    /// already installed. Xcode words the same refusal differently.
    static func isAppLimitError(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("maximum number of installed apps")
            || m.contains("maximum number of apps for free development profiles")
    }

    // MARK: Step 7 — install over AFC + installation_proxy

    @MainActor
    private func install(prestaged: DeviceConnection.PrestagedBundle? = nil) async throws {
        guard let bundle = signedAppPath else { throw EngineError.message(L("No signed bundle to install.")) }
        setStep(.install, .active)
        installProgress = 0
        let ip = deviceHost
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        do {
            try await onDeviceQueue {
                // iOS drops the idle tunnel during sign-in and signing, and
                // `isConnected` doesn't detect it, so reconnect first.
                self.log("Refreshing device link before install (tunnel was idle during sign-in/download/sign) …")
                try self.connection.connect(deviceIP: ip, pairingFilePath: path)
                guard self.connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
                self.log("Installing signed bundle via AFC + installation_proxy …")
                try self.connection.installSignedApp(bundlePath: bundle, prestaged: prestaged)
                self.log("Install request completed.")
            }
        } catch where Self.isAppLimitError(String(describing: error)) {
            log("installd refused the app: \(error)")
            setGuide(Guides.appLimit)
            throw EngineError.appLimit
        }
        installProgress = 1
        setStep(.install, .done)
    }

    /// Starts copying the files signing won't change from the downloaded IPA
    /// into /PublicStaging, on the device queue while signing runs on its own.
    /// A failure only means the install uploads everything, as it used to.
    @MainActor
    private func startPrestage() {
        guard let ipa = downloadedIPAPath else { return }
        let ip = deviceHost
        let rpPath = pairingFilePath ?? PairingController.pairingFilePath()
        prestage = Task { @MainActor in
            guard !Task.isCancelled else { return nil }
            do {
                return try await self.onDeviceQueue { () -> DeviceConnection.PrestagedBundle? in
                    let started = Date()
                    // The link may have sat idle since it opened, and iOS drops idle tunnels.
                    try self.connection.connect(deviceIP: ip, pairingFilePath: rpPath)
                    let staged = try self.connection.prestageUnsignedBundle(ipaPath: ipa)
                    self.log(String(format: "Staged %d files signing won't change, straight from the IPA, in %.2f s.",
                                    staged.files.count, Date().timeIntervalSince(started)))
                    return staged
                }
            } catch {
                self.log("⚠️ Couldn't stage the app ahead of signing (\(self.short(error))); the install uploads all of it.")
                return nil
            }
        }
    }

    // MARK: Step 8 — write the pairing file into SideStore

    /// What a run did on the device link before the install.
    private struct PreparedPairing {
        /// The pairing file to hand over, with the lockdown record when that worked.
        let placement: String
        /// The app the file was already written into, if any.
        let writtenInto: String?
    }

    /// Starts the device work that doesn't need the signed app, on the link just
    /// opened: adding the lockdown record to the pairing file (a Trust prompt the
    /// user can answer while signing runs), then, when the app being installed is
    /// already on the iPhone, writing the pairing file into it now. Installing
    /// over an app keeps its Documents, so that write needn't wait for the install.
    @MainActor
    private func startDevicePreparation() {
        let rpPath = pairingFilePath ?? PairingController.pairingFilePath()
        let udid = deviceUDID
        let ip = deviceHost
        let source = installSource
        let signingIn = backgroundSignIn
        devicePreparation = Task { @MainActor in
            // Never throws; the fallback is only there for the queue's signature.
            let placement = (try? await self.onDeviceQueue {
                self.placementPairingFile(rpPairingPath: rpPath, udid: udid)
            }) ?? rpPath

            // Only SideStore reads the file as it's written here; Madeira takes
            // the RPPairing record on its own, after the install. Signing names
            // the app "<base>.<team ID>", so the team has to be known.
            guard source.sideStoreHome != nil, let base = source.pairingBundleIDBase else {
                return PreparedPairing(placement: placement, writtenInto: nil)
            }
            if let signingIn { _ = await signingIn.result }
            guard !Task.isCancelled, let team = self.signingTeamID else {
                return PreparedPairing(placement: placement, writtenInto: nil)
            }
            let bundleID = "\(base).\(team)"
            // Any failure leaves the write to after the install, as before.
            let written: String? = (try? await self.onDeviceQueue {
                try self.writePairingAheadOfInstall(bundleID: bundleID, source: source,
                                                    placement: placement, ip: ip, rpPath: rpPath)
            }) ?? nil
            return PreparedPairing(placement: placement, writtenInto: written)
        }
    }

    /// Writes the pairing file into `bundleID` if that app is installed already,
    /// returning the bundle ID written into, or nil when it isn't installed yet.
    /// Runs on `deviceQueue`.
    private func writePairingAheadOfInstall(bundleID: String, source: InstallSource,
                                            placement: String, ip: String, rpPath: String) throws -> String? {
        // The link sat idle while the sign-in finished, and iOS drops idle tunnels.
        try connection.connect(deviceIP: ip, pairingFilePath: rpPath)
        guard try connection.isInstalled(bundleID: bundleID) else { return nil }
        let remoteRel = source.pairingRemoteRelativePath
        log("\(bundleID) is already installed — writing the pairing file into it ahead of the install …")
        let written = try connection.writePairingFile(intoBundleID: bundleID,
                                                       remoteRelativePath: remoteRel,
                                                       pairingFilePath: placement)
        log("Pairing file written into \(bundleID) and read-back VERIFIED (\(written) bytes); installing over the app keeps it.")
        return bundleID
    }

    @MainActor
    private func writePairing(accountConfig handOff: Task<String?, Never>? = nil,
                              prepared: PreparedPairing? = nil) async throws {
        setStep(.writePairing, .active)
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        // The installed build decides the host app and where the file lands.
        let source = installedBuild
        // Built on the sign queue, where all isideload calls run, before the
        // device-queue write below; a run starts it during the install.
        let accountConfig: String?
        if let handOff {
            // B-C1：取消发生在等待之前时直接抛，不等交接任务跑完。
            // （取消发生在等待期间时仍等那次短 FFI 跑完——接受的残留，
            // onSignQueue 内不检查取消，Task 取消拦不住它。）
            try Task.checkCancellation()
            accountConfig = await handOff.value
        } else {
            accountConfig = await accountConfigJSON(source: source)
        }
        // SIDE-33 B-2：交接落定后复核取消——覆盖 handOff 与 accountConfigJSON
        // 两个分支；拦住时配对文件不写入。
        try Task.checkCancellation()
        let udid = deviceUDID
        do {
            let handed = try await onDeviceQueue {
                try self.performWritePairing(path: path, udid: udid, source: source,
                                             accountConfig: accountConfig, prepared: prepared)
            }
            madeiraHandoff = handed.madeira
            altStoreHoldsPairing = handed.altStorePairing
        } catch {
            // SideStore can't work without this file. Madeira can pair itself or
            // use StikDebug, AltStore pairs as its Remote AltServer is set up,
            // and an imported IPA may not want one at all.
            guard source.pairingIsOptional else { throw error }
            if signedAppIsMadeira(source) {
                log("⚠️ Couldn't reach Madeira's container (\(short(error))). It's installed: set up JIT in Madeira, and refresh it under Tools › Sideloaded apps.")
            } else if source == .altStore {
                log("⚠️ Couldn't put the pairing file into AltStore (\(short(error))). It's installed: setting up its Remote AltServer pairs it instead.")
            } else {
                log("⚠️ Couldn't seed the pairing file into \(installedAppName) (\(short(error))). It's installed and ready — only AltStore-family apps need that file.")
            }
        }
        // SIDE-33 B-2：写盘返回后复核取消——拦在 setStep(.done) 与
        // finishSuccess() 之前；已发生的写盘保留，只是不再谎报成功。
        try Task.checkCancellation()
        setStep(.writePairing, .done)
    }

    /// What step 8 handed to the app it installed, for the last steps' card.
    private struct Handed {
        var madeira = MadeiraHandoff()
        /// AltStore got the pairing file.
        var altStorePairing = false
    }

    /// Returns what Madeira was handed, when the app is Madeira, and whether
    /// AltStore got the pairing file, when it's AltStore.
    private func performWritePairing(path: String, udid: String?, source: InstallSource,
                                     accountConfig: String?,
                                     prepared: PreparedPairing? = nil) throws -> Handed {
        guard connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
        let size = fileSize(path)
        guard FileManager.default.fileExists(atPath: path), size > 0 else {
            throw EngineError.message(L("Pairing file missing — pairing must run first."))
        }
        // Add a lockdown record so AltStore-family apps can read the file. A run
        // has already done this right after opening the link.
        let placement = prepared?.placement ?? placementPairingFile(rpPairingPath: path, udid: udid)

        let appName = source.pairingAppDisplayName ?? signedAppName() ?? source.displayName
        let bundleID: String
        if prepared != nil, let signed = signedAppBundleID() {
            // A run has just installed the signed bundle, so its ID is the app's.
            bundleID = signed
        } else if let displayName = source.pairingAppDisplayName,
                  let base = source.pairingBundleIDBase,
                  let found = try connection.resolveInstalledBundleID(displayName: displayName, bundleIDBase: base) {
            // Otherwise resolve the host app from installation_proxy, by display
            // name then base id, falling back to the signed bundle's own id.
            bundleID = found
        } else if let signed = signedAppBundleID() {
            bundleID = signed
            if source.pairingAppDisplayName != nil {
                log("\(appName) not found via installation_proxy; using signed bundle id \(signed).")
            }
        } else {
            throw EngineError.message(L("%@ isn't installed yet — install must run first.", source.displayName))
        }
        log("Resolved \(appName) bundle id: \(bundleID)")
        if signedAppIsMadeira(source) {
            // Neither hand-off depends on the other, and Madeira works without both.
            var handed = MadeiraHandoff()
            do {
                handed.pairing = try handOffMadeiraPairing(placementPath: placement, bundleID: bundleID)
            } catch {
                log("⚠️ Couldn't hand Madeira the pairing file (\(short(error))). Pair it under its Settings › JIT › JIT setup, or write the file again from Tools › Pairing.")
            }
            handed.signIn = handOffMadeiraSignIn(accountConfig, bundleID: bundleID)
            return Handed(madeira: handed)
        }
        if source == .altStore {
            return Handed(altStorePairing: try handOffAltStorePairing(placementPath: placement,
                                                                      bundleID: bundleID))
        }
        // SideStore reads the file at its Documents root, LiveContainer deeper.
        let remoteRel = source.pairingRemoteRelativePath
        if prepared?.writtenInto == bundleID {
            log("Pairing file was already written into \(appName) before the install.")
        } else {
            log("Writing pairing file into \(bundleID) /Documents/\(remoteRel) …")
            let written = try connection.writePairingFile(intoBundleID: bundleID,
                                                           remoteRelativePath: remoteRel,
                                                           pairingFilePath: placement)
            log("Pairing file written into \(appName) and read-back VERIFIED (\(written) bytes).")
        }
        // Always after the install: it's the reinstall that makes iOS read the
        // settings this edits, so they can't go in ahead of it.
        let signedSideStore = signedAppBundleID()?.hasPrefix("com.SideStore.SideStore") == true
        if let home = source.sideStoreHome ?? (signedSideStore ? .standalone : nil) {
            handOffSplitPairing(placementPath: placement, bundleID: bundleID,
                                appName: appName, home: home, udid: udid)
        }

        // Give SideStore the signing certificate so its first sign-in reuses it
        // instead of creating a new one and asking to resign. Failures log and leave a notice under the progress card (C25).
        if let accountConfig, let remoteRel = accountConfigRemoteRelativePath(source: source) {
            do {
                let handed = try connection.writeFile(intoBundleID: bundleID,
                                                      remoteRelativePath: remoteRel,
                                                      data: Data(accountConfig.utf8))
                log("Certificate handed to \(appName): /Documents/\(remoteRel) written and read-back VERIFIED (\(handed) bytes). SideStore imports and deletes it on first launch.")
            } catch {
                // C25：同上，证书交接失败也在进度卡下方留一句（新 key 1 个）。
                Task { @MainActor in
                    self.handOffNotice = [self.handOffNotice, L("The signing certificate wasn't handed over. SideStore may ask to resign itself on first sign-in.")].compactMap { $0 }.joined(separator: "\n")
                }
                log("⚠️ Couldn't hand \(appName) the signing certificate (\(short(error))). It's installed and ready, but it will ask to resign itself on first sign-in.")
            }
        }
        return Handed()
    }

    /// Gives AltStore the RPPairing record on its own, where AltServer puts it
    /// (see `AltStorePairingHandoff`). Returns false, writing nothing, when the
    /// pairing file has none. Runs on `deviceQueue`.
    private func handOffAltStorePairing(placementPath: String, bundleID: String) throws -> Bool {
        let file = try Data(contentsOf: URL(fileURLWithPath: placementPath))
        guard let record = AltStorePairingHandoff.record(from: file) else {
            log("This pairing file has no RPPairing record, the only kind AltStore connects with, so none was written. Setting up AltStore's Remote AltServer pairs it instead.")
            return false
        }
        let rel = AltStorePairingHandoff.remoteRelativePath
        log("Writing the RPPairing record into \(bundleID) /Documents/\(rel) …")
        let written = try connection.writeFile(intoBundleID: bundleID, remoteRelativePath: rel, data: record)
        log("Pairing file written into AltStore and read-back VERIFIED (\(written) bytes). AltStore takes it in when its Remote AltServer is set up, which then skips pairing.")
        return true
    }

    /// Gives Madeira the RPPairing record on its own (see
    /// `MadeiraPairingHandoff`). Returns false, writing nothing, when the
    /// pairing file has none. Runs on `deviceQueue`.
    private func handOffMadeiraPairing(placementPath: String, bundleID: String) throws -> Bool {
        let file = try Data(contentsOf: URL(fileURLWithPath: placementPath))
        guard let record = MadeiraPairingHandoff.record(from: file) else {
            log("⚠️ This pairing file has no RPPairing record, the only kind Madeira's built-in JIT reads, so nothing was written. Pair in Madeira (iOS 27), import an RPPairing file there, or use StikDebug.")
            return false
        }
        let rel = MadeiraPairingHandoff.remoteRelativePath
        log("Writing the RPPairing record into \(bundleID) /Documents/\(rel) …")
        let written = try connection.writeFile(intoBundleID: bundleID, remoteRelativePath: rel, data: record)
        log("Pairing file written into Madeira and read-back VERIFIED (\(written) bytes). Madeira moves it into its Keychain the next time it looks for one.")
        return true
    }

    /// Gives ARMSX3 the RPPairing record on its own (see
    /// `ARMSX3PairingHandoff`). Returns false, writing nothing, when the
    /// pairing file has none. Runs on `deviceQueue`.
    private func handOffARMSX3Pairing(placementPath: String, bundleID: String) throws -> Bool {
        let file = try Data(contentsOf: URL(fileURLWithPath: placementPath))
        guard let record = ARMSX3PairingHandoff.record(from: file) else {
            log("⚠️ This pairing file has no RPPairing record, the only kind ARMSX3's JIT reads, so nothing was written. Import a remote pairing file (from idevice_pair or iLoader) here, or generate one on iOS 27, then try again.")
            return false
        }
        let rel = ARMSX3PairingHandoff.remoteRelativePath
        log("Writing the RPPairing record into \(bundleID) /Documents/\(rel) …")
        let written = try connection.writeFile(intoBundleID: bundleID, remoteRelativePath: rel, data: record)
        log("Pairing file written into ARMSX3 and read-back VERIFIED (\(written) bytes). ARMSX3 takes it in the next time it opens; if it's open now, close it in the app switcher first.")
        return true
    }

    /// Gives Madeira the sign-in it renews its own signing with (see
    /// `MadeiraSigningHandoff`), as `madeiraSigningAccountJSON` built it. Returns
    /// whether it's there; failures only log. Runs on `deviceQueue`.
    private func handOffMadeiraSignIn(_ account: String?, bundleID: String) -> Bool {
        guard let account else { return false }
        guard let handoff = MadeiraSigningHandoff.plist(from: account) else {
            log("⚠️ The sign-in for Madeira is incomplete, or the anisette server in use isn't reached over HTTPS, so it wasn't handed over. Refresh Madeira under Tools › Sideloaded apps.")
            return false
        }
        let path = MadeiraSigningHandoff.containerPath
        do {
            let written = try connection.updatePlist(inBundleID: bundleID, containerPath: path) { $0 = handoff }
            log("Sign-in handed to Madeira: /\(path) written and read-back VERIFIED (\(written) bytes). It holds a developer-portal token and the anisette identity, not the Apple ID password. Madeira moves it into its Keychain when it next starts, and renews its own signing from then on.")
            return true
        } catch {
            log("⚠️ Couldn't hand Madeira the sign-in (\(short(error))). It's installed and ready, but won't renew its own signing: refresh it under Tools › Sideloaded apps.")
            return false
        }
    }

    /// Starts building the certificate hand-off for the build just signed.
    @MainActor
    private func startAccountConfig() -> Task<String?, Never> {
        let source = installedBuild
        return Task { @MainActor in await self.accountConfigJSON(source: source) }
    }

    /// What the install hands over besides the pairing file, or nil for nothing:
    /// SideStore's `Account.sideconf` JSON, or the sign-in Madeira renews its own
    /// signing with. Errors are logged, never thrown.
    @MainActor
    private func accountConfigJSON(source: InstallSource) async -> String? {
        if signedAppIsMadeira(source) { return await madeiraSigningAccountJSON() }
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

    /// The sign-in for Madeira as JSON: what `si_signing_account` reads off the
    /// session, plus the anisette servers a sign-in here tries. Nil, with nothing
    /// read, for a Madeira build that doesn't renew its own signing: a
    /// credential isn't left where nothing takes it in.
    @MainActor
    private func madeiraSigningAccountJSON() async -> String? {
        guard signedMadeiraRenewsItself() else {
            log("This Madeira build doesn't renew its own signing, so no sign-in is handed to it. Refresh it under Tools › Sideloaded apps.")
            return nil
        }
        guard let session = signSession else {
            log("No Apple ID session to hand to Madeira — it won't renew its own signing. Refresh it under Tools › Sideloaded apps.")
            return nil
        }
        // Only servers that can use the identity the hand-off carries.
        let servers = AnisetteServer.sameLibrary(asFirstOf: anisetteCandidates(), in: anisetteServers)
        do {
            return try await onSignQueue { () -> String? in
                var json: UnsafeMutablePointer<CChar>?
                var error: UnsafeMutablePointer<CChar>?
                let rc = si_signing_account(session, &json, &error)
                guard rc == 0 else {
                    let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
                    error.map { si_string_free($0) }
                    throw EngineError.message(msg)
                }
                let account = json.map { String(cString: $0) } ?? ""
                json.map { si_string_free($0) }
                return MadeiraSigningHandoff.adding(anisetteServers: servers, to: account)
            }
        } catch {
            log("⚠️ Couldn't read the sign-in to hand to Madeira (\(short(error))). It won't renew its own signing: refresh it under Tools › Sideloaded apps.")
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
        case .sideStore:          return "Account.sideconf"
        case .liveContainer:      return "SideStore/Documents/Account.sideconf"
        case .madeira, .altStore: return nil
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
        guard !payload.isEmpty else { throw EngineError.message(L("empty account config")) }
        return payload
    }

    // MARK: Success

    @MainActor
    private func finishSuccess() {
        finished = true
        // F5 (0.9.143): one line in the install history — successes only;
        // a failed run never reaches here, so it leaves no entry.
        InstallHistoryStore.record(appName: installedAppName,
                                   version: signedAppVersion() ?? downloadedVersion,
                                   identity: historyIdentityOverride ?? normalizedAppleID,
                                   bundleID: signedAppBundleID())
        let source = installedBuild
        if signedAppIsMadeira(source) {
            setGuide(Guides.trustMadeira(holding: madeiraHandoff))
        } else if source == .altStore {
            setGuide(Guides.trustAltStore(holdingPairing: altStoreHoldsPairing))
        } else {
            setGuide(Guides.trust(appName: installedAppName))
        }
        log("✅ Done — \(installedSourceName) is installed. One trust step left (see the card).")
        // F-1 (0.9.159): with the Settings switch on, the source IPA goes
        // away now that the install is done — renewal sources never do.
        deleteInstalledSourceIPAIfEnabled()
    }

    /// F-1 (0.9.159): deletes the IPA this run installed from, when the
    /// Settings switch is on. Runs at the end of `finishSuccess`, when
    /// signing and installing no longer read the file. A renewal source is
    /// never deleted — losing it would leave the next renewal with nothing
    /// to re-sign from — so the file is checked against
    /// `RenewalSourceStore` by path and by bundle ID first, and skipped
    /// when it matches. The ledger entry goes with the file, the cached
    /// path is cleared so the next run re-fetches, and the Downloads and
    /// Files lists rescan on the notification instead of waiting to be
    /// reopened. A delete that fails only logs; the install already
    /// succeeded, so it must not turn into a failure.
    @MainActor
    private func deleteInstalledSourceIPAIfEnabled() {
        guard Self.deleteAfterInstall else { return }
        let url: URL?
        if let path = downloadedIPAPath {
            url = URL(fileURLWithPath: path)
        } else {
            url = IPALibrary.customImport()?.url
        }
        guard let url else { return }
        let bundleID = IPALibrary.appInfo(at: url)?.bundleID
        if RenewalSourceStore.source(forFileURL: url, bundleID: bundleID) != nil {
            log("Keeping \(url.lastPathComponent): it is a renewal source.")
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
            DownloadLedger.forget(url)
            if downloadedIPAPath == url.path {
                downloadedIPAPath = nil
            }
            if installSource == .custom { refreshCustomIPA() }
            log("Deleted \(url.lastPathComponent) after installing (Settings › Delete the IPA after installing).")
            NotificationCenter.default.post(name: Self.downloadsChanged, object: nil)
        } catch {
            log("⚠️ Couldn't delete \(url.lastPathComponent) after installing: \(short(error))")
        }
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
        let (vpn, wifi, detail) = readNetwork()
        publishNetwork(vpn: vpn, wifi: wifi,
                       vpnText: vpn ? "tunnel up" : "no tunnel (start a loopback VPN)")
        log("Network: \(detail)")
        log("VPN(loopback)=\(vpnStatus), Wi-Fi=\(wifiStatus). RSD target \(deviceHost):\(DeviceConnection.rsdPort).")
        if !vpn { log("⚠️ No tunnel on \(deviceHost)'s subnet — connect a loopback VPN (LocalDevVPN, ClashMi, …).") }
    }

    /// Poll the interface list so the readouts track the tunnel while the app is
    /// open. Runs in `.common` mode so it keeps firing during scrolling.
    /// SIDE-2 S1：以前 2 秒一次、从启动跑到进程死、进后台也不停；自动续签保活
    /// 常驻后台时等于拿着保活换来的后台时间空转系统调用。现在前台 5 秒一次，
    /// 进后台由 SideInstallerApp 停掉、回前台重起（见 stopStatusMonitor）。
    func startStatusMonitor() {
        statusTimer?.invalidate()
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshNetworkStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
        refreshNetworkStatus()
    }

    /// 停掉状态轮询（进后台时调用；回前台由 startStatusMonitor 重起）。
    func stopStatusMonitor() {
        statusTimer?.invalidate()
        statusTimer = nil
    }

    /// One quiet re-scan of the tunnel and Wi-Fi state. A full-tunnel VPN gets
    /// its cached probe answer, and a probe is started when that's stale.
    func refreshNetworkStatus() {
        let (vpn, wifi, _) = readNetwork()
        publishNetwork(vpn: vpn, wifi: wifi,
                       vpnText: vpn ? "tunnel up" : "no tunnel (start a loopback VPN)")
    }

    /// `refreshNetworkStatus`, but waiting for a full-tunnel VPN's probe when
    /// there's no fresh answer, so what's decided next sees it. Returns at once
    /// for any other route.
    @MainActor
    func settleNetworkStatus() async {
        let (vpn, wifi, _) = await readNetworkSettled()
        publishNetwork(vpn: vpn, wifi: wifi,
                       vpnText: vpn ? "tunnel up" : "no tunnel (start a loopback VPN)")
    }

    // MARK: Full-tunnel probe
    //
    // A full-tunnel VPN (case (c) in `NetworkStatus`) is judged by a TCP probe
    // of Device IP. It runs off the main thread, one at a time, and its answer
    // is kept per Device IP and tunnel address: a success for
    // `fullTunnelProbeSuccessLifetime`, a failure for `fullTunnelProbeLifetime`.
    // LocalDevVPN, and no VPN at all, never get here.
    // Restored from 2df7e76 ("Tunnel: accept full-tunnel proxy VPNs that loop
    // Device IP back"); the scan family it reuses was never dropped.

    private static let fullTunnelProbeLifetime: TimeInterval = 5

    /// 成功答案的寿命（B-1，O-29 Side 版）：探通一次后 60 秒内不再重探。
    /// 失败/超时答案仍只活 `fullTunnelProbeLifetime`——VPN 恢复后 5 秒内即知。
    private static let fullTunnelProbeSuccessLifetime: TimeInterval = 60

    private typealias NetworkReading = (vpn: Bool, wifi: Bool, detail: String)

    /// The tunnel and Wi-Fi state now. A full-tunnel VPN counts as up by its
    /// last probe, and as down until one has answered.
    private func readNetwork() -> NetworkReading {
        reading(of: NetworkStatus.scan(deviceIP: deviceHost))
    }

    private func reading(of scan: NetworkStatus.Scan) -> NetworkReading {
        let probe = scan.probeTarget.flatMap { fullTunnelAnswer(for: $0) }
        let vpn = NetworkStatus.tunnelIsUp(route: scan.route,
                                           fallbackMatch: scan.fallbackMatch,
                                           probe: probe)
        return (vpn, scan.wifi, scan.detail)
    }

    /// `readNetwork`, after waiting for a full-tunnel VPN's probe that has no
    /// fresh answer (half a second at most).
    @MainActor
    private func readNetworkSettled() async -> NetworkReading {
        let scan = NetworkStatus.scan(deviceIP: deviceHost)
        guard let target = scan.probeTarget, freshFullTunnelAnswer(for: target) == nil
        else { return reading(of: scan) }
        // One probe at a time: one for an earlier VPN or Device IP finishes first.
        while let running = fullTunnelProbe, running.key != target.key {
            _ = await running.task.value
        }
        if let task = startFullTunnelProbe(target) { _ = await task.value }
        return readNetwork()
    }

    /// True when the tunnel is a full-tunnel VPN whose probe has no fresh
    /// answer, so it may still turn out to be up.
    private func awaitsFullTunnelProbe() -> Bool {
        guard let target = NetworkStatus.scan(deviceIP: deviceHost).probeTarget else { return false }
        return freshFullTunnelAnswer(for: target) == nil
    }

    /// The last answer for `target`, if it's recent. A success answer
    /// (`answered`: connected or refused) lives 60 seconds; a failure or
    /// timeout lives only `fullTunnelProbeLifetime`, so a recovered VPN is
    /// noticed within 5 seconds (B-1).
    private func freshFullTunnelAnswer(for target: NetworkStatus.ProbeTarget) -> NetworkStatus.ProbeResult? {
        guard let last = lastFullTunnelProbe, last.key == target.key else { return nil }
        let lifetime = last.result.answered ? Self.fullTunnelProbeSuccessLifetime : Self.fullTunnelProbeLifetime
        guard Date().timeIntervalSince(last.date) < lifetime
        else { return nil }
        return last.result
    }

    /// The probe answer to judge `target` by: the cached one, possibly stale,
    /// or nil when there's none. Starts a probe when it's stale, and drops it
    /// once Device IP or the VPN has changed.
    private func fullTunnelAnswer(for target: NetworkStatus.ProbeTarget) -> NetworkStatus.ProbeResult? {
        if let last = lastFullTunnelProbe, last.key != target.key { lastFullTunnelProbe = nil }
        if let fresh = freshFullTunnelAnswer(for: target) { return fresh }
        startFullTunnelProbe(target)
        return lastFullTunnelProbe?.result
    }

    /// Starts a probe of `target`, or returns the one already running for it.
    /// Nil while one for another target runs; the next look starts this one.
    @discardableResult
    private func startFullTunnelProbe(_ target: NetworkStatus.ProbeTarget) -> Task<NetworkStatus.ProbeResult, Never>? {
        if let running = fullTunnelProbe {
            return running.key == target.key ? running.task : nil
        }
        let task = Task { @MainActor [weak self] () -> NetworkStatus.ProbeResult in
            let result = await NetworkStatus.probe(host: target.deviceIP, port: DeviceConnection.rsdPort)
            self?.finishFullTunnelProbe(target, result: result)
            return result
        }
        fullTunnelProbe = (target.key, task)
        return task
    }

    /// Keeps the answer, and publishes it when it turns the tunnel up or down.
    @MainActor
    private func finishFullTunnelProbe(_ target: NetworkStatus.ProbeTarget,
                                       result: NetworkStatus.ProbeResult) {
        fullTunnelProbe = nil
        let previous = lastFullTunnelProbe.flatMap { $0.key == target.key ? $0.result : nil }
        lastFullTunnelProbe = (target.key, result, Date())
        let wasUp = previous?.answered ?? false
        guard result.answered != wasUp else { return }
        if result.answered {
            log("Tunnel: the full-tunnel VPN on \(target.interface) loops \(target.deviceIP) back (probe \(result)).")
        }
        refreshNetworkStatus()
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
        mayBeInstalled(scheme: Self.localDevVPNScheme)
    }

    /// Time of the last handover, so a second caller waits for it instead of
    /// opening LocalDevVPN again.
    @ObservationIgnored private var lastVPNStartAttempt: Date?

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

    /// True when something that needs the tunnel starts it itself, so
    /// the UI needn't ask for the tunnel first. The built-in tunnel is
    /// tried first; LocalDevVPN is only the fallback.
    var startsVPNWhenNeeded: Bool { autoStartVPN }

    /// True when the tunnel is up, or will be started by what needs it.
    /// The built-in tunnel counts: it's part of the app itself, so it can
    /// always be started — the auto-start setting only governs jumping
    /// over to the separate LocalDevVPN app.
    var tunnelAvailable: Bool { vpnConnected || startsVPNWhenNeeded || BuiltinTunnel.useBuiltinDirectly }

    /// 隧道租约（SIDE-2，2026-11-21 用户亲令“隧道别一直打开了，需要时候才打开”）：
    /// 以前隧道只进不出——安装页预连、断线重连、操作入口都拉，收尾/后台/闲置从不
    /// 停。现在需要设备链路的操作开始时 acquire、结束时 release；持有归零后闲置
    /// 60 秒只停内置隧道。LocalDevVPN 的隧道是另一个 App 的，本 App 停不掉，
    /// 只能做到“不主动拉起”。定位模拟是长时持有者，另有 tunnelLocationHold
    /// 单独记一次（setup 与 stop/sessionClosed 两路结束，防重复释放）。
    /// 持有计数与闲置计时只在主线程碰（acquire/release 都是 @MainActor）。
    @ObservationIgnored var tunnelHolders = 0
    @ObservationIgnored private var tunnelIdleTimer: Timer?
    /// Pill 手动开的持有：用户亲手开的隧道不参与闲置停，只由 pill 关释放。
    @ObservationIgnored var tunnelManualHold = false
    /// 定位模拟会话的持有：prepare 成功置真，stop / sessionClosed 任一结束路清掉。
    @ObservationIgnored private var tunnelLocationHold = false

    /// 操作开始前调用：先记一次持有，再拉隧道（tunnelUp 幂等）。隧道起不来时
    /// 把持有还回去，返回 false，调用方按现有失败路径处理。
    @MainActor func acquireTunnel() async -> Bool {
        tunnelIdleTimer?.invalidate(); tunnelIdleTimer = nil
        tunnelHolders += 1
        guard await tunnelUp() else {
            tunnelHolders = max(0, tunnelHolders - 1)
            return false
        }
        return true
    }

    /// 操作结束后调用：持有归零时启动闲置计时，到时只停内置隧道。
    @MainActor func releaseTunnel() {
        tunnelHolders = max(0, tunnelHolders - 1)
        guard tunnelHolders == 0 else { return }
        scheduleTunnelIdleStop()
    }

    /// 闲置停计时：持有为零且内置隧道可用时才设 60 秒定时；到时二次核对三路
    /// 长时持有（在跑安装 / 在跑续签 / 定位模拟中），任一成立就不停。
    @MainActor private func scheduleTunnelIdleStop() {
        tunnelIdleTimer?.invalidate(); tunnelIdleTimer = nil
        guard tunnelHolders == 0, BuiltinTunnel.useBuiltinDirectly else { return }
        tunnelIdleTimer = Timer(timeInterval: 60, repeats: false) { _ in
            Task { @MainActor in
                guard Engine.shared.tunnelHolders == 0,
                      !Engine.shared.isRunning,
                      !SideloadedAppsManager.shared.isRefreshing,
                      !Engine.shared.connection.isSimulatingLocation else { return }
                await BuiltinTunnel.stop()
                Engine.shared.refreshNetworkStatus()
            }
        }
        RunLoop.main.add(tunnelIdleTimer!, forMode: .common)
    }

    /// 取消闲置停计时（pill 手动关时用；停隧道本身由调用方做）。
    @MainActor func cancelTunnelIdleStop() {
        tunnelIdleTimer?.invalidate(); tunnelIdleTimer = nil
    }

    /// 定位模拟会话结束时释放它那一次持有；没持有时空操作，防两路结束重复放。
    @MainActor func releaseLocationTunnelHold() {
        guard tunnelLocationHold else { return }
        tunnelLocationHold = false
        releaseTunnel()
    }

    /// False when Device IP is one of this iPhone's own addresses, which iOS
    /// won't let an app connect to (EPERM). LocalDevVPN shows one on its main
    /// screen: “Connected to 10.7.1.1/32” is its own end of the tunnel, while
    /// the address to connect to is the 10.7.0.1 under its Settings › Device
    /// IP. When the tunnel carries the default address, Device IP goes back to
    /// it instead. Only tells anything while the tunnel is up.
    /// (Upstream 2.2.0 `deviceIPIsUsable`, restored 0.9.140: the four
    /// Device-IP checkpoints call it first, so a stale own-address
    /// silently falls back to the default instead of blocking the run.
    /// Plain, not @MainActor: `Engine` here is @Observable with
    /// non-isolated `log`/`deviceIP`, and two of the four call sites are
    /// non-isolated too — all four run on the main thread from UI actions.)
    func deviceIPIsUsable() -> Bool {
        let host = deviceHost
        guard NetworkStatus.isOwnAddress(host) else { return true }
        let fallback = Self.defaultDeviceIP
        if host != fallback, !NetworkStatus.isOwnAddress(fallback),
           NetworkStatus.loopbackTunnelUp(deviceIP: fallback) {
            log("Device IP \(host) is one of this iPhone's own addresses (LocalDevVPN's “Connected to” address is its own end of the tunnel), and iOS won't let an app connect to those. Using \(fallback), the address the tunnel carries.")
            deviceIP = fallback
            return true
        }
        log("⛔️ Device IP \(host) is an address this iPhone already holds — that's the tunnel's own end, not the one to connect to. Check Settings › Advanced › Device IP (the default is \(fallback)).")
        return false
    }

    /// Makes sure the tunnel is up for something about to use it. Starts
    /// Side+'s built-in tunnel first — that part is not gated by the
    /// “Start LocalDevVPN when needed” setting; only if the built-in fails
    /// and that setting is on does it hand over to LocalDevVPN and wait
    /// for the tunnel once SideInstaller is back. Returns whether it's up.
    @MainActor
    func tunnelUp() async -> Bool {
        // A full-tunnel VPN that loops Device IP back is already the tunnel, so
        // its probe answers before LocalDevVPN is opened over it.
        await settleNetworkStatus()
        // 内置隧道不受自动启动开关限制：它是 App 自带的一部分。
        // 那个开关只管内置起不来时要不要自动跳去打开独立装的 LOC。
        guard !vpnConnected, startsVPNWhenNeeded || BuiltinTunnel.useBuiltinDirectly else {
            // 隧道已经通着、又没人持有：补一次闲置停计时（不走租约的裸 tunnelUp
            // 调用方，如安装页“修复隧道”按钮，靠这句兜底，不会一直开着）。
            if vpnConnected { scheduleTunnelIdleStop() }
            return vpnConnected
        }
        // Built-in tunnel first: no app switch, no dependency on a
        // separately installed LocalDevVPN.
        if await BuiltinTunnel.startAndWait() {
            refreshNetworkStatus()
            if vpnConnected {
                log("Tunnel up (built-in).")
                scheduleTunnelIdleStop()
                return true
            }
        }
        // Built-in didn't come up (e.g. the network-extension entitlement
        // didn't survive signing) — fall back to LocalDevVPN if it's there
        // and the user left automatic start on.
        guard startsVPNWhenNeeded, localDevVPNInstalled else { return false }
        // A handover a moment ago is still under way: wait for it, don't
        // open LocalDevVPN again.
        let handingOver = lastVPNStartAttempt.map { Date().timeIntervalSince($0) < 5 } ?? false
        guard handingOver || startLocalDevVPN() else { return false }
        // Only time back in SideInstaller counts, so a while spent in
        // LocalDevVPN (its VPN permission prompt, say) doesn't use up the wait.
        // S10：绝对上限——后台时 waited 永不涨，循环不能只靠它退出；
        // 墙钟 30 秒或 60 次迭代先到为准，到时返回 false。
        let waitStartedAt = Date()
        var waited = 0.0
        var waitIterations = 0
        while waited < 15 && waitIterations < 60 && Date().timeIntervalSince(waitStartedAt) < 30 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return false }
            waitIterations += 1
            refreshNetworkStatus()
            if vpnConnected {
                log("Tunnel up.")
                scheduleTunnelIdleStop()
                return true
            }
            if UIApplication.shared.applicationState == .active { waited += 0.5 }
        }
        log("⚠️ LocalDevVPN didn't connect its tunnel.")
        return false
    }

    /// Start the RPPairing host; it reports back through the shared engine.
    func generatePairingFile() {
        Task { @MainActor in PairingController.shared.start() }
    }

    func connectAndReadDeviceInfo() {
        Task { @MainActor in
            // SIDE-2：隧道按需开——单步连接自己拿租约；connect() 本身不拉隧道。
            var tunnelAcquired = false
            defer { if tunnelAcquired { releaseTunnel() } }
            do {
                guard await acquireTunnel() else {
                    throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                        ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                        : L("LocalDevVPN isn't connected. Connect it, then try again."))
                }
                tunnelAcquired = true
                try await connect()
            } catch { log("Connect FAILED: \(short(error))") }
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

    /// True when what was installed is Madeira: picked as such, or imported as
    /// a custom IPA, which only the signed bundle id (Madeira's, with the team
    /// id appended) can tell.
    private func signedAppIsMadeira(_ source: InstallSource) -> Bool {
        if source == .madeira { return true }
        guard source == .custom, let signed = signedAppBundleID() else { return false }
        return MadeiraPairingHandoff.isMadeira(bundleID: signed)
    }

    /// True when the signed Madeira takes in the sign-in it renews its own
    /// signing with: its Info.plist says which version of the hand-over it reads.
    private func signedMadeiraRenewsItself() -> Bool {
        (signedAppPlist()?[MadeiraSigningHandoff.infoKey] as? Int ?? 0) >= MadeiraSigningHandoff.version
    }

    /// The signed app's home-screen name; an app carries only one of the two.
    private func signedAppName() -> String? {
        guard let plist = signedAppPlist() else { return nil }
        return (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String)
    }

    /// The signed app's own version, for the install history; nil when the
    /// signed app has no readable plist or no version in it.
    private func signedAppVersion() -> String? {
        guard let plist = signedAppPlist() else { return nil }
        return plist["CFBundleShortVersionString"] as? String
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
    /// idevicepair, …), replacing the one on disk. Required below iOS 27;
    /// optional (under Advanced) from 27 on.
    @MainActor
    func importPairingFile(from url: URL) async {
        // B4：安装进行中不换配对文件——connection.disconnect() 会断掉在途
        // 安装的设备链路。深链弹窗确认路也走这里，同一处拦住。
        guard !isRunning else {
            lastError = L("An install is already running. Wait for it to finish, then try again.")
            log("⛔️ Pairing import: \(lastError ?? "")")
            return
        }
        // B-38-B2：续签进行中不换配对文件——成功路调 connection.disconnect()
        // 会断掉在途续签的设备链路。
        guard !SideloadedAppsManager.shared.isRefreshing else {
            lastError = L("A refresh is already running. Wait for it to finish, then try again.")
            log("⛔️ Pairing import: \(lastError ?? "")")
            return
        }
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
            if let fileUDID = kind.udid, let currentUDID = deviceUDID, fileUDID != currentUDID {
                let mismatch = PairingImportMismatch(fileUDID: fileUDID, deviceUDID: currentUDID)
                guard await confirmPairingImportMismatch(mismatch) else {
                    log("Pairing import: kept the current pairing file (UDID mismatch).")
                    return
                }
            }
            try data.write(to: PrivateStore.pairingFile, options: .atomic)
            // Drop the cached merged file; it was built from the old record.
            CompositePairingFile.invalidateMerged()
            pairingFilePath = PrivateStore.pairingFile.path
            importedPairingName = url.lastPathComponent
            UserDefaults.standard.set(url.lastPathComponent, forKey: Engine.importedPairingNameKey)
            connection.disconnect()
            deviceSummary = nil
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

    /// Imports a pairing file a Shortcuts action was handed, as the picker's
    /// import does, throwing what the picker would show.
    @MainActor
    func importPairingFile(data: Data, name: String) throws {
        guard !isRunning else {
            throw EngineError.message(L("An install is already running. Wait for it to finish, then try again."))
        }
        let kind = PairingFileKind.of(data: data)
        guard data.count <= 1 << 20, kind.isUsable else {
            throw EngineError.message(ErrorHelp.explained(L("%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.",
                                                            name)))
        }
        log("Importing pairing file \(name) from Shortcuts …")
        try adoptPairingFile(data, kind: kind, name: name)
    }

    /// Makes a checked pairing file the one in use, replacing the one on disk,
    /// and shows it under `name` as the imported file.
    @MainActor
    private func adoptPairingFile(_ data: Data, kind: PairingFileKind, name: String) throws {
        try data.write(to: PrivateStore.pairingFile, options: .atomic)
        // Drop the cached merged file; it was built from the old record.
        CompositePairingFile.invalidateMerged()
        pairingFilePath = PrivateStore.pairingFile.path
        importedPairingName = name
        UserDefaults.standard.set(name, forKey: Engine.importedPairingNameKey)
        connection.disconnect()
        deviceSummary = nil
        setGuide(nil)
        let records = [kind.hasLockdown ? "lockdown" : nil,
                       kind.hasRemotePairing ? "remote-pairing" : nil]
            .compactMap { $0 }.joined(separator: " + ")
        log("Imported \(name) (\(data.count) bytes, \(records) record\(records.contains("+") ? "s" : "")\(kind.udid.map { ", UDID \($0)" } ?? "")).")
        if Self.lockdownWorksOverLoopback {
            if !kind.hasLockdown {
                log("⚠️ No lockdown record in that file — SideStore and Feather can't read it, though the install itself will work.")
            }
        } else if !kind.hasRemotePairing {
            // Nothing stops the import: the connect explains it with advice.
            log(Self.deviceCanSelfPair
                ? "⚠️ That file holds only a lockdown record, and from iOS 26.4 on lockdownd hangs up on those through LocalDevVPN. Install pairs this iPhone with itself instead."
                : "⚠️ That file holds only a lockdown record, and from iOS 26.4 on lockdownd hangs up on those through LocalDevVPN, so it won't connect. Make a remote pairing file instead: idevice_pair › Remote pairing › Create › Save to file…, or iLoader's exported file.")
        }
    }

    // MARK: - Links
    //
    // `sideinstaller://install?url=`, `sideinstaller://pairingFile?data=` and
    // `sideinstaller://certificate?data=` (see `DeepLink`). Each puts up a popup
    // first; only its yes acts. SideStore's certificate, sent back because
    // SideInstaller asked for it, is the exception: SideStore has just asked
    // whether to export it.

    /// How long after asking SideStore a pairing file counts as its reply.
    private static let sideStoreReplyWindow: TimeInterval = 5 * 60

    /// Reads a `sideinstaller://` link and puts up its popup. Nothing is
    /// downloaded or imported yet.
    @MainActor
    func receiveLink(_ url: URL) {
        let answersSideStore = sideStorePairingRequestedAt
            .map { Date().timeIntervalSince($0) < Self.sideStoreReplyWindow } ?? false
        let answersCertificateRequest = sideStoreCertificateRequest
            .map { Date().timeIntervalSince($0.at) < Self.sideStoreReplyWindow } ?? false
        switch DeepLink.parse(url, answersSideStore: answersSideStore,
                              answersCertificateRequest: answersCertificateRequest) {
        case .ignored(let action):
            // LocalDevVPN comes back with a bare `sideinstaller://`.
            if let action { log("Ignored a sideinstaller://\(action) link: this version has no such action.") }
        case .invalid(let message):
            log("⛔️ Link: \(message)")
            // A run's own popups come first; the log keeps the reason.
            if isRunning {
                // B1 (0.9.152): parked until the run ends, then shown with
                // the finished popups — it used to vanish into the log.
                pendingInvalidLinkMessage = message
                log("Link: it asks once this install ends.")
            } else {
                lastError = message
            }
        case .link(let link):
            if case .pairingFile = link { sideStorePairingRequestedAt = nil }
            if case .certificate(let cert) = link, cert.fromSideStore {
                let retryInstall = sideStoreCertificateRequest?.retryInstall ?? false
                sideStoreCertificateRequest = nil
                log("Link: \(link.logDescription).")
                certificateToImport = CertificateImport(certificate: cert, retryInstall: retryInstall)
                return
            }
            if let old = pendingLink {
                // B1 (0.9.152): one slot only — a second link used to
                // silently drop the first; the log now says so.
                log("Link: \(old.logDescription) was still waiting — superseded by \(link.logDescription).")
            }
            pendingLink = link
            log("Link: \(link.logDescription). \(isRunning ? "It asks once this install ends." : "Waiting for the go-ahead.")")
        }
    }

    /// Answers the link popup: true downloads and installs the IPA, or imports
    /// the pairing file; false drops the link.
    @MainActor
    func answerLink(_ accept: Bool) {
        guard let link = pendingLink else { return }
        pendingLink = nil
        guard accept else {
            log("Link dismissed.")
            return
        }
        lastError = nil
        switch link {
        case .install(let url):
            Task {
                // C12：只凭这次导入的返回值起管线——进行中被跳过时
                // importCustomIPA 已置 lastError，旧 IPA 不会再被
                // 当成新导入的装掉。
                if await importCustomIPA(fromLink: url.absoluteString),
                   IPALibrary.customImport() != nil {
                    // B-39-B2：源赋值移到导入成功之后——导入被拒时
                    // 在途管线读到的仍是旧源，不会被改装 custom 槽里的旧 IPA。
                    installSource = .custom
                    runOneClick()
                }
            }
        case .pairingFile(let file):
            do {
                try adoptPairingFile(file.data, kind: file.kind, name: file.displayName)
            } catch {
                lastError = L("Couldn't import %@: %@", file.displayName, error.localizedDescription)
                log("⛔️ Pairing import: \(lastError ?? "")")
            }
        case .certificate(let cert):
            certificateToImport = CertificateImport(certificate: cert, retryInstall: false)
        }
    }

    /// Downloads the IPA at `url` as the custom build, then installs it signed
    /// with the Apple ID's certificate. Used by `sideinstaller://install` links
    /// and the update banner.
    @MainActor
    func installLinkedIPA(_ url: URL) {
        guard !isRunning, !isImportingIPA else { return }
        lastError = nil
        installSource = .custom
        Task { @MainActor in
            // Installs only what the link brought: a failed download leaves
            // its error up instead of installing the previous import.
            guard await self.importCustomIPA(fromLink: url.absoluteString) else { return }
            self.runOneClick()
        }
    }

    // MARK: - App presence & SideStore pairing helpers

    /// True unless SideStore is known to be missing (see `appPresence`).
    /// Opening it reports when it isn't there.
    var sideStoreInstalled: Bool {
        mayBeInstalled(scheme: "sidestore")
    }

    /// True when “Use SideStore's certificate” has somewhere to get it: SideStore
    /// is on this iPhone, or SideInstaller runs inside LiveContainer, which
    /// keeps SideStore's certificate itself (`LiveContainerCertificate`).
    var canUseSideStoreCertificate: Bool {
        Self.runsInLiveContainer || sideStoreInstalled
    }

    /// Bumped each time SideInstaller comes back to the front. Apps installed
    /// or deleted meanwhile aren't observed, so what looks them up reads this
    /// first, and the views showing it redraw then.
    private(set) var foregroundVisits = 0

    /// True unless the app opening `scheme://` links is known to be missing,
    /// read again each time SideInstaller is back in front.
    private func mayBeInstalled(scheme: String) -> Bool {
        _ = foregroundVisits
        return Self.appPresence(scheme: scheme) != .missing
    }

    // Is another app installed?
    //
    // `canOpenURL` only answers for the schemes listed under
    // `LSApplicationQueriesSchemes` in the Info.plist of the app this process
    // really is, and says false for every other one. Inside LiveContainer
    // that's LiveContainer's Info.plist, not ours, the same trap as the Bonjour
    // types in issue #38. It lists sidestore and livecontainer but not
    // localdevvpn, so there LocalDevVPN always read as missing (issue #69).

    enum AppPresence { case installed, missing, unknown }

    /// Whether an app that opens `scheme://` links is installed, as far as
    /// `canOpenURL` can tell. `.unknown` when it isn't allowed to ask.
    static func appPresence(scheme: String) -> AppPresence {
        guard let url = URL(string: "\(scheme)://") else { return .unknown }
        if UIApplication.shared.canOpenURL(url) { return .installed }
        return queryableSchemes?.contains(scheme.lowercased()) == true ? .missing : .unknown
    }

    /// The schemes `canOpenURL` answers for, or nil when they can't be read.
    /// LiveContainer swaps `Bundle.main` for the guest's bundle and keeps its
    /// own as `UserDefaults.lcMainBundle`.
    private static let queryableSchemes: Set<String>? = {
        let host: Bundle
        if getenv("LC_HOME_PATH") == nil {
            host = .main
        } else if let liveContainer = liveContainerBundle() {
            host = liveContainer
        } else {
            return nil
        }
        let schemes = host.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] ?? []
        return Set(schemes.map { $0.lowercased() })
    }()

    /// LiveContainer's name on the Home Screen, which the Files app gives its
    /// folder too; nil outside LiveContainer.
    static var liveContainerName: String? {
        guard runsInLiveContainer, let bundle = liveContainerBundle() else { return nil }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }

    /// LiveContainer's own bundle, from the `+[NSUserDefaults lcMainBundle]`
    /// it adds for the guest app.
    private static func liveContainerBundle() -> Bundle? {
        let selector = NSSelectorFromString("lcMainBundle")
        let defaults = UserDefaults.self as AnyObject
        guard defaults.responds(to: selector) else { return nil }
        return defaults.perform(selector)?.takeUnretainedValue() as? Bundle
    }

    /// True when “Get it from SideStore” has somewhere to get the pairing file:
    /// SideStore is on this iPhone, or, inside LiveContainer, LiveContainer
    /// carries the built-in SideStore whose file is read instead. A SideStore
    /// installed on its own can't hand its file to a LiveContainer guest.
    var canGetSideStorePairing: Bool {
        _ = foregroundVisits
        return Self.runsInLiveContainer
            ? LiveContainerSideStorePairing.hasBuiltInSideStore != false
            : sideStoreInstalled
    }

    /// Opens SideStore, which sends back the pairing file it has as a
    /// `sideinstaller://pairingFile` link. That link asks before importing.
    /// Inside LiveContainer, which the link can't reach, the pairing file the
    /// built-in SideStore keeps is read instead, and the same popup asks.
    @MainActor
    func requestSideStorePairing() {
        if Self.runsInLiveContainer {
            offerBuiltInSideStorePairing()
            return
        }
        guard let url = URL(string: "sidestore://pairing?urlname=\(DeepLink.scheme)") else { return }
        lastError = nil
        sideStorePairingRequestedAt = Date()
        log("Asking SideStore for its pairing file …")
        UIApplication.shared.open(url) { opened in
            Task { @MainActor in
                guard !opened else { return }
                self.sideStorePairingRequestedAt = nil
                self.lastError = ErrorHelp.explained(L("SideStore isn't installed on this iPhone, so there's no pairing file to get from it."))
                self.log("⛔️ Pairing import: \(self.lastError ?? "")")
            }
        }
    }

    /// Puts up the link popup with the pairing file LiveContainer's built-in
    /// SideStore keeps (see `LiveContainerSideStorePairing`), or says what to
    /// do when there's none to be had.
    @MainActor
    private func offerBuiltInSideStorePairing() {
        lastError = nil
        log("Pairing import: inside LiveContainer, SideStore can't send its pairing file back, so SideInstaller reads the one LiveContainer's built-in SideStore keeps.")
        switch LiveContainerSideStorePairing.find(log: { self.log($0) }) {
        case let .found(file, from: names):
            let link = DeepLink.pairingFile(file)
            pendingLink = link
            log("Pairing import: \(link.logDescription), from \(names.joined(separator: " + ")). Waiting for the go-ahead.")
        case .unreachable:
            lastError = ErrorHelp.explained(L("In LiveContainer's Multitask Mode, SideInstaller can't open the built-in SideStore's files. Open SideInstaller in LiveContainer without Multitask Mode, then try again, or tap “Import pairing file” and pick the file your computer made."))
            log("⛔️ Pairing import: \(lastError ?? "")")
        case .notFound:
            lastError = ErrorHelp.explained(L("Inside LiveContainer, SideStore can't send its pairing file back to SideInstaller, and LiveContainer's built-in SideStore has none that SideInstaller can use. Tap “Import pairing file” and pick the file your computer made, or import one into SideStore first, then try again here."))
            log("⛔️ Pairing import: \(lastError ?? "")")
        }
    }

    /// Opens SideStore, which asks whether to export its certificate and sends
    /// it back as a `sideinstaller://certificate` link. `retryInstall` runs the
    /// install again once the certificate is in. Calls `failed` when SideStore
    /// can't be opened.
    @MainActor
    func requestSideStoreCertificate(retryInstall: Bool, failed: @escaping @MainActor () -> Void) {
        // SideStore takes the template percent-decoded, so all of it is encoded.
        let template = DeepLink.certificateCallbackTemplate
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        guard let url = URL(string: "sidestore://certificate?callback_template=\(template)") else { return }
        sideStoreCertificateRequest = (Date(), retryInstall)
        log("Asking SideStore for its certificate …")
        UIApplication.shared.open(url) { opened in
            Task { @MainActor in
                guard !opened else { return }
                self.sideStoreCertificateRequest = nil
                failed()
            }
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
        // SIDE-2：隧道按需开——单次配对操作自己拿租约、defer 还。
        var tunnelAcquired = false
        defer { if tunnelAcquired { releaseTunnel() } }
        guard await acquireTunnel() else {
            throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                : L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        tunnelAcquired = true
        try await ensurePairingConnection()
        let apps = try await onDeviceQueue { try self.connection.installedApps() }
        let targets = PairingTargets.match(installed: apps)
        log("Pairing: \(targets.count) supported app(s) installed\(targets.isEmpty ? "." : ": \(targets.map(\.name).joined(separator: ", "))")")
        return targets
    }

    /// F-1 (0.9.161): uninstall the app with this bundle ID, via
    /// installation_proxy. The running app can't uninstall itself —
    /// installd would kill SideInstaller mid-call — so that is refused
    /// here, not left to the swipe button that offered it.
    @MainActor
    func uninstallApp(bundleID: String) async throws {
        guard bundleID != Bundle.main.bundleIdentifier else {
            throw EngineError.message(L("SideInstaller can't uninstall itself."))
        }
        // SIDE-2：隧道按需开——同 installedPairingTargets。
        var tunnelAcquired = false
        defer { if tunnelAcquired { releaseTunnel() } }
        guard await acquireTunnel() else {
            throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                : L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        tunnelAcquired = true
        try await ensurePairingConnection()
        try await onDeviceQueue { try self.connection.uninstallApp(bundleID: bundleID) }
        log("Uninstalled \(bundleID).")
    }

    /// Write the current pairing file into one installed target app's container.
    @MainActor
    func installPairing(into target: InstalledPairingTarget) async throws {
        // SIDE-2：隧道按需开——同 installedPairingTargets。
        var tunnelAcquired = false
        defer { if tunnelAcquired { releaseTunnel() } }
        guard await acquireTunnel() else {
            throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                : L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        tunnelAcquired = true
        try await ensurePairingConnection()
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        let udid = deviceUDID
        try await onDeviceQueue {
            let placement = try self.resolvePlacement(rpPairingPath: path, udid: udid)
            try self.performInstallPairing(target: target, placementPath: placement, udid: udid)
        }
    }

    /// Write the pairing file into every scanned target, as iLoader's
    /// "Place In All Apps" does. Connects once, then writes each in turn.
    @MainActor
    func installPairing(intoAll targets: [InstalledPairingTarget]) async throws {
        // SIDE-2：隧道按需开——同 installedPairingTargets（整批写完才还）。
        var tunnelAcquired = false
        defer { if tunnelAcquired { releaseTunnel() } }
        guard await acquireTunnel() else {
            throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                : L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        tunnelAcquired = true
        try await ensurePairingConnection()
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        let udid = deviceUDID
        // Resolved once for the whole run: minting the lockdown record can ask
        // the user to tap Trust, and every app is handed the same file anyway.
        let placement = try await onDeviceQueue {
            try self.resolvePlacement(rpPairingPath: path, udid: udid)
        }
        var failures: [String] = []
        var succeeded: [String] = []
        for target in targets {
            do {
                try await onDeviceQueue {
                    try self.performInstallPairing(target: target, placementPath: placement, udid: udid)
                }
                succeeded.append(target.name)
            } catch {
                // One app refusing the write shouldn't cost the rest.
                log("⚠️ Couldn't write into \(target.name) (\(short(error))).")
                failures.append(target.name)
            }
        }
        guard failures.isEmpty else {
            // B7 (0.9.161): a partial write used to report only the failures —
            // the apps that did get the file were invisible, so a user
            // couldn't tell a partial success from a total one. Say both.
            if succeeded.isEmpty {
                throw EngineError.message(L("Couldn't write into %@.", failures.joined(separator: ", ")))
            }
            throw EngineError.message(L("Pairing file installed into %@, but couldn't be written into %@.",
                                        succeeded.joined(separator: ", "),
                                        failures.joined(separator: ", ")))
        }
    }

    /// Bring up the device link for a standalone pairing operation, always with
    /// a fresh tunnel: `isConnected` still reads true after iOS tears one down.
    @MainActor
    private func ensurePairingConnection() async throws {
        // No Wi-Fi check: this all runs over the loopback tunnel.
        guard await tunnelUp() else {
            throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                : L("LocalDevVPN isn't connected. Connect it, then try again."))
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
    }

    /// Write the resolved pairing file into `target`'s Documents, verifying
    /// the read-back.
    private func performInstallPairing(target: InstalledPairingTarget, placementPath: String,
                                       udid: String?) throws {
        guard connection.isConnected else { throw EngineError.message(L("Device link dropped — reconnect.")) }
        let bundleID = target.bundleID
        if target.app.takesRemoteRecordOnly {
            let handed = try target.name == ARMSX3PairingHandoff.appName
                ? handOffARMSX3Pairing(placementPath: placementPath, bundleID: bundleID)
                : handOffMadeiraPairing(placementPath: placementPath, bundleID: bundleID)
            guard handed else {
                throw EngineError.message(L("This pairing file has no RPPairing record, the only kind %@ reads.", target.name))
            }
            return
        }
        log("Writing pairing file into \(bundleID) /Documents/\(target.remoteRelativePath) …")
        let written = try connection.writePairingFile(intoBundleID: bundleID,
                                                       remoteRelativePath: target.remoteRelativePath,
                                                       pairingFilePath: placementPath)
        log("Pairing file written into \(bundleID) and read-back VERIFIED (\(written) bytes).")
        if let home = target.app.sideStoreHome {
            handOffSplitPairing(placementPath: placementPath, bundleID: bundleID,
                                appName: target.name, home: home, udid: udid)
            // iOS caches an app's settings once it has run and ignores the
            // edited file until the app is reinstalled or the iPhone restarts.
            log("If \(target.name) has been opened since it was installed, it picks up these settings once it's reinstalled or this iPhone restarts.")
        }
    }

    /// Hands the pairing to SideStore the way nightly 0.7.0-20260920 and later
    /// read it (see `SideStorePairingHandoff`): one file per protocol, plus the
    /// two settings its own import writes. Older builds read `ALTPairingFile`,
    /// written just before, so failures here log and leave a notice (C25). Runs on `deviceQueue`.
    private func handOffSplitPairing(placementPath: String, bundleID: String,
                                     appName: String, home: SideStoreHome, udid: String?) {
        do {
            let records = try SideStorePairingHandoff.split(
                Data(contentsOf: URL(fileURLWithPath: placementPath)), udid: udid)
            if !records.missingLockdownKeys.isEmpty {
                log("⚠️ The lockdown record lacks \(records.missingLockdownKeys.joined(separator: ", ")), which newer SideStore builds require — leaving it out of their files.")
            }
            guard let active = records.activeProtocol else {
                log("⚠️ Nothing in the pairing file that newer \(appName) builds can load.")
                return
            }
            for (name, data) in [(SideStorePairingHandoff.lockdownFileName, records.lockdown),
                                 (SideStorePairingHandoff.remoteFileName, records.remote)] {
                guard let data else { continue }
                let rel = home.documentsPrefix + name
                let written = try connection.writeFile(intoBundleID: bundleID,
                                                       remoteRelativePath: rel, data: data)
                log("Wrote /Documents/\(rel) into \(appName) (\(written) bytes, read-back VERIFIED).")
            }
            let prefsPath = home.preferencesPath(hostBundleID: bundleID)
            try connection.updatePlist(inBundleID: bundleID, containerPath: prefsPath) { prefs in
                SideStorePairingHandoff.applySettings(to: &prefs, activeProtocol: active)
            }
            log("Set \(appName) to load its \(active) pairing file (/\(prefsPath)), as its own import does.")
        } catch {
            // C25：只记日志不够——对方日后遇到要配对文件时，这边没有
            // 任何提示能把两件事连起来；进度卡下方留一句（run 照常成功）。
            // 照抄 C23（SideBySideView:1796-1799），复用同一条 key。
            Task { @MainActor in
                self.handOffNotice = [self.handOffNotice, L("The pairing wasn't handed over in the newer format. SideStore may ask for the pairing file.")].compactMap { $0 }.joined(separator: "\n")
            }
            log("⚠️ Couldn't hand \(appName) its pairing in the newer format (\(short(error))). SideStore nightlies from 20 September 2026 on may ask for the pairing file; older builds are set.")
        }
    }

    /// Sets SideStore up to sign in the way its users got past Apple's -80046
    /// and HTTP 503s (`SideStoreAnisetteHandoff`). After the install, as
    /// `handOffSplitPairing`; failures only log. Runs on `deviceQueue`.
    private func handOffSideStoreAnisette(bundleID: String, appName: String, home: SideStoreHome) {
        let prefsPath = home.preferencesPath(hostBundleID: bundleID)
        do {
            var changes: [String] = []
            try connection.updatePlist(inBundleID: bundleID, containerPath: prefsPath) { prefs in
                changes = SideStoreAnisetteHandoff.applySettings(to: &prefs)
            }
            guard !changes.isEmpty else { return }
            log("Set \(appName)'s anisette the way SideStore's users get past Apple's -80046 and HTTP 503s: \(changes.joined(separator: ", ")) (/\(prefsPath)).")
            // -22410 after a change of client info, until the identity is made
            // again; unticking would put back the default, which gets 503s.
            log("If \(appName)'s own sign-in still fails (-22410, -45061), use its Settings › User Customizations › Reset adi.pb, with “Keep header customizations” ticked, then sign in again.")
        } catch {
            log("⚠️ Couldn't set \(appName)'s anisette settings (\(short(error))). If its sign-in fails with -80046 or HTTP 503, turn off On-device Anisette and Auto Rotation in its settings, pick “SideStore (New)”, and set its client info to say “Mac OS X” where it says “macOS”.")
        }
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
        // SIDE-2：隧道按需开——同 installedPairingTargets。
        var tunnelAcquired = false
        defer { if tunnelAcquired { releaseTunnel() } }
        guard await acquireTunnel() else {
            throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                : L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        tunnelAcquired = true
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
        try await signIn(updatingChecklist: false, purpose: .refresh)
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
        let path = pairingFilePath ?? PairingController.pairingFilePath()
        // A21-2：defer 登记在 performSign 之前——签名失败时 defer 已登记、
        // signedPath 仍是 nil 不删；成功时才删。失败的解包目录由 Rust 自清；
        // catch 里的 discardExtraction(forIPA:) 只扫 24 小时以上的陈旧目录（此时还没有 bundle 路径）。
        var signedPath: String?
        defer { if let signedPath { Self.discardSignedBundle(at: signedPath) } }
        let signed: String
        do {
            signed = try await onSignQueue {
                try self.performSign(session: session, ipa: ipaPath, udid: udid, deviceName: device,
                                     pairingFilePath: path,
                                     forMadeira: Self.isMadeira(ipaPath: ipaPath))
            }
            signedPath = signed
        } catch {
            Self.discardExtraction(forIPA: ipaPath)
            // Don't set `certConflict`: its retry button starts a full install
            // from the Install tab. Point to the Certificates page instead.
            if case EngineError.certExists = error {
                throw EngineError.message(L("Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Revoke it under Tools › Certificates, then refresh again."))
            }
            throw error
        }
        installProgress = 0
        let ip = deviceHost
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
    /// bundle per app, so each is removed right away to save space; the
    /// install pipelines call it from their shared tail for the same
    /// reason, and Side by Side calls it as `Engine.discardSignedBundle`
    /// (C20 — internal, not private, so the other file can reach it).
    static func discardSignedBundle(at path: String) {
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

    /// Removes extraction dirs a signing attempt left behind, but only
    /// stale ones: a signing never lives 24 hours, so anything older
    /// cannot belong to a live signing. Fresh dirs are left alone —
    /// with unique names (B-50-B1) Swift can no longer tell which fresh
    /// dir belongs to the failed attempt, and deleting it could kill a
    /// concurrent live signing of the same-named IPA.
    static func discardExtraction(forIPA ipaPath: String) {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL
        let name = URL(fileURLWithPath: ipaPath).lastPathComponent
        guard !name.isEmpty else { return }
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(
            at: temp, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey])) ?? []
        for entry in entries {
            guard entry.lastPathComponent.hasPrefix(name + "_"),
                  entry.lastPathComponent.hasSuffix("_extracted") else { continue }
            guard let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true,
                  let mtime = values.contentModificationDate,
                  Date().timeIntervalSince(mtime) > 24 * 3600 else { continue }
            try? fm.removeItem(at: entry)
        }
    }

    // MARK: - Location tab
    //
    // Location simulation is a DVT service. It needs a mounted developer disk
    // image and a session kept open while the location is simulated. Same
    // approach as StikDebug, over the RPPairing tunnel.

    /// Connect, mount the developer disk image unless the device already has
    /// one, and open the location session. Returns true when a mount actually
    /// ran, so the UI can say so.
    @MainActor
    @discardableResult
    func prepareLocationSimulation(imagePath: String,
                                   trustcachePath: String,
                                   manifestPath: String,
                                   progress: @escaping (Double) -> Void) async throws -> Bool {
        // SIDE-2：隧道按需开——会话开始拿租约，整个模拟期间持有；中途失败在
        // catch 里还掉，成功则由 stop / sessionClosed 释放（见 tunnelLocationHold）。
        guard await acquireTunnel() else {
            throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                : L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        tunnelLocationHold = true
        do {
            let mounted = try await prepareDeveloperDiskImage(imagePath: imagePath,
                                                          trustcachePath: trustcachePath,
                                                          manifestPath: manifestPath,
                                                          progress: progress)
            try await onDeviceQueue { try self.connection.beginLocationSimulation() }
            return mounted
        } catch {
            tunnelLocationHold = false
            releaseTunnel()
            throw error
        }
    }

    /// Connect, and mount the developer disk image unless the device already
    /// has one. Location simulation and JIT both need it: DVT and debugserver
    /// come with it. Returns true when a mount actually ran.
    @MainActor
    @discardableResult
    func prepareDeveloperDiskImage(imagePath: String,
                                   trustcachePath: String,
                                   manifestPath: String,
                                   progress: @escaping (Double) -> Void) async throws -> Bool {
        try await ensurePairingConnection()
        let mounted = try await onDeviceQueue { try self.connection.mountedDeveloperImageCount() }
        if mounted > 0 {
            log("Developer disk image already mounted (\(mounted) image(s)).")
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
        guard connection.isSimulatingLocation else {
            // 会话已在别处断掉：顺手回收可能残留的持有（没持有时空操作）。
            releaseLocationTunnelHold()
            return
        }
        // B-C3：clear 失败也不能漏了 end + 释放——以前 clear 一抛，
        // 后面的 endLocationSimulation() 与 releaseLocationTunnelHold()
        // 都不跑，隧道租约永久 +1、isSimulatingLocation 一直为真。
        // clear 失败只记日志继续走：设备位置按注释会自行失效，
        // 本地会话关了、重发停了，目标（停止模拟）已经达到。
        // defer 保证任何出口都释放持有（没持有时空操作）。
        defer { releaseLocationTunnelHold() }
        do {
            try await onDeviceQueue {
                try self.connection.clearSimulatedLocation()
            }
        } catch {
            log("⚠️ Couldn't clear the simulated location (\(short(error))); closing the session anyway.")
        }
        try await onDeviceQueue {
            self.connection.endLocationSimulation()
        }
        log("Simulated location cleared.")
    }

    // MARK: - JIT tab
    //
    // A JIT session runs over a tunnel of its own (`JITSession`), so only the
    // checks and the app list go through the shared connection.

    /// Every app installed on the device, as installation_proxy reports them
    /// (the JIT page keeps those that can be debugged). Opens the device link
    /// first.
    @MainActor
    func installedAppPlists() async throws -> [[String: Any]] {
        try await ensurePairingConnection()
        return try await onDeviceQueue { try self.connection.installedAppPlists() }
    }


    // MARK: - Developer Mode (Settings)
    //
    // AMFI can show Developer Mode in Settings, or turn it on. Both go over a
    // link to this iPhone that already works, so on iOS 27, where the link
    // itself needs Developer Mode, they can't bring a missing option back.

    /// What a Developer Mode request did.
    enum DeveloperModeOutcome {
        /// Developer Mode was already on, so nothing was sent.
        case alreadyOn
        /// The option now shows under Settings › Privacy & Security.
        case revealed
        /// Developer Mode is set to turn on, and the iPhone is restarting.
        case enabling
    }

    /// Opens the device link and sends `request` to AMFI, unless Developer Mode
    /// is already on. When the tunnel won't open (it may need Developer Mode
    /// itself), a classic pair record still reaches AMFI through lockdownd.
    @MainActor
    func requestDeveloperMode(_ request: DeviceConnection.DeveloperModeRequest) async throws -> DeveloperModeOutcome {
        guard !isRunning else {
            throw EngineError.message(L("An install is already running. Wait for it to finish, then try again."))
        }
        let outcome: DeveloperModeOutcome = request == .reveal ? .revealed : .enabling
        log("Developer Mode: \(request == .reveal ? "showing it in Settings" : "turning it on") …")
        // SIDE-2：隧道按需开——单次操作自己拿租约；回落到 lockdownd 直连那路
        // 也在租约内跑完，无非多持有一会儿，无害。
        var tunnelAcquired = false
        defer { if tunnelAcquired { releaseTunnel() } }
        guard await acquireTunnel() else {
            throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                : L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        tunnelAcquired = true
        do {
            try await ensurePairingConnection()
        } catch {
            // No VPN, no pairing file, a Device IP lockdownd can't be reached
            // on either, or an iOS (26.4+) whose lockdownd hangs up on the
            // loopback: nothing else to try.
            let path = pairingFilePath ?? PairingController.pairingFilePath()
            guard vpnConnected, PairingFileKind.of(path: path).hasLockdown,
                  !NetworkStatus.isOwnAddress(deviceHost),
                  Self.lockdownWorksOverLoopback else { throw error }
            log("Developer Mode: the tunnel didn't open (\(short(error))). Asking lockdownd directly …")
            let ip = deviceHost
            do {
                try await onDeviceQueue {
                    try self.connection.requestDeveloperModeOverLockdown(request, deviceIP: ip,
                                                                         pairingFilePath: path)
                }
            } catch {
                throw developerModeFailure(error)
            }
            logDeveloperMode(outcome)
            return outcome
        }

        // Turning it on restarts the iPhone, so never send that needlessly.
        let enabled: Bool?
        do {
            enabled = try await onDeviceQueue { try self.connection.developerModeEnabled() }
        } catch {
            log("Developer Mode: couldn't read whether it's on (\(short(error))). Sending the request anyway.")
            enabled = nil
        }
        if enabled == true {
            logDeveloperMode(.alreadyOn)
            return .alreadyOn
        }
        if enabled == false { log("Developer Mode is off.") }
        do {
            try await onDeviceQueue { try self.connection.requestDeveloperMode(request) }
        } catch {
            throw developerModeFailure(error)
        }
        logDeveloperMode(outcome)
        return outcome
    }

    private func logDeveloperMode(_ outcome: DeveloperModeOutcome) {
        switch outcome {
        case .alreadyOn: log("Developer Mode is already on.")
        case .revealed:  log("Developer Mode: the option now shows under Settings › Privacy & Security.")
        case .enabling:  log("Developer Mode: set to turn on. This iPhone restarts now.")
        }
    }

    /// A failed AMFI request in words. The passcode refusal has a known way
    /// round it; anything else is passed on as the device said it.
    private func developerModeFailure(_ error: Error) -> Error {
        let raw = String(describing: error)
        log("Developer Mode request failed: \(raw)")
        // AMFI answers {Error: "Device has a passcode set"}.
        if raw.localizedCaseInsensitiveContains("passcode") {
            return EngineError.message(L("iOS turns Developer Mode on from here only while this iPhone has no passcode. Tap “Show Developer Mode in Settings” and turn it on there instead."))
        }
        return EngineError.message(L("This iPhone didn't take the Developer Mode request: %@", error is DeviceConnection.FFIError ? L("the connection to this iPhone failed") : short(error)))
    }


    // MARK: The file other apps actually read

    /// Returns the path of the pairing file to write into other apps.
    ///
    /// SideInstaller pairs via RPPairing, but minimuxer (SideStore, LiveContainer)
    /// and Feather need a classic lockdown record. This creates one over the open
    /// tunnel and merges both records into one file, as iLoader does. On iOS 27
    /// lockdownd won't pair, so the RPPairing file goes alone.
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
            } else if !Self.canMintLockdownRecord {
                log("Handing over the RPPairing record on its own: iOS 27 doesn't let lockdown pair over the tunnel. StikDebug (sideloaded) and SideStore nightlies from 20 September 2026 on read it.")
                return rpPairingPath
            } else {
                log("Pairing with lockdown as well, so AltStore-family apps can read the file. Tap Trust if this iPhone asks, and unlock it if it's locked …")
                // A Trust prompt may appear: a 2FA sheet waits for it.
                attention.begin()
                defer { attention.end() }
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
            log("⚠️ Couldn't add the lockdown record to the pairing file (\(short(error))). Writing the RPPairing record on its own — StikDebug (sideloaded) and SideStore nightlies from 20 September 2026 on read that; older SideStore builds and Feather won't.")
            return rpPairingPath
        }
    }

    // MARK: 2FA bridge

    /// Called from a Rust worker thread with isideload's request as JSON; blocks
    /// until the sheet answers this request. Writes the JSON answer into
    /// `outBuf` and returns 1, or returns 0 to cancel.
    ///
    /// `ticket` is the sign-in asking. A request from an install's background
    /// sign-in whose run has ended is declined, so no sheet appears after an
    /// install stopped.
    func answerTwoFactor(request json: UnsafePointer<CChar>?, outBuf: UnsafeMutablePointer<CChar>?, len: Int,
                         for ticket: AppleSignInTicket) -> Int32 {
        guard let outBuf, len > 1 else { return 0 }
        let prompt = json.flatMap { TwoFactorPrompt(json: String(cString: $0)) } ?? .deviceOnly
        // Don't cover a Trust prompt; the wait blocks, so never on main.
        if !Thread.isMainThread { attention.waitUntilFree() }
        guard let request = twoFactorRequests.open(for: ticket) else {
            // The queue lets one sign-in ask at a time, so this shouldn't happen.
            // Declining stops the sign-in rather than leave it waiting on a
            // sheet that shows another request.
            ticket.markTwoFactorCancelled()
            log("⚠️ \(ticket.purpose.name): 2FA requested while another sign-in waits for a code — declined.")
            return 0
        }
        setMain {
            // A cancel can land between opening the request and this block running.
            guard self.twoFactorRequests.isWaiting(request.id) else { return }
            // Checked here, on main, where a stopping run has already counted
            // itself finished by the time this block runs.
            if let run = ticket.run, run < self.finishedRuns {
                self.log("2FA requested by the sign-in of an install that already stopped — declined.")
                self.twoFactorRequests.cancel(request.id)   // no answer, so the sign-in aborts
                return
            }
            self.twoFactor = TwoFactorPhase(request: request.id, signIn: ticket.id,
                                            appleID: ticket.appleID, prompt: prompt)
            self.log(prompt.logLine)
        }
        guard let answer = twoFactorRequests.wait(request),
              let bytes = answer.json.map({ Array($0.utf8) }), bytes.count < len else { return 0 }
        outBuf.withMemoryRebound(to: UInt8.self, capacity: len) { dst in
            for (i, b) in bytes.enumerated() { dst[i] = b }
            dst[bytes.count] = 0
        }
        return 1
    }

    /// Hand the sheet's choice to the request it shows. The sheet stays up
    /// showing progress until that sign-in's next prompt arrives or it returns.
    func answerTwoFactor(_ answer: TwoFactorAnswer, to phase: TwoFactorPhase) {
        // Not waiting anymore: answered already, or cancelled.
        guard twoFactorRequests.answer(phase.request, with: answer) else { return }
        if twoFactor?.request == phase.request { twoFactor?.answer = answer }
        log(answer.logLine)
    }

    /// Close the sheet showing `phase`. While Apple waits on the user this
    /// cancels that sign-in; mid-request it only hides, and the sign-in's next
    /// prompt brings it back.
    func cancelTwoFactor(_ phase: TwoFactorPhase) {
        // Already closed because the sign-in returned: nothing to cancel.
        guard twoFactor?.request == phase.request else { return }
        twoFactor = nil
        twoFactorRequests.cancel(phase.request)
    }

    /// Close the sheet once a sign-in attempt returns, however it went, if it
    /// shows that sign-in's 2FA request or team question. Safe from any thread.
    func endSignInQuestions(for ticket: AppleSignInTicket) {
        setMain {
            if self.twoFactor?.signIn == ticket.id { self.twoFactor = nil }
            if self.teamQuestion?.signIn == ticket.id { self.teamQuestion = nil }
        }
    }

    // MARK: Team bridge

    /// What a sign-in stopped with when its team question was closed unanswered.
    static var noTeamPickedMessage: String {
        L("No developer team was picked, so the sign-in stopped.")
    }

    /// Called from a Rust worker thread with the Apple Account's teams as JSON,
    /// when it's on more than one and none was picked for it; blocks until the
    /// sheet answers. Writes the picked team's ID into `outBuf` and returns 1,
    /// or returns 0 to stop the sign-in.
    ///
    /// Like a 2FA request, it waits while a Trust prompt has the user's
    /// attention, and a question from an install's background sign-in whose
    /// run has ended is declined.
    func answerTeam(request json: UnsafePointer<CChar>?, outBuf: UnsafeMutablePointer<CChar>?, len: Int,
                    for ticket: AppleSignInTicket) -> Int32 {
        guard let outBuf, len > 1 else { return 0 }
        guard let teams = json.flatMap({ DeveloperTeam.list(json: String(cString: $0)) }),
              let suggested = DeveloperTeam.suggested(in: teams) else {
            ticket.markTeamQuestionCancelled()
            log("⚠️ \(ticket.purpose.name): couldn't read the developer teams Apple listed — stopping.")
            return 0
        }
        // Don't cover a Trust prompt; the wait blocks, so never on main.
        if !Thread.isMainThread { attention.waitUntilFree() }
        guard let request = teamRequests.open(for: ticket) else {
            // The queue lets one sign-in ask at a time, so this shouldn't happen.
            ticket.markTeamQuestionCancelled()
            log("⚠️ \(ticket.purpose.name): asked which team signs while another sign-in waits for an answer — declined.")
            return 0
        }
        setMain {
            // A cancel can land between opening the request and this block running.
            guard self.teamRequests.isWaiting(request.id) else { return }
            // Checked here, on main, where a stopping run has already counted
            // itself finished by the time this block runs.
            if let run = ticket.run, run < self.finishedRuns {
                self.log("The sign-in of an install that already stopped asked which team signs — declined.")
                self.teamRequests.cancel(request.id)   // no answer, so the sign-in stops
                return
            }
            // The account got past two-factor, so the question takes the
            // sheet over from it.
            if self.twoFactor?.signIn == ticket.id { self.twoFactor = nil }
            self.teamQuestion = TeamQuestion(request: request.id, signIn: ticket.id,
                                             appleID: ticket.appleID, teams: teams,
                                             suggested: suggested,
                                             remembers: AccountStore.shared.isSaved(ticket.appleID))
            let kinds = teams.map(\.kind.rawValue).joined(separator: ", ")
            self.log("\(ticket.purpose.name): this Apple Account is on \(teams.count) developer teams (\(kinds)) — asking which signs.")
        }
        guard let answer = teamRequests.wait(request) else { return 0 }
        let bytes = Array(answer.utf8)
        guard bytes.count < len else { return 0 }
        outBuf.withMemoryRebound(to: UInt8.self, capacity: len) { dst in
            for (i, b) in bytes.enumerated() { dst[i] = b }
            dst[bytes.count] = 0
        }
        return 1
    }

    /// Hand the sheet's pick to the question it shows, and remember it for the
    /// Apple ID when the question says to.
    func answerTeamQuestion(_ team: DeveloperTeam, to question: TeamQuestion) {
        // Not waiting anymore: answered already, or cancelled.
        guard teamRequests.answer(question.request, with: team.teamId) else { return }
        if teamQuestion?.request == question.request { teamQuestion = nil }
        if question.remembers {
            AccountStore.shared.remember(team, for: question.appleID)
        }
        let kind = team.kind == .unknown ? "" : "\(team.kind.rawValue) "
        log("Signing with the \(kind)team \(team.named)\(question.remembers ? ", from now on for this Apple ID" : "").")
    }

    /// Close the team sheet showing `question`, which stops its sign-in.
    func cancelTeamQuestion(_ question: TeamQuestion) {
        // Already closed because the sign-in returned: nothing to cancel.
        guard teamQuestion?.request == question.request else { return }
        teamQuestion = nil
        teamRequests.cancel(question.request)
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
        let box = CZFContinuationBox<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                box.store(cont)
                // Cancelled before the block was queued: don't start work
                // the caller has already abandoned.
                guard !Task.isCancelled else { return }
                deviceQueue.async {
                    do { box.resume(returning: try work()) }
                    catch { box.resume(throwing: error) }
                }
            }
        } onCancel: {
            box.resume(throwing: CancellationError())
        }
    }

    /// Bridge a blocking signQueue body to async.
    private func onSignQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        let box = CZFContinuationBox<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                box.store(cont)
                // Cancelled before the block was queued: don't start work
                // the caller has already abandoned.
                guard !Task.isCancelled else { return }
                signQueue.async {
                    do { box.resume(returning: try work()) }
                    catch { box.resume(throwing: error) }
                }
            }
        } onCancel: {
            box.resume(throwing: CancellationError())
        }
    }

    private func runInBackground(_ label: String, _ work: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            work()
        }
    }

    /// Run a closure on the main queue (for observed state changed off-thread).
    func setMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}

/// One-shot holder for a checked continuation, so a queue bridge can be
/// cancelled while its block is still queued or running: the queued block
/// resumes it with its result, `withTaskCancellationHandler`'s onCancel
/// resumes it with `CancellationError` — whichever runs first wins, the
/// other finds nothing (AutoRefreshService.SingleResume / BuiltinTunnel
/// TunnelWaitState 同款：NSLock + 恰好一次）。A resume that lands
/// before the continuation is stored is replayed to it on `store`, so a
/// task cancelled before the bridge was entered still throws at once
/// instead of waiting for work it never needed. File scope, so the
/// SideBySide and Entitlements queue bridges share it.
final class CZFContinuationBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var pending: Result<T, Error>?

    func store(_ continuation: CheckedContinuation<T, Error>) {
        lock.lock()
        let pending = self.pending
        self.pending = nil
        if pending == nil { self.continuation = continuation }
        lock.unlock()
        if let pending { continuation.resume(with: pending) }
    }

    func resume(returning value: T) { resume(with: .success(value)) }
    func resume(throwing error: Error) { resume(with: .failure(error)) }

    private func resume(with result: Result<T, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        if continuation == nil { pending = result }
        lock.unlock()
        continuation?.resume(with: result)
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

    /// Shown when Apple has locked the Apple Account (GrandSlam -20209), which
    /// only a password reset at iForgot undoes.
    static var accountLocked: Guide {
        Guide(
            title: L("Reset your Apple Account password"),
            systemImage: "lock.trianglebadge.exclamationmark",
            steps: [
                L("Apple has locked this Apple Account for security reasons, often after too many sign-in attempts. Every sign-in fails until it's unlocked, so tapping Install again won't help yet."),
                L("Open iForgot, enter this Apple Account's email, and follow Apple's steps to unlock it and reset its password."),
                L("Back in SideInstaller, open Settings › Account, swipe left on this Apple ID, tap Edit, and enter the new password."),
                L("Then tap Install again."),
            ],
            actionLabel: L("Open iForgot"),
            actionURLString: "https://iforgot.apple.com")
    }

    /// Shown when Apple refuses developer services for the owner's age
    /// (developer error 1102).
    static var underage: Guide {
        Guide(
            title: L("This Apple Account can't sign apps"),
            systemImage: "person.crop.circle.badge.exclamationmark",
            steps: [
                L("Apple only lets adults use the developer services SideInstaller signs apps with, and it reports that this Apple Account belongs to someone younger (error 1102)."),
                L("Sign in with an adult's Apple Account instead: open Settings › Account and add it there."),
                L("Then tap Install again."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    /// Shown when Apple wants the Apple Account's email address verified before
    /// it allows developer services (developer error 2160).
    static var emailUnverified: Guide {
        Guide(
            title: L("Verify your Apple Account's email"),
            systemImage: "envelope.badge",
            steps: [
                L("Apple won't let this Apple Account sign apps until its email address is verified (error 2160). Signing in again or through another anisette server won't change that."),
                L("Sign in at account.apple.com with this Apple Account and verify its email address when Apple asks. Apple sends the code or link to that address, so check its spam folder too."),
                L("Then tap Install again."),
            ],
            actionLabel: L("Open Apple Account"),
            actionURLString: "https://account.apple.com")
    }

    /// Shown when the Apple ID has no App IDs left this week (error 9120).
    static var appIDLimit: Guide {
        Guide(
            title: L("No App IDs left this week"),
            systemImage: "number.circle",
            steps: [
                L("Every app and app extension SideInstaller signs needs an App ID. A free Apple ID can register 10 a week, and each one counts for 7 days."),
                L("They can't be deleted sooner. Wait until some expire, then tap Install again."),
                L("Or sign in with a different (or spare) Apple ID in Settings › Account, then tap Install again."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    /// Shown when installd refuses a fourth app signed by a free Apple ID.
    static var appLimit: Guide {
        Guide(
            title: L("Three sideloaded apps already"),
            systemImage: "square.stack.3d.up.slash",
            steps: [
                L("iOS allows three apps signed with a free Apple ID on an iPhone at a time, and it refused a fourth."),
                L("Expired apps count too. Delete one you no longer need from the Home Screen."),
                L("Then tap Install again."),
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

    /// Shown when the build's GitHub repository is gone, so there's nothing to
    /// download. `fileName` is the name the download step looks for in Documents.
    static func repoUnavailable(source: InstallSource, saveAs fileName: String) -> Guide {
        Guide(
            title: L("Bring the .ipa yourself"),
            systemImage: "tray.and.arrow.down",
            steps: [
                L("%@ can't be downloaded while its GitHub repository is offline. The other apps still install as usual.",
                  source.displayName),
                L("To install it anyway, get its .ipa from somewhere you trust, name it %@, and copy it into Files › On My iPhone › SideInstaller.",
                  fileName),
                L("Then tap Install again — SideInstaller uses your file instead of downloading one."),
            ],
            actionLabel: nil, actionURLString: nil)
    }

    /// Shown when the build couldn't be downloaded because GitHub can't be
    /// reached from here: blocked, filtered or cut off. Where a VPN app is the
    /// way to GitHub, it can't carry the download, since LocalDevVPN holds the
    /// one VPN iOS runs. A copy fetched another way goes in as a custom IPA,
    /// which SideInstaller recognizes and sets up like its own download.
    static func githubUnreachable(source: InstallSource, link: URL) -> Guide {
        Guide(
            title: L("Bring the .ipa yourself"),
            systemImage: "tray.and.arrow.down",
            steps: [
                L("If you reach GitHub through a VPN or proxy app, turn off LocalDevVPN and turn that one on: iOS runs only one VPN at a time."),
                L("Tap “Get the .ipa” below and save the file, or download it on another device and bring it over."),
                L("Back in SideInstaller, pick Custom .ipa under Install, tap “Import .ipa” and choose the file. SideInstaller recognizes %@ and sets it up just like its own download.",
                  source.displayName),
                L("Turn LocalDevVPN back on, then tap Install."),
            ],
            actionLabel: L("Get the .ipa"), actionURLString: link.absoluteString)
    }

    static var pairing: Guide {
        // The Live Activity, or the notification standing in for it, puts the
        // code over Settings; without either it's only in the app.
        let codeOverSettings = PairingLiveActivity.isAvailable || PairingNotification.mayShow
        var steps = [
            L("Open the Settings app, then go to Privacy & Security › Developer Mode."),
            L("Tap “Pair with SideInstaller”."),
            L("Enter your iPhone’s passcode if it asks for it."),
            codeOverSettings
                ? L("Type the code that appears at the top of the screen into the prompt in Settings. If none appears, come back to SideInstaller to read it.")
                : L("Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings."),
        ]
        // The system's prompt gives no reason, and comes up with these steps.
        if PairingNotification.willAsk {
            steps.insert(L("Allow notifications when SideInstaller asks: that's how the pairing code reaches you in Settings."), at: 0)
        }
        return Guide(
            title: L("Pair this iPhone in Settings"),
            systemImage: "lock.iphone",
            steps: steps,
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
    /// When SideStore's certificate can be had, using it comes first.
    static func certExists(sideStoreCertificate: Bool) -> Guide {
        // Fork 的 Guide.steps 是 [String]（非可选），上游三元里的 nil 放不进来；
        // 按本文件 deviceRegistration 的老办法，有条件才 append，顺序与文案不变。
        var steps: [String] = [
            L("Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending."),
            L("SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone."),
        ]
        if sideStoreCertificate {
            steps.append(L("If SideStore made it, tap “Use SideStore's certificate” above: SideInstaller signs with that one too, and nothing is revoked."))
        }
        steps += [
            L("Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there."),
            L("Revoking is permanent: every app already signed with that certificate stops launching, on every device."),
            L("Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again."),
        ]
        return Guide(
            title: L("A signing certificate already exists"),
            systemImage: "exclamationmark.shield",
            steps: steps,
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

    /// The trust step for Madeira, followed by what its own setup still asks
    /// for, and how its signing is kept alive. With the pairing file already
    /// inside, its setup shows that route as done. With the sign-in inside,
    /// Madeira renews its own signing; without, it's refreshed from the Tools
    /// tab like any other app.
    static func trustMadeira(holding handoff: MadeiraHandoff) -> Guide {
        var guide = trust(appName: MadeiraPairingHandoff.appName)
        guide.steps[guide.steps.count - 1] = L("Open Madeira from your Home Screen.")
        guide.steps.append(handoff.pairing
            ? L("In its setup, under “Set up JIT”, pick “In-app with pairing file”: SideInstaller already put the file there, so tap “Continue”.")
            : L("In its setup, under “Set up JIT”, pick how this iPhone gets JIT."))
        guide.steps.append(handoff.signIn
            ? L("Madeira renews its own signing from now on, when it's open and LocalDevVPN is connected. SideInstaller gave it a sign-in for that: a token for Apple's developer service, not your password. Madeira can forget it under Settings › Signing.")
            : L("Its signing lasts 7 days. Before they run out, refresh it here under Tools › Sideloaded apps."))
        return guide
    }

    /// The trust step for AltStore, then what it needs to install and refresh
    /// apps without a computer: its Remote AltServer, whose setup skips pairing
    /// when the pairing file is already inside.
    static func trustAltStore(holdingPairing: Bool) -> Guide {
        var guide = trust(appName: AltStorePairingHandoff.appName)
        guide.steps[guide.steps.count - 1] = L("Open AltStore from your Home Screen and sign in with your Apple ID.")
        guide.steps.append(holdingPairing
            ? L("To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings. Its pairing file is already in place, so the setup skips pairing.")
            : L("To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings and follow its steps."))
        return guide
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

/// Forwards Rust log lines to the activity log, which redacts them off the
/// main thread.
private let siLogCallback: SILogCallback = { _, msg in
    guard let msg = msg else { return }
    LogStore.shared.append("[rust] " + String(cString: msg))
}

/// The 2FA callback every Apple ID sign-in hands Rust, with its
/// `AppleSignInTicket` as the context, so the sheet answers each request for
/// the sign-in that made it.
let appleSignInTwoFactorCallback: SITwoFactorCb = { ctx, request, outBuf, bufLen in
    guard let ticket = AppleSignInTicket.from(context: ctx) else { return 0 }
    return Engine.shared.answerTwoFactor(request: request, outBuf: outBuf, len: Int(bufLen), for: ticket)
}

/// Counts what currently has the user's attention — a Trust prompt — so a 2FA
/// sheet can wait for it to finish. Thread-safe.
final class AttentionGate {
    /// Posted on the main queue when something starts or stops holding the
    /// user's attention, for the install's Live Activity (`InstallActivity`).
    static let didChange = Notification.Name("AttentionGateDidChange")

    private let condition = NSCondition()
    private var holders = 0

    /// True while something holds the user's attention.
    var isHeld: Bool {
        condition.lock()
        defer { condition.unlock() }
        return holders > 0
    }

    func begin() {
        condition.lock()
        holders += 1
        let changed = holders == 1
        condition.unlock()
        if changed { announce() }
    }

    func end() {
        condition.lock()
        let changed = holders == 1
        holders = max(0, holders - 1)
        if holders == 0 { condition.broadcast() }
        condition.unlock()
        if changed { announce() }
    }

    private func announce() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChange, object: self)
        }
    }

    /// Blocks until nothing holds the user's attention. Never on the main thread.
    func waitUntilFree() {
        condition.lock()
        while holders > 0 { condition.wait() }
        condition.unlock()
    }
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

    /// The errors isideload itself writes into `lastError` when Apple turns a
    /// way of getting the code away (`PHONE_CODE_REFUSED`,
    /// `DEVICE_CODE_UNCONFIRMED` in `apple_account.rs`); keep them in step.
    static let isideloadErrors: Set<String> = [
        "Apple won't send a code by text or call to this sign-in, so it was sent to your Apple devices.",
        "Apple didn't confirm sending a code to your Apple devices. If one arrived, enter it; if not, try another way.",
    ]

    /// `lastError` as the sheet shows it: isideload's own sentences in the app's
    /// language, Apple's service errors by their shape, and anything else as a
    /// generic nudge — never Apple's raw English. The raw text is already in the
    /// log (`logLine` carries it on every prompt).
    var shownError: String? {
        guard let lastError else { return nil }
        if Self.isideloadErrors.contains(lastError) { return L(lastError) }
        // Trusted-device wrong code: Rust writes "-21669 - <message>" (:517).
        if lastError.hasPrefix("-21669 -") { return L("The code was incorrect. Try again.") }
        // SMS send refused: Rust writes "<title> - <message>" (:577) with no code
        // in the string; the titles below are Apple's, verified against the
        // isideload tests for -22979/-22981 and -28248.
        if lastError.hasPrefix("Too many verification codes") {
            return L("A code was already sent and is still valid. Enter it.")
        }
        if lastError.hasPrefix("Unknown 2FA method") {
            return L("That way isn't available. Choose another way.")
        }
        // SMS wrong code (:628) has no verifiable title in-repo, and anything
        // else Apple invents lands here too.
        return L("That didn't work. Try another way.")
    }

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

/// The two-factor sheet's state: the request it shows, whose it is, and
/// where it stands.
struct TwoFactorPhase: Equatable {
    /// The request the sheet answers (`TwoFactorRequests`).
    let request: Int
    /// The sign-in that made it (`AppleSignInTicket.id`).
    let signIn: Int
    /// The Apple ID the code is for.
    let appleID: String
    let prompt: TwoFactorPrompt
    /// The answer the sign-in is acting on; nil while Apple waits on the user.
    var answer: TwoFactorAnswer?

    var isAsking: Bool { answer == nil }
}

// MARK: - 后台唤醒续签（BGAppRefreshTask）

/// BGAppRefreshTask 胶水层：进程不在前台时（甚至被系统回收后），靠系统
/// 适时把 App 唤醒，再跑一轮自动续签巡检。巡检本体在
/// AutoRefreshService（tick）；这里只管提交下一次唤醒、被唤醒时先拉
/// 隧道再巡检、以及保证任务恰好完成一次。实际唤醒时机由系统按使用
/// 习惯决定，不是定时器。
enum SIDAutoRefresh {

    /// 与 Info.plist 的 BGTaskSchedulerPermittedIdentifiers 保持一致。
    static let bgTaskIdentifier = "com.frizzle.sideinstaller.autorefresh"

    /// 自动续签开关是否开着（与 AutoRefreshService 共用同一键）。
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: AutoRefreshService.enabledKey)
    }

    /// 向系统提交下一次后台唤醒（最早 2 小时后，实际时机系统定）。
    /// 开关没开就不提交；提交失败只写日志，不打扰用户。
    static func scheduleBackgroundWake() {
        guard isEnabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 3600)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Engine.shared.log("Auto refresh: background wake scheduling failed: \(error.localizedDescription)")
        }
    }

    /// 回到前台时调：开关开着就确保常驻巡检在跑
    /// （已在跑时 AutoRefreshService.start() 无副作用）。
    static func consider() {
        Task { @MainActor in
            AutoRefreshService.shared.start()
        }
    }

    /// 系统唤醒时的入口（SideInstallerApp 启动时注册）：先续上下
    /// 一轮，再拉隧道、跑一轮巡检，最后恰好完成一次。
    static func handleBackgroundWake(_ task: BGAppRefreshTask) {
        scheduleBackgroundWake()
        let completion = BGTaskCompletion(task)
        // S10：过期回调取消工作 Task——它可能正卡在 tunnelUp 的 LOC
        // 等待循环里（后台 waited 不涨），只 finish 不取消等于空转到过期。
        var work: Task<Void, Never>?
        task.expirationHandler = {
            work?.cancel()
            completion.finish(false)
        }
        work = Task {
            guard isEnabled else {
                completion.finish(true)
                return
            }
            // SIDE-2：隧道按需开——唤醒续签拿租约，跑完还掉；拿不到也照常
            // 跑巡检（tick 自己会判隧道未通而跳过）。
            let tunnelAcquired = await Engine.shared.acquireTunnel()
            // C11：只有巡检真跑了一轮才记成功——隧道不通、清单没读到、
            // 正在跑别的安装时，finish(false)，让系统知道这轮没干活。
            let ran = await AutoRefreshService.shared.runCheck()
            if tunnelAcquired { await Engine.shared.releaseTunnel() }
            completion.finish(ran)
        }
    }
}

/// BGTask 要求 setTaskCompleted 恰好调用一次；过期回调与工作 Task
/// 可能同时到达，用一把锁护住完成标志。
private final class BGTaskCompletion {
    private let task: BGAppRefreshTask
    private let lock = NSLock()
    private var didFinish = false

    init(_ task: BGAppRefreshTask) {
        self.task = task
    }

    func finish(_ success: Bool) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()
        task.setTaskCompleted(success: success)
    }
}

// MARK: - Restored from upstream (2026-10-25 merge recovery)
// 290310a took Engine.swift from the fork side; these upstream members
// (FrizzleM/SideInstaller @ 7d1cb04) were dropped with it.

struct AppIDCost: Hashable {
    /// The App IDs signing would register: the app's, if the Apple ID doesn't
    /// have it yet. Extensions are signed with the app's profile and need none.
    let newIDs: [String]
    /// How many more Apple allows now; nil when it doesn't say.
    let available: Int?
    /// The limit, 10 a week for a free Apple ID; nil when Apple doesn't say.
    let limit: Int?
    /// When the soonest of the Apple ID's App IDs expires, freeing its slot.
    let nextExpiry: Date?

    var cost: Int { newIDs.count }
    /// False when Apple says too few are left: signing would stop with 9120.
    var isAffordable: Bool { available.map { cost <= $0 } ?? true }
    /// What's left once this install has registered its App IDs.
    var remainingAfter: Int? { available.map { Swift.max(0, $0 - cost) } }
}

extension Engine {
    /// Detects an Apple ID sign-in refused because the Mac anisette server's
    /// macOS is too old for Apple's current GrandSlam requirements.
    static func isAppleOutdatedMacRefusal(_ raw: String) -> Bool {
        let m = raw.lowercased()
        return m.contains("-23782") || m.contains("a mac with macos version")
    }

    /// Detects GrandSlam -80046, "This action cannot be completed at this
    /// time", at the sign-in token request: Apple took the password and the
    /// code, then turned down the anisette (from its Android library, since
    /// 2026-10-21).
    static func isAppleTokenRefusal(_ raw: String) -> Bool {
        raw.contains("-80046")
    }

    /// Detects isideload's `ANDROID_ADI_SKIP`: a sign-in through a server on
    /// Apple's Android ADI library wasn't started, so nothing reached Apple.
    static func isAndroidADISkip(_ raw: String) -> Bool {
        raw.hasPrefix("login skipped") && raw.contains("-80046")
    }

    /// Whether a lockdown pair record still opens a tunnel to this iPhone.
    /// False from iOS 26.4 on, where lockdownd hangs up on loopback
    /// connections; see NOTES.md ("iOS 26.4+: lockdownd hangs up on loopback
    /// connections").
    static var lockdownWorksOverLoopback: Bool {
        !ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0))
    }

    /// The error when the anisette server picked in Settings, the only one
    /// tried, runs Apple's Android library.
    func androidADIRefusalMessage(server: String) -> String {
        L("“%@” makes its anisette data with Apple's Android library, and Apple now refuses to finish signing in through those servers (error -80046), after your password and code. In Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.",
          anisetteName(for: server))
    }

    /// The error when Apple refused the sign-in token through `server` and no
    /// server of another kind is left.
    func appleTokenRefusalMessage(through server: String) -> String {
        if AnisetteServer.library(of: server, in: anisetteServers) == .mac {
            return L("Apple refused to finish signing in (error -80046), even through a Mac anisette server, the kind it still accepted. Try again later, or check for a SideInstaller update.")
        }
        return L("Apple refused to finish signing in through “%@” (error -80046). It now only accepts sign-ins through anisette servers on its macOS library: in Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.",
                 anisetteName(for: server))
    }

    func anisetteSignedIn(_ address: String) {
        if anisetteAuto { anisetteURL = address }
        AnisetteServer.RecentFailures.clear(address)
    }

    /// Notes that a sign-in through `address` failed with `error`, so that
    /// Auto tries it after the others for a while if the server was at fault.
    func anisetteFailed(_ address: String, error: String) {
        AnisetteServer.RecentFailures.record(address, error: error)
    }

    /// The error for a sign-in that failed on every server it tried. It shows
    /// the error saying most about why (`AnisetteServer.SignInFailures`), and
    /// with several servers tried, the one it came through. It counts the
    /// servers tried, apart from those skipped. With a server picked in
    /// Settings, the only one tried, it names that server and points to Auto,
    /// which would have tried the others.
    func anisetteSignInFailure(_ failures: AnisetteServer.SignInFailures) -> String {
        let error = failures.shown.map { friendlyRustError($0.error) } ?? L("No anisette servers are configured.")
        guard anisetteAuto else {
            return L("Apple ID sign-in failed on %@. Error: %@", anisetteName(for: anisetteURL), error)
                + " " + L("Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.")
        }
        guard let shown = failures.shown, failures.tried > 1 else {
            return L("Apple ID sign-in failed on %@. Error: %@", L("the anisette server"), error)
        }
        let servers = failures.skipped == 0
            ? L("all %d anisette servers", failures.tried)
            : L("%d anisette servers (%d skipped)", failures.tried, failures.skipped)
        return L("Apple ID sign-in failed on %@. Error via %@: %@", servers, anisetteName(for: shown.server), friendlyRustError(shown.error))
    }

    func deviceCrashLogs() async throws -> [DeviceCrashLog] {
        guard !isRunning else {
            throw EngineError.message(L("An install is already running. Wait for it to finish, then try again."))
        }
        // SIDE-2：隧道按需开——同上；本函数非 @MainActor，defer 里经 Task 回主线程还。
        var tunnelAcquired = false
        defer { if tunnelAcquired { Task { @MainActor in Engine.shared.releaseTunnel() } } }
        guard await acquireTunnel() else {
            throw EngineError.message(BuiltinTunnel.useBuiltinDirectly
                ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                : L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        tunnelAcquired = true
        try await ensurePairingConnection()
        log("Crash logs: looking for SideStore's, LiveContainer's and Madeira's …")
        let logs = try await onDeviceQueue {
            try self.connection.crashReports(select: DeviceCrashLog.select)
                .map { DeviceCrashLog(path: $0.path, data: $0.data) }
        }
        log(logs.isEmpty ? "Crash logs: none on this iPhone from the last \(DeviceCrashLog.maxAgeDays) days."
                         : "Crash logs: \(logs.map(\.name).joined(separator: ", ")).")
        return logs
    }

    // @MainActor: cancelOneClick() below is MainActor-isolated (#35 fix).
    @MainActor
    func answerAppIDCost(_ proceed: Bool) {
        guard let reply = appIDCostReply else { return }
        appIDCostReply = nil
        if proceed {
            reply.resume(returning: true)
        } else {
            // The run ends cancelled, the same as closing the popup.
            reply.resume(returning: false)
            cancelOneClick()
        }
        // Clear here as well as in confirmAppIDCost, so a cancelled run
        // never leaves a stale cost popup behind.
        appIDCost = nil
    }
}
