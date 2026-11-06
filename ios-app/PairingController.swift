import Foundation
import SideInstallerFFI

/// Somewhere outside the app that shows this iPhone's pairing code while the
/// app is behind Settings.
@MainActor
protocol PairingCodeSurface {
    /// Pairing has begun, with the app still in front.
    func start()
    /// Settings is asking for `code`.
    func show(code: String)
    /// Pairing ended.
    func finish(paired: Bool)
}

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
    /// Files paired before `peerHostIdentifier` existed have an identifier
    /// derived from this name. A different name keeps that record on their
    /// iPhone apart from the one their own SideInstaller pairs itself with. With
    /// the same name, pairing them again would replace that record, and the
    /// pairing files their SideInstaller put into SideStore and the rest would
    /// stop working. Never change or localize it: records already on other
    /// iPhones were paired under it.
    nonisolated static let peerHostName = "SideInstaller (Side by Side)"

    /// The identifier a new Side by Side pairing file gets, made once per
    /// install.
    ///
    /// Derived from `peerHostName`, it would be the same on every SideInstaller,
    /// and their iPhone keeps one record per identifier: someone else pairing it
    /// from their own iPhone would replace this one's record, and the pairing
    /// remembered here would stop working. iLoader 2.3.5 gives each host its own
    /// for the same reason. A file already at the run's path keeps its own.
    private static let peerHostIdentifierKey = "sideBySideHostIdentifier"
    private static var peerHostIdentifier: String {
        if let stored = UserDefaults.standard.string(forKey: peerHostIdentifierKey), !stored.isEmpty {
            return stored
        }
        // Lowercase, like the identifiers derived from a name.
        let made = UUID().uuidString.lowercased()
        UserDefaults.standard.set(made, forKey: peerHostIdentifierKey)
        return made
    }

    private var netService: NetService?
    private let localNetwork = LocalNetworkAuthorization()
    private let keepAlive = KeepAlive()
    /// Shows this iPhone's pairing code over Settings: the Live Activity, or a
    /// notification in a build without the extension that draws it. One or the
    /// other, so a build that has the extension never asks to send
    /// notifications. A Side by Side code needs neither: it's typed into their
    /// iPhone, with this app in front.
    private let overSettings: PairingCodeSurface =
        PairingLiveActivity.hasExtension ? PairingLiveActivity.shared : PairingNotification.shared

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
        /// The address it connected from: its IP on this network.
        let address: String
    }

    /// One run of the host. Main-actor bound like the controller: the
    /// background completion only carries it back to the main queue.
    @MainActor
    private final class HostRun {
        let name: String
        let outPath: String
        let altIRK: String
        /// The identifier a new pairing file gets; "" derives it from `name`.
        let identifier: String
        /// Side by Side's PIN display; nil when pairing this iPhone.
        let peerPIN: (@MainActor (String) -> Void)?
        /// Resolved when the run ends, or when it's cancelled; nil for `start()`.
        var continuation: CheckedContinuation<PairedDevice, Error>?
        /// Set by `cancel(_:)`, so the run stops advertising and its end isn't
        /// reported as a failure.
        var cancelled = false
        /// Stops the Rust host whatever stage it's at (`si_pairing_cancel`).
        /// Freed with the run: the background call holds the run until
        /// `si_pairing_run_host` has returned, and only the main actor cancels.
        nonisolated(unsafe) let cancelHandle: OpaquePointer = si_pairing_cancel_new()

        var isThisDevice: Bool { peerPIN == nil }

        init(name: String, outPath: String, altIRK: String, identifier: String,
             peerPIN: (@MainActor (String) -> Void)?,
             continuation: CheckedContinuation<PairedDevice, Error>?) {
            self.name = name
            self.outPath = outPath
            self.altIRK = altIRK
            self.identifier = identifier
            self.peerPIN = peerPIN
            self.continuation = continuation
        }

        deinit { si_pairing_cancel_free(cancelHandle) }
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

    /// Stop pairing this iPhone, whatever stage it's at, so no code turns up
    /// after the run that asked for it has gone. Leaves a Side by Side run
    /// alone.
    func softCancel() {
        guard let run = current, run.isThisDevice, !run.cancelled else { return }
        cancel(run)
        overSettings.finish(paired: false)
    }

    func start() {
        begin(thisDeviceRun(continuation: nil))
    }

    private func thisDeviceRun(continuation: CheckedContinuation<PairedDevice, Error>?) -> HostRun {
        // Derived from the name, as when this iPhone first paired: its record
        // is keyed by that identifier.
        HostRun(name: hostName, outPath: Self.pairingFilePath(), altIRK: Self.storedAltIRK,
                identifier: "", peerPIN: nil, continuation: continuation)
    }

    // MARK: Pairing another iPhone (Side by Side)

    /// Advertise a host that another iPhone on this network pairs with from its
    /// Settings, and resolve once it has, with its pairing file at `outPath`.
    ///
    /// Touches nothing that belongs to this iPhone's own pairing: not its
    /// pairing file, its stored `altIRK`, or the Install tab's status and PIN.
    /// The PIN goes to `onPIN` instead. An existing file at `outPath` lends its
    /// key pair and identifier, as for this iPhone's own file.
    ///
    /// `identifier` names the record their iPhone keeps for this pairing; nil
    /// uses this install's own (`peerHostIdentifier`), so pairing them again
    /// replaces that record. A pairing handed on to an app on their iPhone
    /// (SideStore) gets one of its own, so a later pairing can't replace it.
    func pairPeer(outPath: String,
                  identifier: String? = nil,
                  onPIN: @escaping @MainActor (String) -> Void) async throws -> PairedDevice {
        if running { throw PairingError.busy }
        return try await withCheckedThrowingContinuation { cont in
            // No stored altIRK: a fresh one each run, as StikPair does.
            begin(HostRun(name: Self.peerHostName, outPath: outPath, altIRK: "",
                          identifier: identifier ?? Self.peerHostIdentifier,
                          peerPIN: onPIN, continuation: cont))
        }
    }

    /// Stop a `pairPeer` run, whatever stage it's at.
    func cancelPeer() {
        guard let run = current, !run.isThisDevice, !run.cancelled else { return }
        cancel(run)
    }

    /// Resolve `run` as cancelled, stop advertising, and stop the Rust host,
    /// whether it's waiting for an iPhone, mid-handshake or waiting for the
    /// code. `si_pairing_run_host` returns a moment later, which frees the host
    /// for the next run.
    private func cancel(_ run: HostRun) {
        run.cancelled = true
        resolve(run, .failure(CancellationError()))
        stopAdvertising()
        si_pairing_cancel(run.cancelHandle)
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
            // The run may have been cancelled while the prompt was up.
            guard !run.cancelled else {
                end(run)
                return
            }
            engine.log("RPPairing: Local Network granted. Starting keep-alive (silent audio).")
            keepAlive.startAudio()
            if run.isThisDevice {
                engine.pairingStatus = L("waiting for device…")
                // Now, while the app is still in front: an activity can't
                // start later, and nor can the system ask about notifications.
                overSettings.start()
            }
            runHost(run)
        }
    }

    private func runHost(_ run: HostRun) {
        let bind = bindAddress
        let name = run.name
        let model = hostModel
        let outPath = run.outPath
        let altIRK = run.altIRK
        let identifier = run.identifier
        // Only this iPhone's host keeps its altIRK; see `storedAltIRK`.
        let keepsAltIRK = run.isThisDevice
        // Retained as the C callbacks' `ctx`, released after the run.
        // `nonisolated(unsafe)`: the raw pointer isn't `Sendable`, but only the
        // closure below uses it, and it's released once.
        nonisolated(unsafe) let ctx = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        // Lives as long as `run`, which the closure below holds until it has
        // reported back.
        nonisolated(unsafe) let cancelHandle = run.cancelHandle

        engine.log("RPPairing: invoking si_pairing_run_host (out=\(outPath))")

        DispatchQueue.global(qos: .userInitiated).async {
            var result = SIPairResult()
            let rc = bind.withCString { bindC in
                name.withCString { nameC in
                    model.withCString { modelC in
                        outPath.withCString { outC in
                            altIRK.withCString { irkC in
                                identifier.withCString { idC in
                                    si_pairing_run_host(
                                        bindC, 0, nameC, modelC, outC, irkC, idC,
                                        pairReadyCallback, pairPinCallback, ctx,
                                        cancelHandle, &result)
                                }
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
                    path: cStr(result.pairing_file_path),
                    address: cStr(result.device_address))
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
        case success(name: String, model: String, udid: String, path: String, address: String)
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
        case let .success(name, model, udid, path, address):
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            engine.log("RPPairing: SUCCESS — \(model), UDID \(udid)")
            engine.log("RPPairing: pairing file written to \(path) (\(size) bytes)")
            if size == 0 {
                engine.log("⚠️ pairing file is zero bytes — Connect will refuse to use it.")
                engine.pairingStatus = L("failed: empty pairing file")
                overSettings.finish(paired: false)
                resolve(run, .failure(PairingError.zeroBytes))
            } else {
                engine.pairingFilePath = path
                // The new pairing file replaces any imported one.
                engine.clearImportedPairingMark()
                engine.pairingStatus = L("paired: %@ (%dB)", name, size)
                // The merged file is now stale; the cached lockdown record is kept.
                CompositePairingFile.invalidateMerged()
                overSettings.finish(paired: true)
                resolve(run, .success(PairedDevice(path: path, deviceName: name, deviceModel: model,
                                                   address: address)))
            }
        case let .failure(message):
            // A cancelled run ends with “pairing cancelled”: not a failure.
            engine.log(run.cancelled ? "RPPairing: stopped." : "RPPairing: FAILED — \(message)")
            engine.pairingStatus = L("failed: %@", message)
            overSettings.finish(paired: false)
            resolve(run, .failure(PairingError.failed(message)))
        }
    }

    private func finishPeer(_ outcome: PairOutcome, _ run: HostRun) {
        switch outcome {
        case let .success(name, model, udid, path, address):
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            engine.log("RPPairing: SUCCESS — \(model), UDID \(udid), connected from \(address)")
            engine.log("RPPairing: their pairing file written to \(path) (\(size) bytes)")
            if size == 0 {
                resolve(run, .failure(PairingError.zeroBytes))
            } else {
                resolve(run, .success(PairedDevice(path: path, deviceName: name, deviceModel: model,
                                                   address: address)))
            }
        case let .failure(message):
            // A cancelled run ends with “pairing cancelled”: not a failure.
            engine.log(run.cancelled ? "RPPairing: stopped." : "RPPairing: FAILED — \(message)")
            resolve(run, .failure(PairingError.failed(message)))
        }
    }

    // MARK: Bonjour advertising

    fileprivate func startAdvertising(serviceID: String, port: Int32, txt: [String: Data]) {
        // Cancelled before the host was ready: it's stopping, so don't
        // advertise it.
        guard let run = current, !run.cancelled else { return }
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
        // Displayed as a PIN card in the UI, and over Settings.
        engine.pairingPIN = pin
        overSettings.show(code: pin)
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
