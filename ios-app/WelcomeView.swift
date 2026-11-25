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
            AppBackground()

            VStack(spacing: 0) {
                BrandHeader(icon: "app.dashed", image: "AppLogo", title: "SideInstaller",
                            subtitle: L("an app by Frizzle")) { EmptyView() }
                    .welcomeItem(0)
                    .padding(.top, 72)

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
                        .animation(.snappy(duration: 0.25), value: accepted)
                        .welcomeItem(Engine.deviceCanSelfPair ? 3 : 4)
                }
                .padding(.horizontal, 24)
                .pageColumn()
                .padding(.bottom, 28)
            }
        }
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
            Image(systemName: "lock.doc.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("You'll need a pairing file"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(L("This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.",
                       Engine.shared.osVersionText, Engine.minimumOSText))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))
    }

    /// The tickbox row, where only "Terms" itself opens the terms page.
    private var checkboxRow: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { accepted.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(accepted ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Theme.control))
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline.opacity(accepted ? 0 : 1), lineWidth: 1)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(accepted ? 1 : 0)
                            .scaleEffect(accepted ? 1 : 0.5)
                    }
                    .frame(width: 24, height: 24)
                    Text(L("I have accepted the"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.9))
                }
            }
            .buttonStyle(.plain, sound: accepted ? .fall : .rise)
            // A tickbox to assistive tech, with an on/off value, not a button.
            .accessibilityRepresentation {
                Toggle(L("I have accepted the") + " " + L("Terms"),
                       isOn: $accepted.animation(.snappy(duration: 0.25)))
            }

            Link(destination: URL(string: "https://sideinstaller.net/terms.html")!) {
                Text(L("Terms"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                    .underline()
            }
        }
    }
}

// MARK: - Entrance

/// The welcome page's entrance: each element zooms up from 80% as it fades in.
private struct WelcomeItem: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.8)
            .onAppear {
                withAnimation(.smooth(duration: 0.55, extraBounce: 0.15)
                    .delay(0.2 + Double(index) * 0.13)) { shown = true }
            }
    }
}

private extension View {
    func welcomeItem(_ index: Int) -> some View { modifier(WelcomeItem(index: index)) }
}
