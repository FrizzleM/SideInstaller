import Foundation

/// One app that can receive the pairing file, as in iLoader's PAIRING_APPS
/// table. The file is written into its container over house_arrest/AFC.
struct PairingTargetApp: Identifiable, Equatable {
    /// The display name the installed app reports, matched on and shown.
    let name: String
    /// Where the pairing file must land, relative to the app's Documents dir.
    let remoteRelativePath: String
    /// Restricts the entry to bundle ids containing this, which splits
    /// StikDebug's App Store and sideloaded builds — they read different paths.
    let bundleIDContains: String?

    var id: String { name }

    /// Where SideStore lives in this app, for the apps that carry it.
    var sideStoreHome: SideStoreHome? {
        switch name {
        case "SideStore":     return .standalone
        case "LiveContainer": return .liveContainer
        default:              return nil
        }
    }

    /// The supported apps, in display order. `StikDebug (Sideloaded)` is
    /// reached only through the bundle-id check in `PairingTargets.match`.
    static let all: [PairingTargetApp] = [
        .init(name: "SideStore",
              remoteRelativePath: "ALTPairingFile.mobiledevicepairing",
              bundleIDContains: nil),
        .init(name: "LiveContainer",
              remoteRelativePath: "SideStore/Documents/ALTPairingFile.mobiledevicepairing",
              bundleIDContains: nil),
        .init(name: "Feather",
              remoteRelativePath: "pairingFile.plist",
              bundleIDContains: nil),
        .init(name: "StikDebug",
              remoteRelativePath: "pairingFile.plist",
              bundleIDContains: nil),
        .init(name: "StikDebug (Sideloaded)",
              remoteRelativePath: "rp_pairing_file.plist",
              bundleIDContains: "com.stik.stikdebug"),
        .init(name: "StikTest",
              remoteRelativePath: "stiktest_pairing.plist",
              bundleIDContains: nil),
        .init(name: "Protokolle",
              remoteRelativePath: "pairingFile.plist",
              bundleIDContains: nil),
        .init(name: "Antrag",
              remoteRelativePath: "pairingFile.plist",
              bundleIDContains: nil),
        .init(name: "SparseBox",
              remoteRelativePath: "pairingFile.plist",
              bundleIDContains: nil),
        .init(name: "StikStore",
              remoteRelativePath: "pairingFile.plist",
              bundleIDContains: nil),
        .init(name: "ByeTunes",
              remoteRelativePath: "pairing file/pairingFile.plist",
              bundleIDContains: nil),
        .init(name: "Reynard",
              remoteRelativePath: "pairingFile.plist",
              bundleIDContains: nil),
        .init(name: "PanicAnalyzer",
              remoteRelativePath: "pairingFile.plist",
              bundleIDContains: nil),
    ]
}

/// A table entry paired with the bundle id installation_proxy reported for it.
struct InstalledPairingTarget: Identifiable, Equatable {
    let app: PairingTargetApp
    let bundleID: String

    var id: String { bundleID }
    var name: String { app.name }
    var remoteRelativePath: String { app.remoteRelativePath }
}

enum PairingTargets {

    /// Match the installed apps against `PairingTargetApp.all` by display name,
    /// mapping sideloaded StikDebug to its own entry. Keeps the table's order.
    static func match(installed apps: [DeviceConnection.InstalledApp]) -> [InstalledPairingTarget] {
        var out: [InstalledPairingTarget] = []
        var seen = Set<String>()

        for app in apps {
            guard let display = app.displayName else { continue }

            let entry: PairingTargetApp?
            if display == "StikDebug" {
                let sideloaded = app.bundleID.contains("com.stik.stikdebug")
                entry = PairingTargetApp.all.first {
                    $0.name == (sideloaded ? "StikDebug (Sideloaded)" : "StikDebug")
                }
            } else {
                // Plain entries only, skipping the bundle-id-gated variant.
                entry = PairingTargetApp.all.first { $0.name == display && $0.bundleIDContains == nil }
            }

            guard let entry, seen.insert(entry.name).inserted else { continue }
            out.append(InstalledPairingTarget(app: entry, bundleID: app.bundleID))
        }

        return out.sorted {
            (PairingTargetApp.all.firstIndex(of: $0.app) ?? .max)
                < (PairingTargetApp.all.firstIndex(of: $1.app) ?? .max)
        }
    }
}

/// Which records a pairing file contains. Determines the tunnel route
/// (RPPairing, or CoreDeviceProxy over lockdown) and whether AltStore-family
/// apps can read the file as-is.
struct PairingFileKind {

    /// RPPairing record (`public_key`, `private_key`, `identifier`), used by
    /// `tunnel_create_rppairing`. Created by on-device pairing (iOS 27+), so
    /// imported files rarely have it.
    let hasRemotePairing: Bool
    /// Lockdown record (`HostCertificate`, `HostPrivateKey`, `DeviceCertificate`),
    /// as written by jitterbugpair, pymobiledevice3 and idevicepair. Used by the
    /// CoreDeviceProxy route, and read by minimuxer (SideStore, LiveContainer)
    /// and Feather.
    let hasLockdown: Bool
    /// The device's UDID, if the file includes one.
    let udid: String?

    /// True when at least one record is there to connect with.
    var isUsable: Bool { hasRemotePairing || hasLockdown }

    /// Nothing at all — a file that isn't a pairing file, or isn't a plist.
    static let none = PairingFileKind(hasRemotePairing: false, hasLockdown: false, udid: nil)

    static func of(path: String) -> PairingFileKind {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return .none }
        return of(data: data)
    }

    static func of(data: Data) -> PairingFileKind {
        guard !data.isEmpty,
              let parsed = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = parsed as? [String: Any]
        else { return .none }

        // idevice rejects a key that isn't exactly 32 bytes, so check the length
        // here too rather than calling a file usable that it will refuse.
        let ed25519 = { (key: String) in (dict[key] as? Data)?.count == 32 }
        let remote = ed25519("public_key") && ed25519("private_key")
            && (dict["identifier"] as? String)?.isEmpty == false

        let present = { (key: String) in
            // Both plist parsers accept these as data; XML plists from some
            // tools carry the PEM as a string instead.
            (dict[key] as? Data)?.isEmpty == false || (dict[key] as? String)?.isEmpty == false
        }
        let lockdown = present("HostCertificate") && present("HostPrivateKey")
            && present("DeviceCertificate")

        let udid = (dict["UDID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return PairingFileKind(hasRemotePairing: remote, hasLockdown: lockdown, udid: udid)
    }
}

/// The pairing file given to other apps: RPPairing and lockdown records merged
/// into one plist.
///
/// SideInstaller's tunnel and StikDebug (sideloaded) use the RPPairing keys
/// (`public_key`, `private_key`, `identifier`, `alt_irk`). minimuxer (SideStore,
/// LiveContainer) and Feather use the lockdown record (HostID, SystemBUID,
/// certificates and keys, escrow bag, UDID).
///
/// As in iLoader, both go in one plist; each parser ignores keys it doesn't use.
enum CompositePairingFile {

    /// UDID the cached lockdown record belongs to, so a different (or wiped)
    /// device pairs again instead of reusing it.
    private static let udidKey = "lockdownPairRecordUDID"
    private static let hostIDKey = "lockdownHostID"
    private static let systemBUIDKey = "lockdownSystemBUID"

    enum BuildError: LocalizedError {
        case notAPlistDictionary(String)

        var errorDescription: String? {
            switch self {
            case let .notAPlistDictionary(what):
                return L("The %@ record isn't a plist dictionary.", what)
            }
        }
    }

    // MARK: Host identity

    /// This host's lockdown HostID and SystemBUID, generated once and persisted
    /// so re-pairing replaces the device's record instead of using another slot.
    /// Uppercase UUIDs, as usbmuxd uses.
    static var hostID: String { persistentUUID(forKey: hostIDKey) }
    static var systemBUID: String { persistentUUID(forKey: systemBUIDKey) }

    private static func persistentUUID(forKey key: String) -> String {
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            return stored
        }
        let fresh = UUID().uuidString      // already uppercase
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    // MARK: The cached classic half

    /// The stored lockdown record, if it belongs to `udid`. Only the record is
    /// cached (pairing needs a Trust tap); merging is cheap and redone each time.
    static func cachedLockdownRecord(forUDID udid: String?) -> Data? {
        guard let udid, !udid.isEmpty,
              UserDefaults.standard.string(forKey: udidKey) == udid,
              let data = try? Data(contentsOf: PrivateStore.lockdownPairRecord),
              !data.isEmpty
        else { return nil }
        return data
    }

    static func storeLockdownRecord(_ data: Data, forUDID udid: String?) throws {
        try data.write(to: PrivateStore.lockdownPairRecord, options: .atomic)
        UserDefaults.standard.set(udid ?? "", forKey: udidKey)
    }

    // MARK: Merging

    /// Merge a classic lockdown record with an RPPairing record and stamp in the
    /// UDID, which the classic `Pair` response doesn't carry and minimuxer needs.
    /// The RPPairing keys win on a collision, as in iLoader's
    /// `plist!(dict { :< lockdown_plist, :< rppairing_plist })`.
    static func merge(lockdown: Data, rpPairing: Data, udid: String?) throws -> Data {
        var merged = try dictionary(from: lockdown, describing: "lockdown")
        for (key, value) in try dictionary(from: rpPairing, describing: "RPPairing") {
            merged[key] = value
        }
        if let udid, !udid.isEmpty, (merged["UDID"] as? String)?.isEmpty != false {
            merged["UDID"] = udid
        }
        // XML, not binary: SideStore reads the file as a UTF-8 string and hands
        // that string, not the bytes, to minimuxer.
        return try PropertyListSerialization.data(fromPropertyList: merged,
                                                  format: .xml,
                                                  options: 0)
    }

    /// Adds `udid` to a record that has no UDID (minimuxer needs it). Returns the
    /// data unchanged if a UDID is already present.
    static func stampingUDID(_ udid: String, into data: Data) throws -> Data {
        var dict = try dictionary(from: data, describing: "pairing")
        guard (dict["UDID"] as? String)?.isEmpty != false else { return data }
        dict["UDID"] = udid
        // XML, for the same reason as in `merge`.
        return try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    private static func dictionary(from data: Data, describing what: String) throws -> [String: Any] {
        let parsed = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = parsed as? [String: Any] else {
            throw BuildError.notAPlistDictionary(what)
        }
        return dict
    }

    // MARK: The merged file on disk

    /// Write the merged record out and return its path.
    static func store(_ data: Data) throws -> String {
        try data.write(to: PrivateStore.combinedPairingFile, options: .atomic)
        return PrivateStore.combinedPairingFile.path
    }

    /// Path of the merged file, if it exists and isn't empty. Used by Export.
    static func existingPath() -> String? {
        let url = PrivateStore.combinedPairingFile
        let size = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int) ?? 0
        return size > 0 ? url.path : nil
    }

    /// Deletes the merged file (e.g. after a new RPPairing record). The cached
    /// lockdown record is kept.
    static func invalidateMerged() {
        try? FileManager.default.removeItem(at: PrivateStore.combinedPairingFile)
    }
}

/// Where SideStore lives inside the app that receives the pairing file.
enum SideStoreHome {
    /// SideStore installed on its own.
    case standalone
    /// SideStore as LiveContainer's built-in guest, whose home folder is
    /// Documents/SideStore in LiveContainer's container.
    case liveContainer

    /// SideStore's Documents, relative to the host app's Documents.
    var documentsPrefix: String {
        switch self {
        case .standalone:    return ""
        case .liveContainer: return "SideStore/Documents/"
        }
    }

    /// SideStore's settings plist, relative to the host app's container root.
    /// LiveContainer keeps a guest's settings in the guest's home folder, named
    /// after its bundle id, which signing leaves unchanged for frameworks.
    func preferencesPath(hostBundleID: String) -> String {
        switch self {
        case .standalone:    return "Library/Preferences/\(hostBundleID).plist"
        case .liveContainer: return "Documents/SideStore/Library/Preferences/com.SideStore.SideStore.plist"
        }
    }
}

/// The pairing hand-off SideStore expects from nightly 0.7.0-20260920 on.
///
/// Those builds ignore `ALTPairingFile.mobiledevicepairing`, which older builds
/// (and LiveContainer's built-in SideStore, so far) still read. They keep one
/// file per protocol, reject a file holding both records as ambiguous, and load
/// neither until an import has turned `isPairingReset` off (it defaults to on)
/// and recorded the file's protocol in `activePairingProtocol`. So each record
/// goes in its own file, and both settings are written into SideStore's
/// preferences, as its own import does.
enum SideStorePairingHandoff {

    static let lockdownFileName = "PairingFile_Lockdown.plist"
    static let remoteFileName = "PairingFile_RemoteRP.plist"

    /// The keys minimuxer requires for each protocol (MinimuxerCommon's
    /// `PairingFile.swift`).
    private static let requiredLockdownKeys = [
        "WiFiMACAddress", "SystemBUID", "RootPrivateKey", "HostPrivateKey", "HostID",
        "RootCertificate", "UDID", "EscrowBag", "HostCertificate", "DeviceCertificate",
    ]
    private static let requiredRemoteKeys = ["private_key", "public_key", "identifier"]
    /// Every RPPairing key, including the optional `alt_irk`.
    private static let remoteKeys: Set<String> = ["private_key", "public_key", "identifier", "alt_irk"]

    /// The records split out of the pairing file, each an XML plist (SideStore
    /// reads the file as a UTF-8 string).
    struct Records {
        /// The lockdown record alone, or nil if the file has no complete one.
        let lockdown: Data?
        /// The RPPairing record alone, or nil if the file has none.
        let remote: Data?
        /// Keys missing from a partial lockdown record, for the log.
        let missingLockdownKeys: [String]

        /// The protocol SideStore should load. Lockdown goes first: SideStore
        /// reaches lockdownd over the loopback VPN, while the RPPairing listener
        /// can refuse a tunnel from the device itself.
        var activeProtocol: String? {
            if lockdown != nil { return "lockdown" }
            if remote != nil { return "rppairing" }
            return nil
        }
    }

    /// Splits a pairing file (lockdown, RPPairing, or both merged) into one
    /// record per protocol, adding the UDID the lockdown record needs if missing.
    static func split(_ data: Data, udid: String?) throws -> Records {
        let parsed = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = parsed as? [String: Any] else {
            throw CompositePairingFile.BuildError.notAPlistDictionary("pairing")
        }

        var lockdownDict = dict.filter { !remoteKeys.contains($0.key) }
        if let udid, !udid.isEmpty, (lockdownDict["UDID"] as? String)?.isEmpty != false {
            lockdownDict["UDID"] = udid
        }
        let missingLockdown = requiredLockdownKeys.filter { lockdownDict[$0] == nil }
        // A file with no lockdown keys at all isn't missing anything worth logging.
        let hasAnyLockdown = requiredLockdownKeys.contains { $0 != "UDID" && lockdownDict[$0] != nil }

        let remoteDict = dict.filter { remoteKeys.contains($0.key) }
        let hasRemote = requiredRemoteKeys.allSatisfy { remoteDict[$0] != nil }

        return Records(
            lockdown: missingLockdown.isEmpty ? try xml(lockdownDict) : nil,
            remote: hasRemote ? try xml(remoteDict) : nil,
            missingLockdownKeys: hasAnyLockdown ? missingLockdown : []
        )
    }

    /// Sets what SideStore's own import sets: pairing no longer reset, and the
    /// protocol whose file to load. A protocol picked in SideStore's settings
    /// lives in `preferredPairingProtocol`, which is left alone.
    static func applySettings(to prefs: inout [String: Any], activeProtocol: String) {
        prefs["isPairingReset"] = false
        prefs["activePairingProtocol"] = activeProtocol
    }

    private static func xml(_ dict: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }
}
