import Foundation
import SideInstallerFFI
import Darwin

/// Wraps idevice's C-FFI to reach the device over the loopback tunnel and talk
/// lockdown and installation_proxy across it, following StikDebug's path. The
/// adapter and handshake are created once and reused; every call blocks, so
/// none of this may run on the main thread.
final class DeviceConnection {

    // idevice opaque handles import as OpaquePointer.
    private var adapter: OpaquePointer?
    private var handshake: OpaquePointer?

    /// RemoteServiceDiscovery port reached over the VPN loopback.
    static let rsdPort: UInt16 = 49152

    /// lockdownd's own port. Fixed, unlike the ephemeral port `createListener`
    /// opens, so a route that forwards only well-known ports still reaches it.
    static let lockdownPort: UInt16 = 62078

    var isConnected: Bool { adapter != nil && handshake != nil }

    struct FFIError: Error, CustomStringConvertible {
        let code: Int32
        let subCode: Int32
        let message: String
        var description: String { "idevice FFI error code=\(code) sub=\(subCode): \(message)" }
    }

    /// A tunnel failure said in terms of what the user can change, with the raw
    /// FFI error kept alongside it for the log.
    ///
    /// The FFI's own text — `code=16 sub=0: InternalError("TLS tunnel:
    /// Connection refused (os error 61)")` — names the errno of whichever
    /// attempt happened to be last, which is the same string for a VPN that
    /// forwards one port, a device that never opened the listener, and a
    /// pairing file that no longer matches. The Rust side classifies which of
    /// those it was; this turns that into a sentence.
    struct TunnelError: Error, CustomStringConvertible, LocalizedError {
        let kind: TunnelFailureKind
        let advice: String
        /// The unclassified FFI error, for the debug log — never presented.
        let underlying: FFIError
        var description: String { advice }
        var errorDescription: String? { advice }

        /// Whether pairing again could plausibly change the outcome.
        ///
        /// False when the route to the device is what failed: the pairing file
        /// is fine, and re-pairing walks the user through a PIN for nothing —
        /// then fails identically, which is exactly what a nightly tester hit.
        var repairingCouldHelp: Bool {
            kind != TunnelFailureHostsRefused
                && kind != TunnelFailureTimeout
                && kind != TunnelFailureRsdUnreachable
        }
    }

    /// Consume an `IdeviceFfiError*` into an `FFIError` (null == success).
    private func ffiError(_ err: UnsafeMutablePointer<IdeviceFfiError>?,
                          _ fallback: String) -> FFIError? {
        guard let err = err else { return nil }
        let code = err.pointee.code
        let sub = err.pointee.sub_code
        let msg = err.pointee.message.flatMap { String(validatingUTF8: $0) } ?? fallback
        idevice_error_free(err)
        return FFIError(code: code, subCode: sub, message: msg.isEmpty ? fallback : msg)
    }

    /// Turn a returned IdeviceFfiError* into a thrown error (null == success).
    private func check(_ err: UnsafeMutablePointer<IdeviceFfiError>?, _ fallback: String) throws {
        if let error = ffiError(err, fallback) { throw error }
    }

    private func fail(_ message: String) -> FFIError {
        FFIError(code: -1, subCode: 0, message: message)
    }

    /// What to tell the user for each way the tunnel dial can end, given the
    /// candidate hosts that were tried. The raw error goes to the log; only
    /// this string is presented.
    private func tunnelAdvice(kind: TunnelFailureKind,
                              deviceIP: String,
                              candidates: [String],
                              raw: FFIError?) -> String {
        let tried = ([deviceIP, "127.0.0.1"] + candidates).joined(separator: ", ")
        switch kind {
        case TunnelFailureHostsRefused:
            return """
                The device answered on the RSD port at \(deviceIP), then the tunnel port \
                it opened was unreachable on that same address — dropped or refused, \
                across \(tried). The device is there; what's in front of it is forwarding \
                some ports and not others. The tunnel opens on a fresh high port every \
                attempt, so a rule-based proxy that forwards the RSD port alone can never \
                cover it. Use a loopback VPN that blanket-forwards every port on the RSD \
                subnet. Re-pairing won't help — the pairing is fine.
                """
        case TunnelFailureTimeout:
            return """
                The tunnel port never answered and never refused on any address \
                (\(tried)) — the connection is being swallowed rather than rejected. \
                That's usually a VPN or firewall dropping traffic on the RSD subnet. \
                Check the VPN is still up, then try again.
                """
        case TunnelFailureTlsHandshake:
            return """
                Something accepted the tunnel connection but failed the encrypted \
                handshake on top of it. Either another process holds that port, or this \
                pairing file's key no longer matches the device. Pair again, and if that \
                doesn't take, restart the loopback VPN.
                """
        case TunnelFailurePairVerify:
            return """
                The device rejected this pairing file: it's for a different device, or \
                the pairing was revoked (a reset, a restore, or Developer Mode being \
                turned off). Pair with this iPhone again to get a fresh file.
                """
        case TunnelFailureRsdUnreachable:
            // ECONNREFUSED means the packet arrived and was turned away, so the
            // tunnel is carrying traffic and the address is right — the device
            // simply has nothing listening on the pairing port. Blaming the VPN
            // there sends people to check the one thing that is demonstrably
            // working, which is what the old copy did.
            if Self.wasRefused(raw) {
                return L("Something at %@:%d refused the connection, so the tunnel is carrying traffic — the device just isn't listening on its pairing port. That port only opens while Developer Mode is on, and iOS asks for it again after every restart: turn it on under Settings › Privacy & Security › Developer Mode, then try again. If it's already on, pair this iPhone again under “Pairing file”.",
                         deviceIP, Int(Self.rsdPort))
            }
            return """
                Couldn't reach the device at \(deviceIP):\(Self.rsdPort) at all. The \
                loopback VPN is most likely off, or is handing out a different address \
                than the one configured here.
                """
        default:
            return """
                The tunnel didn't come up, and the failure didn't match any known cause. \
                The raw error is in the log.
                """
        }
    }

    /// Did the dial end in a refusal rather than silence? The classifier folds
    /// both into `RsdUnreachable`, but only the errno tells them apart, and they
    /// mean opposite things — so it is read back out of the raw message.
    static func wasRefused(_ raw: FFIError?) -> Bool {
        guard let message = raw?.message.lowercased() else { return false }
        return message.contains("connection refused") || message.contains("os error 61")
    }

    // MARK: Connect / disconnect

    /// Establish the loopback tunnel and RSD handshake, by whichever route the
    /// pairing file supports.
    ///
    /// Two routes end in the same adapter + RSD handshake, so everything below
    /// this is identical either way:
    ///
    /// - **RPPairing** (`tunnel_create_rppairing`): talks straight to the
    ///   device's remote-pairing listener with the Ed25519 record iOS 27's
    ///   on-device pairing produces. The route SideInstaller has always taken.
    /// - **CoreDeviceProxy** (`tunnel_create_usb`): opens a lockdown session
    ///   with a *classic* pair record and starts
    ///   `com.apple.internal.devicecompute.CoreDeviceProxy`, which vends the
    ///   same tunnel. Works back to iOS 17, and is the only route open to a
    ///   pairing file made on a computer — the pre-27 path, and StikDebug's.
    ///
    /// A file carrying both records tries the route its OS is likeliest to
    /// answer on first, then the other.
    func connect(deviceIP: String, pairingFilePath: String, hostname: String = "SideInstaller") throws {
        let kind = PairingFileKind.of(path: pairingFilePath)
        guard kind.isUsable else {
            throw fail("\((pairingFilePath as NSString).lastPathComponent) isn't a pairing file: it carries neither a remote-pairing key pair nor a lockdown pair record.")
        }
        // iOS 27 answers on the remote-pairing listener; anything older only has
        // lockdownd. With one record there's no choice to make.
        let remoteFirst = Engine.deviceCanSelfPair
        let routes: [Bool] = (kind.hasRemotePairing && kind.hasLockdown)
            ? (remoteFirst ? [true, false] : [false, true])
            : [kind.hasRemotePairing]

        var firstFailure: Error?
        // A file with only the RPPairing half still has one route left after
        // its own are spent: mint the classic half here. See below.
        let canMintLockdownRecord = !kind.hasLockdown
        for (index, useRemotePairing) in routes.enumerated() {
            do {
                if useRemotePairing {
                    try connectRemotePairing(deviceIP: deviceIP,
                                             pairingFilePath: pairingFilePath,
                                             hostname: hostname)
                } else {
                    try connectCoreDeviceProxy(deviceIP: deviceIP,
                                               pairingFilePath: pairingFilePath,
                                               hostname: hostname)
                }
                return
            } catch {
                // Report what the preferred route said, not the fallback's noise.
                if firstFailure == nil { firstFailure = error }
                let more = (index + 1 < routes.count || canMintLockdownRecord)
                    ? " Trying the other route…" : ""
                Engine.shared.log("\(useRemotePairing ? "Remote-pairing" : "Lockdown") tunnel didn't come up (\(error)).\(more)")
            }
        }

        // Every route the pairing file itself supports is spent — but on this
        // iPhone the RPPairing one can fail for a reason no pairing file fixes.
        // It needs the device to accept an inbound connection on the port
        // `createListener` opens, and that listener is bound to the local
        // network interface alone: loopback refuses it and the loopback VPN's
        // address never answers, so the only address that reaches it is this
        // iPhone's own Wi-Fi address — where the device is being asked to build
        // a tunnel to itself, and closes the connection cleanly instead
        // (`close_notify`, right after a TLS handshake it completed happily).
        //
        // CoreDeviceProxy needs no inbound listener at all: it rides the
        // lockdown connection that is already working. The only thing it wants
        // is the classic pair record this file doesn't carry — and lockdownd
        // mints one on its own port, with no tunnel in front of it.
        if canMintLockdownRecord {
            do {
                try connectByMintingLockdownRecord(deviceIP: deviceIP, hostname: hostname)
                return
            } catch {
                Engine.shared.log("Pairing with lockdown didn't open a tunnel either (\(error)).")
            }
        }
        throw firstFailure ?? fail("no tunnel route available for this pairing file")
    }

    /// The RPPairing route: straight to the device's remote-pairing listener.
    private func connectRemotePairing(deviceIP: String, pairingFilePath: String,
                                      hostname: String) throws {
        var pf: OpaquePointer?
        try pairingFilePath.withCString { p in
            try check(rp_pairing_file_read(p, &pf), "failed to read pairing file at \(pairingFilePath)")
        }
        guard let pairingFile = pf else { throw fail("pairing file handle was null") }
        defer { rp_pairing_file_free(pairingFile) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Self.rsdPort.bigEndian
        guard deviceIP.withCString({ inet_pton(AF_INET, $0, &addr.sin_addr) }) == 1 else {
            throw fail("invalid device IP: \(deviceIP)")
        }

        // createListener names a port but no host, so the Rust side sweeps
        // candidates: the RSD address, loopback, then these — the local
        // addresses of the interfaces the pairing session runs over. The whole
        // sweep shares one wall-clock budget, so the extra hosts don't lengthen
        // a run that was going to fail.
        let candidates = NetworkStatus.tunnelHostCandidates()
        let cHosts: [UnsafePointer<CChar>?] = candidates.map { UnsafePointer(strdup($0)) }
        defer { for p in cHosts { free(UnsafeMutablePointer(mutating: p)) } }

        var newAdapter: OpaquePointer?
        var newHandshake: OpaquePointer?
        var failureKind = TunnelFailureNone
        let err = withUnsafePointer(to: &addr) { aptr in
            aptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                hostname.withCString { host in
                    cHosts.withUnsafeBufferPointer { extra in
                        // A nil pin_callback pair-verifies with the existing file.
                        tunnel_create_rppairing_multihost(
                            sa, socklen_t(MemoryLayout<sockaddr_in>.stride),
                            host, pairingFile, nil, nil,
                            extra.baseAddress, UInt(extra.count), &failureKind,
                            &newAdapter, &newHandshake)
                    }
                }
            }
        }
        if let raw = ffiError(err, "tunnel_create_rppairing failed (is a loopback VPN connected, Wi-Fi on, device IP \(deviceIP)?)") {
            // The unclassified error stays in the log; only what's thrown changes.
            Engine.shared.log("tunnel dial failed — raw error: \(raw)")
            throw TunnelError(kind: failureKind,
                              advice: tunnelAdvice(kind: failureKind,
                                                   deviceIP: deviceIP,
                                                   candidates: candidates,
                                                   raw: raw),
                              underlying: raw)
        }
        guard newAdapter != nil, newHandshake != nil else {
            throw fail("tunnel created without valid handles")
        }
        disconnect()
        adapter = newAdapter
        handshake = newHandshake
    }

    /// The CoreDeviceProxy route, for a classic lockdown pair record.
    ///
    /// `tunnel_create_usb` is named for the transport idevice built it against;
    /// what it actually does is start CoreDeviceProxy through whatever provider
    /// it's handed, and a `TcpProvider` reaches lockdownd over the loopback
    /// tunnel exactly as the USB one reaches it over usbmuxd. No RPPairing
    /// record is involved, which is what makes an imported pairing file work.
    private func connectCoreDeviceProxy(deviceIP: String, pairingFilePath: String,
                                        hostname: String) throws {
        var pf: OpaquePointer?
        try pairingFilePath.withCString { p in
            try check(idevice_pairing_file_read(p, &pf),
                      "failed to read the lockdown pair record at \(pairingFilePath)")
        }
        guard let pairingFile = pf else { throw fail("pairing file handle was null") }
        // Freed only on the paths where the provider never takes ownership.
        var pairingFileOwned = true
        defer { if pairingFileOwned { idevice_pairing_file_free(pairingFile) } }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        // The provider picks the port per service; only the address is read.
        addr.sin_port = 0
        guard deviceIP.withCString({ inet_pton(AF_INET, $0, &addr.sin_addr) }) == 1 else {
            throw fail("invalid device IP: \(deviceIP)")
        }

        var provider: OpaquePointer?
        let providerError = withUnsafePointer(to: &addr) { aptr in
            aptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                hostname.withCString { label in
                    idevice_tcp_provider_new(sa, pairingFile, label, &provider)
                }
            }
        }
        // The provider takes ownership of the pairing file, but only once it
        // gets far enough to build one — an early argument error leaves it ours.
        if providerError == nil { pairingFileOwned = false }
        try check(providerError, "idevice_tcp_provider_new failed")
        guard let provider else { throw fail("lockdown provider was null") }
        defer { idevice_provider_free(provider) }

        var newAdapter: OpaquePointer?
        var newHandshake: OpaquePointer?
        try check(tunnel_create_usb(provider, &newAdapter, &newHandshake),
                  "CoreDeviceProxy tunnel failed (is a loopback VPN connected, device IP \(deviceIP), and is this pairing file this iPhone's?)")
        guard newAdapter != nil, newHandshake != nil else {
            throw fail("tunnel created without valid handles")
        }
        disconnect()
        adapter = newAdapter
        handshake = newHandshake
    }

    /// Take the CoreDeviceProxy route with a lockdown pair record minted here,
    /// for a pairing file that carries only the RPPairing half.
    ///
    /// The record is kept once made: minting one is interactive (the device puts
    /// up a Trust prompt) and spends one of the device's pairing slots. A stored
    /// one is tried first and re-minted only when it no longer opens a tunnel,
    /// which is what a reset, a restore, or a record from another iPhone looks
    /// like from here.
    private func connectByMintingLockdownRecord(deviceIP: String, hostname: String) throws {
        let stored = PrivateStore.lockdownPairRecord
        let storedSize = ((try? FileManager.default.attributesOfItem(atPath: stored.path)[.size]) as? Int) ?? 0
        if storedSize > 0 {
            do {
                try connectCoreDeviceProxy(deviceIP: deviceIP,
                                           pairingFilePath: stored.path,
                                           hostname: hostname)
                Engine.shared.log("Tunnel up over CoreDeviceProxy, with the lockdown pair record already stored here.")
                return
            } catch {
                Engine.shared.log("The stored lockdown pair record didn't open a tunnel (\(error)). Pairing with lockdown again…")
            }
        }

        Engine.shared.log("Asking lockdownd for a pair record — unlock this iPhone and tap Trust if it asks …")
        let record = try lockdownPairRecordDirect(hosts: [deviceIP, "127.0.0.1"],
                                                  hostID: CompositePairingFile.hostID,
                                                  systemBUID: CompositePairingFile.systemBUID,
                                                  hostName: hostname)
        try record.write(to: stored, options: .atomic)
        Engine.shared.log("Lockdown pair record minted (\(record.count) bytes). Opening the tunnel over CoreDeviceProxy …")
        try connectCoreDeviceProxy(deviceIP: deviceIP,
                                   pairingFilePath: stored.path,
                                   hostname: hostname)
    }

    /// Run the classic lockdown `Pair` handshake straight against lockdownd,
    /// with no tunnel in front of it.
    ///
    /// `lockdownPairRecord` runs the same handshake *inside* the RSD tunnel, so
    /// it can never be what produces the record a missing tunnel needs. This one
    /// talks to lockdownd's own port instead. Blocks while the device shows its
    /// Trust prompt: idevice retries `Pair` until the user answers.
    ///
    /// Each host is tried in turn, because which address reaches lockdownd from
    /// on-device is exactly what isn't known: the loopback VPN's peer is what
    /// every other lockdown client here uses, and plain loopback is the one that
    /// needs no VPN at all.
    func lockdownPairRecordDirect(hosts: [String], hostID: String, systemBUID: String,
                                  hostName: String) throws -> Data {
        var lastError: Error?
        for host in hosts {
            do {
                return try pairOverLockdown(host: host, hostID: hostID,
                                            systemBUID: systemBUID, hostName: hostName)
            } catch {
                lastError = error
                Engine.shared.log("lockdownd at \(host):\(Self.lockdownPort) didn't pair (\(error)).")
            }
        }
        throw lastError ?? fail("no address to reach lockdownd on")
    }

    private func pairOverLockdown(host: String, hostID: String, systemBUID: String,
                                  hostName: String) throws -> Data {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Self.lockdownPort.bigEndian
        guard host.withCString({ inet_pton(AF_INET, $0, &addr.sin_addr) }) == 1 else {
            throw fail("invalid lockdown address: \(host)")
        }

        var device: OpaquePointer?
        let connectError = withUnsafePointer(to: &addr) { aptr in
            aptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                hostName.withCString { label in
                    idevice_new_tcp_socket(sa, socklen_t(MemoryLayout<sockaddr_in>.stride),
                                           label, &device)
                }
            }
        }
        try check(connectError, "couldn't reach lockdownd at \(host):\(Self.lockdownPort)")
        guard let device else { throw fail("lockdown socket handle was null") }

        // `lockdownd_new` consumes the socket and can only fail on a null
        // argument, so there is no path back where it is still ours to free.
        var client: OpaquePointer?
        try check(lockdownd_new(device, &client), "lockdownd_new failed")
        guard let client else { throw fail("lockdown client was null") }
        defer { lockdownd_client_free(client) }

        var pf: OpaquePointer?
        let pairError = hostID.withCString { h in
            systemBUID.withCString { b in
                hostName.withCString { n in
                    lockdownd_pair(client, h, b, n, &pf)
                }
            }
        }
        try check(pairError, "lockdownd_pair failed")
        guard let pf else { throw fail("lockdownd_pair returned no pair record") }
        defer { idevice_pairing_file_free(pf) }

        var bytes: UnsafeMutablePointer<UInt8>?
        var length: UInt = 0
        try check(idevice_pairing_file_serialize(pf, &bytes, &length),
                  "idevice_pairing_file_serialize failed")
        guard let bytes, length > 0 else { throw fail("serialized pair record was empty") }
        let record = Data(bytes: bytes, count: Int(length))
        idevice_data_free(bytes, length)
        return record
    }

    func disconnect() {
        // Before the tunnel they run over: both hold the adapter's connections.
        endLocationSimulation()
        if let handshake { rsd_handshake_free(handshake); self.handshake = nil }
        if let adapter { adapter_free(adapter); self.adapter = nil }
    }

    // MARK: RSD handshake summary

    /// Basic info straight off the RSD handshake (no extra service connection).
    func rsdSummary() throws -> String {
        guard let handshake else { throw fail("not connected") }
        var uuid: UnsafeMutablePointer<CChar>?
        try check(rsd_get_uuid(handshake, &uuid), "rsd_get_uuid failed")
        let uuidStr = uuid.flatMap { String(validatingUTF8: $0) } ?? "?"
        if let uuid { idevice_string_free(uuid) }

        var proto: UInt = 0
        try check(rsd_get_protocol_version(handshake, &proto), "rsd_get_protocol_version failed")
        return "RSD uuid=\(uuidStr) protocol=\(proto)"
    }

    // MARK: Device info (lockdown over RSD)

    /// ProductVersion / ProductType / UDID etc. via lockdownd over the tunnel.
    func deviceInfo() throws -> [(String, String)] {
        guard let adapter, let handshake else { throw fail("not connected") }
        var client: OpaquePointer?
        try check(lockdownd_connect_rsd(adapter, handshake, &client), "lockdownd_connect_rsd failed")
        guard let client else { throw fail("lockdownd client was null") }
        defer { lockdownd_client_free(client) }

        var plistObj: plist_t?
        try check(lockdownd_get_value(client, nil, nil, &plistObj), "lockdownd_get_value failed")
        guard let plistObj else { return [] }
        defer { plist_free(plistObj) }

        let keys = [
            "DeviceName", "ProductType", "ProductVersion", "BuildVersion",
            "UniqueDeviceID", "HardwareModel", "CPUArchitecture", "ModelNumber",
        ]
        return keys.compactMap { key in
            plistString(plistObj, key).map { (key, $0) }
        }
    }

    // MARK: Classic lockdown pair record

    /// A classic lockdown pair record, and how enabling wireless lockdown went.
    struct LockdownPairRecord {
        /// The record as XML plist bytes.
        let data: Data
        /// nil when `EnableWifiDebugging` was set, the failure otherwise. Every
        /// app that reads this record reaches lockdownd over a loopback, so a
        /// failure here usually means the record won't work — it's still
        /// returned, since the setting may already be on from an earlier pairing.
        let wirelessLockdownError: String?
    }

    /// Run the classic lockdown `Pair` handshake over the RSD tunnel, then turn
    /// on wireless lockdown, as iLoader does while building its pairing file.
    ///
    /// This is the half SideInstaller's RPPairing record doesn't carry: minimuxer
    /// (SideStore, LiveContainer + SideStore) and Feather parse a classic record
    /// — host/root/device certificates, HostID, SystemBUID, escrow bag — and
    /// can't read RPPairing's key pair. Blocks while the device shows its Trust
    /// prompt: idevice retries `Pair` until the user answers.
    func lockdownPairRecord(hostID: String,
                            systemBUID: String,
                            hostName: String = "SideInstaller") throws -> LockdownPairRecord {
        guard let adapter, let handshake else { throw fail("not connected") }

        var client: OpaquePointer?
        try check(lockdownd_connect_rsd(adapter, handshake, &client),
                  "lockdownd_connect_rsd failed")
        guard let client else { throw fail("lockdownd client was null") }
        defer { lockdownd_client_free(client) }

        var pf: OpaquePointer?
        let pairError = hostID.withCString { host in
            systemBUID.withCString { buid in
                hostName.withCString { name in
                    lockdownd_pair(client, host, buid, name, &pf)
                }
            }
        }
        try check(pairError, "lockdownd_pair failed")
        guard let pf else { throw fail("lockdownd_pair returned no pair record") }
        defer { idevice_pairing_file_free(pf) }

        var bytes: UnsafeMutablePointer<UInt8>?
        var length: UInt = 0
        try check(idevice_pairing_file_serialize(pf, &bytes, &length),
                  "idevice_pairing_file_serialize failed")
        guard let bytes, length > 0 else { throw fail("serialized pair record was empty") }
        let record = Data(bytes: bytes, count: Int(length))
        idevice_data_free(bytes, length)

        var wirelessError: String?
        do { try enableWirelessLockdown(pairRecord: pf) }
        catch { wirelessError = String(describing: error) }

        return LockdownPairRecord(data: record, wirelessLockdownError: wirelessError)
    }

    /// Set `EnableWifiDebugging`, without which lockdownd answers over USB only —
    /// and every app reading this record reaches it over a network loopback.
    ///
    /// Tried without a session first. Over USB, iLoader's route, setting a value
    /// in that domain needs `StartSession`; over RSD the stream is already inside
    /// the RPPairing tunnel and the endpoint is the *trusted* one, so the plain
    /// request usually stands — and `StartSession` there wants to negotiate a
    /// second TLS session inside the first, which it can't. The session is still
    /// worth one attempt if the plain request is refused.
    private func enableWirelessLockdown(pairRecord: OpaquePointer) throws {
        do {
            try setWirelessLockdown(startingSessionWith: nil)
        } catch let sessionless {
            do {
                try setWirelessLockdown(startingSessionWith: pairRecord)
            } catch {
                // Both ways, so the log says which door was shut.
                throw fail("without a session: \(sessionless); with one: \(error)")
            }
        }
    }

    /// One `SetValue` attempt on a fresh lockdown client — `Pair`, and a failed
    /// request, both leave the client that ran them mid-protocol.
    private func setWirelessLockdown(startingSessionWith pairRecord: OpaquePointer?) throws {
        guard let adapter, let handshake else { throw fail("not connected") }

        var client: OpaquePointer?
        try check(lockdownd_connect_rsd(adapter, handshake, &client),
                  "lockdownd_connect_rsd (wireless lockdown) failed")
        guard let client else { throw fail("lockdownd client was null") }
        defer { lockdownd_client_free(client) }

        if let pairRecord {
            try check(lockdownd_start_session(client, pairRecord),
                      "lockdownd_start_session failed")
        }

        guard let value: plist_t = plist_new_bool(1) else { throw fail("couldn't build a plist bool") }
        defer { plist_free(value) }          // set_value clones it
        let setError = "EnableWifiDebugging".withCString { key in
            "com.apple.mobile.wireless_lockdown".withCString { domain in
                lockdownd_set_value(client, key, value, domain)
            }
        }
        try check(setError, "lockdownd_set_value(EnableWifiDebugging) failed")
    }

    // MARK: Installed apps (installation_proxy over RSD)

    /// Proves installation_proxy is reachable. `applicationType` nil = all.
    func listApps(applicationType: String? = nil) throws -> [String] {
        guard let adapter, let handshake else { throw fail("not connected") }
        var client: OpaquePointer?
        try check(installation_proxy_connect_rsd(adapter, handshake, &client),
                  "installation_proxy_connect_rsd failed")
        guard let client else { throw fail("installation_proxy client was null") }
        defer { installation_proxy_client_free(client) }

        var result: UnsafeMutableRawPointer?
        var count = 0
        let err: UnsafeMutablePointer<IdeviceFfiError>?
        if let applicationType {
            err = applicationType.withCString {
                installation_proxy_get_apps(client, $0, nil, 0, &result, &count)
            }
        } else {
            err = installation_proxy_get_apps(client, nil, nil, 0, &result, &count)
        }
        try check(err, "installation_proxy_get_apps failed")
        guard let result, count > 0 else { return [] }

        let apps = result.assumingMemoryBound(to: plist_t?.self)
        var out: [String] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let appPlist = apps[i]
            let bid = plistString(appPlist, "CFBundleIdentifier") ?? "?"
            let name = plistString(appPlist, "CFBundleDisplayName")
            let version = plistString(appPlist, "CFBundleShortVersionString")
            var line = bid
            if let name { line += "  \"\(name)\"" }
            if let version { line += "  v\(version)" }
            out.append(line)
            if let appPlist { plist_free(appPlist) }
        }
        // The outer plist_t array has no exposed free: a tiny per-call leak.
        return out
    }

    /// One installed app as installation_proxy reports it.
    struct InstalledApp: Equatable {
        let bundleID: String
        let displayName: String?
    }

    /// Every installed app as data, where `listApps` returns log lines.
    func installedApps() throws -> [InstalledApp] {
        guard let adapter, let handshake else { throw fail("not connected") }
        var client: OpaquePointer?
        try check(installation_proxy_connect_rsd(adapter, handshake, &client),
                  "installation_proxy_connect_rsd failed")
        guard let client else { throw fail("installation_proxy client was null") }
        defer { installation_proxy_client_free(client) }

        var result: UnsafeMutableRawPointer?
        var count = 0
        try check(installation_proxy_get_apps(client, nil, nil, 0, &result, &count),
                  "installation_proxy_get_apps failed")
        guard let result, count > 0 else { return [] }

        let apps = result.assumingMemoryBound(to: plist_t?.self)
        var out: [InstalledApp] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let appPlist = apps[i]
            if let bid = plistString(appPlist, "CFBundleIdentifier") {
                out.append(InstalledApp(bundleID: bid,
                                        displayName: plistString(appPlist, "CFBundleDisplayName")))
            }
            if let appPlist { plist_free(appPlist) }
        }
        return out
    }

    /// Every installed app as its whole installation_proxy plist, rather than
    /// the two fields `installedApps` picks out. `Entitlements` and
    /// `ProfileValidated` only exist here, and they are what tells a sideloaded
    /// app from an App Store one.
    ///
    /// Each app plist is re-serialized to binary and read back through
    /// `PropertyListSerialization`, which is StikDebug's route too: walking a
    /// nested `Entitlements` dictionary through the plist C API by hand would be
    /// a lot of code for a structure Foundation already decodes.
    func installedAppPlists() throws -> [[String: Any]] {
        guard let adapter, let handshake else { throw fail("not connected") }
        var client: OpaquePointer?
        try check(installation_proxy_connect_rsd(adapter, handshake, &client),
                  "installation_proxy_connect_rsd failed")
        guard let client else { throw fail("installation_proxy client was null") }
        defer { installation_proxy_client_free(client) }

        var result: UnsafeMutableRawPointer?
        var count = 0
        try check(installation_proxy_get_apps(client, nil, nil, 0, &result, &count),
                  "installation_proxy_get_apps failed")
        guard let result, count > 0 else { return [] }

        let apps = result.assumingMemoryBound(to: plist_t?.self)
        defer {
            for i in 0..<count { plist_free(apps[i]) }
            idevice_data_free(result.assumingMemoryBound(to: UInt8.self),
                              UInt(count * MemoryLayout<plist_t?>.stride))
        }

        var out: [[String: Any]] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            var binary: UnsafeMutablePointer<CChar>?
            var length: UInt32 = 0
            guard plist_to_bin(apps[i], &binary, &length) == PLIST_ERR_SUCCESS,
                  let binary, length > 0 else { continue }
            let data = Data(bytes: binary, count: Int(length))
            plist_mem_free(binary)
            // One app that won't decode shouldn't cost the whole list.
            guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let dict = plist as? [String: Any] else { continue }
            out.append(dict)
        }
        return out
    }

    /// The host app's exact bundle id for the pairing write, matched on display
    /// name first — isideload rewrites bundle ids — then on "<base>[.<teamID>]".
    func resolveInstalledBundleID(displayName: String, bundleIDBase: String) throws -> String? {
        guard let adapter, let handshake else { throw fail("not connected") }
        var client: OpaquePointer?
        try check(installation_proxy_connect_rsd(adapter, handshake, &client),
                  "installation_proxy_connect_rsd failed")
        guard let client else { throw fail("installation_proxy client was null") }
        defer { installation_proxy_client_free(client) }

        var result: UnsafeMutableRawPointer?
        var count = 0
        try check(installation_proxy_get_apps(client, nil, nil, 0, &result, &count),
                  "installation_proxy_get_apps failed")
        guard let result, count > 0 else { return nil }

        let apps = result.assumingMemoryBound(to: plist_t?.self)
        var byName: String?
        var exact: String?
        var suffixed: String?
        for i in 0..<count {
            let appPlist = apps[i]
            if let bid = plistString(appPlist, "CFBundleIdentifier") {
                if byName == nil, plistString(appPlist, "CFBundleDisplayName") == displayName {
                    byName = bid
                }
                if bid == bundleIDBase { exact = bid }
                else if bid.hasPrefix(bundleIDBase + ".") { suffixed = bid }
            }
            if let appPlist { plist_free(appPlist) }
        }
        return byName ?? exact ?? suffixed
    }

    // MARK: Provisioning profiles (misagent over RSD)

    /// Every provisioning profile installed on the device, as the raw CMS blobs
    /// misagent hands back — the same bytes a `.mobileprovision` file holds.
    /// Decoding them is the caller's job.
    func provisioningProfiles() throws -> [Data] {
        guard let adapter, let handshake else { throw fail("not connected") }
        var client: OpaquePointer?
        try check(misagent_connect_rsd(adapter, handshake, &client),
                  "misagent_connect_rsd failed")
        guard let client else { throw fail("misagent client was null") }
        defer { misagent_client_free(client) }

        var profiles: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?
        var lengths: UnsafeMutablePointer<Int>?
        var count = 0
        try check(misagent_copy_all(client, &profiles, &lengths, &count),
                  "misagent_copy_all failed")
        guard let profiles, let lengths else { return [] }
        defer { misagent_free_profiles(profiles, lengths, count) }

        var out: [Data] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            guard let bytes = profiles[i] else { continue }
            out.append(Data(bytes: bytes, count: lengths[i]))
        }
        return out
    }

    // MARK: Install (AFC upload to /PublicStaging + installation_proxy)

    /// Upload a signed `.app` bundle to /PublicStaging and install it over RSD.
    func installSignedApp(bundlePath: String) throws {
        guard let adapter, let handshake else { throw fail("not connected") }

        var afc: OpaquePointer?
        try check(afc_client_connect_rsd(adapter, handshake, &afc), "afc_client_connect_rsd failed")
        guard let afc else { throw fail("AFC client was null") }
        defer { afc_client_free(afc) }

        let name = (bundlePath as NSString).lastPathComponent
        let remoteRoot = "/PublicStaging/\(name)"
        try uploadDirectory(afc, localDir: bundlePath, remoteDir: remoteRoot)

        var ip: OpaquePointer?
        try check(installation_proxy_connect_rsd(adapter, handshake, &ip),
                  "installation_proxy_connect_rsd failed")
        guard let ip else { throw fail("installation_proxy client was null") }
        defer { installation_proxy_client_free(ip) }

        guard let options = developerInstallOptions() else {
            throw fail("couldn't build install ClientOptions")
        }
        defer { plist_free(options) }

        try remoteRoot.withCString { p in
            try check(installation_proxy_install_with_callback(ip, p, options, installProgressCb, nil),
                      "installation_proxy install failed")
        }
    }

    /// installation_proxy options for a developer-signed bundle. Without
    /// `PackageType: Developer`, installd never reads the embedded profile and
    /// rejects the upload with 0xe8008015 at VerifyingApplication.
    private func developerInstallOptions() -> plist_t? {
        guard let options: plist_t = plist_new_dict() else { return nil }
        // The dict takes ownership of the value node, so freeing it is enough.
        plist_dict_set_item(options, "PackageType", plist_new_string("Developer"))
        return options
    }

    /// Recursively upload a local directory tree to AFC.
    private func uploadDirectory(_ afc: OpaquePointer, localDir: String, remoteDir: String) throws {
        _ = remoteDir.withCString { afc_make_directory(afc, $0) }  // ok if exists
        let fm = FileManager.default
        let entries = try fm.contentsOfDirectory(atPath: localDir)
        for entry in entries {
            let localPath = (localDir as NSString).appendingPathComponent(entry)
            let remotePath = "\(remoteDir)/\(entry)"
            var isDir: ObjCBool = false
            fm.fileExists(atPath: localPath, isDirectory: &isDir)
            if isDir.boolValue {
                try uploadDirectory(afc, localDir: localPath, remoteDir: remotePath)
            } else {
                try uploadFile(afc, localPath: localPath, remotePath: remotePath)
            }
        }
    }

    private func uploadFile(_ afc: OpaquePointer, localPath: String, remotePath: String) throws {
        // Mapped, not read: a tens-of-megabytes binary on the heap risks a jetsam.
        let data = try Data(contentsOf: URL(fileURLWithPath: localPath), options: .mappedIfSafe)
        var file: OpaquePointer?
        try check(remotePath.withCString { afc_file_open(afc, $0, AfcWrOnly, &file) },
                  "afc_file_open \(remotePath) failed")
        guard let file else { throw fail("AFC file handle was null") }
        defer { afc_file_close(file) }

        // Write in chunks so large files don't balloon memory in one FFI call.
        let chunk = 1 << 20
        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            var offset = 0
            while offset < data.count {
                let n = min(chunk, data.count - offset)
                try check(afc_file_write(file, base + offset, n), "afc_file_write failed")
                offset += n
            }
        }
    }

    // MARK: Write pairing file into another app's container (house_arrest)

    /// Write `pairingFilePath` into `bundleID`'s Documents, then read it back to
    /// prove the write committed, returning the verified byte count.
    ///
    /// `house_arrest_vend_documents` consumes the HouseArrestClient on success
    /// and failure alike, so `ha` must never be freed; `afc_file_close` and
    /// `afc_client_free` likewise consume their handle exactly once.
    @discardableResult
    func writePairingFile(intoBundleID bundleID: String,
                          remoteRelativePath: String,
                          pairingFilePath: String) throws -> Int {
        let data = try Data(contentsOf: URL(fileURLWithPath: pairingFilePath))
        guard !data.isEmpty else { throw fail("pairing file at \(pairingFilePath) is empty") }
        return try writeFile(intoBundleID: bundleID,
                             remoteRelativePath: remoteRelativePath,
                             data: data)
    }

    /// Write `data` into `bundleID`'s Documents at `remoteRelativePath`, then
    /// read it back to prove the write committed, returning the verified byte
    /// count. The pairing file is one caller; SideStore's `Account.sideconf`
    /// hand-off is the other.
    @discardableResult
    func writeFile(intoBundleID bundleID: String,
                   remoteRelativePath: String,
                   data: Data) throws -> Int {
        guard let adapter, let handshake else { throw fail("not connected") }
        guard !data.isEmpty else { throw fail("refusing to write an empty file") }

        var ha: OpaquePointer?
        try check(house_arrest_client_connect_rsd(adapter, handshake, &ha),
                  "house_arrest_client_connect_rsd failed")
        guard ha != nil else { throw fail("house_arrest client was null") }

        // vend consumes `ha` — do not free it. The AfcClient owns the Idevice.
        var afc: OpaquePointer?
        let vendErr = bundleID.withCString { house_arrest_vend_documents(ha, $0, &afc) }
        try check(vendErr, "house_arrest_vend_documents(\(bundleID)) failed")
        guard let afc else { throw fail("vended AFC client was null") }
        defer { afc_client_free(afc) }   // free the AfcClient (and its Idevice) once

        // vend_documents roots AFC at the container, not Documents, and the
        // container root itself is read-only, so the path carries "/Documents/".
        let remotePath = "/Documents/\(remoteRelativePath)"
        makeRemoteDirectories(afc, forFileAt: remotePath)

        // Open (create and truncate), write the whole buffer, then close.
        var wfile: OpaquePointer?
        try check(remotePath.withCString { afc_file_open(afc, $0, AfcWr, &wfile) },
                  "afc_file_open(\(remotePath), write) failed")
        guard let wfile else { throw fail("AFC write handle was null") }
        do {
            try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
                try check(afc_file_write(wfile, base, data.count), "afc_file_write failed")
            }
        } catch {
            _ = afc_file_close(wfile)   // consume the handle on the failure path
            throw error
        }
        // Close commits the write AND consumes wfile — check its error.
        try check(afc_file_close(wfile), "afc_file_close failed (write not committed)")

        // Re-open for read and assert the byte length committed.
        var rfile: OpaquePointer?
        try check(remotePath.withCString { afc_file_open(afc, $0, AfcRdOnly, &rfile) },
                  "afc_file_open(\(remotePath), read-back) failed")
        guard let rfile else { throw fail("AFC read-back handle was null") }
        var rdata: UnsafeMutablePointer<UInt8>?
        var rlen = 0
        let readErr = afc_file_read_entire(rfile, &rdata, &rlen)
        _ = afc_file_close(rfile)       // consume the read handle
        if let rdata { afc_file_read_data_free(rdata, rlen) }
        try check(readErr, "afc_file_read_entire (read-back) failed")
        guard rlen == data.count else {
            throw fail("read-back size mismatch: wrote \(data.count) bytes but device has \(rlen)")
        }
        return rlen
    }

    /// Create every parent directory of `remoteFilePath` on the AFC volume, for
    /// the nested LiveContainer guest path.
    private func makeRemoteDirectories(_ afc: OpaquePointer, forFileAt remoteFilePath: String) {
        let components = remoteFilePath.split(separator: "/").dropLast()  // drop the file name
        var path = ""
        for component in components {
            path += "/\(component)"
            _ = path.withCString { afc_make_directory(afc, $0) }
        }
    }

    // MARK: Developer disk image (image_mounter over RSD)

    /// How many developer images the device has mounted. Zero means the DVT
    /// services — location simulation among them — aren't reachable yet.
    func mountedDeveloperImageCount() throws -> Int {
        guard let adapter, let handshake else { throw fail("not connected") }
        var client: OpaquePointer?
        try check(image_mounter_connect_rsd(adapter, handshake, &client),
                  "image_mounter_connect_rsd failed")
        guard let client else { throw fail("image mounter client was null") }
        defer { image_mounter_free(client) }

        var devices: UnsafeMutablePointer<plist_t?>?
        var count = 0
        try check(image_mounter_copy_devices(client, &devices, &count),
                  "image_mounter_copy_devices failed")
        if let devices {
            for i in 0..<count { plist_free(devices[i]) }
            idevice_data_free(UnsafeMutableRawPointer(devices).assumingMemoryBound(to: UInt8.self),
                              UInt(count * MemoryLayout<plist_t?>.stride))
        }
        return count
    }

    /// Mount the personalized developer disk image, the way StikDebug does:
    /// lockdownd for the device's UniqueChipID, then image_mounter over the same
    /// RSD tunnel. Apple personalizes the image per chip, so the manifest and
    /// the chip id both go to the device and it signs its own copy.
    func mountPersonalizedDeveloperImage(imagePath: String,
                                         trustcachePath: String,
                                         manifestPath: String,
                                         progress: ((Double) -> Void)? = nil) throws {
        guard let adapter, let handshake else { throw fail("not connected") }

        // Mapped, not read: the image is tens of megabytes.
        let image = try Data(contentsOf: URL(fileURLWithPath: imagePath), options: .mappedIfSafe)
        let trustcache = try Data(contentsOf: URL(fileURLWithPath: trustcachePath), options: .mappedIfSafe)
        let manifest = try Data(contentsOf: URL(fileURLWithPath: manifestPath), options: .mappedIfSafe)
        guard !image.isEmpty, !trustcache.isEmpty, !manifest.isEmpty else {
            throw fail("developer disk image files are empty — download them again")
        }

        let chipID = try uniqueChipID()

        var client: OpaquePointer?
        try check(image_mounter_connect_rsd(adapter, handshake, &client),
                  "image_mounter_connect_rsd failed")
        guard let client else { throw fail("image mounter client was null") }
        defer { image_mounter_free(client) }

        // The callback fires on idevice's thread; the box is freed below.
        let box = progress.map { Unmanaged.passRetained(ProgressBox($0)).toOpaque() }
        defer { if let box { Unmanaged<ProgressBox>.fromOpaque(box).release() } }

        let err = image.withUnsafeBytes { img in
            trustcache.withUnsafeBytes { tc in
                manifest.withUnsafeBytes { man in
                    image_mounter_mount_personalized_with_callback_rsd(
                        client, adapter, handshake,
                        img.bindMemory(to: UInt8.self).baseAddress, image.count,
                        tc.bindMemory(to: UInt8.self).baseAddress, trustcache.count,
                        man.bindMemory(to: UInt8.self).baseAddress, manifest.count,
                        nil, chipID,
                        box == nil ? nil : mountProgressCb, box)
                }
            }
        }
        try check(err, "mounting the developer disk image failed")
    }

    /// The device's UniqueChipID, which personalizing the image is keyed on.
    private func uniqueChipID() throws -> UInt64 {
        guard let adapter, let handshake else { throw fail("not connected") }
        var client: OpaquePointer?
        try check(lockdownd_connect_rsd(adapter, handshake, &client), "lockdownd_connect_rsd failed")
        guard let client else { throw fail("lockdownd client was null") }
        defer { lockdownd_client_free(client) }

        var value: plist_t?
        try check("UniqueChipID".withCString { lockdownd_get_value(client, $0, nil, &value) },
                  "lockdownd_get_value(UniqueChipID) failed")
        guard let value else { throw fail("device reported no UniqueChipID") }
        defer { plist_free(value) }

        var chipID: UInt64 = 0
        plist_get_uint_val(value, &chipID)
        guard chipID != 0 else { throw fail("device reported an empty UniqueChipID") }
        return chipID
    }

    // MARK: Location simulation (DVT over RSD)

    /// The DVT remote server, and the location client that borrows it. Kept
    /// alive between calls: the device holds the simulated location only as long
    /// as this session is open.
    private var remoteServer: OpaquePointer?
    private var locationSim: OpaquePointer?

    var isSimulatingLocation: Bool { locationSim != nil }

    /// Open the DVT location-simulation session, reusing the existing tunnel.
    /// Needs a mounted developer disk image — without one the RemoteServer
    /// handshake is what fails.
    func beginLocationSimulation() throws {
        guard let adapter, let handshake else { throw fail("not connected") }
        guard locationSim == nil else { return }

        var server: OpaquePointer?
        try check(remote_server_connect_rsd(adapter, handshake, &server),
                  "remote_server_connect_rsd failed (is the developer disk image mounted?)")
        guard let server else { throw fail("remote server handle was null") }

        var sim: OpaquePointer?
        let err = location_simulation_new(server, &sim)
        if err != nil || sim == nil {
            remote_server_free(server)
            try check(err, "location_simulation_new failed")
            throw fail("location simulation handle was null")
        }
        // The client borrows the server rather than taking it, so the server has
        // to outlive it and be freed after — see `endLocationSimulation`.
        remoteServer = server
        locationSim = sim
    }

    func setSimulatedLocation(latitude: Double, longitude: Double) throws {
        guard let locationSim else { throw fail("no location simulation session") }
        try check(location_simulation_set(locationSim, latitude, longitude),
                  "location_simulation_set failed")
    }

    /// Hand the device back its real location. Leaves the session open.
    func clearSimulatedLocation() throws {
        guard let locationSim else { throw fail("no location simulation session") }
        try check(location_simulation_clear(locationSim), "location_simulation_clear failed")
    }

    /// Close the session. Order matters: the client borrows the server.
    func endLocationSimulation() {
        if let locationSim { location_simulation_free(locationSim); self.locationSim = nil }
        if let remoteServer { remote_server_free(remoteServer); self.remoteServer = nil }
    }

    // MARK: plist helpers

    private func plistString(_ dict: plist_t?, _ key: String) -> String? {
        guard let item = key.withCString({ plist_dict_get_item(dict, $0) }) else { return nil }
        var out: UnsafeMutablePointer<CChar>?
        plist_get_string_val(item, &out)
        guard let out else { return nil }
        defer { plist_mem_free(out) }
        let s = String(validatingUTF8: out) ?? ""
        return s.isEmpty ? nil : s
    }
}

/// Carries a Swift closure through the C mount callback's `void *context`.
private final class ProgressBox {
    let report: (Double) -> Void
    init(_ report: @escaping (Double) -> Void) { self.report = report }
}

/// image_mounter progress callback, driving the DDI mount bar.
private let mountProgressCb: @convention(c) (Int, Int, UnsafeMutableRawPointer?) -> Void = { done, total, context in
    guard let context, total > 0 else { return }
    let report = Unmanaged<ProgressBox>.fromOpaque(context).takeUnretainedValue().report
    let fraction = Double(done) / Double(total)
    DispatchQueue.main.async { report(fraction) }
}

/// installation_proxy progress callback, driving the bar and the log.
private let installProgressCb: @convention(c) (UInt64, UnsafeMutableRawPointer?) -> Void = { progress, _ in
    DispatchQueue.main.async {
        // installd repeats a percentage across phases; only act when it moves.
        let fraction = Double(progress) / 100.0
        guard Engine.shared.installProgress != fraction else { return }
        Engine.shared.installProgress = fraction
        Engine.shared.log("install progress: \(progress)%")
    }
}
