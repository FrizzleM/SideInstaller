import AppIntents
import Foundation
import UIKit

// MARK: - Shortcuts actions
//
// SideInstaller's actions in the Shortcuts app, also offered to Siri and
// Spotlight. iOS runs them in the app's own process, started in the background
// when it isn't running, so they drive the same shared managers as the pages
// (`LocationManager.shared`, `SideloadedAppsManager.shared`, `Engine.shared`)
// and never need a page on screen. Location spoofing keeps the app running
// afterwards with the same silent audio the page uses.
//
// Their names and descriptions are what the Shortcuts app shows, in English
// only: iOS reads those from the app bundle's string tables, which this app
// doesn't have (its own translations are in the *Strings.swift tables). What
// they report when they run goes through `L`, like the rest of the app.
//
// The actions are in LocationShortcuts.swift, AppsShortcuts.swift and
// DeviceShortcuts.swift.

/// What a Shortcuts action stops with; Shortcuts shows its text.
struct ShortcutError: Error, CustomLocalizedStringResourceConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var localizedStringResource: LocalizedStringResource { "\(message)" }
}

@MainActor
enum Shortcuts {

    /// Runs an action's work, logged under `action`, and turns what it throws
    /// into the message the app would show for it. Nothing runs before the
    /// terms are accepted, as in the app.
    static func run<T>(_ action: String, _ work: () async throws -> T) async throws -> T {
        guard UserDefaults.standard.bool(forKey: SetupView.acceptedTermsKey) else {
            throw ShortcutError(L("Open SideInstaller and accept its terms first."))
        }
        let engine = Engine.shared
        engine.log("Shortcuts: \(action)")
        do {
            return try await work()
        } catch is CancellationError {
            engine.log("Shortcuts: \(action) stopped.")
            throw CancellationError()
        } catch let error as ShortcutError {
            engine.log("⛔️ Shortcuts: \(action): \(error.message)")
            throw error
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            engine.log("⛔️ Shortcuts: \(action): \(message)")
            throw ShortcutError(message)
        }
    }

    /// True while SideInstaller is on screen.
    static var isInForeground: Bool {
        UIApplication.shared.applicationState == .active
    }

    /// What an action says when it's done, or asks, already in the app's
    /// language. (Written `L` first, so the translation check finds it.)
    nonisolated static func dialog(_ text: String) -> IntentDialog {
        IntentDialog("\(text)")
    }

    // MARK: Tunnel

    /// Makes sure the LocalDevVPN tunnel can be used. In the background
    /// nothing else can be opened, so when the tunnel is down and “Start
    /// LocalDevVPN when needed” is on, it asks to bring SideInstaller forward;
    /// what runs next opens LocalDevVPN and comes back. With that setting off
    /// the action stops and says how to connect it.
    static func ensureTunnel<Intent: ForegroundContinuableIntent>(for intent: Intent) async throws {
        let engine = Engine.shared
        await engine.settleNetworkStatus()
        guard !engine.vpnConnected else {
            try await offerMobileDataMode(for: intent)
            return
        }
        guard engine.startsVPNWhenNeeded else {
            throw ShortcutError(ErrorHelp.explained(L("LocalDevVPN isn't connected. Connect it before this action runs: Shortcuts' Set VPN action can, or turn on “Start LocalDevVPN when needed” in SideInstaller's Settings.")))
        }
        guard !isInForeground else { return }
        try await intent.requestToContinueInForeground(
            Shortcuts.dialog(L("LocalDevVPN isn't connected. Continue in SideInstaller to connect it.")))
    }

    /// On mobile data alone a new tunnel needs Mobile Data Mode, which asks
    /// and has Airplane Mode turned on in SideInstaller: from the background,
    /// the action asks to come forward first. A tunnel Mobile Data Mode kept
    /// open needs none of that.
    private static func offerMobileDataMode<Intent: ForegroundContinuableIntent>(for intent: Intent) async throws {
        guard NetworkStatus.links().mobileDataOnly, !MobileDataMode.shared.mayHaveOpenTunnel,
              !isInForeground else { return }
        try await intent.requestToContinueInForeground(
            Shortcuts.dialog(L("This iPhone is on mobile data. Continue in SideInstaller to use Mobile Data Mode.")))
    }

    // MARK: Apple sign-in

    /// Runs `work`, which may sign in to Apple. A two-factor code or a choice
    /// of team is asked in a sheet in SideInstaller, which nobody sees while
    /// it's in the background, so the action asks to bring it forward. Turning
    /// that down cancels the question, and the sign-in with it.
    static func answeringSignIn<Intent: ForegroundContinuableIntent, T>(
        for intent: Intent, _ work: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        let run = Task { @MainActor in try await work() }
        let watcher = Task { @MainActor in
            let engine = Engine.shared
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                let phase = engine.twoFactor
                let question = engine.teamQuestion
                guard phase?.isAsking == true || question != nil, !isInForeground else { continue }
                do {
                    try await intent.requestToContinueInForeground(
                        Shortcuts.dialog(L("Apple is asking you to finish signing in. Continue in SideInstaller to answer it.")))
                } catch {
                    if let phase = engine.twoFactor { engine.cancelTwoFactor(phase) }
                    if let question = engine.teamQuestion { engine.cancelTeamQuestion(question) }
                    return
                }
            }
        }
        defer { watcher.cancel() }
        return try await withTaskCancellationHandler {
            try await run.value
        } onCancel: {
            run.cancel()
        }
    }

    // MARK: Files

    /// A file handed to an action, as a file of SideInstaller's own in its
    /// temporary folder, where imports delete what they were given once
    /// they're done.
    static func temporaryCopy(of file: IntentFile, defaultName: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShortcutsInput-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = file.filename.isEmpty ? defaultName : (file.filename as NSString).lastPathComponent
        let destination = folder.appendingPathComponent(name)
        if let source = file.fileURL {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            try FileManager.default.copyItem(at: source, to: destination)
        } else {
            try file.data.write(to: destination, options: .atomic)
        }
        return destination
    }

    /// Deletes what `temporaryCopy` made, folder and all.
    static func discard(_ copy: URL) {
        try? FileManager.default.removeItem(at: copy.deletingLastPathComponent())
    }
}

// MARK: - Siri and Spotlight

/// The actions Siri and Spotlight offer without a shortcut being made first.
struct SideInstallerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SetSavedPlaceIntent(),
                    phrases: ["Spoof my location to \(\.$place) with \(.applicationName)",
                              "Set my \(.applicationName) location to \(\.$place)",
                              "Spoof my location with \(.applicationName)"],
                    shortTitle: "Spoof Location",
                    systemImageName: "location.fill")
        AppShortcut(intent: ResetLocationIntent(),
                    phrases: ["Reset my location with \(.applicationName)",
                              "Stop spoofing my location with \(.applicationName)"],
                    shortTitle: "Reset Location",
                    systemImageName: "location.slash")
        AppShortcut(intent: StopRouteIntent(),
                    phrases: ["Stop the route in \(.applicationName)"],
                    shortTitle: "Stop Route",
                    systemImageName: "stop.circle")
        AppShortcut(intent: GetSpoofedLocationIntent(),
                    phrases: ["Where is my \(.applicationName) location"],
                    shortTitle: "Spoofed Location",
                    systemImageName: "mappin.and.ellipse")
        AppShortcut(intent: RefreshAllAppsIntent(),
                    phrases: ["Refresh my apps with \(.applicationName)",
                              "Refresh my sideloaded apps with \(.applicationName)"],
                    shortTitle: "Refresh All Apps",
                    systemImageName: "arrow.clockwise")
        AppShortcut(intent: InstallAppIntent(),
                    phrases: ["Install \(\.$app) with \(.applicationName)"],
                    shortTitle: "Install App",
                    systemImageName: "square.and.arrow.down")
        AppShortcut(intent: ConnectLocalDevVPNIntent(),
                    phrases: ["Connect LocalDevVPN with \(.applicationName)"],
                    shortTitle: "Connect LocalDevVPN",
                    systemImageName: "network")
    }
}
