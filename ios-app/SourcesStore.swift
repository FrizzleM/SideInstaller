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
        return CZFFormattedSize.size(size)
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

/// The one source-URL list both source pages read: the fork's Sources tab
/// (`SourceStore`, key `CZFAppSourceURLs`, default xiaofang-source) and the
/// upstream Sources page (`SourcesManager`, key `sources.urls`, built-in
/// frizzlem.json) used to keep separate lists, so a source added on one page
/// never showed on the other. Both stores now load and save this list; the
/// documents each store fetches stay its own, so add / remove / refresh
/// behaviour on either page is unchanged.
///
/// Migration runs once, at first launch: the two old lists are merged in
/// order (fork list first, then upstream-only URLs), de-duplicated by URL
/// string, with the built-in source leading. Nothing is dropped — a source
/// the user deleted before the migration stays deleted (only a never-set
/// fork list seeds its default). The old keys are left in place, so an
/// older build still reads its own list if the user goes back.
enum UnifiedSourceList {

    /// The single persisted list.
    static let key = "CZFUnifiedSourceURLs"
    /// Set once the one-time migration below has run.
    static let migratedKey = "CZFSourceListMigrated"
    /// The fork list's key (see `SourceStore.urlsKey`).
    static let legacyForkKey = "CZFAppSourceURLs"
    /// The upstream page's key (was `SourcesManager.storeKey`).
    static let legacyUpstreamKey = "sources.urls"
    /// The fork's default source.
    static let forkDefaultURL = "https://xiaofang-source.pages.dev/source.json"
    /// FrizzleM's source: first in every list, and it can't be removed
    /// (both stores guard it, as `SourcesManager` always did).
    static let builtInURL = URL(string: "https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/frizzlem.json")!

    /// Posted whenever the list is saved, so the page that isn't on screen
    /// re-reads it when it appears (and while it is open).
    static let didChange = Notification.Name("CZFUnifiedSourceListDidChange")

    /// Merge the two old lists into the one list, once.
    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        var merged: [String] = []
        func append(_ strings: [String]?) {
            for string in strings ?? [] where !merged.contains(string) {
                merged.append(string)
            }
        }
        // The fork list: nil means first run, so the fork default seeds it;
        // a list that exists is taken as-is, even when the user deleted the
        // default from it.
        let forkStored = UserDefaults.standard.stringArray(forKey: legacyForkKey)
        if forkStored == nil { merged.append(forkDefaultURL) }
        append(forkStored)
        append(UserDefaults.standard.stringArray(forKey: legacyUpstreamKey))
        // The built-in source was never persisted by either list, and it
        // can't be removed: it always leads the unified list.
        merged.removeAll { $0 == builtInURL.absoluteString }
        merged.insert(builtInURL.absoluteString, at: 0)
        UserDefaults.standard.set(merged, forKey: key)
        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    /// The unified list, migrated first. The built-in source is always
    /// first; a list that somehow lost its place gets it back at the front.
    static func load() -> [URL] {
        migrateIfNeeded()
        var strings = UserDefaults.standard.stringArray(forKey: key) ?? []
        if strings.first != builtInURL.absoluteString {
            strings.removeAll { $0 == builtInURL.absoluteString }
            strings.insert(builtInURL.absoluteString, at: 0)
            UserDefaults.standard.set(strings, forKey: key)
        }
        return strings.compactMap(URL.init(string:))
    }

    /// Persist the list and tell the other page.
    static func save(_ urls: [URL]) {
        migrateIfNeeded()
        UserDefaults.standard.set(urls.map(\.absoluteString), forKey: key)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// The disabled sources, by absolute URL string (F1, 0.9.152): a
    /// disabled source stays listed and keeps its disk cache, but is never
    /// fetched and never counts toward updates.
    static let disabledKey = "CZFDisabledSourceURLs"

    static func disabledURLs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: disabledKey) ?? [])
    }

    static func isDisabled(_ url: URL) -> Bool {
        disabledURLs().contains(url.absoluteString)
    }

    /// Persist one source's disabled state and tell the other page.
    static func setDisabled(_ url: URL, disabled: Bool) {
        var set = disabledURLs()
        if disabled { set.insert(url.absoluteString) } else { set.remove(url.absoluteString) }
        UserDefaults.standard.set(Array(set), forKey: disabledKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

// MARK: - Store

/// The user's app sources: the list is kept in UserDefaults, the documents
/// themselves are fetched on demand.
@MainActor
final class SourceStore: ObservableObject {

    @Published var sources: [LoadedSource] = []
    /// The disabled sources, by absolute URL string (F1, 0.9.152): kept
    /// here so rows redraw when one flips; the truth lives in
    /// `UnifiedSourceList`.
    @Published private(set) var disabled: Set<String> = UnifiedSourceList.disabledURLs()

    /// UserDefaults key for the source URL strings. Legacy since 0.9.143:
    /// the list now lives under `UnifiedSourceList.key`; this key is only
    /// read once, by the migration, and left in place for older builds.
    static let urlsKey = "CZFAppSourceURLs"

    /// Preset on first run, when the user has never had a source list.
    static let defaultSourceURL = UnifiedSourceList.forkDefaultURL

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
        sources = UnifiedSourceList.load().map { LoadedSource(url: $0) }
        disabled = UnifiedSourceList.disabledURLs()
    }

    /// Re-read the unified list (the other page saved it): keep the loaded
    /// documents of sources still listed, add new ones unloaded, drop
    /// removed ones. Called when the page appears and when the list changes.
    func syncURLs() {
        let urls = UnifiedSourceList.load()
        disabled = UnifiedSourceList.disabledURLs()
        var kept: [URL: LoadedSource] = [:]
        for source in sources { kept[source.url] = source }
        sources = urls.map { kept[$0] ?? LoadedSource(url: $0) }
    }

    func isDisabled(_ url: URL) -> Bool { disabled.contains(url.absoluteString) }

    /// Flip one source's disabled state (F1, 0.9.152): persisted in
    /// `UnifiedSourceList`, so the other page picks it up on `didChange`.
    func setDisabled(_ url: URL, _ disabled: Bool) {
        UnifiedSourceList.setDisabled(url, disabled: disabled)
        self.disabled = UnifiedSourceList.disabledURLs()
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
    /// The built-in source can't be removed: its offsets are skipped, so a
    /// swipe on its row does nothing (the row is also delete-disabled).
    func removeSource(at offsets: IndexSet) {
        // N3(A)：删源时顺带清掉它的磁盘缓存条目，不然删掉的源还占着缓存。
        let kept = offsets.filter { sources[$0].url != UnifiedSourceList.builtInURL }
        guard !kept.isEmpty else { return }
        let removed = kept.map { sources[$0].url.absoluteString }
        sources.remove(atOffsets: IndexSet(kept))
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
    /// F1 (0.9.152): disabled sources are never fetched.
    func fetchAll(force: Bool = false) async {
        await withTaskGroup(of: Void.self) { group in
            for source in sources where !isDisabled(source.url) {
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
        let (data, response) = try await Self.fetchSession.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "SourceStore", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        // C-6 / A-2（SIDE-32）：声明超限直接抛；实收超限也抛，不解码。
        // data(for:) 一次取体再判长——两道上限只决定收不收进解码，
        // 不再边读边停（10MB 内进内存可接受，解码本来也要全量 Data）。
        if response.expectedContentLength > Int64(Self.sourceBodyCap) {
            throw NSError(domain: "SourceStore", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: L("Source is too large")])
        }
        if data.count > Self.sourceBodyCap {
            throw NSError(domain: "SourceStore", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: L("Source is too large")])
        }
        // C-4：解码失败不再透传 DecodingError 的技术原串——行上只说
        // 读不出这个源；网络错（URLError）与 HTTP 状态码走原路，不动。
        do {
            return try JSONDecoder().decode(AltSource.self, from: data)
        } catch is DecodingError {
            throw NSError(domain: "SourceStore", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: L("Couldn't read this source")])
        }
    }

    /// Fetch (or refetch) one source document. Within 15 minutes of the last
    /// successful fetch, a cached document (memory, then disk) is used
    /// instead of the network, mirroring `loadReleaseCatalog`'s TTL; `force`
    /// skips the cache. Decoding is tolerant: a body that isn't a source
    /// document is reported as the row's error.
    func fetch(_ url: URL, force: Bool = false) async {
        // F1 (0.9.152): a disabled source is never fetched, even directly.
        guard !isDisabled(url) else { return }
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
        // 在途去重：同一源已有 fetch 在跑时直接返回，等那次的结果；
        // 两路缓存命中已在上面返回，不受守卫影响。
        guard sources[index].isLoading == false else { return }
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
        UnifiedSourceList.save(sources.map(\.url))
    }
}

/// A-1（SIDE-32）：源安装下载的进度节流器，与 SideStoreDownloader 的
/// `ProgressThrottler` 同逻辑（变化 ≥0.5% 或距上次发布 ≥100ms 才放行，
/// 最后一块强制发布）——那只是本文件的 `private` 类型，此处照抄一份，
/// 改名避免同模块同名 `private` 类型混淆。IPADownloader 实例是
/// @StateObject、跨多次下载复用，`reset()` 在每次下载起跑时清掉上次
/// 的发布记录；一个下载一个实例的状态，两个下载并行不互相压。
private final class IPADownloadProgressThrottler: @unchecked Sendable {
    private let lock = NSLock()
    private var lastPublished: Double?
    private var lastPublishedAt: Date?

    /// Gates `fraction` through `send`; the last chunk always goes through.
    func publish(_ fraction: Double, send: (Double) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        if fraction < 1,
           let last = lastPublished, let at = lastPublishedAt,
           abs(fraction - last) < 0.005, now.timeIntervalSince(at) < 0.1 { return }
        lastPublished = fraction
        lastPublishedAt = now
        send(fraction)
    }

    /// Forget the previous download's last publish, for the next download.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastPublished = nil
        lastPublishedAt = nil
    }
}

// MARK: - IPA download with progress

/// Downloads one IPA from a source into a private staging folder in the
/// temporary directory, reporting progress. The file keeps the name
/// `Engine.importFileName(for:)` gives its URL, so the custom-import slot it
/// is handed to next names it the same way a pasted link would.
@MainActor
final class IPADownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {

    /// F2 (0.9.153): the one downloader for the whole app. SourceAppsView
    /// used to own a private one and cancelled it in `.onDisappear`, so
    /// leaving the source page killed the download with no trace. The
    /// shared instance keeps running when the page goes away; only an
    /// explicit Cancel (the row's button, or starting another download)
    /// stops it. One download at a time: `download` cancels any in-flight
    /// one first, as before.
    static let shared = IPADownloader()

    @Published private(set) var progress: Double = 0

    /// B1 (0.9.155): bytes arrived so far, and the total the server
    /// promised — -1 while it has promised none (a chunked transfer, where
    /// `totalBytesExpectedToWrite` is -1 and no fraction exists). The row
    /// shows a byte count instead of a stuck 0% then.
    @Published private(set) var bytesWritten: Int64 = 0
    @Published private(set) var totalBytesExpected: Int64 = -1

    /// F-B (0.9.155): true while the in-flight download is suspended by
    /// the row's Pause button (`downloadTask.suspend()`).
    @Published private(set) var isPaused = false

    /// C-6：源下载的 IPA 上限 8GB——与解压总量上限（enterprise.rs）同数。
    /// 不要与源 JSON 的 10MB 共用一个常量：IPA 常规就是几十 MB 到 1GB+，
    /// 10MB 会断掉几乎全部源安装。
    private static let ipaDownloadCap: Int64 = 8 * 1024 * 1024 * 1024

    private var session: URLSession?
    /// B2 (0.9.155): the task the current continuation belongs to —
    /// `finish` only settles for this task, so a stale session's late
    /// callback can't kill the download that replaced it. Its
    /// `ObjectIdentifier` is the Sendable copy the delegate callbacks
    /// carry into their `Task { @MainActor }` hops (the task itself must
    /// not be captured there).
    private var currentTask: URLSessionDownloadTask?
    private var currentTaskID: ObjectIdentifier?
    /// F-B: the URL the current task is fetching, for resume-data matching.
    private var currentURL: URL?
    private var continuation: CheckedContinuation<URL, Error>?
    /// F-B: resume data + its URL, kept when a download is cancelled so a
    /// re-tap of the same link resumes instead of restarting.
    private var resumeData: Data?
    private var resumeURL: URL?
    /// B1: last byte count reported while the total was unknown, so the
    /// unknown-total reports stay throttled to 256KB steps.
    private var lastReportedBytes: Int64 = 0

    /// A-1（SIDE-32）：本下载的进度节流器（delegate 队列是串行的，锁只是兜底）。
    private let progressThrottler = IPADownloadProgressThrottler()

    /// Download `url` and return the staged file. Throws on a non-2xx answer
    /// or a transport error.
    func download(from url: URL) async throws -> URL {
        // A new download drops the previous run without keeping its resume
        // data: the slot holds one URL, and this URL is about to replace it.
        cancel(keepingResumeData: false)
        progress = 0
        bytesWritten = 0
        totalBytesExpected = -1
        isPaused = false
        lastReportedBytes = 0
        progressThrottler.reset()
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        var request = URLRequest(url: url)
        request.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        // F-B: resume where a cancelled run of the same URL stopped, when
        // the server left resume data behind; any other URL (or none)
        // starts clean and drops the stale data.
        let task: URLSessionDownloadTask
        if resumeURL == url, let data = resumeData {
            task = session.downloadTask(withResumeData: data)
        } else {
            task = session.downloadTask(with: request)
        }
        resumeData = nil
        resumeURL = nil
        currentTask = task
        currentTaskID = ObjectIdentifier(task)
        currentURL = url
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            task.resume()
        }
    }

    /// F-B (0.9.155): suspend the in-flight download; the row's Resume
    /// button picks it back up on the same task. A no-op with nothing
    /// running, or while already paused.
    func pause() {
        guard let task = currentTask, !isPaused else { return }
        task.suspend()
        isPaused = true
    }

    /// F-B (0.9.155): resume a download `pause()` suspended. A no-op
    /// with nothing running, or while not paused.
    func resume() {
        guard let task = currentTask, isPaused else { return }
        task.resume()
        isPaused = false
    }

    /// Stop an in-flight download, if any.
    /// - Parameter keepingResumeData: true for an explicit user cancel
    ///   (the row's Cancel button), so a re-tap of the same link resumes;
    ///   false when a new download is about to replace this one.
    func cancel(keepingResumeData: Bool = true) {
        // F-B: keep resume data for the URL being stopped, so tapping the
        // same app again resumes instead of restarting. The callback lands
        // asynchronously, so it only stores when no newer download has
        // started since — a stale capture must not overwrite the live run.
        if keepingResumeData, let task = currentTask, let url = currentURL {
            task.cancel(byProducingResumeData: { [weak self] data in
                guard let data else { return }
                Task { @MainActor in
                    guard let self, self.currentTask == nil else { return }
                    self.resumeData = data
                    self.resumeURL = url
                }
            })
        }
        session?.invalidateAndCancel()
        session = nil
        currentTask = nil
        currentTaskID = nil
        currentURL = nil
        isPaused = false
        // C-4：当场结算旧 continuation，不等 delegate 回调——旧错随后到时
        // continuation 已是 nil，finish 的守卫让它空操作，不会二次恢复。
        // B2 (0.9.155)：C-4 的推理只在纯取消时成立——新下载立即存入新
        // continuation 时，旧会话的回调仍会送达并恢复新下载；那一半由
        // `finish(for:)` 的任务身份核对堵，见该处注释。
        finish(.failure(URLError(.cancelled)))
    }

    /// Resume the waiting download exactly once.
    /// - Parameter taskID: the delegate callback's task, as an
    ///   `ObjectIdentifier`, when this comes from one. B2 (0.9.155): a
    ///   callback from a task that is no longer the current one is stale —
    ///   `invalidateAndCancel` still delivers the old session's
    ///   `didCompleteWithError`, and its hop back to the main actor can
    ///   only run after a replacement download has stored its own
    ///   continuation, so an unguarded finish would resume the *new*
    ///   download with the *old* cancelled error. Stale callbacks drop
    ///   here; a nil id (the synchronous `cancel()` path) always applies.
    private func finish(_ result: Result<URL, Error>, for taskID: ObjectIdentifier? = nil) {
        if let taskID, taskID != currentTaskID { return }
        guard let continuation else { return }
        self.continuation = nil
        currentTask = nil
        currentTaskID = nil
        currentURL = nil
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
        // B1 (0.9.155): the byte counts are published on every path, not
        // just when a total exists — a chunked transfer reports -1 here,
        // and the old `guard total > 0 else { return }` left the row at 0%
        // until the file landed whole.
        if totalBytesExpectedToWrite > 0 {
            let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            // A-1（SIDE-32）：每 chunk 先过节流器再发布，不再每次都跳主线程写 @Published。
            progressThrottler.publish(fraction) { value in
                Task { @MainActor in
                    self.progress = value
                    self.bytesWritten = totalBytesWritten
                    self.totalBytesExpected = totalBytesExpectedToWrite
                }
            }
        } else if totalBytesWritten - lastReportedBytes >= 256 * 1024 || lastReportedBytes == 0 {
            lastReportedBytes = totalBytesWritten
            Task { @MainActor in
                self.bytesWritten = totalBytesWritten
                self.totalBytesExpected = -1
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // The downloaded file is deleted when this callback returns, so it is
        // moved into staging here, on this queue.
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            let error = NSError(domain: "IPADownloader", code: http.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            Task { @MainActor in self.finish(.failure(error), for: ObjectIdentifier(downloadTask)) }
            return
        }
        guard let source = downloadTask.originalRequest?.url else {
            Task { @MainActor in self.finish(.failure(URLError(.badURL)), for: ObjectIdentifier(downloadTask)) }
            return
        }
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("ipa-source-\(UUID().uuidString)", isDirectory: true)
        let dest = staging.appendingPathComponent(Engine.importFileName(for: source))
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: dest)
            // A-1（SIDE-32）：成功时强制发 1.0（fraction == 1 一定过节流器）。
            let received = downloadTask.countOfBytesReceived
            let expected = downloadTask.countOfBytesExpectedToReceive
            progressThrottler.publish(1.0) { value in
                Task { @MainActor in
                    self.progress = value
                    self.bytesWritten = received
                    self.totalBytesExpected = expected
                }
            }
            Task { @MainActor in self.finish(.success(dest), for: ObjectIdentifier(downloadTask)) }
        } catch {
            // N3(C)：建目录/移文件失败也会留一个空 ipa-source-* 目录，顺手删掉。
            try? FileManager.default.removeItem(at: staging)
            Task { @MainActor in self.finish(.failure(error), for: ObjectIdentifier(downloadTask)) }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        // A successful download has already finished in
        // `didFinishDownloadingTo`; this only carries failures and cancels.
        guard let error else { return }
        Task { @MainActor in self.finish(.failure(error), for: ObjectIdentifier(task)) }
    }
}
