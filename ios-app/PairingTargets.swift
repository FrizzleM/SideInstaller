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

/// The pairing file handed to other apps, which is two records in one plist.
///
/// SideInstaller pairs with this iPhone over RPPairing, and that record —
/// `public_key`, `private_key`, `identifier`, `alt_irk` — is all its own RSD
/// tunnel needs, and all StikDebug's sideloaded build reads. Every other
/// supported app reads a *classic* lockdown record instead: minimuxer (SideStore
/// and LiveContainer + SideStore) and Feather want HostID, SystemBUID, the
/// host/root/device certificates and keys, the escrow bag and the UDID.
///
/// iLoader ships both halves in one plist, and each reader ignores what it
/// doesn't know — idevice's RPPairing parser takes its four keys and drops the
/// rest, and the classic parser is a serde struct that skips unknown fields.
/// This builds the same merged file.
enum CompositePairingFile {

    /// The UDID the cached lockdown record was minted for, so another device
    /// (or a wiped one) re-pairs instead of reusing a record it would reject.
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

    /// This host's lockdown identity, generated once and kept, so a re-pair
    /// replaces the device's record for us rather than orphaning it and
    /// spending another slot. usbmuxd writes both as uppercase UUIDs.
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

    /// The stored lockdown record, if one was minted for this same device.
    /// Pairing is the interactive, slot-consuming step, so only it is cached;
    /// the merge below is cheap enough to redo every time.
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

    /// The merged file already on disk, when there is a non-empty one. Behind
    /// the Export button, which should hand over the file that works everywhere.
    static func existingPath() -> String? {
        let url = PrivateStore.combinedPairingFile
        let size = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int) ?? 0
        return size > 0 ? url.path : nil
    }

    /// Drop the merged file. Called when a fresh RPPairing record makes the
    /// half of it that came from the old one wrong; the cached lockdown record
    /// stays, since re-pairing that way is interactive and costs a device slot.
    static func invalidateMerged() {
        try? FileManager.default.removeItem(at: PrivateStore.combinedPairingFile)
    }
}
