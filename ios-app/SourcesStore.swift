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

    /// C-6：源 JSON 专用 session——不用 shared：30 秒空闲 + 120 秒总时长
    /// 双上限（shared 默认空闲 60 秒、总时长 7 天，一个 trickle 源能挂一行 7 天）。
    private static let fetchSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()
    /// C-6：源 JSON body 上限 10MB（默认源 71KB 的约 140 倍）。
    private static let sourceBodyCap = 10 * 1024 * 1024

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
        // N3(A)：删源时顺带清掉它的磁盘缓存条目，不然删掉的源还占着缓存。
        let removed = offsets.map { sources[$0].url.absoluteString }
        sources.remove(atOffsets: offsets)
        persist()
        Self.removeFromSourceCache(keys: removed)
    }

    /// Disk cache for source documents, in Engine's `releaseCatalogs.json`
    /// shape: a missing or unreadable file just means "fetch fresh". Lets a
    /// document survive an app restart, so reopening the sources page
    /// within 15 minutes doesn't cost another download.
    /// nonisolated：下面四件（URL、队列、两个 Locked helper）全在
    /// `cacheQueue.sync` 的同步闭包里跑——闭包是非隔离上下文，@MainActor
    /// 的成员在里面调不到；它们只碰文件 I/O、不碰 actor 状态，串行化
    /// 由队列给，不靠 MainActor。
    nonisolated private static var sourceCacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("sourceDocuments.json")
    }

    /// A3+A4：磁盘缓存读写走同一条串行队列——fetchAll 并行跑多个源的 fetch，
    /// 只标 nonisolated 不够：MainActor 的序列化拿掉后，两个源的 save 会交错
    /// 读改写同一文件。队列内 helper 后缀 Locked，调用方须已在队列上。
    nonisolated private static let cacheQueue = DispatchQueue(label: "sideinstaller.source-cache")

    nonisolated private static func loadSourceCacheLocked() -> [String: CachedSource] {
        guard let data = try? Data(contentsOf: sourceCacheURL),
              let cached = try? JSONDecoder().decode([String: CachedSource].self, from: data)
        else { return [:] }
        return cached
    }

    nonisolated private static func writeSourceCacheLocked(_ cached: [String: CachedSource]) {
        if let data = try? JSONEncoder().encode(cached) {
            try? data.write(to: sourceCacheURL, options: .atomic)
        }
    }

    /// 读整份磁盘缓存（后台线程上跑，不在主线程）。
    nonisolated private static func loadSourceCache() async -> [String: CachedSource] {
        cacheQueue.sync { loadSourceCacheLocked() }
    }

    /// 写回整份磁盘缓存（后台线程上跑；读改写在队列内一次完成）。
    nonisolated private static func saveSourceCache(url: URL, model: AltSource, fetched: Date = Date()) async {
        cacheQueue.sync {
            var cached = loadSourceCacheLocked()
            cached[url.absoluteString] = CachedSource(model: model, fetched: fetched)
            // N3(A)：顺带淘汰 15 分钟以上的条目（与 fetch 的 TTL 同数），
            // 一次成功 fetch 即压缩全文件，不另起定时任务。
            cached = cached.filter { Date().timeIntervalSince($0.value.fetched) < 15 * 60 }
            writeSourceCacheLocked(cached)
        }
    }

    /// 删源时清它的磁盘缓存条目（同步调用点，仍走同一条队列串行化）。
    private static func removeFromSourceCache(keys: [String]) {
        cacheQueue.sync {
            var cached = loadSourceCacheLocked()
            for key in keys { cached.removeValue(forKey: key) }
            writeSourceCacheLocked(cached)
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

    /// Network + byte loop + decode for one source document, off the main
    /// actor: `SourceStore` is @MainActor, so a plain static func here would
    /// still be MainActor-isolated — `nonisolated` is what moves the work.
    /// Only touches static state (`fetchSession`, `sourceBodyCap`); error
    /// semantics are unchanged. Cancellation: URLSession's async methods
    /// throw `URLError(.cancelled)` (-999) on cancel, NOT CancellationError
    /// (only checkCancellation/Task.sleep guarantee that) — `fetch` catches
    /// both below, so a cancelled fetch leaves no fake error on the row.
    nonisolated private static func fetchSourceDocument(url: URL) async throws -> AltSource {
        var request = URLRequest(url: url)
        request.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await Self.fetchSession.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "SourceStore", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        // C-6：边读边计——声明超限直接抛，不读体；累计超限立即停读。
        if response.expectedContentLength > Int64(Self.sourceBodyCap) {
            throw NSError(domain: "SourceStore", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Source is too large"])
        }
        var data = Data()
        if response.expectedContentLength > 0 {
            data.reserveCapacity(Int(min(response.expectedContentLength, Int64(Self.sourceBodyCap))))
        }
        for try await byte in bytes {
            data.append(byte)
            if data.count > Self.sourceBodyCap {
                throw NSError(domain: "SourceStore", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Source is too large"])
            }
        }
        return try JSONDecoder().decode(AltSource.self, from: data)
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
        if !force, let cached = await Self.loadSourceCache()[url.absoluteString],
           Date().timeIntervalSince(cached.fetched) < 15 * 60 {
            sources[index].model = cached.model
            sources[index].fetchedAt = cached.fetched
            sources[index].errorMessage = nil
            return
        }
        sources[index].isLoading = true
        sources[index].errorMessage = nil
        do {
            let model = try await Self.fetchSourceDocument(url: url)
            guard let index = sources.firstIndex(where: { $0.url == url }) else { return }
            sources[index].model = model
            sources[index].fetchedAt = Date()
            sources[index].isLoading = false
            await Self.saveSourceCache(url: url, model: model)
        } catch is CancellationError {
            // 取消不是错误：只把 isLoading 复位，不写 errorMessage——
            // 视图消失导致 .task 取消时，行上不能留一条假错误。
            guard let index = sources.firstIndex(where: { $0.url == url }) else { return }
            sources[index].isLoading = false
        } catch let error as URLError where error.code == .cancelled {
            // URLSession 的 async 方法取消时抛 URLError(.cancelled)（-999），
            // 不是 CancellationError；与上一分支同处理。
            guard let index = sources.firstIndex(where: { $0.url == url }) else { return }
            sources[index].isLoading = false
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

    /// C-6：源下载的 IPA 上限 8GB——与解压总量上限（enterprise.rs）同数。
    /// 不要与源 JSON 的 10MB 共用一个常量：IPA 常规就是几十 MB 到 1GB+，
    /// 10MB 会断掉几乎全部源安装。
    private static let ipaDownloadCap: Int64 = 8 * 1024 * 1024 * 1024

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
        // C-4：当场结算旧 continuation，不等 delegate 回调——旧错随后到时
        // continuation 已是 nil，finish 的守卫让它空操作，不会二次恢复。
        // 只做 A（同步结算），不做 generation：旧 Task 的泄漏只有 A 能堵。
        finish(.failure(URLError(.cancelled)))
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
        // C-6：超 8GB 即停——检查必须放在 totalBytesExpectedToWrite 的
        // guard 之前（未知总长的下载它是 -1，放 guard 里就永远查不到）。
        if totalBytesWritten > Self.ipaDownloadCap {
            downloadTask.cancel()
            return
        }
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
            // N3(C)：建目录/移文件失败也会留一个空 ipa-source-* 目录，顺手删掉。
            try? FileManager.default.removeItem(at: staging)
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
