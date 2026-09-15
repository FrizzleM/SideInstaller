import SwiftUI

@main
struct SideInstallerApp: App {
    // Held here so SwiftUI observes the same instance the C log callback targets.
    @StateObject private var engine = Engine.shared
    // Checks GitHub for a newer release and drives the update banner.
    @StateObject private var updateChecker = UpdateChecker()
    // Held here so every screen redraws when the language setting changes.
    @StateObject private var localizer = Localizer.shared
    // The saved Apple IDs, shared by every screen that signs in.
    @StateObject private var accounts = AccountStore.shared
    /// False until the TOS is accepted, after which the welcome page is gone.
    @AppStorage("hasAcceptedTOS") private var hasAcceptedTOS = false
    /// False until account setup is completed or skipped. Never reset, even if
    /// all accounts are removed later.
    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false
    /// Observed to run the LocalDevVPN auto-start each time the app becomes
    /// active.
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasAcceptedTOS && hasCompletedAccountSetup {
                    RootView()
                        .environmentObject(engine)
                        .environmentObject(updateChecker)
                        .environmentObject(localizer)
                        .environmentObject(accounts)
                        .task { await updateChecker.check() }
                        .transition(.opacity)
                } else if hasAcceptedTOS {
                    AccountSetupView()
                        .environmentObject(localizer)
                        .environmentObject(accounts)
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 1.06))))
                        // Layered between the welcome page and the app, so each
                        // zooms out over the next screen.
                        .zIndex(0.5)
                } else {
                    WelcomeView()
                        .environmentObject(localizer)
                        // Zoom past the camera while the app fades in beneath.
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 1.06))))
                        .zIndex(1)
                }
            }
            .animation(.smooth(duration: 0.5), value: hasAcceptedTOS)
            .animation(.smooth(duration: 0.5), value: hasCompletedAccountSetup)
            // Auto-start LocalDevVPN on activation; `autoStartVPNIfWanted`
            // checks the setting and other conditions.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { engine.autoStartVPNIfWanted() }
            }
            // Files opened in the app (share sheet, "Open with", other apps), as
            // an alternative to the document picker.
            .onOpenURL { url in
                // Ignore `sideinstaller://` URLs: LocalDevVPN only uses them to
                // return to the app.
                guard url.isFileURL else { return }
                // `.mobiledevicepairing`/`.plist` are pairing files; anything else
                // is treated as an IPA.
                if ["mobiledevicepairing", "plist"].contains(url.pathExtension.lowercased()) {
                    Task { await engine.importPairingFile(from: url) }
                } else {
                    engine.installSource = .custom
                    Task { await engine.importCustomIPA(from: url) }
                }
            }
        }
    }
}
