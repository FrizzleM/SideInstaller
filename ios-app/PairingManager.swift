import Foundation

/// Drives the "Pairing" tab — the standalone equivalent of iLoader's "Manage
/// Pairing files". It can:
///   • generate (extract) the device pairing file via the RPPairing host,
///   • export it (share sheet / Save to Files), and
///   • write it into a chosen installed app (SideStore, StikDebug, Feather, …)
///     over LocalDevVPN, the same way the install flow seeds SideStore.
///
/// All device work is delegated to the shared `Engine` (it owns the connection
/// and serializes it); this type holds only the tab's own UI state, mirroring
/// `CertManager` / `DownloadsManager`.
@MainActor
final class PairingManager: ObservableObject {

    // Pairing file on disk (drives the status line + the Export button).
    @Published private(set) var pairingFileExists = false
    @Published private(set) var pairingFileSize = 0
    @Published private(set) var pairingFileDate: Date?

    // In-flight flags.
    @Published private(set) var isGenerating = false
    @Published private(set) var isScanning = false
    /// `id` (bundle id) of the target currently being written, if any.
    @Published private(set) var installingTargetID: String?

    // Results.
    @Published private(set) var targets: [InstalledPairingTarget] = []
    /// True once a scan has completed (drives the "no apps found" empty state).
    @Published private(set) var hasScanned = false
    @Published var lastError: String?
    @Published var lastSuccess: String?

    private var engine: Engine { Engine.shared }

    /// Any device/file operation in flight — used to disable the controls.
    var isBusy: Bool { isGenerating || isScanning || installingTargetID != nil }

    /// The pairing file to hand to a share sheet, when one exists on disk.
    var exportURL: URL? {
        guard pairingFileExists else { return nil }
        return URL(fileURLWithPath: PairingController.pairingFilePath())
    }

    // MARK: - Actions

    /// Re-stat the pairing file. Cheap; safe to call each time the tab appears.
    func refresh() {
        let path = PairingController.pairingFilePath()
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? Int) ?? 0
        pairingFileExists = FileManager.default.fileExists(atPath: path) && size > 0
        pairingFileSize = size
        pairingFileDate = attrs?[.modificationDate] as? Date
    }

    /// Run the RPPairing host to extract a fresh pairing file. Surfaces the PIN
    /// through `Engine.pairingPIN` (shown by the tab) while the user pairs in
    /// Settings. A re-pair invalidates any open device link, so drop it.
    func generate() {
        guard !isBusy else { return }
        lastError = nil
        lastSuccess = nil
        isGenerating = true
        Task {
            do {
                _ = try await PairingController.shared.startAndWait()
                engine.connection.disconnect()
                targets = []
                hasScanned = false
                lastSuccess = "Pairing file ready. You can export it or install it into an app below."
            } catch is CancellationError {
                // User backed out — no error banner.
            } catch {
                lastError = message(error)
            }
            refresh()
            isGenerating = false
        }
    }

    /// Connect over LocalDevVPN and list the supported apps installed on device.
    func scan() {
        guard !isBusy else { return }
        lastError = nil
        isScanning = true
        Task {
            do {
                targets = try await engine.installedPairingTargets()
                hasScanned = true
            } catch {
                lastError = message(error)
            }
            isScanning = false
        }
    }

    /// Write the pairing file into one installed target app.
    func install(into target: InstalledPairingTarget) {
        guard !isBusy else { return }
        lastError = nil
        lastSuccess = nil
        installingTargetID = target.id
        Task {
            do {
                try await engine.installPairing(into: target)
                lastSuccess = "Pairing file installed into \(target.name)."
            } catch {
                lastError = message(error)
            }
            installingTargetID = nil
        }
    }

    // MARK: - Helpers

    /// Human-readable pairing-file size, e.g. "2 KB".
    var pairingFileSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(pairingFileSize), countStyle: .file)
    }

    private func message(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}
