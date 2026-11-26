import SwiftUI
import UIKit
import UserNotifications

// MARK: - Models

/// One provisioning profile, decoded from the CMS blob misagent returns.
///
/// The CMS signature isn't verified (the device already trusts installed
/// profiles). The plist payload is found by scanning the blob, as StikDebug
/// does, rather than using `CMSDecoder`.
struct ProvisioningProfile: Identifiable, Equatable {

    /// Apple's name for the App ID the profile was issued against, e.g.
    /// "SideStore" — not the app's display name, though they usually match.
    let appIDName: String
    /// The full `TEAMID.bundle.id` from the profile's entitlements. This is the
    /// App ID as the developer portal knows it, and may end in `*`.
    let applicationIdentifier: String
    let teamName: String
    let uuid: String
    let creationDate: Date?
    let expirationDate: Date?
    /// Entitlements granted by the profile, as a plist dictionary.
    let entitlements: [String: Any]

    var id: String { uuid }

    /// Compares identity only (UUID and expiry); `[String: Any]` isn't `Equatable`.
    static func == (lhs: ProvisioningProfile, rhs: ProvisioningProfile) -> Bool {
        lhs.uuid == rhs.uuid && lhs.expirationDate == rhs.expirationDate
    }

    /// The bundle ID without the team prefix:
    /// `A1B2C3D4E5.com.example.app` → `com.example.app`.
    var bundleIdentifier: String {
        guard let dot = applicationIdentifier.firstIndex(of: ".") else {
            return applicationIdentifier
        }
        return String(applicationIdentifier[applicationIdentifier.index(after: dot)...])
    }

    /// The team prefix on its own, or nil when the identifier has no prefix.
    var teamIdentifier: String? {
        guard let dot = applicationIdentifier.firstIndex(of: ".") else { return nil }
        return String(applicationIdentifier[..<dot])
    }

    /// True when the App ID is a wildcard (ends in `*`).
    var isWildcard: Bool { applicationIdentifier.hasSuffix("*") }

    /// True for an App Store distribution profile, the kind TestFlight builds
    /// carry. Nothing can be sideloaded with one, so the page leaves it out.
    var isAppStoreDistribution: Bool { entitlements["beta-reports-active"] as? Bool == true }

    /// Calendar days until expiry (1 = tomorrow); negative once expired.
    var daysRemaining: Int? {
        guard let expirationDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day],
                                       from: calendar.startOfDay(for: Date()),
                                       to: calendar.startOfDay(for: expirationDate)).day
    }

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }

    /// Entitlement keys to display, excluding the four every profile has.
    var capabilityKeys: [String] {
        let boilerplate: Set<String> = [
            "application-identifier",
            "com.apple.developer.team-identifier",
            "keychain-access-groups",
            "get-task-allow",
        ]
        return entitlements.keys.filter { !boilerplate.contains($0) }.sorted()
    }

    /// Decodes a `.mobileprovision` payload. Returns nil if no readable plist is
    /// found; such profiles are left off the page.
    init?(data: Data) {
        guard let payload = Self.plistPayload(in: data),
              let plist = try? PropertyListSerialization.propertyList(from: payload, format: nil),
              let dict = plist as? [String: Any] else { return nil }

        let entitlements = dict["Entitlements"] as? [String: Any] ?? [:]
        self.entitlements = entitlements
        self.appIDName = dict["AppIDName"] as? String ?? ""
        self.applicationIdentifier = entitlements["application-identifier"] as? String ?? ""
        self.teamName = dict["TeamName"] as? String ?? ""
        self.uuid = dict["UUID"] as? String ?? UUID().uuidString
        self.creationDate = dict["CreationDate"] as? Date
        self.expirationDate = dict["ExpirationDate"] as? Date
    }

    /// Find the plist inside the CMS wrapper: XML between `<?xml` and `</plist>`,
    /// or everything from `bplist00` on. Apple has shipped both.
    private static func plistPayload(in data: Data) -> Data? {
        let xmlStart = Data("<?xml".utf8)
        let xmlEnd = Data("</plist>".utf8)
        if let start = data.range(of: xmlStart),
           let end = data.range(of: xmlEnd, options: [], in: start.lowerBound..<data.endIndex) {
            return data[start.lowerBound..<end.upperBound]
        }
        if let start = data.range(of: Data("bplist00".utf8)) {
            return data[start.lowerBound..<data.endIndex]
        }
        return nil
    }
}

/// One app installation_proxy reported, kept only when it was installed with a
/// provisioning profile — i.e. sideloaded rather than from the App Store.
struct SideloadedApp: Identifiable, Equatable {

    let bundleID: String
    let name: String
    let version: String?
    /// `TEAMID.bundle.id` from the app's signed entitlements. When missing,
    /// profile matching falls back to the bundle ID.
    let applicationIdentifier: String?
    /// F-1 (0.9.162): the app's first URL scheme, from `CFBundleURLTypes`
    /// — the detail page's Open button uses it. Nil when the app
    /// declares no scheme, so no button shows.
    let urlScheme: String?

    var id: String { bundleID }

    /// Returns nil unless `ProfileValidated` is set. installd sets it only for
    /// apps installed with a provisioning profile, not App Store apps. TestFlight
    /// apps carry a profile too, so they're left out separately.
    init?(plist: [String: Any]) {
        guard plist["ProfileValidated"] != nil,
              let bundleID = plist["CFBundleIdentifier"] as? String else { return nil }
        let entitlements = plist["Entitlements"] as? [String: Any]
        guard !Self.isFromTestFlight(signer: plist["SignerIdentity"] as? String,
                                     entitlements: entitlements) else { return nil }
        self.bundleID = bundleID
        let display = plist["CFBundleDisplayName"] as? String
        let bundleName = plist["CFBundleName"] as? String
        self.name = display?.isEmpty == false ? display! : (bundleName?.isEmpty == false ? bundleName! : bundleID)
        self.version = plist["CFBundleShortVersionString"] as? String
        self.applicationIdentifier = entitlements?["application-identifier"] as? String
        // F-1 (0.9.162): `CFBundleURLTypes` is an array of dictionaries,
        // each with a `CFBundleURLSchemes` array — the first non-empty
        // scheme is the one the Open button launches.
        self.urlScheme = (plist["CFBundleURLTypes"] as? [[String: Any]])?
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }
            .first(where: { !$0.isEmpty })
    }

    /// Whether an app came from TestFlight: Apple signed it (only App Store and
    /// TestFlight builds carry Apple's own signer) or it has the
    /// `beta-reports-active` entitlement, which only App Store distribution
    /// profiles grant. Neither is ever true of a sideloaded app.
    static func isFromTestFlight(signer: String?, entitlements: [String: Any]?) -> Bool {
        if let signer, signer.hasPrefix("Apple iPhone OS Application Signing") { return true }
        return entitlements?["beta-reports-active"] as? Bool == true
    }
}

/// An installed app with every profile on the device that could have signed it,
/// latest expiry first. Multiple profiles are normal: each re-sign leaves one.
struct SideloadedAppStatus: Identifiable, Equatable {

    let app: SideloadedApp
    let profiles: [ProvisioningProfile]

    var id: String { app.bundleID }

    /// The profile in use: the one that expires last.
    var current: ProvisioningProfile? { profiles.first }

    /// Profiles kept only for history, shown on the detail page.
    var superseded: [ProvisioningProfile] { Array(profiles.dropFirst()) }

    /// Sort key: expiry date. Apps without a profile sort last.
    var sortKey: Date { current?.expirationDate ?? .distantFuture }
}

/// Expiry urgency bands and colors (same as AltStore/StikDebug), scaled to a
/// free profile's seven days.
enum ExpiryUrgency {
    case expired, critical, soon, later, comfortable, unknown

    static func of(_ profile: ProvisioningProfile?) -> ExpiryUrgency {
        guard let profile, let days = profile.daysRemaining else { return .unknown }
        if profile.isExpired { return .expired }
        switch days {
        case ...1:  return .critical
        case 2...3: return .soon
        case 4...5: return .later
        default:    return .comfortable
        }
    }

    var color: Color {
        switch self {
        case .expired, .critical: return Theme.negative
        case .soon:               return Theme.warning
        // Between the warning and the positive, toned like them.
        case .later:              return Color(UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(red: 214/255, green: 194/255, blue: 86/255, alpha: 1)   // 深色保持 #D6C256
            : UIColor(red: 122/255, green: 106/255, blue: 0, alpha: 1) })     // 浅色 #7A6A00，白底 5.40:1 / 浅卡 4.84:1
        case .comfortable:        return Theme.positive
        case .unknown:            return Theme.muted
        }
    }

    var symbol: String {
        switch self {
        case .expired:  return "exclamationmark.triangle"
        case .critical: return "clock.badge.exclamationmark"
        case .unknown:  return "questionmark.circle"
        default:        return "clock"
        }
    }

    /// Expiry text, e.g. "Expires today", "Expires in 5 days — 23 Aug",
    /// "Expired 12 Aug". Always shows the remaining days, however far
    /// out the date is (the user asked for the remaining time under
    /// every app in the resign list — the old 30-day cap left
    /// long-lived profiles showing only a bare date).
    /// A-38-A4：到期文案按 (expirationDate, locale) 缓存——每行每 body
    /// 求值现建 Date.FormatStyle 太贵；key 与现行 formatted 用的
    /// Localizer.locale 同一值；>512 条时整表清掉（简单上限，不引入
    /// 逐出策略）。调用方全在主线程 body 求值里，不另加锁。
    /// 审后补丁：key 里必须带今天（startOfDay）——daysRemaining 是按
    /// 自然日算的，不带今天的话，跨过午夜后缓存的“剩 N 天”会错一天，
    /// 直到 512 条上限清表或重进 App 才纠正。
    private static var textCache: [String: String] = [:]

    static func text(for profile: ProvisioningProfile?) -> String {
        guard let profile, let expiration = profile.expirationDate else {
            return L("No matching profile")
        }
        let today = Calendar.current.startOfDay(for: Date())
        let cacheKey = "\(expiration.timeIntervalSince1970)#\(Localizer.locale.identifier)#\(today.timeIntervalSince1970)"
        if let cached = textCache[cacheKey] { return cached }
        let formatted = expiration.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Localizer.locale))
        let result: String
        if profile.isExpired { result = L("Expired %@", formatted) }
        else {
            // 每行算一次存局部量：switch 与插值各取一次会重复算日历差。
            let days = profile.daysRemaining
            switch days {
            case 0:         result = L("Expires today")
            case 1:         result = L("Expires tomorrow")
            case .some(2...): result = L("Expires in %d days — %@", days ?? 0, formatted)
            default:        result = L("Expires %@", formatted)
            }
        }
        if textCache.count > 512 { textCache.removeAll() }
        textCache[cacheKey] = result
        return result
    }
}

// MARK: - Matching

/// Matches installed apps to the profiles that signed them. Static functions
/// with no device or UI state, so the logic can be tested on its own.
enum ProfileMatcher {

    /// Index every profile by the App ID it was issued against, then hand each
    /// app the ones that could have signed it.
    static func match(apps: [SideloadedApp],
                      profiles: [ProvisioningProfile]) -> (entries: [SideloadedAppStatus],
                                                           unmatched: [ProvisioningProfile]) {
        let sorted = profiles.sorted { expiry($0) > expiry($1) }
        // A wildcard App ID covers every bundle id under it, so those can't be
        // looked up — they have to be tried against each app in turn.
        let wildcards = sorted.filter(\.isWildcard)
        let specific = sorted.filter { !$0.isWildcard }
        let byAppID = Dictionary(grouping: specific, by: \.applicationIdentifier)
        // Also index by bundle ID, for apps that don't report
        // `application-identifier`.
        let byBundleID = Dictionary(grouping: specific, by: \.bundleIdentifier)

        var claimed = Set<String>()
        let entries = apps.map { app -> SideloadedAppStatus in
            let matched = matchingProfiles(for: app, byAppID: byAppID,
                                           byBundleID: byBundleID, wildcards: wildcards)
            claimed.formUnion(matched.map(\.uuid))
            return SideloadedAppStatus(app: app, profiles: matched)
        }

        // Profiles no app matched (deleted apps, unused wildcards). Shown because
        // they count toward a free account's App ID limit.
        let unmatched = sorted.filter { !claimed.contains($0.uuid) }

        return (entries.sorted(by: order), unmatched)
    }

    /// Soonest expiry first, then by name.
    private static func order(_ lhs: SideloadedAppStatus, _ rhs: SideloadedAppStatus) -> Bool {
        if lhs.sortKey != rhs.sortKey { return lhs.sortKey < rhs.sortKey }
        return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
    }

    /// The profiles that could have signed `app`, latest expiry first.
    ///
    /// Profiles for this exact App ID or bundle ID take priority. Wildcards are
    /// used only when there are none, so a long-lived wildcard can't hide an
    /// app-specific profile's earlier expiry.
    private static func matchingProfiles(for app: SideloadedApp,
                                         byAppID: [String: [ProvisioningProfile]],
                                         byBundleID: [String: [ProvisioningProfile]],
                                         wildcards: [ProvisioningProfile]) -> [ProvisioningProfile] {
        let target = app.applicationIdentifier ?? app.bundleID
        let specific = (byAppID[target] ?? []) + (byBundleID[app.bundleID] ?? [])
        if !specific.isEmpty { return deduplicated(specific) }
        return deduplicated(wildcards.filter { covers(pattern: $0.applicationIdentifier, app) })
    }

    /// Whether a wildcard App ID covers this app. Checks the app's identifier
    /// first, then its bundle ID against the pattern without the team prefix.
    static func covers(pattern: String, _ app: SideloadedApp) -> Bool {
        if let identifier = app.applicationIdentifier, matches(pattern: pattern, identifier) {
            return true
        }
        guard let dot = pattern.firstIndex(of: ".") else {
            return matches(pattern: pattern, app.bundleID)
        }
        return matches(pattern: String(pattern[pattern.index(after: dot)...]), app.bundleID)
    }

    /// Does `pattern` — an App ID that may end in `*` — cover `value`?
    static func matches(pattern: String, _ value: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        return value.range(of: "^" + escaped + "$", options: .regularExpression) != nil
    }

    /// Removes duplicate profiles (the two indexes overlap) and sorts by latest
    /// expiry.
    private static func deduplicated(_ profiles: [ProvisioningProfile]) -> [ProvisioningProfile] {
        var seen = Set<String>()
        return profiles
            .filter { seen.insert($0.uuid).inserted }
            .sorted { expiry($0) > expiry($1) }
    }

    private static func expiry(_ profile: ProvisioningProfile) -> Date {
        profile.expirationDate ?? .distantPast
    }

    /// Whether an installed app was built from the IPA with `ipaBundleID`.
    /// isideload signs apps as `<bundle id>.<team id>`, so this checks for that
    /// suffix: `teamID` when known, otherwise any 10-character team ID.
    static func installed(_ bundleID: String, isBuiltFrom ipaBundleID: String,
                          teamID: String?) -> Bool {
        if bundleID == ipaBundleID { return true }        // signed by something else
        if let teamID, !teamID.isEmpty { return bundleID == "\(ipaBundleID).\(teamID)" }
        guard bundleID.hasPrefix(ipaBundleID + ".") else { return false }
        let suffix = bundleID.dropFirst(ipaBundleID.count + 1)
        // A team id is ten characters, upper-case letters and digits only.
        return suffix.count == 10 && suffix.allSatisfy { $0.isUppercase || $0.isNumber }
    }
}

extension SideloadedAppsManager {
    /// F-2 (0.9.164): the installed version of the app an IPA's bundle ID
    /// belongs to — SourcesView's `installedVersion(for:)` matcher, shared
    /// so the Downloads and Files rows tag the same way: the team suffix a
    /// signature appends still counts as the same app.
    func installedVersion(forBundleID bundleID: String) -> String? {
        entries.first {
            ProfileMatcher.installed($0.app.bundleID, isBuiltFrom: bundleID, teamID: nil)
        }?.app.version
    }
}

/// F-2 (0.9.164): the Downloads / Files row tag comparing a file's version
/// with the installed one — newer / older / same, with the installed version
/// named. The file version and the installed version are both required, so
/// no tag is ever invented from a missing half.
func czfVersionComparisonTag(fileVersion: String, installedVersion: String) -> (text: String, color: Color) {
    if UpdateChecker.isNewer(fileVersion, than: installedVersion) {
        return (L("Newer than installed %@", installedVersion), Theme.positive)
    }
    if UpdateChecker.isNewer(installedVersion, than: fileVersion) {
        return (L("Older than installed %@", installedVersion), Theme.warning)
    }
    return (L("Same as installed %@", installedVersion), Theme.muted)
}

/// One app a refresh will act on: what is installed, and the IPA on disk it
/// will be signed again from.
struct RefreshJob: Identifiable, Equatable {

    enum State: Equatable {
        case pending, working, done
        case failed(String)
    }

    /// The bundle id as installed — team id and all.
    let bundleID: String
    let name: String
    let ipa: URL
    /// Size in bytes of the IPA at pair time, from the library scan —
    /// the row icon key reads this snapshot instead of statting the disk
    /// on every body evaluation (A-1, SIDE-33).
    let ipaSize: Int
    /// Modification time of the IPA at pair time, seconds since 1970
    /// (0 when the scan saw no date); same snapshot purpose as `ipaSize`.
    let ipaModified: TimeInterval
    /// Team ID the app is currently signed under (from its current profile).
    let teamID: String?
    var state: State = .pending

    var id: String { bundleID }
}

// MARK: - Manager

/// Drives the Sideloaded apps page: loads installed apps and profiles from the
/// device, matches them, and runs "Refresh all" through the install pipeline.
///
/// One for the app, so the Shortcuts actions (AppsShortcuts.swift) see and
/// refresh the same apps as the page.
@MainActor
final class SideloadedAppsManager: ObservableObject {
    /// 界面和快捷指令共用同一个实例，这样后台触发的续签状态界面也能看到，
    /// 且两条路径靠 isRefreshing 互斥、不会重复跑。
    static let shared = SideloadedAppsManager()

    /// 续签期间的无声音频保活（快捷指令后台触发时没有界面，靠它撑住进程不被挂起）。
    private let keepAlive = KeepAlive()

    /// LocalDevVPN 跳回后待续签的标记（UserDefaults 键）。
    static let pendingRefreshKey = "SIDPendingRefreshAll"
    /// 待续签标记的落点时间（UserDefaults 键，C13）：标记过期 24 小时
    /// 只清不跑，免得数日后回前台又自动跑一轮。
    static let pendingRefreshAtKey = "SIDPendingRefreshAllAt"
    /// 待续签标记的有效期。
    private static let pendingRefreshTTL: TimeInterval = 24 * 3600

    /// How a refresh run went.
    struct RefreshOutcome {
        /// Why the run couldn't start (no device link, or no sign-in).
        var failure: String?
        /// The apps it went through, each `done` or `failed`.
        var jobs: [RefreshJob] = []
        var refreshed: Int { jobs.filter { $0.state == .done }.count }
    }

    @Published private(set) var entries: [SideloadedAppStatus] = []
    /// Profiles belonging to no installed app — deleted apps' leftovers.
    @Published private(set) var unmatched: [ProvisioningProfile] = []
    @Published private(set) var isWorking = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var lastRefreshed: Date?
    /// The last device-list load failed: when set, `entries` / `refreshable`
    /// are the previous successful load's, not fresh. Cleared by the next
    /// successful load. Callers that waited on a load check this instead of
    /// trusting `hasLoaded` alone (C5).
    @Published private(set) var lastLoadFailed: Date?
    /// What the last failed load reported, for the log. `lastError` stays
    /// untouched in quiet mode so no popup appears (C5).
    @Published private(set) var lastLoadError: String?
    @Published var lastError: String?

    /// The apps a refresh can act on: an installed app whose IPA is still in
    /// Documents. Rebuilt on every load.
    @Published private(set) var refreshable: [RefreshJob] = []
    /// Apps on the page with no IPA to sign again from, for the note that says
    /// why they aren't included.
    @Published private(set) var unrefreshable = 0
    /// Listed apps dropped from refresh because another team signed them
    /// (an enterprise certificate, someone else's ID): refreshing re-signs
    /// with the signed-in Apple ID, so it only ever applies to that ID's apps.
    @Published private(set) var teamExcluded = 0
    /// Bundle IDs of listed apps that have an IPA on disk, before the team
    /// filter (0.9.150): `refreshable` drops team-excluded apps, so it
    /// can't tell "has an IPA but another team signed it" from "no IPA at
    /// all" — the per-row marker needs this set. Set alongside
    /// `refreshable` / `teamExcluded` / `unrefreshable` in
    /// `rebuildRefreshable`, so it is never newer or older than the count.
    @Published private(set) var pairedBundleIDs: Set<String> = []
    /// The run in progress, or the last one's results until another starts.
    @Published private(set) var jobs: [RefreshJob] = []
    @Published private(set) var isRefreshing = false
    /// What the refresh is doing right now, shown on the button.
    @Published private(set) var refreshStatus: String?
    /// How the last finished run went, e.g. "Refreshed 2 of 3 apps."
    @Published private(set) var refreshSummary: String?
    /// UserDefaults key for `lastBackgroundRefreshResult`.
    private static let backgroundRefreshResultKey = "SIDLastBackgroundRefreshResult"
    /// The last refresh run that finished with failures while its completion
    /// notification couldn't be delivered (C11). Persisted — a background run
    /// has no other way to report — and shown on the apps page next open.
    /// Cleared by the next fully successful refresh. The stored text is the
    /// run's refreshSummary, already localized when it was saved.
    @Published private(set) var lastBackgroundRefreshResult: String? =
        // 键与 backgroundRefreshResultKey 相同：属性初始化器里不能
        // 用 Self.xxx（协变 Self），写字面量。
        UserDefaults.standard.string(forKey: "SIDLastBackgroundRefreshResult")

    /// Writes (or clears) `lastBackgroundRefreshResult`, keeping UserDefaults
    /// in step so the note survives an app restart (C11).
    private func setBackgroundRefreshResult(_ value: String?) {
        lastBackgroundRefreshResult = value
        if let value {
            UserDefaults.standard.set(value, forKey: Self.backgroundRefreshResultKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.backgroundRefreshResultKey)
        }
    }

    private var engine: Engine { Engine.shared }

    /// Keeps `autoLoad` to a single attempt.
    private var didAutoLoad = false

    /// The refresh in flight, kept so it can be called off between apps.
    private var refreshTask: Task<RefreshOutcome, Never>?

    /// The load in flight, kept so a caller that arrived after it started
    /// can await it instead of polling `isWorking` (A-5, SIDE-32).
    private var loadTask: Task<Void, Never>?

    /// Internal read of the load in flight, so the auto-refresh patrol can
    /// await it instead of polling `isWorking` (A-4, SIDE-33).
    var inFlightLoadTask: Task<Void, Never>? { loadTask }

    /// What went wrong last, as a popup `RootView` stacks over the app.
    var popups: [ToolPopup] { lastError.map { [.error($0)] } ?? [] }

    func closePopup(_ popup: ToolPopup) { lastError = nil }

    /// Number of apps expiring within a day (shown in the header pill).
    var expiringSoon: Int {
        entries.filter { status in
            switch ExpiryUrgency.of(status.current) {
            case .expired, .critical: return true
            default: return false
            }
        }.count
    }

    /// Loads once when the page opens with the tunnel up, without showing
    /// errors. Opening the page doesn't start LocalDevVPN; Load does.
    func autoLoad() {
        guard !didAutoLoad, !hasLoaded, !isWorking else { return }
        engine.refreshNetworkStatus()
        guard engine.vpnConnected else { return }
        didAutoLoad = true
        load(quiet: true)
    }

    /// B-3 (0.9.171): let the next `autoLoad()` try again after a load
    /// that started but never delivered entries — otherwise one failed
    /// read (tunnel up, device unreachable) burns the single auto-load
    /// for the whole launch, and the certificate page's revoke confirm
    /// can never list the affected apps again without restarting.
    func resetAutoLoad() { didAutoLoad = false }

    /// Ask the device what it has. `quiet` logs failures instead of showing them.
    /// Returns the Task doing the load (nil when the guard declines because
    /// one is already running), so a caller that must wait on it can await
    /// the Task instead of polling `isWorking` (A-5, SIDE-32).
    @discardableResult
    func load(quiet: Bool = false) -> Task<Void, Never>? {
        guard !isWorking, !isRefreshing else { return nil }
        isWorking = true
        if !quiet { lastError = nil }
        if !quiet { engine.log("=== Sideloaded apps: reading the device ===") }
        // B-3：Swift 5.0 模式下 plain Task 不继承 MainActor，await 回来仍在
        // 全局执行器，随后的 @Published 写会落在主线程外——显式进主 actor。
        let task = Task { @MainActor in
            do {
                let inventory = try await engine.sideloadedAppInventory()
                // A-3（SIDE-33）：三步解析（两个 compactMap + match）是
                // 非隔离纯函数，放 detached 里算完，只把赋值留在主线程。
                // SideloadedApp / ProvisioningProfile / ProfileMatcher 皆为
                // 非隔离 struct/enum，无 @MainActor，移过去无隔离问题。
                let parsed = await Task.detached {
                    let apps = inventory.apps.compactMap(SideloadedApp.init(plist:))
                    // TestFlight apps' profiles would otherwise show as unused.
                    let profiles = inventory.profiles.compactMap(ProvisioningProfile.init(data:))
                        .filter { !$0.isAppStoreDistribution }
                    let matched = ProfileMatcher.match(apps: apps, profiles: profiles)
                    return (apps: apps, profiles: profiles, matched: matched)
                }.value
                entries = parsed.matched.entries
                unmatched = parsed.matched.unmatched
                await rebuildRefreshable()
                hasLoaded = true
                lastRefreshed = Date()
                lastLoadFailed = nil
                lastLoadError = nil
                engine.log("Sideloaded apps: \(parsed.apps.count) sideloaded, \(parsed.profiles.count) profile(s) decoded.")
            } catch {
                let message = userFacingErrorMessage(error)
                let raw = String(describing: error)
                lastLoadFailed = Date()
                lastLoadError = message
                if quiet {
                    engine.log("Sideloaded apps: not ready yet (\(raw))")
                } else {
                    lastError = message
                    engine.log("⛔️ Sideloaded apps: \(raw)")
                }
            }
            isWorking = false
            loadTask = nil
        }
        loadTask = task
        return task
    }

    /// Reads the device's apps and profiles and matches them. The caller holds
    /// `isWorking`.
    private func performLoad() async throws {
        let inventory = try await engine.sideloadedAppInventory()
        let apps = inventory.apps.compactMap(SideloadedApp.init(plist:))
        // TestFlight apps' profiles would otherwise show as unused.
        let profiles = inventory.profiles.compactMap(ProvisioningProfile.init(data:))
            .filter { !$0.isAppStoreDistribution }
        let matched = ProfileMatcher.match(apps: apps, profiles: profiles)
        entries = matched.entries
        unmatched = matched.unmatched
        await rebuildRefreshable()
        hasLoaded = true
        lastRefreshed = Date()
        engine.log("Sideloaded apps: \(apps.count) sideloaded, \(profiles.count) profile(s) decoded.")
    }

    // MARK: - Refresh all

    /// Re-signs and reinstalls every refreshable app, one at a time (they share
    /// one device link and signing queue, and Apple's API is rate-limited).
    /// `onlyBundleIDs` 给定时，自动巡检只续到期的那几个；界面和快捷指令不传，
    /// 照旧全续。`fromUI` 给单 App 续签入口（行滑动 / 详情页按钮）用：它也
    /// 只续指定 bundleID，但它是界面入口，守卫拦下时要像全量续签一样
    /// 置 lastError 弹原因，而不是像自动巡检那样只写日志。
    /// F1 (0.9.153): single-app refresh — same guards, same team filter,
    /// only the entry point is new.
    func refreshAll(onlyBundleIDs: Set<String>? = nil, fromUI: Bool = false) {
        let candidates = onlyBundleIDs.map { ids in
            refreshable.filter { ids.contains($0.bundleID) }
        } ?? refreshable
        // C3：三个守卫别再静默 return——调用方要知道本轮为什么没跑。
        // 只有自动巡检入口（onlyBundleIDs != nil 且非界面入口）只写日志、
        // 不置 lastError：它没有界面可弹，后台一轮也不该弹前台弹窗。
        let showsFailure = onlyBundleIDs == nil || fromUI
        if isRefreshing {
            if showsFailure {
                lastError = L("A refresh is already running. Wait for it to finish, then try again.")
            }
            engine.log("Refresh all: already refreshing.")
            return
        }
        if isWorking {
            if showsFailure {
                lastError = L("Still reading the device. Try again in a moment.")
            }
            engine.log("Refresh all: device inventory in progress.")
            return
        }
        if candidates.isEmpty {
            if showsFailure {
                lastError = L("没有需要续签的应用。")
            }
            engine.log("Refresh all: nothing to refresh.")
            return
        }
        guard !engine.isRunning else {
            // C27：照 C3 其余三道守卫——只有界面入口（onlyBundleIDs == nil
            // 或 fromUI 单 App 入口）才置 lastError；快捷指令/自动巡检
            // 入口只写日志，不留过期弹窗。
            if showsFailure {
                lastError = L("An install is already running. Wait for it to finish, then refresh.")
            }
            engine.log("Refresh all: install already running.")
            return
        }
        // B-38-B2（对称口）：导入进行中不点全部续签——rebuildRefreshable
        // 可能读到正在被 replaceCustomImport 清空的 Custom/。分流照 C3/C27：
        // 界面入口置 lastError，快捷指令/自动巡检入口只写日志。
        guard !engine.isImportingIPA && !engine.isImportingPairing else {
            if showsFailure {
                lastError = L("An import is already running. Wait for it to finish, then try again.")
            }
            engine.log("Refresh all: import already running.")
            return
        }
        // 续签不再以 WiFi 为前置（2026-10-29）：隧道是本机回环
        // utun，包根本不出设备，WiFi 开没开与它无关；引擎的
        // ensurePairingConnection 自己就写着“No Wi-Fi check:
        // this all runs over the loopback tunnel”。以前这里没开
        // WiFi 就直接拒掉，是多余的门。删掉它：隧道没通也先
        // 放行，后面 prepareRefresh 里的 tunnelUp() 会真去拉隧
        // 道，拉不起来再报隧道错误——那才是真原因。没装
        // LocalDevVPN 也一样，别让流程跑到一半才报个看不懂
        // 的连接错误。
        engine.refreshNetworkStatus()
        if !engine.vpnConnected && !engine.localDevVPNInstalled && !BuiltinTunnel.useBuiltinDirectly {
            lastError = L("未安装 LocalDevVPN，请先安装 LocalDevVPN 再续签。")
            engine.log("⛔️ Refresh all: LocalDevVPN isn't installed.")
            return
        }
        refreshTask = startRefresh(candidates, showsFailure: showsFailure, onlyBundleIDs: onlyBundleIDs)
    }

    /// Refreshes `selected` in the background, as the page lists them. A run
    /// that can't start says why in a popup when `showsFailure` is set.
    @discardableResult
    private func startRefresh(_ selected: [RefreshJob], showsFailure: Bool, onlyBundleIDs: Set<String>? = nil) -> Task<RefreshOutcome, Never> {
        jobs = selected
        isRefreshing = true
        lastError = nil
        refreshSummary = nil
        refreshStatus = L("Getting ready")
        engine.log("=== Refresh all: \(jobs.count) app(s) ===")
        // 续签全程开无声保活，息屏/切后台也不会被系统挂起
        keepAlive.startAudio()

        let task = Task { @MainActor () -> RefreshOutcome in
            // 原账号：全程结束（正常、失败、取消）都要切回来。activate
            // 是同步的，放 defer 里保证任何出口都执行；defer 不能
            // await，所以内存 session 的重登放在正文末尾尽力做。
            let originalAccount = AccountStore.shared.active
            var tunnelAcquired = false
            defer {
                isRefreshing = false
                refreshStatus = nil
                refreshTask = nil
                self.keepAlive.stopAudio()
                if let originalAccount { AccountStore.shared.activate(originalAccount) }
                if tunnelAcquired { engine.releaseTunnel() }
            }
            // SIDE-2：隧道按需开——续签全程拿租约；拿不到就地报错、不跑，
            // defer 照常复位 isRefreshing（不走这句会卡死在“续签中”）。
            guard await engine.acquireTunnel() else {
                let message = BuiltinTunnel.useBuiltinDirectly
                    ? L("The built-in tunnel couldn't start. See the log for the reason, then try again.")
                    : L("LocalDevVPN isn't connected. Connect it, then try again.")
                if showsFailure { lastError = message }
                engine.log("⛔️ Refresh all: \(message)")
                jobs = []
                return RefreshOutcome(failure: message)
            }
            tunnelAcquired = true
            do {
                try await engine.prepareRefresh()
            } catch is CancellationError {
                engine.log("Refresh all: cancelled during sign-in.")
                jobs = []
                return RefreshOutcome(jobs: jobs)
            } catch {
                let message = userFacingErrorMessage(error)
                let raw = String(describing: error)
                if showsFailure { lastError = message }
                engine.log("⛔️ Refresh all: \(raw)")
                jobs = []
                return RefreshOutcome(failure: message)
            }

            // prepareRefresh 刚登完当前账号、记下了它的团队映射；但
            // jobs 是登之前建的（那时这队可能还没映射），重建一次让
            // 刚记下的映射当场生效：切到 icloud 点一次全部续签，
            // icloud 的 App 这一轮就能进列表，不用再重读、再点一次。
            // 只续到期的那几只（快捷指令/后台）仍按原 ID 过滤。
            await rebuildRefreshable()
            let rebuiltCandidates = onlyBundleIDs.map { ids in
                refreshable.filter { ids.contains($0.bundleID) }
            } ?? refreshable
            if rebuiltCandidates.count != jobs.count {
                engine.log("Refresh all: list rebuilt after sign-in (\(jobs.count) → \(rebuiltCandidates.count)).")
                // C4：重建把有的 App 悄悄丢了时，别直接换掉 jobs——
                // 被丢的以 .failed 留在原位（分母不变、有一行交代），
                // 新进来的（刚记下团队映射的）接在末尾。
                var byID: [String: RefreshJob] = [:]
                for job in rebuiltCandidates { byID[job.bundleID] = job }
                let oldIDs = Set(jobs.map { $0.bundleID })
                var merged: [RefreshJob] = []
                merged.reserveCapacity(max(jobs.count, rebuiltCandidates.count))
                for var job in jobs {
                    if let rebuilt = byID[job.bundleID] {
                        merged.append(rebuilt)
                    } else {
                        job.state = .failed(L("Skipped: this app stopped being refreshable after the run started. Its IPA may have been deleted."))
                        merged.append(job)
                    }
                }
                merged.append(contentsOf: rebuiltCandidates.filter { !oldIDs.contains($0.bundleID) })
                jobs = merged
            }

            // C4：没团队号的 job 不进任何组——以前 groupedByTeam 里
            // 静默跳过，现在先标 .failed，免得它从总数里无声消失。
            // 正常不会走到这里（rebuildRefreshable 已滤掉没团队号的），
            // 只是防线。
            for index in jobs.indices where jobs[index].teamID == nil {
                jobs[index].state = .failed(L("Skipped: this app has no team on its signing profile, so it can't be refreshed."))
            }
            // 按团队分组跑：每组先切到该团队的账号、登完核对团队号再
            // 签。组内保持页面顺序，组按首次出现顺序。取消只在组间
            // 和 App 间检查，正在签装的单个 App 不中断。
            // B-38-B1：整轮登记——待续签的后项在整轮里都有守卫，
            // 不只当前项。注册点必须在 C4 合并之后（合并会换掉 jobs）。
            engine.renewingSourcePaths.formUnion(jobs.map { $0.ipa.path })
            let groups = Self.groupedByTeam(jobs)
            let multiAccount = groups.count > 1
            var refreshed = 0
            var didSwitchAccount = false
            for group in groups {
                if Task.isCancelled { break }
                let team = group.team
                // 当前 session 已是该组团队时不用切（prepareRefresh 刚
                // 登的原账号组就是这种情况）。
                if engine.signingTeamID != team {
                    guard let groupAccount = AccountStore.shared.account(forTeam: team) else {
                        // rebuildRefreshable 已拦过，走到这里说明列表过期：
                        // 整组跳过，绝不拿当前账号给它签名。
                        for index in jobs.indices where jobs[index].teamID == team {
                            jobs[index].state = .failed(
                                L("Skipped: no saved Apple ID matches this app's team (%@). Switch to that account and refresh again.", team))
                        }
                        engine.log("⛔️ Refresh group \(team): no saved account maps to this team — skipped.")
                        continue
                    }
                    // 切账号：Settings 切账号时 RootView 的 revision 监听
                    // 会异步丢弃旧 session，但那是 fire-and-forget，不能
                    // 等；这里显式等旧 session 释放完再登，否则 signIn
                    // 会因 signSession != nil 直接跳过、还用旧账号。
                    AccountStore.shared.activate(groupAccount)
                    didSwitchAccount = true
                    await engine.dropSignSession()
                    do {
                        try await engine.signInForRefresh()
                    } catch is CancellationError {
                        for index in jobs.indices where jobs[index].teamID == team {
                            jobs[index].state = .failed(L("Skipped: refresh stopped."))
                        }
                        engine.log("Refresh group \(team): sign-in cancelled — skipped.")
                        continue
                    } catch {
                        let message = Self.text(for: error)
                        for index in jobs.indices where jobs[index].teamID == team {
                            jobs[index].state = .failed(
                                L("Couldn't sign in as %@ (%@). Switch to that account and refresh again.", groupAccount.normalized, message))
                        }
                        engine.log("⛔️ Refresh group \(team) as \(groupAccount.normalized): sign-in failed: \(message)")
                        continue
                    }
                    // 底线核对：登完的团队必须等于该组团队，否则整组跳
                    // 过。2FA 取消/锁定/凭据错误/限流都走到这里的上一
                    // 步：只跳过该组，继续跑别的组。
                    guard engine.signingTeamID == team else {
                        for index in jobs.indices where jobs[index].teamID == team {
                            jobs[index].state = .failed(
                                L("Skipped: signed in as %@, but this app's team is %@. Switch to that account and refresh again.", groupAccount.normalized, team))
                        }
                        engine.log("⛔️ Refresh group \(team): signed in as \(groupAccount.normalized) but team is \(engine.signingTeamID ?? "unknown") — skipped.")
                        continue
                    }
                    engine.log("Refresh group \(team): signed in as \(groupAccount.normalized).")
                }
                let groupEmail = AccountStore.shared.account(forTeam: team)?.normalized
                    ?? AccountStore.shared.activeAppleID
                for job in group.jobs {
                    if Task.isCancelled { break }
                    guard let index = jobs.firstIndex(where: { $0.bundleID == job.bundleID }) else { continue }
                    // 第二道闸（保留）：逐个再核一次团队，防列表与
                    // session 漂移。团队号未知、App 团队号未知、团队号
                    // 不一致，三种一律跳过不续，绝不把证书签的 App
                    // 重新签成个人 ID。
                    guard let teamNow = engine.signingTeamID, let installed = job.teamID, installed == teamNow else {
                        jobs[index].state = .failed(
                            L("Skipped: not signed by the team you're signed in as, so a certificate-signed app is never re-signed here."))
                        continue
                    }
                    jobs[index].state = .working
                    // B5：这项续签在跑时把源路径登记进 Engine，文件页/LAN/WebDAV
                    // 的删/移/改名入口会拒掉这个源；.done/.failed 处注销。
                    engine.renewingSourcePaths.insert(job.ipa.path)
                    refreshStatus = multiAccount
                        ? L("Refreshing %@ as %@", job.name, groupEmail)
                        : L("Refreshing %@", job.name)
                    do {
                        try await engine.refreshInstalledApp(named: job.name, ipaPath: job.ipa.path)
                        jobs[index].state = .done
                        engine.renewingSourcePaths.remove(job.ipa.path)
                        refreshed += 1
                        // 记一笔续签源：删文件时凭它提示“这是某 App 续签用的文件”。
                        RenewalSourceStore.record(bundleID: job.bundleID, appName: job.name, ipaURL: job.ipa)
                    } catch is CancellationError {
                        jobs[index].state = .failed(L("Skipped: refresh stopped."))
                        engine.renewingSourcePaths.remove(job.ipa.path)
                        engine.log("Refresh \(job.name): cancelled.")
                        continue
                    } catch {
                        let message = userFacingErrorMessage(error)
                        let raw = String(describing: error)
                        jobs[index].state = .failed(message)
                        // B5：续签失败，注销源路径（与 .working 登记配对）。
                        engine.renewingSourcePaths.remove(job.ipa.path)
                        engine.log("⛔️ Refresh \(job.name): \(raw)")
                    }
                }
            }

            // 切回原账号的内存 session（activeID 已由 defer 恢复）。
            // 只有本轮切过账号时才需要；重登失败则 team 已清，下次
            // 登录重取，绝不顶着别的账号的团队号。
            if didSwitchAccount {
                await self.restoreOriginalSession(original: originalAccount)
            }

            // C22：取消只停 Task、不扫尾 jobs——没轮到的 job 仍是 .pending，
            // 卡片常驻显示 "Waiting"，与“本轮已结束”不符；收尾扫一遍改
            // .failed。正常跑完时没有 .pending 残留，扫尾是空操作。
            // B5：取消时正在 .working 的那项也要扫尾——否则它的源路径
            // 会一直留在续签集里，之后删它永远被拒。
            for index in jobs.indices where jobs[index].state == .pending || jobs[index].state == .working {
                if jobs[index].state == .working {
                    engine.renewingSourcePaths.remove(jobs[index].ipa.path)
                }
                jobs[index].state = .failed(L("Skipped: refresh stopped."))
            }
            // B-38-B1：整轮注销——提前 .failed / 取消后 .pending 的项，
            // 逐项 remove 盖不住，只有整批 subtract 能清掉。
            engine.renewingSourcePaths.subtract(jobs.map { $0.ipa.path })
            refreshSummary = jobs.count == 1
                ? (refreshed == 1 ? L("Refreshed. Its seven days start again now.")
                                  : L("Nothing was refreshed."))
                : L("Refreshed %d of %d apps.", refreshed, jobs.count)
            engine.log("Refresh all finished: \(refreshed)/\(jobs.count) refreshed.")
            // C11：全续完就清掉上次后台失败的留底；没全续完时，
            // 通知发不出去才留底（发出去就不用留，用户已收到）。
            if refreshed == jobs.count {
                setBackgroundRefreshResult(nil)
            }
            // Post local notification for background resign
            let content = UNMutableNotificationContent()
            content.title = refreshed > 0 ? L("续签成功") : L("续签完成")
            content.body = refreshSummary ?? L("Refreshed %d of %d apps.", refreshed, jobs.count)
            content.sound = .default
            let request = UNNotificationRequest(identifier: "resign-done", content: content, trigger: nil)
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                engine.log("Refresh all: completion notification failed to send (\(error.localizedDescription)).")
                // C11：通知是后台续签唯一的出口——发不出去又有失败，
                // 把结果存下来，下次打开应用页时在列表上方显示。
                if refreshed < jobs.count {
                    setBackgroundRefreshResult(refreshSummary ?? L("Refreshed %d of %d apps.", refreshed, jobs.count))
                }
            }
            let outcome = RefreshOutcome(jobs: jobs)
            // Read the device again, so the days on screen are the new ones.
            if refreshed > 0 {
                isRefreshing = false        // `load` won't run while a refresh holds the link
                load(quiet: true)
            }
            // C13：手动续签正常跑完，快捷指令留下的待续签意图已满足——
            // 清掉标记，免得下次回前台又自动跑一轮。
            if onlyBundleIDs == nil {
                UserDefaults.standard.removeObject(forKey: Self.pendingRefreshKey)
                UserDefaults.standard.removeObject(forKey: Self.pendingRefreshAtKey)
            }
            return outcome
        }
        refreshTask = task
        return task
    }

    // MARK: - Shortcuts

    /// Reads the device afresh for a Shortcuts action, once the page's own
    /// load or refresh is done.
    func loadForShortcut() async throws {
        try await waitUntilIdle()
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        try await performLoad()
    }

    /// Reads the device afresh, then refreshes the refreshable apps whose
    /// bundle ids are in `bundleIDs`, or all of them when it's nil, as Refresh
    /// all does. Returns once the last one is done.
    func refreshForShortcut(_ bundleIDs: Set<String>? = nil) async throws -> RefreshOutcome {
        try await loadForShortcut()
        guard !engine.isRunning else {
            throw EngineError.message(L("An install is already running. Wait for it to finish, then refresh."))
        }
        let selected = bundleIDs.map { ids in refreshable.filter { ids.contains($0.bundleID) } }
            ?? refreshable
        guard !selected.isEmpty else {
            if entries.isEmpty {
                throw EngineError.message(L("Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here."))
            }
            let names = entries.filter { bundleIDs?.contains($0.app.bundleID) ?? true }.map(\.app.name)
            // An app picked in a shortcut may be gone since: its bundle ID, then.
            let named = names.isEmpty ? (bundleIDs ?? []).sorted() : names
            throw EngineError.message(L("%@ can't be refreshed: SideInstaller has no IPA to sign it again from. Refresh it in whatever installed it, or import its .ipa into SideInstaller first.",
                                        named.joined(separator: ", ")))
        }
        // A load from the page may have started meanwhile.
        try await waitUntilIdle()
        // Signing in, signing and installing each app outlast the time iOS
        // gives an action in the background.
        keepAlive.startAudio()
        defer { keepAlive.stopAudio() }
        let run = startRefresh(selected, showsFailure: false, onlyBundleIDs: bundleIDs)
        // Stopping the shortcut stops the run after the app being refreshed,
        // as the page's Stop does.
        let outcome = await withTaskCancellationHandler {
            await run.value
        } onCancel: {
            run.cancel()
        }
        if let failure = outcome.failure { throw EngineError.message(failure) }
        return outcome
    }

    /// Returns once the page isn't loading or refreshing.
    private func waitUntilIdle() async throws {
        while isWorking || isRefreshing {
            try await Task.sleep(for: .milliseconds(250))
        }
    }

    /// One refresh group: the jobs of a single team, signed with that team's
    /// Apple ID. Job order inside a group matches the page's order.
    private struct RefreshGroup {
        let team: String
        var jobs: [RefreshJob]
    }

    /// Groups jobs by team, groups in first-appearance order. Jobs without a
    /// team never reach here (rebuildRefreshable filters them); dropped
    /// defensively so a stale list can't crash the run.
    private static func groupedByTeam(_ jobs: [RefreshJob]) -> [RefreshGroup] {
        var order: [String] = []
        var byTeam: [String: [RefreshJob]] = [:]
        for job in jobs {
            guard let team = job.teamID else { continue }
            if byTeam[team] == nil { order.append(team) }
            byTeam[team, default: []].append(job)
        }
        return order.compactMap { team in
            byTeam[team].map { RefreshGroup(team: team, jobs: $0) }
        }
    }

    /// Distinct teams in the refreshable list. The confirm dialog uses it to
    /// say when more than one Apple ID will sign.
    var refreshableTeamCount: Int {
        Set(refreshable.compactMap { $0.teamID }).count
    }

    /// Best-effort re-sign-in as the run's original account, after a
    /// multi-account run switched away from it. activeID is already restored
    /// by refreshAll's defer; this only restores the in-memory session and
    /// team. On failure the team stays cleared (dropSignSession cleared it)
    /// so nothing claims the wrong team; the next sign-in re-derives it.
    private func restoreOriginalSession(original: SavedAccount?) async {
        guard let original else { return }
        AccountStore.shared.activate(original)
        await engine.dropSignSession()
        do {
            try await engine.signInForRefresh()
            engine.log("Refresh done: signed back in as \(original.normalized).")
        } catch {
            engine.log("⛔️ Refresh done: couldn't sign back in as \(original.normalized): \(Self.text(for: error)) — team cleared, next sign-in re-derives it.")
        }
    }

    /// Stops the run after the current app finishes. Remaining apps aren't
    /// refreshed; their rows are marked failed on the run card (C22) instead
    /// of staying "Waiting".
    func cancelRefresh() {
        guard isRefreshing, refreshTask != nil else { return }
        refreshTask?.cancel()
        refreshStatus = L("Stopping after this app")
        engine.log("Refresh all: stopping after the current app.")
    }

    // MARK: - 快捷指令后台续签

    /// 快捷指令入口：不依赖界面存在，自己加载列表再续签。
    /// 内置隧道在包里时自己把它拉起来接着签；不带的包才走老路：
    /// 隧道没通且装了 LocalDevVPN 时，先记待续签标记并打开它连接，
    /// 它连好跳回 App 后由 consumePendingRefresh() 接着跑完。
    @MainActor
    func refreshAllFromShortcut() async {
        guard !isRefreshing else { return }
        engine.refreshNetworkStatus()
        // SIDE-2：隧道按需开——这里的直起改成拿租约（C2 顺带修：两处入口
        // 的双触发已删，见 SideInstallerApp / RefreshAllAppsIntent），
        // loadThenRefreshAll 之后还掉；refreshAll 自己还会再拿一次。
        var tunnelAcquired = false
        if !engine.vpnConnected {
            // 快捷指令/后台续签同样不再查 WiFi（2026-10-29）：
            // 下面本来就有一套隧道拉起流程（内置隧道直起，
            // 起不来再走 LocalDevVPN 交接），WiFi 分支只会
            // 在隧道明明能起时提前判死刑，删掉它。
            if BuiltinTunnel.useBuiltinDirectly {
                // 签名带隧道权限：内置隧道不依赖任何外部 App，拉不起来才报失败
                guard await engine.acquireTunnel() else {
                    await postResignNotification(title: L("续签失败"), body: L("内置隧道没能启动，打开 SideInstaller 重试一次。"))
                    return
                }
                tunnelAcquired = true
                engine.refreshNetworkStatus()
            } else {
                if !engine.localDevVPNInstalled {
                    await postResignNotification(title: L("续签失败"), body: L("未安装 LocalDevVPN，请先安装 LocalDevVPN 再续签。"))
                    return
                }
                UserDefaults.standard.set(true, forKey: Self.pendingRefreshKey)
                UserDefaults.standard.set(Date(), forKey: Self.pendingRefreshAtKey)
                engine.log("Refresh all (shortcut): tunnel down, opening LocalDevVPN; will resume on return.")
                _ = engine.startLocalDevVPN()
                return
            }
        }
        await loadThenRefreshAll()
        if tunnelAcquired { engine.releaseTunnel() }
    }

    /// App 回到前台时调用：有待续签标记且隧道已通就清掉标记接着跑。
    @MainActor
    func consumePendingRefresh() {
        guard UserDefaults.standard.bool(forKey: Self.pendingRefreshKey), !isRefreshing else { return }
        // C13：标记过期 24 小时只清不跑——数日后回前台不该再自动整轮重签。
        // 没时间戳的是旧版留下的标记，同样只清不跑。
        let markedAt = UserDefaults.standard.object(forKey: Self.pendingRefreshAtKey) as? Date
        guard let markedAt, Date().timeIntervalSince(markedAt) < Self.pendingRefreshTTL else {
            UserDefaults.standard.removeObject(forKey: Self.pendingRefreshKey)
            UserDefaults.standard.removeObject(forKey: Self.pendingRefreshAtKey)
            return
        }
        engine.refreshNetworkStatus()
        guard engine.vpnConnected else { return }
        UserDefaults.standard.removeObject(forKey: Self.pendingRefreshKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingRefreshAtKey)
        Task { await loadThenRefreshAll() }
    }

    /// 先（必要时）加载设备上的可续签列表，再开续签。
    @MainActor
    private func loadThenRefreshAll() async {
        // C27：安装进行中时快捷指令/待续签续签静默落空——入口先拦，
        // 照抄 tick()（AutoRefreshService:101-102）的做法；拦下时发
        // 一条通知（复用 refreshAll 守卫里已有的 key，0 新 key），
        // 不走到 refreshAll 那道会留过期 lastError 的守卫。
        guard !engine.isRunning else {
            await postResignNotification(title: L("续签失败"), body: L("An install is already running. Wait for it to finish, then refresh."))
            return
        }
        // C5：快捷指令每次都重读一次设备再续签——只在 hasLoaded 时跳过，
        // 用的是上次的清单，设备上 App 变了（新装/已删/到期日变了）
        // 续签集就是错的。等这一轮 load 跑完再决定。
        let failedBefore = lastLoadFailed
        // A-5（SIDE-32）：直接等 load 起的那只 Task，不再 0.5 秒轮询
        // isWorking。load 没起跑时（已有另一路 load 在跑）等那只在途的；
        // 两只都没有（正刷续签、load 起不来）时直接往下走判定——与旧的
        // “isWorking 为假即跳出”同义。
        if let task = load(quiet: true) ?? loadTask {
            await task.value
        }
        if isWorking {
            await postResignNotification(title: L("续签失败"), body: L("读取设备失败，请打开 SideInstaller 查看。"))
            return
        }
        // 成功加载会清掉失败标记；标记与调用前不同，就是本轮刚失败。
        // 旧标记原样不动时不算失败——那是更早一轮留下的。
        if let failed = lastLoadFailed, failed != failedBefore {
            await postResignNotification(title: L("续签失败"), body: L("读取设备失败，请打开 SideInstaller 查看。"))
            return
        }
        guard hasLoaded else {
            await postResignNotification(title: L("续签失败"), body: L("读取设备失败，请打开 SideInstaller 查看。"))
            return
        }
        guard !refreshable.isEmpty else {
            await postResignNotification(title: L("续签完成"), body: L("没有需要续签的应用。"))
            return
        }
        // B-4（SIDE-33）：load 的数秒内另起了一轮续签时静默返回——
        // 再调 refreshAll() 会撞 isRefreshing 守卫、弹一条假错误。
        guard !isRefreshing else { return }
        refreshAll()
    }

    private func postResignNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "resign-shortcut-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // C11：快捷指令失败通知本身也可能发不出去（没给通知权限
            // 最常见）——记一行日志，别用 try? 静默吞掉。
            engine.log("Refresh (shortcut): notification failed to send (\(error.localizedDescription)).")
        }
    }

    /// A thrown error as the page should print it.
    private static func text(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    /// Finds which listed apps have a matching IPA in Documents. The IPAs are
    /// read off the main thread.
    private func rebuildRefreshable() async {
        let installed = entries.map {
            InstalledRef(bundleID: $0.app.bundleID, name: $0.app.name,
                         teamID: $0.current?.teamIdentifier)
        }
        let paired = await Task.detached(priority: .userInitiated) {
            SideloadedAppsManager.pair(installed, with: IPALibrary.installable())
        }.value
        // 多账号续签：可续签 = 配对成功 且 团队号映射到某个已存账号，
        // 或等于当前登录团队（冷启动兜底：团队号还没记到账号上时，
        // 沿用现行“只续当前登录团队”的行为）。团队号未知、或映射不
        // 到任何账号且不等于当前团队（企业证书团队）的，照样排除，
        // 计入 teamExcluded。IPA-on-disk 这道门不动：没进 paired 的
        // 本来就不在这里。证书签的 App 不续的本意不变——进来的每个
        // App 仍只用它自己团队的账号签，绝不拿当前账号给它签名。
        let knownTeams = Set(AccountStore.shared.accounts.compactMap { $0.teamID })
        let currentTeam = engine.signingTeamID
        let kept = paired.filter { job in
            guard let team = job.teamID else { return false }
            if knownTeams.contains(team) { return true }
            return team == currentTeam
        }
        let excluded = paired.count - kept.count
        refreshable = kept
        pairedBundleIDs = Set(paired.map { $0.bundleID })
        teamExcluded = excluded
        unrefreshable = max(0, entries.count - paired.count)
        engine.log("Sideloaded apps: \(kept.count) of \(entries.count) can be refreshed from an IPA on disk.\(excluded > 0 ? " \(excluded) left out (signed by another team)." : "")")
    }

    /// Recompute only which listed apps still have an IPA on disk, after a
    /// file was deleted from the Files/Downloads page. No device read and
    /// `entries` untouched — just re-pairs the current entries against the
    /// IPA library on disk, so the "N apps can be signed again" count and
    /// the refresh set stop including the deleted IPA (C8).
    func refreshRefreshableOnly() {
        Task { await rebuildRefreshable() }
    }

    /// A page entry cut down to what the matching needs, so that work can be
    /// handed off the main actor.
    private struct InstalledRef: Sendable {
        let bundleID: String
        let name: String
        let teamID: String?
    }

    /// One job per installed app that an IPA on disk would reinstall, in the
    /// page's own order.
    private nonisolated static func pair(
        _ installed: [InstalledRef],
        with library: [(entry: IPALibrary.Entry, info: IPALibrary.AppInfo)]
    ) -> [RefreshJob] {
        installed.compactMap { app in
            guard let match = library.first(where: {
                ProfileMatcher.installed(app.bundleID, isBuiltFrom: $0.info.bundleID,
                                         teamID: app.teamID)
            }) else { return nil }
            return RefreshJob(bundleID: app.bundleID, name: app.name,
                              ipa: match.entry.url, ipaSize: match.entry.size,
                              ipaModified: match.entry.modified?.timeIntervalSince1970 ?? 0,
                              teamID: app.teamID)
        }
    }
}

// MARK: - View

/// Sideloaded apps page: apps installed with a provisioning profile, their App
/// ID, and time until expiry. Pushed from Tools (relies on its `NavigationStack`).
struct AppsView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// Observed for `installProgress` during a refresh.
    @Environment(Engine.self) private var engine
    @ObservedObject var manager: SideloadedAppsManager

    @State private var showSettings = false
    /// Shows the "Refresh all" confirmation alert.
    @State private var confirmRefresh = false
    /// Shows the "LocalDevVPN isn't installed" prompt with a link to get it.
    @State private var showInstallLOCPrompt = false
    /// 行图标已试过的键：文件页同款取法（IPALibrary.iconData 只读 central
    /// directory + 单个图标条目），没配对 IPA 的行继续用虚线占位。
    /// 图标本体在共享 ThumbnailCache 里（A-37-3），按配对 IPA 路径查；
    /// 重绘由 iconEpoch 触发。
    @State private var rowIconsTried: Set<String> = []
    @State private var iconEpoch = 0
    /// F1 (0.9.141): the app list's search text — the file page's SearchBar
    /// 同款，过滤按名字或 Bundle ID（见 `filteredEntries`）。
    @State private var appSearchText = ""
    /// F-3 (0.9.158): true while the header badge's tap filters the list
    /// to the apps expiring within 3 days (or already expired); tapping
    /// the badge again, or "Show all", restores the full list.
    @State private var showExpiringOnly = false
    /// F-1 (0.9.161): the installed app awaiting uninstall confirmation,
    /// the one uninstalling, and a failure to report — the confirm box
    /// is the swipe's, the failure box the run's.
    @State private var pendingUninstall: SideloadedAppStatus?
    @State private var uninstallingID: String?
    @State private var uninstallError: String?
    /// F3 (0.9.145): the app list's sort — the file page's FileSort 同款
    /// （到期日 / 名称 / Bundle ID），@AppStorage 持久化。只改显示顺序，
    /// 不动匹配与续签；默认到期日就是 ProfileMatcher 的顺序，原样返回。
    private enum AppSort: String, CaseIterable {
        case expiry, name, bundleID
        var label: String {
            switch self {
            case .expiry:   return L("Expiry date")
            case .name:     return L("Name")
            case .bundleID: return L("Bundle ID")
            }
        }
    }
    @AppStorage("CZFAppSort") private var appSortRaw = AppSort.expiry.rawValue
    private var appSort: AppSort { AppSort(rawValue: appSortRaw) ?? .expiry }
    /// A-5(c)：行图标的批量写回（loadRowIcon 同款，懒建）。
    @State private var rowIconBatcher: BatchWriteback<String, UIImage>?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header.cascadeItem(0)
                refreshAllButton
                refreshNote
                loadButton
                refreshRunCard
                searchBar
                // Errors show as a popup, which `RootView` lays over the app.
                appList
                unmatchedSection
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: manager.entries)
            .animation(.smooth(duration: 0.3), value: manager.isWorking)
            .animation(.smooth(duration: 0.35), value: manager.jobs)
            .animation(.smooth(duration: 0.35), value: manager.refreshable)
        }
        .refreshable {
            // F2 (0.9.141): pull to reload the device list.
            // SideloadedAppsManager is @MainActor; load() returns the Task
            // doing the load (nil when one is already running), so awaiting
            // its value keeps the spinner up until the fresh list lands.
            // B-cand-2 (0.9.154): when load() declines because one is
            // already running, the old code awaited nil and the spinner
            // vanished at once while the list was still stale — wait on
            // the in-flight load instead; no second load is started.
            let task = await MainActor.run { manager.load() }
            if let task {
                await task.value
            } else {
                // 修法（checks 三轮红：MainActor.run 的首参是带默认值的
                // resultType:，闭包只能放尾随位置——写进括号里就被当成
                // resultType: 实参；同文件上一行就是尾随闭包写法）。
                let inFlight = await MainActor.run { manager.inFlightLoadTask }
                await inFlight?.value
            }
        }
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { manager.autoLoad() }
        .alert(L("Refresh all apps?"), isPresented: $confirmRefresh) {
            Button(L("Refresh all")) {
                // 点续签先做一轮检查：隧道已通直接签；没通也不再
                // 查 WiFi（2026-10-29：回环隧道不出设备，WiFi
                // 与它无关）。签名带隧道权限时不再查 LocalDevVPN，
                // refreshAll 里的 tunnelUp() 会自己把内置隧道拉起来；
                // 签名带不了隧道（个人 ID 等）才按老规矩查 LocalDevVPN。
                engine.refreshNetworkStatus()
                if engine.vpnConnected {
                    manager.refreshAll()
                } else if !BuiltinTunnel.useBuiltinDirectly, !engine.localDevVPNInstalled {
                    showInstallLOCPrompt = true
                } else {
                    manager.refreshAll()
                }
            }
            Button(L("Cancel"), role: .cancel) { }
        } message: {
            Text(manager.refreshable.count == 1
                 ? L("%@ will be signed again with the Apple ID that signed it and installed over the copy on this device. It keeps its data, and its seven days start over.",
                     manager.refreshable.first?.name ?? "")
                 : L("%d apps will be signed again, each with the Apple ID that signed it, and installed over the copies on this device. They keep their data, and their seven days start over.",
                     manager.refreshable.count))
            if manager.refreshableTeamCount > 1 {
                Text(L("These apps were signed under %d Apple IDs, so each group is signed with its own Apple ID.",
                       manager.refreshableTeamCount))
            }
        }
        .alert(L("未安装 LocalDevVPN"), isPresented: $showInstallLOCPrompt) {
            Button(L("去安装")) {
                if let url = URL(string: "https://xiaofang-source.pages.dev/localdevvpn.ipa") {
                    openURL(url)
                }
            }
            Button(L("Cancel"), role: .cancel) { }
        } message: {
            Text(L("续签要走 LocalDevVPN 的本地隧道。先装好 LocalDevVPN，之后点续签会自动打开它连接，不用手动开。"))
        }
        // F-1 (0.9.161): uninstall confirm + failure, for the row swipe.
        .alert(L("Uninstall %@?", pendingUninstall?.app.name ?? ""), isPresented: Binding(
            get: { pendingUninstall != nil },
            set: { if !$0 { pendingUninstall = nil } }
        )) {
            Button(L("Uninstall"), role: .destructive) {
                if let status = pendingUninstall {
                    pendingUninstall = nil
                    uninstall(status)
                }
            }
            Button(L("Cancel"), role: .cancel) { pendingUninstall = nil }
        } message: {
            Text(L("This removes %@ from this iPhone, including its data.", pendingUninstall?.app.name ?? ""))
        }
        .alert(L("Uninstall"), isPresented: Binding(
            get: { uninstallError != nil },
            set: { if !$0 { uninstallError = nil } }
        )) {
            Button(L("OK"), role: .cancel) { uninstallError = nil }
        } message: {
            Text(uninstallError ?? "")
        }
    }

    /// F-1 (0.9.161): uninstall one sideloaded app, then re-read the device
    /// list so the row is gone without leaving the page. Failures surface
    /// here, next to the row the user swiped — not in the manager's popup.
    private func uninstall(_ status: SideloadedAppStatus) {
        guard uninstallingID == nil else { return }
        uninstallingID = status.app.bundleID
        Task { @MainActor in
            do {
                try await engine.uninstallApp(bundleID: status.app.bundleID)
                let task = manager.load()
                if let task { await task.value } else { await manager.inFlightLoadTask?.value }
            } catch {
                uninstallError = userFacingErrorMessage(error)
            }
            uninstallingID = nil
        }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "app.badge.clock", image: "AppsLogo", title: L("Sideloaded apps")) {
            if manager.hasLoaded {
                let expiring = manager.expiringSoon
                // F-3 (0.9.158): the badge is a filter, not just a count —
                // tap it to show only the apps expiring within 3 days (or
                // already expired); tap again to restore the full list.
                // With nothing expiring there is nothing to filter to.
                Button {
                    if expiring > 0 { showExpiringOnly.toggle() }
                } label: {
                    StatusDot(text: expiring > 0
                                 ? (expiring == 1 ? L("%d app needs refreshing", expiring)
                                                  : L("%d apps need refreshing", expiring))
                                 : (manager.entries.count == 1 ? L("%d app", manager.entries.count)
                                                               : L("%d apps", manager.entries.count)),
                              color: expiring > 0 ? Theme.warning : Theme.positive)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }

    // MARK: Primary action

    /// "Refresh all" button, shown once loaded; disabled when no app can be refreshed.
    @ViewBuilder
    private var refreshAllButton: some View {
        if manager.hasLoaded {
            VStack(spacing: 8) {
                Button { confirmRefresh = true } label: {
                    HStack(spacing: 8) {
                        if manager.isRefreshing {
                            ProgressView()
                            Text(manager.refreshStatus ?? L("Getting ready"))
                                .lineLimit(1)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(L("Refresh all"))
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(manager.refreshable.isEmpty || manager.isRefreshing || manager.isWorking)
                // Only the install step reports progress.
                if manager.isRefreshing, engine.installProgress > 0, engine.installProgress < 1 {
                    ProgressView(value: engine.installProgress)
                        .tint(Theme.accent)
                }
                if !manager.refreshable.isEmpty {
                    Text(manager.refreshable.count == 1
                         ? L("%d app can be signed again from an IPA already on this iPhone.",
                             manager.refreshable.count)
                         : L("%d apps can be signed again from IPAs already on this iPhone.",
                             manager.refreshable.count))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .transition(.cardAppear)
            .cascadeItem(1)
        }
    }

    /// Load/Reload button: primary style until "Refresh all" is available, then
    /// secondary. Becomes Cancel during a refresh.
    @ViewBuilder
    private var loadButton: some View {
        if manager.isRefreshing {
            Button(role: .cancel) { manager.cancelRefresh() } label: {
                Text(L("Cancel")).frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
            .cascadeItem(2)
        } else if manager.hasLoaded {
            Button { manager.load() } label: {
                loadLabel(spinner: Theme.accent).frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
            .disabled(manager.isWorking || manager.isRefreshing)
            .cascadeItem(2)
        } else {
            Button { manager.load() } label: { loadLabel(spinner: .white) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(manager.isWorking || manager.isRefreshing)
                .cascadeItem(2)
        }
    }

    private func loadLabel(spinner: Color) -> some View {
        HStack(spacing: 8) {
            if manager.isWorking {
                ProgressView().tint(spinner)
                Text(L("Reading the device"))
            } else {
                Image(systemName: manager.hasLoaded ? "arrow.clockwise" : "iphone.and.arrow.forward")
                    .contentTransition(.symbolEffect(.replace))
                Text(manager.hasLoaded ? L("Reload") : L("Load apps"))
            }
        }
    }

    // MARK: Refresh run

    /// Per-app refresh progress and results. Stays visible after the run so
    /// failures can be read.
    @ViewBuilder
    private var refreshRunCard: some View {
        if !manager.jobs.isEmpty {
            PanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Refresh all"))
                        .font(.headline)
                    // Enumerated so rows redraw on a language change.
                    ForEach(Array(manager.jobs.enumerated()), id: \.element.id) { _, job in
                        jobRow(job)
                    }
                    if let summary = manager.refreshSummary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .transition(.cardAppear)
            .cascadeItem(3)
        }
    }

    private func jobRow(_ job: RefreshJob) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                jobIcon(job.state)
                Text(job.name)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 6)
                Text(Self.stateText(job.state))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Self.stateColor(job.state))
            }
            if case let .failed(message) = job.state {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.negative)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func jobIcon(_ state: RefreshJob.State) -> some View {
        switch state {
        case .pending:  Image(systemName: "clock").foregroundStyle(Theme.muted)
        case .working:  ProgressView().controlSize(.small)
        case .done:     Image(systemName: "checkmark.circle").foregroundStyle(Theme.positive)
        case .failed:   Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.negative)
        }
    }

    private static func stateText(_ state: RefreshJob.State) -> String {
        switch state {
        case .pending: return L("Waiting")
        case .working: return L("In progress")
        case .done:    return L("Done")
        case .failed:  return L("Failed")
        }
    }

    private static func stateColor(_ state: RefreshJob.State) -> Color {
        switch state {
        case .pending, .working: return Theme.muted
        case .done:              return Theme.positive
        case .failed:            return Theme.negative
        }
    }

    /// Notes explaining why listed apps can't be refreshed from this page.
    /// Shown right under "Refresh all" so the reason is visible without
    /// scrolling past the whole list.
    @ViewBuilder
    private var refreshNote: some View {
        if manager.hasLoaded && manager.teamExcluded > 0 {
            CalloutCard(tint: Theme.accent) {
                Text(manager.teamExcluded == 1
                     ? L("%d app here is signed under a team that matches no saved Apple ID, so it is left out. Switch to the Apple ID that signed it and sign in once, then reload, and it will join the list. Enterprise-signed apps stay excluded.", manager.teamExcluded)
                     : L("%d apps here are signed under teams that match no saved Apple ID, so they are left out. Switch to the Apple ID that signed them and sign in once, then reload, and they will join the list. Enterprise-signed apps stay excluded.", manager.teamExcluded))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cascadeItem(2)
        }
        if manager.hasLoaded && manager.unrefreshable > 0 && !manager.entries.isEmpty {
            CalloutCard(tint: Theme.accent) {
                Text(manager.unrefreshable == 1
                     ? L("%d app here has no IPA in SideInstaller, so it can't be refreshed from this page. Refresh it in whatever installed it, or import its .ipa first.",
                         manager.unrefreshable)
                     : L("%d apps here have no IPA in SideInstaller, so they can't be refreshed from this page. Refresh them in whatever installed them, or import their .ipa first.",
                         manager.unrefreshable))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cascadeItem(2)
        }
    }

    // MARK: App list

    /// F1 (0.9.141): search field above the list — the file page's SearchBar
    /// (Theme.swift), shown once the list has loaded.
    @ViewBuilder
    private var searchBar: some View {
        if manager.hasLoaded && !manager.entries.isEmpty {
            SearchBar(text: $appSearchText, placeholder: L("搜索"))
                .cascadeItem(4)
        }
    }

    /// F1 (0.9.141): the list filtered by `appSearchText` — name or Bundle ID
    /// contains the query, case-insensitive (the file page's matching() 同款取法).
    /// F3 (0.9.145): then sorted by `appSort` — expiry is the matcher's own
    /// order, returned as-is; name / Bundle ID sort case-insensitively.
    /// F-3 (0.9.158): when the header badge's filter is on, only the apps
    /// expiring within 3 days (or already expired) stay — the same bands
    /// `expiringSoon` counts, plus `.soon` (2–3 days), per
    /// `ExpiryUrgency.of`.
    private var filteredEntries: [SideloadedAppStatus] {
        var base: [SideloadedAppStatus]
        if appSearchText.isEmpty {
            base = manager.entries
        } else {
            let query = appSearchText.lowercased()
            base = manager.entries.filter {
                $0.app.name.lowercased().contains(query)
                    || $0.app.bundleID.lowercased().contains(query)
            }
        }
        if showExpiringOnly {
            base = base.filter {
                switch ExpiryUrgency.of($0.current) {
                case .expired, .critical, .soon: return true
                default: return false
                }
            }
        }
        switch appSort {
        case .expiry:   return base
        case .name:     return base.sorted { $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending }
        case .bundleID: return base.sorted { $0.app.bundleID.localizedCaseInsensitiveCompare($1.app.bundleID) == .orderedAscending }
        }
    }

    @ViewBuilder
    private var appList: some View {
        if manager.hasLoaded && manager.entries.isEmpty && !manager.isWorking {
            emptyState.transition(.cardAppear)
        } else if !manager.entries.isEmpty {
            VStack(spacing: 12) {
                // A-38-A4：一次建成 bundleID → RefreshJob 字典，行图标三处
                // 查表代替 refreshable.first 线性查找（每行每 body 求值 3 次）。
                // 必须用 uniquingKeysWith——uniqueKeysWithValues 遇重复
                // bundleID 直接 trap；refreshable 正常无重复，但防线不能少。
                let jobsByID = Dictionary(manager.refreshable.map { ($0.bundleID, $0) },
                                          uniquingKeysWith: { first, _ in first })
                HStack {
                    Text(filteredEntries.count == 1
                         ? L("%d app", filteredEntries.count)
                         : L("%d apps", filteredEntries.count))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    // F-3 (0.9.158): the badge filter's way back — only
                    // while it is on, next to the count it shrank.
                    if showExpiringOnly {
                        Button(L("Show all")) { showExpiringOnly = false }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    if let refreshed = manager.lastRefreshed {
                        Text(refreshed.formatted(Date.FormatStyle(date: .omitted, time: .shortened)
                                                     .locale(Localizer.locale)))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .cascadeItem(5)
                // F3 (0.9.145): sort switch — the file page's FileSort menu
                // 同款；只改显示顺序（见 `filteredEntries`）。
                HStack {
                    Menu {
                        ForEach(AppSort.allCases, id: \.self) { option in
                            Button {
                                appSortRaw = option.rawValue
                            } label: {
                                if appSort == option {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    } label: {
                        Label(L("排序：%@", appSort.label), systemImage: "arrow.up.arrow.down")
                            .font(.footnote.weight(.semibold))
                    }
                    Spacer()
                }
                // C5：上次读设备失败时，列表是上一次成功加载的旧清单——
                // 到期天数可能已经变了，标出来，别让用户当成新的看。
                // 成功加载会清掉 lastLoadFailed，小字随之消失。
                if manager.lastLoadFailed != nil {
                    CalloutCard(tint: Theme.negative) {
                        Text(L("Load failed. Showing the last loaded list."))
                            .font(.footnote)
                            .foregroundStyle(Theme.negative)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                // C11：上次后台续签没全续完、通知又没发出去时，留底在
                // 这里显示——前台刚跑完的 summary 优先（refreshSummary
                // 非空时不显示，避免新旧两条结果并列）。
                if manager.refreshSummary == nil, !manager.isRefreshing,
                   let background = manager.lastBackgroundRefreshResult {
                    CalloutCard(tint: Theme.accent) {
                        Text(L("Last refresh (its notification couldn't be delivered): %@", background))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if filteredEntries.isEmpty {
                    // F1 (0.9.141): a search that matches nothing — the list
                    // itself is non-empty (see the branch above), so say so
                    // instead of leaving a bare count header.
                    Text(L("No matching apps."))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { idx, status in
                        NavigationLink {
                            AppProfileDetail(status: status)
                        } label: {
                            appRow(status, jobsByID: jobsByID)
                        }
                        .buttonStyle(.plain, sound: .tick)
                        // F1 (0.9.153): single-app refresh — only rows with a
                        // paired IPA offer it; the guard and team filter
                        // inside refreshAll are unchanged.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if jobsByID[status.app.bundleID] != nil {
                                Button {
                                    manager.refreshAll(onlyBundleIDs: [status.app.bundleID], fromUI: true)
                                } label: {
                                    Label(L("Renew this app"), systemImage: "arrow.clockwise")
                                }
                                .tint(Theme.accent)
                            }
                            // F-1 (0.9.161): uninstall the installed copy —
                            // never SideInstaller itself (it lists here too:
                            // it is installed with a provisioning profile).
                            if status.app.bundleID != Bundle.main.bundleIdentifier {
                                Button(role: .destructive) {
                                    pendingUninstall = status
                                } label: {
                                    Label(L("Uninstall"), systemImage: "trash")
                                }
                                .disabled(uninstallingID != nil)
                            }
                        }
                        .cascadeItem(6 + idx)
                        .task(id: rowIconKey(for: status, jobsByID: jobsByID)) {
                            loadRowIcon(for: status, jobsByID: jobsByID)
                        }
                    }
                }
            }
        }
    }

    /// 行图标取图键：已装包名 + 配对 IPA 路径 + 大小 + 修改时间——
    /// 可续签列表变了（刚读完设备、或导入新 IPA）或同路径文件被替换
    /// 就重取。
    private func rowIconKey(for status: SideloadedAppStatus, jobsByID: [String: RefreshJob]) -> String {
        // A-1（SIDE-33）：只读 pair() 时快照的存量，不再 stat 磁盘——
        // body 每次求值都会调这里。键格式不变。
        // A-38-A4：字典查表代替 refreshable.first 线性查找。
        let job = jobsByID[status.app.bundleID]
        return "\(status.app.bundleID)#\(job?.ipa.path ?? "")#\(job?.ipaSize ?? 0)#\(job?.ipaModified ?? 0)"
    }

    /// A-37-3：行图标在共享缓存里按 IPA 路径查；行上只有 bundleID，
    /// 经 refreshable 的配对找路径（rowIconKey 同款查找）。
    private func rowIconPath(for status: SideloadedAppStatus, jobsByID: [String: RefreshJob]) -> String? {
        jobsByID[status.app.bundleID]?.ipa.path
    }

    /// 行图标：配对 IPA 的真图放后台取，取到写缓存；没配对 IPA、
    /// 或 Assets.car 独占图标取不到时，继续用虚线占位，不造假图。
    private func loadRowIcon(for status: SideloadedAppStatus, jobsByID: [String: RefreshJob]) {
        let key = rowIconKey(for: status, jobsByID: jobsByID)
        guard !rowIconsTried.contains(key) else { return }
        rowIconsTried.insert(key)
        guard let job = jobsByID[status.app.bundleID] else { return }
        let ipa = job.ipa
        // A-5(c)：批量写回懒建（首次加载时立一次，此后复用）。
        if rowIconBatcher == nil {
            rowIconBatcher = BatchWriteback { batch in
                // A-37-3：写共享缓存（路径为键），再 bump iconEpoch 触发重绘。
                for (path, image) in batch { ThumbnailCache.set(image, for: path) }
                self.iconEpoch += 1
            }
        }
        // A-1（SIDE-33）：大小/修改时间复用 pair() 的快照，不再二次 stat；
        // 解包途中文件被替换的校验仍用快照值比对。
        let size = job.ipaSize
        let modified = job.ipaModified
        Task.detached { [ipa, path = ipa.path, size, modified] in
            guard let data = IPALibrary.iconData(at: ipa),
                  // A-7：下采样在 detached 里做——行高 44pt，原来用 88×88；
                  // A-37-3：共享缓存按路径只存一份，各处取最大 120，行上显示
                  // 时再缩到 44pt，不模糊。
                  let image = IPALibrary.thumbnail(from: data, maxPixelSize: 120) else { return }
            // B31-1（ECV 同款核对）：解包途中文件被替换就丢掉旧图。
            let liveAttrs = try? FileManager.default.attributesOfItem(atPath: path)
            let liveSize = liveAttrs?[.size] as? Int
            let liveModified = (liveAttrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            guard liveSize == size, liveModified == modified else { return }
            await MainActor.run { self.rowIconBatcher?.enqueue(image, for: path) }
        }
    }

    /// 行首图标：真图 44×44 圆角填满；没图时虚线占位放同尺寸框里，行高对齐。
    /// 两路不同 View 类型，函数前必须加 @ViewBuilder（AGENTS.md 血泪）。
    @ViewBuilder
    private func rowIcon(for status: SideloadedAppStatus, jobsByID: [String: RefreshJob]) -> some View {
        // A-37-3：读 iconEpoch 建立依赖——图标本体在共享缓存里，
        // 批量写回只 bump epoch、不写 @State；不读它，body 不会
        // 重算，图就永远不出现。别把这行当死代码清掉。
        let _ = iconEpoch
        if let path = rowIconPath(for: status, jobsByID: jobsByID), let uiImage = ThumbnailCache.image(for: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
        } else {
            Image(systemName: "app.dashed")
                .font(.title3)
                .foregroundStyle(Theme.brand)
                .frame(width: 44, height: 44)
        }
    }

    private func appRow(_ status: SideloadedAppStatus, jobsByID: [String: RefreshJob]) -> some View {
        let profile = status.current
        let urgency = ExpiryUrgency.of(profile)
        return PanelCard(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                rowIcon(for: status, jobsByID: jobsByID)
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.app.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    // The App ID, which is what a profile is issued against —
                    // the bundle id alone doesn't say which team signed it.
                    Text(profile?.applicationIdentifier ?? status.app.applicationIdentifier ?? status.app.bundleID)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    expiryLabel(profile, urgency: urgency)
                    // 0.9.150: per-row missing-IPA marker — the top note
                    // only gives a count, and a row with no IPA looked
                    // exactly like a refreshable one. Team-excluded apps
                    // have an IPA (they are in pairedBundleIDs), so they
                    // get no marker; the top team note already explains them.
                    if !manager.pairedBundleIDs.contains(status.app.bundleID) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                            Text(L("No IPA on this iPhone"))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted.opacity(0.6))
            }
        }
    }

    /// The one line that matters: how long is left, and the date it runs out.
    @ViewBuilder
    private func expiryLabel(_ profile: ProvisioningProfile?, urgency: ExpiryUrgency) -> some View {
        HStack(spacing: 8) {
            Image(systemName: urgency.symbol)
            Text(ExpiryUrgency.text(for: profile))
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(urgency.color)
    }

    private var emptyState: some View {
        PanelCard {
            VStack(spacing: 8) {
                EmptyState(title: L("No sideloaded apps"),
                           message: L("Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here."),
                           systemImage: "questionmark.app.dashed")
                    .padding(.vertical, 8)
                // U2 (0.9.140): what to do when the read came back empty —
                // the page otherwise leaves only the Load/Reload button.
                Text(L("No apps were read. Tap Reload to read this iPhone again; pair it and turn on Developer Mode first if nothing shows."))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Leftover profiles

    /// Profiles not used by any installed app (e.g. from deleted apps). Useful
    /// because a free Apple ID is limited to ten App IDs a week.
    @ViewBuilder
    private var unmatchedSection: some View {
        if !manager.unmatched.isEmpty {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Unused profiles"))
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.muted)
                    Text(L("Issued to App IDs no installed app is running on."))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Enumerated so rows redraw on a language change (a plain
                // `ForEach` over an `Equatable` array may skip re-rendering).
                ForEach(Array(manager.unmatched.enumerated()), id: \.element.id) { idx, profile in
                    PanelCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.appIDName.isEmpty ? profile.bundleIdentifier : profile.appIDName)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(profile.applicationIdentifier)
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(ExpiryUrgency.text(for: profile))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(ExpiryUrgency.of(profile).color)
                        }
                    }
                    .cascadeItem(7 + manager.entries.count + idx)
                }
            }
            .cascadeItem(6 + manager.entries.count)
        }
    }
}

// MARK: - Detail

/// Everything the device knows about one app: its App ID, the profile it is
/// living on, and the older profiles left behind by earlier signings.
private struct AppProfileDetail: View {
    let status: SideloadedAppStatus

    @EnvironmentObject private var loc: Localizer
    @EnvironmentObject private var certManager: CertManager
    /// F1 (0.9.153): single-app refresh from the detail page — the same
    /// shared instance the list observes (RootView injects it), so the
    /// row's refresh state and lastError stay in sync.
    @EnvironmentObject private var appsManager: SideloadedAppsManager

    @State private var exportURL: URL?
    @State private var exportPassword: String?
    @State private var exportP12Data: Data?
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                appCard.cascadeItem(0)
                renewCard.cascadeItem(1)
                exportCertCard.cascadeItem(2)
                if let current = status.current {
                    profileCard(current, isCurrent: true).cascadeItem(3)
                } else {
                    noProfileCard.cascadeItem(3)
                }
                if !status.superseded.isEmpty {
                    HStack {
                        Text(L("Older profiles"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.muted)
                        Spacer()
                    }
                    .cascadeItem(3)
                    ForEach(Array(status.superseded.enumerated()), id: \.element.id) { idx, profile in
                        profileCard(profile, isCurrent: false).cascadeItem(4 + idx)
                    }
                }
            }
            .padding(20)
        }
        .background(AppBackground())
        .navigationTitle(status.app.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { Self.deleteExportTempFiles() }
    }

    /// F1 (0.9.153): renew just this app — same `refreshAll` the list's
    /// Refresh-all button runs, with only this bundle ID. Only shown when
    /// a paired IPA exists; otherwise there is nothing to re-sign from.
    /// While a refresh runs, the button is disabled (the manager's guard
    /// would refuse it anyway, and this keeps the tap from looking dead).
    @ViewBuilder
    private var renewCard: some View {
        if appsManager.refreshable.contains(where: { $0.bundleID == status.app.bundleID }) {
            PanelCard {
                VStack(spacing: 10) {
                    Button {
                        appsManager.refreshAll(onlyBundleIDs: [status.app.bundleID], fromUI: true)
                    } label: {
                        Label(L("Renew this app"), systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(appsManager.isRefreshing)
                }
            }
        }
    }

    private var appCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(status.app.name)
                    .font(.headline)
                field(L("Bundle Identifier"), status.app.bundleID)
                if let identifier = status.app.applicationIdentifier ?? status.current?.applicationIdentifier {
                    field(L("App ID"), identifier)
                }
                if let version = status.app.version {
                    field(L("Version"), version)
                }
                // F-1 (0.9.162): one-tap open through the app's own URL
                // scheme, parsed from its plist. No scheme, no button.
                // Not gated on canOpenURL: the scheme isn't in
                // LSApplicationQueriesSchemes, so that answer proves
                // nothing (importCertificate 同款） — and a scheme from
                // the installed app itself opens.
                if let scheme = status.app.urlScheme,
                   let url = URL(string: "\(scheme)://") {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label(L("Open"), systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    private var exportCertCard: some View {
        PanelCard {
            VStack(spacing: 10) {
                if let url = exportURL {
                    ShareLink(item: url) {
                        Label(L("Export certificate (p12)"), systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    if let pwd = exportPassword {
                        VStack(spacing: 4) {
                            Text(L("Certificate password:"))
                                .font(.caption)
                                .foregroundColor(Theme.muted)
                            Text(pwd)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(Theme.controlRadius)
                        }
                    }
                    // Direct import into the app on this page (no password input needed):
                    // the certificate travels by URL scheme, so the button goes to
                    // whichever container app this page is for. Apps with no such
                    // receiver keep the old LiveContainer button.
                    if exportP12Data != nil, exportPassword != nil {
                        let target = certificateImportTarget
                        Button {
                            importCertificate(to: target)
                        } label: {
                            Label(L("Import to %@", target.name), systemImage: "arrow.right.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        if let err = exportError {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(Theme.negative)
                        }
                    }
                } else {
                    Button {
                        doExportCert()
                    } label: {
                        HStack(spacing: 10) {
                            if isExporting {
                                ProgressView()
                                Text(L("Exporting"))
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text(L("Export certificate (p12)"))
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isExporting)
                    if let err = exportError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(Theme.negative)
                    }
                }
            }
        }
    }

    /// N4：同 CertsView.deleteExportTempFiles（同款两份）——证书导出把
    /// 明文密码写进 tmp，导出开始时清上一份，页面离开时清最后一份。
    private static func deleteExportTempFiles() {
        let tmp = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tmp.appendingPathComponent("certificate.p12"))
        try? FileManager.default.removeItem(at: tmp.appendingPathComponent("certificate-password.txt"))
    }

    private func doExportCert() {
        isExporting = true
        exportError = nil
        Self.deleteExportTempFiles()
        Task {
            do {
                try await certManager.ensureSignedIn()
                let (p12Data, password) = try certManager.exportP12()
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("certificate.p12")
                try p12Data.write(to: tempURL)
                let pwdURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("certificate-password.txt")
                try password.write(to: pwdURL, atomically: true, encoding: .utf8)
                await MainActor.run {
                    isExporting = false
                    exportURL = tempURL
                    exportPassword = password
                    exportP12Data = p12Data
                }
            } catch is CancellationError {
                // A2：切账号后本次导出作废，不记错。
                await MainActor.run { isExporting = false }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    /// Which app the exported certificate can be handed to, from this page.
    /// LiveContainer and zContainer both take a certificate by URL scheme
    /// (`<scheme>://certificate?cert=…&password=…` — the receiver only looks
    /// at the URL host, so the scheme is the target's own). The installed
    /// bundle ID carries a team suffix (e.g. `.9C27AADJ2K`), so match by
    /// prefix. Any other app has no receiver: fall back to LiveContainer,
    /// as before.
    private var certificateImportTarget: (scheme: String, name: String) {
        let id = status.app.bundleID
        if id == "com.kdt.livecontainer" || id.hasPrefix("com.kdt.livecontainer.") {
            return ("livecontainer", status.app.name)
        }
        if id == "app.reiko.zcontainer" || id.hasPrefix("app.reiko.zcontainer.") {
            return ("zcontainer", status.app.name)
        }
        return ("livecontainer", "LiveContainer")
    }

    /// Open the target container app with the certificate via URL scheme (no password input needed).
    /// Silent no longer: a missing target, an unbuildable link, or a refused
    /// open all leave the reason under the button, instead of the tap doing
    /// nothing (e.g. this iPhone has no LiveContainer, or only a renamed
    /// twin whose scheme doesn't match). `appPresence` can only answer for
    /// schemes in LSApplicationQueriesSchemes, so a `.unknown` answer is not
    /// proof of anything — the open's own Bool is the verdict.
    private func importCertificate(to target: (scheme: String, name: String)) {
        exportError = nil
        guard let p12Data = exportP12Data, let password = exportPassword else { return }
        let b64 = p12Data.base64EncodedString()
        guard let b64Enc = b64.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let pwdEnc = password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(target.scheme)://certificate?cert=\(b64Enc)&password=\(pwdEnc)") else {
            exportError = L("Couldn't build the certificate link.")
            return
        }
        if Engine.appPresence(scheme: target.scheme) == .missing {
            exportError = L("%@ isn't installed on this iPhone, so there's nowhere to import the certificate.", target.name)
            return
        }
        UIApplication.shared.open(url) { opened in
            Task { @MainActor in
                guard !opened else { return }
                self.exportError = L("%@ isn't installed on this iPhone, so there's nowhere to import the certificate.", target.name)
            }
        }
    }

    private func profileCard(_ profile: ProvisioningProfile, isCurrent: Bool) -> some View {
        let urgency = ExpiryUrgency.of(profile)
        return PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: urgency.symbol)
                        .foregroundStyle(urgency.color)
                    Text(ExpiryUrgency.text(for: profile))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(urgency.color)
                    Spacer(minLength: 6)
                    if isCurrent {
                        Text(L("In use"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.accent)
                    }
                }
                if !profile.appIDName.isEmpty {
                    field(L("Profile name"), profile.appIDName)
                }
                if !profile.teamName.isEmpty {
                    field(L("Team"), profile.teamName)
                }
                if let team = profile.teamIdentifier {
                    field(L("Team ID"), team)
                }
                if profile.isWildcard {
                    // A wildcard App ID can't hold per-app capabilities, which
                    // is the usual reason an entitlement won't stick.
                    Text(L("Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities."))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let created = profile.creationDate {
                    field(L("Issued"), created.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Localizer.locale)))
                }
                field(L("Profile UUID"), profile.uuid)
                capabilities(profile)
            }
        }
    }

    @ViewBuilder
    private func capabilities(_ profile: ProvisioningProfile) -> some View {
        let keys = profile.capabilityKeys
        if !keys.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Capabilities"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.top, 2)
        }
    }

    private var noProfileCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 4) {
                Label(L("No matching profile"), systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.medium))
                Text(L("The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that."))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// A labelled value with selectable text, so identifiers can be copied.
    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
