import SwiftUI

/// The one-time first-launch gate shown before `RootView`: an OLED-black page
/// with the app's name, a TOS-acceptance checkbox and a Start button. Start
/// stays dimmed and inert until the box is ticked; tapping it flips the
/// persisted flag (`hasAcceptedTOS`) so the page never shows again.
struct WelcomeView: View {
    @AppStorage("hasAcceptedTOS") private var hasAcceptedTOS = false
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
                    Text("an app by Frizzle")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .welcomeItem(1)
                }
                .padding(.top, 72)

                Spacer()

                VStack(spacing: 20) {
                    checkboxRow
                        .welcomeItem(2)
                    Button("Start") { hasAcceptedTOS = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!accepted)
                        .opacity(accepted ? 1 : 0.35)
                        .animation(.snappy(duration: 0.25), value: accepted)
                        .welcomeItem(3)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// The tickbox row. Tapping the box or the sentence toggles acceptance;
    /// tapping "TOS" opens the terms page instead.
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
                    Text("I have accepted the")
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

/// Per-object entrance for the welcome page: each element zooms up from 80%
/// while fading in, on its own beat (`index` staggers the start).
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
