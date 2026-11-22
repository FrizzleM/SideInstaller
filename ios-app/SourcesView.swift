import SwiftUI

/// U-UI：源/应用列表排序（照抄 FilesTabView 的 FileSort 形状；源列表只用
/// 默认/名称/最新，应用列表四项全用）。
private enum SourceSort: String, CaseIterable {
    case `default`, name, size, newest

    var label: String {
        switch self {
        case .default: return L("默认")
        case .name: return L("名称")
        case .size: return L("大小")
        case .newest: return L("最新")
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
        List {
            if store.sources.contains(where: \.isLoading) {
                Text(L("正在刷新数据中…"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let last = store.sources.compactMap(\.fetchedAt).max() {
                Text(L("最后更新：%@", last.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Localizer.locale))))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            searchBar
            if store.sources.isEmpty {
                Text(L("No sources yet. Tap + to add one."))
                    .foregroundStyle(.secondary)
            }
            ForEach(displayedSources) { source in
                NavigationLink {
                    SourceAppsView(store: store, sourceURL: source.url)
                } label: {
                    sourceRow(source)
                }
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
        .refreshable { await store.fetchAll(force: true) }
        .task { await store.fetchAll() }
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

    /// U-UI：搜索框（照抄 FilesTabView 的 fileSearchBar 灰底样式）。
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L("搜索"), text: $sourceSearchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(8)
    }

    /// One source: its icon and name, with the app count, a spinner while it
    /// loads, or its load error on the trailing side.
    private func sourceRow(_ source: LoadedSource) -> some View {
        HStack(spacing: 12) {
            sourceIcon(source.model?.iconLink)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .lineLimit(1)
                if let subtitle = source.model?.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if source.isLoading {
                ProgressView()
            } else if let error = source.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if source.model != nil {
                Text(L("%d apps", source.apps.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A source or app icon: the remote image, or a box placeholder while it
    /// loads and when there is none.
    private func sourceIcon(_ url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 44)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    @StateObject private var downloader = IPADownloader()
    /// Row states by app id; an absent entry is idle.
    @State private var states: [String: RowState] = [:]
    /// 企业路径失败过的 app id（仅 startCertInstall 的 catch 写，
    /// startInstall 的 catch 永不写）：失败行的“Try again”按它
    /// 分流——企业失败重试企业路，ID 失败重试 ID 路，不串路。
    /// 任一路成功就清掉（成功即复位，下次失败重新定性）。
    @State private var certFailedIDs: Set<String> = []
    /// The app currently downloading, if any: one download at a time, so its
    /// row can show the downloader's progress and the others stay disabled.
    @State private var activeID: String?
    @State private var downloadTask: Task<Void, Never>?
    /// U-UI：应用列表排序。
    @State private var appSort = SourceSort.default
    /// U-UI：应用列表搜索（名字含查询串，不区分大小写）。
    @State private var appSearchText = ""

    /// What one app's row is doing.
    private enum RowState: Equatable {
        case downloading
        case failed(String)
    }

    /// The source as last loaded; nil once removed elsewhere.
    private var source: LoadedSource? {
        store.sources.first { $0.url == sourceURL }
    }

    var body: some View {
        List {
            if let source {
                if source.isLoading && source.model == nil {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(L("Loading…"))
                            .foregroundStyle(.secondary)
                    }
                } else if let error = source.errorMessage, source.model == nil {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                searchBar
                ForEach(displayedApps, id: \.id) { app in
                    appRow(app)
                }
            }
        }
        .listStyle(.plain)
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
        .refreshable { await store.fetch(sourceURL, force: true) }
        .task { await store.fetch(sourceURL) }
        .onDisappear {
            downloadTask?.cancel()
            downloader.cancel()
        }
    }

    /// U-UI：截图式应用行——60pt 图标 / 名字 / “应用 - 源名（副标题）” /
    /// V版本 | 大小 | 日期 / 多行描述 / 右侧蓝色下载 pill。
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
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(metaLine(for: app))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                installControl(app)
            }
            if let description = appDescription(app), !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 4)
    }

    /// 第二行：“应用 - 源名”，副标题有就跟在括号里（截图同款）。
    private func sourceLine(for app: AltApp) -> String {
        let base = L("应用 - %@", source?.displayName ?? "")
        if let subtitle = source?.model?.subtitle, !subtitle.isEmpty {
            return base + " (\(subtitle))"
        }
        return base
    }

    /// 第三行：“V版本 | 大小 | 日期”，缺的段直接省掉（不留空竖线）。
    private func metaLine(for app: AltApp) -> String {
        var parts: [String] = []
        if let version = app.version, !version.isEmpty { parts.append("V\(version)") }
        if let size = app.sizeText { parts.append(size) }
        if let date = app.versionDate, !date.isEmpty { parts.append(date) }
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

    /// U-UI：搜索框（照抄 FilesTabView 的 fileSearchBar 灰底样式）。
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L("搜索"), text: $appSearchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(8)
    }

    /// The row's trailing control: Install, the download progress with its
    /// percentage, or a failure with a retry.
    @ViewBuilder
    private func installControl(_ app: AltApp) -> some View {
        switch states[app.id] {
        case .downloading:
            VStack(spacing: 4) {
                ProgressView(value: downloader.progress)
                    .frame(width: 72)
                Text(L("Downloading… %d%%", Int(downloader.progress * 100)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            VStack(alignment: .trailing, spacing: 4) {
                // 失败重试走原路：企业失败重试企业路（清 flag 后
                // startCertInstall 里失败会重写），ID 失败维持原样。
                Button(L("Try again")) {
                    if certFailedIDs.contains(app.id) {
                        startCertInstall(app)
                    } else {
                        startInstall(app)
                    }
                }
                .disabled(activeID != nil)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
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
                    HStack {
                        Text(L("下载"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent2))
                }
                .disabled(activeID != nil || engine.isRunning)
            } else {
                Button { startInstall(app) } label: {
                    HStack {
                        Text(L("下载"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent2))
                }
                .buttonStyle(.plain)
                .disabled(activeID != nil || engine.isRunning)
            }
        }
    }

    private func appIcon(_ url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "app")
                .foregroundStyle(.secondary)
        }
        .frame(width: 60, height: 60)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Download the app's IPA, import it as the custom IPA, then start the
    /// one-click install and pop back to the main screen to watch it run.
    private func startInstall(_ app: AltApp) {
        guard activeID == nil, let url = app.downloadLink else { return }
        activeID = app.id
        states[app.id] = .downloading
        let expectedName = Engine.importFileName(for: url)
        downloadTask = Task {
            do {
                let file = try await downloader.download(from: url)
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
                    activeID = nil
                    states[app.id] = nil
                    return
                }
                engine.installSource = .custom
                // Drop any earlier run's cached path, so the pipeline reads
                // the import from disk (its own check would skip it anyway:
                // the cached source no longer matches).
                engine.downloadedIPAPath = nil
                activeID = nil
                states[app.id] = nil
                certFailedIDs.remove(app.id)
                engine.runOneClick()
                dismiss()
            } catch {
                activeID = nil
                states[app.id] = .failed(error.localizedDescription)
            }
        }
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
    /// 手动离开（onDisappear 已取消任务），不 dismiss——否则会
    /// 多 pop 一层（次要竞态，顺手堵上）。
    private func startCertInstall(_ app: AltApp) {
        guard activeID == nil, let url = app.downloadLink else { return }
        activeID = app.id
        states[app.id] = .downloading
        certFailedIDs.remove(app.id)
        let expectedName = Engine.importFileName(for: url)
        downloadTask = Task {
            do {
                let file = try await downloader.download(from: url)
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
                    activeID = nil
                    states[app.id] = nil
                    return
                }
                certWorkspace.selectedIPA = entry.url
                // U-UI：企业页已搬进设置——交完 IPA 还要举手让 RootView
                // 切到设置 tab 并打开企业证书页，否则用户留在源页看不到表单。
                await MainActor.run { certWorkspace.openEnterpriseSign = true }
                activeID = nil
                states[app.id] = nil
                dismiss()
            } catch {
                activeID = nil
                states[app.id] = .failed(error.localizedDescription)
                certFailedIDs.insert(app.id)
            }
        }
    }
}
