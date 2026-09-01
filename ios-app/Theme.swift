import SwiftUI

/// The app's shared visual language: brand colours, gradients and the cards,
/// buttons and headers every screen is composed from.
enum Theme {
    /// Primary brand colour, a deep blue.
    static let accent = Color(red: 0.13, green: 0.44, blue: 0.96)
    /// Secondary brand colour, the far end of the gradient.
    static let accent2 = Color(red: 0.30, green: 0.68, blue: 1.0)
    /// Deep-navy halo behind each header icon, matching the icon art (#011A5C).
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

// MARK: - Backdrop level

/// How dark the backdrop is, and where it has got to on its way between two
/// levels.
///
/// Every page paints its own `AppBackground`, so the wash cannot live in any one
/// of them: two pages overlap for the length of a tab change, and a page built
/// part-way through one would start from the wrong place — which is what made
/// switching tabs look arbitrary. It lives here instead, as the level left
/// behind, the level being travelled to, and the moment the move began. Each
/// backdrop reads its value off the clock, exactly as the mesh does, so all of
/// them show the same frame and a switch reads as one backdrop changing rather
/// than two crossing.
@MainActor
enum Backdrop {
    /// The wash each tab settles on, as black laid over the mesh. The tabs are a
    /// descent: Install bright, Tools dark, About darkest.
    enum Level: Double {
        case bright  = 0
        case dark    = 0.55
        case darkest = 0.75
    }

    /// Long enough to read as the room changing brightness, short enough to be
    /// over before the incoming page has finished its entrance cascade.
    private static let duration: TimeInterval = 0.55

    private static var origin = Level.bright.rawValue
    private static var target = Level.bright.rawValue
    /// Far enough in the past that the first frame is at rest on `bright`.
    private static var departed = -Double.greatestFiniteMagnitude

    /// Start the move to `level` from wherever the wash is right now, so a tab
    /// switch made mid-transition turns around smoothly instead of jumping.
    static func settle(on level: Level) {
        guard target != level.rawValue else { return }
        let now = Date.timeIntervalSinceReferenceDate
        origin = wash(at: now)
        target = level.rawValue
        departed = now
    }

    /// The wash at `t`, on a smoothstep so it both leaves and arrives at rest.
    static func wash(at t: TimeInterval) -> Double {
        let p = min(max((t - departed) / duration, 0), 1)
        return origin + (target - origin) * (p * p * (3 - 2 * p))
    }
}

// MARK: - Background

/// The app's backdrop: OLED black under a slow, low-opacity blue mesh gradient
/// whose control points sway on sine waves, and over that the tab's `Backdrop`
/// wash.
struct AppBackground: View {
    var body: some View {
        // Ticks every frame, with the points derived from the clock so the
        // motion is continuous rather than resetting on a keyframe.
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Color.black
                MeshGradient(width: 3, height: 3, points: meshPoints(at: t), colors: meshColors)
                    .blur(radius: 24)
                    // Low enough to read as a deep tint rather than a light.
                    .opacity(0.2)
                // Off the same clock as the mesh, so every page's copy of this
                // backdrop is at the identical point of the transition.
                Color.black.opacity(Backdrop.wash(at: t))
            }
            .ignoresSafeArea()
        }
    }

    /// Deep-navy corners with brighter blue blooms through the middle.
    private let meshColors: [Color] = [
        Theme.glow,    Theme.accent,   Theme.glow,
        Theme.accent2, Theme.accent,   Theme.accent2,
        Theme.glow,    Theme.accent2,  Theme.glow,
    ]

    /// A 3×3 grid of control points: corners pinned so the gradient fills the
    /// screen, the rest swaying on out-of-phase sine waves.
    private func meshPoints(at t: TimeInterval) -> [SIMD2<Float>] {
        func osc(_ base: Double, _ amp: Double, _ speed: Double, _ phase: Double) -> Float {
            Float(base + amp * sin(t * speed + phase))
        }
        return [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(osc(0.5, 0.18, 0.625, 0.0), 0),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(0, osc(0.5, 0.18, 0.55, 1.0)),
            SIMD2<Float>(osc(0.5, 0.12, 0.75, 2.0), osc(0.5, 0.12, 0.675, 3.0)),
            SIMD2<Float>(1, osc(0.5, 0.18, 0.60, 4.0)),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(osc(0.5, 0.18, 0.65, 5.0), 1),
            SIMD2<Float>(1, 1),
        ]
    }
}

// MARK: - Cards

/// The neutral container every section sits in.
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

/// A `PanelCard` washed in a tint, for guidance, errors and success.
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
    /// Wears a translucent glass capsule instead of the tinted fill, for an
    /// idle state that shouldn't read as a status chip.
    var glass: Bool = false

    var body: some View {
        let label = Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        // Liquid Glass is iOS 26+; older releases get the tinted capsule, which
        // is what every other pill on the screen already wears.
        if glass, #available(iOS 26.0, *) {
            label.glassEffect(.regular, in: Capsule())
        } else {
            label.background(Capsule().fill(color.opacity(0.16)))
        }
    }
}

/// Marks a feature that ships before it is proven. Sized to sit beside a title
/// without pushing it around, so the same tag works on a row and on a header.
struct BetaBadge: View {
    var body: some View {
        Text(L("Beta").uppercased())
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Theme.accent2)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.accent2.opacity(0.16)))
            .fixedSize()
    }
}

/// The hero at the top of each screen: a glyph, the title, and an accessory.
struct BrandHeader<Accessory: View>: View {
    var icon: String
    /// Shows the real app icon in place of the gradient SF Symbol, as the
    /// Install screen does to wear its home-screen identity.
    var image: String? = nil
    var title: String
    /// Tags the title, for a screen whose feature isn't proven yet.
    var beta: Bool = false
    /// A line tucked under the title, close enough to read as one block.
    var subtitle: String? = nil
    var animateIcon: Bool = false
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(spacing: 14) {
            glyph
                .frame(width: 86, height: 86)
                .shadow(color: Theme.glow, radius: 20, x: 0, y: 12)
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                    if beta { BetaBadge() }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
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
                // A breathe while a run is in flight, mirroring `.pulse`.
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

/// Inset, filled text-field background, softer than `.roundedBorder`.
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

/// The full-width gradient call-to-action; pass a `gradient` to recolour it.
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
    /// The insert and remove every status card uses: a fading scale.
    static var cardAppear: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.96, anchor: .top))
                .combined(with: .offset(y: -10)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
        )
    }
}

// MARK: - Page entrance

/// One object's part in a page's entrance cascade, staggered by `index` so they
/// settle one after another. Driven by `onAppear`, so it replays on every page
/// switch, and rows added later animate without disturbing the ones shown.
private struct CascadeItem: ViewModifier {
    let index: Int
    @State private var shown = false

    /// 55 ms apart: enough to read as a cascade, quick enough not to drag.
    private var delay: Double { Double(index) * 0.055 }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.98, anchor: .top)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(.smooth(duration: 0.4, extraBounce: 0.1).delay(delay)) {
                    shown = true
                }
            }
            .onDisappear { shown = false }
    }
}

extension View {
    /// Give an object its place in the entrance cascade (0 appears first).
    func cascadeItem(_ index: Int) -> some View { modifier(CascadeItem(index: index)) }
}
