import Foundation
import SideInstallerFFI

/// Drives the RPPairing host (the make-or-break #1 flow). Requests Local
/// Network, keeps the app alive (silent audio) so the listener survives while
/// the user approves the Developer Mode PIN in Settings, advertises the pairing
/// service over Bonjour (NetService — only Local Network needed, no multicast
/// entitlement), runs `si_pairing_run_host` off the main thread, and reports
/// every step into the shared `Engine`.
///
/// Structure ported from StephenDev0/StikPair's PairingController, simplified
/// to keep-alive only (drops the iOS-26 BGContinuedProcessingTask so the
/// deployment floor stays at 17.4).
@MainActor
final class PairingController {

    static let shared = PairingController()

    private let hostName = "SideInstaller"
    private let hostModel = "Mac17,7"   // device sees a Mac-like pairing host
    private let bindAddress = "0.0.0.0"

    private var netService: NetService?
    private let localNetwork = LocalNetworkAuthorization()
    private let keepAlive = KeepAlive()

    private var running = false

    /// Resolved when an awaited (`startAndWait`) pairing finishes. Nil for the
    /// fire-and-forget `start()` path used by the Advanced section.
    private var pairContinuation: CheckedContinuation<String, Error>?

    private var engine: Engine { Engine.shared }

    private init() {}

    /// Errors surfaced by the awaitable pairing API.
    enum PairingError: LocalizedError {
        case busy
        case localNetworkDenied
        case zeroBytes
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .busy:
                return L("Pairing is already in progress.")
            case .localNetworkDenied:
                return L("Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.")
            case .zeroBytes:
                return L("Pairing produced an empty file. Make sure you approved the pairing request, then try again.")
            case let .failed(message):
                return message
            }
        }
    }

    /// Pairing file destination (also read back when writing into SideStore).
    nonisolated static func pairingFilePath() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rp_pairing_file.plist").path
    }

    /// Awaitable pairing for the one-click orchestrator: starts the host and
    /// resolves with the pairing-file path on success, or throws on failure.
    func startAndWait() async throws -> String {
        if running { throw PairingError.busy }
        return try await withCheckedThrowingContinuation { cont in
            pairContinuation = cont
            start()
        }
    }

    /// Best-effort cancel for the awaited path: unblocks the orchestrator. The
    /// underlying host thread ends when `si_pairing_run_host` returns; `finish`
    /// then no-ops on the (already-cleared) continuation.
    func softCancel() {
        resolve(.failure(CancellationError()))
    }

    private func resolve(_ result: Result<String, Error>) {
        guard let cont = pairContinuation else { return }
        pairContinuation = nil
        cont.resume(with: result)
    }

    func start() {
        guard !running else {
            engine.log("Pairing already running.")
            return
        }
        running = true
        engine.pairingStatus = L("requesting Local Network…")
        engine.log("RPPairing: requesting Local Network permission…")

        Task {
            guard await localNetwork.request() else {
                engine.log("RPPairing: Local Network permission DENIED. Enable it in Settings › SideInstaller › Local Network, then retry.")
                engine.pairingStatus = L("Local Network denied")
                running = false
                resolve(.failure(PairingError.localNetworkDenied))
                return
            }
            engine.log("RPPairing: Local Network granted. Starting keep-alive (silent audio).")
            keepAlive.startAudio()
            engine.pairingStatus = L("waiting for device…")
            runHost()
        }
    }

    private func runHost() {
        let bind = bindAddress
        let name = hostName
        let model = hostModel
        let outPath = Self.pairingFilePath()
        // Retained pointer handed to the C callbacks as ctx; released after run.
        let ctx = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())

        engine.log("RPPairing: invoking si_pairing_run_host (out=\(outPath))")

        DispatchQueue.global(qos: .userInitiated).async {
            var result = SIPairResult()
            let rc = bind.withCString { bindC in
                name.withCString { nameC in
                    model.withCString { modelC in
                        outPath.withCString { outC in
                            si_pairing_run_host(
                                bindC, 0, nameC, modelC, outC,
                                pairReadyCallback, pairPinCallback, ctx, &result)
                        }
                    }
                }
            }

            let outcome: PairOutcome
            if rc == 0 {
                outcome = .success(
                    name: cStr(result.device_name),
                    model: cStr(result.device_model),
                    udid: cStr(result.device_udid),
                    path: cStr(result.pairing_file_path))
            } else {
                let msg = cStr(result.error)
                outcome = .failure(msg.isEmpty ? "pairing failed (rc=\(rc))" : msg)
            }
            si_pairing_result_free(&result)
            Unmanaged<PairingController>.fromOpaque(ctx).release()

            DispatchQueue.main.async {
                self.finish(outcome)
            }
        }
    }

    private enum PairOutcome {
        case success(name: String, model: String, udid: String, path: String)
        case failure(String)
    }

    private func finish(_ outcome: PairOutcome) {
        stopAdvertising()
        keepAlive.stopAll()
        running = false
        engine.pairingPIN = nil

        switch outcome {
        case let .success(name, model, udid, path):
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            engine.log("RPPairing: SUCCESS — \(name) (\(model)) UDID \(udid)")
            engine.log("RPPairing: pairing file written to \(path) (\(size) bytes)")
            if size == 0 {
                engine.log("⚠️ pairing file is zero bytes — Connect will refuse to use it.")
                engine.pairingStatus = L("failed: empty pairing file")
                resolve(.failure(PairingError.zeroBytes))
            } else {
                engine.pairingFilePath = path
                engine.pairingStatus = L("paired: %@ (%dB)", name, size)
                resolve(.success(path))
            }
        case let .failure(message):
            engine.log("RPPairing: FAILED — \(message)")
            engine.pairingStatus = L("failed: %@", message)
            resolve(.failure(PairingError.failed(message)))
        }
    }

    // MARK: Bonjour advertising (called from the ready callback)

    fileprivate func startAdvertising(serviceID: String, port: Int32, txt: [String: Data]) {
        stopAdvertising()
        engine.log("RPPairing: advertising _remotepairing-pairable-host._tcp \(serviceID) on port \(port)")
        let service = NetService(
            domain: "",
            type: "_remotepairing-pairable-host._tcp.",
            name: serviceID,
            port: port)
        service.setTXTRecord(NetService.data(fromTXTRecord: txt))
        service.publish()
        netService = service
        engine.pairingStatus = L("advertising — open Settings › Privacy & Security › Developer Mode")
    }

    fileprivate func presentPin(_ pin: String) {
        engine.log("RPPairing: PIN = \(pin) — confirm it on this device (Settings → Developer Mode → Pair with SideInstaller).")
        engine.pairingStatus = L("enter PIN %@ in Settings", pin)
        // Surfaced as a prominent card in the one-click UI.
        engine.pairingPIN = pin
    }

    private func stopAdvertising() {
        netService?.stop()
        netService = nil
    }
}

// MARK: - C callbacks

private let pairReadyCallback: SIPairReadyCb = { ctx, serviceID, port, keys, vals, count in
    guard let ctx = ctx, let serviceID = serviceID else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let id = String(cString: serviceID)

    var txt: [String: Data] = [:]
    if let keys = keys, let vals = vals {
        for i in 0..<Int(count) {
            guard let k = keys[i], let v = vals[i] else { continue }
            txt[String(cString: k)] = Data(String(cString: v).utf8)
        }
    }
    DispatchQueue.main.async {
        controller.startAdvertising(serviceID: id, port: Int32(port), txt: txt)
    }
}

private let pairPinCallback: SIPairPinCb = { pin, ctx in
    guard let ctx = ctx, let pin = pin else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let pinString = String(cString: pin)
    DispatchQueue.main.async {
        controller.presentPin(pinString)
    }
}

private func cStr(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr = ptr else { return "" }
    return String(cString: ptr)
}
