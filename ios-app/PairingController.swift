import Foundation
import Darwin
import SideInstallerFFI

/// Drives the RPPairing host: requests Local Network, keeps the app alive while
/// the user approves the PIN in Settings, advertises the service over Bonjour,
/// and runs `si_pairing_run_host` off the main thread, logging into `Engine`.
///
/// Pairs either this iPhone (the Install and Pairing tabs) or another iPhone on
/// the same network (Side by Side). Only one host runs at a time.
@MainActor
final class PairingController {

    static let shared = PairingController()

    private let hostName = "SideInstaller"
    private let hostModel = "Mac17,7"   // device sees a Mac-like pairing host
    private let bindAddress = "0.0.0.0"

    /// The host name Side by Side pairs another iPhone with, shown on it as
    /// “Pair with …”.
    ///
    /// A new host's identifier is derived from its name, so a different name
    /// keeps Side by Side's record on their iPhone apart from the one their own
    /// SideInstaller pairs itself with. With the same name, pairing them again
    /// would replace that record, and the pairing files their SideInstaller put
    /// into SideStore and the rest would stop working. Never change or localize
    /// it: records already on other iPhones were paired under it.
    nonisolated static let peerHostName = "SideInstaller (Side by Side)"

    private var netService: NetService?
    private let localNetwork = LocalNetworkAuthorization()
    private let keepAlive = KeepAlive()

    private var running = false
    /// The run in progress; nil when `running` is false.
    private var current: HostRun?

    /// This host's `altIRK`, persisted across pairings.
    ///
    /// The Bonjour `authTag` is derived from it, which lets a previously paired
    /// iPhone recognize this host. The Rust side returns it after each
    /// successful pairing, and it's passed back in on the next run.
    ///
    /// `nonisolated` so the background completion can store it; it only touches
    /// `UserDefaults`, which is thread-safe.
    private nonisolated static let altIRKKey = "rpPairingHostAltIRK"
    private nonisolated static var storedAltIRK: String {
        get { UserDefaults.standard.string(forKey: altIRKKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: altIRKKey) }
    }

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

    /// The iPhone a run paired with.
    struct PairedDevice {
        /// Where the run wrote its pairing file.
        let path: String
        let deviceName: String
        let deviceModel: String
    }

    /// One run of the host. Main-actor bound like the controller: the
    /// background completion only carries it back to the main queue.
    @MainActor
    private final class HostRun {
        let name: String
        let outPath: String
        let altIRK: String
        /// Side by Side's PIN display; nil when pairing this iPhone.
        let peerPIN: (@MainActor (String) -> Void)?
        /// Resolved when the run ends, or when it's cancelled; nil for `start()`.
        var continuation: CheckedContinuation<PairedDevice, Error>?
        /// The port the host listens on, once it's known.
        var port: UInt16?
        /// Set by `cancelPeer`, so the run stops advertising and its end isn't
        /// reported as a failure.
        var cancelled = false

        var isThisDevice: Bool { peerPIN == nil }

        init(name: String, outPath: String, altIRK: String,
             peerPIN: (@MainActor (String) -> Void)?,
             continuation: CheckedContinuation<PairedDevice, Error>?) {
            self.name = name
            self.outPath = outPath
            self.altIRK = altIRK
            self.peerPIN = peerPIN
            self.continuation = continuation
        }
    }

    /// Where the pairing file is written, and read back from; see `PrivateStore`.
    nonisolated static func pairingFilePath() -> String {
        PrivateStore.pairingFile.path
    }

    /// Start the host and resolve with the pairing-file path, or throw.
    func startAndWait() async throws -> String {
        if running { throw PairingError.busy }
        let paired = try await withCheckedThrowingContinuation { cont in
            begin(thisDeviceRun(continuation: cont))
        }
        return paired.path
    }

    /// Unblock the awaited path; the host thread ends when the FFI call returns.
    /// Leaves a Side by Side run alone.
    func softCancel() {
        guard let run = current, run.isThisDevice else { return }
        resolve(run, .failure(CancellationError()))
    }

    func start() {
        begin(thisDeviceRun(continuation: nil))
    }

    private func thisDeviceRun(continuation: CheckedContinuation<PairedDevice, Error>?) -> HostRun {
        HostRun(name: hostName, outPath: Self.pairingFilePath(), altIRK: Self.storedAltIRK,
                peerPIN: nil, continuation: continuation)
    }

    // MARK: Pairing another iPhone (Side by Side)

    /// Advertise a host that another iPhone on this network pairs with from its
    /// Settings, and resolve once it has, with its pairing file at `outPath`.
    ///
    /// Touches nothing that belongs to this iPhone's own pairing: not its
    /// pairing file, its stored `altIRK`, or the Install tab's status and PIN.
    /// The PIN goes to `onPIN` instead. An existing file at `outPath` lends its
    /// key pair and identifier, as for this iPhone's own file.
    func pairPeer(outPath: String,
                  onPIN: @escaping @MainActor (String) -> Void) async throws -> PairedDevice {
        if running { throw PairingError.busy }
        return try await withCheckedThrowingContinuation { cont in
            // No stored altIRK: a fresh one each run, as StikPair does.
            begin(HostRun(name: Self.peerHostName, outPath: outPath, altIRK: "",
                          peerPIN: onPIN, continuation: cont))
        }
    }

    /// Stop a `pairPeer` run: resolve it as cancelled, stop advertising, and end
    /// the host if it's still waiting for their iPhone to connect.
    ///
    /// A host their iPhone has already connected to runs until that iPhone
    /// finishes or gives up, since nothing interrupts the FFI call.
    func cancelPeer() {
        guard let run = current, !run.isThisDevice, !run.cancelled else { return }
        run.cancelled = true
        resolve(run, .failure(CancellationError()))
        stopAdvertising()
        if let port = run.port { Self.wakeHost(port: port) }
    }

    // MARK: Running the host

    private func begin(_ run: HostRun) {
        guard !running else {
            engine.log("Pairing already running.")
            resolve(run, .failure(PairingError.busy))
            return
        }
        running = true
        current = run
        if run.isThisDevice { engine.pairingStatus = L("requesting Local Network…") }
        engine.log("RPPairing: requesting Local Network permission…")

        Task {
            guard await localNetwork.request() else {
                engine.log("RPPairing: Local Network permission DENIED. Enable it in Settings › SideInstaller › Local Network, then retry.")
                if run.isThisDevice { engine.pairingStatus = L("Local Network denied") }
                end(run)
                resolve(run, .failure(PairingError.localNetworkDenied))
                return
            }
            // Side by Side may have been cancelled while the prompt was up.
            guard !run.cancelled else {
                end(run)
                return
            }
            engine.log("RPPairing: Local Network granted. Starting keep-alive (silent audio).")
            keepAlive.startAudio()
            if run.isThisDevice { engine.pairingStatus = L("waiting for device…") }
            runHost(run)
        }
    }

    private func runHost(_ run: HostRun) {
        let bind = bindAddress
        let name = run.name
        let model = hostModel
        let outPath = run.outPath
        let altIRK = run.altIRK
        // Only this iPhone's host keeps its altIRK; see `storedAltIRK`.
        let keepsAltIRK = run.isThisDevice
        // Retained as the C callbacks' `ctx`, released after the run.
        // `nonisolated(unsafe)`: the raw pointer isn't `Sendable`, but only the
        // closure below uses it, and it's released once.
        nonisolated(unsafe) let ctx = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())

        engine.log("RPPairing: invoking si_pairing_run_host (out=\(outPath))")

        DispatchQueue.global(qos: .userInitiated).async {
            var result = SIPairResult()
            let rc = bind.withCString { bindC in
                name.withCString { nameC in
                    model.withCString { modelC in
                        outPath.withCString { outC in
                            altIRK.withCString { irkC in
                                si_pairing_run_host(
                                    bindC, 0, nameC, modelC, outC, irkC,
                                    pairReadyCallback, pairPinCallback, ctx, &result)
                            }
                        }
                    }
                }
            }

            let outcome: PairOutcome
            if rc == 0 {
                // Save the altIRK the run used (stored or newly generated).
                let issued = cStr(result.host_alt_irk_hex)
                if keepsAltIRK, !issued.isEmpty { Self.storedAltIRK = issued }
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
                self.finish(outcome, run)
            }
        }
    }

    private enum PairOutcome {
        case success(name: String, model: String, udid: String, path: String)
        case failure(String)
    }

    /// Frees the host for the next run.
    private func end(_ run: HostRun) {
        guard current === run else { return }
        running = false
        current = nil
    }

    private func resolve(_ run: HostRun, _ result: Result<PairedDevice, Error>) {
        guard let cont = run.continuation else { return }
        run.continuation = nil
        cont.resume(with: result)
    }

    private func finish(_ outcome: PairOutcome, _ run: HostRun) {
        stopAdvertising()
        keepAlive.stopAll()
        end(run)
        if run.isThisDevice {
            finishThisDevice(outcome, run)
        } else {
            finishPeer(outcome, run)
        }
    }

    private func finishThisDevice(_ outcome: PairOutcome, _ run: HostRun) {
        engine.pairingPIN = nil

        switch outcome {
        case let .success(name, model, udid, path):
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            engine.log("RPPairing: SUCCESS — \(name) (\(model)) UDID \(udid)")
            engine.log("RPPairing: pairing file written to \(path) (\(size) bytes)")
            if size == 0 {
                engine.log("⚠️ pairing file is zero bytes — Connect will refuse to use it.")
                engine.pairingStatus = L("failed: empty pairing file")
                resolve(run, .failure(PairingError.zeroBytes))
            } else {
                engine.pairingFilePath = path
                // The new pairing file replaces any imported one.
                engine.clearImportedPairingMark()
                engine.pairingStatus = L("paired: %@ (%dB)", name, size)
                // The merged file is now stale; the cached lockdown record is kept.
                CompositePairingFile.invalidateMerged()
                resolve(run, .success(PairedDevice(path: path, deviceName: name, deviceModel: model)))
            }
        case let .failure(message):
            engine.log("RPPairing: FAILED — \(message)")
            engine.pairingStatus = L("failed: %@", message)
            resolve(run, .failure(PairingError.failed(message)))
        }
    }

    private func finishPeer(_ outcome: PairOutcome, _ run: HostRun) {
        switch outcome {
        case let .success(name, model, udid, path):
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            engine.log("RPPairing: SUCCESS — \(name) (\(model)) UDID \(udid)")
            engine.log("RPPairing: their pairing file written to \(path) (\(size) bytes)")
            if size == 0 {
                resolve(run, .failure(PairingError.zeroBytes))
            } else {
                resolve(run, .success(PairedDevice(path: path, deviceName: name, deviceModel: model)))
            }
        case let .failure(message):
            // A cancelled run ends with whatever the woken host failed on.
            engine.log(run.cancelled ? "RPPairing: stopped." : "RPPairing: FAILED — \(message)")
            resolve(run, .failure(PairingError.failed(message)))
        }
    }

    // MARK: Bonjour advertising

    fileprivate func startAdvertising(serviceID: String, port: Int32, txt: [String: Data]) {
        guard let run = current else { return }
        run.port = UInt16(truncatingIfNeeded: port)
        // Cancelled before the host was ready: don't advertise it, end it.
        if run.cancelled {
            if let port = run.port { Self.wakeHost(port: port) }
            return
        }
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
        if run.isThisDevice {
            engine.pairingStatus = L("advertising — open Settings › Privacy & Security › Developer Mode")
        }
    }

    fileprivate func presentPin(_ pin: String) {
        guard let run = current, !run.cancelled else { return }
        if let peerPIN = run.peerPIN {
            engine.log("RPPairing: PIN = \(pin) — type it into their iPhone (Settings → Developer Mode → Pair with \(run.name)).")
            peerPIN(pin)
            return
        }
        engine.log("RPPairing: PIN = \(pin) — confirm it on this device (Settings → Developer Mode → Pair with SideInstaller).")
        engine.pairingStatus = L("enter PIN %@ in Settings", pin)
        // Displayed as a PIN card in the UI.
        engine.pairingPIN = pin
    }

    private func stopAdvertising() {
        netService?.stop()
        netService = nil
    }

    /// Ends a host still blocked waiting for a device, by connecting to it and
    /// hanging up: the handshake then fails on the empty connection and
    /// `si_pairing_run_host` returns. The listener is bound to 0.0.0.0, so
    /// loopback reaches it.
    private nonisolated static func wakeHost(port: UInt16) {
        DispatchQueue.global(qos: .utility).async {
            let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            guard fd >= 0 else { return }
            defer { Darwin.close(fd) }
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            _ = withUnsafePointer(to: &addr) { aptr in
                aptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
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
