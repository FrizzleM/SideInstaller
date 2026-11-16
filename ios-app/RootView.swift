import SwiftUI
import UIKit

/// Tab container (Certificates, Files, Install, Tools, About). Each page draws its own
/// `AppBackground`, since `TabView` would hide a shared one; they stay in sync
/// because the background animates off the clock. Also hosts the 2FA sheet and
/// the pages' popups, so they show over any tab.
struct RootView: View {
    /// The tabs. The selection is tracked so a tab switch can tick, and a
    /// link can bring the Install tab forward.
    private enum Page: Hashable {
        case cert, files, install, tools, about

        var wash: Backdrop.Level {
            switch self {
            case .cert:    .bright
            case .files:   .bright
            case .install: .bright
            case .tools:   .dark
            // Same as Install, so switching between them doesn't change the backdrop.
            case .about:   .bright
            }
        }
    }

    /// One popup, tagged with the page that raised it.
    private enum PopupItem: Hashable {
        case install(Engine.Popup)
        case pairing(PairingManager.Popup)
        case certificates(ToolPopup)
        case entitlements(EntitlementsManager.Popup)
        case location(ToolPopup)
        case apps(ToolPopup)
    }

    /// Popups that always come up together, so they share one card.
    private enum PopupGroupKind: Hashable {
        /// What an Install run is waiting on: the pairing code and the steps
        /// for Settings, or Wi-Fi or the tunnel alone.
        case installWaiting
        /// Why an install stopped: the error, the guide for it, and
        /// revoke-and-retry.
        case installStopped
        /// A finished install: the news, the trust step, and LiveContainer's
        /// certificate import.
        case installFinished
        /// The Pairing page's code and the steps for Settings.
        case pairingPage
    }

    /// One card in the popup stack: a popup, or popups that come up together.
    private struct PopupEntry: Identifiable, Equatable {
        var group: PopupGroupKind?
        var items: [PopupItem]

        /// A group keeps its card while members come and go.
        var id: AnyHashable { group.map { AnyHashable($0) } ?? AnyHashable(items[0]) }
    }

    @Environment(Engine.self) private var engine
    /// Declared so a language change relabels the tab bar.
    @EnvironmentObject private var loc: Localizer
    /// Watched so switching Apple ID invalidates every cached sign-in below.
    @EnvironmentObject private var accounts: AccountStore
    /// Owned here so they survive tab switches and share the one `Engine`.
    @StateObject private var certManager = CertManager()
    @StateObject private var pairingManager = PairingManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var entitlementsManager = EntitlementsManager()
    /// 与快捷指令共用同一个实例（SideloadedAppsManager.shared），后台续签状态界面可见。
    @ObservedObject private var appsManager = SideloadedAppsManager.shared
    @StateObject private var sideBySideManager = SideBySideManager()
    /// 证书页与文件页之间传递待签 IPA。
    @StateObject private var certWorkspace = CertWorkspace()
    /// The last two-factor prompt shown, so the sheet keeps its content while it
    /// slides away after the sign-in clears it.
    @State private var shownTwoFactor: TwoFactorPhase?
    @State private var page: Page = .install

    var body: some View {
        // `.tabItem`/`.tag` rather than iOS 18's `Tab`, to keep iOS 17.
        TabView(selection: tabSelection) {
            CertTabView()
                .tabItem { Label(L("签名"), systemImage: "checkmark.seal.fill") }
                .tag(Page.cert)
            FilesTabView(onGoCert: { page = .cert })
                .tabItem { Label(L("文件"), systemImage: "folder.fill") }
                .tag(Page.files)
            ContentView()
                .tabItem { Label(L("Install"), systemImage: "square.and.arrow.down") }
                .tag(Page.install)
            ToolsView(pairingManager: pairingManager,
                      certManager: certManager,
                      locationManager: locationManager,
                      entitlementsManager: entitlementsManager,
                      appsManager: appsManager,
                      sideBySideManager: sideBySideManager)
                .tabItem { Label(L("Tools"), systemImage: "wrench.and.screwdriver") }
                .tag(Page.tools)
            AboutView()
                .tabItem { Label(L("About"), systemImage: "info.circle") }
                .tag(Page.about)
        }
        .environmentObject(certWorkspace)
        // Animate the backdrop to the new tab's level.
        .onChange(of: page) { _, page in Backdrop.settle(on: page.wash) }
        // A link's install or pairing file ends up on the Install tab, so its
        // popup comes up over that.
        .onChange(of: engine.pendingLink) { _, link in
            if link != nil { page = .install }
        }
        // A share / “Open with” IPA import lands here too: the run it started
        // (or the guide it stopped on) lives on the Install tab, so jump
        // there instead of leaving the user to go find it by hand.
        .onChange(of: engine.sharedIPAReady) { _, ready in
            if ready { page = .install; engine.sharedIPAReady = false }
        }
        // A certificate a link brought is checked and imported by the same
        // manager as the Certificates page.
        // Zero-arg form: the two-arg (#35) and one-arg (#36) rejections were
        // cascades of the missing CertManager.importCertificate below, not
        // the onChange itself; the zero-arg form is kept because it is the
        // form proven to type-check here. It reads the new value directly,
        // which is behaviorally identical.
        .onChange(of: engine.certificateToImport) {
            guard let request = engine.certificateToImport else { return }
            engine.certificateToImport = nil
            certManager.importCertificate(request)
        }
        // Over the tab bar too, so the whole app dims behind the popups.
        .popupStack(entries, onBackdropTap: backdropTap) { entry in
            card(for: entry)
        }
        .onChange(of: popups) { old, new in
            playSound(forShown: new.filter { !old.contains($0) })
        }
        // The Install tab's revoke-and-retry runs through this same manager
        // (declared below the popups, which use it too).
        .environmentObject(certManager)
        // When the active Apple ID changes, drop all four cached Apple sessions
        // (Side by Side's included) so none is reused for the new account.
        .onChange(of: accounts.revision) { _, _ in
            engine.forgetAppleSession()
            certManager.signOut()
            entitlementsManager.signOut()
            sideBySideManager.signOut()
        }
        .tint(Theme.accent)
        // 外观只听 App 入口的 SIDAppearance 档（SideInstallerApp 的
        // .preferredColorScheme），这里不再硬编码 .dark，否则主界面
        // 永远深色、设置页却跟浅色档走，两边割裂。
        // A swipe down is a cancel; the sign-in closing it is not.
        .sheet(isPresented: Binding(
            get: { engine.twoFactor != nil },
            set: { if !$0, let phase = engine.twoFactor { engine.cancelTwoFactor(phase) } }
        )) {
            if let phase = engine.twoFactor ?? shownTwoFactor {
                TwoFactorSheet(phase: phase)
            }
        }
        .onChange(of: engine.twoFactor) { old, phase in
            if let phase { shownTwoFactor = phase }
            // A code is wanted, or the one entered was turned down.
            if let phase, phase.isAsking {
                if old?.signIn != phase.signIn {
                    SoundEffects.play(.attention)
                } else if old?.isAsking == false, phase.prompt.lastError != nil {
                    SoundEffects.play(.error)
                }
            }
        }
    }

    /// The tab selection, ticking as the user changes tab.
    private var tabSelection: Binding<Page> {
        Binding(get: { page },
                set: { newPage in
                    if newPage != page { SoundEffects.play(.tick) }
                    page = newPage
                })
    }

    // MARK: Popups

    /// Every popup up, top to bottom: each page's in its own order, and a page
    /// whose run is waiting on its popups ahead of the others, so those are
    /// never pushed down out of sight.
    private var popups: [PopupItem] {
        let pages = [engine.popups.map(PopupItem.install),
                     pairingManager.popups.map(PopupItem.pairing),
                     certManager.popups.map(PopupItem.certificates),
                     entitlementsManager.popups.map(PopupItem.entitlements),
                     locationManager.popups.map(PopupItem.location),
                     appsManager.popups.map(PopupItem.apps)]
        let waiting = pages.filter { $0.contains(where: blocks) }
        let others = pages.filter { !$0.contains(where: blocks) }
        return Array((waiting + others).joined())
    }

    /// Closes every popup that only informs. The ones a run is waiting on stay
    /// up, so a stray tap can't stop it; with only those up, taps do nothing.
    private var backdropTap: (() -> Void)? {
        let closable = popups.filter { !blocks($0) }
        guard !closable.isEmpty else { return nil }
        return {
            SoundEffects.play(.dismiss)
            closable.forEach(close)
        }
    }

    /// Plays the sound for popups that just came up: an error over a success
    /// over a request for the user, when several come up at once.
    private func playSound(forShown items: [PopupItem]) {
        let sounds = Set(items.compactMap(sound(for:)))
        if let sound = [UISound.error, .success, .attention].first(where: sounds.contains) {
            SoundEffects.play(sound)
        }
    }

    /// What a popup sounds like as it comes up, if anything.
    private func sound(for item: PopupItem) -> UISound? {
        switch item {
        case .install(.error), .install(.certConflict), .pairing(.error),
             .certificates(.error), .entitlements(.error), .location(.error), .apps(.error):
            .error
        case .install(.success), .pairing(.success),
             .certificates(.success), .location(.success), .apps(.success):
            .success
        // Apple granting nothing it was asked for is a failure.
        case .entitlements(.results(_, let outcomes)):
            outcomes.contains(where: \.ok) ? .success : .error
        // A guide that comes up mid-run is what the run waits on; after one,
        // it comes with the error or the success, which speak for it.
        case .install(.guide):
            engine.isRunning ? .attention : nil
        // Waiting on the user: a code to type, steps to follow, a go-ahead.
        case .install(.pairingCode), .install(.liveContainerImport), .install(.appIDCost),
             .install(.link), .pairing(.pairingCode), .pairing(.pairInSettings):
            .attention
        }
    }

    /// True when a run is waiting on the popup, so closing it stops the run.
    private func blocks(_ item: PopupItem) -> Bool {
        switch item {
        case .install(let popup):    engine.blocks(popup)
        case .pairing(let popup):    pairingManager.blocks(popup)
        // The Tools pages only report; nothing waits on their popups.
        case .certificates, .entitlements, .location, .apps: false
        }
    }

    /// The popups as cards, top to bottom: neighbours that come up together
    /// share one.
    private var entries: [PopupEntry] {
        var entries: [PopupEntry] = []
        for item in popups {
            let kind = group(of: item)
            if let kind, entries.last?.group == kind {
                entries[entries.count - 1].items.append(item)
            } else {
                entries.append(PopupEntry(group: kind, items: [item]))
            }
        }
        return entries
    }

    /// The group a popup comes up in, if it's ever up with others.
    private func group(of item: PopupItem) -> PopupGroupKind? {
        switch item {
        case .install(.pairingCode):
            .installWaiting
        // The same guide slot holds what a run waits on, why it stopped, or
        // the trust step it ended on.
        case .install(.guide):
            engine.isRunning ? .installWaiting : engine.finished ? .installFinished : .installStopped
        case .install(.certConflict), .install(.error):
            .installStopped
        case .install(.success), .install(.liveContainerImport):
            .installFinished
        // Up on its own, waiting for the go-ahead to sign, or to act on a link.
        case .install(.appIDCost), .install(.link):
            nil
        case .pairing(.pairingCode), .pairing(.pairInSettings):
            .pairingPage
        case .pairing, .certificates, .entitlements, .location, .apps:
            nil
        }
    }

    /// A group card's title, symbol and tint. A member titled the same goes
    /// without its own title inside, so it's said once.
    private func groupHeader(for group: PopupGroupKind,
                             _ items: [PopupItem]) -> (title: String, systemImage: String, tint: Color) {
        switch group {
        case .installWaiting:
            // Named after the steps for Settings.
            let steps = items.lazy.compactMap { item -> Guide? in
                if case .install(.guide(let guide)) = item { guide } else { nil }
            }.first
            return (steps?.title ?? L("Pairing code"), "lock.iphone", Theme.accent)
        case .installStopped:
            // Named after the error.
            let stoppedRun = items.lazy.compactMap { item -> Bool? in
                if case .install(.error(_, let stoppedRun)) = item { stoppedRun } else { nil }
            }.first
            return (InstallPopup.errorTitle(stoppedRun: stoppedRun ?? true),
                    "exclamationmark.triangle", Theme.negative)
        case .installFinished:
            return (L("Success: last steps"), "checkmark.seal", Theme.positive)
        case .pairingPage:
            return (PairingPopup.pairInSettingsTitle, "lock.iphone", Theme.accent)
        }
    }

    private func close(_ item: PopupItem) {
        switch item {
        case .install(let popup):      engine.closePopup(popup)
        case .pairing(let popup):      pairingManager.closePopup(popup)
        case .certificates(let popup): certManager.closePopup(popup)
        case .entitlements(let popup): entitlementsManager.closePopup(popup)
        case .location(let popup):     locationManager.closePopup(popup)
        case .apps(let popup):         appsManager.closePopup(popup)
        }
    }

    /// A group's card holds its members as tiles, under one X that closes
    /// them all; a popup alone is a card of its own.
    @ViewBuilder
    private func card(for entry: PopupEntry) -> some View {
        if let group = entry.group {
            let header = groupHeader(for: group, entry.items)
            PopupGroupCard(title: header.title, systemImage: header.systemImage, tint: header.tint,
                           isGrouped: entry.items.count > 1,
                           onClose: { entry.items.forEach(close) }) {
                ForEach(entry.items, id: \.self) { item in
                    card(for: item)
                        .environment(\.popupEndsProcess, blocks(item))
                        .transition(.popup)
                }
            }
            .environment(\.popupEndsProcess, entry.items.contains(where: blocks))
        } else if let item = entry.items.first {
            card(for: item).environment(\.popupEndsProcess, blocks(item))
        }
    }

    @ViewBuilder
    private func card(for item: PopupItem) -> some View {
        switch item {
        case .install(let popup):
            InstallPopup(popup: popup)
        case .pairing(let popup):
            PairingPopup(manager: pairingManager, popup: popup)
        case .certificates(let popup):
            toolPopup(popup, successTitle: L("Certificates")) { certManager.closePopup(popup) }
        case .entitlements(let popup):
            EntitlementsPopup(manager: entitlementsManager, popup: popup)
        case .location(let popup):
            toolPopup(popup, successTitle: L("Location spoofing")) { locationManager.closePopup(popup) }
        case .apps(let popup):
            toolPopup(popup, successTitle: L("Sideloaded apps")) { appsManager.closePopup(popup) }
        }
    }

    /// A Tools page's report. A success is titled after its page, since it can
    /// show over any tab.
    private func toolPopup(_ popup: ToolPopup, successTitle: String,
                           onClose: @escaping () -> Void) -> some View {
        switch popup {
        case .error(let message):
            MessagePopup(title: L("Something went wrong"), message: message, isError: true,
                         onClose: onClose)
        case .success(let message):
            MessagePopup(title: successTitle, message: message, isError: false, onClose: onClose)
        }
    }
}

// MARK: - Two-factor sheet

/// Two-factor sign-in sheet: enter the code, or request one another way (trusted
/// devices, text or call). Stays open through wrong codes and resends; closes
/// when the sign-in returns.
struct TwoFactorSheet: View {
    @Environment(Engine.self) private var engine
    /// Declared so every label redraws when the language changes.
    @EnvironmentObject private var loc: Localizer

    let phase: TwoFactorPhase

    @State private var code = ""
    @FocusState private var codeFocused: Bool

    private var prompt: TwoFactorPrompt { phase.prompt }

    /// The answer the sign-in is acting on, while it does.
    private var pending: TwoFactorAnswer? { phase.answer }

    var body: some View {
        NavigationStack {
            Form {
                if let error = prompt.shownError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.warning)
                    }
                }
                Section {
                    Text(instructions)
                        .foregroundStyle(.secondary)
                    if prompt.expectsCode {
                        TextField(L("6-digit code"), text: $code)
                            .keyboardType(.numberPad)
                            // Lets a texted code fill itself in from Messages.
                            .textContentType(.oneTimeCode)
                            .font(.title2.monospacedDigit())
                            .focused($codeFocused)
                            .disabled(pending != nil)
                            .onChange(of: code) { _, typed in
                                let digits = String(typed.filter(\.isNumber).prefix(6))
                                if digits != typed { code = digits }
                            }
                    }
                    if let pending {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(status(for: pending))
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    // Whose code it is: Side by Side signs in with someone
                    // else's Apple ID, and can be queued behind the install's.
                    Label(phase.appleID, systemImage: "person.crop.circle")
                }
                Section {
                    options
                } header: {
                    if prompt.expectsCode { Text(L("Didn't get it?")) }
                }
                .disabled(pending != nil)
            }
            .navigationTitle(prompt.expectsCode ? L("Two-Factor Code") : L("Choose How to Get a Code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Cancel")) { engine.cancelTwoFactor(phase) }
                }
                if prompt.expectsCode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("Verify")) { engine.answerTwoFactor(.code(code), to: phase) }
                            .disabled(pending != nil || code.count != 6)
                    }
                }
            }
        }
        .onAppear { codeFocused = prompt.expectsCode }
        .onChange(of: phase) { _, phase in
            // Checking an answer disables the field, which takes the keyboard
            // away. Unfocused here too, so focusing it again below is a change.
            guard phase.isAsking else {
                codeFocused = false
                return
            }
            // A fresh prompt — after a wrong code, or with a new code on its way —
            // starts from an empty field.
            code = ""
            // Focused a turn later: until then the field is still disabled, or
            // not there yet after choosing how to get a code, and can't take it.
            Task { @MainActor in codeFocused = phase.prompt.expectsCode }
        }
    }

    /// Every other route to a code, leaving out the one already in use.
    @ViewBuilder
    private var options: some View {
        switch prompt.method {
        case .device: option(L("Send a new code to my devices"), "arrow.clockwise", .resend)
        case .sms:    option(L("Text me a new code"), "arrow.clockwise", .resend)
        case .voice:  option(L("Call me again"), "arrow.clockwise", .resend)
        case .choose: EmptyView()
        }
        if prompt.method != .device {
            option(L("Send a code to my Apple devices"), "laptopcomputer.and.iphone", .devices)
        }
        // Enumerated, so a language switch relabels every row.
        ForEach(Array(prompt.numbers.enumerated()), id: \.element.id) { _, number in
            let inUse = number.id == prompt.selectedNumberId
            if number.takesTexts && !(inUse && prompt.method == .sms) {
                option(L("Text %@", number.number), "message", .sms(number.id))
            }
            if !(inUse && prompt.method == .voice) {
                option(L("Call %@", number.number), "phone", .voice(number.id))
            }
        }
    }

    private func option(_ title: String, _ systemImage: String, _ answer: TwoFactorAnswer) -> some View {
        Button { engine.answerTwoFactor(answer, to: phase) } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private var instructions: String {
        switch prompt.method {
        case .device:
            L("Enter the code Apple just sent to your trusted device.")
        case .sms:
            prompt.selectedNumber.map { L("Enter the code Apple texted to %@.", $0.number) }
                ?? L("Enter the code Apple texted to your phone.")
        case .voice:
            prompt.selectedNumber.map { L("Apple is calling %@. Enter the code you hear.", $0.number) }
                ?? L("Apple is calling your phone. Enter the code you hear.")
        case .choose:
            L("Choose how Apple should send your verification code.")
        }
    }

    private func status(for answer: TwoFactorAnswer) -> String {
        let number = { (id: UInt32) in prompt.numbers.first { $0.id == id }?.number ?? "" }
        return switch answer {
        case .code:          L("Checking the code…")
        case .resend:        L("Requesting a new code…")
        case .devices:       L("Sending a code to your devices…")
        case .sms(let id):   L("Texting a code to %@…", number(id))
        case .voice(let id): L("Calling %@…", number(id))
        }
    }
}

// MARK: - Tools

/// A Tools page's popup, reporting how its last action went.
enum ToolPopup: Hashable {
    case error(String)
    case success(String)
}

/// The Tools tab: a menu of utility pages. Owns the `NavigationStack` they're
/// pushed onto, so those pages don't declare their own.
struct ToolsView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// Passed in (owned by `RootView`) so pages keep their state across tabs.
    @ObservedObject var pairingManager: PairingManager
    @ObservedObject var certManager: CertManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var entitlementsManager: EntitlementsManager
    @ObservedObject var appsManager: SideloadedAppsManager
    @ObservedObject var sideBySideManager: SideBySideManager

    @State private var showSettings = false
    /// WebDAV 服务单例（0.9.88）：开关状态不持久化，默认关闭。
    @StateObject private var webdav = CZFWebDAVServer.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header.cascadeItem(0)
                    NavigationLink {
                        SideBySideView(manager: sideBySideManager)
                    } label: {
                        ToolRow(icon: "square.on.square", color: .purple,
                                title: L("Side by Side"),
                                beta: true)
                    }
                    .buttonStyle(.plain, sound: .tick)
                    .cascadeItem(1)
                    // The Pairing page generates a pairing file on-device, which
                    // needs iOS 27+. Older iOS imports it on the Install screen.
                    if Engine.deviceCanSelfPair {
                        NavigationLink {
                            PairingView(manager: pairingManager)
                        } label: {
                            ToolRow(icon: "link", color: .teal, title: L("Pairing"))
                        }
                        .buttonStyle(.plain, sound: .tick)
                        .cascadeItem(2)
                    }
                    NavigationLink {
                        CertsView(manager: certManager)
                    } label: {
                        ToolRow(icon: "checkmark.seal", color: .blue, title: L("Apple ID 证书"))
                    }
                    .buttonStyle(.plain, sound: .tick)
                    .cascadeItem(rowIndex(2))
                    // 别走错：这里是上游的 Apple ID 证书管理，企业证书
                    // 在底部第一栏「签名」页，不在这里。
                    NavigationLink {
                        EntitlementsView(manager: entitlementsManager)
                    } label: {
                        ToolRow(icon: "checklist", color: .orange, title: L("Entitlements"))
                    }
                    .buttonStyle(.plain, sound: .tick)
                    .cascadeItem(rowIndex(3))
                    NavigationLink {
                        LocationView(manager: locationManager)
                    } label: {
                        ToolRow(icon: "location.fill", color: .green, title: L("Location spoofing"))
                    }
                    .buttonStyle(.plain, sound: .tick)
                    .cascadeItem(rowIndex(4))
                    NavigationLink {
                        AppsView(manager: appsManager)
                    } label: {
                        ToolRow(icon: "app.badge.clock", color: .red, title: L("Sideloaded apps"))
                    }
                    .buttonStyle(.plain, sound: .tick)
                    .cascadeItem(rowIndex(5))
                    // 下载独立页（轻松签下载顶级 tab 的等价物）：
                    // 内容就是设置页下载区（复用 DownloadsManager），
                    // 只是以前只藏在设置 sheet 里，这里在工具 tab
                    // 给一个固定入口，不另起顶级 tab（5 tab 已满，
                    // 第 6 个会被收进 More，反而更难找）。
                    NavigationLink {
                        DownloadsListView()
                    } label: {
                        ToolRow(icon: "arrow.down.circle", color: .pink, title: L("下载"))
                    }
                    .buttonStyle(.plain, sound: .tick)
                    .cascadeItem(rowIndex(6))
                    // 设置固定入口（轻松签设置顶级 tab 的等价物）：
                    // 设置页本就存在，只是以前只在各页 toolbar 里
                    // 弹 sheet，这里在工具 tab 给一个固定行。
                    Button {
                        CZFHaptics.impact()
                        showSettings = true
                    } label: {
                        ToolRow(icon: "gearshape", color: .indigo, title: L("设置"))
                    }
                    .buttonStyle(.plain, sound: .tick)
                    .cascadeItem(rowIndex(7))
                    // WebDAV 文件服务（0.9.88）：开关 + 开启后的局域网
                    // 地址与安全提示。放最后，不打乱上面各行的级联序号。
                    webdavCard
                        .cascadeItem(rowIndex(8))
                }
                // No bottom padding: the tab bar's inset already clears the last
                // row, and the extra 20pt would make a page that fits scroll.
                .padding([.horizontal, .top], 20)
                .pageColumn()
            }
            // Still unless the rows don't all fit on the screen.
            .scrollBounceBehavior(.basedOnSize)
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    /// Cascade index for rows below Pairing, shifted by one when that row is shown.
    private func rowIndex(_ position: Int) -> Int {
        Engine.deviceCanSelfPair ? position + 1 : position
    }

    /// Just the title: the rows below carry the iconography on this page.
    private var header: some View {
        Text(L("Tools"))
            .font(.largeTitle.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    /// WebDAV 文件服务卡片（0.9.88）：开关 + 开启后的局域网地址、
    /// 复制按钮与安全提示。样式跟 ToolRow 同款（PanelCard + 46×46
    /// 渐变图标），不另起视觉语言。开关不持久化，默认关闭；开关
    /// 绑服务的 isRunning，启动失败时开关自动弹回关闭并显示原因。
    @ViewBuilder
    private var webdavCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { webdav.isRunning },
                    set: { on in
                        CZFHaptics.impact()
                        if on { webdav.start() } else { webdav.stop() }
                    }
                )) {
                    HStack(spacing: 14) {
                        ZStack {
                            Rectangle().fill(Theme.gradient(.cyan))
                            Image(systemName: "server.rack")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("WebDAV file service"))
                                .font(.headline)
                            Text(L("Transfer files to Documents over LAN"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if webdav.isRunning {
                    if let address = webdav.address {
                        HStack(spacing: 8) {
                            Text(address)
                                .font(.subheadline.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Button {
                                CZFHaptics.impact()
                                UIPasteboard.general.string = address
                            } label: {
                                Text(L("Copy"))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.bordered, sound: .tap)
                        }
                    } else {
                        Text(L("Wi-Fi not connected"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(L("Anyone on your LAN can access it without a password. Turn it off when done."))
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error = webdav.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

/// One Tools menu row: coloured glyph, name and chevron. Each row gets its
/// own gradient colour (no uniform black: the dark logo art rendered every
/// row black); the glyph is a white SF Symbol on that row's gradient.
/// The logo assets stay in the catalog (each pushed page's BrandHeader
/// still uses its own), only the Tools rows stop using them.
private struct ToolRow: View {
    var icon: String
    var color: Color
    var title: String
    /// Shows a Beta badge.
    var beta: Bool = false

    var body: some View {
        PanelCard {
            HStack(spacing: 14) {
                glyph
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.headline)
                if beta { BetaBadge() }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Single branch now (no if/switch over View types), so no
    /// @ViewBuilder needed here; the 46×46 frame + cornerRadius 12
    /// in body are untouched.
    private var glyph: some View {
        ZStack {
            Rectangle().fill(Theme.gradient(color))
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

