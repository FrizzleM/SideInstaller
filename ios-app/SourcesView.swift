import SwiftUI

// MARK: - Source format

/// An app source in the AltStore format, the JSON SideStore and AltStore read:
/// a name, and the apps it offers with their versions and release notes.
/// Decoded leniently: an app the source describes badly is left out rather
/// than failing the whole source.
struct AppSource: Decodable, Equatable {
    let name: String
    let identifier: String?
    let iconURL: URL?
    let website: URL?
    let apps: [SourceApp]

    private enum CodingKeys: String, CodingKey {
        case name, identifier, iconURL, website, apps
    }

    /// Who makes the apps: the developer every app names, or the first one's.
    var developerName: String? {
        apps.lazy.compactMap(\.developerName).first { !$0.isEmpty }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        identifier = try? c.decode(String.self, forKey: .identifier)
        iconURL = SourceApp.url(try? c.decode(String.self, forKey: .iconURL))
        website = SourceApp.url(try? c.decode(String.self, forKey: .website))
        let entries = (try? c.decode([Lenient<SourceApp>].self, forKey: .apps)) ?? []
        apps = entries.compactMap(\.value)
    }

    /// Wraps an element so one that fails to decode becomes nil.
    private struct Lenient<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }
}

/// One app a source offers.
struct SourceApp: Decodable, Equatable {
    let bundleIdentifier: String
    let name: String
    let developerName: String?
    let subtitle: String?
    let localizedDescription: String?
    let iconURL: URL?
    /// Newest first. Built from the app's top-level `version` and
    /// `downloadURL` for a source that has no `versions` list.
    let versions: [SourceVersion]

    var latest: SourceVersion? { versions.first }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, name, developerName, subtitle, localizedDescription,
             iconURL, versions, version, versionDate, versionDescription, downloadURL, size,
             patreon
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // AltStore shows an app with Patreon terms only to the developer's
        // patrons, and its downloads are patreon.com links that need their
        // Patreon sign-in: AltStore's own source lists its betas that way.
        if c.contains(.patreon), (try? c.decodeNil(forKey: .patreon)) == false {
            throw DecodingError.dataCorruptedError(forKey: .patreon, in: c,
                                                   debugDescription: "only for Patreon backers")
        }
        bundleIdentifier = try c.decode(String.self, forKey: .bundleIdentifier)
        name = try c.decode(String.self, forKey: .name)
        developerName = try? c.decode(String.self, forKey: .developerName)
        subtitle = try? c.decode(String.self, forKey: .subtitle)
        localizedDescription = try? c.decode(String.self, forKey: .localizedDescription)
        iconURL = Self.url(try? c.decode(String.self, forKey: .iconURL))

        var versions = ((try? c.decode([Lenient].self, forKey: .versions)) ?? []).compactMap(\.value)
        if versions.isEmpty,
           let version = try? c.decode(String.self, forKey: .version),
           let link = Self.url(try? c.decode(String.self, forKey: .downloadURL)) {
            versions = [SourceVersion(
                version: version,
                date: SourceVersion.date(try? c.decode(String.self, forKey: .versionDate)),
                notes: try? c.decode(String.self, forKey: .versionDescription),
                downloadURL: link,
                size: try? c.decode(Int64.self, forKey: .size))]
        }
        guard !versions.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .versions, in: c,
                                                   debugDescription: "no version to install")
        }
        self.versions = versions
    }

    /// An http(s) link, or nil for anything else.
    static func url(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http"
        else { return nil }
        return url
    }

    private struct Lenient: Decodable {
        let value: SourceVersion?
        init(from decoder: Decoder) throws { value = try? SourceVersion(from: decoder) }
    }
}

/// One version of a source's app, with its release notes.
struct SourceVersion: Decodable, Equatable, Identifiable {
    let version: String
    let date: Date?
    let notes: String?
    let downloadURL: URL
    let size: Int64?

    var id: String { version + "|" + downloadURL.absoluteString }

    init(version: String, date: Date?, notes: String?, downloadURL: URL, size: Int64?) {
        self.version = version
        self.date = date
        self.notes = notes
        self.downloadURL = downloadURL
        self.size = size
    }

    private enum CodingKeys: String, CodingKey {
        case version, date, localizedDescription, downloadURL, size
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        guard let link = SourceApp.url(try c.decode(String.self, forKey: .downloadURL)) else {
            throw DecodingError.dataCorruptedError(forKey: .downloadURL, in: c,
                                                   debugDescription: "not an https link")
        }
        downloadURL = link
        date = Self.date(try? c.decode(String.self, forKey: .date))
        notes = try? c.decode(String.self, forKey: .localizedDescription)
        size = try? c.decode(Int64.self, forKey: .size)
    }

    /// Sources write dates as ISO 8601, with or without the time.
    static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let full = ISO8601DateFormatter()
        if let date = full.date(from: text) { return date }
        full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = full.date(from: text) { return date }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(identifier: "UTC")
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: String(text.prefix(10)))
    }
}

/// An app as the Sources page lists it: the app, the source it came from, and
/// what is installed of it.
struct SourceListing: Identifiable, Equatable {
    let app: SourceApp
    let sourceURL: URL
    let sourceName: String
    /// The version on this iPhone, when the device has been read.
    let installedVersion: String?

    /// With the newest download too: a source may list several builds of one
    /// app under the same bundle id.
    var id: String {
        [sourceURL.absoluteString, app.bundleIdentifier, app.latest?.downloadURL.absoluteString ?? ""]
            .joined(separator: "|")
    }

    /// True when the source has a newer version than the installed one.
    var hasUpdate: Bool {
        guard let installedVersion, let latest = app.latest?.version else { return false }
        return UpdateChecker.isNewer(latest, than: installedVersion)
    }

    /// True when this iPhone has a newer version than `version`, so installing
    /// it goes back one. A source can lag behind the app's releases, and then
    /// even its newest version does: in November 2026 SideStore's own source
    /// still listed 0.6.2, though SideStore had released 0.6.4.
    func isDowngrade(to version: SourceVersion) -> Bool {
        guard let installedVersion else { return false }
        return UpdateChecker.isNewer(installedVersion, than: version.version)
    }
}

// MARK: - Manager

/// The sources the user added, what they offer, and which of their apps have
/// updates. Owned by `RootView`, so it survives tab switches. Installs go
/// through the same path as a `sideinstaller://install` link: the link popup
/// asks first, then the Install tab downloads, signs and installs.
@MainActor
final class SourcesManager: ObservableObject {

    /// A source's state after its last fetch.
    enum SourceState: Equatable {
        case loading
        case loaded(AppSource)
        case failed(String)
    }

    /// The sources, in the order they were added.
    @Published private(set) var urls: [URL] = []
    @Published private(set) var states: [URL: SourceState] = [:]
    @Published private(set) var isAdding = false
    /// Why the last add failed, shown under the field.
    @Published var addError: String?

    private static let storeKey = "sources.urls"

    /// Sources every copy of SideInstaller starts with, listed first. They
    /// can't be removed: FrizzleM's own, with SideInstaller in it, kept up to
    /// date with each release by the update-altsource workflow.
    static let builtIn: [URL] = [
        URL(string: "https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/frizzlem.json")!,
    ]

    init() {
        let saved = (UserDefaults.standard.stringArray(forKey: Self.storeKey) ?? [])
            .compactMap(URL.init(string:))
        urls = Self.builtIn + saved.filter { !Self.builtIn.contains($0) }
    }

    func isBuiltIn(_ url: URL) -> Bool { Self.builtIn.contains(url) }

    /// A well-known source offered under "Add a source", one tap to add.
    struct Suggestion: Identifiable {
        let name: String
        let developer: String
        let url: URL
        /// The GitHub account whose picture stands for the developer.
        let gitHub: String

        var id: URL { url }
        var picture: URL? { URL(string: "https://github.com/\(gitHub).png?size=128") }
    }

    /// The official sources of the apps SideInstaller installs. Any other
    /// source is added by its link.
    static let suggestions: [Suggestion] = [
        Suggestion(name: "SideStore", developer: "SideStore",
                   url: URL(string: "https://apps.sidestore.io")!, gitHub: "SideStore"),
        Suggestion(name: "AltStore", developer: "AltStore",
                   url: URL(string: "https://apps.altstore.io")!, gitHub: "altstoreio"),
        Suggestion(name: "LiveContainer + SideStore", developer: "LiveContainer",
                   url: URL(string: "https://github.com/LiveContainer/LiveContainer/releases/download/1.0/apps_ss_lc.json")!,
                   gitHub: "LiveContainer"),
    ]

    /// The suggestions not added yet.
    var openSuggestions: [Suggestion] {
        Self.suggestions.filter { !urls.contains($0.url) }
    }

    var isRefreshing: Bool { states.values.contains(.loading) }

    /// Every app of every source that loaded, by name. An app two sources
    /// both offer is listed under each.
    func listings(installed apps: [SideloadedAppStatus]) -> [SourceListing] {
        urls.flatMap { url -> [SourceListing] in
            guard case .loaded(let source)? = states[url] else { return [] }
            return source.apps.map { app in
                SourceListing(app: app, sourceURL: url, sourceName: Self.name(of: source, at: url),
                              installedVersion: Self.installedVersion(of: app, in: apps))
            }
        }
        .sorted { $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending }
    }

    /// The version of `app` on this iPhone, from what the Sideloaded apps page
    /// read. SideInstaller signs an app as `<bundle id>.<team id>`, so that
    /// counts as the same app.
    static func installedVersion(of app: SourceApp, in apps: [SideloadedAppStatus]) -> String? {
        apps.first {
            ProfileMatcher.installed($0.app.bundleID, isBuiltFrom: app.bundleIdentifier, teamID: nil)
        }?.app.version
    }

    /// How many apps on this iPhone a source has a newer version of.
    func updateCount(installed apps: [SideloadedAppStatus]) -> Int {
        listings(installed: apps).filter(\.hasUpdate).count
    }

    /// The GitHub account a source is published from, read from where it is
    /// hosted (`<owner>.github.io`, `raw.githubusercontent.com/<owner>/…`,
    /// `github.com/<owner>/…`) or from its website.
    static func gitHubOwner(of url: URL, website: URL? = nil) -> String? {
        if let known = suggestions.first(where: { $0.url == url }) { return known.gitHub }
        for link in [url, website].compactMap({ $0 }) {
            guard let host = link.host?.lowercased() else { continue }
            let parts = link.path.split(separator: "/").map(String.init)
            if host.hasSuffix(".github.io") {
                return String(host.dropLast(".github.io".count))
            }
            if ["raw.githubusercontent.com", "github.com", "www.github.com",
                "objects.githubusercontent.com"].contains(host), let owner = parts.first {
                return owner
            }
        }
        return nil
    }

    /// The picture for a source's row: its developer's GitHub picture when it
    /// comes from GitHub, else its first app's icon, else the source's own.
    static func picture(of source: AppSource?, at url: URL) -> (primary: URL?, fallback: URL?) {
        let appIcon = source?.apps.lazy.compactMap(\.iconURL).first ?? source?.iconURL
        if let owner = gitHubOwner(of: url, website: source?.website),
           let avatar = URL(string: "https://github.com/\(owner).png?size=128") {
            return (avatar, appIcon)
        }
        return (appIcon, nil)
    }

    /// Checks for updates without the page open: fetches the sources and,
    /// with LocalDevVPN on, reads which apps are installed. Called once when
    /// SideInstaller opens, as `UpdateChecker` checks SideInstaller itself.
    func checkAtLaunch(apps: SideloadedAppsManager) async {
        guard !urls.isEmpty else { return }
        apps.autoLoad()
        await refresh()
    }

    static func name(of source: AppSource, at url: URL) -> String {
        source.name.isEmpty ? (url.host ?? url.absoluteString) : source.name
    }

    // MARK: Adding and removing

    /// Adds the source at `text`: an https link to its JSON, or an
    /// `altstore://source?url=` / `sidestore://source?url=` link. Fetched first,
    /// so only a working source is kept. Returns true once added.
    @discardableResult
    func add(_ text: String) async -> Bool {
        addError = nil
        guard let url = Self.sourceLink(text) else {
            addError = L("That isn't a source link. Paste the whole https:// address of the source.")
            return false
        }
        guard !urls.contains(url) else {
            addError = L("That source is already added.")
            return false
        }
        isAdding = true
        defer { isAdding = false }
        do {
            let source = try await Self.fetch(url)
            urls.append(url)
            states[url] = .loaded(source)
            save()
            Engine.shared.log("Sources: added \(url.absoluteString) (\(source.apps.count) apps).")
            return true
        } catch {
            addError = Self.describe(error)
            Engine.shared.log("⛔️ Sources: couldn't add \(url.absoluteString): \(addError ?? "")")
            return false
        }
    }

    func remove(_ url: URL) {
        guard !isBuiltIn(url) else { return }
        urls.removeAll { $0 == url }
        states[url] = nil
        save()
        Engine.shared.log("Sources: removed \(url.absoluteString).")
    }

    private func save() {
        UserDefaults.standard.set(urls.filter { !isBuiltIn($0) }.map(\.absoluteString),
                                  forKey: Self.storeKey)
    }

    /// The source a pasted link points at.
    static func sourceLink(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let components = URLComponents(string: trimmed),
           let scheme = components.scheme?.lowercased(),
           ["altstore", "sidestore", "feather"].contains(scheme),
           let inner = components.queryItems?.first(where: { $0.name.lowercased() == "url" })?.value {
            return Engine.downloadLink(inner)
        }
        return Engine.downloadLink(trimmed)
    }

    // MARK: Fetching

    /// Fetches every source again. Called when the page opens and on pull.
    func refresh() async {
        let all = urls
        guard !all.isEmpty else { return }
        for url in all where states[url] == nil { states[url] = .loading }
        await withTaskGroup(of: (URL, SourceState).self) { group in
            for url in all {
                group.addTask {
                    do { return (url, .loaded(try await Self.fetch(url))) }
                    catch { return (url, .failed(await Self.describe(error))) }
                }
            }
            for await (url, state) in group where urls.contains(url) {
                // A source that fetched before keeps its apps if this fetch fails.
                if case .failed = state, case .loaded? = states[url] { continue }
                states[url] = state
            }
        }
    }

    /// Fetches the sources not fetched yet, when the page opens. The rest
    /// were fetched at launch; pull down or Check for updates fetches them again.
    func refreshMissing() async {
        guard urls.contains(where: { states[$0] == nil }) else { return }
        await refresh()
    }

    enum FetchError: Error {
        case status(Int)
        case notASource
    }

    nonisolated static func fetch(_ url: URL) async throws -> AppSource {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.status(http.statusCode)
        }
        guard let source = try? JSONDecoder().decode(AppSource.self, from: data),
              !source.apps.isEmpty || !source.name.isEmpty else {
            throw FetchError.notASource
        }
        return source
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case FetchError.status(let code):
            return L("The source answered with HTTP %d.", code)
        case FetchError.notASource:
            return L("That link didn't return a source. It has to be the source's JSON file itself.")
        default:
            return L("Couldn't reach the source: %@", error.localizedDescription)
        }
    }

    // MARK: Installing

    /// Puts up the install popup for `version`, as a `sideinstaller://install`
    /// link would. On yes, the Install tab downloads, signs and installs it.
    func install(_ version: SourceVersion, of app: SourceApp) {
        var components = URLComponents()
        components.scheme = DeepLink.scheme
        components.host = "install"
        components.queryItems = [URLQueryItem(name: "url", value: version.downloadURL.absoluteString)]
        guard let link = components.url else { return }
        Engine.shared.log("Sources: \(app.name) \(version.version) from \(version.downloadURL.absoluteString).")
        Engine.shared.receiveLink(link)
    }
}

// MARK: - Sources page

/// The Sources page: add AltStore-format sources, browse their apps, see which
/// installed ones have updates, and install from them without fetching the
/// IPA by hand.
struct SourcesView: View {
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var manager: SourcesManager
    /// What is installed comes from the Sideloaded apps page's device read.
    @ObservedObject var appsManager: SideloadedAppsManager

    @State private var showSettings = false
    @State private var newSource = ""
    @FocusState private var fieldFocused: Bool
    /// The add-a-source field, opened from its button.
    @State private var showAdd = false
    /// The list of sources, opened from its button.
    @State private var showSources = false

    private var listings: [SourceListing] { manager.listings(installed: appsManager.entries) }

    var body: some View {
        let all = listings
        let updates = all.filter(\.hasUpdate)
        ScrollView {
            VStack(spacing: 16) {
                header(updates: updates.count).cascadeItem(0)
                actionButtons.cascadeItem(1)
                if showAdd {
                    addCard.transition(.cardAppear)
                }
                if !updates.isEmpty {
                    section(title: L("Updates"), listings: updates)
                        .transition(.cardAppear)
                        .cascadeItem(3)
                }
                if !manager.urls.isEmpty {
                    sourcesButton.cascadeItem(4)
                    if showSources {
                        SourceRowsCard(manager: manager)
                            .transition(.cardAppear)
                    }
                }
                if !all.isEmpty {
                    section(title: L("Apps"), listings: all)
                        .cascadeItem(5)
                }
            }
            .padding(20)
            .pageColumn()
            .animation(.smooth(duration: 0.3), value: manager.states)
            .animation(.smooth(duration: 0.3), value: manager.urls)
            .animation(.smooth(duration: 0.3), value: appsManager.entries)
            .animation(.smooth(duration: 0.3), value: showAdd)
            .animation(.smooth(duration: 0.3), value: showSources)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .refreshable { await manager.refresh() }
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .task {
            appsManager.autoLoad()
            await manager.refreshMissing()
        }
    }

    // MARK: Header

    private func header(updates: Int) -> some View {
        BrandHeader(icon: "square.stack.3d.down.right", image: "SourcesLogo", title: L("Sources")) {
            if updates > 0 {
                StatusDot(text: updates == 1 ? L("%d update", updates) : L("%d updates", updates),
                          color: Theme.warning)
            } else if !manager.urls.isEmpty {
                StatusDot(text: manager.urls.count == 1 ? L("%d source", manager.urls.count)
                                                        : L("%d sources", manager.urls.count),
                          color: Theme.positive, idle: manager.isRefreshing)
            }
        }
    }

    // MARK: Add

    private var addCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    TextField(String("https://example.com/source.json"), text: $newSource)
                        .textFieldStyle(.plain)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($fieldFocused)
                        .onSubmit(add)
                        .fieldBackground()
                    Button(action: add) {
                        if manager.isAdding {
                            ProgressView()
                        } else {
                            Text(L("Add"))
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    .disabled(manager.isAdding || newSource.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let error = manager.addError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Theme.negative)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.cardAppear)
                }
                Text(L("Paste the link of a SideStore or AltStore source, or of a .json source file. Its apps, their updates and release notes show here."))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if !manager.openSuggestions.isEmpty {
                    Divider().overlay(Theme.hairline)
                    Text(L("Suggested"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(manager.openSuggestions) { suggestion in
                        suggestionRow(suggestion)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.smooth(duration: 0.25), value: manager.urls)
            .animation(.smooth(duration: 0.25), value: manager.addError)
        }
    }

    private func suggestionRow(_ suggestion: SourcesManager.Suggestion) -> some View {
        HStack(spacing: 12) {
            AppIconView(url: suggestion.picture, side: 36, round: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(suggestion.developer)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(L("Add")) {
                Task { await manager.add(suggestion.url.absoluteString) }
            }
            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
            .controlSize(.small)
            .disabled(manager.isAdding)
        }
    }

    private func add() {
        let text = newSource
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            if await manager.add(text) {
                newSource = ""
                fieldFocused = false
                showAdd = false
            }
        }
    }

    // MARK: Buttons

    /// "Add a source", which opens the field, and "Check for updates", which
    /// reads which apps are on this iPhone (LocalDevVPN on, as Sideloaded apps
    /// needs) and fetches every source again.
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showAdd.toggle()
                manager.addError = nil
                fieldFocused = showAdd
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showAdd ? "xmark" : "plus")
                        .contentTransition(.symbolEffect(.replace))
                    Text(L("Add a source"))
                }
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
            if !manager.urls.isEmpty {
                Button(action: checkForUpdates) {
                    HStack(spacing: 6) {
                        if appsManager.isWorking || manager.isRefreshing {
                            ProgressView().tint(Theme.accent).controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(L("Check for updates"))
                    }
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                .disabled(appsManager.isWorking || manager.isRefreshing)
            }
        }
    }

    private func checkForUpdates() {
        appsManager.load()
        Task { await manager.refresh() }
    }

    // MARK: Apps

    private func section(title: String, listings: [SourceListing]) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                ForEach(Array(listings.enumerated()), id: \.element.id) { index, listing in
                    if index > 0 { Divider().overlay(Theme.hairline) }
                    NavigationLink {
                        SourceAppView(listing: listing, manager: manager)
                    } label: {
                        SourceAppRow(listing: listing)
                    }
                    .buttonStyle(.plain, sound: .tick)
                }
            }
        }
    }

    // MARK: Sources

    /// Opens and closes the list of sources below it, so the apps keep the
    /// room until it is wanted.
    private var sourcesButton: some View {
        Button { showSources.toggle() } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(Theme.accent)
                Text(L("Your sources"))
                    .font(.body.weight(.medium))
                Spacer(minLength: 8)
                Text("\(manager.urls.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .rotationEffect(.degrees(showSources ? 180 : 0))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .cardSurface(in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain, sound: .tick)
    }
}

/// Every source added, with who publishes it, what it offers and its link;
/// each can be copied or removed.
struct SourceRowsCard: View {
    @ObservedObject var manager: SourcesManager

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(manager.urls.enumerated()), id: \.element) { index, url in
                    if index > 0 { Divider().overlay(Theme.hairline) }
                    sourceRow(url)
                }
            }
        }
    }

    private func sourceRow(_ url: URL) -> some View {
        HStack(spacing: 12) {
            let picture = SourcesManager.picture(of: loadedSource(url), at: url)
            AppIconView(url: picture.primary, fallback: picture.fallback, side: 40, round: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(loadedSource(url)?.developerName ?? sourceName(url))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Group {
                    switch manager.states[url] {
                    case .loaded(let source)?:
                        Text(sourceName(url) + " · " + (source.apps.count == 1
                                ? L("%d app", source.apps.count)
                                : L("%d apps", source.apps.count)))
                    case .failed(let message)?:
                        Text(message).foregroundStyle(Theme.negative)
                    default:
                        Text(L("Loading…"))
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                Text(url.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Menu {
                Button { UIPasteboard.general.string = url.absoluteString } label: {
                    Label(L("Copy link"), systemImage: "doc.on.doc")
                }
                if !manager.isBuiltIn(url) {
                    Button(role: .destructive) { manager.remove(url) } label: {
                        Label(L("Remove"), systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L("Source options"))
        }
        .padding(.vertical, 6)
    }

    private func sourceName(_ url: URL) -> String {
        if case .loaded(let source)? = manager.states[url] { return SourcesManager.name(of: source, at: url) }
        return url.host ?? url.absoluteString
    }

    private func loadedSource(_ url: URL) -> AppSource? {
        if case .loaded(let source)? = manager.states[url] { return source }
        return nil
    }
}

/// One app in a list: its icon, name, developer and version, with an Update
/// tag when the source has a newer one than the iPhone.
private struct SourceAppRow: View {
    let listing: SourceListing

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(url: listing.app.iconURL, side: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.app.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(listing.app.developerName ?? listing.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(versionLine)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if listing.hasUpdate {
                Tag(text: L("Update"), color: Theme.warning)
            } else if listing.installedVersion != nil {
                Tag(text: L("Installed"), color: Theme.positive)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var versionLine: String {
        let latest = listing.app.latest?.version ?? ""
        if let installed = listing.installedVersion, listing.hasUpdate {
            return "\(installed) → \(latest)"
        }
        return latest
    }
}

/// A small outlined tag, like the Beta badge.
private struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
            .fixedSize()
    }
}

/// An app's icon from its source, or a plain tile while it loads or when it
/// has none. With `fallback`, that picture is tried when `url` fails (a
/// developer with no GitHub picture shows their app's icon). `round` draws a
/// person's picture in a circle.
struct AppIconView: View {
    let url: URL?
    var fallback: URL? = nil
    let side: CGFloat
    var round = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: round ? side / 2 : side * 0.225, style: .continuous)
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else if case .failure = phase, let fallback {
                AppIconView(url: fallback, side: side, round: round)
            } else {
                placeholder
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(Theme.raised)
            Image(systemName: "app.dashed")
                .font(.system(size: side * 0.4))
                .foregroundStyle(Theme.muted)
        }
    }
}

// MARK: - App page

/// One source app: install or update it, what's new, its description, and
/// every version with its release notes.
struct SourceAppView: View {
    @EnvironmentObject private var loc: Localizer
    let listing: SourceListing
    @ObservedObject var manager: SourcesManager

    @State private var showSettings = false
    @State private var confirm: SourceVersion?

    private var app: SourceApp { listing.app }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header.cascadeItem(0)
                installButton.cascadeItem(1)
                if let latest = app.latest {
                    whatsNew(latest).cascadeItem(2)
                }
                if let description = app.localizedDescription, !description.isEmpty {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 8) {
                            cardTitle(L("About"))
                            ReleaseNotesText(text: description)
                        }
                    }
                    .cascadeItem(3)
                }
                if app.versions.count > 1 {
                    history.cascadeItem(4)
                }
            }
            .padding(20)
            .pageColumn()
        }
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .alert(confirm.map { L("Install %@ %@?", app.name, $0.version) } ?? "",
               isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })) {
            Button(L("Install")) {
                if let confirm { manager.install(confirm, of: app) }
                confirm = nil
            }
            Button(L("Cancel"), role: .cancel) { confirm = nil }
        } message: {
            if let confirm, listing.isDowngrade(to: confirm), let installed = listing.installedVersion {
                Text(L("This version is older than the one on this iPhone (%@). Installed over it, it may not open data the newer version saved.", installed))
            } else {
                Text(L("This version is older than the newest one. It's installed over the copy on this iPhone, which may not open data a newer version saved."))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            AppIconView(url: app.iconURL, side: 96)
            VStack(spacing: 4) {
                Text(app.name)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                if let developer = app.developerName {
                    Text(developer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let subtitle = app.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            StatusDot(text: statusText, color: listing.hasUpdate ? Theme.warning : Theme.positive,
                      idle: listing.installedVersion == nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var statusText: String {
        let latest = app.latest?.version ?? ""
        guard let installed = listing.installedVersion else {
            return L("Version %@ · from %@", latest, listing.sourceName)
        }
        return listing.hasUpdate ? L("%@ installed · %@ available", installed, latest)
                                 : L("%@ installed · up to date", installed)
    }

    @ViewBuilder
    private var installButton: some View {
        if let latest = app.latest {
            VStack(spacing: 8) {
                Button {
                    // Asks first when the iPhone's copy is newer than the source's.
                    if listing.isDowngrade(to: latest) {
                        confirm = latest
                    } else {
                        manager.install(latest, of: app)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: listing.hasUpdate ? "arrow.down.circle" : "square.and.arrow.down")
                        Text(listing.hasUpdate ? L("Update to %@", latest.version)
                                               : L("Install %@", latest.version))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Text(L("Downloads the IPA from the source, then signs it with your Apple ID and installs it, as a custom .ipa would be."))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func whatsNew(_ latest: SourceVersion) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    cardTitle(L("What's new"))
                    Spacer()
                    Text(versionMeta(latest))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                if let notes = latest.notes, !notes.isEmpty {
                    ReleaseNotesText(text: notes)
                } else {
                    Text(L("This version has no release notes."))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var history: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle(L("Version history"))
                ForEach(Array(app.versions.dropFirst().enumerated()), id: \.element.id) { index, version in
                    if index > 0 { Divider().overlay(Theme.hairline) }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(version.version)
                                .font(.subheadline.weight(.semibold))
                            Text(versionMeta(version))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                            Spacer()
                            Button(L("Install")) { confirm = version }
                                .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                                .controlSize(.small)
                        }
                        if let notes = version.notes, !notes.isEmpty {
                            ReleaseNotesText(text: notes)
                        }
                    }
                }
            }
        }
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }

    /// "16 Nov 2026 · 10.4 MB", with what the source gives.
    private func versionMeta(_ version: SourceVersion) -> String {
        var parts: [String] = []
        if let date = version.date {
            parts.append(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(Localizer.locale)))
        }
        if let size = version.size, size > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        return parts.joined(separator: " · ")
    }
}

/// Release notes as sources write them: Markdown headings, bullets and inline
/// bold, italics and links. Anything else shows as plain text.
struct ReleaseNotesText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(Self.blocks(text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let line):
                    Text(Self.inline(line))
                        .font(.footnote.weight(.semibold))
                        .padding(.top, 4)
                case .bullet(let line):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(Theme.muted)
                        Text(Self.inline(line))
                    }
                    .font(.footnote)
                case .paragraph(let line):
                    Text(Self.inline(line)).font(.footnote)
                }
            }
        }
        .foregroundStyle(.primary.opacity(0.9))
        .tint(Theme.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
        // Anyone can publish a source, so its links open only web pages. An
        // app's link acts as soon as it's tapped: sidestore://pairing?urlname=
        // hands SideStore's pairing file to the app it names.
        .environment(\.openURL, OpenURLAction { url in
            Self.opensLink(url) ? .systemAction : .discarded
        })
    }

    /// Whether a link in a source's text opens: http(s) only.
    static func opensLink(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
    }

    enum Block: Equatable {
        case heading(String)
        case bullet(String)
        case paragraph(String)
    }

    static func blocks(_ text: String) -> [Block] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { raw -> Block? in
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty else { return nil }
                if line.hasPrefix("#") {
                    return .heading(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces))
                }
                for marker in ["- ", "* ", "• "] where line.hasPrefix(marker) {
                    return .bullet(String(line.dropFirst(marker.count)))
                }
                return .paragraph(line)
            }
    }

    static func inline(_ line: String) -> AttributedString {
        (try? AttributedString(markdown: line,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(line)
    }
}
