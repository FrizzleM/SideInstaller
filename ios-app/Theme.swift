import SwiftUI

/// The app's shared visual language: brand colours/gradients plus the reusable
/// building blocks (cards, callouts, the primary button, the hero header) that
/// every screen is composed from, so the whole app stays consistent.
enum Theme {
    /// Primary brand colour — a deep blue.
    static let accent = Color(red: 0.13, green: 0.44, blue: 0.96)
    /// Secondary brand colour — a brighter sky blue, the far end of the gradient.
    static let accent2 = Color(red: 0.30, green: 0.68, blue: 1.0)
    /// Deep-navy halo cast behind each header icon (#011A5C) — matches the icon
    /// art's background so the glyph reads as lifted off the black backdrop.
    static let glow = Color(red: 1 / 255, green: 26 / 255, blue: 92 / 255)

    /// The signature diagonal gradient used for the logo, CTA and accents.
    static var brand: LinearGradient {
        LinearGradient(colors: [accent, accent2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// A diagonal gradient built from any tint, for tinted glyphs.
    static func gradient(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color, color.opacity(0.72)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Background

/// Pure OLED-black app background.
struct AppBackground: View {
    var body: some View {
        Color.black.ignoresSafeArea()
    }
}

// MARK: - Cards

/// The neutral container every section sits in: a continuous rounded rectangle
/// with a hairline highlight and a soft drop shadow.
struct PanelCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 7)
    }
}

/// A tinted container for contextual callouts (guidance, errors, success). Same
/// silhouette as `PanelCard` but washed in the supplied colour.
struct CalloutCard<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            )
    }
}

// MARK: - Small components

/// A compact, colour-coded status capsule shown under the header.
struct StatusPill: View {
    var text: String
    var systemImage: String
    var color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(color.opacity(0.16)))
    }
}

/// The hero at the top of each screen: a gradient app glyph, the title, and an
/// optional accessory (e.g. a status pill).
struct BrandHeader<Accessory: View>: View {
    var icon: String
    /// When set, the real app icon (an asset image) is shown in place of the
    /// gradient SF Symbol — used on the app's brand (Install) screen so it wears
    /// its home-screen identity. The other tabs keep their contextual glyphs.
    var image: String? = nil
    var title: String
    var animateIcon: Bool = false
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(spacing: 14) {
            glyph
                .frame(width: 86, height: 86)
                .shadow(color: Theme.glow, radius: 20, x: 0, y: 12)
            Text(title)
                .font(.largeTitle.weight(.bold))
            accessory()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var glyph: some View {
        if let image {
            Image(image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                // A gentle breathe while a run is in flight, mirroring the
                // SF Symbol's `.pulse` on the other glyphs.
                .scaleEffect(animateIcon ? 1.04 : 1)
                .animation(animateIcon ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                       : .default,
                           value: animateIcon)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(Theme.brand)
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: animateIcon)
            }
        }
    }
}

// MARK: - Field styling

/// Inset, filled text-field background — softer than `.roundedBorder`.
private struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
    }
}

extension View {
    /// Wrap a `.plain` text/secure field in the app's inset field background.
    func fieldBackground() -> some View { modifier(FieldBackground()) }
}

// MARK: - Buttons

/// The full-width gradient call-to-action style. Pass a `gradient` to recolour
/// it (e.g. a red gradient for a cancel action).
struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.brand
    var glow: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(gradient)
            )
            .shadow(color: glow.opacity(0.4), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.22), value: configuration.isPressed)
    }
}

// MARK: - Transitions

extension AnyTransition {
    /// Shared insert/remove used by every status card: eases down and scales up
    /// while fading in, then fades + shrinks slightly on the way out.
    static var cardAppear: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.96, anchor: .top))
                .combined(with: .offset(y: -10)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
        )
    }
}

// MARK: - Tab entrance

/// One card's part in the tab's entrance cascade: it "materializes" into place —
/// fading up from slightly low and small with a quick focus-pull (blur clearing)
/// and a gentle spring — staggered by `index` so the cards reveal top-to-bottom.
///
/// Driven by `onAppear`/`onDisappear`, which fire on *every* tab switch, so the
/// cascade replays each time the user opens the tab (not just on first launch).
/// A view only animates when it first appears, so rows added later (e.g. a freshly
/// loaded list) cascade in on arrival without re-animating the ones already shown.
private struct CascadeItem: ViewModifier {
    let index: Int
    @State private var shown = false

    /// 60 ms between cards — enough to read as a cascade, quick enough not to drag.
    private var delay: Double { Double(index) * 0.06 }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.96, anchor: .top)
            .offset(y: shown ? 0 : 18)
            .blur(radius: shown ? 0 : 6)
            .onAppear {
                withAnimation(.smooth(duration: 0.45, extraBounce: 0.12).delay(delay)) {
                    shown = true
                }
            }
            .onDisappear { shown = false }
    }
}

extension View {
    /// Give a card its place in the tab's entrance cascade (0 = first to appear).
    /// Replays each time the tab is opened.
    func cascadeItem(_ index: Int) -> some View { modifier(CascadeItem(index: index)) }
}
