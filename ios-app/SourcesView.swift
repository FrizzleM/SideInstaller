import Combine
import SwiftUI
import UserNotifications

/// U-UI：源/应用列表排序（照抄 FilesTabView 的 FileSort 形状；源列表只用
/// 默认/名称/最新，应用列表四项全用）。
private enum SourceSort: String, CaseIterable {
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

/// The App Sources list: every source the user added, each leading to its
/// apps. Reached from the Sources tab.
struct SourcesView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @StateObject private var store = SourceStore()

    @State private var showAddAlert = false
    @State private var newSourceURL = ""
    @State private var addFailed = false
    /// U-UI：源列表排序（默认/名称/最新；大小只用于应用列表）。
    @State private var sourceSort = SourceSort.default
    /// U-UI：源列表搜索（名字含查询串，不区分大小写）。
    @State private var sourceSearchText = ""

    var body: some View {
        VStack(spacing: 12) {
            searchBar
                .padding(.horizontal, 20)
            List {
                if store.sources.contains(where: \.isLoading) {
                    Text(L("正在刷新数据中…"))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let last = store.sources.compactMap(\.fetchedAt).max() {
                    Text(L("最后更新：%@", last.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Localizer.locale))))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                if store.sources.isEmpty {
                    Text(L("No sources yet. Tap + to add one."))
                        .foregroundStyle(Theme.muted)
                }
                ForEach(displayedSources) { source in
                    NavigationLink {
                        SourceAppsView(store: store, sourceURL: source.url)
                    } label: {
                        sourceRow(source)
                    }
                    .deleteDisabled(source.url == UnifiedSourceList.builtInURL)
                }
                .onDelete { offsets in
                    for offset in offsets {
                        let item = displayedSources[offset]
                        if let idx = store.sources.firstIndex(where: { $0.url == item.url }) {
                            store.removeSource(at: IndexSet(integer: idx))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { await store.fetchAll(force: true) }
            .task { store.syncURLs(); await store.fetchAll() }
            .onReceive(NotificationCenter.default.publisher(for: UnifiedSourceList.didChange)) { _ in
                Task { @MainActor in store.syncURLs() }
            }
        }
        .blueTopBar()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L("AppStore"))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showAddAlert = true } label: {
                    Image(systemName: "plus").foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach([SourceSort.default, .name, .newest], id: \.self) { option in
                        Button {
                            sourceSort = option
                        } label: {
                            if sourceSort == option {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    Text(L("筛选")).foregroundStyle(.white)
                }
            }
        }
        .alert(L("Add Source"), isPresented: $showAddAlert) {
            TextField(L("Source URL"), text: $newSourceURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(L("Add")) {
                if store.addSource(newSourceURL) {
                    newSourceURL = ""
                } else {
                    addFailed = true
                }
            }
            Button(L("Cancel"), role: .cancel) { newSourceURL = "" }
        }
        .alert(L("That isn't a usable source link."), isPresented: $addFailed) {
            Button(L("OK"), role: .cancel) { }
        }
    }

    /// U-UI：搜索过滤 + 排序后的源（onDelete 按 url 回映射到 store.sources，
    /// 不能直接用 displayedSources 的下标删 store.sources）。
    private var displayedSources: [LoadedSource] {
        let q = sourceSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        var list = store.sources
        if !q.isEmpty {
            list = list.filter { $0.displayName.lowercased().contains(q) }
        }
        switch sourceSort {
        case .default:
            return list
        case .name:
            return list.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .size:
            return list
        case .newest:
            return list.sorted { ($0.fetchedAt ?? .distantPast) > ($1.fetchedAt ?? .distantPast) }
        }
    }

    /// U-UI：搜索框。
    private var searchBar: some View {
        SearchBar(text: $sourceSearchText, placeholder: L("搜索"))
    }

    /// One source: its icon and name, with the app count, a spinner while it
    /// loads, or its load error on the trailing side.
    private func sourceRow(_ source: LoadedSource) -> some View {
        HStack(spacing: 12) {
            sourceIcon(source.model?.iconLink)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .font(.headline)
                    .lineLimit(1)
                if let subtitle = source.model?.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                // F-3 (0.9.161): when this source was last checked — the
                // persisted time, so it survives a restart. Over 24 hours
                // without a check reads as stale, in the warning color.
                if let checked = source.lastCheckedAt {
                    Text(Self.checkedText(for: checked))
                        .font(.caption)
                        .foregroundStyle(Date().timeIntervalSince(checked) > 24 * 3600 ? Theme.warning : Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            if source.isLoading {
                ProgressView()
            } else if let error = source.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Theme.negative)
                    .lineLimit(2)
            } else if source.model != nil {
                Text(L("%d apps", source.apps.count))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            // F1 (0.9.152): per-source enable switch — off means never
            // fetched and never counted toward updates, without deleting it.
            Toggle(L("Enabled"), isOn: Binding(
                get: { !store.isDisabled(source.url) },
                set: { store.setDisabled(source.url, !$0) }
            ))
            .labelsHidden()
        }
        .opacity(store.isDisabled(source.url) ? 0.5 : 1)
    }

    /// F-3 (0.9.161): "x 分钟前检查过" — just now / minutes / hours / days
    /// from the persisted last-check time. Over 24 hours the row colors
    /// it as stale (see the call site in `sourceRow`).
    private static func checkedText(for date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 { return L("Checked just now") }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return L("Checked %d minutes ago", minutes) }
        let hours = minutes / 60
        if hours < 24 { return L("Checked %d hours ago", hours) }
        return L("Checked %d days ago", hours / 24)
    }

    /// A source or app icon: the remote image, or a box placeholder while it
    /// loads and when there is none.
    private func sourceIcon(_ url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "shippingbox")
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 44, height: 44)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// One source's apps, each with an Install button that downloads the IPA and
/// hands it to the one-click pipeline on the main screen.
struct SourceAppsView: View {
    @Environment(Engine.self) private var engine: Engine
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// 企业页共享工作区（RootView 在 TabView 层注入，证书页与
    /// 安装 tab 的来源页都在它里面，声明安全）：企业路径成功后
    /// 把刚导入的 IPA 写到这里，企业页 onChange 接住 → select()
    /// → 签名表单预填——v63 前这条交接根本没有，签名段拿不到
    /// 刚导入的 App，才显得“空白卡死”。
    @EnvironmentObject private var certWorkspace: CertWorkspace
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: SourceStore
    let sourceURL: URL
    /// 0.9.140: what is installed comes from the Sideloaded apps page's
    /// device read (RootView injects it at the tab level), so this list can
    /// tell which of the source's apps have an update — same match as
    /// `SourcesManager.installedVersion`, only over `AltApp`.
    @EnvironmentObject private var appsManager: SideloadedAppsManager

    @StateObject private var downloader = IPADownloader.shared
    /// Row states by app id; an absent entry is idle.
    @State private var states: [String: RowState] = [:]
    /// 企业路径失败过的 app id（仅 startCertInstall 的 catch 写，
    /// startInstall 的 catch 永不写）：失败行的“Try again”按它
    /// 分流——企业失败重试企业路，ID 失败重试 ID 路，不串路。
    /// 任一路成功就清掉（成功即复位，下次失败重新定性）。
    @State private var certFailedIDs: Set<String> = []
    /// The app the update-all batch is on, if one is going: only the
    /// batch sets this now — single downloads queue in the downloader
    /// instead (F-1, 0.9.163), so it no longer means "a download is
    /// running". The batch's button and the rows' guards still read it.
    @State private var activeID: String?
    /// F-1 (0.9.163): one Task per downloading app, keyed by app id —
    /// several rows can be downloading or queued at once now, so the
    /// single `downloadTask` can't say which row a Cancel tap means.
    @State private var downloadTasks: [String: Task<Void, Never>] = [:]
    /// F3 (0.9.154): the batch update-all run, if one is going — its Task
    /// (the cancel handle), which app it is on, and the summary the
    /// end-of-batch alert shows.
    @State private var updateAllTask: Task<Void, Never>?
    @State private var updateAllIndex = 0
    @State private var updateAllTotal = 0
    @State private var updateAllCurrent: String?
    @State private var updateAllSummary: String?
    @State private var showingUpdateAllSummary = false
    /// U-UI：应用列表排序。
    @State private var appSort = SourceSort.default
    /// U-UI：应用列表搜索（名字含查询串，不区分大小写）。
    @State private var appSearchText = ""
    /// F-1 (0.9.161): the installed app awaiting uninstall confirmation
    /// (installed bundle ID + shown name), the one uninstalling, and a
    /// failure to report — the confirm box is the swipe's, the failure
    /// box the run's.
    @State private var pendingUninstall: (bundleID: String, name: String)?
    @State private var uninstallingID: String?
    @State private var uninstallError: String?

    /// What one app's row is doing.
    private enum RowState: Equatable {
        case downloading
        /// F-1 (0.9.163): tapped while another download runs — the
        /// downloader queues it, and the row shows this until its turn.
        case queued
        case failed(String)
    }

    /// F-1 (0.9.163): what the row shows — the downloader's live state
    /// wins over the tap-time state: a queued tap becomes "downloading"
    /// when its turn comes, without the row re-tapping anything. A row
    /// whose download landed and is waiting for an earlier install to
    /// finish keeps its tap-time `.queued` (the install wait has no
    /// progress of its own to show).
    private func effectiveRowState(for app: AltApp) -> RowState? {
        guard let state = states[app.id] else { return nil }
        switch state {
        case .downloading, .queued:
            guard let url = app.downloadLink else { return state }
            if downloader.currentURL == url { return .downloading }
            if downloader.queue.contains(where: { $0.url == url }) { return .queued }
            return state
        case .failed:
            return state
        }
    }

    /// F-1 (0.9.163): stop one row's download — the running one, or a
    /// queued one. `cancelDownload(url:)` only settles that row's waiter,
    /// so cancelling a queued row can't kill the download in front of it;
    /// cancelling the row's Task covers the wait before the download
    /// starts (the cellular prompt), and its catch clears the row.
    private func cancelRowDownload(_ app: AltApp) {
        if let url = app.downloadLink { downloader.cancelDownload(url: url) }
        downloadTasks[app.id]?.cancel()
        downloadTasks[app.id] = nil
    }

    /// The source as last loaded; nil once removed elsewhere.
    private var source: LoadedSource? {
        store.sources.first { $0.url == sourceURL }
    }

    var body: some View {
        VStack(spacing: 12) {
            if source != nil {
                searchBar
                    .padding(.horizontal, 20)
            }
            List {
                if let source {
                    if source.isLoading && source.model == nil {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(L("Loading…"))
                                .foregroundStyle(Theme.muted)
                        }
                } else if let error = source.errorMessage, source.model == nil {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.negative)
                }
                // P2: the Updates section first, mirroring the upstream Sources
                // page — an app both sections list is listed under each.
                if !updateApps.isEmpty {
                    Section {
                        ForEach(updateApps, id: \.id) { app in
                            appRow(app)
                        }
                        // F3 (0.9.154): the batch run's progress + stop
                        // button, next to the rows it is working through.
                        if updateAllTask != nil {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text(L("正在更新第 %d/%d 个：%@", updateAllIndex, updateAllTotal, updateAllCurrent ?? ""))
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                Button(L("Cancel")) { cancelUpdateAll() }
                                    .font(.footnote)
                            }
                        }
                    } header: {
                        HStack {
                            Text(L("Updates"))
                            Spacer()
                            // F3 (0.9.154): update every app in this
                            // section, one at a time (see startUpdateAll).
                            Button(L("全部更新")) { startUpdateAll() }
                                .font(.subheadline)
                                .disabled(updateAllTask != nil || activeID != nil || engine.isRunning)
                        }
                    }
                }
                ForEach(displayedApps, id: \.id) { app in
                    appRow(app)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await store.fetch(sourceURL, force: true) }
        .task { await store.fetch(sourceURL) }
        // P2: read the device once, so the update check below has installed
        // versions to compare against (same as the upstream Sources page).
        .task { appsManager.autoLoad() }
        }
        .blueTopBar()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L("AppStore"))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Text("‹ " + L("软件源"))
                        .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(SourceSort.allCases, id: \.self) { option in
                        Button {
                            appSort = option
                        } label: {
                            if appSort == option {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    Text(L("筛选")).foregroundStyle(.white)
                }
            }
        }
        // F3 (0.9.154): the update-all totals, once the batch finishes.
        .alert(L("全部更新"), isPresented: $showingUpdateAllSummary) {
            Button(L("OK")) {}
        } message: {
            Text(updateAllSummary ?? "")
        }
        // F-1 (0.9.161): uninstall confirm + failure, for the row swipe.
        .alert(L("Uninstall %@?", pendingUninstall?.name ?? ""), isPresented: Binding(
            get: { pendingUninstall != nil },
            set: { if !$0 { pendingUninstall = nil } }
        )) {
            Button(L("Uninstall"), role: .destructive) {
                if let pending = pendingUninstall {
                    pendingUninstall = nil
                    uninstallApp(bundleID: pending.bundleID)
                }
            }
            Button(L("Cancel"), role: .cancel) { pendingUninstall = nil }
        } message: {
            Text(L("This removes %@ from this iPhone, including its data.", pendingUninstall?.name ?? ""))
        }
        .alert(L("Uninstall"), isPresented: Binding(
            get: { uninstallError != nil },
            set: { if !$0 { uninstallError = nil } }
        )) {
            Button(L("OK"), role: .cancel) { uninstallError = nil }
        } message: {
            Text(uninstallError ?? "")
        }
        // F2 (0.9.153): leaving the page no longer cancels the download —
        // the shared downloader keeps it running, and the completion
        // notification (see startInstall/startCertInstall) says when it
        // lands. Only the row's Cancel button stops it.
    }

    /// U-UI：截图式应用行——60pt 图标 / 名字 / “应用 - 源名（副标题）” /
    /// V版本 | 大小 | 日期 / 多行描述 / 右侧蓝色下载 pill。
    /// P2：已装时多一行已装版本与更新状态（上游 `statusText` 同款文案），
    /// 行尾多一枚 Update/Installed 角标；描述走上游的 ReleaseNotesText。
    private func appRow(_ app: AltApp) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                appIcon(app.iconLink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name ?? "")
                        .font(.headline)
                        .lineLimit(1)
                    Text(sourceLine(for: app))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    Text(metaLine(for: app))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    if let installed = installedVersion(for: app) {
                        if hasUpdate(for: app) {
                            Text(L("%@ installed · %@ available", installed, app.version ?? ""))
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                                .lineLimit(1)
                        } else if isDowngrade(for: app), let latest = app.version {
                            // B-3 (0.9.165)：源比已装旧——不再写死「up to date」，
                            // 行文案就是 0.9.164 的版本对比 tag。
                            let tag = czfVersionComparisonTag(fileVersion: latest, installedVersion: installed)
                            Text(tag.text)
                                .font(.caption)
                                .foregroundStyle(tag.color)
                                .lineLimit(1)
                        } else {
                            Text(L("%@ installed · up to date", installed))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                if hasUpdate(for: app) {
                    Tag(text: L("Update"), color: Theme.warning)
                } else if isDowngrade(for: app), let installed = installedVersion(for: app),
                          let latest = app.version {
                    // B-3 (0.9.165)：降级角标——同一份 tag，不再冒充 Installed。
                    let tag = czfVersionComparisonTag(fileVersion: latest, installedVersion: installed)
                    Tag(text: tag.text, color: tag.color)
                } else if installedVersion(for: app) != nil {
                    Tag(text: L("Installed"), color: Theme.positive)
                }
                installControl(app)
            }
            if let description = appDescription(app), !description.isEmpty {
                ReleaseNotesText(text: description)
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // F-1 (0.9.161): uninstall the installed copy — only when this
            // source's app is on the device, never SideInstaller itself.
            if let bundleID = installedBundleID(for: app),
               bundleID != Bundle.main.bundleIdentifier {
                Button(role: .destructive) {
                    pendingUninstall = (bundleID, app.name ?? bundleID)
                } label: {
                    Label(L("Uninstall"), systemImage: "trash")
                }
                .disabled(uninstallingID != nil)
            }
        }
    }

    /// 第二行：“应用 - 源名”，副标题有就跟在括号里（截图同款）。
    private func sourceLine(for app: AltApp) -> String {
        let base = L("应用 - %@", source?.displayName ?? "")
        if let subtitle = source?.model?.subtitle, !subtitle.isEmpty {
            return base + " (\(subtitle))"
        }
        return base
    }

    /// 第三行：“V版本 | 大小 | 日期 | iOS 最低版本”，缺的段直接省掉（不留空竖线）。
    /// F-2 (0.9.166)：最低 iOS 终于有地方看——`minOSVersion` 早就解码了
    ///（SourcesStore），全仓却没一处显示；行上看不见，点了才下载整个
    /// IPA，装时才在 Engine 的 minOS 守卫被拒。缺字段的源直接省掉这段。
    private func metaLine(for app: AltApp) -> String {
        var parts: [String] = []
        if let version = app.version, !version.isEmpty { parts.append("V\(version)") }
        if let size = app.sizeText { parts.append(size) }
        if let date = app.versionDate, !date.isEmpty { parts.append(date) }
        if let minOS = app.minOSVersion, !minOS.isEmpty { parts.append("iOS \(minOS)+") }
        return parts.joined(separator: " | ")
    }

    /// 描述行：localizedDescription 优先，空了退回 subtitle。
    private func appDescription(_ app: AltApp) -> String? {
        if let desc = app.localizedDescription, !desc.isEmpty { return desc }
        return app.subtitle
    }

    /// U-UI：搜索过滤 + 排序后的应用（最新按 versionDate 字符串倒序，不解析日期）。
    private var displayedApps: [AltApp] {
        guard let source else { return [] }
        let q = appSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        var list = source.apps
        if !q.isEmpty {
            list = list.filter { ($0.name ?? "").lowercased().contains(q) }
        }
        switch appSort {
        case .default:
            return list
        case .name:
            return list.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        case .size:
            return list.sorted { ($0.size ?? 0) > ($1.size ?? 0) }
        case .newest:
            return list.sorted { ($0.versionDate ?? "") > ($1.versionDate ?? "") }
        }
    }

    /// The shown apps with a newer version available, first in their own
    /// section above. (P2, upstream Sources page's Updates section.)
    private var updateApps: [AltApp] { displayedApps.filter { hasUpdate(for: $0) } }

    /// The version of `app` on this iPhone, from the Sideloaded apps page's
    /// device read. Same match as `SourcesManager.installedVersion`:
    /// SideInstaller signs an app as `<bundle id>.<team id>`, so that counts
    /// as the same app. (P2, upstream `installedVersion`.)
    private func installedVersion(for app: AltApp) -> String? {
        guard let bundleID = app.bundleIdentifier, !bundleID.isEmpty else { return nil }
        return appsManager.entries.first {
            ProfileMatcher.installed($0.app.bundleID, isBuiltFrom: bundleID, teamID: nil)
        }?.app.version
    }

    /// F-1 (0.9.161): the installed bundle ID behind `installedVersion`,
    /// for the uninstall swipe — the exact ID installd knows, team suffix
    /// and all, not the source's base ID.
    private func installedBundleID(for app: AltApp) -> String? {
        guard let bundleID = app.bundleIdentifier, !bundleID.isEmpty else { return nil }
        return appsManager.entries.first {
            ProfileMatcher.installed($0.app.bundleID, isBuiltFrom: bundleID, teamID: nil)
        }?.app.bundleID
    }

    /// F-1 (0.9.161): uninstall one installed app, then re-read the device
    /// list so the row's "installed" line is gone without leaving the
    /// page. Failures surface here, next to the row the user swiped.
    private func uninstallApp(bundleID: String) {
        guard uninstallingID == nil else { return }
        uninstallingID = bundleID
        Task { @MainActor in
            do {
                try await engine.uninstallApp(bundleID: bundleID)
                let task = appsManager.load()
                if let task { await task.value } else { await appsManager.inFlightLoadTask?.value }
            } catch {
                uninstallError = userFacingErrorMessage(error)
            }
            uninstallingID = nil
        }
    }

    /// True when the source offers a newer version than the installed one.
    /// (P2, upstream `SourceListing.hasUpdate`.)
    private func hasUpdate(for app: AltApp) -> Bool {
        guard let installed = installedVersion(for: app),
              let latest = app.version, !latest.isEmpty else { return false }
        return UpdateChecker.isNewer(latest, than: installed)
    }

    /// B-3 (0.9.165): true when the source's newest build is older than
    /// the installed one — the source lags behind the app's releases
    /// (SourceListing.isDowngrade 同款，live 路的 AltApp 版）。
    private func isDowngrade(for app: AltApp) -> Bool {
        guard let installed = installedVersion(for: app),
              let latest = app.version, !latest.isEmpty else { return false }
        return UpdateChecker.isNewer(installed, than: latest)
    }

    /// U-UI：搜索框。
    private var searchBar: some View {
        SearchBar(text: $appSearchText, placeholder: L("搜索"))
    }

    /// F-C (0.9.156): the download's second line — speed, downloaded of
    /// total, and time left when the total and a speed are both known.
    /// Unknown totals show speed and bytes only, never a stuck 0%.
    private var downloadDetailLine: String {
        let speed = L("%@/s", ByteCountFormatter.string(fromByteCount: Int64(downloader.downloadSpeed), countStyle: .file))
        if downloader.totalBytesExpected > 0 {
            let of = L("%@ of %@",
                       ByteCountFormatter.string(fromByteCount: downloader.bytesWritten, countStyle: .file),
                       ByteCountFormatter.string(fromByteCount: downloader.totalBytesExpected, countStyle: .file))
            if let eta = downloader.estimatedTimeRemaining {
                return "\(speed) • \(of) • \(L("%@ left", Self.etaText(eta)))"
            }
            return "\(speed) • \(of)"
        }
        return "\(speed) • \(L("%@ downloaded", ByteCountFormatter.string(fromByteCount: downloader.bytesWritten, countStyle: .file)))"
    }

    /// "3:42", or "1:12:33" past the hour, for a remaining-time estimate.
    private static func etaText(_ eta: TimeInterval) -> String {
        let total = Int(eta.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// The row's trailing control: Install, the download progress with its
    /// percentage, or a failure with a retry.
    @ViewBuilder
    private func installControl(_ app: AltApp) -> some View {
        switch effectiveRowState(for: app) {
        case .downloading:
            VStack(spacing: 4) {
                // B1 (0.9.155): a chunked transfer never states a total, so
                // `progress` sits at 0 the whole way — show an indeterminate
                // spinner plus the bytes so far instead of a stuck 0%.
                if downloader.totalBytesExpected > 0 {
                    ProgressView(value: downloader.progress)
                        .frame(width: 72)
                    Text(L("Downloading… %d%%", Int(downloader.progress * 100)))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                } else {
                    ProgressView()
                        .frame(width: 72)
                    Text(L("%@ downloaded", ByteCountFormatter.string(fromByteCount: downloader.bytesWritten, countStyle: .file)))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                // F-C (0.9.156): speed + downloaded/total + time left, once
                // two samples have measured a speed; unknown totals show
                // speed and bytes only, never a 0% that never moves.
                if downloader.downloadSpeed > 0 {
                    Text(downloadDetailLine)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                // F2 (0.9.153): leaving the page no longer cancels, so the
                // row keeps the only stop button — an explicit user cancel.
                // F-B (0.9.155): Pause suspends the task in place; Resume
                // picks it up again, and a cancelled-then-retapped download
                // resumes from its resume data instead of restarting.
                HStack(spacing: 12) {
                    Button(downloader.isPaused ? L("Resume") : L("Pause")) {
                        if downloader.isPaused {
                            downloader.resume()
                        } else {
                            downloader.pause()
                        }
                    }
                    .font(.caption)
                    Button(L("Cancel")) { cancelRowDownload(app) }
                    .font(.caption)
                }
            }
        case .queued:
            // F-1 (0.9.163): waiting for the slot — the name of the state
            // is the whole UI, plus the same Cancel as the running row.
            VStack(spacing: 4) {
                Text(L("Queued"))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Button(L("Cancel")) { cancelRowDownload(app) }
                    .font(.caption)
            }
        case .failed(let message):
            VStack(alignment: .trailing, spacing: 4) {
                // 失败重试走原路：企业失败重试企业路（清 flag 后
                // startCertInstall 里失败会重写），ID 失败维持原样。
                // B-1 (0.9.164): the entry guards in `startInstall` /
                // `startCertInstall` only let a row through when its state
                // is nil, and nothing ever cleared `.failed` back to nil —
                // the retry silently died in the guard. Clear it first,
                // so the tap actually retries.
                Button(L("Try again")) {
                    states[app.id] = nil
                    if certFailedIDs.contains(app.id) {
                        startCertInstall(app)
                    } else {
                        startInstall(app)
                    }
                }
                .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                .controlSize(.small)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.negative)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            }
        case nil:
            if EnterpriseCertStore.ready {
                Menu {
                    Button {
                        startInstall(app)
                    } label: {
                        Label(L("用 Apple ID 安装"), systemImage: "person.crop.circle")
                    }
                    Button {
                        startCertInstall(app)
                    } label: {
                        Label(L("企业证书签名安装"), systemImage: "checkmark.seal")
                    }
                } label: {
                    DownloadPill()
                }
                // F-1 (0.9.163): a tap while another download runs queues
                // behind it now, so the row is only disabled while an
                // install runs — not while a download does.
                .disabled(engine.isRunning)
            } else {
                Button { startInstall(app) } label: {
                    DownloadPill()
                }
                .buttonStyle(.plain)
                .disabled(engine.isRunning)
            }
        }
    }

    private func appIcon(_ url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "app")
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 60, height: 60)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// F2 (0.9.153): the download outlives the page, so a finished download
    /// says so even when the user has moved on. Permission follows the
    /// existing launch-time request (SideInstallerApp); if it was refused,
    /// `add` throws and the failure is only logged, like the resign
    /// notifications — the imported file is in Downloads either way.
    private func postDownloadNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = L("Download complete")
        content.body = L("%@ downloaded. You can install it from the Downloads page.", appName)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "source-download-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: nil)
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                Engine.shared.log("Sources: download notification failed to send (\(error.localizedDescription)).")
            }
        }
    }

    /// Download the app's IPA, import it as the custom IPA, then start the
    /// one-click install and pop back to the main screen to watch it run.
    /// F-1 (0.9.163): a tap while another download runs queues behind it
    /// (`states` goes to `.queued`; the downloader's live state decides
    /// what the row shows from there). The guard only bars a second tap
    /// on the same row.
    private func startInstall(_ app: AltApp) {
        guard states[app.id] == nil, let url = app.downloadLink else { return }
        states[app.id] = .queued
        let expectedName = Engine.importFileName(for: url)
        // B-2 (0.9.167)：最低 iOS 不符直接拒——行上已显示 minOSVersion，
        // 却要等几百 MB 下完、导入完才在 runOneClick 的后置守卫
        // （minOSBlockReason）被拒。下载前、蜂窝确认前就拦：不下载、
        // 不弹流量确认，失败文案与 runOneClick 的同款。
        if let minOS = app.minOSVersion, !minOS.isEmpty,
           !SideStoreDownloader.runs(on: ProcessInfo.processInfo.operatingSystemVersion, from: minOS, to: nil) {
            states[app.id] = .failed(L("%@ needs iOS %@ or later. This iPhone runs iOS %@.",
                                        app.name ?? expectedName, minOS, engine.osVersionText))
            return
        }
        downloadTasks[app.id] = Task {
            do {
                // F-G (0.9.156): with "Wi-Fi only downloads" on, a cellular
                // download asks first — the row's size is what the prompt shows.
                guard await engine.confirmCellularDownload(size: app.size.map(Int64.init),
                                                           what: app.name ?? expectedName) else {
                    states[app.id] = nil
                    return
                }
                let file = try await downloader.download(from: url)
                // F-1 (0.9.163): a queued download lands while an earlier
                // item's install is still running — the import refuses
                // mid-run (B3) and deletes the staged file, so wait the
                // run out first, then import and install this one in
                // turn. The row keeps `.queued` meanwhile (the downloader
                // has moved on, so the effective state falls back to it).
                while engine.isRunning, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                }
                guard !Task.isCancelled else {
                    states[app.id] = nil
                    return
                }
                // The staged file already carries `expectedName`: the import
                // names the custom slot after it.
                _ = await engine.importCustomIPA(from: file)
                guard engine.lastError == nil,
                      IPALibrary.customImport()?.url.lastPathComponent == expectedName
                else {
                    throw NSError(domain: "SourceAppsView", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey:
                                                engine.lastError ?? L("Import failed")])
                }
                guard !Task.isCancelled else {
                    states[app.id] = nil
                    return
                }
                postDownloadNotification(appName: app.name ?? expectedName)
                engine.installSource = .custom
                // Drop any earlier run's cached path, so the pipeline reads
                // the import from disk (its own check would skip it anyway:
                // the cached source no longer matches).
                engine.downloadedIPAPath = nil
                states[app.id] = nil
                certFailedIDs.remove(app.id)
                engine.runOneClick()
                dismiss()
            } catch {
                // B-C2：取消下载时不记失败行——成功路的
                // Task.isCancelled 守卫同款，catch 里也要有。
                // F-1 (0.9.163)：取消一条排队的下载只结算它自己的
                // continuation（URLError .cancelled，Task 本身没取消）
                // ——同样静默，不记失败行。
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    states[app.id] = nil
                    return
                }
                states[app.id] = .failed(error.localizedDescription)
            }
        }
    }

    /// F3 (0.9.154): update every app in the Updates section, one at a
    /// time — download, then `installOneCustomIPA` (import + one-click
    /// install + wait for it to finish), skipping failures and reporting
    /// the totals at the end. The single-install path (`startInstall`)
    /// dismisses the page after starting, so the batch reuses its steps
    /// through `installOneCustomIPA` instead of calling it; `activeID`
    /// stays set for the whole item (download + install) so a row's
    /// Download button can't start a second install mid-batch, while
    /// the row's progress pill only shows during the download itself.
    private func startUpdateAll() {
        guard updateAllTask == nil, !updateApps.isEmpty, activeID == nil, !engine.isRunning else { return }
        // B-2 (0.9.168): `startInstall` 同款最低 iOS 前置检查——0.9.167
        // 只堵了单装两路，全部更新是第三路：不符项整包下完才在后置守卫
        // 被拒，白占一个下载位。事前滤出：不符项不进 targets、不占蜂窝
        // 总量、不占下载位；汇总里按 startInstall 同款文案说明哪款、
        // 为什么跳过（与失败行同一格式列出）。
        var skippedMinOS: [(name: String, error: String)] = []
        let targets = updateApps.filter { app in
            guard let minOS = app.minOSVersion, !minOS.isEmpty,
                  !SideStoreDownloader.runs(on: ProcessInfo.processInfo.operatingSystemVersion, from: minOS, to: nil)
            else { return true }
            skippedMinOS.append((app.name ?? app.bundleIdentifier ?? "",
                                 L("%@ needs iOS %@ or later. This iPhone runs iOS %@.",
                                   app.name ?? app.bundleIdentifier ?? "", minOS, engine.osVersionText)))
            return false
        }
        updateAllTotal = targets.count
        updateAllIndex = 0
        updateAllCurrent = nil
        updateAllTask = Task { @MainActor in
            var succeeded = 0
            var failed: [(name: String, error: String)] = []
            var stopped = false
            // F-G (0.9.156): one prompt for the whole batch, with the total
            // size when every app states one — not one prompt per item.
            // B-2 (0.9.168): 全被滤掉时不弹确认——没有要下的东西，直接汇总。
            let batchSizes = targets.compactMap(\.size)
            let batchSize: Int64? = batchSizes.count == targets.count
                ? Int64(batchSizes.reduce(0, +)) : nil
            if !targets.isEmpty {
                guard await engine.confirmCellularDownload(size: batchSize,
                                                           what: L("%d updates", targets.count)) else {
                    updateAllTask = nil
                    updateAllCurrent = nil
                    updateAllIndex = 0
                    updateAllTotal = 0
                    return
                }
            }
            for (offset, app) in targets.enumerated() {
                if Task.isCancelled || stopped { break }
                updateAllIndex = offset + 1
                let name = app.name ?? app.bundleIdentifier ?? ""
                updateAllCurrent = name
                guard let url = app.downloadLink else {
                    failed.append((name, L("Import failed")))
                    continue
                }
                activeID = app.id
                states[app.id] = .downloading
                do {
                    let file = try await downloader.download(from: url)
                    states[app.id] = nil
                    let outcome = await engine.installOneCustomIPA(file)
                    if let error = outcome.error {
                        failed.append((name, error))
                        stopped = outcome.stopped
                    } else {
                        succeeded += 1
                    }
                } catch {
                    // B-C2 同款：取消下载不记失败行——这里是整批取消，
                    // 记一条“已停止”就收尾，剩下的进下面的未跑填补。
                    if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                        failed.append((name, L("Install stopped")))
                        activeID = nil
                        states[app.id] = nil
                        break
                    }
                    failed.append((name, error.localizedDescription))
                }
                activeID = nil
                states[app.id] = nil
            }
            // 没跑到的各项：停批的原因同样记一条，不静默丢掉
            // （installSelection 同款）。
            if failed.count + succeeded < targets.count {
                let reason = failed.last?.error ?? L("Install stopped")
                for app in targets[(failed.count + succeeded)...] {
                    failed.append((app.name ?? app.bundleIdentifier ?? "", reason))
                }
            }
            // B-2 (0.9.168): 事前滤出的最低 iOS 不符项——没下载、没占位，
            // 但汇总里要说明哪款、为什么跳过；与失败行同一格式列出。
            // 放在未跑填补之后：填补按 targets 索引，混进跳过项会越界。
            failed.append(contentsOf: skippedMinOS)
            updateAllTask = nil
            updateAllCurrent = nil
            updateAllIndex = 0
            updateAllTotal = 0
            activeID = nil
            if failed.isEmpty {
                updateAllSummary = L("全部更新完成：%d 个已更新。", succeeded)
            } else {
                let shown = failed.prefix(5).map { "\($0.name)：\($0.error)" }
                var list = shown.joined(separator: "、")
                if failed.count > 5 {
                    list += "、" + L("等 %d 个", failed.count - 5)
                }
                updateAllSummary = L("全部更新完成：成功 %d 个，失败 %d 个。失败：%@", succeeded, failed.count, list)
            }
            showingUpdateAllSummary = true
        }
    }

    /// F3 (0.9.154): stop the update-all run — cancel the batch Task
    /// (the loop stops after the current item) and the running download
    /// / install itself (the batch-install Cancel button 同款）.
    /// F-1 (0.9.163): no `downloader.cancel()` here any more — the
    /// batch Task is itself the download's waiter, so cancelling it
    /// settles its own request through `onCancel`; a blanket cancel
    /// would kill a single download the user queued ahead of the batch.
    private func cancelUpdateAll() {
        updateAllTask?.cancel()
        engine.cancelOneClick()
    }

    /// Download the app's IPA like `startInstall`, but hand it to the
    /// enterprise certificate page instead of an Apple ID install.
    /// v63 改道（源导入卡死修复）：下载 → 导入 custom 槽 → 校验
    /// 这三步不动；成功后不再调 engine.runEnterpriseCertInstall
    ///（那路前置失败只写 Engine 日志、企业页全程无反馈，且从
    /// 不写 selectedIPA，签名段拿不到刚导入的 App——“空白卡死”
    /// 的成因链），改为把文件写进 certWorkspace.selectedIPA，
    /// 企业页 onChange 接住 → select() → 签名表单预填该 App，
    /// 用户点“开始签名”走企业页自己的本地安装（进度在企业页）。
    /// dismiss 前的 Task.isCancelled 守卫：用户若已在下载完成前
    /// 取消（行内取消按钮；F2 前是离开页面取消，F2 后离开不再
    /// 取消），不 dismiss——否则会多 pop 一层（次要竞态，顺手堵上）。
    private func startCertInstall(_ app: AltApp) {
        guard states[app.id] == nil, let url = app.downloadLink else { return }
        states[app.id] = .queued
        certFailedIDs.remove(app.id)
        let expectedName = Engine.importFileName(for: url)
        // B-2 (0.9.167)：startInstall 同款——最低 iOS 不符下载前直接拒，
        // 不下完整 IPA、不弹蜂窝确认；失败文案与 runOneClick 的同款。
        if let minOS = app.minOSVersion, !minOS.isEmpty,
           !SideStoreDownloader.runs(on: ProcessInfo.processInfo.operatingSystemVersion, from: minOS, to: nil) {
            states[app.id] = .failed(L("%@ needs iOS %@ or later. This iPhone runs iOS %@.",
                                        app.name ?? expectedName, minOS, engine.osVersionText))
            return
        }
        downloadTasks[app.id] = Task {
            do {
                // F-G (0.9.156): 同 startInstall——蜂窝下先确认再下载。
                guard await engine.confirmCellularDownload(size: app.size.map(Int64.init),
                                                           what: app.name ?? expectedName) else {
                    states[app.id] = nil
                    certFailedIDs.remove(app.id)
                    return
                }
                let file = try await downloader.download(from: url)
                // F-1 (0.9.163): startInstall 同款——排队的下载落地时若
                // 有安装在跑，先等它结束再导入，否则 B3 拒掉导入并删掉
                // 刚下好的文件。
                while engine.isRunning, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                }
                guard !Task.isCancelled else {
                    states[app.id] = nil
                    return
                }
                _ = await engine.importCustomIPA(from: file)
                guard engine.lastError == nil,
                      let entry = IPALibrary.customImport(),
                      entry.url.lastPathComponent == expectedName
                else {
                    throw NSError(domain: "SourceAppsView", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey:
                                                engine.lastError ?? L("Import failed")])
                }
                guard !Task.isCancelled else {
                    states[app.id] = nil
                    return
                }
                // F2 (0.9.153): the download outlived the page, so say it
                // landed — the enterprise form it hands to is on another tab.
                postDownloadNotification(appName: app.name ?? expectedName)
                certWorkspace.selectedIPA = entry.url
                // U-UI：企业页已搬进设置——交完 IPA 还要举手让 RootView
                // 切到设置 tab 并打开企业证书页，否则用户留在源页看不到表单。
                await MainActor.run { certWorkspace.openEnterpriseSign = true }
                states[app.id] = nil
                dismiss()
            } catch {
                // B-C2：同上；取消也不污染重试分流（certFailedIDs）。
                // F-1 (0.9.163)：取消一条排队的下载只结算它自己的
                // continuation（URLError .cancelled，Task 本身没取消）
                // ——同样静默。
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    states[app.id] = nil
                    certFailedIDs.remove(app.id)
                    return
                }
                states[app.id] = .failed(error.localizedDescription)
                certFailedIDs.insert(app.id)
            }
        }
    }
}

/// The blue Download capsule on a source app's row, shared by the
/// Apple-ID install button and the install-menu label.
private struct DownloadPill: View {
    var body: some View {
        Text(L("Download"))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.topBarFill))
    }
}

// MARK: - App sources (upstream 2.2.0)

// Upstream 2.2.0 Sources feature page, renamed: the fork already has a
// `SourcesView` (the Sources tab), so this one is `AppSourcesView`.

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
    /// F-2 (0.9.168): the lowest iOS this build runs on, as the source
    /// lists it (`AltSourceListing.Version.minOSVersion` 同款字段）.
    /// Optional: sources that don't list it decode to nil, and the
    /// version line just omits the iOS part.
    let minOSVersion: String?

    var id: String { version + "|" + downloadURL.absoluteString }

    init(version: String, date: Date?, notes: String?, downloadURL: URL, size: Int64?, minOSVersion: String? = nil) {
        self.version = version
        self.date = date
        self.notes = notes
        self.downloadURL = downloadURL
        self.size = size
        self.minOSVersion = minOSVersion
    }

    private enum CodingKeys: String, CodingKey {
        case version, date, localizedDescription, downloadURL, size, minOSVersion
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
        minOSVersion = try? c.decode(String.self, forKey: .minOSVersion)
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
    /// The disabled sources, by absolute URL string (F1, 0.9.152): kept
    /// here so rows and listings redraw when one flips; the truth lives
    /// in `UnifiedSourceList`.
    @Published private(set) var disabled: Set<String> = UnifiedSourceList.disabledURLs()
    @Published private(set) var isAdding = false
    /// Why the last add failed, shown under the field.
    @Published var addError: String?
    /// F-D (0.9.156): the Sources tab's badge — how many installed apps
    /// have an update. The tab reads this; it is recounted after every
    /// fetch and whenever the installed list changes.
    @Published private(set) var availableUpdateCount = 0

    /// Sources every copy of SideInstaller starts with, listed first. They
    /// can't be removed: FrizzleM's own, with SideInstaller in it, kept up to
    /// date with each release by the update-altsource workflow. The URL lives
    /// in `UnifiedSourceList`, the one list both source pages share.
    static let builtIn: [URL] = [UnifiedSourceList.builtInURL]

    init() {
        urls = UnifiedSourceList.load()
        disabled = UnifiedSourceList.disabledURLs()
    }

    /// Re-read the unified list (the other page saved it): keep the fetch
    /// states of sources still listed, drop the rest. Called when the page
    /// appears and when the list changes.
    func syncURLs() {
        urls = UnifiedSourceList.load()
        disabled = UnifiedSourceList.disabledURLs()
        states = states.filter { urls.contains($0.key) }
    }

    func isDisabled(_ url: URL) -> Bool { disabled.contains(url.absoluteString) }

    /// Flip one source's disabled state (F1, 0.9.152): persisted in
    /// `UnifiedSourceList`, so the other page picks it up on `didChange`.
    func setDisabled(_ url: URL, _ disabled: Bool) {
        UnifiedSourceList.setDisabled(url, disabled: disabled)
        self.disabled = UnifiedSourceList.disabledURLs()
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
    /// both offer is listed under each. F1 (0.9.152): disabled sources
    /// contribute nothing here, so their apps never count toward updates.
    func listings(installed apps: [SideloadedAppStatus]) -> [SourceListing] {
        urls.filter { !isDisabled($0) }.flatMap { url -> [SourceListing] in
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

    /// F-D (0.9.156): recomputes `availableUpdateCount` for `apps`.
    func recountUpdates(installed apps: [SideloadedAppStatus]) {
        availableUpdateCount = updateCount(installed: apps)
    }

    /// B-2 (0.9.157): adopt what the fork store just fetched, for the
    /// badge. The Sources tab runs on `SourceStore`, not this manager —
    /// its fetches never touch `states`, so recounting here alone would
    /// recompute the same stale count. The fork store's disk cache holds
    /// the same JSON this manager decodes from the network, so a fresh
    /// (15-minute) cached document is decoded as an `AppSource` and takes
    /// its row's place; a stale or missing cache leaves the row alone.
    /// Called from RootView when the fork store posts new content.
    func adoptCachedSources() {
        for url in urls where !isDisabled(url) {
            guard let alt = SourceStore.cachedModel(for: url),
                  let source = Self.appSource(from: alt) else { continue }
            states[url] = .loaded(source)
        }
    }

    /// The fork store's `AltSource` as this manager's `AppSource`: the
    /// same AltStore JSON, re-decoded through this manager's tolerant
    /// decoder (an app that fails to decode is dropped, exactly as on
    /// the network path).
    private static func appSource(from alt: AltSource) -> AppSource? {
        guard let data = try? JSONEncoder().encode(alt) else { return nil }
        return try? JSONDecoder().decode(AppSource.self, from: data)
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
        // F-D (0.9.156): the badge follows the launch fetch.
        recountUpdates(installed: apps.entries)
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
        UnifiedSourceList.save(urls)
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
    /// F1 (0.9.152): disabled sources are never fetched — they keep their
    /// last state and their disk cache, and `listings` skips them.
    func refresh() async {
        let all = urls.filter { !isDisabled($0) }
        guard !all.isEmpty else { return }
        // B2 (0.9.152): snapshot the states before this refresh marks the
        // unfetched ones .loading, so a cancelled fetch can put each row
        // back exactly where it was instead of leaving a fake error.
        let before = states
        for url in all where states[url] == nil { states[url] = .loading }
        await withTaskGroup(of: (URL, SourceState?).self) { group in
            for url in all {
                group.addTask {
                    do { return (url, .loaded(try await Self.fetch(url))) }
                    // B2 (0.9.152): a cancelled fetch is not an error
                    // (SourceStore.fetch 同款): nil means "restore the
                    // row's pre-refresh state" in the loop below. Both
                    // shapes of cancel are caught — URLSession throws
                    // URLError(.cancelled), not CancellationError.
                    catch is CancellationError { return (url, nil) }
                    catch let error as URLError where error.code == .cancelled { return (url, nil) }
                    catch { return (url, .failed(await Self.describe(error))) }
                }
            }
            for await (url, state) in group where urls.contains(url) {
                guard let state else { states[url] = before[url]; continue }
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
        case tooLarge
    }

    /// B3 (0.9.153): same 10MB body cap as `SourceStore.fetchSourceDocument`
    /// (C-6) — a declared length over the cap, or a body that arrives over
    /// it, is refused before decoding.
    private static let sourceBodyCap = 10 * 1024 * 1024

    nonisolated static func fetch(_ url: URL) async throws -> AppSource {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.status(http.statusCode)
        }
        if response.expectedContentLength > Int64(Self.sourceBodyCap) {
            throw FetchError.tooLarge
        }
        if data.count > Self.sourceBodyCap {
            throw FetchError.tooLarge
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
        case FetchError.tooLarge:
            return L("Source is too large")
        default:
            return L("Couldn't reach the source: %@", error.localizedDescription)
        }
    }

    // MARK: Installing

    /// Puts up the install popup for `version`, as a `sideinstaller://install`
    /// link would. On yes, the Install tab downloads, signs and installs it.
    /// F-2 (0.9.168): `startInstall` 同款最低 iOS 前置检查——详情页安装
    /// 是第三路（B-2 0.9.167 只堵了 startInstall 与 startCertInstall），
    /// 没它就得等几百 MB 下完才在 Engine 的后置守卫被拒。不符返回
    /// false、不发深链，调用方把原因告诉用户；文案与 startInstall 同款。
    @discardableResult
    func install(_ version: SourceVersion, of app: SourceApp) -> Bool {
        if let minOS = version.minOSVersion, !minOS.isEmpty,
           !SideStoreDownloader.runs(on: ProcessInfo.processInfo.operatingSystemVersion, from: minOS, to: nil) {
            Engine.shared.log("Sources: \(app.name) \(version.version) needs iOS \(minOS)+ — this iPhone runs iOS \(Engine.shared.osVersionText).")
            return false
        }
        var components = URLComponents()
        components.scheme = DeepLink.scheme
        components.host = "install"
        components.queryItems = [URLQueryItem(name: "url", value: version.downloadURL.absoluteString)]
        guard let link = components.url else { return false }
        Engine.shared.log("Sources: \(app.name) \(version.version) from \(version.downloadURL.absoluteString).")
        Engine.shared.receiveLink(link)
        return true
    }
}

// MARK: - Sources page

/// The Sources page: add AltStore-format sources, browse their apps, see which
/// installed ones have updates, and install from them without fetching the
/// IPA by hand.
struct AppSourcesView: View {
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
    /// The import result, shown in an alert (F2, 0.9.152).
    @State private var importSummary: String?

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
        .refreshable {
            await manager.refresh()
            // F-D (0.9.156): the badge follows a manual refresh too.
            manager.recountUpdates(installed: appsManager.entries)
        }
        .toolbar {
            // F2 (0.9.152): export the whole source list as text, and import
            // the same format back from the clipboard.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        shareSources()
                    } label: {
                        Label(L("Export sources"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(manager.urls.isEmpty)
                    Button {
                        importFromClipboard()
                    } label: {
                        Label(L("Import sources"), systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(L("Source options"))
            }
            settingsToolbarItem(isPresented: $showSettings)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .alert(L("Import sources"), isPresented: Binding(
            get: { importSummary != nil },
            set: { if !$0 { importSummary = nil } }
        )) {
            Button(L("OK"), role: .cancel) { importSummary = nil }
        } message: {
            if let importSummary { Text(importSummary) }
        }
        .task {
            manager.syncURLs()
            appsManager.autoLoad()
            await manager.refreshMissing()
            // F-D (0.9.156): the badge follows the page-open fetch.
            manager.recountUpdates(installed: appsManager.entries)
        }
        .onReceive(NotificationCenter.default.publisher(for: UnifiedSourceList.didChange)) { _ in
            Task { @MainActor in manager.syncURLs() }
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

    /// The source list as text, one URL per line — the export format the
    /// import reads back (F2, 0.9.152).
    private var exportText: String {
        manager.urls.map(\.absoluteString).joined(separator: "\n")
    }

    /// Shares the exported list with the system sheet (FilesTabView.shareFile
    /// 同款：UIActivityViewController + topViewController, iPad anchor centred).
    private func shareSources() {
        DispatchQueue.main.async {
            let sheet = UIActivityViewController(activityItems: [exportText], applicationActivities: nil)
            guard let top = UIApplication.shared.topViewController else { return }
            sheet.popoverPresentationController?.sourceView = top.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                                                     width: 0, height: 0)
            top.present(sheet, animated: true)
        }
    }

    /// Imports sources from the clipboard, one URL per line (F2, 0.9.152):
    /// each line goes through the same add path as a pasted link, so a bad
    /// line or a duplicate is counted, not fatal.
    private func importFromClipboard() {
        let lines = (UIPasteboard.general.string ?? "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            importSummary = L("The clipboard has no source list to import.")
            return
        }
        Task { @MainActor in
            var added = 0, skipped = 0, failed = 0
            for line in lines {
                guard let url = SourcesManager.sourceLink(line) else { failed += 1; continue }
                if manager.urls.contains(url) { skipped += 1; continue }
                if await manager.add(line) { added += 1 } else { failed += 1 }
            }
            importSummary = L("Imported %d, already added %d, failed %d.", added, skipped, failed)
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
            // F1 (0.9.152): per-source enable switch — off means never
            // fetched and never counted toward updates, without deleting it.
            Toggle(L("Enabled"), isOn: Binding(
                get: { !manager.isDisabled(url) },
                set: { manager.setDisabled(url, !$0) }
            ))
            .labelsHidden()
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
        .opacity(manager.isDisabled(url) ? 0.5 : 1)
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
    /// F-2/F-3 (0.9.168)：详情页的操作提示——最低 iOS 前置拦截的
    /// 原因，或复制直链后的“已复制”；静默不做事是最差的反馈。
    @State private var notice: String?

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
                if let confirm { install(confirm) }
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
        .alert(app.name, isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button(L("OK"), role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
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
            StatusDot(text: statusText, color: (listing.hasUpdate || isDowngrade) ? Theme.warning : Theme.positive,
                      idle: listing.installedVersion == nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// B-3 (0.9.165)：源最新版比已装旧（SourceListing.isDowngrade 同款）。
    private var isDowngrade: Bool {
        guard let latest = app.latest else { return false }
        return listing.isDowngrade(to: latest)
    }

    private var statusText: String {
        let latest = app.latest?.version ?? ""
        guard let installed = listing.installedVersion else {
            return L("Version %@ · from %@", latest, listing.sourceName)
        }
        if listing.hasUpdate {
            return L("%@ installed · %@ available", installed, latest)
        }
        // B-3 (0.9.165)：源比已装旧——不再写死「up to date」，行文案
        // 就是 0.9.164 的版本对比 tag；安装本身仍走降级确认，不动。
        if isDowngrade {
            return czfVersionComparisonTag(fileVersion: latest, installedVersion: installed).text
        }
        return L("%@ installed · up to date", installed)
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
                        install(latest)
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

    /// F-2 (0.9.168): the detail page's install entry — both the main
    /// button and the downgrade confirm go through here. The minOS
    /// pre-check lives in `manager.install`; a refusal shows the same
    /// reason `startInstall` writes on its row instead of silently
    /// doing nothing. (`minOSVersion` is non-nil whenever the check
    /// can refuse, so the `?? ""` never shows.)
    private func install(_ version: SourceVersion) {
        guard !manager.install(version, of: app) else { return }
        notice = L("%@ needs iOS %@ or later. This iPhone runs iOS %@.",
                   app.name, version.minOSVersion ?? "", Engine.shared.osVersionText)
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
                            // F-3 (0.9.168): copy this version's IPA link —
                            // the source row's Copy link 同款（源 URL 换成
                            // 版本直链），拷完提示已复制，不静默。
                            Button {
                                UIPasteboard.general.string = version.downloadURL.absoluteString
                                notice = L("Copied")
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                            .controlSize(.small)
                            .accessibilityLabel(L("Copy link"))
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

    /// "16 Nov 2026 · 10.4 MB · iOS 18+", with what the source gives.
    /// F-2 (0.9.168): the lowest iOS joins the line when the source
    /// lists it — one place, so the newest-version header and every
    /// history row show it. Sources without the field omit the part.
    private func versionMeta(_ version: SourceVersion) -> String {
        var parts: [String] = []
        if let date = version.date {
            parts.append(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(Localizer.locale)))
        }
        if let size = version.size, size > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        if let minOS = version.minOSVersion, !minOS.isEmpty {
            parts.append("iOS \(minOS)+")
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
