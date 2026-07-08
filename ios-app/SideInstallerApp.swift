import SwiftUI

@main
struct SideInstallerApp: App {
    // The engine is a singleton (the C log callback targets Engine.shared);
    // hold it here so SwiftUI observes the same instance.
    @StateObject private var engine = Engine.shared
    // Checks GitHub for a newer release and drives the update banner.
    @StateObject private var updateChecker = UpdateChecker()
    /// First-run gate: false until the user accepts the TOS on the welcome
    /// page, which then never shows again.
    @AppStorage("hasAcceptedTOS") private var hasAcceptedTOS = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasAcceptedTOS {
                    RootView()
                        .environmentObject(engine)
                        .environmentObject(updateChecker)
                        .task { await updateChecker.check() }
                        .transition(.opacity)
                } else {
                    WelcomeView()
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
