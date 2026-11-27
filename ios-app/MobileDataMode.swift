import Observation
import SwiftUI
import UIKit

// MARK: - Mobile Data Mode (beta)
//
// While this iPhone is on mobile data and not on Wi-Fi, iOS keeps its remote
// pairing listener closed, so every new tunnel LocalDevVPN would carry to it is
// refused, on every port (`NetworkStatus.Links.mobileDataOnly`). In Airplane
// Mode the listener is open, and a tunnel opened then keeps working once mobile
// data is back (iPhone 16, iOS 27.2.1, 2026-11-26), as StikDebug's Airplane
// Mode hint relies on.
//
// So, once the user agrees, whatever they started has them turn Airplane Mode
// on before each new tunnel, opens it, and has them turn Airplane Mode off
// again before a step that needs the internet. The tunnel is kept and reused
// while it answers (`DeviceConnection.keepsOpenTunnel`), instead of a new one
// opened for each step as on Wi-Fi, until Wi-Fi is back.
//
// Only what the user starts asks (`MobileDataMode.run`). A page's own quiet
// attempts never do, and fail as they would without it. Every step is logged
// under "Mobile Data Mode:", to tell which features it works for.

/// What the user started, for the log.
enum MobileDataFeature: String {
    case install = "Install"
    case refresh = "Refresh"
    case location = "Location spoofing"
    case jit = "JIT"
    case pairing = "Pairing"
    case apps = "Sideloaded apps"
    case crashLogs = "Crash logs"
    case developerMode = "Developer Mode"
}

/// Why Airplane Mode has to go off before the next step.
enum MobileDataInternetNeed: Equatable {
    /// An install signs in to Apple, downloads the app and has it signed.
    case install
    /// A refresh signs in to Apple.
    case signIn
    /// A refresh has Apple sign the next app.
    case signing
    /// The developer disk image is downloaded.
    case diskImageDownload
    /// Apple signs the developer disk image for this iPhone.
    case diskImage

    /// What comes next, for the popup.
    var sentence: String {
        switch self {
        case .install:
            L("Next, SideInstaller signs in to Apple, downloads the app and has Apple sign it, which needs the internet.")
        case .signIn:
            L("Next, SideInstaller signs in to Apple, which needs the internet.")
        case .signing:
            L("Next, Apple signs the app, which needs the internet.")
        case .diskImageDownload:
            L("Next, SideInstaller downloads the developer disk image, which needs the internet.")
        case .diskImage:
            L("Next, Apple signs the developer disk image for this iPhone, which needs the internet.")
        }
    }

    var logName: String {
        switch self {
        case .install:           "sign-in, download and signing"
        case .signIn:            "sign-in"
        case .signing:           "signing"
        case .diskImageDownload: "the disk image download"
        case .diskImage:         "the disk image's personalization"
        }
    }
}

/// One thing the user started, from its first step to its last. It asks at
/// most once whether to use Mobile Data Mode. Read and changed on the main
/// actor only.
final class MobileDataActionContext: @unchecked Sendable {
    let feature: MobileDataFeature
    let started = Date()
    /// The answer to the offer; nil until it's been asked.
    var accepted: Bool?
    /// Set once it has ended, so a task it left running asks nothing more.
    var ended = false
    /// Tunnels opened in Airplane Mode for it.
    var tunnelsOpened = 0
    /// Times Airplane Mode was asked for, on and off.
    var airplaneRequests = 0

    init(feature: MobileDataFeature) {
        self.feature = feature
    }
}

enum MobileDataAction {
    /// What the user started that the running task is part of, if anything.
    /// Tasks started inside it inherit it.
    @TaskLocal static var current: MobileDataActionContext?
}

@MainActor
@Observable
final class MobileDataMode {

    static let shared = MobileDataMode()

    /// The popup up now; see `MobileDataPopup`.
    enum Prompt: Equatable {
        /// Asks whether to try Mobile Data Mode.
        case offer
        /// Turn Airplane Mode on for a new tunnel. `again` when the one kept
        /// has closed; `pairing` when it's for pairing this iPhone.
        case airplaneOn(again: Bool, pairing: Bool)
        /// The tunnel is opening in Airplane Mode.
        case connecting
        /// Turn Airplane Mode off for what comes next.
        case airplaneOff(MobileDataInternetNeed)
        /// Nothing needs Airplane Mode any more.
        case canTurnOff

        /// True while something the user started waits on it. The dial goes
        /// on whether the connecting popup is up or not.
        var blocks: Bool { self != .canTurnOff && self != .connecting }
    }

    /// What a popup is waiting for, shown under its steps.
    enum Waiting: Equatable {
        case airplaneMode
        /// Airplane Mode is on, but LocalDevVPN's tunnel isn't.
        case localDevVPN
        case mobileData
    }

    private(set) var prompt: Prompt?
    private(set) var waiting: Waiting?
    /// True from the first yes until Wi-Fi is back. While it is, the tunnel
    /// open is kept and reused (`DeviceConnection.keepsOpenTunnel`).
    private(set) var isOn = false

    @ObservationIgnored private var offerAnswer: Bool?
    /// True from Airplane Mode being on until the dial for it has ended.
    @ObservationIgnored private var dialingInAirplaneMode = false
    @ObservationIgnored private var cancelRequested = false
    /// One blocking popup at a time: a second action's waits its turn.
    @ObservationIgnored private var promptBusy = false
    @ObservationIgnored private let overlay = MobileDataOverlay()
    /// Takes the "you can turn it off" note away once the iPhone is online.
    @ObservationIgnored private var noticeWatch: Task<Void, Never>?

    private init() {}

    private var engine: Engine { Engine.shared }

    private func log(_ message: String) {
        engine.log("Mobile Data Mode: \(message)")
    }

    private func setPrompt(_ new: Prompt?) {
        guard prompt != new else { return }
        prompt = new
        if new == nil { waiting = nil }
        overlay.update(shown: new != nil)
    }

    /// True while a tunnel kept from Airplane Mode may still be open, so a
    /// Shortcuts action needn't come forward for a new one.
    var mayHaveOpenTunnel: Bool {
        isOn && engine.connection.isConnected
    }

    // MARK: Actions

    /// Runs `body`, something the user started (`feature`). On mobile data
    /// alone, the first new tunnel it needs asks whether to use Mobile Data
    /// Mode. Inside an action already running, `body` is part of that one.
    func run<T>(_ feature: MobileDataFeature, _ body: () async throws -> T) async rethrows -> T {
        if let outer = MobileDataAction.current, !outer.ended {
            return try await body()
        }
        let action = MobileDataActionContext(feature: feature)
        defer { finish(action) }
        return try await MobileDataAction.$current.withValue(action) { try await body() }
    }

    /// Runs `body` as no action's part, even inside one: a page's own quiet
    /// attempt, which never asks.
    static func quietly<T>(_ body: () async throws -> T) async rethrows -> T {
        try await MobileDataAction.$current.withValue(nil) { try await body() }
    }

    private func finish(_ action: MobileDataActionContext) {
        action.ended = true
        guard action.accepted == true || action.airplaneRequests > 0 else { return }
        log(String(format: "%@ ended after %.0f s: %d tunnel(s) opened in Airplane Mode, Airplane Mode asked for %d time(s).",
                   action.feature.rawValue, Date().timeIntervalSince(action.started),
                   action.tunnelsOpened, action.airplaneRequests))
        let links = NetworkStatus.links()
        guard isOn, !links.mobileData, !links.wifi, prompt == nil else { return }
        showNotice()
    }

    // MARK: Tunnels

    /// Before a new tunnel is opened for what the user started. On mobile data
    /// alone it asks whether to use Mobile Data Mode, once per action, then has
    /// Airplane Mode turned on and waits for it. Returns true when the tunnel
    /// is to be opened in Airplane Mode; false when nothing was asked, on
    /// Wi-Fi or outside anything the user started, and the dial goes ahead as
    /// it would anyway. Throws when the user would rather use Wi-Fi, or cancels.
    @discardableResult
    func prepareNewTunnel(again: Bool = false, forPairing: Bool = false) async throws -> Bool {
        let links = NetworkStatus.links()
        if links.wifi {
            leaveForWiFi()
            return false
        }
        guard let action = MobileDataAction.current, !action.ended else { return false }
        if !links.mobileData {
            // Airplane Mode is on already: the tunnel opens as it is.
            guard isOn else { return false }
            dialingInAirplaneMode = true
            setPrompt(.connecting)
            return true
        }
        try await ensureAccepted(action)
        action.airplaneRequests += 1
        let started = Date()
        log(again ? "the tunnel kept for \(action.feature.rawValue) has closed; asking for Airplane Mode again."
                  : "asking for Airplane Mode, for a new tunnel (\(action.feature.rawValue)).")
        try await withPrompt(.airplaneOn(again: again, pairing: forPairing)) {
            while true {
                try checkCancelled()
                let links = NetworkStatus.links()
                if links.wifi {
                    log("Wi-Fi came on instead, so the tunnel opens the usual way.")
                    return
                }
                if !links.mobileData {
                    if NetworkStatus.loopbackTunnelUp(deviceIP: engine.deviceHost) {
                        log(String(format: "Airplane Mode is on after %.1f s (%@).",
                                   Date().timeIntervalSince(started), links.summary))
                        return
                    }
                    waiting = .localDevVPN
                } else {
                    waiting = .airplaneMode
                }
                try await Task.sleep(for: .milliseconds(400))
            }
        }
        dialingInAirplaneMode = !NetworkStatus.links().wifi
        setPrompt(.connecting)
        return true
    }

    /// After the dial `prepareNewTunnel` was for, whichever way it went.
    func dialEnded(opened: Bool) {
        if dialingInAirplaneMode, opened {
            MobileDataAction.current?.tunnelsOpened += 1
            log("tunnel opened in Airplane Mode (\(NetworkStatus.links().summary)).")
        }
        dialingInAirplaneMode = false
        if prompt == .connecting { setPrompt(nil) }
    }

    /// Before a step that needs the internet, while Mobile Data Mode is on in
    /// something the user started: if Airplane Mode is still on, has it
    /// turned off and waits until the iPhone is online again. The tunnel
    /// stays open meanwhile. Nothing otherwise.
    func requireInternet(_ need: MobileDataInternetNeed) async throws {
        guard isOn, let action = MobileDataAction.current, !action.ended else { return }
        let links = NetworkStatus.links()
        guard !links.mobileData, !links.wifi else { return }
        action.airplaneRequests += 1
        let started = Date()
        log("asking for Airplane Mode off, for \(need.logName).")
        try await withPrompt(.airplaneOff(need)) {
            while true {
                try checkCancelled()
                let links = NetworkStatus.links()
                if links.mobileData || links.wifi {
                    log(String(format: "online again after %.1f s (%@).",
                               Date().timeIntervalSince(started), links.summary))
                    return
                }
                waiting = .mobileData
                try await Task.sleep(for: .milliseconds(400))
            }
        }
        // Mobile data has an address a moment before requests get through.
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            try Task.checkCancellation()
            if await NetworkStatus.internetPath().status == .satisfied { return }
            try await Task.sleep(for: .milliseconds(500))
        }
        log("iOS still says there's no internet path; going on anyway.")
    }

    /// Back to the usual way: Wi-Fi is on, so new tunnels open again.
    private func leaveForWiFi() {
        guard isOn else { return }
        isOn = false
        DeviceConnection.keepsOpenTunnel = false
        log("Wi-Fi is on, so tunnels open the usual way again.")
    }

    // MARK: Asking

    private func ensureAccepted(_ action: MobileDataActionContext) async throws {
        switch action.accepted {
        case true?:
            return
        case false?:
            throw Self.declined
        case nil:
            log("offered for \(action.feature.rawValue) (\(NetworkStatus.links().summary)).")
            offerAnswer = nil
            let yes = try await withPrompt(.offer) { () -> Bool in
                while true {
                    try checkCancelled()
                    if let answer = offerAnswer { return answer }
                    try await Task.sleep(for: .milliseconds(150))
                }
            }
            action.accepted = yes
            guard yes else {
                log("declined for \(action.feature.rawValue).")
                throw Self.declined
            }
            log("accepted for \(action.feature.rawValue).")
            isOn = true
            DeviceConnection.keepsOpenTunnel = true
        }
    }

    /// What stops an action whose user would rather use Wi-Fi: it ends like
    /// Cancel, with no error, since the offer already said how.
    private static var declined: Error { CancellationError() }

    /// Shows `shown` while `body` waits on it, one popup at a time.
    private func withPrompt<T>(_ shown: Prompt, _ body: () async throws -> T) async throws -> T {
        while promptBusy {
            try await Task.sleep(for: .milliseconds(200))
        }
        promptBusy = true
        cancelRequested = false
        noticeWatch?.cancel()
        setPrompt(shown)
        SoundEffects.play(.attention)
        defer {
            promptBusy = false
            if prompt == shown { setPrompt(nil) }
        }
        return try await body()
    }

    private func checkCancelled() throws {
        try Task.checkCancellation()
        if cancelRequested {
            cancelRequested = false
            log("stopped from its popup.")
            throw CancellationError()
        }
    }

    private func showNotice() {
        setPrompt(.canTurnOff)
        noticeWatch?.cancel()
        noticeWatch = Task { @MainActor in
            while !Task.isCancelled, prompt == .canTurnOff {
                let links = NetworkStatus.links()
                if links.mobileData || links.wifi {
                    setPrompt(nil)
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: The popup's buttons

    func answerOffer(_ yes: Bool) {
        offerAnswer = yes
    }

    /// Ends what the popup holds up, as its X and Cancel do; closes the note.
    func close() {
        switch prompt {
        case .canTurnOff?, .connecting?:
            noticeWatch?.cancel()
            setPrompt(nil)
        default:
            cancelRequested = true
        }
    }
}

// MARK: - The popup

/// Puts Mobile Data Mode's popup in a window of its own, over the whole app
/// and any sheet on it (Settings, Report a problem), which `RootView`'s popups
/// would sit under.
@MainActor
private final class MobileDataOverlay {
    private var window: UIWindow?
    private var hiding: Task<Void, Never>?

    func update(shown: Bool) {
        hiding?.cancel()
        if shown {
            (window ?? makeWindow())?.isHidden = false
        } else if let window {
            // After the popup's own way out.
            hiding = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                window.isHidden = true
            }
        }
    }

    private func makeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        else { return nil }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.overrideUserInterfaceStyle = .dark
        let host = UIHostingController(rootView: MobileDataOverlayView()
            .environmentObject(Localizer.shared))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        self.window = window
        return window
    }
}

/// The overlay window's content: the popup over a dimmed, blurred app.
private struct MobileDataOverlayView: View {
    /// Declared so a language change relabels the popup.
    @EnvironmentObject private var loc: Localizer

    /// Its one slot: the popup changes in place from one step to the next.
    private struct Entry: Identifiable, Equatable {
        let prompt: MobileDataMode.Prompt
        var id: String { "mobile-data-mode" }
    }

    var body: some View {
        let mode = MobileDataMode.shared
        Color.clear
            .ignoresSafeArea()
            .popupStack(mode.prompt.map { [Entry(prompt: $0)] } ?? [],
                        onBackdropTap: mode.prompt?.blocks == false ? { mode.close() } : nil) { entry in
                MobileDataPopup(prompt: entry.prompt)
                    .environment(\.popupEndsProcess, entry.prompt.blocks)
            }
            .tint(Theme.accent)
    }
}

/// One step of Mobile Data Mode, as a popup.
struct MobileDataPopup: View {
    let prompt: MobileDataMode.Prompt

    private var mode: MobileDataMode { .shared }

    var body: some View {
        switch prompt {
        case .offer:
            PopupCard(title: L("Try Mobile Data Mode?"),
                      systemImage: "antenna.radiowaves.left.and.right",
                      tint: Theme.accent, onClose: { mode.close() }) {
                VStack(alignment: .leading, spacing: 16) {
                    BetaBadge()
                    paragraph(L("This iPhone is on mobile data, not Wi-Fi, and iOS doesn't accept new connections from LocalDevVPN then."))
                    paragraph(L("Mobile Data Mode works around that with Airplane Mode: you turn it on while SideInstaller connects, and off again when SideInstaller needs the internet. SideInstaller tells you when."),
                              secondary: true)
                    Label {
                        Text(L("Wi-Fi is the stable way, and the safer one. To use it, turn on Wi-Fi and try again."))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "wifi")
                            .foregroundStyle(Theme.positive)
                    }
                    VStack(spacing: 12) {
                        Button { mode.answerOffer(true) } label: {
                            Label(L("Try Mobile Data Mode"), systemImage: "airplane")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button { mode.answerOffer(false) } label: {
                            Label(L("Use Wi-Fi Instead"), systemImage: "wifi")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    }
                }
            }
        case .airplaneOn(let again, let pairing):
            PopupCard(title: L("Turn on Airplane Mode"), systemImage: "airplane",
                      tint: Theme.warning, onClose: { mode.close() }) {
                VStack(alignment: .leading, spacing: 16) {
                    if again {
                        paragraph(L("The connection SideInstaller kept has closed, so it needs a new one."))
                    }
                    NumberedSteps(steps: [
                        L("Open Control Center: swipe down from the top-right corner of the screen."),
                        L("Tap Airplane Mode to turn it on. Leave Wi-Fi off and LocalDevVPN connected."),
                        L("Come back to SideInstaller. It carries on by itself."),
                    ])
                    if pairing {
                        paragraph(L("Then pair this iPhone with SideInstaller in Settings, as usual."),
                                  secondary: true)
                    }
                    waitingLine
                    cancelButton
                }
            }
        case .connecting:
            PopupCard(title: L("Connecting in Airplane Mode"), systemImage: "airplane",
                      tint: Theme.accent, onClose: { mode.close() }) {
                HStack(alignment: .center, spacing: 12) {
                    ProgressView()
                    paragraph(L("Keep Airplane Mode on until SideInstaller asks you to turn it off."))
                }
            }
        case .airplaneOff(let need):
            PopupCard(title: L("Turn off Airplane Mode"),
                      systemImage: "antenna.radiowaves.left.and.right",
                      tint: Theme.warning, onClose: { mode.close() }) {
                VStack(alignment: .leading, spacing: 16) {
                    paragraph(L("SideInstaller is connected, and keeps its connection once mobile data is back."))
                    paragraph(need.sentence, secondary: true)
                    NumberedSteps(steps: [
                        L("Open Control Center again."),
                        L("Tap Airplane Mode to turn it off."),
                        L("Come back to SideInstaller. It carries on once mobile data is back."),
                    ])
                    waitingLine
                    cancelButton
                }
            }
        case .canTurnOff:
            PopupCard(title: L("You can turn off Airplane Mode"), systemImage: "checkmark.circle",
                      tint: Theme.positive, onClose: { mode.close() }) {
                paragraph(L("SideInstaller is done with Airplane Mode for now, and keeps its connection for what you do next. Turn Airplane Mode off whenever you like."))
            }
        }
    }

    private func paragraph(_ text: String, secondary: Bool = false) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// What the popup is waiting for, as it is now.
    @ViewBuilder
    private var waitingLine: some View {
        if let waiting = mode.waiting {
            HStack(alignment: .center, spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(text(for: waiting))
                    .font(.footnote)
                    .foregroundStyle(waiting == .localDevVPN ? AnyShapeStyle(Theme.warning)
                                                             : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func text(for waiting: MobileDataMode.Waiting) -> String {
        switch waiting {
        case .airplaneMode: L("Waiting for Airplane Mode…")
        case .localDevVPN:  L("Airplane Mode is on, but LocalDevVPN isn't connected. Open it and connect it again.")
        case .mobileData:   L("Waiting for mobile data…")
        }
    }

    private var cancelButton: some View {
        Button(role: .cancel) { mode.close() } label: {
            Text(L("Cancel"))
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
    }
}
