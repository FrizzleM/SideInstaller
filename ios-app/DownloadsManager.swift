import Foundation

/// One IPA in Documents, as the download manager in Settings lists it.
struct DownloadedIPA: Identifiable, Equatable {
    let source: InstallSource
    let channel: ReleaseChannel
    let url: URL
    let size: Int
    let modified: Date?
    /// True when this file arrived from the Files app rather than a download.
    let isImported: Bool

    /// Stable identity: the path is unique per source and channel.
    var id: String { url.path }

    /// Channel-qualified name, e.g. "LiveContainer + SideStore (Nightly)", or
    /// the filename for a custom IPA, which the row already names.
    var displayName: String {
        guard source != .custom else { return fileName }
        var name = source.displayName
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
    /// True once `refresh()` has run, so the empty state can tell them apart.
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
                          size: $0.size, modified: $0.modified, isImported: $0.isImported)
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
            // The Install tab's button also shows the custom import.
            if item.source == .custom { engine.refreshCustomIPA() }
            engine.log("Downloads: deleted \(item.fileName) (\(item.sizeText)).")
        } catch {
            lastError = L("Couldn't delete %@: %@", item.fileName, error.localizedDescription)
            engine.log("⛔️ Downloads: \(lastError ?? "delete failed")")
        }
        deletingID = nil
        refresh()
    }
}
