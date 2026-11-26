import Foundation
import SwiftUI

/// One IPA in Documents, as the download manager in Settings lists it.
struct DownloadedIPA: Identifiable, Equatable {
    let source: InstallSource
    let channel: ReleaseChannel
    let url: URL
    let size: Int
    let modified: Date?
    /// True when this file arrived from the Files app rather than a download.
    let isImported: Bool
    /// The release picked under Advanced that this was downloaded as.
    let version: String?

    /// Stable identity: the path is unique per source and channel.
    var id: String { url.path }

    /// Channel-qualified name, e.g. "LiveContainer + SideStore (Nightly)" or
    /// "SideStore 0.6.3", or the filename for a custom IPA, which the row
    /// already names.
    var displayName: String {
        guard source != .custom else { return fileName }
        var name = source.displayName
        if let version { name += " \(version)" }
        if channel == .nightly { name += " (\(channel.displayName))" }
        if isImported { name += " — \(L("imported"))" }
        return name
    }

    /// The on-disk filename, e.g. "SideStore.ipa".
    var fileName: String { url.lastPathComponent }

    /// Human-readable size, e.g. "42.3 MB".
    var sizeText: String {
        CZFFormattedSize.size(size)
    }
}

/// Lists and deletes the IPAs in Documents. Pure file-system work, so it runs
/// inline on the main thread.
final class DownloadsManager: ObservableObject {

    @Published private(set) var downloads: [DownloadedIPA] = []
    /// `id` of the IPA currently being deleted, if any.
    @Published private(set) var deletingID: String?
    @Published var lastError: String?
    /// True once `refresh()` has run (tells "not loaded" apart from "empty").
    @Published private(set) var hasLoaded = false

    private var engine: Engine { Engine.shared }

    /// Total bytes across every IPA, for the header summary.
    var totalSize: Int { downloads.reduce(0) { $0 + $1.size } }

    var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    // MARK: - Actions

    /// 下载列表重扫代际号（FilesTabView.refreshFiles 同模式）：每次
    /// refresh() 调用 +1 并捕获，写回前核对，旧扫描直接丢弃；delete
    /// 成功路也 +1，使在途的旧扫描失效，已删文件不再被它的写回带回列表。
    private var refreshGeneration = 0

    /// Rebuild the list from disk, scanning the directory so hand-copied files
    /// appear too. Safe to call repeatedly. The scan runs off the main thread
    /// (FilesTabView.refreshFiles 同款）：进页先显示旧列表，扫完再换新。
    @MainActor
    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        Task.detached { [weak self] in
            let entries = IPALibrary.scan()
            await MainActor.run {
                guard let self, generation == self.refreshGeneration else { return }
                self.downloads = entries.map {
                    DownloadedIPA(source: $0.source, channel: $0.channel, url: $0.url,
                                  size: $0.size, modified: $0.modified, isImported: $0.isImported,
                                  version: $0.version)
                }
                self.hasLoaded = true
            }
        }
    }

    /// Delete one downloaded IPA, then refresh the list.
    @MainActor
    func delete(_ item: DownloadedIPA) {
        guard deletingID == nil else { return }
        // B-8：正在安装的源文件不删——删了签名步读不到文件，安装死在签名失败。
        if engine.isInstallingSource(path: item.url.path) {
            lastError = L("This file is being installed. Wait until it finishes.")
            return
        }
        // B1+B5：正在签名/续签的源文件不删——签名步/续签步正读它。
        if engine.isSigningSource(path: item.url.path) {
            lastError = L("This file is being signed. Wait until it finishes.")
            return
        }
        if engine.isRenewingSource(path: item.url.path) {
            lastError = L("This file is being renewed. Wait until it finishes.")
            return
        }
        deletingID = item.id
        lastError = nil
        do {
            try FileManager.default.removeItem(at: item.url)
            DownloadLedger.forget(item.url)
            // Drop the pipeline's cached path so it re-fetches this file.
            if engine.downloadedIPAPath == item.url.path {
                engine.downloadedIPAPath = nil
            }
            // Update the Install tab's custom IPA button.
            if item.source == .custom { engine.refreshCustomIPA() }
            engine.log("Downloads: deleted \(item.fileName) (\(item.sizeText)).")
            // C8：删掉的 IPA 可能是某 App 的续签源——应用页的“可续签”
            // 数字只在 load/续签时重算，不联动这里就会一直显示旧数。
            // 只重算配对，不重读设备。
            SideloadedAppsManager.shared.refreshRefreshableOnly()
            // A-6：本地先去掉已删行，列表立即正确；末尾 refresh() 的
            // 后台重扫随后确认真相（FilesTabView.delete 同款）。
            downloads.removeAll { $0.id == item.id }
        } catch {
            lastError = L("Couldn't delete %@: %@", item.fileName, error.localizedDescription)
            engine.log("⛔️ Downloads: \(lastError ?? "delete failed")")
        }
        deletingID = nil
        refresh()
    }

    /// Rename one downloaded IPA (F3, 0.9.152): the Files page's rename
    /// rules via `FilesTabView.validatedRenameName` — same refusal, same
    /// `.ipa` suffix. The guards mirror delete(_:): a file an install /
    /// signing / renewal run is reading can't move under it. After the
    /// move the pairing is re-matched, so renewal follows the new name
    /// (FilesTabView.performRename 同款); the row is swapped in place
    /// and the background rescan confirms it.
    @MainActor
    func rename(_ item: DownloadedIPA, to rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != item.fileName else { return }
        guard let newName = FilesTabView.validatedRenameName(rawName, isDirectory: false, isIPA: true) else {
            lastError = L("Names can't be empty, contain /, or start with .")
            return
        }
        guard newName != item.fileName else { return }
        if engine.isInstallingSource(path: item.url.path) {
            lastError = L("This file is being installed. Wait until it finishes.")
            return
        }
        if engine.isSigningSource(path: item.url.path) {
            lastError = L("This file is being signed. Wait until it finishes.")
            return
        }
        if engine.isRenewingSource(path: item.url.path) {
            lastError = L("This file is being renewed. Wait until it finishes.")
            return
        }
        let dest = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: dest.path) else {
            lastError = L("已有同名文件")
            return
        }
        do {
            try FileManager.default.moveItem(at: item.url, to: dest)
            DownloadLedger.forget(item.url)
            if engine.downloadedIPAPath == item.url.path {
                engine.downloadedIPAPath = dest.path
            }
            if item.source == .custom { engine.refreshCustomIPA() }
            SideloadedAppsManager.shared.refreshRefreshableOnly()
            engine.log("Downloads: renamed \(item.fileName) → \(newName).")
            if let idx = downloads.firstIndex(where: { $0.id == item.id }) {
                downloads[idx] = DownloadedIPA(source: item.source, channel: item.channel, url: dest,
                                               size: item.size, modified: item.modified,
                                               isImported: item.isImported, version: item.version)
            }
        } catch {
            lastError = error.localizedDescription
            engine.log("⛔️ Downloads: \(lastError ?? "rename failed")")
        }
        refresh()
    }

    /// Delete every downloaded IPA, skipping ones an install, signing or
    /// renewal run is reading (FilesTabView.deleteSelection 同款：同三道
    /// 拦、同跳过计数、同失败口径）；续签源提示在清空确认框里，不在这
    /// 里——确认框弹起时读 RenewalSourceStore，见 DownloadsListView。
    @MainActor
    func deleteAll() {
        guard deletingID == nil else { return }
        // B-cand-1 (0.9.154): the old code never set `deletingID`, so this
        // guard and the Clear button's `.disabled(deletingID != nil)`
        // could never fire mid-clear — a second tap re-ran the loop and
        // counted just-deleted files as failures. A file id would lie
        // (no such row is being deleted), so the clear uses its own
        // sentinel, cleared on every exit via defer.
        deletingID = "__clearAll__"
        defer { deletingID = nil }
        lastError = nil
        var deletedIDs: [String] = []
        var failed = 0
        /// U3 (0.9.151): the names that failed to delete — the old code
        /// overwrote `lastError` per failure, then the count line at the
        /// end wiped even that, so no single filename survived.
        var failedNames: [String] = []
        var skippedInstalling = 0
        var skippedSigning = 0
        var skippedRenewing = 0
        var hadIPA = false
        for item in downloads {
            // B-8 / B1+B5：与 delete(_:) 同拦——在用的文件跳过不删，
            // 记数后统一报，不在管线读文件的途中删它。
            if engine.isInstallingSource(path: item.url.path) { skippedInstalling += 1; continue }
            if engine.isSigningSource(path: item.url.path) { skippedSigning += 1; continue }
            if engine.isRenewingSource(path: item.url.path) { skippedRenewing += 1; continue }
            hadIPA = true
            do {
                try FileManager.default.removeItem(at: item.url)
                DownloadLedger.forget(item.url)
                if engine.downloadedIPAPath == item.url.path {
                    engine.downloadedIPAPath = nil
                }
                if item.source == .custom { engine.refreshCustomIPA() }
                engine.log("Downloads: deleted \(item.fileName) (\(item.sizeText)).")
                deletedIDs.append(item.id)
            } catch {
                failed += 1
                failedNames.append(item.fileName)
                lastError = L("Couldn't delete %@: %@", item.fileName, error.localizedDescription)
                engine.log("⛔️ Downloads: \(lastError ?? "delete failed")")
            }
        }
        // A-6：本地先去掉已删行，列表立即正确；末尾 refresh() 的
        // 后台重扫随后确认真相（delete(_:) 同款）。
        downloads.removeAll { deletedIDs.contains($0.id) }
        // C8：删掉的 IPA 可能是某 App 的续签源——应用页的“可续签”
        // 数字只在 load/续签时重算，不联动这里就会一直显示旧数。
        if hadIPA {
            SideloadedAppsManager.shared.refreshRefreshableOnly()
        }
        if failed > 0 {
            // U3：末尾报失败文件名，不只报个数；超过 5 个只列前 5 个，
            // 余下的计总数（行太长也看不清，全列反而把原因淹没）。
            var list = failedNames.prefix(5).joined(separator: "、")
            if failedNames.count > 5 {
                list += "、" + L("等 %d 个", failedNames.count - 5)
            }
            lastError = L("以下 %d 个删除失败：%@", failed, list)
        } else if skippedInstalling > 0 {
            lastError = L("This file is being installed. Wait until it finishes.")
        } else if skippedSigning > 0 {
            lastError = L("This file is being signed. Wait until it finishes.")
        } else if skippedRenewing > 0 {
            lastError = L("This file is being renewed. Wait until it finishes.")
        }
        refresh()
    }

    /// F-2 (0.9.161): what "clean up old versions" would delete, before
    /// anything is deleted — per bundle ID, only the newest IPA stays
    /// (newest version, then newest file); files in use or serving as a
    /// renewal source are never candidates, they're counted as skipped.
    /// A file no IPA on disk can be identified by (no readable bundle ID
    /// or version) is left alone: without a version it can't be proven
    /// older than the one kept.
    @MainActor
    func cleanupPreview() -> (deletable: [DownloadedIPA], skipped: Int) {
        var byBundleID: [String: [(item: DownloadedIPA, version: String)]] = [:]
        for item in downloads {
            guard let info = IPALibrary.appInfo(at: item.url),
                  let version = info.version ?? item.version, !version.isEmpty
            else { continue }
            byBundleID[info.bundleID, default: []].append((item, version))
        }
        var deletable: [DownloadedIPA] = []
        var skipped = 0
        for (_, group) in byBundleID {
            guard group.count > 1 else { continue }
            // Newest first: higher version, then later modification.
            let ranked = group.sorted { a, b in
                if a.version != b.version { return UpdateChecker.isNewer(a.version, than: b.version) }
                return (a.item.modified ?? .distantPast) > (b.item.modified ?? .distantPast)
            }
            for old in ranked.dropFirst() {
                let path = old.item.url.path
                // deleteAll 同款三道拦 + 续签源（Engine.finishSuccess 同款判据）。
                if engine.isInstallingSource(path: path)
                    || engine.isSigningSource(path: path)
                    || engine.isRenewingSource(path: path) {
                    skipped += 1
                    continue
                }
                if RenewalSourceStore.source(forFileURL: old.item.url,
                                            bundleID: IPALibrary.appInfo(at: old.item.url)?.bundleID) != nil {
                    skipped += 1
                    continue
                }
                deletable.append(old.item)
            }
        }
        return (deletable, skipped)
    }

    /// F-2 (0.9.161): delete the preview's candidates, with `delete(_:)`
    /// 同款 bookkeeping per file (ledger, custom slot, renewal pairing),
    /// and report what happened — deleted, skipped, failed — as one
    /// summary the view shows, instead of leaving the list to speak
    /// for itself.
    @MainActor
    func cleanupOldVersions() -> String {
        let preview = cleanupPreview()
        var deleted = 0
        var failed = 0
        var failedNames: [String] = []
        var deletedItems: [DownloadedIPA] = []
        for item in preview.deletable {
            do {
                try FileManager.default.removeItem(at: item.url)
                DownloadLedger.forget(item.url)
                if engine.downloadedIPAPath == item.url.path {
                    engine.downloadedIPAPath = nil
                }
                if item.source == .custom { engine.refreshCustomIPA() }
                engine.log("Downloads: cleaned up old version \(item.fileName).")
                deleted += 1
                deletedItems.append(item)
            } catch {
                failed += 1
                failedNames.append(item.fileName)
                engine.log("⛔️ Downloads: couldn't delete \(item.fileName) (\(error.localizedDescription))")
            }
        }
        if deleted > 0 {
            SideloadedAppsManager.shared.refreshRefreshableOnly()
        }
        // Only the files actually deleted leave the list locally — a
        // failed delete stays until the background rescan confirms it.
        downloads.removeAll { deletedItems.contains($0) }
        refresh()
        var summary = deleted > 0
            ? L("Cleaned up %d old versions.", deleted)
            : L("No old versions to clean up.")
        if preview.skipped > 0 {
            summary += " " + L("%d files skipped (in use or needed for renewal).", preview.skipped)
        }
        if failed > 0 {
            var list = failedNames.prefix(5).joined(separator: "、")
            if failedNames.count > 5 {
                list += "、" + L("等 %d 个", failedNames.count - 5)
            }
            summary += " " + L("%d files couldn't be deleted: %@", failed, list)
        }
        return summary
    }
}

/// 下载列表独立页（工具 tab 固定入口，复用 DownloadsManager）：
/// 设置页下载区同款内容（行样式照本页的下载行），
/// 不再只藏在设置 sheet 里；删文件前先弹确认，不直接删。
struct DownloadsListView: View {
    @Environment(Engine.self) private var engine
    @StateObject private var manager = DownloadsManager()
    /// F-2 (0.9.164): the installed apps, for the row's newer/older tag —
    /// the shared instance RootView already observes, so the tag follows
    /// the device list without another load.
    @ObservedObject private var appsManager = SideloadedAppsManager.shared
    /// F-3 (0.9.164): the download a history row asked to reveal
    /// (`id` = file path), still waiting to be scrolled to.
    @State private var pendingRevealID: String?
    /// F-3 (0.9.164): the revealed download, highlighted until the user
    /// taps its row to install it.
    @State private var highlightedID: String?
    /// F-3 (0.9.164): bumps on every reveal request, so the ScrollViewReader
    /// answers even when the file is already listed (no download change
    /// to observe).
    @State private var revealNonce = 0
    /// F-2 (0.9.162): the shared source downloader — the "Downloading"
    /// section at the top observes its in-flight state, so a download
    /// started on the source page stays visible here. Same instance the
    /// source rows observe (SourcesView 同款）.
    @StateObject private var downloader = IPADownloader.shared
    @State private var pendingDelete: DownloadedIPA?
    /// B-1 (0.9.160): the renewal-source app name for `pendingDelete`,
    /// read when the Delete button is tapped (clear-all's
    /// `clearAllRenewalNames` 同款：点按钮时读，不在每次 body 求值时
    /// 读盘）— nil means this file isn't any app's renewal source.
    @State private var pendingDeleteRenewalName: String?
    /// The download being renamed (F3, 0.9.152), with its name in the field.
    @State private var renameItem: DownloadedIPA?
    @State private var renameText = ""
    /// `id` of the IPA being moved into the Install tab's custom slot, if any.
    @State private var installingID: String?
    /// F-3 (0.9.171): the failed-download retry in flight, if any.
    @State private var retryTask: Task<Void, Never>?
    /// B-1 (0.9.176): the failed row whose retry has downloaded and is
    /// waiting for the install slot (an install or a batch in its gap) —
    /// its row reads “等待中” meanwhile (single-source `.queued` 同款）.
    @State private var waitingRetryURL: URL?
    /// F-1 (0.9.174): the retry-all run in flight, if any — the header
    /// button turns into Cancel while it runs, and cancelling stops
    /// after the current item instead of starting the next one.
    @State private var retryAllTask: Task<Void, Never>?
    /// F-3 (0.9.174): the Clear-all-failed confirmation, true while its
    /// alert stands.
    @State private var confirmingClearFailed = false
    /// Clear-all confirmation: true while the alert stands, with the
    /// renewal-source app names it must warn about (read when the button
    /// is tapped, not on every body pass).
    @State private var confirmingClearAll = false
    @State private var clearAllRenewalNames: [String] = []
    /// F-2 (0.9.161): the old-version cleanup's confirm (count + skipped)
    /// and its result line — the counts are read when the button is
    /// tapped, not on every body pass.
    @State private var pendingCleanup: (count: Int, skipped: Int)?
    @State private var cleanupResult: String?
    /// U1 (0.9.148): search text + sort (FilesTabView FileSort 同款，
    /// 只改显示顺序，不动磁盘顺序）。
    @State private var searchText = ""
    @AppStorage("CZFDownloadSort") private var downloadSortRaw = DownloadSort.default.rawValue
    private var downloadSort: DownloadSort { DownloadSort(rawValue: downloadSortRaw) ?? .default }

    /// Sort order for the download list: default scan order / name /
    /// size (largest first) / newest (latest modified first).
    private enum DownloadSort: String, CaseIterable {
        case `default`, name, size, newest
        var label: String {
            switch self {
            case .default: return L("默认")
            case .name: return L("Name")
            case .size: return L("Size")
            case .newest: return L("Latest")
            }
        }
    }

    /// F-2 (0.9.164): the installed-version comparison tag for a row — the
    /// IPA's own version (the release version it was downloaded as when
    /// the IPA can't be read) against what this iPhone has installed.
    /// No readable version or no installed match means no tag, not a guess.
    private func versionTag(for item: DownloadedIPA) -> (text: String, color: Color)? {
        guard let info = IPALibrary.appInfo(at: item.url),
              let fileVersion = info.version ?? item.version, !fileVersion.isEmpty,
              !info.bundleID.isEmpty,
              let installed = appsManager.installedVersion(forBundleID: info.bundleID) else { return nil }
        return czfVersionComparisonTag(fileVersion: fileVersion, installedVersion: installed)
    }

    /// F-3 (0.9.164): scroll a revealed download into view and highlight it.
    /// Nothing to do until the file is actually in the list — a refresh
    /// still in flight just leaves the request pending, and the downloads
    /// change below retries it; a loaded list without the file drops it
    /// (the file was verified a moment ago, so this is only a race).
    private func reveal(_ proxy: ScrollViewProxy) {
        guard let id = pendingRevealID else { return }
        guard manager.downloads.contains(where: { $0.id == id }) else {
            if manager.hasLoaded { pendingRevealID = nil }
            return
        }
        pendingRevealID = nil
        highlightedID = id
        withAnimation { proxy.scrollTo(id, anchor: .center) }
    }

    /// Search + sort applied to the scanned list: search matches the shown
    /// name or the filename, case-insensitive; sorting only reorders.
    private var visibleDownloads: [DownloadedIPA] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var items = manager.downloads
        if !query.isEmpty {
            items = items.filter {
                $0.displayName.lowercased().contains(query)
                    || $0.fileName.lowercased().contains(query)
            }
        }
        switch downloadSort {
        case .default: return items
        case .name: return items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .size: return items.sorted { $0.size > $1.size }
        case .newest: return items.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
        }
    }

    /// F-2 (0.9.162): the in-flight row's speed line — SourcesView's
    /// `downloadDetailLine` 同款 minus the ETA (this row shows the
    /// percent already; the estimate lives on the source row).
    private var downloadDetailLine: String {
        let speed = L("%@/s", ByteCountFormatter.string(fromByteCount: Int64(downloader.downloadSpeed), countStyle: .file))
        if downloader.totalBytesExpected > 0 {
            return "\(speed) • \(L("%@ of %@", ByteCountFormatter.string(fromByteCount: downloader.bytesWritten, countStyle: .file), ByteCountFormatter.string(fromByteCount: downloader.totalBytesExpected, countStyle: .file)))"
        }
        return "\(speed) • \(L("%@ downloaded", ByteCountFormatter.string(fromByteCount: downloader.bytesWritten, countStyle: .file)))"
    }

    /// A-39-2：下载行日期文案静态缓存——照抄 SIDE-38 A4 的
    /// ExpiryUrgency.textCache 模式；每行每 body 求值现建
    /// Date.FormatStyle 太贵。key 带今天（值本身不依赖今天，防以后
    /// 加相对文案时跨午夜踩坑）；>512 条整表清掉。调用方全在
    /// 主线程 body 里，不另加锁。
    private static var dateTextCache: [String: String] = [:]
    private static func dateText(for modified: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let key = "\(modified.timeIntervalSince1970)#\(Localizer.locale.identifier)#\(today.timeIntervalSince1970)"
        if let cached = dateTextCache[key] { return cached }
        let text = modified.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(Localizer.locale))
        if dateTextCache.count > 512 { dateTextCache.removeAll() }
        dateTextCache[key] = text
        return text
    }

    var body: some View {
        VStack(spacing: 12) {
            // U1 (0.9.148): search + sort above the list (SourcesView 同款：
            // SearchBar 在 List 外，键盘与行重绘互不干扰）。
            SearchBar(text: $searchText, placeholder: L("搜索"))
                .padding(.horizontal, 20)
            HStack {
                Menu {
                    ForEach(DownloadSort.allCases, id: \.self) { option in
                        Button {
                            downloadSortRaw = option.rawValue
                        } label: {
                            if downloadSort == option {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    Label(L("排序：%@", downloadSort.label), systemImage: "arrow.up.arrow.down")
                        .font(.footnote.weight(.semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            // F-3 (0.9.164): the reader a history row's reveal scrolls with —
            // the reveal handlers live inside it, where the proxy is.
            ScrollViewReader { proxy in
                List {
                    // F-2 (0.9.162): the in-flight source download, at the top —
                    // the source page's row state is local to that page, so
                    // switching here used to hide the download entirely. The
                    // row reuses the shared downloader's pause/cancel and
                    // vanishes when the file lands (`isDownloading` falls in
                    // `finish()`); a cancel here settles the source row too
                    // (its catch treats `.cancelled` as silent).
                    if downloader.isDownloading, let name = downloader.currentName {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text(name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Spacer()
                                    if downloader.totalBytesExpected > 0 {
                                        Text(L("Downloading… %d%%", Int(downloader.progress * 100)))
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                            .contentTransition(.numericText())
                                    }
                                }
                                if downloader.totalBytesExpected > 0 {
                                    ProgressView(value: downloader.progress)
                                        .tint(Theme.accent)
                                } else {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                        Text(L("%@ downloaded", ByteCountFormatter.string(fromByteCount: downloader.bytesWritten, countStyle: .file)))
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                    }
                                }
                                if downloader.downloadSpeed > 0 {
                                    Text(downloadDetailLine)
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                                HStack(spacing: 12) {
                                    Button(downloader.isPaused ? L("Resume") : L("Pause")) {
                                        if downloader.isPaused {
                                            downloader.resume()
                                        } else {
                                            downloader.pause()
                                        }
                                    }
                                    .font(.caption)
                                    Button(L("Cancel")) {
                                        downloader.cancel()
                                    }
                                    .font(.caption)
                                }
                                // F-1 (0.9.163): the downloads waiting behind
                                // this one, in tap order — each with the same
                                // Cancel the running row has (a queued cancel
                                // only settles its own waiter, never the run
                                // in front of it).
                                ForEach(downloader.queue) { queued in
                                    HStack(spacing: 8) {
                                        Text(queued.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(L("Queued"))
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                        Button(L("Cancel")) {
                                            downloader.cancelDownload(url: queued.url)
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                        } header: {
                            // F-2 (0.9.170): pause / resume everything at
                            // once — the downloader runs one download at a
                            // time (0.9.163 queue), so one `pause()` /
                            // `resume()` covers the running item and the
                            // queued ones stay queued behind it. No-op when
                            // nothing is running or already paused.
                            HStack {
                                Text(L("Downloading"))
                                Spacer()
                                Button(downloader.isPaused ? L("Resume all") : L("Pause all")) {
                                    if downloader.isPaused {
                                        downloader.resume()
                                    } else {
                                        downloader.pause()
                                    }
                                }
                                .font(.caption)
                            }
                        }
                    }
                    // F-1 (0.9.173): the source downloads that failed —
                    // one row each, so a second failure no longer drops
                    // the first one's retry (the 0.9.171 single slot did).
                    // A retry that lands clears its own row (the
                    // downloader drops its record on a matching success);
                    // a retry that fails again replaces it with the new
                    // reason, and an install failure lands on this
                    // page's error line instead.
                    if !downloader.failedDownloads.isEmpty {
                        Section {
                            ForEach(downloader.failedDownloads, id: \.url) { failed in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(failed.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(failed.error)
                                        .font(.caption)
                                        .foregroundStyle(Theme.negative)
                                        .lineLimit(2)
                                    // B-1 (0.9.176): the retry has landed
                                    // and is waiting for the install slot —
                                    // say so on the row instead of leaving
                                    // the old error up while nothing
                                    // visibly happens.
                                    if waitingRetryURL == failed.url {
                                        HStack(spacing: 6) {
                                            ProgressView().controlSize(.small)
                                            Text(L("Waiting"))
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                    }
                                    HStack(spacing: 12) {
                                        Button(L("Try again")) { retryFailedDownload(failed) }
                                            .font(.caption)
                                            // F-1 (0.9.175): no `isDownloading` here any
                                            // more — `download(from:)` queues FIFO
                                            // (0.9.163), so a retry tapped mid-download
                                            // joins the queue and shows as Queued
                                            // instead of being locked out until the
                                            // running download ends. `isRunning`,
                                            // the batch guard and the retry-task
                                            // mutual exclusion all stay.
                                            .disabled(engine.isRunning || retryTask != nil || retryAllTask != nil)
                                        Button(L("Remove")) { downloader.removeFailedDownload(failed) }
                                            .font(.caption)
                                    }
                                }
                            }
                        } header: {
                            // F-1/F-3 (0.9.174): retry every failed row,
                            // or clear them all — the rows alone only
                            // offer one-at-a-time Try again / Remove, and
                            // a batch failure leaves several rows to work
                            // through. Retry all needs at least two rows
                            // (one row's Try again already does the job);
                            // while it runs the button is Cancel instead,
                            // so a tap stops after the current item. Clear
                            // all asks first (below), and never touches
                            // the in-flight or queued downloads.
                            HStack {
                                Text(L("Failed"))
                                Spacer()
                                Button(retryAllTask != nil ? L("Cancel") : L("Retry all")) {
                                    if retryAllTask != nil {
                                        retryAllTask?.cancel()
                                    } else {
                                        retryAllFailedDownloads()
                                    }
                                }
                                .font(.caption)
                                // F-1 (0.9.175): 同 Try again——`isDownloading`
                                // 不再锁 Retry all：重试进 FIFO 队列排队，
                                // 行状态由队列里的 Queued 承接。
                                .disabled(retryAllTask == nil && (downloader.failedDownloads.count < 2 || retryTask != nil || engine.isRunning || engine.batchUpdateRunning))
                                Button(L("Clear all")) { confirmingClearFailed = true }
                                    .font(.caption)
                                    .disabled(retryTask != nil || retryAllTask != nil)
                            }
                        }
                    }
                    if let error = manager.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.negative)
                    }
                    // UI-4：没扫完先给加载行，别让列表空白看着像没东西。
                    if !manager.hasLoaded {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(L("Loading…"))
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }
                    } else if manager.downloads.isEmpty {
                        Text(L("No downloaded IPAs. Ones you install from a source or a file are cached here."))
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    } else if visibleDownloads.isEmpty {
                        Text(L("没有匹配的 IPA。"))
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    } else {
                        // F2：页顶合计行（文件页合计行同款文案 + 样式）与清空全部。
                        HStack(spacing: 8) {
                            Text(L("%d 个 IPA · %@", manager.downloads.count, manager.totalSizeText))
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                            Spacer()
                            // F-2 (0.9.161): one-tap old-version cleanup — the
                            // count is read now, for the confirm box; nothing
                            // to delete means the result line at once, no box.
                            Button(L("Clean up old versions")) {
                                let preview = manager.cleanupPreview()
                                if preview.deletable.isEmpty {
                                    cleanupResult = manager.cleanupOldVersions()
                                } else {
                                    pendingCleanup = (preview.deletable.count, preview.skipped)
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .disabled(manager.deletingID != nil)
                            Button(L("清空全部")) {
                                clearAllRenewalNames = manager.downloads.compactMap {
                                    RenewalSourceStore.source(forFileURL: $0.url, bundleID: nil)?.appName
                                }
                                confirmingClearAll = true
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.negative)
                            .disabled(manager.deletingID != nil)
                        }
                        ForEach(visibleDownloads) { item in
                            Button { install(item) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "shippingbox.fill")
                                        .font(.title3)
                                        .foregroundStyle(Theme.brand)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.displayName)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(1)
                                        if let modified = item.modified {
                                            let when = Self.dateText(for: modified)
                                            Text(item.isImported ? L("Added %@", when) : L("Downloaded %@", when))
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                        // F-2 (0.9.164): how this file's version
                                        // compares with the installed one.
                                        if let tag = versionTag(for: item) {
                                            Text(tag.text)
                                                .font(.caption)
                                                .foregroundStyle(tag.color)
                                        }
                                    }
                                    Spacer()
                                    Text(item.sizeText)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Theme.accent2)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Theme.accent.opacity(0.16)))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(installingID == item.id)
                            .id(item.id)
                            // F-3 (0.9.164): the revealed row's highlight; nil
                            // keeps every other row on its default background.
                            .listRowBackground(highlightedID == item.id ? Theme.accent.opacity(0.12) : nil)
                            .swipeActions {
                                // F3 (0.9.152): rename from here, Files page
                                // rules (same alert, same validation).
                                Button {
                                    renameText = item.fileName
                                    renameItem = item
                                } label: {
                                    Label(L("重命名"), systemImage: "pencil")
                                }
                                .tint(Theme.accent)
                                Button(role: .destructive) {
                                    // B-1 (0.9.160): read the renewal source now,
                                    // while the row is tapped — the confirm box
                                    // below warns from this, Files page
                                    // `renewalDeleteWarning` 同款（路径对上，或
                                    // 包名对上），不只按路径认。
                                    pendingDeleteRenewalName = RenewalSourceStore.source(
                                        forFileURL: item.url,
                                        bundleID: IPALibrary.appInfo(at: item.url)?.bundleID)?.appName
                                    pendingDelete = item
                                } label: {
                                    Label(L("Delete"), systemImage: "trash")
                                }
                                .disabled(manager.deletingID != nil)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                // F-3 (0.9.164): a reveal request, or the refreshed list it
                // was waiting on — both funnel into the same scroll.
                .onChange(of: revealNonce) { _, _ in reveal(proxy) }
                .onChange(of: manager.downloads) { _, _ in reveal(proxy) }
            }
        }
        .navigationTitle(L("Download"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { manager.refresh() }
        // F-1 (0.9.159): an install that deleted its source IPA rescans
        // this list now, instead of waiting for the next time it's opened.
        .onReceive(NotificationCenter.default.publisher(for: Engine.downloadsChanged)) { _ in
            manager.refresh()
        }
        // F-3 (0.9.164): a history row's "Show in Downloads" — clear the
        // search (it would hide the file), then ask for the reveal; the
        // scroll itself happens in the ScrollViewReader above, once the
        // refreshed list holds the file.
        .onReceive(NotificationCenter.default.publisher(for: Engine.revealDownload)) { note in
            guard let path = note.userInfo?["url"] as? String else { return }
            searchText = ""
            highlightedID = nil
            pendingRevealID = path
            revealNonce += 1
            manager.refresh()
        }
        .alert(L("删除这个下载的 IPA？"), isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button(L("Delete"), role: .destructive) {
                if let item = pendingDelete { manager.delete(item) }
                pendingDelete = nil
                pendingDeleteRenewalName = nil
            }
            Button(L("Cancel"), role: .cancel) {
                pendingDelete = nil
                pendingDeleteRenewalName = nil
            }
        } message: {
            // B-1 (0.9.160): a renewal source says so first — the old
            // "只删文件，不影响已装的 App。" is wrong for exactly this
            // file: deleting it leaves the next renewal with "no matching
            // IPA". A file no app renews from keeps the old line, which
            // is true for it. Wording is the Files page's single-delete
            // warning, one source of truth for both pages.
            if let name = pendingDeleteRenewalName {
                Text(L("这是 %@ 续签用的文件，删了它下次就续不了，要重新导入 IPA 才能续。删除后无法恢复", name))
            } else {
                Text(L("只删文件，不影响已装的 App。"))
            }
        }
        // F3 (0.9.152): rename alert, Files page 同款（标题/字段/保存/
        // 扩展名提示全复用那边的文案）。
        .alert(L("重命名"), isPresented: Binding(
            get: { renameItem != nil },
            set: { if !$0 { renameItem = nil } }
        )) {
            TextField(L("文件名"), text: $renameText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button(L("Cancel"), role: .cancel) { renameItem = nil }
            Button(L("Save")) {
                if let item = renameItem { manager.rename(item, to: renameText) }
                renameItem = nil
            }
        } message: {
            Text(L("扩展名别改错，不然文件可能打不开。"))
        }
        // F2：清空全部确认（文件页批量删同款：带数量的标题，续签源
        // 有名字就列出来、否则只说删后无法恢复）。
        .alert(L("清空全部 %d 个下载？", manager.downloads.count), isPresented: $confirmingClearAll) {
            Button(L("Delete"), role: .destructive) {
                confirmingClearAll = false
                manager.deleteAll()
            }
            Button(L("Cancel"), role: .cancel) { confirmingClearAll = false }
        } message: {
            if !clearAllRenewalNames.isEmpty {
                Text(L("其中 %@ 是续签用的文件，删了它们下次就续不了，要重新导入 IPA 才能续。删除后无法恢复", clearAllRenewalNames.joined(separator: "、")))
            } else {
                Text(L("删除后无法恢复"))
            }
        }
        // F-3 (0.9.174): clear the whole Failed section at once — the
        // header's Clear all asks first, so one tap can't wipe several
        // failure records by accident. Only the failed rows go; the
        // in-flight and queued downloads are untouched.
        .alert(L("Clear all failed downloads?"), isPresented: $confirmingClearFailed) {
            Button(L("Delete"), role: .destructive) {
                confirmingClearFailed = false
                downloader.clearFailedDownloads()
            }
            Button(L("Cancel"), role: .cancel) { confirmingClearFailed = false }
        } message: {
            Text(L("删除后无法恢复"))
        }
        // F-2 (0.9.161): old-version cleanup — confirm with the count,
        // then the result line (deleted / skipped / failed).
        .alert(L("Clean up %d old versions?", pendingCleanup?.count ?? 0), isPresented: Binding(
            get: { pendingCleanup != nil },
            set: { if !$0 { pendingCleanup = nil } }
        )) {
            Button(L("Delete"), role: .destructive) {
                cleanupResult = manager.cleanupOldVersions()
                pendingCleanup = nil
            }
            Button(L("Cancel"), role: .cancel) { pendingCleanup = nil }
        } message: {
            let skipped = pendingCleanup?.skipped ?? 0
            Text(L("Only the newest version of each app is kept. Deleted files can't be recovered.")
                + (skipped > 0 ? " " + L("%d files skipped (in use or needed for renewal).", skipped) : ""))
        }
        .alert(L("Clean up old versions"), isPresented: Binding(
            get: { cleanupResult != nil },
            set: { if !$0 { cleanupResult = nil } }
        )) {
            Button(L("OK"), role: .cancel) { cleanupResult = nil }
        } message: {
            Text(cleanupResult ?? "")
        }
    }

    /// F-1 (0.9.173): re-run one failed download, then install it the
    /// way the update-all batch does — a bare re-download would strand
    /// the file in staging with nothing to install it. The downloader's
    /// own record clears on a landing retry; a failed retry replaces
    /// it with the new reason, and an install failure lands on this
    /// page's error line instead.
    private func retryFailedDownload(_ failed: IPADownloader.FailedDownload) {
        // F-1 (0.9.175): no `isDownloading` here any more — the retry's
        // download joins the FIFO queue (0.9.163) instead of being
        // refused while another download runs; the batch guard below
        // stays, so a retry never starts an install into a batch.
        guard retryTask == nil, retryAllTask == nil, !engine.isRunning else { return }
        // B-1 (0.9.173): an update-all batch owns the install slot —
        // the retry's install would be refused mid-batch, so say so on
        // this page instead of failing silently. The button stays
        // tappable so the tap can surface the reason.
        if engine.batchUpdateRunning {
            manager.lastError = L("全部更新进行中，等它跑完再重试。")
            return
        }
        retryTask = Task {
            await runFailedRetry(failed)
            retryTask = nil
        }
    }

    /// F-1 (0.9.174): retry every failed download, one at a time — the
    /// same body as the row's Try again (`runFailedRetry`), serially,
    /// so two installs never race for the install slot. The snapshot
    /// is taken up front (rows clear as their retries land); a
    /// declined cellular ask stops the run, and cancelling stops after
    /// the current item instead of starting the next one.
    private func retryAllFailedDownloads() {
        // F-1 (0.9.175): 同 retryFailedDownload——`isDownloading` 不再
        // 拦入口，重试进 FIFO 队列；batch 守卫保留。
        guard retryAllTask == nil, retryTask == nil, !engine.isRunning else { return }
        // B-1 (0.9.173) 同款：批跑时不另起重装——行按钮同款文案。
        if engine.batchUpdateRunning {
            manager.lastError = L("全部更新进行中，等它跑完再重试。")
            return
        }
        let targets = downloader.failedDownloads
        guard targets.count >= 2 else { return }
        retryAllTask = Task {
            for failed in targets {
                if Task.isCancelled { break }
                guard await runFailedRetry(failed) else { break }
            }
            retryAllTask = nil
        }
    }

    /// F-1 (0.9.174): one failed download's retry body — the cellular
    /// ask, the download, then the install like the batch does. Shared
    /// by the row's Try again and Retry all, so the two paths can't
    /// drift apart. Returns false only when the user declined the
    /// cellular ask (the caller stops); a download or install failure
    /// is already recorded — a fresh failure replaces the row, an
    /// install failure lands on this page's error line — so it still
    /// returns true.
    private func runFailedRetry(_ failed: IPADownloader.FailedDownload) async -> Bool {
        // The source row's retry re-runs its install path, which
        // asks first — this one does the same, so a big IPA over
        // cellular doesn't re-download silently.
        guard await engine.confirmCellularDownload(size: nil, what: failed.name) else { return false }
        do {
            let file = try await downloader.download(from: failed.url)
            // B-1 (0.9.176): `startInstall` 同款 wait 循环——下载落地
            // 时不等在途安装，直接撞 `importCustomIPA` 的 `guard
            // !isRunning` 被拒，且拒掉那路会调 `discardInboxCopy`
            // 把刚下好的几百 MB 删掉（再重试从零重下）；更糟是批跑
            // 下载间隙落地会偷走批跑的槽。等的同时行上标“等待中”
            // （`waitingRetryURL`，上面）；取消即返。
            waitingRetryURL = failed.url
            while engine.isRunning || engine.batchUpdateRunning, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
            }
            waitingRetryURL = nil
            guard !Task.isCancelled else { return true }
            let outcome = await engine.installOneCustomIPA(file)
            if let error = outcome.error, !outcome.declined {
                manager.lastError = error
            }
        } catch {
            // A fresh failure is already the downloader's record; a
            // cancel just drops the wait silently.
        }
        return true
    }

    /// Tap a row to install that IPA: copy it into the Install tab's custom
    /// import slot, then raise the Install sheet on it — RootView jumps on
    /// `sharedIPAReady`, the share path's flag. A refused import (an install
    /// or refresh already running) leaves the reason on this page instead of
    /// opening the sheet.
    private func install(_ item: DownloadedIPA) {
        // F-3 (0.9.164): the highlight has done its job once the row is tapped.
        highlightedID = nil
        guard installingID == nil else {
            // U2 (0.9.145): the other rows stay tappable while one imports —
            // say so instead of silently ignoring the tap (the import itself
            // still refuses while one is running; see importCustomIPA).
            manager.lastError = L("This file is being installed. Wait until it finishes.")
            return
        }
        // B-1 (0.9.175): an update-all batch owns the install slot — its
        // download gaps leave `engine.isRunning` false, so the import
        // below would be refused mid-batch (Engine.swift:2386). Say so
        // on this page instead of failing silently; the retry entry
        // (`retryFailedDownload`) 同款：write `manager.lastError`,
        // don't open the sheet.
        if engine.batchUpdateRunning {
            manager.lastError = L("全部更新进行中，等它跑完再安装。")
            return
        }
        installingID = item.id
        Task {
            let ok = await engine.importCustomIPA(from: item.url)
            if ok {
                engine.sharedIPAReady = true
            } else if let error = engine.lastError {
                manager.lastError = error
            }
            installingID = nil
        }
    }
}
