import Foundation

// MARK: - AltStore source format

/// One app in an AltStore-format source. Every field is optional at decode
/// time, since real-world sources omit some and vary others (a `versionDate`
/// can be a full timestamp or a bare date, so it stays a string). Entries
/// without a name or a download link are filtered out in `AltSource.validApps`.
struct AltApp: Codable {
    let name: String?
    let bundleIdentifier: String?
    let version: String?
    let downloadURL: String?
    let iconURL: String?
    let size: Int?
    let subtitle: String?
    let localizedDescription: String?
    let versionDate: String?
    let minOSVersion: String?
    let developerName: String?

    /// Stable identity for lists: the bundle id when there is one, else the
    /// download link, which the filter below guarantees.
    var id: String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty { return bundleIdentifier }
        return downloadURL ?? name ?? ""
    }

    /// The download link as a URL, nil when the string isn't one.
    var downloadLink: URL? {
        guard let downloadURL, !downloadURL.isEmpty else { return nil }
        return URL(string: downloadURL)
    }

    /// The icon as a URL, nil when absent or malformed.
    var iconLink: URL? {
        guard let iconURL, !iconURL.isEmpty else { return nil }
        return URL(string: iconURL)
    }

    /// Human-readable size, e.g. "42.3 MB"; nil when the source doesn't say.
    var sizeText: String? {
        guard let size, size > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

/// An AltStore-format source document: a name and a list of apps.
struct AltSource: Codable {
    let name: String?
    let identifier: String?
    let subtitle: String?
    let iconURL: String?
    let apps: [AltApp]?

    /// The apps that can actually be shown and installed: both a name and a
    /// usable download link are required.
    var validApps: [AltApp] {
        (apps ?? []).filter { app in
            guard let name = app.name, !name.isEmpty else { return false }
            return app.downloadLink != nil
        }
    }

    /// The source's icon as a URL, nil when absent or malformed.
    var iconLink: URL? {
        guard let iconURL, !iconURL.isEmpty else { return nil }
        return URL(string: iconURL)
    }
}

/// A source the user added, with its fetch state.
struct LoadedSource: Identifiable {
    let url: URL
    var model: AltSource?
    var isLoading = false
    var errorMessage: String?
    /// When `model` was last fetched (network or disk cache); nil if never.
    /// Drives the 15-minute TTL in `fetch(_:force:)`.
    var fetchedAt: Date?

    var id: String { url.absoluteString }

    /// The source's own name once loaded, else its host.
    var displayName: String {
        if let name = model?.name, !name.isEmpty { return name }
        return url.host ?? url.absoluteString
    }

    /// The installable apps in the loaded document.
    var apps: [AltApp] { model?.validApps ?? [] }
}

/// One source document as kept on disk: the decoded model plus when it was
/// fetched. Mirrors Engine's `ReleaseCatalog` (`fetched`) shape.
private struct CachedSource: Codable {
    let model: AltSource
    let fetched: Date
}

// MARK: - Store

/// The user's app sources: the list is kept in UserDefaults, the documents
/// themselves are fetched on demand.
@MainActor
final class SourceStore: ObservableObject {

    @Published var sources: [LoadedSource] = []

    /// UserDefaults key for the source URL strings.
    static let urlsKey = "CZFAppSourceURLs"

    /// Preset on first run, when the user has never had a source list.
    static let defaultSourceURL = "https://xiaofang-source.pages.dev/source.json"

    init() {
        var stored = UserDefaults.standard.stringArray(forKey: Self.urlsKey)
        if stored == nil {
            stored = [Self.defaultSourceURL]
            UserDefaults.standard.set(stored, forKey: Self.urlsKey)
        }
        sources = (stored ?? []).compactMap { URL(string: $0) }
            .map { LoadedSource(url: $0) }
    }

    /// Add a source by its address text: validated like a pasted IPA link,
    /// de-duplicated, saved, and fetched. Returns false for an unusable link
    /// or one already in the list.
    @discardableResult
    func addSource(_ urlString: String) -> Bool {
        guard let url = Engine.downloadLink(urlString) else { return false }
        guard !sources.contains(where: { $0.url.absoluteString == url.absoluteString })
        else { return false }
        sources.append(LoadedSource(url: url))
        persist()
        Task { await fetch(url) }
        return true
    }

    /// Remove the sources at `offsets` (a list swipe) and save the list.
    func removeSource(at offsets: IndexSet) {
        sources.remove(atOffsets: offsets)
        persist()
    }

    /// Disk cache for source documents, in Engine's `releaseCatalogs.json`
    /// shape: a missing or unreadable file just means "fetch fresh". Lets a
    /// document survive an app restart, so reopening the sources page
    /// within 15 minutes doesn't cost another download.
    private static var sourceCacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("sourceDocuments.json")
    }

    private static func loadSourceCache() -> [String: CachedSource] {
        guard let data = try? Data(contentsOf: sourceCacheURL),
              let cached = try? JSONDecoder().decode([String: CachedSource].self, from: data)
        else { return [:] }
        return cached
    }

    private static func saveSourceCache(url: URL, model: AltSource, fetched: Date = Date()) {
        var cached = loadSourceCache()
        cached[url.absoluteString] = CachedSource(model: model, fetched: fetched)
        if let data = try? JSONEncoder().encode(cached) {
            try? data.write(to: sourceCacheURL, options: .atomic)
        }
    }

    /// Fetch every source, in parallel. `force` (pull-to-refresh) skips the
    /// 15-minute cache; entry and detail `.task` calls use the cache.
    func fetchAll(force: Bool = false) async {
        await withTaskGroup(of: Void.self) { group in
            for source in sources {
                group.addTask { await self.fetch(source.url, force: force) }
            }
        }
    }

    /// Fetch (or refetch) one source document. Within 15 minutes of the last
    /// successful fetch, a cached document (memory, then disk) is used
    /// instead of the network, mirroring `loadReleaseCatalog`'s TTL; `force`
    /// skips the cache. Decoding is tolerant: a body that isn't a source
    /// document is reported as the row's error.
    func fetch(_ url: URL, force: Bool = false) async {
        guard let index = sources.firstIndex(where: { $0.url == url }) else { return }
        // Memory cache, same 15-minute rule as loadReleaseCatalog.
        if !force, let fetchedAt = sources[index].fetchedAt,
           sources[index].model != nil,
           Date().timeIntervalSince(fetchedAt) < 15 * 60 {
            // 3.8.900（SIDE-4/S4）：缓存命中也要清掉旧的 errorMessage——
            // 上次下拉失败留下的错不能继续盖在有效的缓存模型上（列表
            // 行有 model 时也优先显示 errorMessage；磁盘命中那路已清）。
            sources[index].errorMessage = nil
            return
        }
        // Disk cache, same 15-minute rule: a document saved by an earlier
        // launch still counts, so reopening the sources page doesn't refetch.
        // isLoading is left alone here — a fetch may already be in flight.
        if !force, let cached = Self.loadSourceCache()[url.absoluteString],
           Date().timeIntervalSince(cached.fetched) < 15 * 60 {
            sources[index].model = cached.model
            sources[index].fetchedAt = cached.fetched
            sources[index].errorMessage = nil
            return
        }
        sources[index].isLoading = true
        sources[index].errorMessage = nil
        do {
            var request = URLRequest(url: url)
            request.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw NSError(domain: "SourceStore", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            }
            let model = try JSONDecoder().decode(AltSource.self, from: data)
            guard let index = sources.firstIndex(where: { $0.url == url }) else { return }
            sources[index].model = model
            sources[index].fetchedAt = Date()
            sources[index].isLoading = false
            Self.saveSourceCache(url: url, model: model)
        } catch {
            guard let index = sources.firstIndex(where: { $0.url == url }) else { return }
            sources[index].errorMessage = error.localizedDescription
            sources[index].isLoading = false
        }
    }

    private func persist() {
        UserDefaults.standard.set(sources.map(\.url.absoluteString), forKey: Self.urlsKey)
    }
}

// MARK: - IPA download with progress

/// Downloads one IPA from a source into a private staging folder in the
/// temporary directory, reporting progress. The file keeps the name
/// `Engine.importFileName(for:)` gives its URL, so the custom-import slot it
/// is handed to next names it the same way a pasted link would.
@MainActor
final class IPADownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {

    @Published private(set) var progress: Double = 0

    private var session: URLSession?
    private var continuation: CheckedContinuation<URL, Error>?

    /// Download `url` and return the staged file. Throws on a non-2xx answer
    /// or a transport error.
    func download(from url: URL) async throws -> URL {
        cancel()
        progress = 0
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        var request = URLRequest(url: url)
        request.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            task.resume()
        }
    }

    /// Stop an in-flight download, if any.
    func cancel() {
        session?.invalidateAndCancel()
        session = nil
    }

    /// Resume the waiting download exactly once.
    private func finish(_ result: Result<URL, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    // The delegate callbacks arrive on the session's own queue, so each hops
    // back to the main actor before touching state.

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in self.progress = fraction }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // The downloaded file is deleted when this callback returns, so it is
        // moved into staging here, on this queue.
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            let error = NSError(domain: "IPADownloader", code: http.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            Task { @MainActor in self.finish(.failure(error)) }
            return
        }
        guard let source = downloadTask.originalRequest?.url else {
            Task { @MainActor in self.finish(.failure(URLError(.badURL))) }
            return
        }
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("ipa-source-\(UUID().uuidString)", isDirectory: true)
        let dest = staging.appendingPathComponent(Engine.importFileName(for: source))
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: dest)
            Task { @MainActor in self.finish(.success(dest)) }
        } catch {
            Task { @MainActor in self.finish(.failure(error)) }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        // A successful download has already finished in
        // `didFinishDownloadingTo`; this only carries failures and cancels.
        guard let error else { return }
        Task { @MainActor in self.finish(.failure(error)) }
    }
}
