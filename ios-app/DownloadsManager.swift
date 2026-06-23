import Foundation

/// One IPA the app has downloaded into Documents, ready to be (re)deleted from
/// the Downloads tab. Each maps 1:1 to an `InstallSource`, whose `fileName` is
/// the on-disk name the downloader writes to.
struct DownloadedIPA: Identifiable, Equatable {
    let source: InstallSource
    let url: URL
    let size: Int
    let modified: Date?

    /// Stable identity for SwiftUI — the file path is unique per source.
    var id: String { url.path }

    /// Full source name, e.g. "LiveContainer + SideStore".
    var displayName: String { source.displayName }

    /// The on-disk filename, e.g. "SideStore.ipa".
    var fileName: String { url.lastPathComponent }

    /// Human-readable size, e.g. "42.3 MB".
    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

/// Lists and deletes the release IPAs the app has downloaded into its Documents
/// directory. Pure file-system work — no FFI, no network, no Apple sign-in — so,
/// unlike `CertManager`, every operation is cheap and runs inline on the main
/// thread.
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

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Total bytes across every downloaded IPA — shown as a header summary.
    var totalSize: Int { downloads.reduce(0) { $0 + $1.size } }

    var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    // MARK: - Actions

    /// Re-scan Documents for every known IPA. Safe to call repeatedly (e.g. each
    /// time the tab appears) — it just rebuilds the list from disk.
    @MainActor
    func refresh() {
        let fm = FileManager.default
        var found: [DownloadedIPA] = []
        for source in InstallSource.allCases {
            let url = documentsDir.appendingPathComponent(source.fileName)
            guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { continue }
            let size = (attrs[.size] as? Int) ?? 0
            let modified = attrs[.modificationDate] as? Date
            found.append(DownloadedIPA(source: source, url: url, size: size, modified: modified))
        }
        downloads = found
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
            // Keep the install pipeline honest: if it had cached this exact file,
            // forget it so "Download" re-fetches rather than skipping.
            if engine.downloadedIPAPath == item.url.path {
                engine.downloadedIPAPath = nil
            }
            engine.log("Downloads: deleted \(item.fileName) (\(item.sizeText)).")
        } catch {
            lastError = "Couldn't delete \(item.fileName): \(error.localizedDescription)"
            engine.log("⛔️ Downloads: \(lastError ?? "delete failed")")
        }
        deletingID = nil
        refresh()
    }
}
