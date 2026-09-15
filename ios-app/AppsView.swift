import SwiftUI

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

    var id: String { bundleID }

    /// Returns nil unless `ProfileValidated` is set. installd sets it only for
    /// apps installed with a provisioning profile, not App Store apps.
    init?(plist: [String: Any]) {
        guard plist["ProfileValidated"] != nil,
              let bundleID = plist["CFBundleIdentifier"] as? String else { return nil }
        self.bundleID = bundleID
        let display = plist["CFBundleDisplayName"] as? String
        let bundleName = plist["CFBundleName"] as? String
        self.name = display?.isEmpty == false ? display! : (bundleName?.isEmpty == false ? bundleName! : bundleID)
        self.version = plist["CFBundleShortVersionString"] as? String
        let entitlements = plist["Entitlements"] as? [String: Any]
        self.applicationIdentifier = entitlements?["application-identifier"] as? String
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
        case .expired, .critical: return .red
        case .soon:               return .orange
        case .later:              return .yellow
        case .comfortable:        return .green
        case .unknown:            return .secondary
        }
    }

    var symbol: String {
        switch self {
        case .expired:  return "exclamationmark.triangle.fill"
        case .critical: return "clock.badge.exclamationmark.fill"
        case .unknown:  return "questionmark.circle"
        default:        return "clock.fill"
        }
    }

    /// Expiry text, e.g. "Expires today", "Expires in 5 days — 23 Aug",
    /// "Expired 12 Aug". More than 30 days out shows only the date.
    static func text(for profile: ProvisioningProfile?) -> String {
        guard let profile, let expiration = profile.expirationDate else {
            return L("No matching profile")
        }
        let formatted = expiration.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Localizer.locale))
        if profile.isExpired { return L("Expired %@", formatted) }
        switch profile.daysRemaining {
        case 0:            return L("Expires today")
        case 1:            return L("Expires tomorrow")
        case .some(2...30): return L("Expires in %d days — %@", profile.daysRemaining ?? 0, formatted)
        default:           return L("Expires %@", formatted)
        }
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
    /// Team ID the app is currently signed under (from its current profile).
    let teamID: String?
    var state: State = .pending

    var id: String { bundleID }
}

// MARK: - Manager

/// Drives the Sideloaded apps page: loads installed apps and profiles from the
/// device, matches them, and runs "Refresh all" through the install pipeline.
@MainActor
final class SideloadedAppsManager: ObservableObject {

    @Published private(set) var entries: [SideloadedAppStatus] = []
    /// Profiles belonging to no installed app — deleted apps' leftovers.
    @Published private(set) var unmatched: [ProvisioningProfile] = []
    @Published private(set) var isWorking = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var lastRefreshed: Date?
    @Published var lastError: String?

    /// The apps a refresh can act on: an installed app whose IPA is still in
    /// Documents. Rebuilt on every load.
    @Published private(set) var refreshable: [RefreshJob] = []
    /// Apps on the page with no IPA to sign again from, for the note that says
    /// why they aren't included.
    @Published private(set) var unrefreshable = 0
    /// The run in progress, or the last one's results until another starts.
    @Published private(set) var jobs: [RefreshJob] = []
    @Published private(set) var isRefreshing = false
    /// What the refresh is doing right now, shown on the button.
    @Published private(set) var refreshStatus: String?
    /// How the last finished run went, e.g. "Refreshed 2 of 3 apps."
    @Published private(set) var refreshSummary: String?

    private var engine: Engine { Engine.shared }

    /// Keeps `autoLoad` to a single attempt, so a page opened before the tunnel
    /// is up doesn't retry on every visit.
    private var didAutoLoad = false

    /// The refresh in flight, kept so it can be called off between apps.
    private var refreshTask: Task<Void, Never>?

    /// Number of apps expiring within a day (shown in the header pill).
    var expiringSoon: Int {
        entries.filter { status in
            switch ExpiryUrgency.of(status.current) {
            case .expired, .critical: return true
            default: return false
            }
        }.count
    }

    /// Loads once when the page opens, without showing errors (e.g. when the VPN
    /// isn't up yet).
    func autoLoad() {
        guard !didAutoLoad, !hasLoaded, !isWorking else { return }
        didAutoLoad = true
        load(quiet: true)
    }

    /// Ask the device what it has. `quiet` logs failures instead of showing them.
    func load(quiet: Bool = false) {
        guard !isWorking, !isRefreshing else { return }
        isWorking = true
        lastError = nil
        if !quiet { engine.log("=== Sideloaded apps: reading the device ===") }
        Task {
            do {
                let inventory = try await engine.sideloadedAppInventory()
                let apps = inventory.apps.compactMap(SideloadedApp.init(plist:))
                let profiles = inventory.profiles.compactMap(ProvisioningProfile.init(data:))
                let matched = ProfileMatcher.match(apps: apps, profiles: profiles)
                entries = matched.entries
                unmatched = matched.unmatched
                await rebuildRefreshable()
                hasLoaded = true
                lastRefreshed = Date()
                engine.log("Sideloaded apps: \(apps.count) sideloaded, \(profiles.count) profile(s) decoded.")
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                if quiet {
                    engine.log("Sideloaded apps: not ready yet (\(message))")
                } else {
                    lastError = message
                    engine.log("⛔️ Sideloaded apps: \(message)")
                }
            }
            isWorking = false
        }
    }

    // MARK: - Refresh all

    /// Re-signs and reinstalls every refreshable app, one at a time (they share
    /// one device link and signing queue, and Apple's API is rate-limited).
    func refreshAll() {
        guard !isRefreshing, !isWorking, !refreshable.isEmpty else { return }
        guard !engine.isRunning else {
            lastError = L("An install is already running. Wait for it to finish, then refresh.")
            return
        }
        jobs = refreshable
        isRefreshing = true
        lastError = nil
        refreshSummary = nil
        refreshStatus = L("Getting ready")
        engine.log("=== Refresh all: \(jobs.count) app(s) ===")

        refreshTask = Task {
            defer {
                isRefreshing = false
                refreshStatus = nil
                refreshTask = nil
            }
            do {
                try await engine.prepareRefresh()
            } catch {
                let message = Self.text(for: error)
                lastError = message
                engine.log("⛔️ Refresh all: \(message)")
                jobs = []
                return
            }

            var refreshed = 0
            for index in jobs.indices {
                // Cancellation is checked between apps; signing and installing
                // can't be interrupted midway.
                if Task.isCancelled { break }
                let job = jobs[index]
                // Skip apps signed by a different team: the new bundle ID would
                // install a second copy instead of replacing the app.
                if let team = engine.signingTeamID, let installed = job.teamID, installed != team {
                    jobs[index].state = .failed(
                        L("Signed by team %@, not the one you're signed in as — refreshing it here would install a second copy.", installed))
                    continue
                }
                jobs[index].state = .working
                refreshStatus = L("Refreshing %@", job.name)
                do {
                    try await engine.refreshInstalledApp(named: job.name, ipaPath: job.ipa.path)
                    jobs[index].state = .done
                    refreshed += 1
                } catch {
                    let message = Self.text(for: error)
                    jobs[index].state = .failed(message)
                    engine.log("⛔️ Refresh \(job.name): \(message)")
                }
            }

            refreshSummary = jobs.count == 1
                ? (refreshed == 1 ? L("Refreshed. Its seven days start again now.")
                                  : L("Nothing was refreshed."))
                : L("Refreshed %d of %d apps.", refreshed, jobs.count)
            engine.log("Refresh all finished: \(refreshed)/\(jobs.count) refreshed.")
            // Read the device again, so the days on screen are the new ones.
            if refreshed > 0 {
                isRefreshing = false        // `load` won't run while a refresh holds the link
                load(quiet: true)
            }
        }
    }

    /// Stops the run after the current app finishes. Remaining apps are left
    /// unchanged.
    func cancelRefresh() {
        guard isRefreshing, refreshTask != nil else { return }
        refreshTask?.cancel()
        refreshStatus = L("Stopping after this app")
        engine.log("Refresh all: stopping after the current app.")
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
        let matched = await Task.detached(priority: .userInitiated) {
            SideloadedAppsManager.pair(installed, with: IPALibrary.installable())
        }.value
        refreshable = matched
        unrefreshable = max(0, entries.count - matched.count)
        engine.log("Sideloaded apps: \(matched.count) of \(entries.count) can be refreshed from an IPA on disk.")
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
                              ipa: match.entry.url, teamID: app.teamID)
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
    @EnvironmentObject private var engine: Engine
    @ObservedObject var manager: SideloadedAppsManager

    @State private var showSettings = false
    /// Shows the "Refresh all" confirmation alert.
    @State private var confirmRefresh = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header.cascadeItem(0)
                refreshAllButton
                loadButton
                refreshRunCard
                if let error = manager.lastError {
                    errorCallout(error).transition(.cardAppear)
                }
                appList
                refreshNote
                unmatchedSection
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: manager.lastError)
            .animation(.smooth(duration: 0.35), value: manager.entries)
            .animation(.smooth(duration: 0.3), value: manager.isWorking)
            .animation(.smooth(duration: 0.35), value: manager.jobs)
            .animation(.smooth(duration: 0.35), value: manager.refreshable)
        }
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { manager.autoLoad() }
        .alert(L("Refresh all apps?"), isPresented: $confirmRefresh) {
            Button(L("Refresh all")) { manager.refreshAll() }
            Button(L("Cancel"), role: .cancel) { }
        } message: {
            Text(manager.refreshable.count == 1
                 ? L("%@ will be signed again with your Apple ID and installed over the copy on this device. It keeps its data, and its seven days start over.",
                     manager.refreshable.first?.name ?? "")
                 : L("%d apps will be signed again with your Apple ID and installed over the copies on this device. They keep their data, and their seven days start over.",
                     manager.refreshable.count))
        }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "app.badge.clock", image: "AppsLogo", title: L("Sideloaded apps")) {
            if manager.hasLoaded {
                let expiring = manager.expiringSoon
                StatusPill(text: expiring > 0
                             ? (expiring == 1 ? L("%d app needs refreshing", expiring)
                                              : L("%d apps need refreshing", expiring))
                             : (manager.entries.count == 1 ? L("%d app", manager.entries.count)
                                                           : L("%d apps", manager.entries.count)),
                           systemImage: expiring > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                           color: expiring > 0 ? .orange : .green)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
            }
        }
    }

    // MARK: Primary action

    /// "Refresh all" button, shown when at least one app can be refreshed.
    @ViewBuilder
    private var refreshAllButton: some View {
        if manager.hasLoaded && !manager.refreshable.isEmpty {
            VStack(spacing: 8) {
                Button { confirmRefresh = true } label: {
                    HStack(spacing: 10) {
                        if manager.isRefreshing {
                            ProgressView().tint(.white)
                            Text(manager.refreshStatus ?? L("Getting ready"))
                                .lineLimit(1)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(L("Refresh all"))
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(manager.isRefreshing || manager.isWorking)
                // Only the install step reports progress.
                if manager.isRefreshing, engine.installProgress > 0, engine.installProgress < 1 {
                    ProgressView(value: engine.installProgress)
                        .tint(Theme.accent2)
                }
                Text(manager.refreshable.count == 1
                     ? L("%d app can be signed again from an IPA already on this iPhone.",
                         manager.refreshable.count)
                     : L("%d apps can be signed again from IPAs already on this iPhone.",
                         manager.refreshable.count))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
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
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Theme.accent)
            .cascadeItem(2)
        } else if manager.hasLoaded && !manager.refreshable.isEmpty {
            Button { manager.load() } label: {
                loadLabel(spinner: Theme.accent).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Theme.accent)
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
        HStack(spacing: 10) {
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    // Enumerated so rows redraw on a language change.
                    ForEach(Array(manager.jobs.enumerated()), id: \.element.id) { _, job in
                        jobRow(job)
                    }
                    if let summary = manager.refreshSummary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .transition(.cardAppear)
            .cascadeItem(3)
        }
    }

    private func jobRow(_ job: RefreshJob) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                jobIcon(job.state)
                Text(job.name)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 6)
                Text(Self.stateText(job.state))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Self.stateColor(job.state))
            }
            if case let .failed(message) = job.state {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func jobIcon(_ state: RefreshJob.State) -> some View {
        switch state {
        case .pending:  Image(systemName: "clock").foregroundStyle(.tertiary)
        case .working:  ProgressView().controlSize(.small)
        case .done:     Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:   Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
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
        case .pending, .working: return .secondary
        case .done:              return .green
        case .failed:            return .red
        }
    }

    /// Note explaining that apps without an IPA in SideInstaller can't be
    /// refreshed.
    @ViewBuilder
    private var refreshNote: some View {
        if manager.hasLoaded && manager.unrefreshable > 0 && !manager.entries.isEmpty {
            Text(manager.unrefreshable == 1
                 ? L("%d app here has no IPA in SideInstaller, so it can't be refreshed from this page. Refresh it in whatever installed it, or import its .ipa first.",
                     manager.unrefreshable)
                 : L("%d apps here have no IPA in SideInstaller, so they can't be refreshed from this page. Refresh them in whatever installed them, or import their .ipa first.",
                     manager.unrefreshable))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cascadeItem(5 + manager.entries.count)
        }
    }

    // MARK: App list

    @ViewBuilder
    private var appList: some View {
        if manager.hasLoaded && manager.entries.isEmpty && !manager.isWorking {
            emptyState.transition(.cardAppear)
        } else if !manager.entries.isEmpty {
            VStack(spacing: 14) {
                HStack {
                    Text(manager.entries.count == 1
                         ? L("%d app", manager.entries.count)
                         : L("%d apps", manager.entries.count))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let refreshed = manager.lastRefreshed {
                        Text(refreshed.formatted(Date.FormatStyle(date: .omitted, time: .shortened)
                                                     .locale(Localizer.locale)))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .cascadeItem(4)
                ForEach(Array(manager.entries.enumerated()), id: \.element.id) { idx, status in
                    NavigationLink {
                        AppProfileDetail(status: status)
                    } label: {
                        appRow(status)
                    }
                    .buttonStyle(.plain)
                    .cascadeItem(5 + idx)
                }
            }
        }
    }

    private func appRow(_ status: SideloadedAppStatus) -> some View {
        let profile = status.current
        let urgency = ExpiryUrgency.of(profile)
        return PanelCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "app.dashed")
                    .font(.title3)
                    .foregroundStyle(Theme.brand)
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.app.name)
                        .font(.subheadline.weight(.semibold))
                    // The App ID, which is what a profile is issued against —
                    // the bundle id alone doesn't say which team signed it.
                    Text(profile?.applicationIdentifier ?? status.app.applicationIdentifier ?? status.app.bundleID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    expiryLabel(profile, urgency: urgency)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// The one line that matters: how long is left, and the date it runs out.
    @ViewBuilder
    private func expiryLabel(_ profile: ProvisioningProfile?, urgency: ExpiryUrgency) -> some View {
        HStack(spacing: 6) {
            Image(systemName: urgency.symbol)
            Text(ExpiryUrgency.text(for: profile))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(urgency.color)
        .padding(.top, 1)
    }

    private var emptyState: some View {
        PanelCard {
            VStack(spacing: 8) {
                Image(systemName: "questionmark.app.dashed")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.brand)
                Text(L("No sideloaded apps"))
                    .font(.headline)
                Text(L("Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: Leftover profiles

    /// Profiles not used by any installed app (e.g. from deleted apps). Useful
    /// because a free Apple ID is limited to ten App IDs a week.
    @ViewBuilder
    private var unmatchedSection: some View {
        if !manager.unmatched.isEmpty {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Unused profiles"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L("Issued to App IDs no installed app is running on."))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Enumerated so rows redraw on a language change (a plain
                // `ForEach` over an `Equatable` array may skip re-rendering).
                ForEach(Array(manager.unmatched.enumerated()), id: \.element.id) { idx, profile in
                    PanelCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.appIDName.isEmpty ? profile.bundleIdentifier : profile.appIDName)
                                .font(.subheadline.weight(.semibold))
                            Text(profile.applicationIdentifier)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(ExpiryUrgency.text(for: profile))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ExpiryUrgency.of(profile).color)
                        }
                    }
                    .cascadeItem(7 + manager.entries.count + idx)
                }
            }
            .cascadeItem(6 + manager.entries.count)
        }
    }

    // MARK: Error

    private func errorCallout(_ message: String) -> some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Something went wrong"))
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Detail

/// Everything the device knows about one app: its App ID, the profile it is
/// living on, and the older profiles left behind by earlier signings.
private struct AppProfileDetail: View {
    let status: SideloadedAppStatus

    @EnvironmentObject private var loc: Localizer

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                appCard.cascadeItem(0)
                if let current = status.current {
                    profileCard(current, isCurrent: true).cascadeItem(1)
                } else {
                    noProfileCard.cascadeItem(1)
                }
                if !status.superseded.isEmpty {
                    HStack {
                        Text(L("Older profiles"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .cascadeItem(2)
                    ForEach(Array(status.superseded.enumerated()), id: \.element.id) { idx, profile in
                        profileCard(profile, isCurrent: false).cascadeItem(3 + idx)
                    }
                }
            }
            .padding(20)
        }
        .background(AppBackground())
        .navigationTitle(status.app.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(status.app.name)
                    .font(.title3.weight(.bold))
                field(L("Bundle identifier"), status.app.bundleID)
                if let identifier = status.app.applicationIdentifier ?? status.current?.applicationIdentifier {
                    field(L("App ID"), identifier)
                }
                if let version = status.app.version {
                    field(L("Version"), version)
                }
            }
        }
    }

    private func profileCard(_ profile: ProvisioningProfile, isCurrent: Bool) -> some View {
        let urgency = ExpiryUrgency.of(profile)
        return PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: urgency.symbol)
                        .foregroundStyle(urgency.color)
                    Text(ExpiryUrgency.text(for: profile))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(urgency.color)
                    Spacer(minLength: 6)
                    if isCurrent {
                        Text(L("In use"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.accent2)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.accent.opacity(0.18)))
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
                        .foregroundStyle(.secondary)
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.top, 2)
        }
    }

    private var noProfileCard: some View {
        CalloutCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 6) {
                Label(L("No matching profile"), systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                Text(L("The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// A labelled value with selectable text, so identifiers can be copied.
    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
