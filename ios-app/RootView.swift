import SwiftUI
import UIKit

/// B-2 (0.9.157): the Sources badge's recount wiring, as its own
/// modifier — `RootView.body`'s chain grew too long for the compiler to
/// type-check once these five joined it (0.9.157 build: "unable to
/// type-check this expression in reasonable time" at RootView:251).
/// Same wiring, only split out of `body`: the fix is to split the
/// expression, not to change the logic. The chain is now shorter than
/// the 0.9.156 one that built green.
private struct SourcesBadgeRecountModifier: ViewModifier {
    @ObservedObject var sourcesManager: SourcesManager
    @ObservedObject var appsManager: SideloadedAppsManager

    func body(content: Content) -> some View {
        content
            // F-D (0.9.156): the installed list arrives after the launch
            // fetch (autoLoad reads the device), so the badge recounts
            // when it lands.
            .onChange(of: appsManager.entries) { _, entries in
                sourcesManager.recountUpdates(installed: entries)
            }
            // B-2 (0.9.157): the badge counts from this manager's states,
            // so it recounts whenever they or the disabled set change —
            // not only at the three call sites that used to recount by hand.
            .onChange(of: sourcesManager.states) { _, _ in
                sourcesManager.recountUpdates(installed: appsManager.entries)
            }
            .onChange(of: sourcesManager.disabled) { _, _ in
                sourcesManager.recountUpdates(installed: appsManager.entries)
            }
            // B-2 (0.9.157): the Sources tab fetches through the fork
            // store, not this manager — when it lands a document, adopt
            // it for the badge; when the list or a disabled flag changes,
            // re-read them.
            .onReceive(NotificationCenter.default.publisher(for: SourceStore.contentDidChange)) { _ in
                Task { @MainActor in
                    sourcesManager.adoptCachedSources()
                    sourcesManager.recountUpdates(installed: appsManager.entries)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UnifiedSourceList.didChange)) { _ in
                Task { @MainActor in
                    sourcesManager.syncURLs()
                    sourcesManager.recountUpdates(installed: appsManager.entries)
                }
            }
    }
}

/// Tab container (Files, Apps, Sources, Downloads, Settings). Each page draws its own
/// `AppBackground`, since `TabView` would hide a shared one; they stay in sync
/// because the background animates off the clock. Also hosts the sign-in sheet
/// (2FA, and which team signs) and the pages' popups, so they show over any tab.
struct RootView: View {
    /// The tabs. The selection is tracked so a tab switch can tick, and a
    /// link can bring the install sheet forward.
    /// U-UI：五栏改成截图那套——文件 / 应用 / 源 / 下载 / 设置。
    /// 证书 tab 拆掉（签名段 → 设置·企业证书页，应用库段 → 文件·应用文件夹库）；
    /// Install tab 拆掉（ContentView 变全屏 sheet，见 showInstallSheet）；
    /// Tools/About 两 tab 拆掉（行 → 设置·工具区 / 关于区）。
    private enum Page: Hashable {
        case files, apps, sources, downloads, settings

        var wash: Backdrop.Level {
            // 工具 tab 的 .dark 随旧工具页一起没了；新列表页全是
            // 白底（U8），wash 全亮，不再分情况。
            switch self {
            case .files, .apps, .sources, .downloads, .settings: .bright
            }
        }
    }

    /// What the sign-in sheet shows: a 2FA prompt, or which team signs.
    private enum SignInSheet: Equatable {
        case twoFactor(TwoFactorPhase)
        case team(TeamQuestion)
    }

    /// One popup, tagged with the page that raised it.
    private enum PopupItem: Hashable {
        case install(Engine.Popup)
        case pairing(PairingManager.Popup)
        case certificates(ToolPopup)
        case entitlements(EntitlementsManager.Popup)
        case location(ToolPopup)
        case apps(ToolPopup)
        case jit(ToolPopup)
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
    /// The app's own, shared with the JIT page, which generates a missing
    /// pairing file with it.
    @ObservedObject private var pairingManager = PairingManager.shared
    /// The app's own, shared with the Shortcuts actions.
    @ObservedObject private var locationManager = LocationManager.shared
    @StateObject private var entitlementsManager = EntitlementsManager()
    /// 与快捷指令共用同一个实例（SideloadedAppsManager.shared），后台续签状态界面可见。
    @ObservedObject private var appsManager = SideloadedAppsManager.shared
    @StateObject private var sideBySideManager = SideBySideManager()
    /// 证书页与文件页之间传递待签 IPA。
    @StateObject private var certWorkspace = CertWorkspace()
    @State private var page: Page = .sources
    /// U-UI：安装页改全屏 sheet 后的开关（浮动 pill 与链接/分享入口共用）。
    @State private var showInstallSheet = false
    /// C31：2FA 弹着时安装页暂缓打开的待处理标志（反方向）。
    @State private var showInstallSheetPending = false
    /// U-UI：文件页/源页“签名”动作要求打开设置里的企业证书页时置位；
    /// SettingsView 的企业区 NavigationLink 认它，打开后自己清掉。
    @State private var settingsEnterpriseRequest = false
    /// P0-2 (0.9.185): the error popup's "View log" asks for the
    /// activity log; SettingsView's log section scrolls to it, then
    /// clears the flag itself (settingsEnterpriseRequest 同款）.
    @State private var settingsLogRequest = false
    /// P1-1/P1-4 (0.9.186): a "Go to Settings" action asks for the
    /// Account section; SettingsView scrolls to it, then clears the
    /// flag itself (settingsLogRequest 同款）.
    @State private var settingsAccountRequest = false
    /// P1-4 (0.9.186): a failed refresh whose next step is the
    /// Certificates page; SettingsView's tools NavigationLink opens
    /// it, then clears the flag itself (enterpriseRequest 同款）.
    @State private var settingsCertRequest = false
    @StateObject private var sourcesManager = SourcesManager()
    @StateObject private var jitManager = JITManager()
    /// What the sign-in sheet showed last, so it keeps its content while it
    /// slides away after the sign-in clears it.
    @State private var shownSignInSheet: SignInSheet?

    var body: some View {
        // `.tabItem`/`.tag` rather than iOS 18's `Tab`, to keep iOS 17.
        // U-UI：五栏——文件 / 应用 / 源 / 下载 / 设置（截图顺序）。
        // 图标全是仓内已用过的 SF Symbol（storefront 见 SideBySideView:86，
        // square.grid.2x2 见 SideBySideView:2521，arrow.down.circle 见旧 Tools 行，
        // gearshape 见旧 Tools 行，folder.fill 见旧文件 tab）。
        TabView(selection: tabSelection) {
            FilesTabView()
                .blueTopBar()
                .tabItem { Label(L("File"), systemImage: "folder") }
                .tag(Page.files)
            NavigationStack { AppsView(manager: appsManager) }
                .blueTopBar()
                .tabItem { Label(L("Apps"), systemImage: "square.grid.2x2") }
                .tag(Page.apps)
                .badge(appsManager.expiringSoon > 0 ? Text("\(appsManager.expiringSoon)") : nil)
            NavigationStack { SourcesView() }
                .blueTopBar()
                .tabItem { Label(L("Sources"), systemImage: "storefront") }
                .tag(Page.sources)
                // F-D (0.9.156): the Apps tab's expiring-soon badge, but for
                // updates — 0 shows nothing, like the Apps tab.
                .badge(sourcesManager.availableUpdateCount > 0 ? Text("\(sourcesManager.availableUpdateCount)") : nil)
            NavigationStack { DownloadsListView() }
                .blueTopBar()
                .tabItem { Label(L("Download"), systemImage: "arrow.down.circle") }
                .tag(Page.downloads)
            SettingsView(isTab: true, enterpriseRequest: $settingsEnterpriseRequest, logRequest: $settingsLogRequest, accountRequest: $settingsAccountRequest, certRequest: $settingsCertRequest)
                .tabItem { Label(L("Settings"), systemImage: "gearshape") }
                .tag(Page.settings)
        }
        .environmentObject(certWorkspace)
        // F-2 (0.9.179): the share-in certificate choice sheet.
        .modifier(SigningChoiceSheetModifier())
        // F-3 (0.9.164): a history row's "Show in Downloads" — switch to the
        // Downloads tab; DownloadsListView scrolls to the file itself.
        .onReceive(NotificationCenter.default.publisher(for: Engine.revealDownload)) { _ in
            page = .downloads
        }
        // P0-2 (0.9.185): the error popup's "View log" — the install
        // sheet would cover the tab, so close it first (the 2FA
        // handling below does the same), then switch to Settings
        // and let the log section scroll itself into view.
        .onReceive(NotificationCenter.default.publisher(for: Engine.revealLog)) { _ in
            showInstallSheet = false
            showInstallSheetPending = false
            page = .settings
            settingsLogRequest = true
        }
        // P1-1/P1-4 (0.9.186): the install checklist's and the failed
        // refresh row's "Go to Settings" — same shape as revealLog,
        // landing on the Account section instead of the log.
        .onReceive(NotificationCenter.default.publisher(for: Engine.revealAccount)) { _ in
            showInstallSheet = false
            showInstallSheetPending = false
            page = .settings
            settingsAccountRequest = true
        }
        // P1-4 (0.9.186): the failed refresh row's "Go to the
        // Certificates page" — same shape, opening that page.
        .onReceive(NotificationCenter.default.publisher(for: Engine.revealCertificates)) { _ in
            showInstallSheet = false
            showInstallSheetPending = false
            page = .settings
            settingsCertRequest = true
        }
        // U-UI：文件页/源页把 IPA 交给企业证书页时（CertWorkspace.openEnterpriseSign），
        // 切到设置 tab 并让企业区自动打开；标志由这里清掉，只触发一次。
        .onChange(of: certWorkspace.openEnterpriseSign) { _, open in
            guard open else { return }
            certWorkspace.openEnterpriseSign = false
            page = .settings
            settingsEnterpriseRequest = true
        }
        // Animate the backdrop to the new tab's level.
        .onChange(of: page) { _, page in Backdrop.settle(on: page.wash) }
        // A link's install or pairing file ends up on the install sheet, so its
        // popup comes up over that.
        .onChange(of: engine.pendingLink) { _, link in
            if link != nil { openInstallSheet() }
        }
        // A share / “Open with” IPA import lands here too: the run it started
        // (or the guide it stopped on) lives on the install sheet, so jump
        // there instead of leaving the user to go find it by hand.
        .onChange(of: engine.sharedIPAReady) { _, ready in
            if ready { openInstallSheet(); engine.sharedIPAReady = false }
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
        .fullScreenCover(isPresented: $showInstallSheet) {
            ContentView()
                .popupStack(installEntries, onBackdropTap: installBackdropTap) { entry in
                    card(for: entry)
                }
        }
        // U-UI：安装进行中/刚跑完时各 tab 底部浮一颗 pill，点开就是
        // 原来的安装页（ContentView 原样搬进 sheet，逻辑不动）；
        // 没跑过时不显示，不占地方。文案复用 L("Install")，0 新 key。
        .overlay(alignment: .bottom) {
            if engine.isRunning || engine.overallProgress > 0 || engine.finished {
                Button { openInstallSheet() } label: {
                    HStack(spacing: 6) {
                        if engine.isRunning {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(L("Install"))
                        Image(systemName: "chevron.up")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.topBarFill))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
        }
        // Over the tab bar too, so the whole app dims behind the popups.
        .popupStack(showInstallSheet ? otherEntries : entries,
                    onBackdropTap: showInstallSheet ? otherBackdropTap : backdropTap) { entry in
            card(for: entry)
        }
        .onChange(of: popups) { old, new in
            playSound(forShown: new.filter { !old.contains($0) })
        }
        // The Install tab's revoke-and-retry runs through this same manager
        // (declared below the popups, which use it too).
        .environmentObject(certManager)
        .environmentObject(pairingManager)
        .environmentObject(locationManager)
        .environmentObject(entitlementsManager)
        .environmentObject(appsManager)
        .environmentObject(sideBySideManager)
        // 0.9.140: the JIT and Sources pages live in Settings now (their
        // old Tools tab is gone), so their managers come from here too.
        .environmentObject(sourcesManager)
        .environmentObject(jitManager)
        // When the active Apple ID changes, drop all four cached Apple sessions
        // (Side by Side's included) so none is reused for the new account.
        .onChange(of: accounts.revision) { _, _ in
            engine.forgetAppleSession()
            certManager.signOut()
            entitlementsManager.signOut()
            sideBySideManager.signOut()
        }
        .tint(Theme.topBarFill)
        // 外观只听 App 入口的 SIDAppearance 档（SideInstallerApp 的
        // .preferredColorScheme），这里不再硬编码 .dark，否则主界面
        // 永远深色、设置页却跟浅色档走，两边割裂。
        // The sources are checked for updates once when SideInstaller opens,
        // as SideInstallerApp checks SideInstaller itself, so the Sources tile
        // can show how many there are.
        .task { await sourcesManager.checkAtLaunch(apps: appsManager) }
        // B-2 (0.9.157): the badge's recount wiring lives in
        // `SourcesBadgeRecountModifier` — inline here it pushed the
        // body's chain past what the compiler can type-check.
        .modifier(SourcesBadgeRecountModifier(sourcesManager: sourcesManager, appsManager: appsManager))
        // A swipe down is a cancel; the sign-in closing it is not.
        .sheet(isPresented: Binding(
            get: { signInSheet != nil },
            set: { if !$0 { cancel(signInSheet) } }
        )) {
            switch signInSheet ?? shownSignInSheet {
            case .twoFactor(let phase): TwoFactorSheet(phase: phase)
            case .team(let question):   TeamSheet(question: question)
            case nil:                   EmptyView()
            }
        }
        .onChange(of: signInSheet) { _, sheet in
            if let sheet { shownSignInSheet = sheet }
        }
        // Which team signs is asked once per Apple ID.
        .onChange(of: engine.teamQuestion) { old, question in
            if let question, old?.request != question.request {
                SoundEffects.play(.attention)
            }
        }
        .onChange(of: engine.twoFactor) { old, phase in
            // C31：2FA 来了先落安装页（全屏 sheet 盖住 TabView 时 2FA sheet
            // 会被 UIKit 静默丢弃）；2FA 清掉后把暂缓的安装页补开。
            if phase != nil {
                if showInstallSheet { showInstallSheetPending = true }
                showInstallSheet = false
            } else if showInstallSheetPending {
                showInstallSheetPending = false
                showInstallSheet = true
            }
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

    /// C31：安装页与 2FA sheet 不能同时 present——2FA 弹着时只记 pending，
    /// 等 2FA 清掉再补开安装页（否则 UIKit 静默丢弃 present）。
    private func openInstallSheet() {
        if engine.twoFactor != nil {
            showInstallSheetPending = true
        } else {
            showInstallSheet = true
        }
    }

    /// The sign-in sheet's content now. The team question comes once the code
    /// has gone through, so it takes the sheet over.
    private var signInSheet: SignInSheet? {
        if let question = engine.teamQuestion { return .team(question) }
        return engine.twoFactor.map(SignInSheet.twoFactor)
    }

    /// Stops the sign-in the sheet asks for, as a swipe down does.
    private func cancel(_ sheet: SignInSheet?) {
        switch sheet {
        case .twoFactor(let phase): engine.cancelTwoFactor(phase)
        case .team(let question):   engine.cancelTeamQuestion(question)
        case nil:                   break
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
                     appsManager.popups.map(PopupItem.apps),
                     jitManager.popups.map(PopupItem.jit)]
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

    /// cover 里 backdrop 点按：只关 install 组里不阻塞的项。
    private var installBackdropTap: (() -> Void)? {
        let closable = installEntries.flatMap(\.items).filter { !blocks($0) }
        guard !closable.isEmpty else { return nil }
        return { SoundEffects.play(.dismiss); closable.forEach(close) }
    }
    /// TabView 层 backdrop 点按：只关非 install 组里不阻塞的项。
    private var otherBackdropTap: (() -> Void)? {
        let closable = otherEntries.flatMap(\.items).filter { !blocks($0) }
        guard !closable.isEmpty else { return nil }
        return { SoundEffects.play(.dismiss); closable.forEach(close) }
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
             .certificates(.error), .entitlements(.error), .location(.error), .apps(.error),
             .jit(.error):
            .error
        case .install(.success), .pairing(.success),
             .certificates(.success), .location(.success), .apps(.success), .jit(.success):
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
             .install(.pairingImportMismatch), .install(.link), .install(.cellularDownload),
             .install(.downgrade),
             .pairing(.pairingCode), .pairing(.pairInSettings):
            .attention
        }
    }

    /// True when a run is waiting on the popup, so closing it stops the run.
    private func blocks(_ item: PopupItem) -> Bool {
        switch item {
        case .install(let popup):    engine.blocks(popup)
        case .pairing(let popup):    pairingManager.blocks(popup)
        // The Tools pages only report; nothing waits on their popups.
        case .certificates, .entitlements, .location, .apps, .jit: false
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

    /// Install 组进全屏 cover 里渲染（TabView 层的 overlay 被 cover 盖住）；
    /// 其余组留在 TabView 层。组要么全是 install、要么全不是，不会拆散一组。
    private var installEntries: [PopupEntry] {
        entries.filter { $0.items.allSatisfy(isInstall) }
    }
    private var otherEntries: [PopupEntry] {
        entries.filter { !$0.items.allSatisfy(isInstall) }
    }
    private func isInstall(_ item: PopupItem) -> Bool {
        if case .install = item { return true }
        return false
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
        case .install(.appIDCost), .install(.pairingImportMismatch), .install(.link),
             .install(.cellularDownload), .install(.downgrade):
            nil
        case .pairing(.pairingCode), .pairing(.pairInSettings):
            .pairingPage
        case .pairing, .certificates, .entitlements, .location, .apps, .jit:
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
        case .jit(let popup):          jitManager.closePopup(popup)
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
        case .jit(let popup):
            toolPopup(popup, successTitle: L("JIT")) { jitManager.closePopup(popup) }
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
                        .foregroundStyle(Theme.muted)
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
                                .foregroundStyle(Theme.muted)
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
