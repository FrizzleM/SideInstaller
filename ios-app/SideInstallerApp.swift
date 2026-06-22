import SwiftUI

@main
struct SideInstallerApp: App {
    // The engine is a singleton (the C log callback targets Engine.shared);
    // hold it here so SwiftUI observes the same instance.
    @StateObject private var engine = Engine.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
        }
    }
}
