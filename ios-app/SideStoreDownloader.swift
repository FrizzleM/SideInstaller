import Foundation

/// Which release track to pull the IPA from. Both supported repos publish a
/// stable tagged release *and* a rolling `nightly` pre-release carrying the same
/// asset names, so the choice is orthogonal to `InstallSource`.
enum ReleaseChannel: String, CaseIterable, Identifiable {
    case stable
    case nightly

    var id: String { rawValue }

    /// Label for the picker.
    var displayName: String {
        switch self {
        case .stable:  return L("Stable")
        case .nightly: return L("Nightly")
        }
    }

    /// Filename suffix, so a stable and a nightly download of the same app can
    /// coexist in Documents instead of overwriting each other.
    var fileSuffix: String {
        switch self {
        case .stable:  return ""
        case .nightly: return "-nightly"
        }
    }
}

/// What to install. `sideStore` and `liveContainer` are both SideStore builds —
/// the difference is which GitHub repo the IPA is fetched from (LiveContainer
/// + SideStore is SideStore with LiveContainer integrated). Which *release* of
/// that repo is picked comes from the `ReleaseChannel` the user selected.
///
/// `custom` is neither: it's whatever IPA the user handed the app, which is the
/// only route that works at all where GitHub is unreachable. Nothing about it
/// can be known ahead of time, so the properties that describe a *known* build
/// — the repo, the app the pairing file belongs to — are optional, and the code
/// that needs them has to say what it does without.
enum InstallSource: String, CaseIterable, Identifiable {
    case sideStore
    case liveContainer
    case custom

    var id: String { rawValue }

    /// Full name, used in logs.
    var displayName: String {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer + SideStore"
        case .custom:        return L("Custom .ipa")
        }
    }

    /// Short label for the segmented picker / button.
    var shortName: String {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "SS + LiveContainer"
        case .custom:        return L("Custom .ipa")
        }
    }

    /// GitHub "owner/repo" whose release holds the IPA — nil for a build that
    /// doesn't come from a release.
    var repo: String? {
        switch self {
        case .sideStore:     return "SideStore/SideStore"
        case .liveContainer: return "LiveContainer/LiveContainer"
        case .custom:        return nil
        }
    }

    /// GitHub releases API endpoint for a channel. `/releases/latest` skips
    /// pre-releases, so the nightly build is fetched by its `nightly` tag. Nil
    /// when there's no release to ask about.
    func releaseAPI(_ channel: ReleaseChannel) -> URL? {
        guard let repo else { return nil }
        let base = "https://api.github.com/repos/\(repo)/releases"
        switch channel {
        case .stable:  return URL(string: "\(base)/latest")!
        case .nightly: return URL(string: "\(base)/tags/nightly")!
        }
    }

    /// Local filename for the downloaded IPA, e.g. "SideStore-nightly.ipa".
    /// An imported IPA keeps its own name instead (see `IPALibrary.customDir`),
    /// so this is only ever a placeholder for `custom`.
    func fileName(_ channel: ReleaseChannel) -> String {
        let base: String
        switch self {
        case .sideStore:     base = "SideStore"
        case .liveContainer: base = "LiveContainer+SideStore"
        case .custom:        return "Custom.ipa"
        }
        return "\(base)\(channel.fileSuffix).ipa"
    }

    // MARK: Pairing-file placement
    //
    // After install, the device pairing file is written into the *installed*
    // host app's container so SideStore can find it. The host app and the path
    // it reads differ between the two builds — mirrored from iLoader's
    // PAIRING_APPS table (src-tauri/src/pairing.rs).

    /// CFBundleDisplayName of the installed host app that receives the pairing
    /// file. installation_proxy reports this; matching on the display name
    /// (rather than a bundle id, which isideload rewrites) is how iLoader
    /// locates the target app. Nil for an imported IPA — there's nothing to
    /// match on until it's been signed, so the caller reads it off the signed
    /// bundle instead.
    var pairingAppDisplayName: String? {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer"
        case .custom:        return nil
        }
    }

    /// Base bundle id of the installed host app — fallback for resolving the
    /// install when the display-name lookup misses. isideload appends
    /// ".<teamID>" to this. Nil for the same reason as above.
    var pairingBundleIDBase: String? {
        switch self {
        case .sideStore:     return "com.SideStore.SideStore"
        case .liveContainer: return "com.kdt.livecontainer"
        case .custom:        return nil
        }
    }

    /// Where the pairing file must land, relative to the host app's Documents
    /// directory. Plain SideStore reads it at the Documents root. Under
    /// LiveContainer, SideStore runs as a guest whose Documents live in a
    /// nested folder, so the file goes there instead. An imported IPA gets the
    /// root path: it's what every AltStore-family app but LiveContainer uses,
    /// and for an IPA that wants no pairing file at all the write is harmless.
    var pairingRemoteRelativePath: String {
        switch self {
        case .sideStore, .custom: return "ALTPairingFile.mobiledevicepairing"
        case .liveContainer:      return "SideStore/Documents/ALTPairingFile.mobiledevicepairing"
        }
    }

    /// Pick the right `.ipa` asset out of a release's assets.
    func selectAsset(from assets: [SideStoreDownloader.GHAsset]) -> SideStoreDownloader.GHAsset? {
        switch self {
        case .sideStore:
            // Publishes a single `.ipa` per release.
            return assets.first { $0.name.hasSuffix(".ipa") }
        case .liveContainer:
            // Prefer the exact published bundle; fall back to any SideStore-
            // flavored .ipa in case the asset is renamed in a future release.
            return assets.first { $0.name == "LiveContainer+SideStore.ipa" }
                ?? assets.first { $0.name.lowercased().contains("sidestore") && $0.name.hasSuffix(".ipa") }
        case .custom:
            // No release to pick from.
            return nil
        }
    }
}

/// Downloads the newest IPA on the chosen `InstallSource` + `ReleaseChannel`
/// into Documents.
enum SideStoreDownloader {

    struct GHAsset: Decodable {
        let name: String
        let browser_download_url: String
        let size: Int
    }
    struct GHRelease: Decodable {
        let tag_name: String
        let assets: [GHAsset]
    }

    enum DownloadError: Error, CustomStringConvertible {
        case noIPAAsset(String, ReleaseChannel)
        case noRelease(String, ReleaseChannel)
        case badURL
        /// The chosen source has no release to download — `.custom`, which is
        /// supplied by the user rather than fetched.
        case notDownloadable
        var description: String {
            switch self {
            case let .noIPAAsset(source, channel):
                return L("couldn't find the IPA in the %@ %@ release",
                         channel.displayName.lowercased(), source)
            case let .noRelease(source, channel):
                return L("%@ has no %@ release right now",
                         source, channel.displayName.lowercased())
            case .badURL:
                return L("bad asset URL")
            case .notDownloadable:
                return L("there's nothing to download for a custom IPA — import one first")
            }
        }
    }

    /// Returns the local path of the downloaded IPA. `log` receives progress.
    static func downloadLatest(source: InstallSource,
                               channel: ReleaseChannel,
                               log: @escaping (String) -> Void) async throws -> String {
        guard let api = source.releaseAPI(channel) else { throw DownloadError.notDownloadable }
        var req = URLRequest(url: api)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        let (data, releaseResponse) = try await URLSession.shared.data(for: req)
        // A repo that has dropped (or never published) the `nightly` tag answers
        // 404 — report that as a missing channel rather than a decode failure.
        if let http = releaseResponse as? HTTPURLResponse, http.statusCode == 404 {
            throw DownloadError.noRelease(source.displayName, channel)
        }
        let release = try JSONDecoder().decode(GHRelease.self, from: data)
        log("\(channel.displayName) \(source.displayName) release: \(release.tag_name) with \(release.assets.count) assets")

        guard let asset = source.selectAsset(from: release.assets) else {
            throw DownloadError.noIPAAsset(source.displayName, channel)
        }
        guard let assetURL = URL(string: asset.browser_download_url) else {
            throw DownloadError.badURL
        }
        log("Downloading \(asset.name) (\(asset.size) bytes) …")

        let (tmp, response) = try await URLSession.shared.download(from: assetURL)
        if let http = response as? HTTPURLResponse {
            log("HTTP \(http.statusCode) for \(asset.name)")
        }

        let dest = IPALibrary.documentsDir.appendingPathComponent(source.fileName(channel))
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        // Claim the file, so a later run knows this copy came off GitHub and is
        // safe to replace — unlike one the user put there by hand.
        DownloadLedger.record(dest)
        return dest.path
    }
}

// MARK: - IPAs already on disk

/// The IPAs sitting in the app's Documents directory, however they got there.
///
/// Downloading isn't possible everywhere. The tunnel this install runs over is
/// loopback-only and iOS allows one VPN at a time, so while it's up there's no
/// proxy left to reach GitHub through — and in some countries GitHub is blocked
/// outright. The way around that is to fetch the IPA by hand, on any machine
/// and from any mirror, and copy it into SideInstaller's folder in the Files
/// app (`UIFileSharingEnabled` in Info.plist is what puts it there). The
/// install then reads it from disk instead of the network.
enum IPALibrary {

    /// Where both the downloader and the Files app write.
    static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Where an IPA imported for `InstallSource.custom` is kept. Its own folder,
    /// rather than a reserved filename in Documents, for two reasons: a custom
    /// IPA can be called anything — including the exact name a download uses —
    /// and keeping it apart means it never has to be renamed, so the user can
    /// still recognise what they picked.
    static var customDir: URL {
        documentsDir.appendingPathComponent("Custom", isDirectory: true)
    }

    /// One `.ipa` in Documents, tagged with the build its name identifies.
    struct Entry {
        let source: InstallSource
        let channel: ReleaseChannel
        let url: URL
        let size: Int
        let modified: Date?
        /// True when the app didn't download this file — the user supplied it.
        /// The install treats those two cases differently (see `Engine.download`).
        let isImported: Bool
    }

    /// Which build a filename names, or nil if it names neither. Deliberately
    /// loose about case, separators and version suffixes: someone saving a
    /// release asset by hand just as often ends up with `sidestore.ipa` or
    /// `SideStore_1.0.ipa` as with the exact name the downloader would write.
    static func classify(_ fileName: String) -> (source: InstallSource, channel: ReleaseChannel)? {
        let name = fileName.lowercased()
        guard name.hasSuffix(".ipa") else { return nil }
        let source: InstallSource
        // LiveContainer's asset carries "SideStore" in its name too, so the more
        // specific test has to run first or every LiveContainer build would read
        // as plain SideStore.
        if name.contains("livecontainer")     { source = .liveContainer }
        else if name.contains("sidestore")    { source = .sideStore }
        else { return nil }
        return (source, name.contains("nightly") ? .nightly : .stable)
    }

    /// Every IPA the app can install, newest first: the recognisable ones in
    /// Documents plus whatever has been imported for the custom source.
    static func scan() -> [Entry] {
        let entries = describe(namesIn: documentsDir).compactMap { (name, url, attrs) -> Entry? in
            guard let kind = classify(name) else { return nil }
            return Entry(source: kind.source, channel: kind.channel, url: url,
                         size: (attrs[.size] as? Int) ?? 0,
                         modified: attrs[.modificationDate] as? Date,
                         isImported: !DownloadLedger.isManaged(url))
        }
        return (entries + [customImport()].compactMap { $0 })
            .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    /// The IPA imported for `InstallSource.custom`, if there is one. Only ever
    /// one at a time — importing replaces — so the newest file wins if a stale
    /// one somehow survives.
    static func customImport() -> Entry? {
        describe(namesIn: customDir)
            .filter { $0.name.lowercased().hasSuffix(".ipa") }
            .map { (name, url, attrs) in
                Entry(source: .custom, channel: .stable, url: url,
                      size: (attrs[.size] as? Int) ?? 0,
                      modified: attrs[.modificationDate] as? Date,
                      isImported: true)
            }
            .max { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
    }

    /// Directory listing paired with each entry's file attributes, skipping
    /// anything that has vanished between the two calls.
    private static func describe(namesIn dir: URL) -> [(name: String, url: URL, attrs: [FileAttributeKey: Any])] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.compactMap { name in
            let url = dir.appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return nil }
            return (name, url, attrs)
        }
    }

    /// The IPA to install for one build, or nil if there's none on disk.
    ///
    /// An import outranks a download of the same build — it's there because
    /// someone chose to put it there — and within that, the exact filename the
    /// downloader writes wins, being the unambiguous one. `scan()` is already
    /// newest-first, and `min(by:)` keeps the first of equally ranked entries,
    /// so ties fall to the most recent file.
    static func entry(source: InstallSource, channel: ReleaseChannel) -> Entry? {
        guard source != .custom else { return customImport() }
        let canonical = source.fileName(channel)
        func rank(_ e: Entry) -> Int {
            (e.isImported ? 0 : 2) + (e.url.lastPathComponent == canonical ? 0 : 1)
        }
        return scan()
            .filter { $0.source == source && $0.channel == channel }
            .min { rank($0) < rank($1) }
    }

    /// Replace the custom import with `url`, copying it into `customDir` under
    /// its own name. Returns the new location. The caller is responsible for
    /// any security-scoped access `url` needs.
    ///
    /// The extension is forced to `.ipa`: an IPA is a zip, and a browser that
    /// saved one may well have named it `.zip`. Since the picker accepts any
    /// file and the contents are what get checked, normalising here is what
    /// keeps such a file findable afterwards.
    static func replaceCustomImport(with url: URL) throws -> URL {
        let fm = FileManager.default
        // One import at a time: clearing the folder keeps "the custom IPA"
        // unambiguous, and stops old picks accumulating invisibly.
        try? fm.removeItem(at: customDir)
        try fm.createDirectory(at: customDir, withIntermediateDirectories: true)
        let name = url.deletingPathExtension().lastPathComponent
        let dest = customDir.appendingPathComponent(name).appendingPathExtension("ipa")
        try fm.copyItem(at: url, to: dest)
        return dest
    }

    /// Forget the custom import, if any.
    static func clearCustomImport() {
        try? FileManager.default.removeItem(at: customDir)
    }

    /// True when the file at least starts like a zip, which every `.ipa` is.
    ///
    /// Worth checking before an imported file is signed, because the population
    /// that imports is the population with an unreliable route to GitHub: a
    /// blocked download saves the block page under the name you asked for, and
    /// a copy through Files can stop halfway. Either way the file is only found
    /// out much later, as an opaque signing failure.
    static func looksLikeIPA(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 2)) == Data([0x50, 0x4B])   // "PK"
    }

    /// `.ipa` files in Documents whose names identify no known build — worth
    /// mentioning when a download fails, since a misnamed import looks from the
    /// outside exactly like one that was ignored for no reason.
    static func unrecognized() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: documentsDir.path)) ?? []
        return names.filter { $0.lowercased().hasSuffix(".ipa") && classify($0) == nil }.sorted()
    }
}

/// Remembers which IPAs the app downloaded itself, so those can be told apart
/// from the ones a user dropped into Documents. The distinction is what lets
/// `Engine.download()` refresh its own stale copy from GitHub while leaving an
/// imported file — placed there deliberately, and possibly the only copy that
/// machine can get — untouched.
enum DownloadLedger {

    private static let defaultsKey = "managedIPAs"

    /// Size + modification time. Keying on the name alone would keep counting a
    /// file as ours after the user replaced it with their own build under the
    /// same name; a fingerprint stops matching the moment the bytes change.
    ///
    /// This assumes nothing downstream rewrites the IPA in place — signing reads
    /// it and emits a separate `.app` bundle (see `Engine.performSign`). If that
    /// ever changed, the app's own downloads would start reading as imported and
    /// it would quietly stop refreshing them from GitHub.
    private static func fingerprint(_ url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let size = (attrs[.size] as? Int) ?? 0
        let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)@\(Int(modified))"
    }

    private static var table: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// True only for a file this app downloaded and nothing has touched since.
    static func isManaged(_ url: URL) -> Bool {
        guard let fp = fingerprint(url) else { return false }
        return table[url.lastPathComponent] == fp
    }

    static func record(_ url: URL) {
        guard let fp = fingerprint(url) else { return }
        var t = table
        t[url.lastPathComponent] = fp
        table = t
    }

    static func forget(_ url: URL) {
        var t = table
        t.removeValue(forKey: url.lastPathComponent)
        table = t
    }
}
