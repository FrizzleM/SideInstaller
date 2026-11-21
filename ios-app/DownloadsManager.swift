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
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
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

    /// Rebuild the list from disk, scanning the directory so hand-copied files
    /// appear too. Safe to call repeatedly.
    @MainActor
    func refresh() {
        downloads = IPALibrary.scan().map {
            DownloadedIPA(source: $0.source, channel: $0.channel, url: $0.url,
                          size: $0.size, modified: $0.modified, isImported: $0.isImported,
                          version: $0.version)
        }
        hasLoaded = true
    }

    /// Delete one downloaded IPA, then refresh the list.
    @MainActor
    func delete(_ item: DownloadedIPA) {
        guard deletingID == nil else { return }
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
        } catch {
            lastError = L("Couldn't delete %@: %@", item.fileName, error.localizedDescription)
            engine.log("⛔️ Downloads: \(lastError ?? "delete failed")")
        }
        deletingID = nil
        refresh()
    }
}

/// 下载列表独立页（工具 tab 固定入口，复用 DownloadsManager）：
/// 设置页下载区同款内容（行样式照 SettingsView.downloadRow），
/// 不再只藏在设置 sheet 里；删文件前先弹确认，不直接删。
struct DownloadsListView: View {
    @StateObject private var manager = DownloadsManager()
    @State private var pendingDelete: DownloadedIPA?

    var body: some View {
        List {
            if let error = manager.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if manager.hasLoaded && manager.downloads.isEmpty {
                Text(L("No downloaded IPAs. Ones you install from the Install tab are cached here."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manager.downloads) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "shippingbox.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.brand)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(.subheadline.weight(.medium))
                            if let modified = item.modified {
                                let when = modified.formatted(
                                    Date.FormatStyle(date: .abbreviated, time: .shortened)
                                        .locale(Localizer.locale))
                                Text(item.isImported ? L("Added %@", when) : L("Downloaded %@", when))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                    .swipeActions {
                        Button(role: .destructive) {
                            pendingDelete = item
                        } label: {
                            Label(L("删除"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(L("下载"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { manager.refresh() }
        .alert(L("删除这个下载的 IPA？"), isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button(L("删除"), role: .destructive) {
                if let item = pendingDelete { manager.delete(item) }
                pendingDelete = nil
            }
            Button(L("取消"), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(L("只删文件，不影响已装的 App。"))
        }
    }
}
