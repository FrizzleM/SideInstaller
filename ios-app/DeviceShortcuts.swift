import AppIntents
import Foundation
import UIKit
import UniformTypeIdentifiers

// MARK: - Tunnel, pairing and device actions
//
// LocalDevVPN, the pairing file (the Pairing page and the Install tab's
// pairing card), Developer Mode (Settings) and the activity log as Shortcuts
// actions.

// MARK: LocalDevVPN

struct IsTunnelConnectedIntent: AppIntent {
    static let title: LocalizedStringResource = "Is LocalDevVPN Connected"
    static let description = IntentDescription(
        "True while LocalDevVPN's tunnel is up, which every action that talks to this iPhone needs: location spoofing, refreshing, installing.",
        categoryName: "LocalDevVPN",
        searchKeywords: ["vpn", "tunnel", "status", "connected"])

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let engine = Engine.shared
        await engine.settleNetworkStatus()
        return .result(value: engine.vpnConnected)
    }
}

struct ConnectLocalDevVPNIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Connect LocalDevVPN"
    static let description = IntentDescription(
        "Connects LocalDevVPN's tunnel if it isn't up: SideInstaller opens LocalDevVPN, which connects and comes back. Nothing opens when it's already connected. Shortcuts' Set VPN action connects it without leaving Shortcuts.",
        categoryName: "LocalDevVPN",
        searchKeywords: ["vpn", "tunnel", "connect", "start"])

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        try await Shortcuts.run("Connect LocalDevVPN") {
            let engine = Engine.shared
            await engine.settleNetworkStatus()
            guard !engine.vpnConnected else { return }
            if !Shortcuts.isInForeground {
                try await requestToContinueInForeground(
                    Shortcuts.dialog(L("LocalDevVPN isn't connected. Continue in SideInstaller to connect it.")))
            }
            guard await engine.startLocalDevVPN() else {
                throw ShortcutError(L("Install LocalDevVPN from the App Store and open it."))
            }
            // Only time back in SideInstaller counts, as for an install, so
            // LocalDevVPN's own prompts don't use up the wait.
            var waited = 0.0
            while waited < 15 {
                try await Task.sleep(for: .milliseconds(500))
                engine.refreshNetworkStatus()
                if engine.vpnConnected { return }
                if Shortcuts.isInForeground { waited += 0.5 }
            }
            throw ShortcutError(L("LocalDevVPN isn't connected. Connect it, then try again."))
        }
        return .result(value: true, dialog: Shortcuts.dialog(L("LocalDevVPN is connected.")))
    }
}

// MARK: Pairing file

struct GetPairingFileIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Pairing File"
    static let description = IntentDescription(
        "Gives the pairing file SideInstaller connects to this iPhone with, as Export pairing file does: the one SideStore, StikDebug and other apps read, once it has been installed into one. Keep it private, as it lets its holder control this iPhone.",
        categoryName: "Pairing",
        searchKeywords: ["pairing", "export", "plist", "mobiledevicepairing", "stikdebug"])

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let file = try await Shortcuts.run("Get Pairing File") { () -> IntentFile in
            let path = PairingController.pairingFilePath()
            let size = ((try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int) ?? 0
            guard size > 0 else {
                throw ShortcutError(Engine.deviceCanSelfPair
                    ? L("No pairing file yet — tap “Generate pairing file” first.")
                    : L("No pairing file yet — tap “Import pairing file” first."))
            }
            // The merged file, when a write built it, reads in every app.
            let url = URL(fileURLWithPath: CompositePairingFile.existingPath() ?? path)
            return IntentFile(data: try Data(contentsOf: url), filename: url.lastPathComponent,
                              type: .propertyList)
        }
        return .result(value: file)
    }
}

struct ImportPairingFileIntent: AppIntent {
    static let title: LocalizedStringResource = "Import Pairing File"
    static let description = IntentDescription(
        "Makes a pairing file made elsewhere (iLoader, idevice_pair, jitterbugpair, pymobiledevice3…) the one SideInstaller uses, replacing the one it has, as Import pairing file does.",
        categoryName: "Pairing",
        searchKeywords: ["pairing", "import", "plist", "mobiledevicepairing"])

    // What the pairing-file picker takes (`UTType.pairingFileTypes`), and
    // plain data, as type identifiers: UTTypes need iOS 18 here.
    @Parameter(title: "Pairing File",
               supportedTypeIdentifiers: ["com.frizzlem.sideinstaller.mobiledevicepairing",
                                          "com.apple.property-list", "public.xml", "public.data"])
    var file: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Import \(\.$file)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await Shortcuts.run("Import Pairing File") {
            let copy = try Shortcuts.temporaryCopy(of: file, defaultName: "pairingFile.plist")
            defer { Shortcuts.discard(copy) }
            try Engine.shared.importPairingFile(data: try Data(contentsOf: copy),
                                                name: copy.lastPathComponent)
        }
        return .result()
    }
}

struct InstallPairingIntoAppsIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Install Pairing File into Apps"
    static let description = IntentDescription(
        "Writes the pairing file into every app on this iPhone that reads one (SideStore, LiveContainer, StikDebug, Feather and more), as Install pairing into all apps does. Gives the apps' names. Runs over LocalDevVPN.",
        categoryName: "Pairing",
        searchKeywords: ["pairing", "sidestore", "stikdebug", "feather", "jit"])

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> & ProvidesDialog {
        let (names, message) = try await Shortcuts.run("Install Pairing File into Apps") { () -> ([String], String) in
            try Shortcuts.requireNoInstall()
            try await Shortcuts.ensureTunnel(for: self)
            let engine = Engine.shared
            let targets = try await MobileDataMode.shared.run(.pairing) { () -> [InstalledPairingTarget] in
                let targets = try await engine.installedPairingTargets()
                guard !targets.isEmpty else {
                    throw ShortcutError(L("Install an app like SideStore, StikDebug, or Feather first, then rescan."))
                }
                try await engine.installPairing(intoAll: targets)
                return targets
            }
            let message = targets.count == 1
                ? L("Pairing file installed into %@.", targets[0].name)
                : L("Pairing file installed into all %d apps.", targets.count)
            return (targets.map(\.name), message)
        }
        return .result(value: names, dialog: Shortcuts.dialog(message))
    }
}

// MARK: Developer Mode

struct ShowDeveloperModeIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Show Developer Mode in Settings"
    static let description = IntentDescription(
        "Makes the Developer Mode switch appear under Settings › Privacy & Security, as the same button in SideInstaller's Settings does. Nothing changes when it's already on. Needs a working pairing file and LocalDevVPN.",
        categoryName: "Device",
        searchKeywords: ["developer mode", "amfi", "settings", "jit"])

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await Shortcuts.run("Show Developer Mode in Settings") { () -> String in
            try await Shortcuts.ensureTunnel(for: self)
            let outcome = try await MobileDataMode.shared.run(.developerMode) {
                try await Engine.shared.requestDeveloperMode(.reveal)
            }
            switch outcome {
            case .alreadyOn:
                return L("Developer Mode is already on.")
            case .revealed, .enabling:
                return L("Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.")
            }
        }
        return .result(dialog: Shortcuts.dialog(message))
    }
}

// MARK: Activity log

struct GetActivityLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Activity Log"
    static let description = IntentDescription(
        "Gives SideInstaller's activity log as text, the same as Copy in Settings › Activity Log, with your Apple ID, device name and keys left out. Handy when an action fails.",
        categoryName: "Device",
        searchKeywords: ["log", "debug", "report", "problem"])

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: LogStore.shared.text)
    }
}
