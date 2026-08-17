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
    /// False until the Apple ID setup page has been answered — by saving an
    /// account or by deferring it. Set once, so emptying the account list in
    /// Settings never drops the user back onto setup.
    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false

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
                        // Between the welcome page and the app, so each zooms
                        // away over whatever it hands off to.
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
            // A file handed over from the Files share sheet, from “Open with”,
            // or from another app. The import route that doesn't go through the
            // document picker — the one to reach for where the picker won't
            // hand a file over.
            .onOpenURL { url in
                guard url.isFileURL else { return }
                // A pairing file is told apart by its extension, as everywhere
                // else; anything else that arrives is meant to be an IPA.
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
