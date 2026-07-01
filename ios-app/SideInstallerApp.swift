import SwiftUI

@main
struct SideInstallerApp: App {
    // The engine is a singleton (the C log callback targets Engine.shared);
    // hold it here so SwiftUI observes the same instance.
    @StateObject private var engine = Engine.shared
    // Checks GitHub for a newer release and drives the update banner.
    @StateObject private var updateChecker = UpdateChecker()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .environmentObject(updateChecker)
                .task { await updateChecker.check() }
        }
    }
}
