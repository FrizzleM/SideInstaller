import SwiftUI
import UIKit

/// The app's shared visual language: a ramp of night blues, three blues
/// with a job each, and the cards, buttons and headers every screen is
/// composed from.
///
/// In dark mode the surfaces are navy so dark they read as night, and the
/// blues are kept apart by what they do: `navy` for the logo art and the
/// wash at the top of a page, `blue` for what's filled behind white (the
/// main button), `accent` for what's drawn on the dark (progress, links,
/// the selection). Depth comes from a step between surfaces and a hairline
/// edge. In light mode `card` and `raised` step down to the system
/// backgrounds instead, so the dark text on them stays readable — a fixed
/// navy under black text was unreadable (Files page, 2026-11-22).
enum Theme {
    // MARK: Ramp

    /// A card on the page. Dark keeps the night navy; light uses the
    /// system's secondary background, so the black text on it stays
    /// readable — a fixed navy under black text was unreadable in
    /// light mode (Files page screenshot, 2026-11-22: the file-row
    /// card and the file-management card were dark navy with near-
    /// black text, while the rest of the page was light).
    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 13 / 255, green: 21 / 255, blue: 36 / 255, alpha: 1)
            : UIColor.secondarySystemBackground
    })
    /// One step above a card: popups, which float over the dimmed app.
    /// Dark keeps the night navy; light is the system background, so
    /// popup text (.primary, black in light mode) stays readable —
    /// the same fixed-navy disease as `card`, confirmed by reading
    /// the code (no screenshot, but the surface and the text colour
    /// are the same pair). The two plain icon tiles that use this as
    /// a glyph backdrop go light with it, which stays legible.
    static let raised = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 20 / 255, green: 30 / 255, blue: 49 / 255, alpha: 1)
            : UIColor.systemBackground
    })
    /// The pale blue that controls and edges are drawn in, faintly, so they
    /// stay in the ramp's hue instead of greying it.
    static let ice = Color(red: 185 / 255, green: 211 / 255, blue: 249 / 255)
    /// A control's fill, a step up from whatever it sits on. Dark keeps the
    /// pale-blue wash; light uses black at 5%, so a control stays a step up
    /// from the card without tinting it blue.
    static let control = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 185 / 255, green: 211 / 255, blue: 249 / 255, alpha: 0.07)
            : UIColor(white: 0, alpha: 0.05)
    })
    /// The edge of a card or control. Dark keeps the pale-blue hairline;
    /// light uses black at 12%.
    static let hairline = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 185 / 255, green: 211 / 255, blue: 249 / 255, alpha: 0.1)
            : UIColor(white: 0, alpha: 0.12)
    })
    /// Captions, meta and quiet icons: a slate blue. Dark keeps the old
    /// value (at least 4.5:1 on a popup, more on a card); light uses a
    /// deeper slate (#5A6678, 5.82:1 on white, 5.22:1 on a card) — the
    /// old value was only 3.36:1 on white in light mode.
    static let muted = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 127 / 255, green: 141 / 255, blue: 165 / 255, alpha: 1)
            : UIColor(red: 90 / 255, green: 102 / 255, blue: 120 / 255, alpha: 1)
    })

    // MARK: Colour

    /// The deep blue of the logo art's patterns, and of the wash at the top
    /// of every page.
    static let navy = Color(red: 9 / 255, green: 50 / 255, blue: 143 / 255)
    /// The filled blue: the main button and a ticked box. White on it reads
    /// at 4.8:1.
    static let blue = Color(red: 38 / 255, green: 105 / 255, blue: 237 / 255)
    /// The light blue drawn on the dark: progress, the selection, links and
    /// a card's label icon. Dark keeps the old value (at least 6:1 on a card);
    /// light uses a deeper blue (#1F5BD0, 6.06:1 on white, 5.43:1 on a card) —
    /// the old value was only 2.49:1 on white in light mode.
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 96 / 255, green: 167 / 255, blue: 253 / 255, alpha: 1)
            : UIColor(red: 31 / 255, green: 91 / 255, blue: 208 / 255, alpha: 1)
    })
    static let accent2 = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.68, blue: 1.0, alpha: 1)
            : UIColor(red: 77 / 255, green: 141 / 255, blue: 255 / 255, alpha: 1) // 浅色 #4D8DFF，与 accent 拉开一档
    })
    /// Deep-navy halo behind each header icon, matching the icon art (#011A5C).
    static let glow = Color(red: 1/255, green: 26/255, blue: 92/255)

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
    /// Done, connected, granted.
    static let positive = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(red: 76/255, green: 195/255, blue: 138/255, alpha: 1)   // 深色保持 #4CC38A，深卡 8.24:1
        : UIColor(red: 30/255, green: 125/255, blue: 50/255, alpha: 1) }) // 浅色 #1E7D32，白底 5.20:1 / 浅卡 4.66:1
    /// Something needs the user, or will soon.
    static let warning = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(red: 229/255, green: 161/255, blue: 64/255, alpha: 1)   // 深色保持 #E5A140
        : UIColor(red: 140/255, green: 94/255,  blue: 0,     alpha: 1) }) // 浅色 #8C5E00，白底 5.65:1 / 浅卡 5.06:1
    /// Failed, missing, can't be undone.
    static let negative = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(red: 229/255, green: 72/255,  blue: 77/255, alpha: 1)   // 深色保持 #E5484D
        : UIColor(red: 200/255, green: 30/255,  blue: 30/255, alpha: 1) }) // 浅色 #C81E1E，白底 5.74:1 / 浅卡 5.14:1
    /// 顶栏/药丸/安装 pill 的填充：浅色沿用现浅 accent2，深色用 Theme.blue。
    /// 不能直接改 accent2 深色分支——accent2 同时是深色正文色（深卡 7.67:1）。
    static let topBarFill = Color(UIColor { t in t.userInterfaceStyle == .dark
        ? UIColor(red: 38/255, green: 105/255, blue: 237/255, alpha: 1)   // 深色 #2669ED，白字 4.85:1
        : UIColor(red: 31/255, green: 91/255,  blue: 208/255, alpha: 1) }) // 浅色 #1F5BD0，白字 6.06:1
    /// 徽章类深填充（圆点/绿 pill 用，白字均过 5:1，双模式通用固定值）。
    static let badgePositive = Color(red: 30/255,  green: 125/255, blue: 50/255)  // #1E7D32，白字 5.20:1
    static let badgeWarning  = Color(red: 140/255, green: 94/255,  blue: 0)       // #8C5E00，白字 5.65:1
    /// Tools 行深瓦色（B-11）：白字图标均过 4.5:1，双模式通用固定值。
    /// 绿/橙复用徽章深填充，蓝复用 Theme.blue。
    static let tilePurple = Color(red: 107/255, green: 33/255,  blue: 168/255)  // #6B21A8，白字 8.72:1
    static let tileTeal   = Color(red: 14/255,  green: 116/255, blue: 144/255)  // #0E7490，白字 5.36:1
    static let tileCyan   = Color(red: 3/255,   green: 105/255, blue: 161/255)  // #0369A1，白字 5.93:1

    // MARK: Shape

    /// Corner radius of a control: a field, a button, a row.
    static let controlRadius: CGFloat = 12
    /// Corner radius of a card.
    static let cardRadius: CGFloat = 20
    /// Corner radius of a popup.
    static let popupRadius: CGFloat = 20

    /// The widest a page's column grows, its padding included. A phone is
    /// narrower than this; a wider window, such as an open iPhone Duo (about
    /// 950 points across) or an iPad, keeps the column at this width and
    /// centres it rather than stretching every card across the screen.
    static let columnWidth: CGFloat = 600
}

// MARK: - Page column

extension View {
    /// Holds a page's content to `Theme.columnWidth`, centred. Goes inside the
    /// page's scroll view, which still spans the window, so the page scrolls
    /// from anywhere and its backdrop fills the screen.
    func pageColumn() -> some View {
        frame(maxWidth: Theme.columnWidth)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Background

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

/// The page every screen sits on: the night-blue page with a wash of navy at
/// the top, where each page's logo tile and title sit, gone by the middle of
/// a phone's screen. Still: nothing in it moves.

struct AppBackground: View {
    // 浅色下也得可读：以前底恒黑，浅色时 .primary 是黑色，黑字压黑底
    // （关于页截图就是这样）。底色跟随浅/深色，浅色用系统底色 + 淡蓝晕，
    // 深色保持原来的黑底蓝晕；工具页的深浅过渡在浅色下只压 1/4，避免压灰。
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // A-3（SIDE-32）：10Hz 就够——动画只是缓慢摇摆，不必逐帧重算
        // MeshGradient + blur；点仍由时钟推导，运动连续不跳变。
        TimelineView(.animation(minimumInterval: 0.1, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let light = colorScheme == .light
            ZStack {
                light ? Color(.systemBackground) : Color.black
                mesh(at: t)
                    .blur(radius: 24)
                    // Low enough to read as a deep tint rather than a light.
                    .opacity(light ? 0.12 : 0.2)
                // Off the same clock as the mesh, so every page's copy of this
                // backdrop is at the identical point of the transition.
                Color.black.opacity(Backdrop.wash(at: t) * (light ? 0.25 : 1))
            }
            .ignoresSafeArea()
    }
}

    /// The blue layer: the swaying mesh, or on iOS 17 (no `MeshGradient`) a
    /// radial bloom that follows the mesh's centre point.
    @ViewBuilder
    private func mesh(at t: TimeInterval) -> some View {
        let points = meshPoints(at: t)
        if #available(iOS 18.0, *) {
            MeshGradient(width: 3, height: 3, points: points, colors: meshColors)
        } else {
            let centre = points[4]
            RadialGradient(colors: [Theme.accent2, Theme.accent, Theme.glow],
                           center: UnitPoint(x: CGFloat(centre.x), y: CGFloat(centre.y)),
                           startRadius: 0, endRadius: 600)
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

/// The container every section sits in.
struct PanelCard<Content: View>: View {
    /// Inner padding: 20 by default; tight list rows use 16.
    var padding: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .cardSurface(in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

/// A `PanelCard` washed in a tint, for guidance, errors and success.
struct CalloutCard<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            )
    }
}

/// 触感反馈集中一处（全仓唯一 helper，别每处各写一套）：主操作
/// .medium，其余 .light；完成/失败走 notification。只在用户手势
/// 触发处调用（点按动作里），别在后台回调里乱震；系统级触感
/// 开关自带，不另起设置项。
enum CZFHaptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

/// 大按钮按压态（plain 样式本身不给按压反馈，点着像没点）：
/// 按下时整块微缩 + 变淡，松手复原；只改观感，不改点击行为。
/// 签名页红/蓝大按钮用，别的 plain 按钮不动。
struct CZFPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// What a card is made of: a pane of glass with nothing in it. The backdrop
/// shows through untouched, under the faintest wash, and the pane is drawn by
/// its rim: lit along the top, dim down the sides, catching a little light
/// again at the foot. Drawn by hand, since the system's glass and materials
/// all frost what's behind them, which over this backdrop reads as gray.
/// What a card is made of: a step up from the page, and a hairline edge.
private struct CardSurface<S: InsettableShape>: ViewModifier {
    var shape: S
    /// False takes the surface away without changing the view, for one that
    /// is a card only some of the time.
    var shown: Bool

    func body(content: Content) -> some View {
        content
            .background(shape.fill(Theme.card.opacity(shown ? 1 : 0)))
            .overlay(shape.strokeBorder(Theme.hairline.opacity(shown ? 1 : 0), lineWidth: 1))
    }
}

extension View {
    /// Puts a card's surface behind this view, cut to `shape`.
    func cardSurface(in shape: some InsettableShape, shown: Bool = true) -> some View {
        modifier(CardSurface(shape: shape, shown: shown))
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
/// its own, since the group's card has them. `tint` colours only its symbol;
/// the card itself stays neutral.
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
        VStack(alignment: .leading, spacing: 16) {
            // A tile titled like its group leaves the title to the group.
            if title != group?.title {
                header
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(isTile ? 16 : 20)
        .frame(maxWidth: 460)
        .background(shape.fill(isTile ? Color.clear : Theme.raised))
        .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(isTile ? 0 : 0.5), radius: 24, x: 0, y: 12)
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
            SoundEffects.play(.tap)
            confirmingClose = true
        } else {
            SoundEffects.play(.dismiss)
            onClose()
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: isTile ? 16 : Theme.popupRadius, style: .continuous)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if !isTile {
                PopupCloseButton(action: requestClose)
                    .transition(.opacity)
            }
        }
    }
}

/// Popups that always come up together, as one card under a title of their
/// own: each sits inside as a tile, and the card's X closes them all. With
/// only one of them up the card steps back and that one shows as a popup of
/// its own; the card stays in place, so the others join it without a jump.
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
        VStack(alignment: .leading, spacing: 12) {
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
        .background(shape.fill(Theme.raised).opacity(isGrouped ? 1 : 0))
        .overlay(shape.strokeBorder(Theme.hairline.opacity(isGrouped ? 1 : 0), lineWidth: 1))
        .shadow(color: .black.opacity(isGrouped ? 0.5 : 0), radius: 24, x: 0, y: 12)
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
            SoundEffects.play(.tap)
            confirmingClose = true
        } else {
            SoundEffects.play(.dismiss)
            onClose()
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.popupRadius, style: .continuous)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
            Text(title)
                .font(.title3.weight(.semibold))
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
        // The card plays the sound, which depends on whether it asks first.
        IconCircleButton(systemImage: "xmark", sound: nil, action: action)
            .accessibilityLabel(L("Close"))
    }
}

// MARK: - Shared components (0.9.137)

/// The shared search field: a magnifier on a control fill, used wherever a
/// list is filtered by name. Replaces the four hand-copied grey search boxes
/// (Files, Sources ×2, Enterprise library picker).
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.muted)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textFieldStyle(.plain)
            // F-1 (0.9.180): one-tap clear — every list with a search
            // field used to need selecting the text to empty it.
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Clear"))
            }
        }
        .padding(8)
        .background(Theme.control)
        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
    }
}

/// A page's empty state: a 40pt icon, a headline and a muted footnote.
struct EmptyState: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(Theme.muted)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A small round icon button: a 32pt circle with a 44pt hit target, for the
/// close, chevron and info buttons on cards and headers.
struct IconCircleButton: View {
    var systemImage: String
    /// Nil plays no sound (the popup card plays its own on close).
    var sound: UISound? = .tap
    var action: () -> Void

    var body: some View {
        Group {
            if let sound {
                Button(action: action) { label }
                    .buttonStyle(.plain, sound: sound)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.plain)
            }
        }
        .frame(width: 44, height: 44)
    }

    private var label: some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.muted)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Theme.control))
            .contentShape(Rectangle())
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
                .animation(.smooth(duration: 0.3), value: isPresented)
            }
    }

    /// The cards, centred while they fit and scrolling once they don't.
    private var cards: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
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
                .animation(.smooth(duration: 0.35), value: items)
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

/// A popup that only reports: what went wrong, or what went right. An error
/// the app can't explain offers Copy logs.
struct MessagePopup: View {
    var title: String
    var message: String
    var isError: Bool
    var onClose: () -> Void

    var body: some View {
        PopupCard(title: title,
                  systemImage: isError ? "exclamationmark.triangle" : "checkmark.seal",
                  tint: isError ? Theme.negative : Theme.positive,
                  onClose: onClose) {
            ErrorMessage(message: message, offersLogs: isError)
        }
    }
}

/// An error popup's message, with Copy logs under it unless the message
/// already says how to fix it.
struct ErrorMessage: View {
    var message: String
    /// False when something else on screen explains the fix.
    var offersLogs = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if offersLogs && !ErrorHelp.isExplained(message) {
                CopyLogsButton()
            }
        }
    }
}

/// Error messages that tell the user what to do themselves ("pick the .ipa
/// file itself", "Wi-Fi is off"). Every other error is one the app can't help
/// with, so its popup offers the activity log to send on.
enum ErrorHelp {
    private static let lock = NSLock()
    private static var explained = Set<String>()

    /// Marks `message` as one that explains its own fix, and returns it.
    @discardableResult
    static func explained(_ message: String) -> String {
        lock.lock(); defer { lock.unlock() }
        explained.insert(message)
        return message
    }

    static func isExplained(_ message: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return explained.contains(message)
    }
}

/// Copies the activity log, the same text as Settings › Activity Log › Copy,
/// and says so for a moment.
struct CopyLogsButton: View {
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = LogStore.shared.text
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        } label: {
            Label(copied ? L("Copied") : L("Copy logs"),
                  systemImage: copied ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(SecondaryButtonStyle(), sound: .rise)
        .animation(.smooth(duration: 0.2), value: copied)
    }
}

/// Numbered instructions, as the guides and pairing popups list them: the
/// numbers set in figures, on the first line of each step.
struct NumberedSteps: View {
    var steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(idx + 1)")
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 16, alignment: .leading)
                    Text(step)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 44, alignment: .top)
            }
        }
    }
}

/// The code an iPhone asks for while it pairs: one figure to a key, big
/// enough to read across a room and type in without losing your place.
struct PairingCodeDigits: View {
    var pin: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(pin.enumerated()), id: \.offset) { _, digit in
                Text(String(digit))
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .frame(maxWidth: 44, minHeight: 56)
                    .background(key.fill(Theme.control))
                    .overlay(key.strokeBorder(Theme.hairline, lineWidth: 1))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pin.map(String.init).joined(separator: " "))
    }

    private var key: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
    }
}

/// The code an iPhone asks for while it pairs, as a popup of its own, with
/// where it goes.
struct PairingCodePopup: View {
    var pin: String
    var caption: String
    var onClose: () -> Void

    var body: some View {
        PopupCard(title: L("Pairing code"), systemImage: "lock.iphone", tint: Theme.warning,
                  onClose: onClose) {
            VStack(spacing: 12) {
                PairingCodeDigits(pin: pin)
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Small components

/// A card's label: what the card is for, quieter than what it holds, after
/// an icon in the light blue.
struct SectionTitle: View {
    var title: String
    var systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.muted)
        } icon: {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
        }
    }
}

/// How something stands, in a few words after a small dot: the app's mark
/// for the tunnel, the device, the team and a run. Green is working, amber
/// and red need the user, and a muted dot is a state that needs nothing.
struct StatusDot: View {
    var text: String
    var color: Color
    /// The text colour. Defaults to Theme.muted; a page that needs the
    /// system secondary label can pass .secondary instead.
    var textColor: Color = Theme.muted
    /// A state that needs nothing from the user, shown with a muted dot.
    var idle = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(idle ? Theme.muted : color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.footnote)
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

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

/// "Beta" tag for unfinished features, sized to sit next to a title.
struct BetaBadge: View {
    var body: some View {
        Text(L("Beta"))
            .font(.caption)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1))
            .fixedSize()
    }
}

extension Image {
    /// A logo tile's art, filling its frame: SideInstaller's own are the
    /// `navy` patterns and a white glyph on a night-blue tile.
    func logoArt() -> some View {
        resizable()
            .scaledToFill()
    }
}

/// The top of each screen: the page's logo tile, the title, and an accessory.
///
/// In a short window (an iPhone on its side, or a closed iPhone Duo stood up
/// like a tent) it takes one row, the glyph beside the title, so it doesn't
/// fill the screen and push the page's controls out of sight.
struct BrandHeader<Accessory: View>: View {
    var icon: String
    /// Asset image shown instead of the SF Symbol `icon`.
    var image: String? = nil
    var title: String
    /// Shows a Beta badge next to the title.
    var beta: Bool = false
    /// A line tucked under the title, close enough to read as one block.
    var subtitle: String? = nil
    /// Breathe/pulse the icon while a run is in flight.
    var animateIcon: Bool = false
    @ViewBuilder var accessory: () -> Accessory

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// True in a short window, where the header takes one row.
    private var isRow: Bool { verticalSizeClass == .compact }
    private var glyphSide: CGFloat { isRow ? 48 : 72 }
    private var alignment: HorizontalAlignment { isRow ? .leading : .center }

    var body: some View {
        // One layout that changes shape, so a rotation moves the pieces
        // rather than swapping them out.
        let layout = isRow ? AnyLayout(HStackLayout(spacing: 16))
                           : AnyLayout(VStackLayout(spacing: 16))
        layout {
            glyph
                .frame(width: glyphSide, height: glyphSide)
            VStack(alignment: alignment, spacing: 8) {
                VStack(alignment: alignment, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font((isRow ? Font.title : .largeTitle).weight(.semibold))
                        if beta { BetaBadge() }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                }
                accessory()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// The icon art's corner radius, at any size.
    private var cornerRadius: CGFloat { glyphSide * 23 / 86 }

    private var tile: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var glyph: some View {
        if let image {
            Image(image)
                .logoArt()
                .clipShape(tile)
                // A breathe while a run is in flight, mirroring `.pulse`.
                .scaleEffect(animateIcon ? 1.04 : 1)
                .animation(animateIcon ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                       : .default,
                           value: animateIcon)
                // The art's dark tile would melt into the page without it.
                .overlay(tile.strokeBorder(Theme.hairline, lineWidth: 1))
        } else {
            ZStack {
                tile.fill(Theme.navy)
                tile.strokeBorder(Theme.hairline, lineWidth: 1)
                Image(systemName: icon)
                    .font(.system(size: glyphSide * 32 / 72))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: animateIcon)
            }
        }
    }
}

// MARK: - Field styling

/// A control's inset fill and hairline, for a `.plain` text field or a field
/// that opens a menu.
private struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(shape.fill(Theme.control))
            .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

extension View {
    /// Wrap a `.plain` text/secure field in the app's inset field background.
    func fieldBackground() -> some View { modifier(FieldBackground()) }
}

// MARK: - Buttons

/// The full-width call to action: filled `blue` under a white label, the one
/// solid colour on a page. Plays `sound` as it fires.
struct PrimaryButtonStyle: PrimitiveButtonStyle {
    var sound: UISound = .press

    func makeBody(configuration: Configuration) -> some View {
        SoundingButtonStyle(base: PrimaryButtonLook(), sound: sound)
            .makeBody(configuration: configuration)
    }
}

/// How `PrimaryButtonStyle` draws its button.
private struct PrimaryButtonLook: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }
}

private struct PrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.white : Theme.muted)
            // A spinner in the label, while the button's action is under way.
            .tint(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 20)
            .background(shape.fill(isEnabled ? Theme.blue : Theme.control))
            .contentShape(shape)
            .modifier(PressFeedback(isPressed: configuration.isPressed))
    }
}

/// The quiet button beside or under a primary one: a control fill and a
/// hairline, in the text colour, red for a destructive role, or `tint` for
/// an action that carries a warning. Follows `controlSize`.
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        SecondaryButtonBody(configuration: configuration, tint: tint)
    }
}

private struct SecondaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color?
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    private var isSmall: Bool { controlSize == .small || controlSize == .mini }
    private var isLarge: Bool { controlSize == .large || controlSize == .extraLarge }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: isSmall ? 8 : Theme.controlRadius, style: .continuous)
        configuration.label
            .font((isSmall ? Font.footnote : isLarge ? .body : .subheadline).weight(.medium))
            .foregroundStyle(labelColor)
            .padding(.horizontal, isSmall ? 12 : 16)
            .frame(minHeight: height)
            .background(shape.fill(Theme.control))
            .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
            .modifier(PressFeedback(isPressed: configuration.isPressed))
    }

    private var height: CGFloat {
        switch controlSize {
        case .mini, .small:       32
        case .large, .extraLarge: 52
        default:                  44
        }
    }

    private var labelColor: Color {
        if configuration.role == .destructive { return Theme.negative }
        return tint ?? .primary
    }
}

/// A press: the button gives a little, then springs back without bouncing.
private struct PressFeedback: ViewModifier {
    var isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1)
            .opacity(isPressed ? 0.85 : 1)
            .animation(.smooth(duration: 0.15), value: isPressed)
    }
}

// MARK: - Transitions

extension AnyTransition {
    /// The insert and remove every status card uses: a short fade and rise.
    static var cardAppear: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(y: -8)),
                    removal: .opacity)
    }

    /// A popup fading into place, and away when it closes.
    static var popup: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.96))
    }
}

// MARK: - Page entrance

/// One object's part in a page's entrance: a short fade and rise, staggered by
/// `index` so the first few settle one after another. Driven by `onAppear`, so
/// it replays on every page switch, and rows added later animate without
/// disturbing the ones shown.
private struct CascadeItem: ViewModifier {
    let index: Int
    @State private var shown = false

    /// 50 ms apart, and nothing past the sixth waits longer than the sixth.
    private var delay: Double { Double(min(index, 5)) * 0.05 }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .onAppear {
                withAnimation(.smooth(duration: 0.4).delay(delay)) {
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

// MARK: - Restored from the fork (2026-10-25 merge recovery)
// 290310a took Theme.swift from the upstream side, dropping the fork's
// appearance enum below; restored verbatim from the fork @ 3e560dd.

/// 界面外观：跟随系统 / 浅色 / 深色。设置页与 App 入口共用同一
/// UserDefaults 键（SIDAppearance），入口处统一用 preferredColorScheme 生效。
enum AppAppearance: String, CaseIterable {
    case system, light, dark

    /// 传给 preferredColorScheme 的值；nil 表示跟随系统。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return L("Follow System")
        case .light:  return L("Light")
        case .dark:   return L("Dark")
        }
    }
}

/// U-UI：截图式蓝顶栏（复用 Theme.accent2 #4DAEFF，不发明新色）。
extension View {
    func blueTopBar() -> some View {
        self
            .toolbarBackground(Theme.topBarFill, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
