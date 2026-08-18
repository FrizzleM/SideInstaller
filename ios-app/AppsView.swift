import SwiftUI

// MARK: - Models

/// One provisioning profile, decoded from the CMS blob misagent hands back.
///
/// The signature is not checked. The device already refused to install anything
/// whose profile it didn't trust, so re-verifying here would only tell us what
/// the device has already decided — and the plist inside is what the page needs.
/// The payload is extracted by scanning for the plist rather than by running the
/// blob through `CMSDecoder`, which is StikDebug's route too.
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
    /// The profile's own entitlements, i.e. what an app signed with it is
    /// allowed to do. Kept as a plist dictionary — the values are of every type.
    let entitlements: [String: Any]

    var id: String { uuid }

    /// Only the identity matters for equality: the rest is decoded from the same
    /// bytes, and `[String: Any]` isn't `Equatable` anyway.
    static func == (lhs: ProvisioningProfile, rhs: ProvisioningProfile) -> Bool {
        lhs.uuid == rhs.uuid && lhs.expirationDate == rhs.expirationDate
    }

    /// The bundle id with the team prefix stripped, which is what the user
    /// recognises. `A1B2C3D4E5.com.example.app` → `com.example.app`.
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

    /// True when the App ID is a wildcard, which is what a free Apple ID gets
    /// for anything it hasn't registered explicitly.
    var isWildcard: Bool { applicationIdentifier.hasSuffix("*") }

    /// Whole days from today until it lapses; negative once it has. Counted in
    /// calendar days, so "expires tomorrow" reads as 1 whatever the clock says.
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

    /// The entitlement keys worth showing: every profile carries the same four
    /// pieces of bookkeeping, and listing those on each app would bury the
    /// capabilities that actually differ.
    var capabilityKeys: [String] {
        let boilerplate: Set<String> = [
            "application-identifier",
            "com.apple.developer.team-identifier",
            "keychain-access-groups",
            "get-task-allow",
        ]
        return entitlements.keys.filter { !boilerplate.contains($0) }.sorted()
    }

    /// Decode one `.mobileprovision` payload. Returns nil when the bytes hold no
    /// readable plist, which is the only failure worth having — a profile that
    /// won't decode is simply left out of the page.
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
    /// The `TEAMID.bundle.id` baked into the app's own entitlements at signing.
    /// Present on everything free-signed; the profile match falls back to the
    /// bundle id when it isn't.
    let applicationIdentifier: String?

    var id: String { bundleID }

    /// `ProfileValidated` is installd's own mark that the app was installed
    /// against a provisioning profile. App Store apps don't carry it, which is
    /// what makes it the filter for this page.
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

/// An installed app together with every profile on the device that could have
/// signed it, newest expiry first. More than one is normal: each re-signing
/// leaves its profile behind, and the device keeps them all.
struct SideloadedAppStatus: Identifiable, Equatable {

    let app: SideloadedApp
    let profiles: [ProvisioningProfile]

    var id: String { app.bundleID }

    /// The one the app is actually living on: the profile that lapses last.
    var current: ProvisioningProfile? { profiles.first }

    /// Profiles kept only for history, shown on the detail page.
    var superseded: [ProvisioningProfile] { Array(profiles.dropFirst()) }

    /// What to sort on. Apps with no profile at all sort last — they are the
    /// odd case, and putting them above something expiring today would be wrong.
    var sortKey: Date { current?.expirationDate ?? .distantFuture }
}

/// How urgent an expiry is, and the colour that says so. The bands are
/// AltStore's, by way of StikDebug: a free profile lasts seven days, so a week
/// is the whole scale.
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

    /// The line the whole page turns on: "Expires today", "Expires in 5 days —
    /// 23 Aug", "Expired 12 Aug". Anything more than a month out gets the date
    /// alone — a countdown only means something against a seven-day grant.
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

/// Pairs installed apps with the profiles that signed them. Free of any device
/// or UI state on purpose: this is the only part with real logic in it, and
/// keeping it static makes it something that can be exercised on its own.
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
        // Second index, because installation_proxy doesn't always report an
        // app's `application-identifier` — then the bare bundle id is all there
        // is to match a profile on.
        let byBundleID = Dictionary(grouping: specific, by: \.bundleIdentifier)

        var claimed = Set<String>()
        let entries = apps.map { app -> SideloadedAppStatus in
            let matched = matchingProfiles(for: app, byAppID: byAppID,
                                           byBundleID: byBundleID, wildcards: wildcards)
            claimed.formUnion(matched.map(\.uuid))
            return SideloadedAppStatus(app: app, profiles: matched)
        }

        // Left over: profiles for apps that have since been deleted, and
        // wildcards nothing had to fall back on. Worth showing, because they are
        // what fills a free account's App ID list up.
        let unmatched = sorted.filter { !claimed.contains($0.uuid) }

        return (entries.sorted(by: order), unmatched)
    }

    /// Soonest expiry first: the whole point of the page is spotting what is
    /// about to stop launching, so that has to be the top of the list.
    private static func order(_ lhs: SideloadedAppStatus, _ rhs: SideloadedAppStatus) -> Bool {
        if lhs.sortKey != rhs.sortKey { return lhs.sortKey < rhs.sortKey }
        return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
    }

    /// The profiles that could have signed `app`, latest expiry first.
    ///
    /// A profile issued for this bundle id specifically wins outright: it is what
    /// was embedded in the bundle at signing, so it is what the app is actually
    /// living on. Only when there is none does a wildcard count — merging the
    /// two would let the team's long-lived wildcard mask the real expiry date of
    /// an app whose own profile runs out tomorrow.
    private static func matchingProfiles(for app: SideloadedApp,
                                         byAppID: [String: [ProvisioningProfile]],
                                         byBundleID: [String: [ProvisioningProfile]],
                                         wildcards: [ProvisioningProfile]) -> [ProvisioningProfile] {
        let target = app.applicationIdentifier ?? app.bundleID
        let specific = (byAppID[target] ?? []) + (byBundleID[app.bundleID] ?? [])
        if !specific.isEmpty { return deduplicated(specific) }
        return deduplicated(wildcards.filter { covers(pattern: $0.applicationIdentifier, app) })
    }

    /// Does a wildcard App ID cover this app? Tried against the app's own
    /// identifier first, then — since that may be missing — against the bare
    /// bundle id, with the pattern's team prefix taken off to match.
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

    /// One entry per profile, latest expiry first. The two indexes above overlap
    /// whenever an app reports its identifier, so this runs on every result.
    private static func deduplicated(_ profiles: [ProvisioningProfile]) -> [ProvisioningProfile] {
        var seen = Set<String>()
        return profiles
            .filter { seen.insert($0.uuid).inserted }
            .sorted { expiry($0) > expiry($1) }
    }

    private static func expiry(_ profile: ProvisioningProfile) -> Date {
        profile.expirationDate ?? .distantPast
    }
}

// MARK: - Manager

/// Drives the Sideloaded apps page: one trip to the device for what's installed
/// and what profiles it holds, then the matching above. Nothing is written, so
/// unlike the other device pages this one has no failure worth recovering from —
/// a load either works or says why.
@MainActor
final class SideloadedAppsManager: ObservableObject {

    @Published private(set) var entries: [SideloadedAppStatus] = []
    /// Profiles belonging to no installed app — deleted apps' leftovers.
    @Published private(set) var unmatched: [ProvisioningProfile] = []
    @Published private(set) var isWorking = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var lastRefreshed: Date?
    @Published var lastError: String?

    private var engine: Engine { Engine.shared }

    /// Keeps `autoLoad` to a single attempt, so a page opened before the tunnel
    /// is up doesn't retry on every visit.
    private var didAutoLoad = false

    /// The apps that need re-signing within a day, which is what the header
    /// pill counts.
    var expiringSoon: Int {
        entries.filter { status in
            switch ExpiryUrgency.of(status.current) {
            case .expired, .critical: return true
            default: return false
            }
        }.count
    }

    /// Load once when the page opens, quietly. Arriving here before the VPN is
    /// up shouldn't paint an error nobody asked for — the button below says it
    /// plainly enough when the user does ask.
    func autoLoad() {
        guard !didAutoLoad, !hasLoaded, !isWorking else { return }
        didAutoLoad = true
        load(quiet: true)
    }

    /// Ask the device what it has. `quiet` logs failures instead of showing them.
    func load(quiet: Bool = false) {
        guard !isWorking else { return }
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
}

// MARK: - View

/// The Sideloaded apps page: what this device is carrying that SideInstaller (or
/// anything else signing with a free Apple ID) put there, which App ID each one
/// runs under, and how long it has left. Pushed from Tools, whose
/// `NavigationStack` this relies on.
struct AppsView: View {
    /// Declared so every label on this screen redraws when the language changes.
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var manager: SideloadedAppsManager

    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header.cascadeItem(0)
                loadButton.cascadeItem(1)
                if let error = manager.lastError {
                    errorCallout(error).transition(.cardAppear)
                }
                appList
                unmatchedSection
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: manager.lastError)
            .animation(.smooth(duration: 0.35), value: manager.entries)
            .animation(.smooth(duration: 0.3), value: manager.isWorking)
        }
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { manager.autoLoad() }
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

    private var loadButton: some View {
        Button { manager.load() } label: {
            HStack(spacing: 10) {
                if manager.isWorking {
                    ProgressView().tint(.white)
                    Text(L("Reading the device"))
                } else {
                    Image(systemName: manager.hasLoaded ? "arrow.clockwise" : "iphone.and.arrow.forward")
                        .contentTransition(.symbolEffect(.replace))
                    Text(manager.hasLoaded ? L("Refresh") : L("Load apps"))
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(manager.isWorking)
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
                .cascadeItem(2)
                ForEach(Array(manager.entries.enumerated()), id: \.element.id) { idx, status in
                    NavigationLink {
                        AppProfileDetail(status: status)
                    } label: {
                        appRow(status)
                    }
                    .buttonStyle(.plain)
                    .cascadeItem(3 + idx)
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

    /// Profiles nothing on the device is running on: leftovers from apps that
    /// have been deleted, and App IDs nothing is signed with right now. A free
    /// Apple ID is capped at ten App IDs a week, so knowing what is taking up
    /// the room is genuinely useful.
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
                // Enumerated, like the list above: a `ForEach` straight over an
                // `Equatable` array lets SwiftUI skip re-evaluating these rows,
                // and a language switch then leaves them in the old copy.
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
                    .cascadeItem(4 + manager.entries.count + idx)
                }
            }
            .cascadeItem(3 + manager.entries.count)
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

    /// One labelled, selectable line. The identifiers here are things people
    /// copy into bug reports, so they are worth being able to select.
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
