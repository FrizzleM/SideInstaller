import Foundation

/// One IPA sitting in Documents, ready to be deleted from the download manager
/// in Settings. Either the app downloaded it, or the user copied it in through
/// the Files app — `isImported` says which, and the install treats the two
/// differently (see `Engine.download()`).
struct DownloadedIPA: Identifiable, Equatable {
    let source: InstallSource
    let channel: ReleaseChannel
    let url: URL
    let size: Int
    let modified: Date?
    /// True when this file arrived from the Files app rather than a download.
    let isImported: Bool

    /// Stable identity for SwiftUI — the file path is unique per source+channel.
    var id: String { url.path }

    /// Full source name, channel-qualified: "LiveContainer + SideStore (Nightly)".
    /// An imported file says so, because that's what explains why the install
    /// stopped downloading — the question someone asks after dropping a file in.
    /// A custom IPA is named by its file instead: "Custom .ipa — imported" would
    /// say nothing the row doesn't already say twice.
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

/// Lists and deletes the release IPAs in the app's Documents directory. Pure
/// file-system work — no FFI, no network, no Apple sign-in — so, unlike
/// `CertManager`, every operation is cheap and runs inline on the main thread.
///
/// Deleting a file the install flow had cached clears `Engine.downloadedIPAPath`
/// so the next install re-fetches it instead of pointing at a missing file.
final class DownloadsManager: ObservableObject {

    @Published private(set) var downloads: [DownloadedIPA] = []
    /// `id` of the IPA currently being deleted, if any.
    @Published private(set) var deletingID: String?
    @Published var lastError: String?
    /// True once `refresh()` has run at least once (drives the empty state).
    @Published private(set) var hasLoaded = false

    private var engine: Engine { Engine.shared }

    /// Total bytes across every downloaded IPA — shown as a header summary.
    var totalSize: Int { downloads.reduce(0) { $0 + $1.size } }

    var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    // MARK: - Actions

    /// Re-scan Documents for every recognisable IPA. Safe to call repeatedly
    /// (e.g. each time the tab appears) — it just rebuilds the list from disk.
    /// Scanning the directory, rather than probing the four filenames the
    /// downloader writes, is what makes a hand-copied `sidestore.ipa` show up
    /// here at all.
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
            // Keep the install pipeline honest: if it had cached this exact file,
            // forget it so "Download" re-fetches rather than skipping.
            if engine.downloadedIPAPath == item.url.path {
                engine.downloadedIPAPath = nil
            }
            // Deleting the custom import here has to reach the Install tab's
            // button, which is the only other place it's shown.
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
