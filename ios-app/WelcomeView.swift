import SwiftUI

/// The first-launch gate before `RootView`: Start stays inert until the TOS box
/// is ticked, then sets `hasAcceptedTOS` and the page never returns.
struct WelcomeView: View {
    @AppStorage("hasAcceptedTOS") private var hasAcceptedTOS = false
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @State private var accepted = false
    /// The "Update to iOS 27" popup, for an iPhone below 27 that can run it.
    @State private var recommendingUpdate = false

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // The logo tile and the name, a little above the middle of
                // the space the controls leave.
                VStack(spacing: 20) {
                    logo
                        .welcomeItem(0)
                    VStack(spacing: 8) {
                        Text("SideInstaller")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(L("an app by Frizzle"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .welcomeItem(1)
                }
                .padding(.bottom, 48)

                Spacer()

                VStack(spacing: 20) {
                    // Below iOS 27, say up front that a pairing file made on a
                    // computer is needed.
                    if !Engine.deviceCanSelfPair {
                        pairingFileNotice
                            .welcomeItem(2)
                    }
                    checkboxRow
                        .welcomeItem(Engine.deviceCanSelfPair ? 2 : 3)
                    Button(L("Start")) { hasAcceptedTOS = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!accepted)
                        .animation(.smooth(duration: 0.2), value: accepted)
                        .welcomeItem(Engine.deviceCanSelfPair ? 3 : 4)
                }
                .padding(.horizontal, 24)
                .pageColumn()
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        // An iPhone that can update to iOS 27 is told so once the page has
        // come in: there it pairs with itself, with no computer involved.
        .task {
            guard Engine.canUpdateToSelfPairingOS else { return }
            try? await Task.sleep(for: .seconds(1.4))
            recommendingUpdate = true
        }
        .alert(L("Update to iOS %@", Engine.minimumOSText), isPresented: $recommendingUpdate) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(L("This iPhone can run iOS %@, where SideInstaller works without a computer: the iPhone pairs with itself, so there's no pairing file to make. Update in Settings › General › Software Update.",
                   Engine.minimumOSText))
        }
    }

    /// Notice for iOS below 27, explaining the extra pairing-file step.
    private var pairingFileNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.doc")
                .font(.title3)
                .foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("You'll need a pairing file"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(L("This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.",
                       Engine.shared.osVersionText, Engine.minimumOSText))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    /// The app's logo tile, the page's one picture.
    private var logo: some View {
        let tile = RoundedRectangle(cornerRadius: 96 * 23 / 86, style: .continuous)
        return Image("AppLogo")
            .logoArt()
            .frame(width: 96, height: 96)
            .clipShape(tile)
            // The art's black tile would melt into the page without it.
            .overlay(tile.strokeBorder(Theme.hairline, lineWidth: 1))
            .accessibilityHidden(true)
    }

    /// The tickbox row, where only "TOS" itself opens the terms page.
    private var checkboxRow: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.smooth(duration: 0.2)) { accepted.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accepted ? Theme.accent : Theme.control)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.white.opacity(accepted ? 0 : 0.3), lineWidth: 1)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .opacity(accepted ? 1 : 0)
                    }
                    .frame(width: 24, height: 24)
                    Text(L("I have accepted the"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain, sound: accepted ? .fall : .rise)
            // A tickbox to assistive tech, with an on/off value, not a button.
            .accessibilityRepresentation {
                Toggle(L("I have accepted the") + " TOS",
                       isOn: $accepted.animation(.smooth(duration: 0.2)))
            }

            Link(destination: URL(string: "https://sideinstaller.net/terms.html")!) {
                Text("TOS")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .underline()
            }
        }
    }
}

// MARK: - Entrance

/// The welcome page's entrance: each element fades in and rises a little,
/// one after another.
private struct WelcomeItem: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .onAppear {
                withAnimation(.smooth(duration: 0.5)
                    .delay(0.2 + Double(index) * 0.06)) { shown = true }
            }
    }
}

private extension View {
    func welcomeItem(_ index: Int) -> some View { modifier(WelcomeItem(index: index)) }
}
