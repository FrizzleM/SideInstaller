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

    var isConnected: Bool { adapter != nil && handshake != nil }

    struct FFIError: Error, CustomStringConvertible {
        let code: Int32
        let subCode: Int32
        let message: String
        var description: String { "idevice FFI error code=\(code) sub=\(subCode): \(message)" }
    }

    /// Turn a returned IdeviceFfiError* into a thrown error (null == success).
    private func check(_ err: UnsafeMutablePointer<IdeviceFfiError>?, _ fallback: String) throws {
        guard let err = err else { return }
        let code = err.pointee.code
        let sub = err.pointee.sub_code
        let msg = err.pointee.message.flatMap { String(validatingUTF8: $0) } ?? fallback
        idevice_error_free(err)
        throw FFIError(code: code, subCode: sub, message: msg.isEmpty ? fallback : msg)
    }

    private func fail(_ message: String) -> FFIError {
        FFIError(code: -1, subCode: 0, message: message)
    }

    // MARK: Connect / disconnect

    /// Establish the loopback tunnel and RSD handshake.
    func connect(deviceIP: String, pairingFilePath: String, hostname: String = "SideInstaller") throws {
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

        var newAdapter: OpaquePointer?
        var newHandshake: OpaquePointer?
        let err = withUnsafePointer(to: &addr) { aptr in
            aptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                hostname.withCString { host in
                    // A nil pin_callback pair-verifies with the existing file.
                    tunnel_create_rppairing(
                        sa, socklen_t(MemoryLayout<sockaddr_in>.stride),
                        host, pairingFile, nil, nil,
                        &newAdapter, &newHandshake)
                }
            }
        }
        try check(err, "tunnel_create_rppairing failed (is a loopback VPN connected, Wi-Fi on, device IP \(deviceIP)?)")
        guard newAdapter != nil, newHandshake != nil else {
            throw fail("tunnel created without valid handles")
        }
        disconnect()
        adapter = newAdapter
        handshake = newHandshake
    }

    func disconnect() {
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
        guard let adapter, let handshake else { throw fail("not connected") }

        let data = try Data(contentsOf: URL(fileURLWithPath: pairingFilePath))
        guard !data.isEmpty else { throw fail("pairing file at \(pairingFilePath) is empty") }

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
