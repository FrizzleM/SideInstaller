import SwiftUI

/// The tab container for Install, Pairing and Certificates. Each page paints
/// `AppBackground` itself, since a `TabView`'s opaque containers would hide one
/// behind them, and they stay in sync because it animates off the wall clock.
/// The 2FA alert lives here so it presents whichever tab is active.
struct RootView: View {
    @EnvironmentObject private var engine: Engine
    /// Declared so a language change relabels the tab bar.
    @EnvironmentObject private var loc: Localizer
    /// Owned here so they survive tab switches and share the one `Engine`.
    @StateObject private var certManager = CertManager()
    @StateObject private var pairingManager = PairingManager()
    @State private var twoFactorCode = ""

    var body: some View {
        TabView {
            Tab(L("Install"), systemImage: "square.and.arrow.down") {
                ContentView()
            }
            Tab(L("Pairing"), systemImage: "lock.iphone") {
                PairingView(manager: pairingManager)
            }
            Tab(L("Certificates"), systemImage: "checkmark.seal") {
                CertsView(manager: certManager)
            }
        }
        // The Install tab's revoke-and-retry runs through this same manager.
        .environmentObject(certManager)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .alert(L("Two-Factor Code"), isPresented: $engine.pendingTwoFactor) {
            TextField(L("6-digit code"), text: $twoFactorCode)
                .keyboardType(.numberPad)
            Button(L("Submit")) { engine.submitTwoFactor(twoFactorCode); twoFactorCode = "" }
            Button(L("Cancel"), role: .cancel) { engine.cancelTwoFactor(); twoFactorCode = "" }
        } message: {
            Text(L("Enter the code Apple just sent to your trusted device."))
        }
    }
}
