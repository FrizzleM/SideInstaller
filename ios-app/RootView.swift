import SwiftUI

/// Tab container (Install, Tools, About). Each page draws its own
/// `AppBackground`, since `TabView` would hide a shared one; they stay in sync
/// because the background animates off the clock. Also hosts the 2FA sheet so
/// it shows over any tab.
struct RootView: View {
    /// The tabs and their backdrop level. The selection is tracked so a tab
    /// switch can animate `Backdrop` to the new level.
    private enum Page: Hashable {
        case install, tools, about

        var wash: Backdrop.Level {
            switch self {
            case .install: .bright
            case .tools:   .dark
            // Same as Install, so switching between them doesn't change the backdrop.
            case .about:   .bright
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
    @StateObject private var appsManager = SideloadedAppsManager()
    @StateObject private var sideBySideManager = SideBySideManager()
    /// The last two-factor prompt shown, so the sheet keeps its content while it
    /// slides away after the sign-in clears it.
    @State private var shownTwoFactor: TwoFactorPhase?
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
                          entitlementsManager: entitlementsManager,
                          appsManager: appsManager,
                          sideBySideManager: sideBySideManager)
            }
            Tab(L("About"), systemImage: "info.circle", value: Page.about) {
                AboutView()
            }
        }
        // Animate the backdrop to the new tab's level.
        .onChange(of: page) { _, page in Backdrop.settle(on: page.wash) }
        // The Install tab's revoke-and-retry runs through this same manager.
        .environmentObject(certManager)
        // When the active Apple ID changes, drop all four cached Apple sessions
        // (Side by Side's included) so none is reused for the new account.
        .onChange(of: accounts.revision) { _, _ in
            engine.forgetAppleSession()
            certManager.signOut()
            entitlementsManager.signOut()
            sideBySideManager.signOut()
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        // A swipe down is a cancel; the sign-in closing it is not.
        .sheet(isPresented: Binding(
            get: { engine.twoFactor != nil },
            set: { if !$0 { engine.cancelTwoFactor() } }
        )) {
            if let phase = engine.twoFactor ?? shownTwoFactor {
                TwoFactorSheet(phase: phase)
            }
        }
        .onChange(of: engine.twoFactor) { _, phase in
            if let phase { shownTwoFactor = phase }
        }    }
}

// MARK: - Two-factor sheet

/// Two-factor sign-in sheet: enter the code, or request one another way (trusted
/// devices, text or call). Stays open through wrong codes and resends; closes
/// when the sign-in returns.
struct TwoFactorSheet: View {
    @EnvironmentObject private var engine: Engine
    /// Declared so every label redraws when the language changes.
    @EnvironmentObject private var loc: Localizer

    let phase: TwoFactorPhase

    @State private var code = ""
    @FocusState private var codeFocused: Bool

    private var prompt: TwoFactorPrompt { phase.prompt }

    /// The answer the sign-in is acting on, while it does.
    private var pending: TwoFactorAnswer? {
        if case .working(_, let answer) = phase { answer } else { nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = prompt.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    Text(instructions)
                        .foregroundStyle(.secondary)
                    if prompt.expectsCode {
                        TextField(L("6-digit code"), text: $code)
                            .keyboardType(.numberPad)
                            // Lets a texted code fill itself in from Messages.
                            .textContentType(.oneTimeCode)
                            .font(.title2.monospacedDigit())
                            .focused($codeFocused)
                            .disabled(pending != nil)
                            .onChange(of: code) { _, typed in
                                let digits = String(typed.filter(\.isNumber).prefix(6))
                                if digits != typed { code = digits }
                            }
                    }
                    if let pending {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(status(for: pending))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    options
                } header: {
                    if prompt.expectsCode { Text(L("Didn't get it?")) }
                }
                .disabled(pending != nil)
            }
            .navigationTitle(prompt.expectsCode ? L("Two-Factor Code") : L("Choose How to Get a Code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Cancel")) { engine.cancelTwoFactor() }
                }
                if prompt.expectsCode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("Verify")) { engine.answerTwoFactor(.code(code)) }
                            .disabled(pending != nil || code.count != 6)
                    }
                }
            }
        }
        .onAppear { codeFocused = prompt.expectsCode }
        .onChange(of: phase) { _, phase in
            // A fresh prompt — after a wrong code, or with a new code on its way —
            // starts from an empty field.
            guard case .asking(let prompt) = phase else { return }
            code = ""
            codeFocused = prompt.expectsCode
        }
    }

    /// Every other route to a code, leaving out the one already in use.
    @ViewBuilder
    private var options: some View {
        switch prompt.method {
        case .device: option(L("Send a new code to my devices"), "arrow.clockwise", .resend)
        case .sms:    option(L("Text me a new code"), "arrow.clockwise", .resend)
        case .voice:  option(L("Call me again"), "arrow.clockwise", .resend)
        case .choose: EmptyView()
        }
        if prompt.method != .device {
            option(L("Send a code to my Apple devices"), "laptopcomputer.and.iphone", .devices)
        }
        // Enumerated, so a language switch relabels every row.
        ForEach(Array(prompt.numbers.enumerated()), id: \.element.id) { _, number in
            let inUse = number.id == prompt.selectedNumberId
            if number.takesTexts && !(inUse && prompt.method == .sms) {
                option(L("Text %@", number.number), "message", .sms(number.id))
            }
            if !(inUse && prompt.method == .voice) {
                option(L("Call %@", number.number), "phone", .voice(number.id))
            }
        }
    }

    private func option(_ title: String, _ systemImage: String, _ answer: TwoFactorAnswer) -> some View {
        Button { engine.answerTwoFactor(answer) } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private var instructions: String {
        switch prompt.method {
        case .device:
            L("Enter the code Apple just sent to your trusted device.")
        case .sms:
            prompt.selectedNumber.map { L("Enter the code Apple texted to %@.", $0.number) }
                ?? L("Enter the code Apple texted to your phone.")
        case .voice:
            prompt.selectedNumber.map { L("Apple is calling %@. Enter the code you hear.", $0.number) }
                ?? L("Apple is calling your phone. Enter the code you hear.")
        case .choose:
            L("Choose how Apple should send your verification code.")
        }
    }

    private func status(for answer: TwoFactorAnswer) -> String {
        let number = { (id: UInt32) in prompt.numbers.first { $0.id == id }?.number ?? "" }
        return switch answer {
        case .code:          L("Checking the code…")
        case .resend:        L("Requesting a new code…")
        case .devices:       L("Sending a code to your devices…")
        case .sms(let id):   L("Texting a code to %@…", number(id))
        case .voice(let id): L("Calling %@…", number(id))
        }
    }
}

// MARK: - Tools

/// The Tools tab: a menu of utility pages. Owns the `NavigationStack` they're
/// pushed onto, so those pages don't declare their own.
struct ToolsView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// Passed in (owned by `RootView`) so pages keep their state across tabs.
    @ObservedObject var pairingManager: PairingManager
    @ObservedObject var certManager: CertManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var entitlementsManager: EntitlementsManager
    @ObservedObject var appsManager: SideloadedAppsManager
    @ObservedObject var sideBySideManager: SideBySideManager

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    NavigationLink {
                        SideBySideView(manager: sideBySideManager)
                    } label: {
                        ToolRow(image: "SideBySideLogo",
                                title: L("Side by Side"),
                                beta: true)
                    }
                    .buttonStyle(.plain)
                    .cascadeItem(1)
                    // The Pairing page generates a pairing file on-device, which
                    // needs iOS 27+. Older iOS imports it on the Install screen.
                    if Engine.deviceCanSelfPair {
                        NavigationLink {
                            PairingView(manager: pairingManager)
                        } label: {
                            ToolRow(image: "PairingLogo", title: L("Pairing"))
                        }
                        .buttonStyle(.plain)
                        .cascadeItem(2)
                    }
                    NavigationLink {
                        CertsView(manager: certManager)
                    } label: {
                        ToolRow(image: "CertsLogo", title: L("Certificates"))
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
                    NavigationLink {
                        LocationView(manager: locationManager)
                    } label: {
                        ToolRow(image: "LocationLogo", title: L("Location spoofing"))
                    }
                    .buttonStyle(.plain)
                    .cascadeItem(rowIndex(4))
                    NavigationLink {
                        AppsView(manager: appsManager)
                    } label: {
                        ToolRow(image: "AppsLogo", title: L("Sideloaded apps"))
                    }
                    .buttonStyle(.plain)
                    .cascadeItem(rowIndex(5))
                }
                .padding(20)
            }
            // The darker backdrop is set by the tab switch, not by this page
            // appearing, so pushed pages keep the same level.
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    /// Cascade index for rows below Pairing, shifted by one when that row is shown.
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

/// One Tools menu row: logo, name and chevron. Pages without logo art pass an
/// SF Symbol, drawn on the brand gradient at the same size.
private struct ToolRow: View {
    var image: String? = nil
    var icon: String? = nil
    var title: String
    /// Shows a Beta badge.
    var beta: Bool = false

    var body: some View {
        PanelCard {
            HStack(spacing: 14) {
                glyph
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.headline)
                if beta { BetaBadge() }
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
