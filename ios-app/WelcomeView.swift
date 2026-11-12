import SwiftUI
import UIKit

// MARK: - First-run setup

/// What a first launch asks before the app opens, a page each: the terms,
/// where this copy came from, and the Apple ID to sign in with.
enum SetupPage: Int, CaseIterable, Hashable {
    case terms, source, account

    /// The page's place in the setup, from 1.
    var number: Int { rawValue + 1 }

    /// Where setup picks up: the first page not answered on an earlier
    /// launch, read from the settings the pages keep.
    static var resumed: SetupPage {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: SetupView.acceptedTermsKey) { return .terms }
        if !defaults.bool(forKey: OfficialSourceCheck.defaultsKey) { return .source }
        return .account
    }
}

/// The first-run setup before `RootView`: three pages under a bar that fills a
/// segment for each. Moving on, the page's objects slide out to the left one
/// after another while the next page's come in from the right.
///
/// The terms and the sideinstaller.net answer are kept as soon as they're
/// given, so setup left halfway resumes at the page it stopped on. The Apple
/// ID page ends it: Continue saves the account, and "Set this up later" skips
/// it; either sets `hasCompletedAccountSetup` and the app opens.
struct SetupView: View {
    static let acceptedTermsKey = "hasAcceptedTOS"

    @AppStorage(SetupView.acceptedTermsKey) private var hasAcceptedTOS = false
    @AppStorage(OfficialSourceCheck.defaultsKey) private var confirmedOfficialSource = false
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer

    /// The page in front.
    @State private var page = SetupPage.resumed
    /// The page sliding out, drawn under the one coming in until it's gone.
    @State private var leaving: SetupPage?
    /// False until the page in front has started coming in.
    @State private var arrived = false
    /// The segments of the bar filled so far.
    @State private var filled = 0
    /// The "Update to iOS 27" popup, for an iPhone below 27 that can run it.
    @State private var recommendingUpdate = false

    var body: some View {
        VStack(spacing: 0) {
            SetupProgressBar(filled: filled, total: SetupPage.allCases.count)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .pageColumn()
            // The page leaving and the one coming in overlap while they move.
            ZStack {
                ForEach(shownPages, id: \.self) { shown in
                    pageView(shown)
                        .environment(\.setupMotion, motion(of: shown))
                        .allowsHitTesting(shown == page)
                        .accessibilityHidden(shown != page)
                        .zIndex(shown == page ? 1 : 0)
                        .transition(.identity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppBackground())
        .preferredColorScheme(.dark)
        .task {
            // A beat for the first page to be drawn where it starts from.
            try? await Task.sleep(for: .milliseconds(150))
            arrive()
            // An iPhone that can update to iOS 27 is told so once the terms
            // have come in: there it pairs with itself, with no computer.
            guard page == .terms, Engine.canUpdateToSelfPairingOS else { return }
            try? await Task.sleep(for: .seconds(1.25))
            if page == .terms { recommendingUpdate = true }
        }
        .alert(L("Update to iOS %@", Engine.minimumOSText), isPresented: $recommendingUpdate) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(L("This iPhone can run iOS %@, where SideInstaller works without a computer: the iPhone pairs with itself, so there's no pairing file to make. Update in Settings › General › Software Update.",
                   Engine.minimumOSText))
        }
    }

    /// The leaving page first, so the one in front is drawn over it.
    private var shownPages: [SetupPage] {
        [leaving, page].compactMap { $0 }
    }

    private func motion(of shown: SetupPage) -> SetupMotion {
        guard shown == page else { return .leaving }
        return arrived ? .settled : .waiting
    }

    @ViewBuilder
    private func pageView(_ shown: SetupPage) -> some View {
        switch shown {
        case .terms:
            TermsPage {
                hasAcceptedTOS = true
                advance(to: confirmedOfficialSource ? .account : .source)
            }
        case .source:
            SourcePage {
                confirmedOfficialSource = true
                advance(to: .account)
            }
        case .account:
            AccountPage()
        }
    }

    /// Sends the page in front out to the left and brings `next` in from the
    /// right a beat later, then drops the old page once it's out of sight.
    private func advance(to next: SetupPage) {
        guard next != page, leaving == nil else { return }
        leaving = page
        arrived = false
        page = next
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            arrive()
            try? await Task.sleep(for: .milliseconds(560))
            leaving = nil
        }
    }

    /// The page in front starts coming in, and the bar fills up to it.
    private func arrive() {
        arrived = true
        filled = page.number
        // VoiceOver starts over on the new page.
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
}

// MARK: - Pages

/// Page 1: the logo, the name and the terms, which Start waits for.
private struct TermsPage: View {
    let onStart: () -> Void
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @State private var accepted = false

    var body: some View {
        // The logo tile and the name sit a little above the middle of the
        // space the controls leave.
        SetupPageLayout(lift: 48) {
            VStack(spacing: 20) {
                logo
                    .setupObject(0)
                VStack(spacing: 8) {
                    Text("SideInstaller")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(L("an app by Frizzle"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .setupObject(1)
            }
        } actions: {
            VStack(spacing: 20) {
                // Below iOS 27, say up front that a pairing file made on a
                // computer is needed.
                if !Engine.deviceCanSelfPair {
                    pairingFileNotice
                        .setupObject(2)
                }
                checkboxRow
                    .setupObject(3)
                Button(L("Start"), action: onStart)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!accepted)
                    .animation(.smooth(duration: 0.2), value: accepted)
                    .setupObject(4)
            }
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
            // The art's dark tile would melt into the page without it.
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
                            .fill(accepted ? Theme.blue : Theme.control)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Theme.ice.opacity(accepted ? 0 : 0.3), lineWidth: 1)
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

/// Page 2: was this copy downloaded from sideinstaller.net? "No" turns the
/// page into the warning, with Back to answer again; the bar stays where it
/// is, as the answer is still to come.
private struct SourcePage: View {
    let onConfirm: () -> Void
    @State private var unofficial = false

    var body: some View {
        SetupPageLayout {
            ZStack {
                if unofficial {
                    OfficialSourceWarning()
                        .transition(.cardAppear)
                } else {
                    OfficialSourceQuestion()
                        .transition(.cardAppear)
                }
            }
        } actions: {
            ZStack {
                if unofficial {
                    OfficialSourceWarningActions(onBack: { unofficial = false }, onConfirm: onConfirm)
                        .transition(.cardAppear)
                } else {
                    OfficialSourceAnswers(onYes: onConfirm) { unofficial = true }
                        .transition(.cardAppear)
                }
            }
        }
        .animation(.smooth(duration: 0.35), value: unofficial)
    }
}

/// Page 3: the Apple ID every screen that signs in uses. Can be skipped and
/// set later in Settings › Account.
private struct AccountPage: View {
    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false
    @EnvironmentObject private var accounts: AccountStore
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: AccountField?

    private var canSave: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        SetupPageLayout {
            VStack(spacing: 24) {
                header
                    .setupObject(0)
                fields
                    .setupObject(1)
            }
        } actions: {
            VStack(spacing: 16) {
                Button(L("Continue")) {
                    accounts.save(appleID: email, password: password)
                    hasCompletedAccountSetup = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
                .animation(.smooth(duration: 0.2), value: canSave)
                .setupObject(2)

                Button(L("Set this up later")) { hasCompletedAccountSetup = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain, sound: .tap)
                    .setupObject(3)
            }
        }
        // Focus only once the fields have come in. AutoFill pairs the username
        // field with a *visible* password field when it gains focus; focusing
        // while they're still transparent makes it fill the email alone, then
        // the password separately.
        .task {
            try? await Task.sleep(for: .milliseconds(850))
            focus = .email
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text(L("Sign in with your Apple ID"))
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(L("Don't worry, these are stored locally"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fields: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                TextField(L("Email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textFieldStyle(.plain)
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
                    .fieldBackground()
                SecureField(L("Password"), text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .focused($focus, equals: .password)
                    .fieldBackground()
            }
        }
    }
}

// MARK: - Page frame

/// A setup page: its content in the middle of the space above, scrolling when
/// it doesn't fit, and its buttons at the foot, where every page keeps its way
/// on. The keyboard pushes the buttons up with it.
private struct SetupPageLayout<Content: View, Actions: View>: View {
    /// How far above the middle the content sits.
    var lift: CGFloat = 0
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView {
                    content()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .padding(.bottom, lift)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                        .pageColumn()
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
            actions()
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 28)
                .pageColumn()
        }
    }
}

// MARK: - Progress

/// How far setup has come: a segment for each page, filled up to the one in
/// front. A segment fills from its leading edge as its page comes in.
private struct SetupProgressBar: View {
    let filled: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                SegmentFill(fraction: index <= filled ? 1 : 0)
                    .fill(Theme.accent)
                    .background(Capsule().fill(Theme.ice.opacity(0.12)))
                    .frame(height: 4)
            }
        }
        .animation(.smooth(duration: 0.6), value: filled)
        .accessibilityElement()
        .accessibilityLabel(L("Step %@ of %@", "\(max(filled, 1))", "\(total)"))
    }
}

/// A segment's fill, `fraction` of the way along, with round ends.
private struct SegmentFill: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let width = rect.width * min(max(fraction, 0), 1)
        let bar = CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height)
        return Path(roundedRect: bar, cornerRadius: min(rect.height, width) / 2)
    }
}

// MARK: - Object motion

/// Where a setup page's objects are in its move: off to the right before the
/// page comes in, in place, or off to the left as it leaves.
enum SetupMotion: Hashable {
    case waiting, settled, leaving
}

private struct SetupMotionKey: EnvironmentKey {
    /// Outside the setup nothing moves: the objects are simply in place.
    static let defaultValue = SetupMotion.settled
}

extension EnvironmentValues {
    /// The move of the setup page this view is on.
    var setupMotion: SetupMotion {
        get { self[SetupMotionKey.self] }
        set { self[SetupMotionKey.self] = newValue }
    }
}

/// One object's part in a setup page's move: in from the right as the page
/// arrives and out to the left as it leaves, fading as it goes, each a little
/// after the one before (`index` 0 moves first). With Reduce Motion on, the
/// objects only fade.
private struct SetupObject: ViewModifier {
    let index: Int
    @Environment(\.setupMotion) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far an object travels, either way.
    private static let distance: CGFloat = 64

    func body(content: Content) -> some View {
        content
            .opacity(motion == .settled ? 1 : 0)
            .offset(x: offset)
            .animation(animation, value: motion)
    }

    private var offset: CGFloat {
        guard !reduceMotion else { return 0 }
        switch motion {
        case .waiting: return Self.distance
        case .settled: return 0
        case .leaving: return -Self.distance
        }
    }

    /// Nothing past the sixth object waits longer than the sixth.
    private var step: Double { Double(min(index, 5)) }

    private var animation: Animation? {
        switch motion {
        // Put in place to start from, unseen.
        case .waiting: return nil
        case .settled: return .smooth(duration: 0.5).delay(step * 0.05)
        case .leaving: return .smooth(duration: 0.32).delay(step * 0.03)
        }
    }
}

extension View {
    /// Give an object its place in a setup page's move (0 moves first). Does
    /// nothing outside the setup.
    func setupObject(_ index: Int) -> some View { modifier(SetupObject(index: index)) }
}
