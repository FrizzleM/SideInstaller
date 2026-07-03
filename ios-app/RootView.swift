import SwiftUI

/// Top-level tab container hosting the app's three screens — Install, Pairing
/// and Certificates. (Managing downloaded IPAs now lives in the Settings sheet.)
///
/// Each page paints the shared animated `AppBackground` behind its own content.
/// (`TabView` hosts each tab in an opaque container, so a single backdrop *behind*
/// the `TabView` would be hidden — the background has to live inside each page.)
/// Because that gradient is driven off the wall clock rather than an elapsed
/// timer, every page renders the identical frame, so it stays perfectly in sync
/// and reads as one continuous surface even across tab switches.
///
/// The two-factor prompt lives here, not inside a tab: every flow drives the same
/// shared `Engine` 2FA bridge, and an `.alert` attached at the root presents
/// regardless of which tab is active.
struct RootView: View {
    @EnvironmentObject private var engine: Engine
    /// Owned here so they survive tab switches and share the one `Engine`.
    @StateObject private var certManager = CertManager()
    @StateObject private var pairingManager = PairingManager()
    @State private var twoFactorCode = ""

    var body: some View {
        TabView {
            Tab("Install", systemImage: "square.and.arrow.down") {
                ContentView()
            }
            Tab("Pairing", systemImage: "lock.iphone") {
                PairingView(manager: pairingManager)
            }
            Tab("Certificates", systemImage: "checkmark.seal") {
                CertsView(manager: certManager)
            }
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
