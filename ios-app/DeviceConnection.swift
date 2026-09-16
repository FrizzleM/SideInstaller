import Foundation
import SideInstallerFFI
import Darwin
import zlib

/// Wraps idevice's C FFI to talk to the device over the loopback tunnel
/// (lockdown, installation_proxy, AFC, etc.), like StikDebug does. The tunnel
/// adapter and RSD handshake are created once and reused. Every call blocks, so
/// never call these on the main thread.
final class DeviceConnection {

    // idevice opaque handles import as OpaquePointer.
    private var adapter: OpaquePointer?
    private var handshake: OpaquePointer?

    /// RemoteServiceDiscovery port reached over the VPN loopback.
    static let rsdPort: UInt16 = 49152

    /// lockdownd's fixed port (unlike the ephemeral tunnel port `createListener`
    /// opens).
    static let lockdownPort: UInt16 = 62078

    var isConnected: Bool { adapter != nil && handshake != nil }

    struct FFIError: Error, CustomStringConvertible {
        let code: Int32
        let subCode: Int32
        let message: String
        var description: String { "idevice FFI error code=\(code) sub=\(subCode): \(message)" }
    }

    /// A tunnel failure with user-facing advice, plus the raw FFI error for logs.
    ///
    /// The raw FFI message only shows the last attempt's errno, which looks the
    /// same for very different causes (port-filtering VPN, no listener, stale
    /// pairing file). The Rust side classifies the cause into `kind`.
    struct TunnelError: Error, CustomStringConvertible, LocalizedError {
        let kind: TunnelFailureKind
        let advice: String
        /// The unclassified FFI error, for the debug log — never presented.
        let underlying: FFIError
        var description: String { advice }
        var errorDescription: String? { advice }

        /// Whether re-pairing might fix this failure. False for route/network
        /// failures, where the pairing file isn't the problem.
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

    /// User-facing advice for each tunnel failure kind, listing the hosts that
    /// were tried.
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
            // ECONNREFUSED means the tunnel works and the address is right, but
            // nothing is listening on the pairing port (usually Developer Mode
            // is off), so don't blame the VPN.
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

    /// True if the connection was refused rather than timed out. Both are
    /// classified as `RsdUnreachable`, so this checks the raw message.
    static func wasRefused(_ raw: FFIError?) -> Bool {
        guard let message = raw?.message.lowercased() else { return false }
        return message.contains("connection refused") || message.contains("os error 61")
    }

    // MARK: Connect / disconnect

    /// Opens the loopback tunnel and RSD handshake using the routes the pairing
    /// file supports. Both routes produce the same adapter + handshake:
    ///
    /// - **RPPairing** (`tunnel_create_rppairing`): connects to the device's
    ///   remote-pairing listener with the Ed25519 record from on-device pairing
    ///   (iOS 27+).
    /// - **CoreDeviceProxy** (`tunnel_create_usb`): opens a lockdown session with
    ///   a classic pair record and starts CoreDeviceProxy. Works on iOS 17+ and
    ///   is the only route for pairing files made on a computer.
    ///
    /// With both records, the route most likely to work on this iOS goes first.
    /// With only an RPPairing record, a lockdown record is created as a last
    /// resort and CoreDeviceProxy is tried.
    func connect(deviceIP: String, pairingFilePath: String, hostname: String = "SideInstaller") throws {
        let kind = PairingFileKind.of(path: pairingFilePath)
        guard kind.isUsable else {
            throw fail("\((pairingFilePath as NSString).lastPathComponent) isn't a pairing file: it carries neither a remote-pairing key pair nor a lockdown pair record.")
        }
        // Prefer RPPairing on iOS 27+, lockdown otherwise. With one record, use
        // its route only.
        let remoteFirst = Engine.deviceCanSelfPair
        let routes: [Bool] = (kind.hasRemotePairing && kind.hasLockdown)
            ? (remoteFirst ? [true, false] : [false, true])
            : [kind.hasRemotePairing]

        var firstFailure: Error?
        // An RPPairing-only file can still fall back to creating a lockdown
        // record (see below).
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

        // RPPairing can fail on-device regardless of the pairing file: its
        // tunnel listener only binds to the Wi-Fi interface, and the device
        // closes a tunnel to itself right after the TLS handshake.
        // CoreDeviceProxy needs no inbound listener, only a classic pair record,
        // which lockdownd can create directly on its own port.
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

        // createListener returns a port but no host, so the Rust side tries the
        // RSD address, loopback, then these local interface addresses, all
        // within one shared timeout.
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
            // Log the raw error; throw the classified one.
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

    /// The CoreDeviceProxy route, using a classic lockdown pair record.
    ///
    /// Despite its name, `tunnel_create_usb` works with any provider; here a
    /// `TcpProvider` reaches lockdownd over the loopback tunnel. No RPPairing
    /// record is needed, so imported pairing files work.
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
        // On success the provider owns the pairing file; on error we free it.
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

    /// CoreDeviceProxy route for an RPPairing-only file, using a lockdown pair
    /// record created by this app.
    ///
    /// The record is stored and reused, because creating one shows a Trust
    /// prompt and uses a pairing slot. A new one is created only when the stored
    /// record no longer opens a tunnel (e.g. after a reset or restore).
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

    /// Runs the lockdown `Pair` handshake directly on lockdownd's port, with no
    /// tunnel (unlike `lockdownPairRecord`, which needs one).
    ///
    /// Blocks while the device shows the Trust prompt. Tries each host in order
    /// (e.g. the VPN peer, then 127.0.0.1) and returns the first record created.
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

        // `lockdownd_new` takes ownership of the socket, so it's never freed here.
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
        // End location simulation first; its handles use the tunnel.
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
        /// Nil if `EnableWifiDebugging` was set, otherwise the error. Apps using
        /// the record need it enabled, but the record is still returned since
        /// the setting may already be on.
        let wirelessLockdownError: String?
    }

    /// Runs the lockdown `Pair` handshake over the RSD tunnel, then enables
    /// wireless lockdown (as iLoader does).
    ///
    /// Produces the classic record (certificates, HostID, SystemBUID, escrow bag)
    /// that minimuxer and Feather need. Blocks while the device shows the Trust
    /// prompt.
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

    /// Sets `EnableWifiDebugging` so lockdownd accepts network connections, not
    /// just USB.
    ///
    /// Tries without `StartSession` first: over RSD the connection is already
    /// trusted, and a session would nest TLS inside TLS. Falls back to a session
    /// if the plain request is refused.
    private func enableWirelessLockdown(pairRecord: OpaquePointer) throws {
        do {
            try setWirelessLockdown(startingSessionWith: nil)
        } catch let sessionless {
            do {
                try setWirelessLockdown(startingSessionWith: pairRecord)
            } catch {
                // Report both errors.
                throw fail("without a session: \(sessionless); with one: \(error)")
            }
        }
    }

    /// One `SetValue` attempt on a new lockdown client (a client that ran `Pair`
    /// or a failed request can't be reused).
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

    /// Installed apps as log lines. `applicationType` nil = all.
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

    /// Every installed app's full installation_proxy plist, including
    /// `Entitlements` and `ProfileValidated`, which identify sideloaded apps.
    ///
    /// Each plist is converted to binary and decoded with
    /// `PropertyListSerialization` rather than walked with the plist C API.
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
        // The host app is sideloaded, so it's a user app. Leaving system apps out
        // keeps installd's reply a fraction of the size.
        try check("User".withCString { installation_proxy_get_apps(client, $0, nil, 0, &result, &count) },
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

        let mode = UploadMode.current
        let uploadStart = Date()
        let staged: StagedPackage
        switch mode {
        case .files:
            staged = try stageSequentially(bundlePath)
        case let .parallel(connections):
            staged = try stageInParallel(bundlePath, connections: connections)
        case let .archive(level):
            staged = try stageAsArchive(bundlePath, level: level)
        }
        Engine.shared.log(String(format: "Uploaded %d files (%.1f MB sent) in %.2f s [%@].",
                                 staged.totals.files, Double(staged.totals.bytes) / 1_048_576,
                                 Date().timeIntervalSince(uploadStart), mode.description))

        var ip: OpaquePointer?
        try check(installation_proxy_connect_rsd(adapter, handshake, &ip),
                  "installation_proxy_connect_rsd failed")
        guard let ip else { throw fail("installation_proxy client was null") }
        defer { installation_proxy_client_free(ip) }

        guard let options = installOptions(for: staged) else {
            throw fail("couldn't build install ClientOptions")
        }
        defer { plist_free(options) }

        let installStart = Date()
        try staged.remotePath.withCString { p in
            try check(installation_proxy_install_with_callback(ip, p, options, installProgressCb, nil),
                      "installation_proxy install failed")
        }
        Engine.shared.log(String(format: "installd finished in %.2f s.", Date().timeIntervalSince(installStart)))
    }

    /// What an upload sent, for the log.
    private struct UploadTotals {
        var files = 0
        var bytes = 0
    }

    /// A bundle waiting in /PublicStaging for installation_proxy.
    private struct StagedPackage {
        let remotePath: String
        let totals: UploadTotals
        let isArchive: Bool
        let bundleID: String?
    }

    /// TEMPORARY, for timing on a device: how a bundle reaches /PublicStaging,
    /// read from SIDEINSTALLER_UPLOAD (files | parallel:N | archive:LEVEL).
    private enum UploadMode: CustomStringConvertible {
        case files
        case parallel(Int)
        case archive(Int32)

        static var current: UploadMode {
            let raw = ProcessInfo.processInfo.environment["SIDEINSTALLER_UPLOAD"] ?? "files"
            let parts = raw.split(separator: ":").map(String.init)
            switch parts.first {
            case "parallel": return .parallel(max(1, Int(parts.last ?? "") ?? 4))
            case "archive":  return .archive(Int32(parts.last ?? "") ?? 0)
            default:         return .files
            }
        }

        var description: String {
            switch self {
            case .files:              return "files"
            case let .parallel(n):    return "parallel:\(n)"
            case let .archive(level): return "archive:\(level)"
            }
        }
    }

    /// installation_proxy options for a developer-signed bundle. Without
    /// `PackageType: Developer`, installd never reads the embedded profile and
    /// rejects a directory upload with 0xe8008015 at VerifyingApplication.
    private func installOptions(for staged: StagedPackage) -> plist_t? {
        guard let options: plist_t = plist_new_dict() else { return nil }
        // TEMPORARY: which options an archive gets, from SIDEINSTALLER_IPA_OPTIONS.
        let archiveOptions = ProcessInfo.processInfo.environment["SIDEINSTALLER_IPA_OPTIONS"] ?? "developer"
        // The dict takes ownership of the value node, so freeing it is enough.
        if !staged.isArchive || archiveOptions.contains("developer") {
            plist_dict_set_item(options, "PackageType", plist_new_string("Developer"))
        }
        if staged.isArchive, archiveOptions.contains("bundle"), let id = staged.bundleID {
            plist_dict_set_item(options, "CFBundleIdentifier", plist_new_string(id))
        }
        return options
    }

    /// One file or directory inside a bundle, relative to its root.
    private struct BundleEntry {
        let relativePath: String
        let isDirectory: Bool
        let size: Int
        let permissions: UInt16
    }

    /// Every directory and file under `root`, parents before their contents.
    private func bundleEntries(_ root: String) throws -> [BundleEntry] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(atPath: root) else { throw fail("couldn't list \(root)") }
        var entries: [BundleEntry] = []
        for case let relative as String in walker {
            let path = (root as NSString).appendingPathComponent(relative)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }
            let attrs = try fm.attributesOfItem(atPath: (path as NSString).resolvingSymlinksInPath)
            let fallback = isDir.boolValue ? 0o755 : 0o644
            entries.append(BundleEntry(relativePath: relative,
                                       isDirectory: isDir.boolValue,
                                       size: isDir.boolValue ? 0 : ((attrs[.size] as? Int) ?? 0),
                                       permissions: UInt16((attrs[.posixPermissions] as? Int) ?? fallback)))
        }
        return entries
    }

    private func bundleIdentifier(_ bundlePath: String) -> String? {
        let url = URL(fileURLWithPath: bundlePath).appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleIdentifier"] as? String
    }

    /// The bundle as a directory tree, one file after another on one AFC client.
    private func stageSequentially(_ bundlePath: String) throws -> StagedPackage {
        guard let adapter, let handshake else { throw fail("not connected") }
        var afc: OpaquePointer?
        try check(afc_client_connect_rsd(adapter, handshake, &afc), "afc_client_connect_rsd failed")
        guard let afc else { throw fail("AFC client was null") }
        defer { afc_client_free(afc) }

        let remoteRoot = "/PublicStaging/\((bundlePath as NSString).lastPathComponent)"
        var totals = UploadTotals()
        try uploadDirectory(afc, localDir: bundlePath, remoteDir: remoteRoot, totals: &totals)
        return StagedPackage(remotePath: remoteRoot, totals: totals, isArchive: false, bundleID: nil)
    }

    /// The bundle as a directory tree, its files spread over several AFC clients.
    private func stageInParallel(_ bundlePath: String, connections: Int) throws -> StagedPackage {
        guard let adapter, let handshake else { throw fail("not connected") }
        let remoteRoot = "/PublicStaging/\((bundlePath as NSString).lastPathComponent)"
        let entries = try bundleEntries(bundlePath)

        // Opened one at a time: the FFI takes the adapter exclusively while it
        // connects a stream. Once open, each client is independent.
        var clients: [OpaquePointer] = []
        defer { clients.forEach { afc_client_free($0) } }
        for _ in 0..<connections {
            var afc: OpaquePointer?
            try check(afc_client_connect_rsd(adapter, handshake, &afc), "afc_client_connect_rsd failed")
            guard let afc else { throw fail("AFC client was null") }
            clients.append(afc)
        }

        // Every directory exists before any file lands in it.
        _ = remoteRoot.withCString { afc_make_directory(clients[0], $0) }
        for entry in entries where entry.isDirectory {
            _ = "\(remoteRoot)/\(entry.relativePath)".withCString { afc_make_directory(clients[0], $0) }
        }

        // Biggest files first, each to the lane carrying the least so far.
        var lanes = Array(repeating: [BundleEntry](), count: clients.count)
        var load = Array(repeating: 0, count: clients.count)
        for file in entries.filter({ !$0.isDirectory }).sorted(by: { $0.size > $1.size }) {
            let lane = load.indices.min { load[$0] < load[$1] } ?? 0
            lanes[lane].append(file)
            load[lane] += file.size
        }

        let lock = NSLock()
        var totals = UploadTotals()
        var firstError: Error?
        DispatchQueue.concurrentPerform(iterations: clients.count) { lane in
            for file in lanes[lane] {
                lock.lock()
                let stop = firstError != nil
                lock.unlock()
                if stop { return }
                do {
                    let bytes = try uploadFile(clients[lane],
                                               localPath: (bundlePath as NSString).appendingPathComponent(file.relativePath),
                                               remotePath: "\(remoteRoot)/\(file.relativePath)")
                    lock.lock()
                    totals.files += 1
                    totals.bytes += bytes
                    lock.unlock()
                } catch {
                    lock.lock()
                    if firstError == nil { firstError = error }
                    lock.unlock()
                    return
                }
            }
        }
        if let firstError { throw firstError }
        return StagedPackage(remotePath: remoteRoot, totals: totals, isArchive: false, bundleID: nil)
    }

    /// The bundle as one zip archive, built while it's written into a single
    /// AFC file, so nothing is copied to disk first.
    private func stageAsArchive(_ bundlePath: String, level: Int32) throws -> StagedPackage {
        guard let adapter, let handshake else { throw fail("not connected") }
        var afc: OpaquePointer?
        try check(afc_client_connect_rsd(adapter, handshake, &afc), "afc_client_connect_rsd failed")
        guard let afc else { throw fail("AFC client was null") }
        defer { afc_client_free(afc) }

        let appName = (bundlePath as NSString).lastPathComponent
        let remotePath = "/PublicStaging/\((appName as NSString).deletingPathExtension).ipa"
        _ = "/PublicStaging".withCString { afc_make_directory(afc, $0) }
        var opened: OpaquePointer?
        try check(remotePath.withCString { afc_file_open(afc, $0, AfcWrOnly, &opened) },
                  "afc_file_open \(remotePath) failed")
        guard let handle = opened else { throw fail("AFC file handle was null") }
        // afc_file_close consumes the handle, so it's closed exactly once.
        var closed = false
        defer { if !closed { _ = afc_file_close(handle) } }

        let zip = ZipStream { chunk in
            guard let base = chunk.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            try self.check(afc_file_write(handle, base, chunk.count), "afc_file_write failed")
        }
        try zip.addDirectory("Payload/")
        try zip.addDirectory("Payload/\(appName)/")
        var totals = UploadTotals()
        for entry in try bundleEntries(bundlePath) {
            let name = "Payload/\(appName)/\(entry.relativePath)"
            if entry.isDirectory {
                try zip.addDirectory(name + "/", permissions: entry.permissions)
            } else {
                let url = URL(fileURLWithPath: (bundlePath as NSString).appendingPathComponent(entry.relativePath))
                // Mapped, not read: a tens-of-megabytes binary on the heap risks a jetsam.
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                try zip.addFile(name, data: data, permissions: entry.permissions, level: level)
                totals.files += 1
            }
        }
        totals.bytes = try zip.finish()
        closed = true
        try check(afc_file_close(handle), "afc_file_close failed (archive not committed)")
        return StagedPackage(remotePath: remotePath, totals: totals, isArchive: true,
                             bundleID: bundleIdentifier(bundlePath))
    }

    /// Recursively upload a local directory tree to AFC.
    private func uploadDirectory(_ afc: OpaquePointer, localDir: String, remoteDir: String,
                                 totals: inout UploadTotals) throws {
        _ = remoteDir.withCString { afc_make_directory(afc, $0) }  // ok if exists
        let fm = FileManager.default
        let entries = try fm.contentsOfDirectory(atPath: localDir)
        for entry in entries {
            let localPath = (localDir as NSString).appendingPathComponent(entry)
            let remotePath = "\(remoteDir)/\(entry)"
            var isDir: ObjCBool = false
            fm.fileExists(atPath: localPath, isDirectory: &isDir)
            if isDir.boolValue {
                try uploadDirectory(afc, localDir: localPath, remoteDir: remotePath, totals: &totals)
            } else {
                totals.bytes += try uploadFile(afc, localPath: localPath, remotePath: remotePath)
                totals.files += 1
            }
        }
    }

    /// Returns the number of bytes written.
    private func uploadFile(_ afc: OpaquePointer, localPath: String, remotePath: String) throws -> Int {
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
        return data.count
    }

    // MARK: Write pairing file into another app's container (house_arrest)

    /// Writes the file at `pairingFilePath` into `bundleID`'s Documents and
    /// returns the verified byte count. See `writeFile`.
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

    /// Writes `data` into `bundleID`'s Documents at `remoteRelativePath`, reads
    /// it back to verify, and returns the byte count.
    ///
    /// `house_arrest_vend_documents` consumes the HouseArrestClient on success
    /// and failure, so `ha` is never freed. `afc_file_close` and
    /// `afc_client_free` each consume their handle once.
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

    /// Mounts the personalized developer disk image (same as StikDebug): reads
    /// the UniqueChipID from lockdownd, then sends the image, trust cache,
    /// manifest and chip ID to image_mounter over the RSD tunnel.
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

// MARK: - Streaming zip

/// Builds a zip archive as it goes and hands it out in 1 MiB pieces, so a
/// bundle can be written straight into one AFC file. Entries are stored, or
/// deflated when that's smaller. No ZIP64: an app bundle stays far below 4 GB.
private final class ZipStream {
    enum Failure: Error { case tooLarge }

    private static let chunkSize = 1 << 20
    private static let utf8Names: UInt16 = 0x0800
    private static let dosTime: UInt16 = 0
    private static let dosDate: UInt16 = (46 << 9) | (1 << 5) | 1     // 2026-01-01
    private static let madeByUnix: UInt16 = (3 << 8) | 20

    private let emit: (UnsafeRawBufferPointer) throws -> Void
    private var pending = Data()
    private var written = 0
    private var centralDirectory = Data()
    private var entryCount = 0

    init(emit: @escaping (UnsafeRawBufferPointer) throws -> Void) {
        self.emit = emit
        pending.reserveCapacity(Self.chunkSize)
    }

    func addDirectory(_ name: String, permissions: UInt16 = 0o755) throws {
        let attributes = (UInt32(0o040000) | UInt32(permissions)) << 16 | 0x10
        try addEntry(name: name, method: 0, crc: 0, compressedSize: 0, size: 0,
                     externalAttributes: attributes, body: nil)
    }

    func addFile(_ name: String, data: Data, permissions: UInt16, level: Int32) throws {
        let attributes = (UInt32(0o100000) | UInt32(permissions)) << 16
        try data.withUnsafeBytes { raw in
            let crc = Self.checksum(raw)
            if level > 0, let packed = Self.deflated(raw, level: level), packed.count < raw.count {
                try packed.withUnsafeBytes { body in
                    try addEntry(name: name, method: 8, crc: crc, compressedSize: body.count,
                                 size: raw.count, externalAttributes: attributes, body: body)
                }
            } else {
                try addEntry(name: name, method: 0, crc: crc, compressedSize: raw.count,
                             size: raw.count, externalAttributes: attributes, body: raw)
            }
        }
    }

    /// Writes the central directory and returns the archive's size in bytes.
    func finish() throws -> Int {
        let directoryOffset = written
        let directorySize = centralDirectory.count
        guard directoryOffset + directorySize < Int(UInt32.max), entryCount < Int(UInt16.max) else {
            throw Failure.tooLarge
        }
        try write(centralDirectory)
        var end = Data()
        end.appendLE(UInt32(0x0605_4B50))
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(entryCount))
        end.appendLE(UInt16(entryCount))
        end.appendLE(UInt32(directorySize))
        end.appendLE(UInt32(directoryOffset))
        end.appendLE(UInt16(0))
        try write(end)
        if !pending.isEmpty {
            try pending.withUnsafeBytes { try emit($0) }
            pending.removeAll()
        }
        return written
    }

    private func addEntry(name: String, method: UInt16, crc: UInt32, compressedSize: Int, size: Int,
                          externalAttributes: UInt32, body: UnsafeRawBufferPointer?) throws {
        let nameBytes = Data(name.utf8)
        guard written + 30 + nameBytes.count + compressedSize < Int(UInt32.max),
              size < Int(UInt32.max), nameBytes.count < Int(UInt16.max) else {
            throw Failure.tooLarge
        }
        let offset = UInt32(written)

        var local = Data()
        local.appendLE(UInt32(0x0403_4B50))
        local.appendLE(UInt16(20))
        local.appendLE(Self.utf8Names)
        local.appendLE(method)
        local.appendLE(Self.dosTime)
        local.appendLE(Self.dosDate)
        local.appendLE(crc)
        local.appendLE(UInt32(compressedSize))
        local.appendLE(UInt32(size))
        local.appendLE(UInt16(nameBytes.count))
        local.appendLE(UInt16(0))
        local.append(nameBytes)
        try write(local)
        if let body { try write(body) }

        centralDirectory.appendLE(UInt32(0x0201_4B50))
        centralDirectory.appendLE(Self.madeByUnix)
        centralDirectory.appendLE(UInt16(20))
        centralDirectory.appendLE(Self.utf8Names)
        centralDirectory.appendLE(method)
        centralDirectory.appendLE(Self.dosTime)
        centralDirectory.appendLE(Self.dosDate)
        centralDirectory.appendLE(crc)
        centralDirectory.appendLE(UInt32(compressedSize))
        centralDirectory.appendLE(UInt32(size))
        centralDirectory.appendLE(UInt16(nameBytes.count))
        centralDirectory.appendLE(UInt16(0))                // extra field
        centralDirectory.appendLE(UInt16(0))                // comment
        centralDirectory.appendLE(UInt16(0))                // disk number
        centralDirectory.appendLE(UInt16(0))                // internal attributes
        centralDirectory.appendLE(externalAttributes)
        centralDirectory.appendLE(offset)
        centralDirectory.append(nameBytes)
        entryCount += 1
    }

    private func write(_ data: Data) throws {
        try data.withUnsafeBytes { try write($0) }
    }

    /// Emits whole chunks straight from `bytes` where it can, so a large file
    /// isn't copied into `pending` first.
    private func write(_ bytes: UnsafeRawBufferPointer) throws {
        guard bytes.count > 0 else { return }
        written += bytes.count
        var rest = bytes[...]
        if !pending.isEmpty {
            let take = min(Self.chunkSize - pending.count, rest.count)
            pending.append(contentsOf: UnsafeRawBufferPointer(rebasing: rest.prefix(take)))
            rest = rest.dropFirst(take)
            guard pending.count == Self.chunkSize else { return }
            try pending.withUnsafeBytes { try emit($0) }
            pending.removeAll(keepingCapacity: true)
        }
        while rest.count >= Self.chunkSize {
            try emit(UnsafeRawBufferPointer(rebasing: rest.prefix(Self.chunkSize)))
            rest = rest.dropFirst(Self.chunkSize)
        }
        if !rest.isEmpty {
            pending.append(contentsOf: UnsafeRawBufferPointer(rebasing: rest))
        }
    }

    private static func checksum(_ bytes: UnsafeRawBufferPointer) -> UInt32 {
        var crc = zlib.crc32(0, nil, 0)
        guard let base = bytes.baseAddress?.assumingMemoryBound(to: Bytef.self) else {
            return UInt32(truncatingIfNeeded: crc)
        }
        var offset = 0
        while offset < bytes.count {
            let n = min(bytes.count - offset, Int(Int32.max))
            crc = zlib.crc32(crc, base + offset, uInt(n))
            offset += n
        }
        return UInt32(truncatingIfNeeded: crc)
    }

    /// Raw DEFLATE, the form a zip entry holds, or nil if zlib refuses.
    private static func deflated(_ bytes: UnsafeRawBufferPointer, level: Int32) -> Data? {
        guard let base = bytes.baseAddress?.assumingMemoryBound(to: Bytef.self),
              bytes.count < Int(UInt32.max) else { return nil }
        var stream = z_stream()
        guard deflateInit2_(&stream, level, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY,
                            ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return nil }
        defer { deflateEnd(&stream) }
        let bound = Int(deflateBound(&stream, uLong(bytes.count)))
        var out = Data(count: bound)
        let status: Int32 = out.withUnsafeMutableBytes { dst in
            stream.next_in = UnsafeMutablePointer(mutating: base)
            stream.avail_in = uInt(bytes.count)
            stream.next_out = dst.baseAddress?.assumingMemoryBound(to: Bytef.self)
            stream.avail_out = uInt(bound)
            return deflate(&stream, Z_FINISH)
        }
        guard status == Z_STREAM_END else { return nil }
        out.count = Int(stream.total_out)
        return out
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
