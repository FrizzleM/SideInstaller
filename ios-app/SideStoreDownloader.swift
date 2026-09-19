import Compression
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

    /// GitHub Releases API URL for a channel, used only when the direct download
    /// 404s. Nightly uses the `nightly` tag since `/releases/latest` skips
    /// pre-releases.
    func releaseAPI(_ channel: ReleaseChannel) -> URL? {
        guard let repo else { return nil }
        let base = "https://api.github.com/repos/\(repo)/releases"
        switch channel {
        case .stable:  return URL(string: "\(base)/latest")!
        case .nightly: return URL(string: "\(base)/tags/nightly")!
        }
    }

    /// Published `.ipa` asset name, used to build the direct download URL.
    var assetFileName: String? {
        switch self {
        case .sideStore:     return "SideStore.ipa"
        case .liveContainer: return "LiveContainer+SideStore.ipa"
        case .custom:        return nil
        }
    }

    /// Direct github.com download URL. Preferred over the API, which has a
    /// per-IP rate limit.
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
    // After install, the pairing file is written into the host app's container.
    // The app and path depend on the build (like iLoader's PAIRING_APPS table).

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
        /// Optional so decoding doesn't depend on it. Used by the release scan to
        /// keep stable requests off pre-releases.
        let prerelease: Bool?
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
        /// A pasted link returned a non-2xx status (kept separate from the
        /// GitHub-specific `badStatus`).
        case linkStatus(Int)

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
                // Replace GitHub's rate-limit text with when to retry.
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
            case let .linkStatus(status):
                // Usually 401/403: the link requires signing in.
                return L("that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.",
                         status)
            }
        }

        /// True when downloading the IPA another way would help (network
        /// interference), not for rate limits or missing releases.
        var manualSideloadHelps: Bool {
            switch self {
            case .unreachable, .badRelease, .notAnIPA:
                return true
            case .noIPAAsset, .noRelease, .badURL, .notDownloadable, .linkStatus:
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

        /// True when the channel's release is missing or has no usable IPA, so
        /// the repo's other releases should be scanned.
        var isChannelEmpty: Bool {
            switch self {
            case .noIPAAsset, .noRelease:
                return true
            case .badURL, .notDownloadable, .badStatus, .unreachable,
                 .badRelease, .notAnIPA, .linkStatus:
                return false
            }
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
        /// Channel of the release the file actually came from (can differ from
        /// the requested one after `fetchViaReleaseScan`). Used for the filename.
        let channel: ReleaseChannel
        /// GitHub's ETag for the file, so a later run can tell it hasn't changed.
        let etag: String?
    }

    /// Returns the local path of the downloaded IPA. `log` receives progress.
    static func downloadLatest(source: InstallSource,
                               channel: ReleaseChannel,
                               log: @escaping (String) -> Void) async throws -> String {
        guard let direct = source.downloadURL(channel), let assetName = source.assetFileName else {
            throw DownloadError.notDownloadable
        }

        // Tens of megabytes aren't fetched again while the copy from an earlier
        // run is still the file GitHub serves.
        if let current = await unchangedDownload(source: source, channel: channel, at: direct, log: log) {
            return current.path
        }

        let fetched: Fetched
        do {
            fetched = try await fetch(direct, named: assetName, from: channel, log: log)
        } catch let error as DownloadError where error.isAssetMissing {
            log("No \(assetName) on that release — asking GitHub's API what the asset is called now.")
            do {
                fetched = try await fetchViaAPI(source: source, channel: channel, log: log)
            } catch let error as DownloadError where error.isChannelEmpty {
                fetched = try await fetchViaReleaseScan(source: source, channel: channel, log: log)
            }
        }

        // Validate now, so an error page or truncated download doesn't fail
        // later during signing.
        guard IPALibrary.looksLikeIPA(fetched.file) else {
            try? FileManager.default.removeItem(at: fetched.file)
            throw DownloadError.notAnIPA(fetched.name)
        }

        let dest = IPALibrary.documentsDir.appendingPathComponent(source.fileName(fetched.channel))
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: fetched.file, to: dest)
        // Mark as app-downloaded, so later runs may replace it, or reuse it while
        // GitHub still serves the same file.
        DownloadLedger.record(dest, etag: fetched.etag)
        return dest.path
    }

    /// The IPA an earlier run downloaded for this build, if GitHub still serves
    /// that exact file at `url`.
    ///
    /// Only the headers are fetched (a HEAD request). The file must be one this
    /// app downloaded and nothing has touched since, its recorded ETag must match
    /// GitHub's current one, and its size the Content-Length. Anything else,
    /// including a failed request, returns nil so the caller downloads as usual.
    private static func unchangedDownload(source: InstallSource, channel: ReleaseChannel,
                                          at url: URL,
                                          log: @escaping (String) -> Void) async -> URL? {
        let file = IPALibrary.documentsDir.appendingPathComponent(source.fileName(channel))
        guard let recorded = DownloadLedger.etag(for: file),
              let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? Int
        else { return nil }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.httpMethod = "HEAD"
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let redirects = ReleaseTagRecorder()
        guard let result = try? await URLSession.shared.data(for: req, delegate: redirects),
              let http = result.1 as? HTTPURLResponse, http.statusCode == 200,
              http.value(forHTTPHeaderField: "ETag") == recorded,
              http.value(forHTTPHeaderField: "Content-Length").flatMap(Int.init) == size,
              IPALibrary.looksLikeIPA(file)
        else { return nil }

        let tag = redirects.tag.map { " (release \($0))" } ?? ""
        log("\(file.lastPathComponent) is already the file GitHub serves\(tag) — skipping the download.")
        return file
    }

    /// Download one URL to a temporary file, if the response isn't a refusal.
    private static func fetch(_ url: URL, named name: String, from channel: ReleaseChannel,
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
        return Fetched(file: file, name: name, channel: channel,
                       etag: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag"))
    }

    /// Downloads a pasted link into its own temp directory, saved as `name`.
    /// `progress` is called on an arbitrary queue.
    ///
    /// Separate from `fetch`: there's no release tag to record, and errors refer
    /// to the link rather than GitHub.
    static func fetchDirect(_ url: URL,
                            named name: String,
                            progress: @escaping (Double) -> Void) async throws -> URL {
        var req = URLRequest(url: url)
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("ipa-link-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let dest = staging.appendingPathComponent(name)

        return try await withCheckedThrowingContinuation { cont in
            // Progress is observed via KVO on the task's `Progress` instead of
            // a download delegate, which would conflict over the downloaded file.
            var observation: NSKeyValueObservation?
            let task = URLSession.shared.downloadTask(with: req) { file, response, error in
                observation?.invalidate()
                do {
                    if let error { throw error }
                    guard let file, let http = response as? HTTPURLResponse else {
                        throw DownloadError.badURL
                    }
                    guard (200...299).contains(http.statusCode) else {
                        throw DownloadError.linkStatus(http.statusCode)
                    }
                    // The temp file is deleted when this handler returns, so
                    // move it now.
                    try FileManager.default.moveItem(at: file, to: dest)
                    cont.resume(returning: dest)
                } catch let urlError as URLError {
                    cont.resume(throwing: urlError.code == .cancelled
                                ? CancellationError() : DownloadError.unreachable(urlError))
                } catch {
                    cont.resume(throwing: error)
                }
            }
            observation = task.progress.observe(\.fractionCompleted) { done, _ in
                progress(done.fractionCompleted)
            }
            task.resume()
        }
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
            // The status was 2xx, so this is a real decode failure.
            throw DownloadError.badRelease(String(describing: error))
        }
        log("\(channel.displayName) \(source.displayName) release: \(release.tag_name) with \(release.assets.count) assets")

        guard let asset = source.selectAsset(from: release.assets) else {
            throw DownloadError.noIPAAsset(source.displayName, channel)
        }
        guard let assetURL = URL(string: asset.browser_download_url) else {
            throw DownloadError.badURL
        }
        return try await fetch(assetURL, named: asset.name, from: channel, log: log)
    }

    /// Scans the repo's recent releases for the newest one that has this build,
    /// used when the channel's own release doesn't.
    ///
    /// Needed for LiveContainer: its rolling `nightly` release can carry only
    /// `LiveContainer.ipa`, so the newest `LiveContainer+SideStore.ipa` is on a
    /// tagged release.
    ///
    /// Stable requests never fall back to a pre-release. Nightly requests take
    /// the newest release of either kind.
    private static func fetchViaReleaseScan(source: InstallSource,
                                            channel: ReleaseChannel,
                                            log: @escaping (String) -> Void) async throws -> Fetched {
        guard let repo = source.repo,
              let api = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=20")
        else { throw DownloadError.notDownloadable }

        log("That release has no \(source.displayName) IPA — looking through \(repo)'s other releases for one.")
        var req = URLRequest(url: api)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await perform { try await URLSession.shared.data(for: req) }
        try check(response, body: data)

        let releases: [GHRelease]
        do {
            releases = try JSONDecoder().decode([GHRelease].self, from: data)
        } catch {
            throw DownloadError.badRelease(String(describing: error))
        }

        // Newest first, which is the order GitHub answers in.
        for release in releases {
            if channel == .stable, release.prerelease == true { continue }
            guard let asset = source.selectAsset(from: release.assets),
                  let assetURL = URL(string: asset.browser_download_url) else { continue }
            // Save under the release's actual channel, not the requested one.
            let served: ReleaseChannel = release.prerelease == true ? .nightly : .stable
            log("\(source.displayName) isn't published on the \(channel.displayName.lowercased()) release — taking \(asset.name) from release \(release.tag_name) instead.")
            return try await fetch(assetURL, named: asset.name, from: served, log: log)
        }
        throw DownloadError.noIPAAsset(source.displayName, channel)
    }

    /// Runs a URLSession call, mapping `URLError` to `.unreachable` (or to
    /// `CancellationError` when cancelled).
    private static func perform<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as URLError {
            // A cancelled install arrives as a URLError, and isn't a failure.
            if error.code == .cancelled { throw CancellationError() }
            throw DownloadError.unreachable(error)
        }
    }

    /// Throws `badStatus` for a non-2xx response, before the body is decoded.
    private static func check(_ response: URLResponse, body: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw DownloadError.badStatus(status: http.statusCode,
                                          detail: body.flatMap(errorMessage(in:)),
                                          retryAfter: retryAfter(http))
        }
    }

    /// Retry time for a GitHub rate limit: from `retry-after` (seconds), or from
    /// `x-ratelimit-reset` (Unix time) when the hourly quota is used up.
    private static func retryAfter(_ http: HTTPURLResponse) -> Date? {
        if let seconds = http.value(forHTTPHeaderField: "retry-after").flatMap(Double.init) {
            return Date().addingTimeInterval(seconds)
        }
        guard http.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0",
              let reset = http.value(forHTTPHeaderField: "x-ratelimit-reset").flatMap(Double.init)
        else { return nil }
        return Date(timeIntervalSince1970: reset)
    }

    /// The `message` field of GitHub's JSON error body.
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
        guard task.originalRequest?.httpMethod == "HEAD" else {
            completionHandler(request)      // follow it, unchanged
            return
        }
        // A HEAD stays a HEAD all the way down, so checking a file never downloads it.
        var head = request
        head.httpMethod = "HEAD"
        head.cachePolicy = .reloadIgnoringLocalCacheData
        completionHandler(head)
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

/// IPAs in the app's Documents directory, whether downloaded, imported, or
/// copied in with the Files app.
enum IPALibrary {

    /// Where both the downloader and the Files app write.
    static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Folder for the imported custom IPA, separate so its name can't clash with
    /// a download.
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

    /// Thrown when the picked file isn't an IPA.
    enum ImportError: Error {
        case notAnIPA
    }

    /// Replaces the custom import with `url`, forcing a `.ipa` extension.
    /// Blocking. Copies to a staging directory first, so only a complete, valid
    /// IPA replaces the old one. The caller handles security-scoped access.
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

// MARK: - What an IPA will install

/// Reads `Payload/<name>.app/Info.plist` directly from an IPA using the zip
/// central directory, without unpacking the archive. The Sideloaded apps page
/// uses this to match IPAs on disk to installed apps. ZIP64 isn't supported.
extension IPALibrary {

    /// What an `.ipa` says it will put on the device.
    struct AppInfo: Equatable {
        /// Bundle ID as published. After isideload signs it, the installed app's
        /// ID has `.<teamID>` appended, so matching must allow for that.
        let bundleID: String
        let name: String
        let version: String?
    }

    /// IPAs on disk with their app info, newest first, one per bundle ID (the
    /// same build can exist as both a download and an import).
    static func installable() -> [(entry: Entry, info: AppInfo)] {
        var seen = Set<String>()
        return scan().compactMap { entry in
            guard let info = appInfo(at: entry.url),
                  seen.insert(info.bundleID).inserted else { return nil }
            return (entry, info)
        }
    }

    /// Reads an IPA's main `Info.plist`. Nil if it can't be read; such files are
    /// left out of the refresh list.
    static func appInfo(at url: URL) -> AppInfo? {
        guard let raw = infoPlist(inIPA: url),
              let plist = try? PropertyListSerialization.propertyList(from: raw, format: nil),
              let dict = plist as? [String: Any],
              let bundleID = dict["CFBundleIdentifier"] as? String, !bundleID.isEmpty
        else { return nil }
        let display = dict["CFBundleDisplayName"] as? String
        let bundleName = dict["CFBundleName"] as? String
        let name = display?.isEmpty == false ? display!
            : (bundleName?.isEmpty == false ? bundleName! : bundleID)
        return AppInfo(bundleID: bundleID, name: name,
                       version: dict["CFBundleShortVersionString"] as? String)
    }

    /// One entry of the archive's central directory.
    private struct ZipEntry {
        let name: String
        let method: Int
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private static func infoPlist(inIPA url: URL) -> Data? {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int,
              size > 22,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let directory = centralDirectory(handle, fileSize: size),
              let entry = mainInfoPlist(in: directory) else { return nil }
        return contents(of: entry, handle)
    }

    /// The central directory, found through the end-of-central-directory record
    /// in the archive's last 64 KB.
    private static func centralDirectory(_ handle: FileHandle, fileSize: Int) -> [ZipEntry]? {
        let tailLength = min(fileSize, 65_557)      // the record plus a full comment
        guard (try? handle.seek(toOffset: UInt64(fileSize - tailLength))) != nil,
              let tail = try? handle.readToEnd(),
              let found = tail.range(of: Data([0x50, 0x4B, 0x05, 0x06]), options: .backwards)
        else { return nil }
        let record = tail[found.lowerBound...]
        guard record.count >= 22 else { return nil }
        let offset = u32(record, 16)
        let length = u32(record, 12)
        // 0xFFFFFFFF puts the real numbers in a ZIP64 record this doesn't read.
        guard offset != 0xFFFF_FFFF, length > 0, offset + length <= fileSize,
              (try? handle.seek(toOffset: UInt64(offset))) != nil,
              let raw = try? handle.read(upToCount: length), raw.count == length
        else { return nil }
        return entries(in: raw)
    }

    private static func entries(in directory: Data) -> [ZipEntry] {
        var out: [ZipEntry] = []
        var cursor = 0
        while cursor + 46 <= directory.count {
            let header = directory[(directory.startIndex + cursor)...]
            guard u32(header, 0) == 0x0201_4B50 else { break }      // "PK\u{01}\u{02}"
            let nameLength = u16(header, 28)
            let total = 46 + nameLength + u16(header, 30) + u16(header, 32)
            guard cursor + total <= directory.count else { break }
            let start = header.startIndex + 46
            if let name = String(data: header[start..<(start + nameLength)], encoding: .utf8) {
                out.append(ZipEntry(name: name,
                                    method: u16(header, 10),
                                    compressedSize: u32(header, 20),
                                    uncompressedSize: u32(header, 24),
                                    localHeaderOffset: u32(header, 42)))
            }
            cursor += total
        }
        return out
    }

    /// The one app's own `Info.plist`: exactly `Payload/<name>.app/Info.plist`,
    /// which leaves out the ones inside nested extensions and frameworks.
    private static func mainInfoPlist(in entries: [ZipEntry]) -> ZipEntry? {
        entries.first { entry in
            let parts = entry.name.split(separator: "/", omittingEmptySubsequences: false)
            return parts.count == 3 && parts[0] == "Payload"
                && parts[1].hasSuffix(".app") && parts[2] == "Info.plist"
        }
    }

    private static func contents(of entry: ZipEntry, _ handle: FileHandle) -> Data? {
        // Sanity limit: an Info.plist is only kilobytes, and the inflate below
        // allocates this size.
        guard entry.uncompressedSize > 0, entry.uncompressedSize < 4 << 20,
              entry.compressedSize > 0,
              (try? handle.seek(toOffset: UInt64(entry.localHeaderOffset))) != nil,
              let header = try? handle.read(upToCount: 30), header.count == 30,
              u32(header, 0) == 0x0403_4B50                        // "PK\u{03}\u{04}"
        else { return nil }
        // The local header repeats the name and carries its own extra field,
        // whose length routinely differs from the central directory's.
        let dataOffset = entry.localHeaderOffset + 30 + u16(header, 26) + u16(header, 28)
        guard (try? handle.seek(toOffset: UInt64(dataOffset))) != nil,
              let raw = try? handle.read(upToCount: entry.compressedSize),
              raw.count == entry.compressedSize else { return nil }
        switch entry.method {
        case 0: return raw                                          // stored
        case 8: return inflate(raw, to: entry.uncompressedSize)      // deflated
        default: return nil
        }
    }

    /// `COMPRESSION_ZLIB` is raw DEFLATE with no zlib wrapper, which is exactly
    /// what a zip member holds.
    private static func inflate(_ data: Data, to size: Int) -> Data? {
        var out = Data(count: size)
        let written = out.withUnsafeMutableBytes { dst -> Int in
            guard let target = dst.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return data.withUnsafeBytes { src -> Int in
                guard let source = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(target, size, source, data.count, nil,
                                                 COMPRESSION_ZLIB)
            }
        }
        return written == size ? out : nil
    }

    /// Little-endian reads relative to a slice's own start, which is where every
    /// offset in the format above is measured from.
    private static func u16(_ data: Data, _ at: Int) -> Int {
        let i = data.startIndex + at
        guard i >= data.startIndex, i + 1 < data.endIndex else { return 0 }
        return Int(data[i]) | Int(data[i + 1]) << 8
    }

    private static func u32(_ data: Data, _ at: Int) -> Int {
        u16(data, at) | u16(data, at + 2) << 16
    }
}

/// State kept in Application Support rather than the file-sharing-visible
/// Documents: the device pairing record, and isideload's certificate store.
enum PrivateStore {

    /// The device pairing file (from the RPPairing host, or imported).
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

    /// Lockdown pair record for another device on the LAN (Side by Side), one
    /// file per IP address. Separate from `lockdownPairRecord`, which belongs to
    /// this iPhone.
    ///
    /// Keyed by address because the UDID isn't known before connecting. A record
    /// that stops working is created again.
    static func peerPairRecord(host: String) -> URL {
        peerPairingsFile(prefix: "lockdown", host: host)
    }

    /// RPPairing file for another device on the LAN (Side by Side), written when
    /// it pairs from its own Settings — the only way iOS 27 pairs over Wi-Fi.
    /// Separate from `pairingFile`, which belongs to this iPhone. Keyed by
    /// address like `peerPairRecord`.
    static func peerRemotePairing(host: String) -> URL {
        peerPairingsFile(prefix: "remote", host: host)
    }

    private static func peerPairingsFile(prefix: String, host: String) -> URL {
        let dir = directory.appendingPathComponent("peer-pairings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Keep only digits and dots for a safe filename.
        let key = host.filter { $0.isNumber || $0 == "." }
        return dir.appendingPathComponent("\(prefix)-\(key.isEmpty ? "unknown" : key).plist")
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

    /// The private location, or the old Documents copy if migration left one
    /// there.
    private static func resolve(private url: URL, legacy: URL) -> URL {
        _ = migrated
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { return url }
        if fm.fileExists(atPath: legacy.path) { return legacy }
        return url          // nothing yet: new state goes to the private location
    }

    /// Runs `migrate()` once per launch, before the first path is handed out.
    private static let migrated: Void = migrate()

    /// Moves files that were stored in Documents into Application Support.
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
    private static let etagsKey = "managedIPAETags"

    /// Size and modification time, so a file replaced under the same name stops
    /// matching. Assumes nothing downstream rewrites the IPA in place.
    private static func fingerprint(_ url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let size = (attrs[.size] as? Int) ?? 0
        let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)@\(Int(modified))"
    }

    /// Ledger key: the path relative to Documents (the container path changes on
    /// app updates, and an import can share a filename with a download).
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

    /// ETags by ledger key, each stored as "<fingerprint>|<etag>" so it only ever
    /// describes the exact file it was recorded with.
    private static var etags: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: etagsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: etagsKey) }
    }

    static func record(_ url: URL, etag: String? = nil) {
        guard let fp = fingerprint(url) else { return }
        var t = table
        t[key(url)] = fp
        table = t
        // Replaced, or dropped when this download came without one.
        var e = etags
        e[key(url)] = etag.map { "\(fp)|\($0)" }
        etags = e
    }

    /// The ETag GitHub served `url` with, while the file is still exactly the one
    /// that was downloaded.
    static func etag(for url: URL) -> String? {
        guard let fp = fingerprint(url), table[key(url)] == fp,
              let entry = etags[key(url)], entry.hasPrefix(fp + "|") else { return nil }
        return String(entry.dropFirst(fp.count + 1))
    }

    static func forget(_ url: URL) {
        var t = table
        t.removeValue(forKey: key(url))
        table = t
        var e = etags
        e.removeValue(forKey: key(url))
        etags = e
    }
}
