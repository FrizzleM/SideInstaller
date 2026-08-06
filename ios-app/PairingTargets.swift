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
