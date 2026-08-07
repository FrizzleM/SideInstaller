import Foundation

/// Which release track to pull the IPA from.
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

    /// Filename suffix, so stable and nightly downloads can coexist.
    var fileSuffix: String {
        switch self {
        case .stable:  return ""
        case .nightly: return "-nightly"
        }
    }
}

/// What to install: two SideStore builds fetched from GitHub, or a user-supplied
/// IPA. Nothing is known about the latter, so its release properties are nil.
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

    /// GitHub "owner/repo" whose release holds the IPA.
    var repo: String? {
        switch self {
        case .sideStore:     return "SideStore/SideStore"
        case .liveContainer: return "LiveContainer/LiveContainer"
        case .custom:        return nil
        }
    }

    /// Releases API endpoint for a channel, asked only when an asset has been
    /// renamed; `/releases/latest` skips pre-releases, hence the nightly tag.
    func releaseAPI(_ channel: ReleaseChannel) -> URL? {
        guard let repo else { return nil }
        let base = "https://api.github.com/repos/\(repo)/releases"
        switch channel {
        case .stable:  return URL(string: "\(base)/latest")!
        case .nightly: return URL(string: "\(base)/tags/nightly")!
        }
    }

    /// The `.ipa` this build publishes, letting the URL be derived not looked up.
    var assetFileName: String? {
        switch self {
        case .sideStore:     return "SideStore.ipa"
        case .liveContainer: return "LiveContainer+SideStore.ipa"
        case .custom:        return nil
        }
    }

    /// Direct download off github.com, which the API's per-IP rate limit — often
    /// already spent by strangers behind carrier-grade NAT — doesn't meter.
    func downloadURL(_ channel: ReleaseChannel) -> URL? {
        guard let repo, let assetFileName else { return nil }
        let base = "https://github.com/\(repo)/releases"
        switch channel {
        case .stable:  return URL(string: "\(base)/latest/download/\(assetFileName)")
        // The nightly tag is fixed, so nothing needs resolving.
        case .nightly: return URL(string: "\(base)/download/nightly/\(assetFileName)")
        }
    }

    /// Local filename for the downloaded IPA, e.g. "SideStore-nightly.ipa".
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
    // After install, the pairing file goes into the host app's container. Which
    // app and which path differ per build, as in iLoader's PAIRING_APPS table.

    /// Display name of the host app receiving the file, as installation_proxy
    /// reports it; isideload rewrites bundle ids, so names are matched instead.
    var pairingAppDisplayName: String? {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer"
        case .custom:        return nil
        }
    }

    /// Base bundle id of the host app, which isideload suffixes with ".<teamID>".
    var pairingBundleIDBase: String? {
        switch self {
        case .sideStore:     return "com.SideStore.SideStore"
        case .liveContainer: return "com.kdt.livecontainer"
        case .custom:        return nil
        }
    }

    /// Where the pairing file lands inside the host app's Documents; under
    /// LiveContainer, SideStore is a guest with a nested Documents folder.
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
            // Prefer the published name, in case the asset is renamed later.
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
        /// The chosen source has no release to download.
        case notDownloadable
        /// GitHub answered with a status rather than a release or an IPA,
        /// carrying its explanation and, for a rate limit, when it clears.
        case badStatus(status: Int, detail: String?, retryAfter: Date?)
        /// The request never reached GitHub: offline, DNS, TLS, timeout, blocked.
        case unreachable(URLError)
        /// A 2xx whose body isn't the release JSON this app models.
        case badRelease(String)
        /// The bytes arrived and aren't an IPA.
        case notAnIPA(String)

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
            case let .badStatus(status, detail, retryAfter):
                // GitHub's rate-limit text names the public IP it counted and
                // suggests authenticating, so say the actionable part instead.
                if let retryAfter {
                    return L("GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.",
                             Self.relative(retryAfter))
                }
                return L("GitHub answered HTTP %d%@", status, detail.map { ": \($0)" } ?? "")
            case let .unreachable(error):
                return L("couldn't reach GitHub: %@", error.localizedDescription)
            case let .badRelease(detail):
                return L("GitHub's answer wasn't release information (%@) — something on this network may have replaced it.",
                         detail)
            case let .notAnIPA(name):
                return L("what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.",
                         name)
            }
        }

        /// True when fetching the IPA elsewhere is really the way past this: the
        /// network interfering, not a rate limit or a release that isn't there.
        var manualSideloadHelps: Bool {
            switch self {
            case .unreachable, .badRelease, .notAnIPA:
                return true
            case .noIPAAsset, .noRelease, .badURL, .notDownloadable:
                return false
            case let .badStatus(_, _, retryAfter):
                return retryAfter == nil
            }
        }

        /// A 404 on the derived URL: the asset isn't under the expected name.
        var isAssetMissing: Bool {
            if case let .badStatus(status, _, _) = self { return status == 404 }
            return false
        }

        /// "in 12 minutes", in the language of the surrounding sentence.
        private static func relative(_ date: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Localizer.locale
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }

    /// An IPA downloaded to a temporary file, whichever route found it.
    private struct Fetched {
        let file: URL
        /// The asset name GitHub gave it, which may differ from the one asked for.
        let name: String
    }

    /// Returns the local path of the downloaded IPA. `log` receives progress.
    static func downloadLatest(source: InstallSource,
                               channel: ReleaseChannel,
                               log: @escaping (String) -> Void) async throws -> String {
        guard let direct = source.downloadURL(channel), let assetName = source.assetFileName else {
            throw DownloadError.notDownloadable
        }

        let fetched: Fetched
        do {
            fetched = try await fetch(direct, named: assetName, log: log)
        } catch let error as DownloadError where error.isAssetMissing {
            log("No \(assetName) on that release — asking GitHub's API what the asset is called now.")
            fetched = try await fetchViaAPI(source: source, channel: channel, log: log)
        }

        // An answer isn't proof of an IPA: a block page or a stopped transfer
        // would otherwise surface later as an opaque signing failure.
        guard IPALibrary.looksLikeIPA(fetched.file) else {
            try? FileManager.default.removeItem(at: fetched.file)
            throw DownloadError.notAnIPA(fetched.name)
        }

        let dest = IPALibrary.documentsDir.appendingPathComponent(source.fileName(channel))
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: fetched.file, to: dest)
        // Claim the file, so a later run knows this copy is safe to replace.
        DownloadLedger.record(dest)
        return dest.path
    }

    /// Download one URL to a temporary file, if the response isn't a refusal.
    private static func fetch(_ url: URL, named name: String,
                              log: @escaping (String) -> Void) async throws -> Fetched {
        var req = URLRequest(url: url)
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let redirects = ReleaseTagRecorder()

        log("Downloading \(name) …")
        let (file, response) = try await perform {
            try await URLSession.shared.download(for: req, delegate: redirects)
        }
        do {
            // No body to quote: the download host refuses in plain text, not JSON.
            try check(response)
        } catch {
            try? FileManager.default.removeItem(at: file)
            throw error
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let tag = redirects.tag.map { ", release \($0)" } ?? ""
        log("HTTP \(status) for \(name) — \(response.expectedContentLength) bytes\(tag)")
        return Fetched(file: file, name: name)
    }

    /// Ask the releases API where the IPA is, once the derived URL has 404'd.
    private static func fetchViaAPI(source: InstallSource,
                                    channel: ReleaseChannel,
                                    log: @escaping (String) -> Void) async throws -> Fetched {
        guard let api = source.releaseAPI(channel) else { throw DownloadError.notDownloadable }
        var req = URLRequest(url: api)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await perform { try await URLSession.shared.data(for: req) }
        // A repo with no `nightly` tag answers 404: a missing channel, not a status.
        if (response as? HTTPURLResponse)?.statusCode == 404 {
            throw DownloadError.noRelease(source.displayName, channel)
        }
        try check(response, body: data)

        let release: GHRelease
        do {
            release = try JSONDecoder().decode(GHRelease.self, from: data)
        } catch {
            // The status is already ruled out, so a 2xx that won't decode is
            // exactly that, not a refusal in disguise.
            throw DownloadError.badRelease(String(describing: error))
        }
        log("\(channel.displayName) \(source.displayName) release: \(release.tag_name) with \(release.assets.count) assets")

        guard let asset = source.selectAsset(from: release.assets) else {
            throw DownloadError.noIPAAsset(source.displayName, channel)
        }
        guard let assetURL = URL(string: asset.browser_download_url) else {
            throw DownloadError.badURL
        }
        return try await fetch(assetURL, named: asset.name, log: log)
    }

    /// Run a URLSession call, typing its failures: a `URLError` is the only one
    /// that means GitHub was out of reach.
    private static func perform<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as URLError {
            // A cancelled install arrives as a URLError, and isn't a failure.
            if error.code == .cancelled { throw CancellationError() }
            throw DownloadError.unreachable(error)
        }
    }

    /// Reject anything that isn't a 2xx before its body is trusted, so a refusal
    /// reads as itself rather than as a decode failure.
    private static func check(_ response: URLResponse, body: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw DownloadError.badStatus(status: http.statusCode,
                                          detail: body.flatMap(errorMessage(in:)),
                                          retryAfter: retryAfter(http))
        }
    }

    /// When GitHub will answer again, if this refusal is a rate limit: seconds
    /// for the secondary limits, a Unix timestamp for the spent hourly quota.
    private static func retryAfter(_ http: HTTPURLResponse) -> Date? {
        if let seconds = http.value(forHTTPHeaderField: "retry-after").flatMap(Double.init) {
            return Date().addingTimeInterval(seconds)
        }
        guard http.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0",
              let reset = http.value(forHTTPHeaderField: "x-ratelimit-reset").flatMap(Double.init)
        else { return nil }
        return Date(timeIntervalSince1970: reset)
    }

    /// The readable half of GitHub's error envelope.
    private static func errorMessage(in data: Data) -> String? {
        struct Envelope: Decodable { let message: String }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              !envelope.message.isEmpty else { return nil }
        return envelope.message
    }
}

/// Reads the release tag out of GitHub's redirect chain, since the download
/// passes through `releases/download/<tag>/<asset>` on its way to the bytes.
private final class ReleaseTagRecorder: NSObject, URLSessionTaskDelegate {

    /// Written on the delegate queue during the download, read once it's done.
    private(set) var tag: String?

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let found = Self.tag(in: request.url) { tag = found }
        completionHandler(request)          // follow it, unchanged
    }

    /// The `<tag>` in `…/releases/download/<tag>/<asset>`, or nil for any other
    /// shape, including the `…/latest/download/<asset>` the chain starts from.
    static func tag(in url: URL?) -> String? {
        let parts = url?.pathComponents ?? []
        guard let download = parts.lastIndex(of: "download"),
              download > 0, parts[download - 1] == "releases",
              download + 2 < parts.count            // a tag *and* an asset after it
        else { return nil }
        return parts[download + 1]
    }
}

// MARK: - IPAs already on disk

/// The IPAs in the app's Documents directory, however they got there. Copying
/// one in through the Files app is how to install where GitHub is unreachable.
enum IPALibrary {

    /// Where both the downloader and the Files app write.
    static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Where an imported IPA is kept: its own folder, so it keeps its name even
    /// when that name is one a download also uses.
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
        /// True when the user supplied this file rather than the app fetching it.
        let isImported: Bool
    }

    /// Which build a filename names, loose about case, separators and versions,
    /// since a hand-saved asset rarely keeps the exact published name.
    static func classify(_ fileName: String) -> (source: InstallSource, channel: ReleaseChannel)? {
        let name = fileName.lowercased()
        guard name.hasSuffix(".ipa") else { return nil }
        let source: InstallSource
        // LiveContainer's asset also carries "SideStore", so test it first.
        if name.contains("livecontainer")     { source = .liveContainer }
        else if name.contains("sidestore")    { source = .sideStore }
        else { return nil }
        return (source, name.contains("nightly") ? .nightly : .stable)
    }

    /// Every IPA the app can install, newest first.
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

    /// The imported IPA, if there is one; the newest wins if a stale one survives.
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

    /// Directory listing paired with each entry's attributes.
    private static func describe(namesIn dir: URL) -> [(name: String, url: URL, attrs: [FileAttributeKey: Any])] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.compactMap { name in
            let url = dir.appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return nil }
            return (name, url, attrs)
        }
    }

    /// The IPA to install for one build: an import outranks a download, the
    /// canonical filename outranks any other, and ties fall to the newest.
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

    /// A wrong pick, kept apart from the file-system errors a copy can throw.
    enum ImportError: Error {
        case notAnIPA
    }

    /// Replace the custom import with `url`, forcing the `.ipa` extension.
    /// Blocking, and staged in a temporary directory so only a complete, valid
    /// IPA replaces the previous one. The caller handles security-scoped access.
    static func replaceCustomImport(with url: URL) throws -> URL {
        let fm = FileManager.default
        let name = url.deletingPathExtension().lastPathComponent
        let staging = fm.temporaryDirectory
            .appendingPathComponent("ipa-import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        let staged = staging.appendingPathComponent(name).appendingPathExtension("ipa")

        try copy(url, to: staged)
        guard looksLikeIPA(staged) else { throw ImportError.notAnIPA }

        // One import at a time, so "the custom IPA" stays unambiguous.
        try? fm.removeItem(at: customDir)
        try fm.createDirectory(at: customDir, withIntermediateDirectories: true)
        let dest = customDir.appendingPathComponent(name).appendingPathExtension("ipa")
        // Same volume as the staging dir, so this is a rename, not a second copy.
        try fm.moveItem(at: staged, to: dest)
        return dest
    }

    /// Copy `src` to `dest` under a file coordinator, which waits for an iCloud
    /// placeholder to download instead of failing on it.
    private static func copy(_ src: URL, to dest: URL) throws {
        let fm = FileManager.default
        try? fm.startDownloadingUbiquitousItem(at: src)   // throws for non-iCloud items
        var copyError: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: src, options: [], error: &coordinationError) { readURL in
            do { try fm.copyItem(at: readURL, to: dest) } catch { copyError = error }
        }
        if let copyError { throw copyError }
        if let coordinationError { throw coordinationError }
    }

    /// True when the file is a complete zip, which every `.ipa` is. The `PK`
    /// header rejects a block page; the end-of-central-directory record, which
    /// sits in the last 65557 bytes, rejects a copy that stopped partway.
    static func looksLikeIPA(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard (try? handle.read(upToCount: 2)) == Data([0x50, 0x4B]) else { return false }   // "PK"

        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int,
              size >= 22 else { return false }
        let tailLength = min(size, 65_557)
        guard (try? handle.seek(toOffset: UInt64(size - tailLength))) != nil,
              let tail = try? handle.readToEnd() else { return false }
        return tail.range(of: Data([0x50, 0x4B, 0x05, 0x06])) != nil
    }

    /// `.ipa` files in Documents whose names identify no known build.
    static func unrecognized() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: documentsDir.path)) ?? []
        return names.filter { $0.lowercased().hasSuffix(".ipa") && classify($0) == nil }.sorted()
    }
}

/// State kept in Application Support rather than the file-sharing-visible
/// Documents: the device pairing record, and isideload's certificate store.
enum PrivateStore {

    /// The device pairing file produced by the RPPairing host.
    static var pairingFile: URL {
        resolve(private: directory.appendingPathComponent("rp_pairing_file.plist"),
                legacy: IPALibrary.documentsDir.appendingPathComponent("rp_pairing_file.plist"))
    }

    /// The classic lockdown pair record, minted over the tunnel. Cached because
    /// producing it is interactive and takes one of the device's pairing slots.
    static var lockdownPairRecord: URL {
        directory.appendingPathComponent("lockdown_pair_record.plist")
    }

    /// The pairing file handed to other apps: the RPPairing and lockdown records
    /// merged into one plist. Rebuilt from those two whenever it's needed.
    static var combinedPairingFile: URL {
        directory.appendingPathComponent("combined_pairing_file.plist")
    }

    /// isideload's `FsStorage` root, created on demand as isideload expects.
    static var isideload: URL {
        let url = resolve(private: directory.appendingPathComponent("isideload", isDirectory: true),
                          legacy: IPALibrary.documentsDir.appendingPathComponent("isideload", isDirectory: true))
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Application Support, which iOS doesn't create for you.
    private static var directory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The private location, falling back to a copy the migration left in
    /// Documents rather than costing a re-pair or a certificate slot.
    private static func resolve(private url: URL, legacy: URL) -> URL {
        _ = migrated
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { return url }
        if fm.fileExists(atPath: legacy.path) { return legacy }
        return url          // nothing yet: new state goes to the private location
    }

    /// Runs `migrate()` once per launch, before the first path is handed out.
    private static let migrated: Void = migrate()

    /// Bring older versions' files across from Documents.
    private static func migrate() {
        let docs = IPALibrary.documentsDir
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        for name in ["rp_pairing_file.plist", "isideload"] {
            relocate(docs.appendingPathComponent(name), to: support.appendingPathComponent(name))
        }
    }

    /// Copy, verify, then delete rather than move: a half-finished move would
    /// cost a re-pair or one of Apple's three certificate slots.
    private static func relocate(_ src: URL, to dest: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: src.path) else { return }
        // An existing destination means the leftover in Documents is stale.
        guard !fm.fileExists(atPath: dest.path) else {
            try? fm.removeItem(at: src)
            return
        }
        do {
            try fm.copyItem(at: src, to: dest)
            guard let before = tally(src), let after = tally(dest), before == after else {
                try? fm.removeItem(at: dest)
                return
            }
            try? fm.removeItem(at: src)
        } catch {
            try? fm.removeItem(at: dest)
        }
    }

    /// (file count, total bytes) under `url`, or nil if it can't be read.
    private static func tally(_ url: URL) -> (Int, Int)? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }
        guard isDir.boolValue else {
            guard let size = (try? fm.attributesOfItem(atPath: url.path)[.size]) as? Int else { return nil }
            return (1, size)
        }
        guard let walker = fm.enumerator(atPath: url.path) else { return nil }
        var count = 0, bytes = 0
        for case let name as String in walker {
            let child = url.appendingPathComponent(name)
            var childIsDir: ObjCBool = false
            guard fm.fileExists(atPath: child.path, isDirectory: &childIsDir), !childIsDir.boolValue
            else { continue }
            guard let size = (try? fm.attributesOfItem(atPath: child.path)[.size]) as? Int else { return nil }
            count += 1
            bytes += size
        }
        return (count, bytes)
    }
}

/// Remembers which IPAs the app downloaded itself, so it can refresh those
/// while leaving a file the user placed in Documents untouched.
enum DownloadLedger {

    private static let defaultsKey = "managedIPAs"

    /// Size and modification time, so a file replaced under the same name stops
    /// matching. Assumes nothing downstream rewrites the IPA in place.
    private static func fingerprint(_ url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let size = (attrs[.size] as? Int) ?? 0
        let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)@\(Int(modified))"
    }

    /// A file's entry key: its path relative to Documents. Relative because the
    /// container UUID changes on update, and a path because an import can share
    /// a filename with a download.
    private static func key(_ url: URL) -> String {
        let docs = IPALibrary.documentsDir.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(docs + "/") else { return url.lastPathComponent }
        return String(path.dropFirst(docs.count + 1))
    }

    private static var table: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// True only for a file this app downloaded and nothing has touched since.
    static func isManaged(_ url: URL) -> Bool {
        guard let fp = fingerprint(url) else { return false }
        return table[key(url)] == fp
    }

    static func record(_ url: URL) {
        guard let fp = fingerprint(url) else { return }
        var t = table
        t[key(url)] = fp
        table = t
    }

    static func forget(_ url: URL) {
        var t = table
        t.removeValue(forKey: key(url))
        table = t
    }
}
