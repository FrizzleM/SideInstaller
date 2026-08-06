import Foundation

/// Drives the Pairing tab: generate the pairing file, export it, and write it
/// into a chosen installed app. Only UI state lives here — the shared `Engine`
/// owns the device connection and serializes the work.
@MainActor
final class PairingManager: ObservableObject {

    // Pairing file on disk, behind the status line and the Export button.
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
    /// True once a scan has completed, for the "no apps found" empty state.
    @Published private(set) var hasScanned = false
    @Published var lastError: String?
    @Published var lastSuccess: String?

    private var engine: Engine { Engine.shared }

    /// Any operation in flight, which disables the controls.
    var isBusy: Bool { isGenerating || isScanning || installingTargetID != nil }

    /// The pairing file to hand to a share sheet, when one exists on disk.
    var exportURL: URL? {
        guard pairingFileExists else { return nil }
        return URL(fileURLWithPath: PairingController.pairingFilePath())
    }

    // MARK: - Actions

    /// Re-stat the pairing file, cheap enough to call whenever the tab appears.
    func refresh() {
        let path = PairingController.pairingFilePath()
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? Int) ?? 0
        pairingFileExists = FileManager.default.fileExists(atPath: path) && size > 0
        pairingFileSize = size
        pairingFileDate = attrs?[.modificationDate] as? Date
    }

    /// Run the RPPairing host for a fresh pairing file, showing the PIN through
    /// `Engine.pairingPIN`. Drops the device link, which a re-pair invalidates.
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
                lastSuccess = L("Pairing file ready. You can export it or install it into an app below.")
            } catch is CancellationError {
                // User backed out — no error banner.
            } catch {
                lastError = message(error)
            }
            refresh()
            isGenerating = false
        }
    }

    /// Connect over the loopback tunnel and list the supported apps on device.
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
                lastSuccess = L("Pairing file installed into %@.", target.name)
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
