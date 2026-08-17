import SwiftUI

/// The first-launch gate before `RootView`: Start stays inert until the TOS box
/// is ticked, then sets `hasAcceptedTOS` and the page never returns.
struct WelcomeView: View {
    @AppStorage("hasAcceptedTOS") private var hasAcceptedTOS = false
    /// Declared so the page redraws if the language changes underneath it.
    @EnvironmentObject private var loc: Localizer
    @State private var accepted = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Text("SideInstaller")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                        .welcomeItem(0)
                    Text(L("an app by Frizzle"))
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .welcomeItem(1)
                }
                .padding(.top, 72)

                Spacer()

                VStack(spacing: 20) {
                    // Said before anything is agreed to: on this iPhone the
                    // pairing file has to come from a computer, and that's worth
                    // knowing before the first install run asks for one.
                    if !Engine.deviceCanSelfPair {
                        pairingFileNotice
                            .welcomeItem(2)
                    }
                    checkboxRow
                        .welcomeItem(Engine.deviceCanSelfPair ? 2 : 3)
                    Button(L("Start")) { hasAcceptedTOS = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!accepted)
                        .opacity(accepted ? 1 : 0.35)
                        .animation(.snappy(duration: 0.25), value: accepted)
                        .welcomeItem(Engine.deviceCanSelfPair ? 3 : 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// What an iPhone below iOS 27 will be asked for. Everything else about the
    /// install is the same, so this says what the extra step is rather than
    /// reading as an unsupported-device warning.
    private var pairingFileNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.doc.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("You'll need a pairing file"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(L("This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.",
                       Engine.shared.osVersionText, Engine.minimumOSText))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))
    }

    /// The tickbox row, where only "TOS" itself opens the terms page.
    private var checkboxRow: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { accepted.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(accepted ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(.white.opacity(0.06)))
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(.white.opacity(accepted ? 0 : 0.25), lineWidth: 1)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(accepted ? 1 : 0)
                            .scaleEffect(accepted ? 1 : 0.5)
                    }
                    .frame(width: 24, height: 24)
                    Text(L("I have accepted the"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(accepted ? [.isSelected] : [])

            Link(destination: URL(string: "https://frizzlem.github.io/SideInstaller/terms.html")!) {
                Text("TOS")
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
