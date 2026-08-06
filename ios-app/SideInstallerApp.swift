import SwiftUI

@main
struct SideInstallerApp: App {
    // Held here so SwiftUI observes the same instance the C log callback targets.
    @StateObject private var engine = Engine.shared
    // Checks GitHub for a newer release and drives the update banner.
    @StateObject private var updateChecker = UpdateChecker()
    // Held here so every screen redraws when the language setting changes.
    @StateObject private var localizer = Localizer.shared
    /// False until the TOS is accepted, after which the welcome page is gone.
    @AppStorage("hasAcceptedTOS") private var hasAcceptedTOS = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasAcceptedTOS {
                    RootView()
                        .environmentObject(engine)
                        .environmentObject(updateChecker)
                        .environmentObject(localizer)
                        .task { await updateChecker.check() }
                        .transition(.opacity)
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
        }
    }
}
