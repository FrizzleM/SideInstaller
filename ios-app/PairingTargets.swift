import Foundation

/// One app that can receive the device pairing file, ported 1:1 from iLoader's
/// PAIRING_APPS table (src-tauri/src/pairing.rs). The pairing file is written
/// into the app's container at `remoteRelativePath` (relative to its Documents
/// directory) over the same house_arrest/AFC path the SideStore install uses.
struct PairingTargetApp: Identifiable, Equatable {
    /// CFBundleDisplayName the installed app reports — both how it's matched and
    /// how it's shown. (iLoader resolves targets by display name, not bundle id.)
    let name: String
    /// Where the pairing file must land, relative to the app's Documents dir.
    let remoteRelativePath: String
    /// When set, this entry only applies to an installed app whose bundle id
    /// contains this substring. Used to split StikDebug into its App Store and
    /// sideloaded variants, which read the pairing file from different paths.
    let bundleIDContains: String?

    var id: String { name }

    /// The supported apps, in display order (mirrors iLoader's PAIRING_APPS).
    /// The `StikDebug (Sideloaded)` entry is reached only via the bundle-id check
    /// in `PairingTargets.match` — no app reports that display name directly.
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
        .init(name: "StikDebug (Sideloaded)",
              remoteRelativePath: "rp_pairing_file.plist",
              bundleIDContains: "com.stik.stikdebug"),
        .init(name: "StikDebug",
              remoteRelativePath: "pairingFile.plist",
              bundleIDContains: nil),
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

/// A supported app that's actually installed on the connected device — pairs a
/// table entry with the exact bundle id installation_proxy reported, which is
/// what the pairing-file write vends house_arrest for.
struct InstalledPairingTarget: Identifiable, Equatable {
    let app: PairingTargetApp
    let bundleID: String

    var id: String { bundleID }
    var name: String { app.name }
    var remoteRelativePath: String { app.remoteRelativePath }
}

enum PairingTargets {

    /// Match the device's installed apps against `PairingTargetApp.all` exactly
    /// the way iLoader does: by CFBundleDisplayName. StikDebug is special-cased —
    /// the sideloaded build (bundle id contains `com.stik.stikdebug`) reads the
    /// file from a different path than the App Store build, so it maps to the
    /// `StikDebug (Sideloaded)` entry. Results keep the table's order and are
    /// de-duplicated by entry.
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
                // Plain entries only (skip the bundle-id-gated StikDebug variant).
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
