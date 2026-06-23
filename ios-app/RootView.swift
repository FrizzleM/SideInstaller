import SwiftUI

/// Top-level tab container hosting the install flow (`ContentView`) and the
/// certificate manager (`CertsView`).
///
/// The two-factor prompt lives here, not inside a tab: both flows drive the same
/// shared `Engine` 2FA bridge, and an `.alert` attached at the tab root presents
/// regardless of which tab is active.
struct RootView: View {
    @EnvironmentObject private var engine: Engine
    /// Owned here so they survive tab switches and share the one `Engine`.
    @StateObject private var certManager = CertManager()
    @StateObject private var downloadsManager = DownloadsManager()
    @State private var twoFactorCode = ""
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem { Label("Install", systemImage: "square.and.arrow.down") }
                .tag(0)
            CertsView(manager: certManager)
                .tabItem { Label("Certificates", systemImage: "checkmark.seal") }
                .tag(1)
            DownloadsView(manager: downloadsManager)
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
                .tag(2)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .alert("Two-Factor Code", isPresented: $engine.pendingTwoFactor) {
            TextField("6-digit code", text: $twoFactorCode)
                .keyboardType(.numberPad)
            Button("Submit") { engine.submitTwoFactor(twoFactorCode); twoFactorCode = "" }
            Button("Cancel", role: .cancel) { engine.cancelTwoFactor(); twoFactorCode = "" }
        } message: {
            Text("Enter the code Apple just sent to your trusted device.")
        }
    }
}
