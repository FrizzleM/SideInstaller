import CryptoKit
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
    /// F-3 (0.9.161): when this source's document was last checked
    /// (successfully fetched, network or disk cache) — persisted in
    /// UserDefaults, unlike `fetchedAt`, so the row still knows after a
    /// restart. The row shows it as "x 分钟前检查过", stale past 24 h.
    var lastCheckedAt: Date?

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

    /// B-2 (0.9.157): posted when a fetch lands a new document, so the
    /// Sources tab badge — which counts from `SourcesManager`'s states,
    /// not this store's — can adopt it (see `SourcesManager.adoptCachedSources`).
    static let contentDidChange = Notification.Name("CZFSourceStoreContentDidChange")

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
        // B-1 (0.9.158): drop stale resume points left by cancelled
        // downloads, before any new download can reuse the folder.
        // (The sweep lives on IPADownloader, which owns resumeData/.)
        IPADownloader.purgeStaleResumeData()
        sources = UnifiedSourceList.load().map { LoadedSource(url: $0) }
        disabled = UnifiedSourceList.disabledURLs()
        // F-3 (0.9.161): restore the persisted last-check times.
        let checked = Self.loadLastChecked()
        for i in sources.indices { sources[i].lastCheckedAt = checked[sources[i].url.absoluteString] }
    }

    /// F-3 (0.9.161): per-source last-check time, persisted across launches
    /// (the in-memory `fetchedAt` drives the 15-minute TTL and dies with
    /// the process). One dict, URL string → seconds since 1970.
    private static let lastCheckedKey = "CZFSourceLastChecked"

    private static func loadLastChecked() -> [String: Date] {
        guard let raw = UserDefaults.standard.dictionary(forKey: lastCheckedKey) else { return [:] }
        var out: [String: Date] = [:]
        for (key, value) in raw {
            if let seconds = value as? TimeInterval { out[key] = Date(timeIntervalSince1970: seconds) }
        }
        return out
    }

    private static func saveLastChecked(url: URL, at date: Date) {
        var stored = loadLastChecked()
        stored[url.absoluteString] = date
        UserDefaults.standard.set(stored.mapValues { $0.timeIntervalSince1970 }, forKey: lastCheckedKey)
    }

    private static func removeLastChecked(keys: [String]) {
        var stored = loadLastChecked()
        for key in keys { stored.removeValue(forKey: key) }
        UserDefaults.standard.set(stored.mapValues { $0.timeIntervalSince1970 }, forKey: lastCheckedKey)
    }

    /// Re-read the unified list (the other page saved it): keep the loaded
    /// documents of sources still listed, add new ones unloaded, drop
    /// removed ones. Called when the page appears and when the list changes.
    func syncURLs() {
        // B-1 (0.9.158): same sweep as `init` — entering the page is the
        // moment a cancelled download's point stops being reachable.
        IPADownloader.purgeStaleResumeData()
        let urls = UnifiedSourceList.load()
        disabled = UnifiedSourceList.disabledURLs()
        var kept: [URL: LoadedSource] = [:]
        for source in sources { kept[source.url] = source }
        sources = urls.map { kept[$0] ?? LoadedSource(url: $0) }
        // F-3 (0.9.161): a source added elsewhere still gets its persisted
        // last-check time; kept ones already carry it.
        let checked = Self.loadLastChecked()
        for i in sources.indices where sources[i].lastCheckedAt == nil {
            sources[i].lastCheckedAt = checked[sources[i].url.absoluteString]
        }
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
        Self.removeLastChecked(keys: removed)
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

    /// B-2 (0.9.157): the disk-cached document for `url`, while it is
    /// still within the 15-minute fetch TTL — `SourcesManager` adopts it
    /// for the badge instead of refetching what this store just fetched.
    /// Sync: the cache queue serializes it, like the async loader above.
    nonisolated static func cachedModel(for url: URL) -> AltSource? {
        cacheQueue.sync {
            guard let cached = loadSourceCacheLocked()[url.absoluteString],
                  Date().timeIntervalSince(cached.fetched) < 15 * 60
            else { return nil }
            return cached.model
        }
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
            // F-3 (0.9.161): a disk hit is still a check — its time is
            // when the document was actually fetched, not now.
            sources[index].lastCheckedAt = cached.fetched
            Self.saveLastChecked(url: url, at: cached.fetched)
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
            let now = Date()
            sources[index].fetchedAt = now
            // F-3 (0.9.161): a successful fetch is a check — record it.
            sources[index].lastCheckedAt = now
            Self.saveLastChecked(url: url, at: now)
            sources[index].isLoading = false
            await Self.saveSourceCache(url: url, model: model)
            // B-2 (0.9.157): a new document landed — the badge counts from
            // the other store's states, so tell it to adopt this one.
            NotificationCenter.default.post(name: Self.contentDidChange, object: nil)
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
    /// B1 (0.9.155): last byte count let through by `publishBytes`, so
    /// unknown-total reports stay throttled to 256KB steps. Lives here,
    /// not on the @MainActor downloader, because the delegate callback
    /// that reports bytes is nonisolated and may not touch MainActor state.
    private var lastBytes: Int64?

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

    /// Gates a byte count through `send` for a transfer with no total:
    /// the first report and then every 256KB step go through.
    func publishBytes(_ bytes: Int64, send: (Int64) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard bytes > 0 else { return }
        if let last = lastBytes, bytes - last < 256 * 1024 { return }
        lastBytes = bytes
        send(bytes)
    }

    /// Forget the previous download's last publish, for the next download.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastPublished = nil
        lastPublishedAt = nil
        lastBytes = nil
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
    /// stops it.
    /// F-1 (0.9.163): one download runs at a time, but the rest no longer
    /// cancel it — `download(from:)` queues behind the running one and
    /// starts when its turn comes (see `pending` / `pumpIfIdle`).
    static let shared = IPADownloader()

    @Published private(set) var progress: Double = 0

    /// B1 (0.9.155): bytes arrived so far, and the total the server
    /// promised — -1 while it has promised none (a chunked transfer, where
    /// `totalBytesExpectedToWrite` is -1 and no fraction exists). The row
    /// shows a byte count instead of a stuck 0% then.
    @Published private(set) var bytesWritten: Int64 = 0
    @Published private(set) var totalBytesExpected: Int64 = -1

    /// F-C (0.9.156): the download's speed in bytes per second, and the
    /// estimated seconds left. Speed is 0 until two samples arrive; the
    /// estimate is nil while the total is unknown or no speed is known yet.
    @Published private(set) var downloadSpeed: Double = 0
    @Published private(set) var estimatedTimeRemaining: TimeInterval?

    /// The last sample `noteProgress` measured speed from.
    private var lastSpeedBytes: Int64 = 0
    private var lastSpeedAt: Date?

    /// F-B (0.9.155): true while the in-flight download is suspended by
    /// the row's Pause button (`downloadTask.suspend()`).
    @Published private(set) var isPaused = false

    /// F-2 (0.9.162): true while a download is in flight, and the name
    /// the Downloads page shows for it — the staged filename, so the row
    /// reads the same as the file that lands in Downloads. The source
    /// page's row state is local to that page; this shared state is what
    /// the Downloads page's "Downloading" section observes. Both fall
    /// together in `finish()`, so the row vanishes when the file lands.
    @Published private(set) var isDownloading = false
    @Published private(set) var currentName: String?

    /// F-1 (0.9.163): one queued download, as the source rows and the
    /// Downloads page show it — the URL it fetches and the staged
    /// filename it lands as.
    struct QueuedDownload: Identifiable, Equatable {
        let id: UUID
        let url: URL
        let name: String
    }

    /// F-1 (0.9.163): the downloads still waiting, in tap order — the
    /// running one is `currentURL`, not here. The source rows read this
    /// for "排队中", the Downloads page lists it under the running row.
    @Published private(set) var queue: [QueuedDownload] = []

    /// F-1 (0.9.173): the source downloads that failed, one entry per
    /// URL — so the Downloads page can show each with its own retry
    /// after the source page is gone. F-3 (0.9.171) kept one entry only
    /// ("a newer failure replaces it"); two failures in a row silently
    /// dropped the first one's retry, so this is now a queue: a newer
    /// failure for the same URL replaces its entry, a retry that lands
    /// clears its own URL. A cancel is never a failure (the row's
    /// Cancel is silent by design). This is the Downloads page's
    /// in-flight failure, not the history page's failure records (F-A,
    /// 0.9.164) — those live on past installs.
    struct FailedDownload: Codable, Equatable {
        let name: String
        let url: URL
        let error: String
    }

    /// F-1 (0.9.173): the failed downloads, in failure order.
    /// B-2 (0.9.192): persisted in UserDefaults, so the retry survives
    /// an app restart — a failure list that only lives in memory loses
    /// its retry the moment the app is closed. Only the name, the URL
    /// and the failure text are stored; nothing sensitive.
    @Published private(set) var failedDownloads: [FailedDownload] = SourceStore.loadFailedDownloads()

    private static let failedDownloadsKey = "CZFFailedDownloads"

    private static func loadFailedDownloads() -> [FailedDownload] {
        guard let data = UserDefaults.standard.data(forKey: failedDownloadsKey) else { return [] }
        return (try? JSONDecoder().decode([FailedDownload].self, from: data)) ?? []
    }

    private func storeFailedDownloads() {
        guard let data = try? JSONEncoder().encode(failedDownloads) else { return }
        UserDefaults.standard.set(data, forKey: Self.failedDownloadsKey)
    }

    /// F-1 (0.9.173): drop one failed-download row (its Remove button).
    func removeFailedDownload(_ failed: FailedDownload) {
        failedDownloads.removeAll { $0 == failed }
        storeFailedDownloads()
    }

    /// F-3 (0.9.174): drop every failed-download row at once (the Failed
    /// section's Clear all, after its confirm box). The in-flight and
    /// queued downloads are untouched — only this list is cleared.
    func clearFailedDownloads() {
        failedDownloads.removeAll()
        storeFailedDownloads()
    }

    /// F-1 (0.9.163): one entry in the FIFO queue — the URL, the staged
    /// filename, and the continuation its waiter suspended in. A class,
    /// not a struct: the waiter stores its continuation into the same
    /// object the queue holds, and the pump drops it once it settles.
    private final class DownloadRequest {
        let id = UUID()
        let url: URL
        let name: String
        var continuation: CheckedContinuation<URL, Error>?
        init(url: URL) {
            self.url = url
            self.name = Engine.importFileName(for: url)
        }
    }

    /// F-1 (0.9.163): the requests still waiting for the slot, in tap
    /// order. The running one lives in `activeRequest`, not here.
    private var pending: [DownloadRequest] = []
    /// F-1 (0.9.163): the request the slot is running now, if any.
    private var activeRequest: DownloadRequest?

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
    /// F-1 (0.9.163): published, so a source row can tell whether *its*
    /// URL is the running one (downloading UI) or a waiting one (queued UI).
    @Published private(set) var currentURL: URL?
    /// F-B: resume data + its URL, kept when a download is cancelled so a
    /// re-tap of the same link resumes instead of restarting.
    private var resumeData: Data?
    private var resumeURL: URL?

    /// F-1 (0.9.157): a resume point survives a kill or a system reclaim
    /// only on disk — memory alone loses it, and a big IPA then restarts
    /// from zero. 7 days: a server that old has forgotten the range, so
    /// an older point would only fail at once instead of resuming.
    private static let resumeDataMaxAge: TimeInterval = 7 * 24 * 3600

    /// One resume point on disk: the URL it belongs to, when it was saved,
    /// and the resume data itself.
    private struct PersistedResumeData: Codable {
        let url: String
        let savedAt: Date
        let data: Data
    }

    /// The resume-data folder, in Application Support next to the source
    /// documents cache. nonisolated: only file I/O, no actor state.
    nonisolated private static var resumeDataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("resumeData", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// The file for one URL's resume point: the URL's SHA256 hex, so the
    /// name is unique per URL, short, and needs no escaping (a base64'd
    /// URL can pass the 255-character filename limit on a long link).
    nonisolated private static func resumeDataFileURL(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return resumeDataDirectory.appendingPathComponent(hash + ".resume")
    }

    nonisolated private static func saveResumeDataToDisk(url: URL, data: Data) {
        let record = PersistedResumeData(url: url.absoluteString, savedAt: Date(), data: data)
        guard let encoded = try? JSONEncoder().encode(record) else { return }
        try? encoded.write(to: resumeDataFileURL(for: url), options: .atomic)
    }

    /// The disk point for `url`, or nil when there is none, it belongs to
    /// another URL, or it is older than `resumeDataMaxAge` — an expired or
    /// unreadable file is deleted on the spot, not left to be retried.
    nonisolated private static func loadResumeDataFromDisk(url: URL) -> Data? {
        let file = resumeDataFileURL(for: url)
        guard let encoded = try? Data(contentsOf: file),
              let record = try? JSONDecoder().decode(PersistedResumeData.self, from: encoded),
              record.url == url.absoluteString,
              Date().timeIntervalSince(record.savedAt) < Self.resumeDataMaxAge
        else {
            try? FileManager.default.removeItem(at: file)
            return nil
        }
        return record.data
    }

    nonisolated private static func deleteResumeDataFromDisk(url: URL) {
        try? FileManager.default.removeItem(at: resumeDataFileURL(for: url))
    }

    /// B-1 (0.9.158): sweep `resumeData/` for points no download will ever
    /// claim again — expired (older than `resumeDataMaxAge`) or unreadable,
    /// so cancelling several sources and never reopening them doesn't leave
    /// one `.resume` file per URL behind forever. A live run's point is
    /// fresh by construction, so the sweep never touches it; callers run
    /// this on entry (`SourceStore.init` + `syncURLs`), never mid-download.
    /// Internal (not private): the callers live on `SourceStore`.
    nonisolated static func purgeStaleResumeData() {
        let dir = resumeDataDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "resume" {
            guard let encoded = try? Data(contentsOf: file),
                  let record = try? JSONDecoder().decode(PersistedResumeData.self, from: encoded),
                  Date().timeIntervalSince(record.savedAt) < Self.resumeDataMaxAge else {
                try? FileManager.default.removeItem(at: file)
                continue
            }
        }
    }

    /// A-1（SIDE-32）：本下载的进度节流器（delegate 队列是串行的，锁只是兜底）。
    private let progressThrottler = IPADownloadProgressThrottler()

    /// Download `url` and return the staged file. Throws on a non-2xx answer
    /// or a transport error.
    /// F-1 (0.9.163): a tap no longer cancels the running download — this
    /// call joins the FIFO queue and awaits its own turn. The waiter
    /// suspends in its request's continuation; `pumpIfIdle` starts the
    /// head once the slot frees, and `finish` pumps the next one.
    func download(from url: URL) async throws -> URL {
        if Task.isCancelled { throw CancellationError() }
        let request = DownloadRequest(url: url)
        pending.append(request)
        publishQueue()
        // S1 (0.9.159): a bare continuation never resumes when only the
        // waiting task is cancelled — the task would hang forever. The
        // handler settles it through `cancelRequest`, which drops only
        // this request: the running download and the rest of the queue
        // are untouched (pre-0.9.163 it called `cancel()` and killed
        // whatever was running). `onCancel` is a non-isolated
        // synchronous context, so it hops back to the main actor
        // through a Task first (Engine's `confirmPairingImportMismatch`
        // shape); `cancelRequest` no-ops when the request is already gone.
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // The cancel handler may already have dropped this request
                // (a Cancel tap landing before the continuation stored):
                // settle at once instead of waiting for a pump that will
                // never see it.
                guard pending.contains(where: { $0 === request }) else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                request.continuation = continuation
                pumpIfIdle()
            }
        } onCancel: {
            Task { @MainActor in self.cancelRequest(request.id) }
        }
    }

    /// F-1 (0.9.163): publish the waiting queue for the rows that show
    /// it — the running request is `currentURL`, never here.
    private func publishQueue() {
        queue = pending.map { QueuedDownload(id: $0.id, url: $0.url, name: $0.name) }
    }

    /// F-1 (0.9.163): start the head of the queue when the slot is free.
    /// Called when a waiter stores its continuation, and when the running
    /// one settles (`finish`). A request whose continuation isn't stored
    /// yet can't start — it isn't runnable until its waiter suspends, and
    /// the waiter's own `pumpIfIdle` picks it up then.
    private func pumpIfIdle() {
        guard activeRequest == nil, let next = pending.first, next.continuation != nil else { return }
        pending.removeFirst()
        publishQueue()
        startDownload(next)
    }

    /// F-1 (0.9.163): run one queued request on the slot — the old
    /// `download(from:)` body, minus the cancel-the-previous-run head
    /// (the queue replaces it) and minus the `defer` that invalidated
    /// the session when the await returned: this returns at once now,
    /// so the session is invalidated in `finish()` instead.
    private func startDownload(_ request: DownloadRequest) {
        activeRequest = request
        progress = 0
        bytesWritten = 0
        totalBytesExpected = -1
        isPaused = false
        downloadSpeed = 0
        estimatedTimeRemaining = nil
        lastSpeedBytes = 0
        lastSpeedAt = nil
        progressThrottler.reset()
        // F-2 (0.9.162): the new run's flag can't be undone by the old
        // run's teardown — `finish()` clears these before the pump, so
        // the order here is safe by construction.
        isDownloading = true
        currentName = request.name
        let url = request.url
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        var httpRequest = URLRequest(url: url)
        httpRequest.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        // F-1 (0.9.157): memory is empty after a relaunch, but the disk
        // point from the last cancel may still be there — load it, and
        // consume it at once: the data now lives in memory, a cancel
        // re-saves it, a success clears it, so the file must not outlive
        // this run and be retried stale. A point for another URL is
        // dropped with the memory one.
        if resumeURL == url, resumeData == nil {
            if let saved = Self.loadResumeDataFromDisk(url: url) {
                resumeData = saved
            } else {
                resumeURL = nil
            }
            Self.deleteResumeDataFromDisk(url: url)
        } else if let old = resumeURL, old != url {
            Self.deleteResumeDataFromDisk(url: old)
        }
        // F-B: resume where a cancelled run of the same URL stopped, when
        // the server left resume data behind; any other URL (or none)
        // starts clean and drops the stale data.
        let task: URLSessionDownloadTask
        if resumeURL == url, let data = resumeData {
            task = session.downloadTask(withResumeData: data)
        } else {
            task = session.downloadTask(with: httpRequest)
        }
        resumeData = nil
        resumeURL = nil
        currentTask = task
        currentTaskID = ObjectIdentifier(task)
        currentURL = url
        task.resume()
    }

    /// F-1 (0.9.163): drop one request by id — the running one, or a
    /// waiting one. A waiting cancel only settles its own waiter with
    /// `.cancelled` (its row clears silently, like the active one's);
    /// the running download and the rest of the queue are untouched.
    /// A no-op when the request already settled.
    private func cancelRequest(_ id: UUID) {
        if activeRequest?.id == id {
            cancel()
            return
        }
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let request = pending.remove(at: index)
        publishQueue()
        request.continuation?.resume(throwing: URLError(.cancelled))
        request.continuation = nil
    }

    /// F-1 (0.9.163): stop one download by URL — the running one, or a
    /// queued one. The rows' Cancel button calls this instead of
    /// `cancel()`, so cancelling a queued row can't kill the download
    /// in front of it.
    func cancelDownload(url: URL) {
        if activeRequest?.url == url {
            cancel()
            return
        }
        guard let index = pending.firstIndex(where: { $0.url == url }) else { return }
        let request = pending.remove(at: index)
        publishQueue()
        request.continuation?.resume(throwing: URLError(.cancelled))
        request.continuation = nil
    }

    /// F-B (0.9.155): suspend the in-flight download; the row's Resume
    /// button picks it back up on the same task. A no-op with nothing
    /// running, or while already paused.
    /// B-2 (0.9.165): a bare suspend() leaves no resume point — kill the
    /// app and the suspended task dies with it, so the next tap restarts
    /// from zero. Pause now cancels by producing resume data instead:
    /// the point is saved to disk (+ memory while still paused) at once,
    /// and resume() restarts the same request from it. Pause is not
    /// cancel: activeRequest and its continuation stay pending, the slot
    /// stays held (pumpIfIdle only starts when activeRequest is nil), and
    /// no queued download is pumped.
    func pause() {
        guard let task = currentTask, !isPaused else { return }
        isPaused = true
        guard let url = currentURL else {
            task.suspend()
            return
        }
        // The session stays alive until the callback lands — invalidating
        // it now would drop the callback. The callback invalidates the
        // captured session itself once the point is safe on disk.
        let session = self.session
        task.cancel(byProducingResumeData: { [weak self] data in
            if let data {
                // B-1 (0.9.165) 同款：落盘不经守卫，回调在 delegate 队列
                // 上同步落盘，杀进程也丢不了；内存那一份才在跳回主线程
                // 后守卫（仍暂停、且没新跑占位才留）。
                Self.saveResumeDataToDisk(url: url, data: data)
            }
            Task { @MainActor in
                session?.finishTasksAndInvalidate()
                guard let self, self.isPaused, self.currentTask == nil else { return }
                if let data {
                    self.resumeData = data
                    self.resumeURL = url
                }
            }
        })
        currentTask = nil
        currentTaskID = nil
    }

    /// F-B (0.9.155): resume a download `pause()` suspended. A no-op
    /// with nothing running, or while not paused.
    /// B-2 (0.9.165): pause() now cancels by producing resume data, so
    /// there is no suspended task to wake — restart the same request
    /// from the saved point instead. startDownload picks the memory or
    /// disk point up for the same URL, so this resumes, never restarts.
    /// A still-suspended task (pause's no-URL fallback) resumes in place.
    func resume() {
        guard isPaused else { return }
        if let task = currentTask {
            task.resume()
            isPaused = false
            return
        }
        guard let request = activeRequest else {
            isPaused = false
            return
        }
        isPaused = false
        startDownload(request)
    }

    /// Stop the in-flight download, if any — and start the next queued
    /// one, if one is waiting (`finish` pumps it). The queue itself is
    /// untouched: use `cancelDownload(url:)` to stop one waiting entry.
    /// - Parameter keepingResumeData: true for an explicit user cancel
    ///   (the row's Cancel button), so a re-tap of the same link resumes.
    func cancel(keepingResumeData: Bool = true) {
        // F-B: keep resume data for the URL being stopped, so tapping the
        // same app again resumes instead of restarting. The callback lands
        // asynchronously, so it only stores when no newer download has
        // started since — a stale capture must not overwrite the live run.
        if keepingResumeData, let task = currentTask, let url = currentURL {
            task.cancel(byProducingResumeData: { [weak self] data in
                guard let data else { return }
                // B-1 (0.9.165)：落盘不经 `currentTask == nil` 守卫——
                // 回调是异步的（delegate 队列 + 跳回 MainActor 两跳），
                // 而 cancel() 同步尾行 finish() → pumpIfIdle() 已把
                // currentTask 置为下一个排队下载，守卫到时必失败，内存
                // 与磁盘两份断点全丢。落盘文件按 URL 哈希分文件，与
                // 新跑的断点不冲突；只守卫内存那一份。
                Self.saveResumeDataToDisk(url: url, data: data)
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
    /// F-1 (0.9.163): the continuation lives on the running request now,
    /// and settling it pumps the next queued download. The session is
    /// invalidated here, before the pump — `startDownload` returns at
    /// once now, so the old `download(from:)` `defer` that did this when
    /// the await returned has nowhere else to live.
    private func finish(_ result: Result<URL, Error>, for taskID: ObjectIdentifier? = nil) {
        if let taskID, taskID != currentTaskID { return }
        guard let request = activeRequest, let continuation = request.continuation else { return }
        // F-1 (0.9.173): keep the failures for the Downloads page —
        // a cancel is not a failure, and a success clears the record
        // for its own URL (a retry that lands).
        switch result {
        case .success:
            failedDownloads.removeAll { $0.url == request.url }
            storeFailedDownloads()
        case .failure(let error):
            if (error as? URLError)?.code != .cancelled, !(error is CancellationError) {
                // F-1 (0.9.173): one entry per URL — a re-failure of
                // the same URL replaces its entry, other URLs keep
                // theirs.
                failedDownloads.removeAll { $0.url == request.url }
                failedDownloads.append(FailedDownload(name: request.name, url: request.url,
                                                      error: error.localizedDescription))
                // B-2 (0.9.192): persist, so the retry survives a restart.
                storeFailedDownloads()
            }
        }
        request.continuation = nil
        activeRequest = nil
        currentTask = nil
        currentTaskID = nil
        currentURL = nil
        // F-2 (0.9.162): the run is over — success, failure, or cancel —
        // so the Downloads page's row goes away with it. After the guard
        // above, so a stale callback (or a cancel with nothing running)
        // can't clear a newer run's flag.
        isDownloading = false
        currentName = nil
        // F-C (0.9.156): the row goes away with the download — don't leave
        // a stale speed and estimate for the next one to show first.
        downloadSpeed = 0
        estimatedTimeRemaining = nil
        lastSpeedBytes = 0
        lastSpeedAt = nil
        continuation.resume(with: result)
        session?.finishTasksAndInvalidate()
        session = nil
        pumpIfIdle()
    }

    /// F-C (0.9.156): folds one published sample into the speed and the
    /// time left. Called on the main actor from the publish hops below, so
    /// the sample state is never touched from the delegate queue. The speed
    /// is an exponential moving average over the throttled samples, so one
    /// fast chunk doesn't swing the estimate; the first sample only sets
    /// the baseline, it measures nothing yet.
    private func noteProgress(bytes: Int64, total: Int64) {
        let now = Date()
        if let lastAt = lastSpeedAt, now > lastAt {
            let delta = bytes - lastSpeedBytes
            if delta >= 0 {
                let instant = Double(delta) / now.timeIntervalSince(lastAt)
                downloadSpeed = downloadSpeed > 0 ? 0.7 * downloadSpeed + 0.3 * instant : instant
            }
        }
        lastSpeedBytes = bytes
        lastSpeedAt = now
        estimatedTimeRemaining = total > 0 && downloadSpeed > 0
            ? TimeInterval(max(total - bytes, 0)) / downloadSpeed : nil
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
                    self.noteProgress(bytes: totalBytesWritten, total: totalBytesExpectedToWrite)
                }
            }
        } else {
            // Unknown total: no fraction to publish — report the bytes
            // through the throttler (which owns the 256KB gate on its own
            // locked state, as the nonisolated callback may not touch the
            // downloader's MainActor properties directly).
            progressThrottler.publishBytes(totalBytesWritten) { bytes in
                Task { @MainActor in
                    self.bytesWritten = bytes
                    self.totalBytesExpected = -1
                    self.noteProgress(bytes: bytes, total: -1)
                }
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
            // F-1 (0.9.157): the file landed whole — its resume point is
            // done, on disk as in memory.
            Self.deleteResumeDataFromDisk(url: source)
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
        // F-1 (0.9.157): a transfer that died mid-way can still carry
        // resume data in the error — keep it (memory + disk) when this is
        // still the live task, so the next tap resumes instead of
        // restarting. A user cancel never reaches here with a live task:
        // cancel() already settled the continuation, and its
        // byProducingResumeData callback owns that path — the identity
        // check below keeps this one from overwriting it.
        if let data = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data,
           let url = task.originalRequest?.url {
            Task { @MainActor in
                guard self.currentTaskID == ObjectIdentifier(task) else { return }
                self.resumeData = data
                self.resumeURL = url
                Self.saveResumeDataToDisk(url: url, data: data)
            }
        }
        Task { @MainActor in self.finish(.failure(error), for: ObjectIdentifier(task)) }
    }
}
