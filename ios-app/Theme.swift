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

/// Shared backdrop darkness level and its animation between tabs.
///
/// Each page draws its own `AppBackground`, and pages overlap during a tab
/// change, so the state lives here: start level, target level and start time.
/// Every backdrop computes its value from the clock, so all copies show the
/// same frame.
@MainActor
enum Backdrop {
    /// Opacity of the black overlay on the mesh: bright (Install, About) or
    /// dark (Tools).
    enum Level: Double, CaseIterable {
        case bright = 0
        case dark   = 0.55
    }

    /// Duration of a full bright ↔ dark transition.
    private static let fullTravel: TimeInterval = 0.55

    /// Largest gap between levels. Shorter moves get proportionally less time,
    /// so all transitions run at the same speed.
    private static let span = (Level.allCases.map(\.rawValue).max() ?? 1)
                            - (Level.allCases.map(\.rawValue).min() ?? 0)

    private static var origin = Level.bright.rawValue
    private static var target = Level.bright.rawValue
    /// Far enough in the past that the first frame is at rest on `bright`.
    private static var departed = -Double.greatestFiniteMagnitude
    /// Duration of the current move, scaled to its distance.
    private static var travel = fullTravel

    /// Starts animating to `level` from the current value, so switching tabs
    /// mid-transition reverses smoothly. No-op if already heading to `level`.
    static func settle(on level: Level) {
        guard target != level.rawValue else { return }
        let now = Date.timeIntervalSinceReferenceDate
        origin = wash(at: now)
        target = level.rawValue
        departed = now
        // Scale duration by distance, so a mid-transition reversal isn't slow.
        travel = fullTravel * min(1, abs(target - origin) / span)
    }

    /// The wash at `t`, on a smoothstep so it both leaves and arrives at rest.
    static func wash(at t: TimeInterval) -> Double {
        guard travel > 0 else { return target }
        let p = min(max((t - departed) / travel, 0), 1)
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

// MARK: - Popups

/// A message that floats over the whole app, which dims and softly blurs
/// behind it (see `popupStack`). Each replaces a callout card that used to sit
/// under a page's progress; several stack, each closing on its own.
///
/// A blocking popup holds what a running step is waiting on, such as the
/// pairing code: closing it stops the run, so taps on the backdrop leave it
/// open, and its X asks before closing it.
///
/// Inside a `PopupGroupCard` it's drawn as a tile instead: no X or shadow of
/// its own, since the group's card has them.
struct PopupCard<Content: View>: View {
    var title: String
    var systemImage: String
    var tint: Color
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    /// The group card this one sits in as a tile, if any.
    @Environment(\.popupGroup) private var group
    /// True while a run is waiting on this card, so closing it ends the run.
    @Environment(\.popupEndsProcess) private var endsProcess
    /// Shows the "are you sure" alert before a blocking card closes.
    @State private var confirmingClose = false

    private var isTile: Bool { group != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: isTile ? 12 : 16) {
            // A tile titled like its group leaves the title to the group.
            if title != group?.title {
                header
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(isTile ? 16 : 20)
        .frame(maxWidth: 460)
        .background(
            shape
                .fill(Color(.secondarySystemBackground).opacity(isTile ? 0 : 1))
                .overlay(shape.fill(tint.opacity(0.1)))
        )
        .overlay(shape.strokeBorder(tint.opacity(isTile ? 0.25 : 0.35), lineWidth: 1))
        .shadow(color: .black.opacity(isTile ? 0 : 0.45), radius: 30, x: 0, y: 14)
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, requestClose)
        .alert(L("Closing this popup will end the process. Are you sure?"),
               isPresented: $confirmingClose) {
            Button(L("Yes"), role: .destructive, action: onClose)
            Button(L("No"), role: .cancel) { }
        }
    }

    /// Closes the card, asking first when that would end the run. A tile
    /// closes its whole group.
    private func requestClose() {
        if let group {
            group.close()
        } else if endsProcess {
            confirmingClose = true
        } else {
            onClose()
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: isTile ? 20 : 28, style: .continuous)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font((isTile ? Font.body : .title3).weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: isTile ? 34 : 40, height: isTile ? 34 : 40)
                .background(Circle().fill(tint.opacity(0.16)))
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if !isTile {
                PopupCloseButton(action: requestClose)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
    }
}

/// Popups that always come up together, as one card under a title of their
/// own: each sits inside as a tile in its own tint, and the card's X closes
/// them all. With only one of them up the card steps back and that one shows
/// as a popup of its own; the card stays in place, so the others join it
/// without a jump.
struct PopupGroupCard<Content: View>: View {
    var title: String
    var systemImage: String
    var tint: Color
    /// False while only one member is up.
    var isGrouped: Bool
    /// Closes every member.
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    /// True while a run is waiting on a member, so closing them ends the run.
    @Environment(\.popupEndsProcess) private var endsProcess
    @State private var confirmingClose = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isGrouped {
                header
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
            content()
        }
        .environment(\.popupGroup, isGrouped ? PopupGroup(title: title, close: requestClose) : nil)
        .padding(isGrouped ? 20 : 0)
        .frame(maxWidth: 460)
        .background(
            shape
                .fill(Color(.secondarySystemBackground))
                .overlay(shape.fill(tint.opacity(0.08)))
                .opacity(isGrouped ? 1 : 0)
        )
        .overlay(shape.strokeBorder(tint.opacity(isGrouped ? 0.35 : 0), lineWidth: 1))
        .shadow(color: .black.opacity(isGrouped ? 0.45 : 0), radius: 30, x: 0, y: 14)
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, requestClose)
        .alert(L("Closing this popup will end the process. Are you sure?"),
               isPresented: $confirmingClose) {
            Button(L("Yes"), role: .destructive, action: onClose)
            Button(L("No"), role: .cancel) { }
        }
    }

    /// Closes the group, asking first when that would end the run.
    private func requestClose() {
        if endsProcess {
            confirmingClose = true
        } else {
            onClose()
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(Circle().fill(tint.opacity(0.16)))
            Text(title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            PopupCloseButton(action: requestClose)
        }
    }
}

/// The X at the top right of a popup.
private struct PopupCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(8)
                .background(Circle().fill(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Close"))
    }
}

/// The group card a popup sits in as a tile; see `PopupGroupCard`.
struct PopupGroup {
    /// The group's title. A tile with the same one doesn't repeat it.
    var title: String
    /// Closes the whole group, asking first when that ends a run.
    var close: () -> Void
}

private struct PopupGroupKey: EnvironmentKey {
    static let defaultValue: PopupGroup? = nil
}

private struct PopupEndsProcessKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The group card a popup sits in as a tile, nil for one of its own.
    var popupGroup: PopupGroup? {
        get { self[PopupGroupKey.self] }
        set { self[PopupGroupKey.self] = newValue }
    }

    /// True when a run is waiting on the popup card, so closing it ends the
    /// run; set by `RootView`, which knows what each page is waiting on.
    var popupEndsProcess: Bool {
        get { self[PopupEndsProcessKey.self] }
        set { self[PopupEndsProcessKey.self] = newValue }
    }
}

/// Lays popups over this view, one above the other and centred as a group:
/// what's behind darkens and blurs a little, and takes no taps. Closing one
/// lets the rest glide back to the centre. Applied once, by `RootView`, so the
/// tab bar goes under too.
private struct PopupStack<Item: Identifiable & Equatable, Card: View>: ViewModifier {
    /// The popup cards up, top to bottom.
    var items: [Item]
    /// Runs on a tap outside the cards. Nil leaves the popups up, so a stray
    /// tap can't stop a run that's waiting on them.
    var onBackdropTap: (() -> Void)?
    @ViewBuilder var card: (Item) -> Card

    private var isPresented: Bool { !items.isEmpty }

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(isPresented)
            .overlay {
                ZStack {
                    if isPresented {
                        backdrop
                            .transition(.opacity)
                        // The first popup to open and the last to close zoom
                        // with the stack; the rest come and go inside it.
                        cards
                            .transition(.popup)
                    }
                }
                .animation(.smooth(duration: 0.35), value: isPresented)
            }
    }

    /// The cards, centred while they fit and scrolling once they don't.
    private var cards: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(items) { item in
                        card(item)
                            .transition(.popup)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                // The gaps around the cards are backdrop too.
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onBackdropTap?() }
                }
                .animation(.smooth(duration: 0.4, extraBounce: 0.08), value: items)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    /// A thinned-out material under a dark wash: the app stays recognisable
    /// behind, blurred a little and dimmed until the last popup closes. A
    /// material rather than `.blur` on the content, which would clip at the
    /// safe area and leave the status bar strip unblurred. The material is
    /// kept dark so in light mode it doesn't frost the app white and undo the
    /// dimming.
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).opacity(0.7)
                .environment(\.colorScheme, .dark)
            Color.black.opacity(0.5)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onBackdropTap?() }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Shows a popup card over this view for each of `items`, stacked in
    /// order; see `PopupStack`.
    func popupStack<Item: Identifiable & Equatable, Card: View>(_ items: [Item],
                                                                onBackdropTap: (() -> Void)?,
                                                                @ViewBuilder card: @escaping (Item) -> Card) -> some View {
        modifier(PopupStack(items: items, onBackdropTap: onBackdropTap, card: card))
    }
}

/// A popup that only reports: what went wrong, or what went right.
struct MessagePopup: View {
    var title: String
    var message: String
    var isError: Bool
    var onClose: () -> Void

    var body: some View {
        PopupCard(title: title,
                  systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                  tint: isError ? .red : .green,
                  onClose: onClose) {
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Numbered instructions, as the guides and pairing popups list them.
struct NumberedSteps: View {
    var steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(idx + 1)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.brand))
                    Text(step)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// The code an iPhone asks for while it pairs, as a popup of its own: big
/// enough to read at a glance, with where it goes.
struct PairingCodePopup: View {
    var pin: String
    var caption: String
    var onClose: () -> Void

    var body: some View {
        PopupCard(title: L("Pairing code"), systemImage: "lock.iphone", tint: .orange,
                  onClose: onClose) {
            VStack(spacing: 10) {
                Text(pin)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .tracking(8)
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
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
        // Liquid Glass needs iOS 26+; fall back to the tinted capsule.
        if glass, #available(iOS 26.0, *) {
            label.glassEffect(.regular, in: Capsule())
        } else {
            label.background(Capsule().fill(color.opacity(0.16)))
        }
    }
}

/// "BETA" tag for unfinished features, sized to sit next to a title.
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
    /// Asset image shown instead of the SF Symbol `icon`.
    var image: String? = nil
    var title: String
    /// Shows a Beta badge next to the title.
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

    /// A popup card rising into place, and sinking away when it closes.
    static var popup: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.92))
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
