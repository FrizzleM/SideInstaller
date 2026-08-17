import SwiftUI

/// The tab container for Install and Tools. Each page paints `AppBackground`
/// itself, since a `TabView`'s opaque containers would hide one behind them,
/// and they stay in sync because it animates off the wall clock.
/// The 2FA alert lives here so it presents whichever tab is active.
struct RootView: View {
    /// The tabs in the order they appear, each with the backdrop it wears. The
    /// selection is tracked only so a switch can hand `Backdrop` the level to
    /// travel to; every page then draws that same wash for as long as it shows.
    private enum Page: Hashable {
        case install, tools, about

        var wash: Backdrop.Level {
            switch self {
            case .install: .bright
            case .tools:   .dark
            case .about:   .darkest
            }
        }
    }

    @EnvironmentObject private var engine: Engine
    /// Declared so a language change relabels the tab bar.
    @EnvironmentObject private var loc: Localizer
    /// Watched so switching Apple ID invalidates every cached sign-in below.
    @EnvironmentObject private var accounts: AccountStore
    /// Owned here so they survive tab switches and share the one `Engine`.
    @StateObject private var certManager = CertManager()
    @StateObject private var pairingManager = PairingManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var entitlementsManager = EntitlementsManager()
    @State private var twoFactorCode = ""
    @State private var page: Page = .install

    var body: some View {
        TabView(selection: $page) {
            Tab(L("Install"), systemImage: "square.and.arrow.down", value: Page.install) {
                ContentView()
            }
            Tab(L("Tools"), systemImage: "wrench.and.screwdriver", value: Page.tools) {
                ToolsView(pairingManager: pairingManager,
                          certManager: certManager,
                          locationManager: locationManager,
                          entitlementsManager: entitlementsManager)
            }
            Tab(L("About"), systemImage: "info.circle", value: Page.about) {
                AboutView()
            }
        }
        // The one place the backdrop is told to move. Whichever pair of tabs a
        // switch runs between, the wash travels the distance between their two
        // levels — never resetting through bright on the way.
        .onChange(of: page) { _, page in Backdrop.settle(on: page.wash) }
        // The Install tab's revoke-and-retry runs through this same manager.
        .environmentObject(certManager)
        // Three separate Apple sessions are cached below; all three belong to
        // the account that opened them, so none may outlive a switch.
        .onChange(of: accounts.revision) { _, _ in
            engine.forgetAppleSession()
            certManager.signOut()
            entitlementsManager.signOut()
        }
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

// MARK: - Tools

/// The Tools tab: a menu of the utilities that each used to be a tab of their
/// own. It owns the navigation stack they are pushed onto, which is why
/// neither `PairingView` nor `CertsView` declares one.
struct ToolsView: View {
    /// Declared so every label on this screen redraws when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// Passed in rather than owned, so both pages keep their state across tabs.
    @ObservedObject var pairingManager: PairingManager
    @ObservedObject var certManager: CertManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var entitlementsManager: EntitlementsManager

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    // Everything on the Pairing page is about producing a
                    // pairing file on this iPhone, which only iOS 27 can do —
                    // below it the file is imported on the Install screen
                    // instead, so the row would lead nowhere useful.
                    if Engine.deviceCanSelfPair {
                        NavigationLink {
                            PairingView(manager: pairingManager)
                        } label: {
                            ToolRow(image: "PairingLogo", title: L("Pairing"))
                        }
                        .buttonStyle(.plain)
                        .cascadeItem(1)
                    }
                    NavigationLink {
                        CertsView(manager: certManager)
                    } label: {
                        ToolRow(image: "CertsLogo", title: L("Certificates"))
                    }
                    .buttonStyle(.plain)
                    .cascadeItem(rowIndex(1))
                    NavigationLink {
                        LocationView(manager: locationManager)
                    } label: {
                        ToolRow(image: "LocationLogo", title: L("Location spoofing"))
                    }
                    .buttonStyle(.plain)
                    .cascadeItem(rowIndex(2))
                    NavigationLink {
                        EntitlementsView(manager: entitlementsManager)
                    } label: {
                        ToolRow(image: "EntitlementsLogo", title: L("Entitlements"))
                    }
                    .buttonStyle(.plain)
                    .cascadeItem(rowIndex(3))
                }
                .padding(20)
            }
            // The wash this page reads darker under is `Backdrop.dark`, set by
            // the tab switch rather than by this page appearing, so the pages
            // pushed on top of it stay at the same level.
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    /// Entrance order for the rows below Pairing, so they close the gap when it
    /// isn't there rather than cascading in with a beat missing.
    private func rowIndex(_ position: Int) -> Int {
        Engine.deviceCanSelfPair ? position + 1 : position
    }

    /// Just the title: the rows below carry the iconography on this page.
    private var header: some View {
        Text(L("Tools"))
            .font(.largeTitle.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}

/// One row of the Tools menu: the page's own logo, its name, and a chevron.
/// Pages without logo art pass an SF Symbol, drawn on the brand gradient at the
/// same size so the column of icons still lines up.
private struct ToolRow: View {
    var image: String? = nil
    var icon: String? = nil
    var title: String

    var body: some View {
        PanelCard {
            HStack(spacing: 14) {
                glyph
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.headline)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var glyph: some View {
        if let image {
            Image(image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(Theme.brand)
                Image(systemName: icon ?? "questionmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}
