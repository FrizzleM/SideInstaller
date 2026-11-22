import SwiftUI

/// The App Sources list: every source the user added, each leading to its
/// apps. Reached from the Install card on the main screen.
struct SourcesView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @StateObject private var store = SourceStore()

    @State private var showAddAlert = false
    @State private var newSourceURL = ""
    @State private var addFailed = false

    var body: some View {
        List {
            if store.sources.isEmpty {
                Text(L("No sources yet. Tap + to add one."))
                    .foregroundStyle(.secondary)
            }
            ForEach(store.sources) { source in
                NavigationLink {
                    SourceAppsView(store: store, sourceURL: source.url)
                } label: {
                    sourceRow(source)
                }
            }
            .onDelete { store.removeSource(at: $0) }
        }
        .navigationTitle(L("App Sources"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddAlert = true
                } label: {
                    Image(systemName: "plus")
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
                ForEach(source.apps, id: \.id) { app in
                    appRow(app)
                }
            }
        }
        .navigationTitle(source?.displayName ?? L("App Sources"))
        .refreshable { await store.fetch(sourceURL, force: true) }
        .task { await store.fetch(sourceURL) }
        .onDisappear {
            downloadTask?.cancel()
            downloader.cancel()
        }
    }

    /// One app: icon, name, version and size, its subtitle, and the Install
    /// button (or the download's progress / failure in its place).
    private func appRow(_ app: AltApp) -> some View {
        HStack(spacing: 12) {
            appIcon(app.iconLink)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name ?? "")
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let version = app.version, !version.isEmpty {
                        Text("v\(version)")
                    }
                    if let size = app.sizeText {
                        Text(size)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let subtitle = app.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            installControl(app)
        }
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
                    HStack(spacing: 3) {
                        Text(L("Install"))
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(activeID != nil || engine.isRunning)
            } else {
                Button(L("Install")) { startInstall(app) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
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
        .frame(width: 52, height: 52)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
