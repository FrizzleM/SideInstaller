import SwiftUI

/// The app's shared visual language: one near-black ramp, one blue, and the
/// cards, buttons and headers every screen is composed from.
///
/// The surfaces stay quiet so the logo tiles' blue line art, an install's
/// progress and the pairing code are what the eye lands on. Depth comes from
/// a step between surfaces and a hairline edge, never a glow.
enum Theme {
    // MARK: Ramp

    /// The page behind everything: black with the faintest blue in it, so the
    /// logo tiles' black still reads as a tile.
    static let page = Color(red: 11 / 255, green: 12 / 255, blue: 15 / 255)
    /// A card on the page.
    static let card = Color(red: 20 / 255, green: 21 / 255, blue: 24 / 255)
    /// One step above a card: popups, which float over the dimmed app.
    static let raised = Color(red: 28 / 255, green: 30 / 255, blue: 34 / 255)
    /// A control's fill, a step up from whatever it sits on.
    static let control = Color.white.opacity(0.06)
    /// The edge of a card or control.
    static let hairline = Color.white.opacity(0.08)
    /// The primary button's fill: the one bright thing on a page.
    static let offWhite = Color(red: 237 / 255, green: 238 / 255, blue: 240 / 255)
    /// Captions, meta and quiet icons; at least 4.5:1 on a card.
    static let muted = Color(red: 128 / 255, green: 133 / 255, blue: 141 / 255)

    // MARK: Colour

    /// SideInstaller's blue, flat: progress, the selection and links. Light
    /// enough to read as text on every surface above.
    static let accent = Color(red: 47 / 255, green: 128 / 255, blue: 255 / 255)
    /// Done, connected, granted.
    static let positive = Color(red: 76 / 255, green: 195 / 255, blue: 138 / 255)
    /// Something needs the user, or will soon.
    static let warning = Color(red: 229 / 255, green: 161 / 255, blue: 64 / 255)
    /// Failed, missing, can't be undone.
    static let negative = Color(red: 229 / 255, green: 72 / 255, blue: 77 / 255)

    // MARK: Shape

    /// Corner radius of a control: a field, a button, a row.
    static let controlRadius: CGFloat = 12
    /// Corner radius of a card.
    static let cardRadius: CGFloat = 20
    /// Corner radius of a popup.
    static let popupRadius: CGFloat = 24

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

/// The page every screen sits on: still and near-black.
struct AppBackground: View {
    var body: some View {
        Theme.page.ignoresSafeArea()
    }
}

// MARK: - Cards

/// The container every section sits in.
struct PanelCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .cardSurface(in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

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
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.control))
                .contentShape(Circle())
        }
        // The card plays the sound, which depends on whether it asks first.
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
            UIPasteboard.general.string = Engine.shared.logText()
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
                        .foregroundStyle(Theme.muted)
                        .frame(width: 16, alignment: .leading)
                    Text(step)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Small components

/// A card's label: what the card is for, quieter than what it holds.
struct SectionTitle: View {
    var title: String
    var systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }
}

/// How something stands, in a few words after a small dot: the app's mark
/// for the tunnel, the device, the team and a run. Green is working, amber
/// and red need the user, and a muted dot is a state that needs nothing.
struct StatusDot: View {
    var text: String
    var color: Color
    /// A state that needs nothing from the user, shown with a muted dot.
    var idle = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(idle ? Theme.muted : color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// "Beta" tag for unfinished features, sized to sit next to a title.
struct BetaBadge: View {
    var body: some View {
        Text(L("Beta"))
            .font(.caption)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
            .fixedSize()
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
                            .foregroundStyle(.secondary)
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
                .resizable()
                .scaledToFill()
                .clipShape(tile)
                // The art's black tile would melt into the page without it.
                .overlay(tile.strokeBorder(Theme.hairline, lineWidth: 1))
        } else {
            ZStack {
                tile.fill(Theme.card)
                tile.strokeBorder(Theme.hairline, lineWidth: 1)
                Image(systemName: icon)
                    .font(.system(size: glyphSide * 32 / 72))
                    .foregroundStyle(.secondary)
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

/// The full-width call to action: off-white, the brightest thing on the page.
/// Plays `sound` as it fires.
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
            .foregroundStyle(isEnabled ? Theme.page : Theme.muted)
            // A spinner in the label, while the button's action is under way.
            .tint(Theme.page)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 20)
            .background(shape.fill(isEnabled ? Theme.offWhite : Theme.control))
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
