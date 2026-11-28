import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The Install screen: an Apple ID, a build, and a step timeline while it runs.
struct ContentView: View {
    @Environment(Engine.self) private var engine
    @EnvironmentObject private var updateChecker: UpdateChecker
    /// F-1 (0.9.179): the enterprise branch of the self-update hands its
    /// downloaded IPA to the signing page through this workspace.
    @EnvironmentObject private var certWorkspace: CertWorkspace
    /// Dismisses this full-screen cover; P0 (0.9.152) uses it for the Back
    /// button — leaving the page never cancels the run.
    @Environment(\.dismiss) private var dismiss
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// P0-4 (0.9.185): the free-quota row reads the same device list
    /// as the Apps tab; CertManager gives the current team's id for
    /// the team-filtered count (CertsView.affectedApps 同款）.
    @EnvironmentObject private var appsManager: SideloadedAppsManager
    @EnvironmentObject private var certManager: CertManager
    /// P1-2 (0.9.186): the install page's account/team picker reads
    /// the saved Apple IDs straight from the store (Settings ›
    /// Account 同款来源）.
    @EnvironmentObject private var accounts: AccountStore
    /// P0-4 (0.9.185): the last signing method, reactive so the quota
    /// row hides when the user picks enterprise signing (which doesn't
    /// consume App IDs). Default mirrors CZFSignIdentity.stored.
    @AppStorage(CZFSignIdentity.defaultsKey) private var signIdentityRaw: String = CZFSignIdentity.enterprise.rawValue
    /// P0-5 (0.9.185): the custom IPA's paid-only capabilities, if any
    /// (nil = no custom IPA / not computed yet). Read by the install
    /// card's inline row and the precheck sheet; computed once per
    /// imported IPA in the task on appCard.
    @State private var missingCapabilities: [String]? = nil
    @Environment(\.openURL) private var openURL
    @State private var showSettings = false
    @State private var showImporter = false
    /// True while the pairing-file picker is up.
    @State private var showPairingImporter = false
    /// When false, the Advanced section under the Install button shows only its
    /// title.
    @State private var advancedExpanded = false
    /// When false, the timeline shows only the current step.
    @State private var stepsExpanded = false
    /// True while the Install button is held down. Its surface is drawn outside
    /// the button, so the press is passed out to it.
    @State private var installPressed = false
    /// Shows the "are you sure" alert before the progress card's X stops a run.
    @State private var confirmingCancel = false
    /// Shows the "install LocalDevVPN first" prompt when Install is tapped
    /// with no tunnel and no LocalDevVPN on the phone.
    @State private var showInstallLOCPrompt = false
    /// Shows the pre-install checklist sheet (v0.9.19).
    @State private var showPrecheck = false
    /// Shows the "LocalDevVPN's tunnel can only be closed from LocalDevVPN"
    /// note when the pill is tapped with a LOC tunnel up.
    @State private var showLOCStopNote = false
    /// F-1 (0.9.178): true while a manual update check from the banner is
    /// in flight — the banner's "Try again" can't double-tap (AboutView's
    /// `isCheckingUpdate` 同款；`UpdateChecker` has no in-flight flag).
    @State private var isCheckingUpdate = false
    /// The in-flight banner check, so a second tap can cancel it.
    @State private var checkTask: Task<Void, Never>?
    /// B-1 (0.9.194): which banner check is current — a cancelled
    /// check's Task still resumes, but only while no newer check has
    /// taken over (AboutView's `checkGeneration` 同款).
    @State private var checkGeneration = 0
    /// F-2 (0.9.178): true while the full release-notes sheet is up.
    @State private var showingReleaseNotes = false
    /// F-1 (0.9.179): true while the certificate choice sheet is up —
    /// a verified update doesn't install straight away any more, the
    /// user picks enterprise or Apple ID signing first.
    @State private var showingSigningChoice = false
    /// 0.9.197: 0.9.193 deferred 同款——点下的自更新选择先存这里，等
    /// sheet 真正消失后 onDismiss 再跑（见 `runDeferredSelfUpdateChoice`）。
    @State private var deferredSelfUpdateChoice: CZFSignIdentity?
    /// The tunnel was closed by hand from the pill: the holder-only
    /// auto-reconnect must not pull it back up until it comes up again.
    @State private var tunnelManualOff = false
    /// Last auto-reconnect attempt, so a flapping tunnel doesn't hammer start.
    @State private var lastTunnelReconnect = Date.distantPast
    /// Text in the IPA download-link field.
    @State private var ipaLink = ""
    /// B-1 (0.9.183): the clipboard's link, as state — the old computed
    /// property only re-read the pasteboard when the body happened to
    /// re-run, and nothing re-ran it when the app came back to the
    /// foreground, so a link copied in Safari never raised the paste
    /// button until some other state changed. Refreshed on appear and
    /// on every foreground return (below).
    @State private var clipboardLinkState: String?
    @FocusState private var linkFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header.cascadeItem(0)
                    if updateChecker.showBanner {
                        updateBanner.transition(.cardAppear)
                    }
                    appCard.cascadeItem(1)
                    // Below iOS 27 a pairing file must be imported, so show the
                    // import card.
                    if showsPairingCard {
                        pairingFileCard.cascadeItem(2)
                    }
                    // 企业证书签名在设置页的企业证书区（功能更全），安装页不再放卡片。
                    // Most-blocking requirement first: an unsupported iOS, then
                    // the missing tunnel. No Wi-Fi card: without Wi-Fi, Mobile
                    // Data Mode (beta) offers Airplane Mode instead.
                    if !engine.isRunning {
                        if !engine.osSupported {
                            osRequirement.cascadeItem(cascade(2))
                        // Not when Install starts LocalDevVPN itself.
                        } else if !engine.tunnelAvailable, !BuiltinTunnel.useBuiltinDirectly {
                            vpnRequirement.cascadeItem(cascade(2))
                        }
                    }
                    // The Install button, which grows into the run's progress.
                    // Drawn over what follows, so the button below tucks in
                    // under it.
                    installSurface
                        .cascadeItem(cascade(3))
                        .zIndex(1)
                    // The progress outlives its run, so the button comes back
                    // under it. The cascade handles its entrance (including
                    // on a tab switch), so the transition only covers removal.
                    if showProgress && !engine.isRunning {
                        installButton
                            .cascadeItem(cascade(4))
                            .transition(.asymmetric(insertion: .identity, removal: .tuckUnder))
                    }
                    // The build's version, and from iOS 27 (which pairs itself)
                    // the optional pairing-file import, folded away. Like the
                    // button above, the cascade brings it back after a run.
                    if showsAdvanced {
                        advancedSection
                            .cascadeItem(cascade(5))
                            .transition(.asymmetric(insertion: .identity, removal: .quickFade))
                    }
                    // Guides, the pairing code, errors and success show as
                    // `InstallPopup`, which `RootView` lays over the app.
                    footer.cascadeItem(cascade(6))
                }
                .padding(20)
                // One modifier per piece of state, so only its own card animates.
                .animation(.smooth(duration: 0.35), value: updateChecker.showBanner)
                .animation(.smooth(duration: 0.35), value: engine.vpnConnected)
                .animation(.smooth(duration: 0.35), value: engine.wifiConnected)
                // The surface's change of shape, and what it pushes along.
                .animation(.smooth(duration: 0.45), value: showProgress)
                .animation(.smooth(duration: 0.4), value: engine.finished)
                .animation(.smooth(duration: 0.35), value: engine.deviceSummary)
                .animation(.smooth(duration: 0.3), value: engine.isRunning)
                .animation(.smooth(duration: 0.35), value: engine.importedPairingName)
                .animation(.smooth(duration: 0.35), value: advancedExpanded)
                .animation(.smooth(duration: 0.35), value: showsAdvanced)
            }
            .background(AppBackground())
            .toolbar {
                // P0 (0.9.152): this page is a full-screen cover over the tab
                // bar — the tab bar and its pill are unreachable from here,
                // and the header's chevron only opens the step list while the
                // X cancels the run. Without a way out, a run in flight left
                // the user stuck on this page. Back only hides the page: the
                // run keeps going, and the pill at the bottom of the tabs
                // brings the page back with its progress.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        CZFHaptics.impact(.light)
                        dismiss()
                    } label: {
                        Label(L("Back"), systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain, sound: .tick)
                }
                settingsToolbarItem(isPresented: $showSettings)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showImporter) {
                FileImporterRepresentableView(allowedContentTypes: [.ipa]) { urls in
                    guard let url = urls.first else { return }   // empty means cancelled
                    Task { _ = await engine.importCustomIPA(from: url) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPairingImporter) {
                FileImporterRepresentableView(allowedContentTypes: UTType.pairingFileTypes) { urls in
                    guard let url = urls.first else { return }   // empty means cancelled
                    Task { await engine.importPairingFile(from: url) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPrecheck) {
                PrecheckSheet(onContinue: continueAfterPrecheck, missingCapabilities: missingCapabilities)
            }
            .sheet(isPresented: $showingSigningChoice, onDismiss: { runDeferredSelfUpdateChoice() }) {
                CertificateChoiceSheet(
                    isSelfUpdate: true,
                    onChoose: { deferredSelfUpdateChoice = $0; showingSigningChoice = false },
                    onCancel: { showingSigningChoice = false }
                )
            }
            .alert(L("LocalDevVPN 隧道"), isPresented: $showLOCStopNote) {
                Button(L("打开 LocalDevVPN")) { engine.startLocalDevVPN() }
                Button(L("Cancel"), role: .cancel) { }
            } message: {
                Text(L("LocalDevVPN 的隧道只能在 LocalDevVPN 里关。过去关掉后，回到这里 pill 会自动变回关闭态。"))
            }
            .scrollDismissesKeyboard(.interactively)
            // B-1 (0.9.183): re-read the clipboard when this page appears
            // and whenever the app returns to the foreground — a link
            // copied in another app must raise the paste button at once,
            // not on the next unrelated body refresh.
            .onAppear {
                refreshClipboardLink()
                // P0-4 (0.9.185): the quota row needs the device list;
                // the Apps tab's auto-load, shared manager — guarded
                // inside (once, tunnel up, never starts LocalDevVPN).
                appsManager.autoLoad()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                refreshClipboardLink()
            }
            // SIDE-2：安装页不再预连隧道（2026-11-21 用户亲令按需开）：
            // 以前打开安装页即拉、WiFi 后连上再补一次，什么都没点隧道
            // 已经起了。隧道只在需要它的操作开始时起（见 Engine 租约）。
            // 断线重连只留给“有操作正在用隧道”的情况：空闲掉线不再拉回。
            .onChange(of: engine.vpnConnected) { _, isUp in
                if isUp {
                    // 回升即清手动关闭：下次重连恢复正常。
                    tunnelManualOff = false
                } else if !tunnelManualOff, !engine.isRunning, engine.tunnelHolders > 0,
                          engine.wifiConnected, BuiltinTunnel.useBuiltinDirectly,
                          Date().timeIntervalSince(lastTunnelReconnect) > 30 {
                    // 隧道中途掉了：只走内置直连（绝不无操作跳去
                    // LocalDevVPN），30 秒内只试一次；运行中隧道
                    // 归操作方 ensureNetwork 管，这里不插手。
                    lastTunnelReconnect = Date()
                    Task { _ = await engine.tunnelUp() }
                }
            }
        }
    }

    // MARK: Derived visibility

    private var showProgress: Bool {
        engine.isRunning || engine.overallProgress > 0 || engine.finished
    }

    /// True on an iPhone new enough to install but too old to pair itself.
    private var showsPairingCard: Bool {
        engine.osSupported && !engine.canSelfPair
    }

    /// True when Advanced has something to hold: a version to pick (not for a
    /// custom IPA), or the optional pairing file (iOS 27 and above). A run
    /// can't take a change to either, so it's away while one goes.
    private var showsAdvanced: Bool {
        !engine.isRunning && (engine.installSource != .custom || engine.canSelfPair)
    }

    /// Cascade index for items below the pairing-file card, shifted by one when
    /// that card is shown.
    private func cascade(_ position: Int) -> Int {
        showsPairingCard ? position + 1 : position
    }

    /// True once a step has failed; turns the progress card red.
    private var runFailed: Bool {
        engine.stepStates.values.contains(.failed)
    }

    /// The active, waiting or failed step; otherwise the last completed one.
    private var currentStep: Step {
        if let live = Step.allCases.first(where: {
            let state = engine.stepStates[$0]
            return state == .active || state == .waiting || state == .failed
        }) {
            return live
        }
        return Step.allCases.last { engine.stepStates[$0] == .done } ?? .network
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "arrow.down.app.fill", image: "AppLogo", title: "SideInstaller 🅥",
                    animateIcon: engine.isRunning) {
            statusPill
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                .id(statusPillID)
        }
    }

    /// A stable identity so the pill cross-fades when its meaning changes.
    private var statusPillID: String {
        engine.deviceSummary ?? (engine.vpnConnected ? "up"
            : (engine.startsVPNWhenNeeded || BuiltinTunnel.useBuiltinDirectly ? "standby" : "down"))
    }

    /// Tunnel pill, tappable (v0.9.19): connected stops it, off starts it.
    /// The device pill stays information-only. Orange no longer reads
    /// "Tunnel off" like the red problem state: "standby" means Install
    /// will start it on demand, red means nothing will.
    @ViewBuilder
    private var statusPill: some View {
        if let summary = engine.deviceSummary {
            StatusDot(text: summary, color: Theme.positive)
        } else if engine.vpnConnected {
            Button(action: stopTunnelFromTap) {
                StatusPill(text: L("Tunnel connected"), systemImage: "checkmark.shield.fill", color: Theme.positive)
            }
            .buttonStyle(.plain)
        } else if engine.startsVPNWhenNeeded || BuiltinTunnel.useBuiltinDirectly {
            Button(action: startTunnelFromTap) {
                StatusPill(text: L("Tunnel standby"), systemImage: "shield.slash.fill", color: Theme.warning, glass: true)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: startTunnelFromTap) {
                StatusPill(text: L("Tunnel off"), systemImage: "shield.slash.fill", color: Theme.negative)
            }
            .buttonStyle(.plain)
        }
    }

    /// Pill 点按：已连时关。内置隧道直接停；LOC 的隧道是另一个 App 的，
    /// 本 App 停不掉，只提示去 LocalDevVPN 里关。
    private func stopTunnelFromTap() {
        CZFHaptics.impact()
        guard BuiltinTunnel.useBuiltinDirectly else {
            showLOCStopNote = true
            return
        }
        tunnelManualOff = true
        Task { @MainActor in
            // SIDE-2：手动关顺带释放 pill 开的那一次持有（有才放，没有空操作，
            // 不碰操作方持有的计数），再取消闲置停计时、立刻停隧道。
            if engine.tunnelManualHold {
                engine.tunnelManualHold = false
                engine.releaseTunnel()
            }
            engine.cancelTunnelIdleStop()
            // S21：还有操作方持有时不调停——在途的安装/续签正用着隧道，
            // 只记日志；持有归零时照旧停。
            guard engine.tunnelHolders == 0 else {
                engine.log("Tunnel: pill tap ignored — an operation still holds the tunnel (\(engine.tunnelHolders) holder(s)).")
                return
            }
            await BuiltinTunnel.stop()
        }
    }

    /// Pill 点按：未连时开。内置直接拉；LOC 装了就交接过去；
    /// 都没有时弹已有的安装提示（跟点安装同一处）。
    private func startTunnelFromTap() {
        CZFHaptics.impact()
        tunnelManualOff = false
        if BuiltinTunnel.useBuiltinDirectly {
            // SIDE-2：pill 手动开拿一次手动持有——用户亲手开的隧道不参与
            // 闲置停，只由 pill 关释放；拿不到就不置持有。
            Task { @MainActor in
                if await engine.acquireTunnel() {
                    engine.tunnelManualHold = true
                }
            }
        } else if engine.localDevVPNInstalled {
            engine.startLocalDevVPN()
        } else {
            showInstallLOCPrompt = true
        }
    }

    // MARK: Footer

    /// A quiet brand credit at the foot of the screen.
    private var footer: some View {
        Text(L("an app by Frizzle"))
            .font(.caption)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    // MARK: Update banner

    /// B-1 (0.9.177): txt 已新、门控未过 — the banner stays up, but
    /// the second line says the release is still being published
    /// instead of offering an update that isn't verified yet (About's
    /// detail line shares the same sentence).
    /// B-1 (0.9.179): a gate that failed on the network says so —
    /// the release-is-still-publishing sentence is only for a gate
    /// that failed on the release itself (wrong tag / missing asset).
    private var updateBannerDetail: String {
        if updateChecker.pendingReleaseNetworkFailed {
            return L("Couldn't check for updates. Check your connection and try again.")
        }
        if updateChecker.pendingRelease {
            return L("SideInstaller %@ is still being published — try again later.",
                     updateChecker.latestVersion ?? "")
        }
        return L("SideInstaller %@ is available — you're on %@.",
                 updateChecker.latestVersion ?? "", updateChecker.currentVersion)
    }

    /// F-3 (0.9.179): "Update now · 28 MB" — the verified release IPA's
    /// size, when the gate recorded it; plain "Update now" when it didn't.
    private var updateNowText: String {
        guard let size = updateChecker.latestAssetSize else { return L("Update now") }
        return L("Update now") + " · " + CZFFormattedSize.size(size)
    }

    /// Notice shown when GitHub advertises a newer version than this build.
    private var updateBanner: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.up.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Update available"))
                            .font(.subheadline.weight(.medium))
                        Text(updateBannerDetail)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Button {
                        updateChecker.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Theme.control))
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain, sound: .dismiss)
                }
                HStack(spacing: 12) {
                    // F-1 (0.9.182): no more jumping to Safari — when a
                    // verified update is waiting (or one is running), the
                    // Install pill below IS the in-app update, so this
                    // link is hidden instead of offering a second path
                    // out of the app. It only stays while the release
                    // isn't verified yet (pendingRelease), when there is
                    // no in-app install to run and the repo page is the
                    // only manual way to fetch it.
                    if !updateChecker.selfUpdateAvailable && !updateChecker.isSelfUpdating {
                        Button {
                            if let url = URL(string: UpdateChecker.installPageURL) { openURL(url) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(L("Get the latest version"))
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    // F-1 (0.9.178): the release is still being published —
                    // re-run the check from here instead of sending the
                    // user to About → Check for updates. A second tap
                    // while one is in flight cancels it (B-3, 0.9.179:
                    // no `.disabled` any more — AboutView's runUpdateCheck
                    // 同款, which never had one); the banner itself
                    // reports the outcome, so nothing is stored here.
                    if updateChecker.pendingRelease {
                        Button {
                            retryUpdateCheck()
                        } label: {
                            Text(isCheckingUpdate ? L("Checking for updates…") : L("Try again"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    // F-1 (0.9.176): 一键自更新——About 页 `startSelfUpdate`
                    // 同一条管线（0.9.143 搁置的一键选项至今没补），状态
                    // 已抽到 `UpdateChecker` 共享处，横幅上直接跑。只在
                    // 已验证有新版时出现（未验证仍只留网页链接）；跑着时
                    // 显示进度、点它取消；被拒的原因写在下面一行。本轮
                    // UI 打磨：更新按钮做成实心 pill，与链接并排，不再
                    // 只有一行弱链接。
                    // F-1 (0.9.179): 点它不再直装——先弹证书选择（企业证书 /
                    // Apple ID），与 About 的版本 pill 同款。
                    if updateChecker.selfUpdateAvailable || updateChecker.isSelfUpdating {
                        Button {
                            if updateChecker.isSelfUpdating {
                                updateChecker.cancelSelfUpdate()
                            } else {
                                showingSigningChoice = true
                            }
                        } label: {
                            Text(updateChecker.isSelfUpdating
                                 ? (updateChecker.selfUpdateProgressText ?? L("Installing — tap to cancel"))
                                 : updateNowText)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Theme.accent))
                        }
                        .buttonStyle(.plain)
                    }
                }
                // F-1 (0.9.177): the verified newer release's notes —
                // the same section as About; only when an install is
                // actually offered.
                // F-2 (0.9.178): tap it for the full notes — the preview
                // is only the first 5 lines / ~500 chars, the complete
                // `releaseNotes` had no consumer until this sheet.
                if updateChecker.selfUpdateAvailable, let notes = updateChecker.releaseNotesPreview {
                    Button {
                        showingReleaseNotes = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(L("What's new"))
                                    .font(.footnote.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                            }
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingReleaseNotes) {
                        ReleaseNotesSheet(updateChecker: updateChecker)
                    }
                }
                if let error = updateChecker.selfUpdateError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.negative)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// 0.9.197: 0.9.193 deferred 同款（`SigningChoiceSheetModifier`）——
    /// 点下的选择只记下并清掉请求，后续动作推迟到 sheet 真正消失后的
    /// onDismiss 再跑；dismiss 与后续的 present 不撞同一事务。取消
    /// （onCancel / 下滑）时没有攒下的选择，直接 no-op。
    @MainActor
    private func runDeferredSelfUpdateChoice() {
        guard let choice = deferredSelfUpdateChoice else { return }
        deferredSelfUpdateChoice = nil
        chooseSelfUpdateIdentity(choice, updateChecker: updateChecker, certWorkspace: certWorkspace)
    }

    /// F-1 (0.9.178): re-run the version check from the banner while the
    /// release is pending — AboutView's `runUpdateCheck` 同款, minus the
    /// status line: the banner itself reports the outcome, so there is
    /// nothing to store here. A second tap while one is in flight cancels
    /// it. B-1 (0.9.194): the cancel is real now — the shared run is
    /// cancelled too (cancelling this view's Task alone never reached
    /// it), and "Checking…" clears at once instead of waiting for the
    /// Task to unwind.
    private func retryUpdateCheck() {
        if isCheckingUpdate {
            checkTask?.cancel()
            updateChecker.cancelCheck()
            isCheckingUpdate = false
            checkTask = nil
            return
        }
        isCheckingUpdate = true
        checkGeneration += 1
        let generation = checkGeneration
        checkTask = Task {
            _ = await updateChecker.check(force: true)
            guard generation == checkGeneration else { return }
            isCheckingUpdate = false
            checkTask = nil
        }
    }

    // MARK: App picker

    private var appCard: some View {
        PanelCard {
            // 0.9.188：卡内间距走共享 token，与 advancedSection /
            // progressContent 对齐（原字面 12，值不动）。
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                SectionTitle(title: L("Install"), systemImage: "square.and.arrow.down")
                quotaRow
                capabilitiesInlineRow
                // P1-1 (0.9.186): the preflight checklist, on the page
                // itself instead of only behind the Install tap's sheet —
                // the same guard conditions runOneClick enforces, shown
                // up front. P1-2: the signing account/team picker.
                if isAppleIDSigning {
                    preflightChecklist
                    accountTeamPicker
                }
                // Each app with its own icon, in the menu and in the field.
                Menu {
                    Picker(L("Install"), selection: Bindable(engine).installSource) {
                        ForEach(InstallSource.allCases) { src in
                            Label {
                                Text(src.displayName)
                            } icon: {
                                Image(uiImage: AppIconMenuImage.image(for: src))
                            }
                            .tag(src)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        AppIconTile(source: engine.installSource, side: 28)
                            .id(engine.installSource)
                            .transition(.opacity)
                        Text(engine.installSource.displayName)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.muted)
                    }
                    // Kept to a plain field's height, the icon included.
                    .padding(.vertical, -4)
                    .padding(.leading, -6)
                    .fieldBackground()
                    .contentShape(Rectangle())
                }
                // A value, not a link: the menu's label keeps the text colour.
                .tint(.primary)


                // A custom IPA has no release, so the importer takes that slot;
                // a build with one channel has nothing to pick and no slot.
                if engine.installSource == .custom || engine.channels(for: engine.installSource).count > 1 {
                    ZStack {
                        if engine.installSource == .custom {
                            importControl.transition(.opacity)
                        } else {
                            Picker(L("Release"), selection: Bindable(engine).releaseChannel) {
                                ForEach(ReleaseChannel.allCases) { channel in
                                    Text(channel.displayName).tag(channel)
                                }
                            }
                            .pickerStyle(.segmented)
                            .transition(.opacity)
                        }
                    }
                    .transition(.opacity)
                }
            }
            // On the whole card, so it also resizes smoothly when the slot goes.
            .animation(.smooth(duration: 0.28), value: engine.installSource)
            .animation(.smooth(duration: 0.28), value: engine.stableReleased)
        }
        .disabled(engine.isRunning || engine.batchUpdateRunning)
        // Madeira offers Stable only once its first stable release is out.
        .task(id: engine.installSource) { await engine.checkStableRelease(for: engine.installSource) }
        // P0-5 (0.9.185): the custom IPA's paid-only capabilities,
        // computed once per imported IPA (local zip read, no login
        // or network). The inline row and the precheck sheet share it.
        .task(id: engine.customIPAName) {
            if engine.installSource == .custom, let entry = IPALibrary.customImport() {
                missingCapabilities = Engine.unsupportedEntitlements(inIPA: entry.url)
            } else {
                missingCapabilities = nil
            }
        }
    }

    /// P0-4 (0.9.185): free slots before signing — AltStore's
    /// "View App IDs" as a one-liner. Only for Apple ID signing
    /// (enterprise doesn't consume App IDs), only once the device
    /// list has loaded (never a wrong 0/3), and only when the
    /// current team is known (else the count can't be attributed).
    /// The App ID half shows the last quota a run actually saw
    /// (`lastAppIDCost`); unknown until a run has checked, so the
    /// segment is omitted rather than guessed.
    @ViewBuilder
    private var quotaRow: some View {
        if (CZFSignIdentity(rawValue: signIdentityRaw) ?? .enterprise) == .appleID,
           appsManager.hasLoaded, let teamID = certManager.teamID {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(Theme.muted)
                Text(L("免费名额：已装 %d/3", installedCount(teamID: teamID)))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                if let cost = engine.lastAppIDCost,
                   let limit = cost.limit, let available = cost.available {
                    Text("·")
                        .foregroundStyle(Theme.muted)
                    Text(L("App ID：已用 %d/%d", limit - available, limit))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
            }
        }
    }

    /// The installed apps signed under the current team — the
    /// free 3-slot count (CertsView.affectedApps 同款口径）.
    private func installedCount(teamID: String) -> Int {
        appsManager.entries.filter { $0.current?.teamIdentifier == teamID }.count
    }

    /// P0-5 (0.9.185): the missing capabilities up front, on the
    /// install page itself — the precheck sheet only opens on a
    /// blocked row, so a warn-only row there would otherwise never
    /// be seen. Same sentence as the run's warning (installWarning).
    @ViewBuilder
    private var capabilitiesInlineRow: some View {
        if engine.installSource == .custom, let missing = missingCapabilities, !missing.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Theme.warning)
                Text(L("This IPA asks for %@, which a free Apple ID certificate can't provide. Those features will silently stop working after install.", missing.joined(separator: ", ")))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// P1-1 (0.9.186): the preflight checklist on the install page —
    /// pairing file / tunnel / Apple ID / team, one row each. The
    /// first three reuse the PrecheckSheet's own state functions
    /// (the same conditions runOneClick's guards enforce), so the
    /// page and the tap-time sheet can never disagree; the team row
    /// reads the remembered team for the active account. Display
    /// only — the guards themselves are untouched. Each failing row
    /// carries its fix: import the pairing file here, start the
    /// tunnel, or jump to Settings › Account.
    private var isAppleIDSigning: Bool {
        (CZFSignIdentity(rawValue: signIdentityRaw) ?? .enterprise) == .appleID
    }

    @ViewBuilder
    private var preflightChecklist: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text(L("安装前检查"))
                    .font(.subheadline.weight(.semibold))
                if pairingPrecheckState(engine) == .blocked {
                    preflightRow(title: L("Pairing file"), state: .blocked, detail: L("未导入"),
                                 fixTitle: L("Import pairing file")) { showPairingImporter = true }
                } else if engine.canSelfPair {
                    preflightRow(title: L("Pairing file"), state: .ok, detail: L("本机可自配对，不需要文件"))
                } else if let name = engine.importedPairingName {
                    preflightRow(title: L("Pairing file"), state: .ok, detail: L("已导入：%@", name))
                } else {
                    preflightRow(title: L("Pairing file"), state: .ok, detail: L("imported pairing file"))
                }
                if tunnelPrecheckState(engine) == .ok {
                    preflightRow(title: L("Tunnel"), state: .ok, detail: L("connected"))
                } else if tunnelPrecheckState(engine) == .warn {
                    preflightRow(title: L("Tunnel"), state: .warn, detail: L("未连接，安装时自动启动"),
                                 fixTitle: L("去连 LocalDevVPN")) { startTunnelFromChecklist() }
                } else if engine.localDevVPNInstalled {
                    preflightRow(title: L("Tunnel"), state: .blocked, detail: L("未连接，且不会自动启动"),
                                 fixTitle: L("去连 LocalDevVPN")) { _ = engine.startLocalDevVPN() }
                } else {
                    preflightRow(title: L("Tunnel"), state: .blocked, detail: L("未连接，且不会自动启动——点继续安装时会提示安装 LocalDevVPN"),
                                 fixTitle: L("Get LocalDevVPN")) { if let url = Guides.vpn.actionURL { openURL(url) } }
                }
                if accountPrecheckState(engine) == .ok {
                    preflightRow(title: L("Apple ID（签名身份）"), state: .ok, detail: engine.normalizedAppleID)
                } else {
                    preflightRow(title: L("Apple ID（签名身份）"), state: .blocked, detail: L("去设置页登录 Apple ID 并填好密码"),
                                 fixTitle: L("去设置")) { NotificationCenter.default.post(name: Engine.revealAccount, object: nil) }
                }
                if accountPrecheckState(engine) != .ok {
                    preflightRow(title: L("Team"), state: .blocked, detail: L("去设置页登录 Apple ID 并填好密码"),
                                 fixTitle: L("去设置")) { NotificationCenter.default.post(name: Engine.revealAccount, object: nil) }
                } else if let team = accounts.team(for: engine.normalizedAppleID) {
                    preflightRow(title: L("Team"), state: .ok, detail: team.label)
                } else {
                    preflightRow(title: L("Team"), state: .warn, detail: L("首次登录时选择"),
                                 fixTitle: L("去设置")) { NotificationCenter.default.post(name: Engine.revealAccount, object: nil) }
                }
            }
        }
        // The tunnel/Wi-Fi states are read live; refresh once on appear
        // so a tunnel connected elsewhere shows green without a tap.
        .task { engine.refreshNetworkStatus() }
    }

    /// One checklist row: status colour + title + detail, with an
    /// optional fix button on the right (precheckRow 同款形状，行更紧凑，
    /// so four of them fit in one card on the install page).
    /// 0.9.188：行内间距与 PrecheckSheet 的 precheckRow 对齐（12），
    /// 图标字号与 precheckRow 相同（默认 body），行高一致。
    private func preflightRow(title: String, state: PrecheckState, detail: String,
                              fixTitle: String? = nil, fix: (() -> Void)? = nil) -> some View {
        HStack(spacing: Theme.spacingSmall) {
            Image(systemName: state.systemImage)
                .foregroundStyle(state.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let fixTitle, let fix {
                Button(fixTitle) { CZFHaptics.impact(); fix() }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    .controlSize(.small)
            }
        }
    }

    /// The checklist's tunnel fix: PrecheckSheet.startTunnel 同款
    /// （内置直拉，否则交接 LocalDevVPN）; with neither available
    /// the App Store page is the only way forward.
    private func startTunnelFromChecklist() {
        if BuiltinTunnel.useBuiltinDirectly {
            Task { _ = await engine.tunnelUp() }
        } else if engine.localDevVPNInstalled {
            engine.startLocalDevVPN()
        } else if let url = Guides.vpn.actionURL {
            openURL(url)
        }
    }

    /// P1-2 (0.9.186): pick the signing account and team on the
    /// install page, instead of going to Settings › Account and back.
    /// The account list is AccountStore's own; the team shown is the
    /// one remembered for that account (picked at sign-in through
    /// TeamSheet). Switching the account also drops the in-memory
    /// sign session, so the run's sign-in can't skip on the old
    /// session and sign with the wrong account.
    @ViewBuilder
    private var accountTeamPicker: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                HStack(spacing: Theme.spacingSmall) {
                    Text(L("签名账号"))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    if accounts.accounts.isEmpty {
                        Button(L("去设置")) { NotificationCenter.default.post(name: Engine.revealAccount, object: nil) }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                            .controlSize(.small)
                    } else {
                        Menu {
                            ForEach(accounts.accounts) { account in
                                Button { Task { await pickInstallAccount(account) } } label: {
                                    Label {
                                        Text(account.appleID)
                                    } icon: {
                                        if accounts.isActive(account) { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            Text(accounts.active?.appleID ?? L("Add Apple ID"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Theme.accent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: Theme.spacingSmall) {
                    Text(L("Team"))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    if let team = accounts.team(for: engine.normalizedAppleID) {
                        Text(team.label)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        Button(L("换团队")) { accounts.forgetTeam(for: engine.normalizedAppleID) }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                            .controlSize(.small)
                    } else {
                        Text(L("首次登录时选择"))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }

    /// Activates `account` for the next sign-in and drops the cached
    /// session, so the run signs as the account just picked. The
    /// revision listener drops it fire-and-forget too; awaiting the
    /// drop here closes the race where a run started right after the
    /// tap would still see the old session and skip sign-in.
    @MainActor
    private func pickInstallAccount(_ account: SavedAccount) async {
        guard !accounts.isActive(account) else { return }
        accounts.activate(account)
        await engine.dropSignSession()
        engine.log("Install: signing account switched to \(account.normalized).")
    }

    /// The two ways in for a custom build: pick a file, or paste a link.
    private var importControl: some View {
        VStack(spacing: Theme.spacingSmall) {
            filePickerButton
            if let build = engine.customIPABuild, !engine.isImportingIPA {
                recognizedNote(build)
            }
            orDivider
            linkField
        }
        .animation(.smooth(duration: 0.25), value: engine.customIPABuild)
    }

    /// Says the imported IPA is one of SideInstaller's own builds, which the
    /// install sets up just like its download: a LiveContainer + SideStore
    /// brought from elsewhere gets its pairing file where SideStore reads it.
    private func recognizedNote(_ build: InstallSource) -> some View {
        Text(L("SideInstaller recognizes this as %@ and sets it up just like its own download.",
               build.displayName))
            .font(.footnote)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
    }

    /// "or" divider between the file picker and the link field.
    private var orDivider: some View {
        HStack(spacing: 12) {
            Divider()
            Text(L("or"))
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Divider()
        }
        .padding(.vertical, 4)
    }

    /// Import button showing the loaded file's name, or progress while importing.
    private var filePickerButton: some View {
        Button {
            linkFieldFocused = false
            showImporter = true
        } label: {
            HStack(spacing: 8) {
                if engine.isImportingIPA {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: engine.customIPAName == nil
                          ? "square.and.arrow.down" : "checkmark.circle")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(engine.customIPAName == nil ? Theme.muted : Theme.accent)
                }
                Text(importLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Spacer()
                if engine.customIPAName != nil, !engine.isImportingIPA {
                    Text(L("Replace"))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .fieldBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain, sound: .tap)
        .disabled(engine.isImportingIPA)
    }

    /// The button's caption: what an import is doing, or what is loaded.
    private var importLabel: String {
        guard engine.isImportingIPA else { return engine.customIPAName ?? L("Import .ipa") }
        // A file copy reports no fraction; a link download does.
        guard let fraction = engine.importProgress else {
            // B1 (0.9.155): total unknown — byte count instead of a bare
            // "Importing…" that never says whether anything arrives.
            if let bytes = engine.importBytes {
                return L("%@ downloaded", ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
            }
            return L("Importing…")
        }
        return L("Downloading… %d%%", Int(fraction * 100))
    }

    /// Text field for importing an IPA from a direct download link.
    private var linkField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.muted)
                TextField(L("Paste a download link"), text: $ipaLink)
                    .textFieldStyle(.plain)
                    .focused($linkFieldFocused)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .lineLimit(1)
                    .onSubmit(downloadFromLink)
                if !ipaLink.isEmpty {
                    Button { ipaLink = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.muted)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain, sound: .tick)
                }
                // F-1 (0.9.181): one-tap paste of a copied IPA link —
                // only when the clipboard holds an http(s) link that
                // `Engine.downloadLink` accepts; otherwise the button
                // stays hidden instead of pasting plain text.
                if let clipboardLink = clipboardLinkState {
                    Button { ipaLink = clipboardLink } label: {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundStyle(Theme.muted)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain, sound: .tick)
                    .accessibilityLabel(L("Paste a download link"))
                }
                // F-3 (0.9.182): recent links — a clock button (only
                // when history is non-empty) opening a menu of the last
                // 5 used links; tapping one fills the field. Recorded
                // on a real `startLinkImport` start, deduped, newest
                // first, capped at 5, in UserDefaults.
                if !recentLinks.isEmpty {
                    Menu {
                        ForEach(recentLinks, id: \.self) { link in
                            Button(link) { ipaLink = link }
                        }
                        Divider()
                        // F-2 (0.9.184): clear the list — stale links
                        // otherwise sit here until five newer ones push
                        // them out, one by one.
                        Button(L("Clear recent links"), role: .destructive) {
                            recentLinks = []
                        }
                    } label: {
                        Image(systemName: "clock")
                            .foregroundStyle(Theme.muted)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain, sound: .tick)
                    .accessibilityLabel(L("Recent links"))
                }
                Button(action: downloadFromLink) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(linkIsUsable ? Theme.accent : Color.secondary.opacity(0.5))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain, sound: .tap)
                .disabled(!linkIsUsable)
            }
            .fieldBackground()
            // Progress bar for link downloads (file copies report no progress).
            if engine.isImportingIPA, let fraction = engine.importProgress {
                HStack(spacing: 8) {
                    ProgressView(value: fraction)
                        .tint(Theme.accent)
                    Button(L("Cancel")) { engine.cancelLinkImport() }
                        .buttonStyle(.plain, sound: .tap)
                        .foregroundStyle(Theme.accent)
                }
            } else if engine.isImportingIPA, engine.importBytes != nil {
                // B1 (0.9.155): total unknown — indeterminate bar; the byte
                // count rides in the button caption (`importLabel`).
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Theme.accent)
                    Button(L("Cancel")) { engine.cancelLinkImport() }
                        .buttonStyle(.plain, sound: .tap)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: engine.importProgress == nil)
    }

    /// True once the field holds something worth trying to download.
    private var linkIsUsable: Bool {
        !engine.isImportingIPA && Engine.downloadLink(ipaLink) != nil
    }

    /// F-1 (0.9.181): the clipboard's link, when it holds an http(s)
    /// URL that `Engine.downloadLink` accepts — nil for plain text or
    /// any other scheme, so the paste button never offers junk.
    /// B-1 (0.9.183): read on demand into `clipboardLinkState`, not as
    /// a computed property — see the state's comment.
    private static func readClipboardLink() -> String? {
        guard let text = UIPasteboard.general.string?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        let lowered = text.lowercased()
        guard lowered.hasPrefix("http://") || lowered.hasPrefix("https://"),
              Engine.downloadLink(text) != nil else { return nil }
        return text
    }

    /// B-1 (0.9.183): re-read the clipboard into state.
    private func refreshClipboardLink() {
        clipboardLinkState = Self.readClipboardLink()
    }

    /// F-3 (0.9.182): the last 5 links that really started a link
    /// import, newest first — UserDefaults, so they survive a relaunch.
    /// No shared store existed before this (full-repo grep: zero hits).
    private var recentLinks: [String] {
        get { UserDefaults.standard.stringArray(forKey: "CZFRecentLinks") ?? [] }
        // nonmutating: the setter only touches UserDefaults, never self —
        // a plain setter would demand a mutating caller and fail to compile.
        nonmutating set {
            UserDefaults.standard.set(Array(newValue.prefix(5)), forKey: "CZFRecentLinks")
        }
    }

    /// F-3 (0.9.182): record a link that started importing — dedupe,
    /// newest first, capped at 5.
    private func recordRecentLink(_ link: String) {
        var links = recentLinks
        links.removeAll { $0 == link }
        links.insert(link, at: 0)
        recentLinks = links
    }

    private func downloadFromLink() {
        guard linkIsUsable else { return }
        linkFieldFocused = false
        let link = ipaLink
        // B1 (0.9.147): the task lives in the engine, so the link row can
        // cancel it — the old fire-and-forget Task had no handle.
        // F-3 (0.9.182): only a real start joins the recent links.
        // F-2 (0.9.183): the field clears on a real start — the link
        // already sits in Recent links, so clearing loses nothing, and
        // a stale link left in the field invites a second tap that
        // re-imports the same IPA.
        if engine.startLinkImport(link) {
            recordRecentLink(link)
            ipaLink = ""
        }
    }

    // MARK: Primary action

    /// The Install button and the progress card it turns into, as one surface:
    /// starting a run reshapes the button instead of swapping it for a card.
    /// Only the two sets of content cross-fade; the surface itself changes
    /// size, and the button's blue gives way to the card's fill.
    private var installSurface: some View {
        // 0.9.188：圆角走卡片 token（原来硬编码 16；按钮与进度卡共用
        // 同一形状，表面不在两态之间跳变——值改走 Theme.cardRadius）。
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        return ZStack(alignment: .top) {
            if showProgress {
                progressContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .transition(.surfaceSwap)
            } else {
                Button(action: startInstall) {
                    installLabel
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                }
                // B-2 (0.9.175): 同 installButton——批跑时不另起安装；
                // 不然点它会走到 startInstall 的守卫、往 `engine.lastError`
                // 写原因，而批跑项正好在那时失败会把这句当成自己的失败原因。
                .disabled(engine.batchUpdateRunning)
                .buttonStyle(PressReportingButtonStyle(isPressed: $installPressed), sound: .press)
                .transition(.surfaceSwap)
            }
        }
        .frame(maxWidth: .infinity)
        // Clips the incoming content to the surface while it's still growing.
        .clipShape(shape)
        // The button's blue, which gives way to the card's fill.
        .background(
            shape
                .fill(Theme.blue)
                .opacity(showProgress ? 0 : 1)
        )
        .cardSurface(in: shape, shown: showProgress)
        // The press `PrimaryButtonStyle` draws, kept apart from the reshaping.
        .animation(.smooth(duration: 0.15)) { surface in
            surface
                .scaleEffect(surfacePressed ? 0.98 : 1)
                .opacity(surfacePressed ? 0.85 : 1)
        }
        .alert(L("Cancel the install?"), isPresented: $confirmingCancel) {
            Button(L("Yes"), role: .destructive) { CZFHaptics.impact(.light); engine.cancelOneClick() }
            Button(L("No"), role: .cancel) { }
        }
        .alert(L("未安装 LocalDevVPN"), isPresented: $showInstallLOCPrompt) {
            Button(L("去安装")) {
                CZFHaptics.impact(.light)
                if let url = URL(string: "https://xiaofang-source.pages.dev/localdevvpn.ipa") {
                    openURL(url)
                }
            }
            Button(L("Cancel"), role: .cancel) { }
        } message: {
            Text(L("安装要走 LocalDevVPN 的本地隧道。先装好 LocalDevVPN，之后点安装会自动打开它连接，不用手动开。"))
        }
        // F-2 (0.9.160): the entitlements precheck's warning — a free
        // certificate can't provide some capabilities this IPA asks for.
        // Informational only: the run is already going, OK just clears it.
        .alert(L("Before you install"), isPresented: Binding(
            get: { engine.installWarning != nil },
            set: { if !$0 { engine.installWarning = nil } }
        )) {
            Button(L("OK"), role: .cancel) { engine.installWarning = nil }
        } message: {
            Text(engine.installWarning ?? "")
        }
        .onChange(of: engine.isRunning) { _, running in
            // A run that ended by itself leaves nothing to cancel.
            if !running { confirmingCancel = false }
        }
    }

    /// True while the surface is the button and is held down.
    private var surfacePressed: Bool {
        installPressed && !showProgress
    }

    /// Starts the run straight from the tap. The surface reshapes because the
    /// run is going, so nothing waits on the animation.
    /// 点安装先算一次清单状态（跟 PrecheckSheet 同一套判定）：
    /// 只有红行（blocked，缺了会卡住）时才弹清单；全绿或只有
    /// 橙色（安装时自动启动）时直接走继续安装的路，省一屏一 tap。
    /// 真正的门禁仍在 continueAfterPrecheck 与 runOneClick 里。
    private func startInstall() {
        // B-2 (0.9.175): an update-all batch owns the install slot — its
        // download gaps leave `engine.isRunning` false, so this tap would
        // start a second install and knock the batch over. The source
        // detail page's `install(_:)` 同款双锁：the button below is
        // disabled while a batch runs, and this guard is the second lock
        // for a tap that slipped through. The reason goes on
        // `engine.lastError`, which the Install page shows as its error
        // popup (runOneClick's own guards 同款）; the guard runs before
        // the precheck sheet opens, so nothing opens over it.
        guard !engine.batchUpdateRunning else {
            engine.lastError = L("已有安装在进行，先等当前安装完成再试。")
            return
        }
        installPressed = false
        CZFHaptics.impact(.medium)
        engine.refreshNetworkStatus()
        if precheckHasBlocked(engine) {
            showPrecheck = true
        } else {
            continueAfterPrecheck()
        }
    }

    /// 清单点“继续安装”后走原 startInstall 的路：先过隧道门禁
    ///（没隧道 + 没内置 + 没装 LOC 时弹安装提示、不进 run），
    /// 再进 runOneClick（它自己的门禁照常跑）。
    private func continueAfterPrecheck() {
        // B-2 (0.9.175): the precheck sheet can outlive the tap that
        // opened it — a batch started while it was open would slip past
        // `startInstall`'s guard straight into `runOneClick`. Same lock
        // here; the sheet closes first and the reason lands on
        // `engine.lastError` on the next main-queue turn, so the sheet's
        // dismissal doesn't swallow the popup （同款：下面的
        // showInstallLOCPrompt 也是这么递延的）.
        guard !engine.batchUpdateRunning else {
            showPrecheck = false
            Task { @MainActor in engine.lastError = L("已有安装在进行，先等当前安装完成再试。") }
            return
        }
        CZFHaptics.impact(.medium)
        showPrecheck = false
        // 点安装先检查隧道：没通也不再查 WiFi（2026-10-29，
        // 跟续签同理：回环隧道不出设备，WiFi 与它无关；
        // 只有第一次配对才要 WiFi，那是引擎 ensureNetwork
        // 里 needsFreshPairing 的事，不归这里管）。签名带隧道
        // 权限（企业证书等）时不再查 LocalDevVPN——流程里的
        // tunnelUp() 会自己把内置隧道拉起来（首次弹一次系统
        // 许可）；签名带不了隧道（个人 ID 等）就按老规矩查
        // LocalDevVPN、缺了才提示。
        if !engine.vpnConnected {
            if !BuiltinTunnel.useBuiltinDirectly, !engine.localDevVPNInstalled {
                // sheet 正在收起时直接弹 alert 会被吞掉：先让
                // 收起提交，下一个主队列回合再弹。
                Task { @MainActor in showInstallLOCPrompt = true }
                return
            }
        }
        engine.runOneClick()
    }

    /// The button under a run's progress once it has ended.
    private var installButton: some View {
        Button(action: startInstall) { installLabel }
            // B-2 (0.9.175): not while an update-all batch runs — the
            // batch's download gaps leave `engine.isRunning` false, so
            // this button would otherwise start a second install; the
            // guard in `startInstall` is the second lock.
            .disabled(engine.batchUpdateRunning)
            .buttonStyle(PrimaryButtonStyle())
    }

    private var installLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: engine.finished ? "arrow.clockwise" : "square.and.arrow.down")
                .contentTransition(.symbolEffect(.replace))
            Text(engine.finished ? L("Reinstall") : L("Install %@", installTargetName))
        }
    }

    /// The build the Install button names, with its version when one is picked.
    private var installTargetName: String {
        let name = engine.installSource.shortName
        return engine.selectedVersion.map { "\(name) \($0.title)" } ?? name
    }

    // MARK: iOS version requirement

    /// The three requirement cards share one template: an icon, a headline,
    /// a footnote, and an optional action under the text.
    private func requirementCard(systemImage: String, tint: Color,
                                 title: String, message: String) -> some View {
        requirementCard(systemImage: systemImage, tint: tint,
                        title: title, message: message) { EmptyView() }
    }

    private func requirementCard<Extra: View>(systemImage: String, tint: Color,
                                              title: String, message: String,
                                              @ViewBuilder extra: @escaping () -> Extra) -> some View {
        PanelCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    extra()
                }
            }
        }
    }

    /// Shown when iOS is below the minimum supported version.
    private var osRequirement: some View {
        requirementCard(systemImage: "iphone.gen3.slash", tint: Theme.negative,
                        title: L("iOS %@ required", Engine.minimumTunnelOSText),
                        message: L("This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.",
                                   engine.osVersionText, Engine.minimumTunnelOSText))
    }

    // MARK: Pairing file

    /// SideStore's guide to creating a pairing file on a computer.
    private static let pairingDocsURL =
        "https://docs.sidestore.io/docs/advanced/alternative#pairing"

    /// Pairing-file import card, shown when this iPhone can't pair with itself
    /// (below iOS 27).
    private var pairingFileCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                HStack(spacing: 8) {
                    SectionTitle(title: L("Pairing file"), systemImage: "lock.doc")
                    Spacer(minLength: 4)
                    if engine.importedPairingName != nil {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(Theme.positive)
                    }
                }

                pairingImportButton
                if engine.canGetSideStorePairing {
                    orDivider
                    sideStorePairingButton
                }
                pairingDocsLink
            }
        }
        .disabled(engine.isRunning)
    }

    /// Asks SideStore for the pairing file it already has. SideStore opens and
    /// sends it back, and the import asks before replacing anything. Inside
    /// LiveContainer nothing opens: the built-in SideStore's file is read.
    private var sideStorePairingButton: some View {
        let insideLiveContainer = Engine.runsInLiveContainer
        return VStack(alignment: .leading, spacing: 6) {
            Button { CZFHaptics.impact(); engine.requestSideStorePairing() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundStyle(Theme.muted)
                    Text(L("Get it from SideStore"))
                        .foregroundStyle(.primary)
                    Spacer()
                    if !insideLiveContainer {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .fieldBackground()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain, sound: .tap)
            .disabled(engine.isImportingPairing)
            Text(insideLiveContainer
                 ? L("SideInstaller takes the pairing file LiveContainer's built-in SideStore has.")
                 : L("SideStore opens and sends back the pairing file it has."))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Link to SideStore's guide to making a pairing file.
    private var pairingDocsLink: some View {
        Button {
            if let url = URL(string: Self.pairingDocsURL) { openURL(url) }
        } label: {
            HStack(spacing: 4) {
                Text(L("How do I make one?"))
                Image(systemName: "arrow.up.right")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain, sound: .tick)
    }

    /// Import button, labelled with the imported file's name once one is in.
    private var pairingImportButton: some View {
        Button { CZFHaptics.impact(); showPairingImporter = true } label: {
            HStack(spacing: 8) {
                if engine.isImportingPairing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: engine.importedPairingName == nil
                          ? "square.and.arrow.down" : "checkmark.circle")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(engine.importedPairingName == nil ? Theme.muted : Theme.accent)
                }
                Text(engine.importedPairingName ?? L("Import pairing file"))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Spacer()
                if engine.importedPairingName != nil, !engine.isImportingPairing {
                    Text(L("Replace"))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .fieldBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain, sound: .tap)
        .disabled(engine.isImportingPairing)
    }

    // MARK: Advanced

    /// Advanced section under the Install button, collapsed until its title is
    /// tapped. Holds the build's version and, from iOS 27, the optional
    /// pairing-file import.
    private var advancedSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Button { advancedExpanded.toggle() } label: {
                    HStack(spacing: 8) {
                        SectionTitle(title: L("Advanced"), systemImage: "slider.horizontal.3")
                        Spacer(minLength: 4)
                        // Collapsed, this is the only sign an imported file is in use.
                        if engine.canSelfPair, engine.importedPairingName != nil {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(Theme.positive)
                                .transition(.opacity)
                        }
                        disclosureChevron(expanded: advancedExpanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain, sound: .tick)

                if advancedExpanded {
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        if engine.installSource != .custom {
                            versionOption
                        }
                        if engine.canSelfPair {
                            pairingFileOption
                        }
                    }
                    .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }
        }
    }

    /// Which release of the selected build to install. The list follows the
    /// channel picked above; "Latest" is the default.
    private var versionOption: some View {
        let source = engine.installSource
        let catalog = engine.releaseCatalogs[source]
        let latest = catalog?.latest[engine.selectedChannel]
        let shown = engine.selectedVersion ?? latest
        return VStack(alignment: .leading, spacing: 12) {
            Label(L("%@ version", source.shortName), systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)
            Menu {
                Picker(L("Version"), selection: Bindable(engine).selectedVersion) {
                    Text(latestLabel(latest)).tag(ReleaseVersion?.none)
                    ForEach(catalog?.others[engine.selectedChannel] ?? []) { version in
                        Text(version.menuTitle).tag(Optional(version))
                    }
                }
            } label: {
                HStack {
                    Text(engine.selectedVersion?.title ?? latestLabel(latest))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    if engine.loadingCatalog == source {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .fieldBackground()
                .contentShape(Rectangle())
            }
            // A release's title can carry the maintainers' warning ("DO NOT USE").
            if let shown, shown.hasRemark {
                Label(shown.menuTitle, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = engine.catalogErrors[source] {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Couldn't load the other versions: %@", error))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L("Try again")) {
                        Task { await engine.loadReleaseCatalog(for: source, force: true) }
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.plain, sound: .tap)
                }
            }
        }
        // Fetched when the section opens, and again for another build.
        .task(id: source) { await engine.loadReleaseCatalog(for: source) }
    }

    /// "Latest", naming the release it stands for when that has a version.
    private func latestLabel(_ latest: ReleaseVersion?) -> String {
        // The nightly tag names no version, so it isn't repeated.
        guard let latest, latest.tag != "nightly" else { return L("Latest") }
        return L("Latest (%@)", latest.title)
    }

    /// The optional pairing-file import (iOS 27 and above).
    private var pairingFileOption: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L("Pairing file"), systemImage: "lock.doc")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)
            Text(L("(Optional)"))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            pairingImportButton
            pairingDocsLink
        }
    }

    // MARK: Loopback-VPN requirement

    /// Shown while the tunnel is off. Names LocalDevVPN, though any loopback VPN
    /// works.
    private var vpnRequirement: some View {
        requirementCard(systemImage: "shield.lefthalf.filled", tint: Theme.negative,
                        title: L("LocalDevVPN required"),
                        message: L("Install LocalDevVPN and connect it. The install runs over its tunnel.")) {
            if engine.localDevVPNInstalled {
                // 装了就直接打开 LocalDevVPN 连接并自动跳回，不再去 App Store 获取
                Button { engine.startLocalDevVPN() } label: {
                    Label(L("打开 LocalDevVPN"), systemImage: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                .controlSize(.small)
                .padding(.top, 2)
            } else if let label = Guides.vpn.actionLabel, let url = Guides.vpn.actionURL {
                Button { openURL(url) } label: {
                    Label(label, systemImage: "arrow.up.right")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                .controlSize(.small)
                .padding(.top, 8)
            }
        }
    }

    // MARK: Progress + step timeline

    /// What the install surface holds as a card; `installSurface` draws the
    /// card itself.
    private var progressContent: some View {
        // 0.9.188：卡内间距走共享 token，与 appCard / advancedSection 对齐。
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            HStack(spacing: 8) {
                Text(progressTitle)
                    .font(.headline)
                    .contentTransition(.opacity)
                Spacer(minLength: 4)
                // B1 (0.9.155): total unknown — byte count instead of a
                // 0% that never moves.
                if let bytes = engine.downloadBytesWritten {
                    Text(L("%@ downloaded", ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(progressTint)
                } else {
                    Text("\(Int(engine.overallProgress * 100))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(progressTint)
                        .contentTransition(.numericText(value: engine.overallProgress))
                        .animation(.smooth(duration: 0.3), value: engine.overallProgress)
                }
                stepsDisclosure
                // Only a run in flight can be cancelled.
                if engine.isRunning {
                    cancelButton
                        .transition(.opacity)
                }
            }

            // F-2 (0.9.157): the download's speed and time left, in the
            // source rows' second-line shape, while the download step runs.
            if let detail = downloadDetailLine {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            if engine.downloadBytesWritten != nil {
                ProgressView()
                    .tint(progressTint)
            } else {
                InstallProgressBar(progress: engine.overallProgress, tint: progressTint)
            }

            stepSection

            // C7: a download that fell back to an older local copy says so
            // here, under the card, until the next run clears it.
            if let notice = engine.downloadFallbackNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            // C25：配对/证书交接失败的提示（Engine.handOffNotice），与 C7
            // 的 downloadFallbackNotice 并列显示在进度卡下方。
            if let notice = engine.handOffNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var progressTitle: String {
        if engine.finished { return L("Installed") }
        // B-5：取消安装不是立刻停——要等设备上正在跑的安装收尾，
        // 文案说清在等，别让用户以为点取消没反应。
        return engine.isCancelling ? L("Waiting for this install to finish…") : L("Installing")
    }

    /// F-2 (0.9.157): the download step's speed / bytes / time left, in
    /// the source rows' second-line shape. Nil until two samples arrive,
    /// or once the download step is over (the speed is cleared then).
    private var downloadDetailLine: String? {
        guard engine.downloadSpeed > 0 else { return nil }
        let speed = L("%@/s", ByteCountFormatter.string(fromByteCount: Int64(engine.downloadSpeed), countStyle: .file))
        if engine.downloadTotalBytes > 0 {
            let bytes = Int64(engine.downloadProgress * Double(engine.downloadTotalBytes))
            let of = L("%@ of %@",
                       ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file),
                       ByteCountFormatter.string(fromByteCount: engine.downloadTotalBytes, countStyle: .file))
            if let eta = engine.estimatedTimeRemaining {
                return "\(speed) • \(of) • \(L("%@ left", Self.etaText(eta)))"
            }
            return "\(speed) • \(of)"
        }
        if let bytes = engine.downloadBytesWritten {
            return "\(speed) • \(L("%@ downloaded", ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)))"
        }
        return speed
    }

    /// "3:42", or "1:12:33" past the hour, for a remaining-time estimate —
    /// the source rows' shape (SourcesView.etaText).
    private static func etaText(_ eta: TimeInterval) -> String {
        let total = Int(eta.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// The X in the card's corner, which stops the run after asking. It dims
    /// once the run is stopping, which waits for the step in flight.
    private var cancelButton: some View {
        IconCircleButton(systemImage: "xmark") {
            CZFHaptics.impact()
            confirmingCancel = true
        }
        .disabled(engine.isCancelling)
        .opacity(engine.isCancelling ? 0.4 : 1)
        .accessibilityLabel(L("Cancel"))
    }

    /// Progress color: red on failure, green when finished, the blue while
    /// running.
    private var progressTint: Color {
        if runFailed { return Theme.negative }
        return engine.finished ? Theme.positive : Theme.accent
    }

    /// Chevron that expands/collapses the step timeline. Placed in the header so
    /// it stays put in both states.
    private var stepsDisclosure: some View {
        Button {
            stepsExpanded.toggle()
        } label: {
            disclosureChevron(expanded: stepsExpanded)
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain, sound: .tick)
        .accessibilityLabel(stepsExpanded ? L("Show fewer steps") : L("Show all steps"))
    }

    /// Circled chevron that flips to point up while its section is open.
    private func disclosureChevron(expanded: Bool) -> some View {
        Image(systemName: "chevron.down")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.muted)
            .rotationEffect(.degrees(expanded ? 180 : 0))
            .frame(width: 28, height: 28)
            .background(Circle().fill(Theme.control))
    }

    // MARK: Step timeline

    /// The checklist, collapsed to the step in flight until it is opened.
    private var stepSection: some View {
        VStack(spacing: 0) {
            if stepsExpanded {
                ForEach(Array(Step.allCases.enumerated()), id: \.element) { idx, step in
                    // Resolved here so the row redraws on a language change.
                    StepRow(step: step,
                            title: step.title(for: engine.installSource),
                            state: engine.stepStates[step] ?? .pending,
                            installProgress: engine.installProgress,
                            isLast: idx == Step.allCases.count - 1,
                            waitingForPairingPort: engine.waitingForPairingPort)
                        // Staggered, so opening the list reads as it unrolling.
                        .cascadeItem(idx)
                }
            } else {
                collapsedStepRow
            }
        }
        .animation(.smooth(duration: 0.38), value: stepsExpanded)
    }

    /// Collapsed timeline: the current step, pushed out when the next one starts.
    /// Tap to expand.
    private var collapsedStepRow: some View {
        let step = currentStep
        return ZStack {
            CurrentStepRow(step: step,
                           title: step.title(for: engine.installSource),
                           state: engine.stepStates[step] ?? .pending,
                           installProgress: engine.installProgress,
                           index: (Step.allCases.firstIndex(of: step) ?? 0) + 1,
                           total: Step.allCases.count,
                           waitingForPairingPort: engine.waitingForPairingPort)
                .id(step)
                .transition(.push(from: .bottom))
        }
        // Fixed, so the card doesn't breathe as one row replaces another.
        .frame(height: 44)
        // Clipped for the push transition.
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { stepsExpanded = true }
        .animation(.smooth(duration: 0.35), value: step)
    }

    // MARK: Helpers
    // 0.9.188：本地 sectionTitle 已并入 Theme SectionTitle（原来只是
    // 一层透传），调用处直接用 SectionTitle。
}

// MARK: - Pre-install checklist

/// 点安装前一屏的检查清单（v0.9.19）：Wi-Fi、隧道、配对文件、
/// 签名身份（Apple ID）、安装包（仅自定义 IPA）逐项列出来，
/// 缺啥直接指出来。只做提醒，不拦安装：点“继续安装”后，
/// 原有隧道门禁与 runOneClick 自己的门禁照常跑。
/// 行读的都是 engine 的实时状态，行内修复（启动隧道、
/// 导入配对文件/安装包）做完行自己变绿，不用重开清单。
/// 清单各行的状态判定：PrecheckSheet 各行与 startInstall 共用同一套，
/// 行里只按这个状态分叉，startInstall 只凭它决定弹不弹清单。
/// 各行说明文字/修复按钮的明细选择仍在行里，不影响状态。
private func wifiPrecheckState(_ engine: Engine) -> PrecheckState {
    if engine.wifiConnected { return .ok }
    if engine.needsFreshPairing, engine.canSelfPair { return .blocked }
    return .na
}

private func tunnelPrecheckState(_ engine: Engine) -> PrecheckState {
    if engine.vpnConnected { return .ok }
    if engine.tunnelAvailable { return .warn }
    return .blocked
}

private func pairingPrecheckState(_ engine: Engine) -> PrecheckState {
    if engine.canSelfPair { return .ok }
    if engine.importedPairingName != nil { return .ok }
    if engine.hasPairingFile { return .ok }
    return .blocked
}

private func accountPrecheckState(_ engine: Engine) -> PrecheckState {
    if !engine.normalizedAppleID.isEmpty, !engine.applePassword.isEmpty { return .ok }
    return .blocked
}

private func packagePrecheckState(_ engine: Engine) -> PrecheckState {
    if engine.customIPAName != nil { return .ok }
    return .blocked
}

/// 任一行红（blocked）即弹清单；安装包行只在自定义 IPA 时才算
///（sheet 里本来也只在自定义 IPA 时才渲染这一行）。
private func precheckHasBlocked(_ engine: Engine) -> Bool {
    if wifiPrecheckState(engine) == .blocked { return true }
    if tunnelPrecheckState(engine) == .blocked { return true }
    if pairingPrecheckState(engine) == .blocked { return true }
    if accountPrecheckState(engine) == .blocked { return true }
    if engine.installSource == .custom, packagePrecheckState(engine) == .blocked { return true }
    return false
}

private struct PrecheckSheet: View {
    @Environment(Engine.self) private var engine: Engine
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void
    /// P0-5 (0.9.185): the custom IPA's paid-only capabilities, if any
    /// (nil = no custom IPA / not computed yet). Computed once per
    /// imported IPA by ContentView's task on appCard.
    let missingCapabilities: [String]?

    @State private var showPairingPicker = false
    @State private var showIPAPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("绿的是已齐，红的是缺了会卡住，橙的是安装时会自动启动；行内能修的直接点右边的按钮。"))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    wifiRow
                    tunnelRow
                    pairingRow
                    accountRow
                    if engine.installSource == .custom {
                        packageRow
                    }
                    if engine.installSource == .custom, let missing = missingCapabilities {
                        capabilitiesRow(missing: missing)
                    }
                    VStack(spacing: 10) {
                        Button(action: onContinue) {
                            Text(L("继续安装"))
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button(L("Cancel")) { CZFHaptics.impact(); dismiss() }
                            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle(L("安装前检查"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPairingPicker) {
                FileImporterRepresentableView(allowedContentTypes: UTType.pairingFileTypes) { urls in
                    guard let url = urls.first else { return }   // empty means cancelled
                    Task { await engine.importPairingFile(from: url) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showIPAPicker) {
                FileImporterRepresentableView(allowedContentTypes: [.ipa]) { urls in
                    guard let url = urls.first else { return }   // empty means cancelled
                    Task { _ = await engine.importCustomIPA(from: url) }
                }
                .ignoresSafeArea()
            }
        }
    }

    /// Wi-Fi 只在本次要自配对时才阻塞：已有配对文件、
    /// 或本机不能自配对（走文件导入）时都不需要 Wi-Fi。
    @ViewBuilder
    private var wifiRow: some View {
        if wifiPrecheckState(engine) == .ok {
            precheckRow(title: L("Wi-Fi"), state: .ok, detail: L("connected"))
        } else if wifiPrecheckState(engine) == .blocked {
            precheckRow(title: L("Wi-Fi"), state: .blocked, detail: L("未连接——本次配对需要 Wi-Fi"))
        } else {
            precheckRow(title: L("Wi-Fi"), state: .na, detail: L("不需要 Wi-Fi"))
        }
    }

    /// 隧道：已连绿；未连但安装时会启动橙（行内可先拉起）；
    /// 未连且不会启动红（LOC 装了可直接打开，没装则点
    /// 继续安装时会弹安装提示）。
    @ViewBuilder
    private var tunnelRow: some View {
        if tunnelPrecheckState(engine) == .ok {
            precheckRow(title: L("Tunnel"), state: .ok, detail: L("connected"))
        } else if tunnelPrecheckState(engine) == .warn {
            if BuiltinTunnel.useBuiltinDirectly || engine.localDevVPNInstalled {
                precheckRow(title: L("Tunnel"), state: .warn, detail: L("未连接，安装时自动启动"),
                            fixTitle: L("立即启动"), fix: startTunnel)
            } else {
                precheckRow(title: L("Tunnel"), state: .warn, detail: L("未连接，安装时自动启动（需先装 LocalDevVPN）"))
            }
        } else if engine.localDevVPNInstalled {
            precheckRow(title: L("Tunnel"), state: .blocked, detail: L("未连接，且不会自动启动"),
                        fixTitle: L("打开 LocalDevVPN"), fix: { engine.startLocalDevVPN() })
        } else {
            precheckRow(title: L("Tunnel"), state: .blocked, detail: L("未连接，且不会自动启动——点继续安装时会提示安装 LocalDevVPN"))
        }
    }

    /// 配对文件：本机能自配对就不需要；否则以磁盘上的
    /// 文件为准（名字没记下来也算已导入）。
    @ViewBuilder
    private var pairingRow: some View {
        if pairingPrecheckState(engine) == .blocked {
            precheckRow(title: L("Pairing file"), state: .blocked, detail: L("未导入"),
                        fixTitle: L("Import pairing file"), fix: { showPairingPicker = true })
        } else if engine.canSelfPair {
            precheckRow(title: L("Pairing file"), state: .ok, detail: L("本机可自配对，不需要文件"))
        } else if let name = engine.importedPairingName {
            precheckRow(title: L("Pairing file"), state: .ok, detail: L("已导入：%@", name))
        } else {
            precheckRow(title: L("Pairing file"), state: .ok, detail: L("imported pairing file"))
        }
    }

    /// 签名身份对应 runOneClick 的 Apple ID + 密码门禁，
    /// 不是证书页的企业证书（企业安装不走这条路，故不列入）。
    @ViewBuilder
    private var accountRow: some View {
        if accountPrecheckState(engine) == .ok {
            precheckRow(title: L("Apple ID（签名身份）"), state: .ok, detail: engine.normalizedAppleID)
        } else {
            precheckRow(title: L("Apple ID（签名身份）"), state: .blocked, detail: L("去设置页登录 Apple ID 并填好密码"))
        }
    }

    /// 仅自定义 IPA 有这一行，对应 runOneClick 的已导入门禁。
    @ViewBuilder
    private var packageRow: some View {
        if packagePrecheckState(engine) == .ok, let name = engine.customIPAName {
            precheckRow(title: L("安装包"), state: .ok, detail: name)
        } else {
            precheckRow(title: L("安装包"), state: .blocked, detail: L("还没导入 .ipa"),
                        fixTitle: L("导入安装包"), fix: { showIPAPicker = true })
        }
    }

    /// P0-5 (0.9.185): the custom IPA's paid-only capabilities as a
    /// checklist row — warn, never blocked (0.9.160's "warn, don't
    /// block" kept). The ok state says the free certificate covers
    /// everything, so the sheet doesn't leave the question open.
    private func capabilitiesRow(missing: [String]) -> some View {
        if missing.isEmpty {
            precheckRow(title: L("Capabilities"), state: .ok, detail: L("免费证书都支持"))
        } else {
            precheckRow(title: L("Capabilities"), state: .warn,
                        detail: L("This IPA asks for %@, which a free Apple ID certificate can't provide. Those features will silently stop working after install.", missing.joined(separator: ", ")))
        }
    }

    /// 行内启动隧道：跟 pill 点按同一路（内置直拉，
    /// 否则交接 LOC）；两样都没有时本行不给修复按钮。
    private func startTunnel() {
        if BuiltinTunnel.useBuiltinDirectly {
            Task { _ = await engine.tunnelUp() }
        } else if engine.localDevVPNInstalled {
            engine.startLocalDevVPN()
        }
    }
}

/// 检查清单一行的状态：绿已齐、橙安装时自动启动、
/// 红缺了会卡住、灰不需要。
private enum PrecheckState {
    case ok, warn, blocked, na

    var systemImage: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.circle.fill"
        case .blocked: return "xmark.circle.fill"
        case .na: return "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .ok: return Theme.positive
        case .warn: return Theme.warning
        case .blocked: return Theme.negative
        case .na: return .secondary
        }
    }
}

/// 检查清单的一行：状态色 + 标题 + 说明，右边可选一个修复按钮。
/// 单一 PanelCard 表达式，行内 if 只在 HStack 的 ViewBuilder 里，
/// 不触发普通函数多类型分支问题。
private func precheckRow(title: String, state: PrecheckState, detail: String,
                         fixTitle: String? = nil, fix: (() -> Void)? = nil) -> some View {
    PanelCard {
        HStack(spacing: 12) {
            Image(systemName: state.systemImage)
                .foregroundStyle(state.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let fixTitle, let fix {
                Button(fixTitle) { CZFHaptics.impact(); fix() }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Popup

/// One of the Install tab's popups, which `RootView` stacks over the whole app:
/// what a waiting step needs (Wi-Fi, the tunnel, the pairing code), a guide for
/// a run that couldn't start, or how the run ended. See `Engine.Popup`.
struct InstallPopup: View {
    let popup: Engine.Popup

    @Environment(Engine.self) private var engine
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// Shared with the Certificates page; revoke-and-retry runs through it.
    @EnvironmentObject private var certManager: CertManager
    @Environment(\.openURL) private var openURL
    /// Shows the dialog for choosing which certificate to revoke.
    @State private var showRevokeChooser = false
    /// Shows the Report a problem sheet from the error popup.
    @State private var showReport = false

    var body: some View {
        switch popup {
        case .pairingCode(let pin):
            PairingCodePopup(pin: pin, caption: L("Type this into the prompt in Settings."),
                             onClose: close)
        case .certConflict:
            certConflictPopup
        case .guide(let guide):
            guidePopup(guide)
        case .error(let message, let stoppedRun):
            PopupCard(title: Self.errorTitle(stoppedRun: stoppedRun),
                      systemImage: "exclamationmark.triangle",
                      tint: Theme.negative,
                      onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(message)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { errorButtons(message) }
                        VStack(alignment: .leading, spacing: 12) { errorButtons(message) }
                    }
                }
            }
            .sheet(isPresented: $showReport) { ReportProblemView() }
        case .success(let name, let leads):
            PopupCard(title: L("Installed"), systemImage: "checkmark.seal", tint: Theme.positive,
                      onClose: close) {
                Text(leads ? L("%@ is installed. Finish the trust step below to open it.", name)
                           : L("%@ is installed. Finish the trust step above to open it.", name))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .liveContainerImport:
            guidePopup(Guides.liveContainerImport)
        case .appIDCost(let cost):
            appIDCostPopup(cost)
        case .pairingImportMismatch(let mismatch):
            PopupCard(title: L("Pairing file for another iPhone"), systemImage: "lock.iphone",
                      tint: Theme.accent, onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("This pairing file belongs to another iPhone (UDID %@). The iPhone connected now is %@.",
                           mismatch.fileUDID, mismatch.deviceUDID))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 12) {
                        Button { engine.answerPairingImportMismatch(true) } label: {
                            Text(L("Replace"))
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button(role: .cancel) { engine.answerPairingImportMismatch(false) } label: {
                            Text(L("Cancel"))
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    }
                }
            }
        case .cellularDownload(let request):
            // F-G (0.9.156): the "Wi-Fi only downloads" prompt — what it is,
            // how big (or that the size is unknown), and that it will use
            // mobile data. Download goes ahead; Cancel, or the X, stops it.
            PopupCard(title: L("Download over cellular?"), systemImage: "cellularbars",
                      tint: Theme.warning, onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(request.what)
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(request.size.map {
                        L("Size: %@", ByteCountFormatter.string(fromByteCount: $0, countStyle: .file))
                    } ?? L("Size unknown"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("You're on cellular data. This download will use your mobile data."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 12) {
                        Button { engine.answerCellularDownload(true) } label: {
                            Label(L("Download"), systemImage: "arrow.down.app")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button(role: .cancel) { engine.answerCellularDownload(false) } label: {
                            Text(L("Cancel"))
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    }
                }
            }
        case .downgrade(let request):
            // F-2 (0.9.159): the "older than what's installed" prompt — the
            // two versions, and the same warning the Sources page gives:
            // the older copy may not open data the newer one saved. Install
            // goes ahead; Cancel, or the X, stops the run.
            PopupCard(title: L("Install an older version?"), systemImage: "arrow.down.circle",
                      tint: Theme.warning, onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(request.appName)
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("Installed: %@ · This IPA: %@", request.installedVersion, request.ipaVersion))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("This version is older than the one on this iPhone (%@). Installed over it, it may not open data the newer version saved.", request.installedVersion))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 12) {
                        Button { engine.answerDowngrade(true) } label: {
                            Label(L("Install"), systemImage: "arrow.down.app")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button(role: .cancel) { engine.answerDowngrade(false) } label: {
                            Text(L("Cancel"))
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    }
                }
            }
        case .link(let link):
            linkPopup(link)
        }
    }

    private func close() { engine.closePopup(popup) }

    /// The error popup's buttons. Copy logs shows only when nothing explains
    /// the fix: no guide or revoke-and-retry popup beside it, and a message
    /// that doesn't say what to do itself.
    @ViewBuilder
    private func errorButtons(_ message: String) -> some View {
        Button { showReport = true } label: {
            Label(L("Report this problem"), systemImage: "exclamationmark.bubble")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
        // P0-2 (0.9.185): the failure is no longer a dead end. "View
        // log" closes this popup and jumps to the activity log
        // (RootView closes the install sheet, switches to Settings
        // and scrolls to the log); "Try again" re-runs the same
        // install — runOneClick clears lastError itself, so the
        // popup goes away on success and re-renders on a new failure.
        Button {
            close()
            NotificationCenter.default.post(name: Engine.revealLog, object: nil)
        } label: {
            Label(L("查看日志"), systemImage: "doc.text.magnifyingglass")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
        Button {
            engine.runOneClick()
        } label: {
            Label(L("Try again"), systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
        .disabled(engine.isRunning)
        if engine.guide == nil, !engine.certConflict, !ErrorHelp.isExplained(message) {
            CopyLogsButton()
        }
    }
    /// The App ID cost popup, restored from upstream (2026-10-25 merge
    /// recovery): the fork's Engine never sets `appIDCost`, so this only
    /// renders if a future wiring does.
    private func appIDCostPopup(_ cost: AppIDCost) -> some View {
        PopupCard(title: L("App IDs for this app"), systemImage: "number.square",
                  tint: cost.isAffordable ? Theme.accent : Theme.warning,
                  onClose: close) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    appIDTile(L("Cost"), "\(cost.cost)", tint: cost.isAffordable ? .primary : Theme.warning)
                    appIDTile(L("Left now"), cost.available.map { "\($0)" } ?? "–", tint: .primary)
                    appIDTile(L("Left after"),
                              cost.isAffordable ? cost.remainingAfter.map { "\($0)" } ?? "–" : "–",
                              tint: .primary)
                }
                Text(appIDCostMessage(cost))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !cost.newIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("New App IDs"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.muted)
                        ForEach(cost.newIDs, id: \.self) { id in
                            Text(id)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                VStack(spacing: 12) {
                    if cost.isAffordable {
                        Button { engine.answerAppIDCost(true) } label: {
                            Label(L("Install"), systemImage: "arrow.down.app")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    Button(role: .cancel) { engine.answerAppIDCost(false) } label: {
                        Text(L("Cancel"))
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: cost.isAffordable ? nil : Theme.warning),
                                 sound: .tap)
                }
            }
        }
    }

    /// One number in the App ID cost popup, with what it counts.
    private func appIDTile(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.medium).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
            .fill(Theme.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
            .strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func appIDCostMessage(_ cost: AppIDCost) -> String {
        guard cost.isAffordable else {
            var text = L("This Apple ID doesn't have enough App IDs left: this app needs %d, and %d are left. Each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.",
                         cost.cost, cost.available ?? 0)
            if let next = cost.nextExpiry {
                let when = next.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)
                    .locale(Localizer.locale))
                text += " " + L("The next one frees up on %@.", when)
            }
            return text
        }
        if cost.cost == 0 {
            return L("Your Apple ID already has every App ID this app needs, so installing it uses none.")
        }
        let base = L("Signing registers one App ID for the app, and its extensions share it. It counts for 7 days.")
        guard let limit = cost.limit else { return base }
        return base + " " + L("This Apple ID can register %d a week.", limit)
    }

    /// The error popup's title, which also titles the group it's in.
    static func errorTitle(stoppedRun: Bool) -> String {
        stoppedRun ? L("Install stopped") : L("Something went wrong")
    }

    // MARK: Guides

    /// A guide's steps, and its link out when it has one.
    private func guidePopup(_ guide: Guide) -> some View {
        PopupCard(title: guide.title, systemImage: guide.systemImage, tint: Theme.accent,
                  onClose: close) {
            VStack(alignment: .leading, spacing: 14) {
                NumberedSteps(steps: guide.steps)
                if let label = guide.actionLabel, let url = guide.actionURL {
                    Button { openURL(url) } label: {
                        Label(label, systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                }
            }
        }
    }

    // 必须带 @ViewBuilder（2026-10-29 构建 #47 血泪）：三个分支
    // 各返回一种 PopupCard，plain 的 some View 只能是一种类型，
    // 没它编译报 conflicting arguments to generic parameter。
    // body 能编是因为 View 协议的 body 自带 @ViewBuilder，普通
    // 函数没有，得自己加。
    @ViewBuilder
    private func linkPopup(_ link: DeepLink) -> some View {
        switch link {
        case .install(let url):
            PopupCard(title: L("Install from a link?"), systemImage: "link",
                      tint: Theme.accent, onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(url.host ?? url.absoluteString)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(url.absoluteString)
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.muted)
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    Text(installLinkMessage)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    linkButtons(L("Download and install"), systemImage: "arrow.down.app")
                }
            }
        case .pairingFile(let file):
            PopupCard(title: file.fromSideStore ? L("Use SideStore's pairing file?")
                                                : L("Import this pairing file?"),
                      systemImage: "lock.doc", tint: Theme.accent, onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    if let udid = file.kind.udid {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("UDID")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.muted)
                            Text(udid)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Text(pairingLinkMessage(file))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    linkButtons(L("Import"), systemImage: "square.and.arrow.down")
                }
            }
        case .certificate:
            // Only an unasked-for one asks here; SideStore's reply is imported
            // straight away.
            PopupCard(title: L("Sign with this certificate?"), systemImage: "checkmark.seal",
                      tint: Theme.accent, onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("A link sent SideInstaller a signing certificate. Only use it if you asked for one: SideInstaller will sign apps with it from now on, in place of its own. It's used only if it's one of your Apple ID's certificates."))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    linkButtons(L("Use it"), systemImage: "checkmark.seal")
                }
            }
        }
    }

    /// The link popup's go-ahead and Cancel.
    private func linkButtons(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Button { engine.answerLink(true) } label: {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(PrimaryButtonStyle())
            Button(role: .cancel) { engine.answerLink(false) } label: {
                Text(L("Cancel"))
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
        }
    }

    private var installLinkMessage: String {
        let base = L("SideInstaller will download this .ipa, then sign it with your Apple ID and install it. Only go ahead if you trust where the link came from.")
        guard let current = engine.customIPAName else { return base }
        return base + " " + L("It replaces %@, the custom .ipa you have now.", current)
    }

    private func pairingLinkMessage(_ file: LinkedPairingFile) -> String {
        let base: String
        if !file.fromSideStore {
            base = L("A link sent SideInstaller a pairing file. Only import it if you asked for one: SideInstaller will connect to this iPhone with it.")
        } else if Engine.runsInLiveContainer {
            // SideStore's reply can't get there, so it's the file read from
            // the built-in SideStore.
            base = L("This is the pairing file LiveContainer's built-in SideStore has. SideInstaller will connect to this iPhone with it.")
        } else {
            base = L("SideStore sent back the pairing file it has. SideInstaller will connect to this iPhone with it.")
        }
        if let current = engine.importedPairingName {
            return base + " " + L("It replaces %@.", current)
        }
        return engine.hasPairingFile ? base + " " + L("It replaces the pairing file in use now.") : base
    }

    // MARK: Certificate conflict (Apple error 7460)

    /// Shown on error 7460. With SideStore's certificate to be had, the first
    /// button gets it (from SideStore, or inside LiveContainer from
    /// LiveContainer), signs with that and retries the install. The other
    /// loads the certificates; the dialog asks which one to revoke, then
    /// retries the install.
    private var certConflictPopup: some View {
        let sideStoreCertificate = engine.canUseSideStoreCertificate
        return PopupCard(title: L("A certificate already exists"),
                         systemImage: "exclamationmark.shield",
                         tint: Theme.warning,
                         onClose: close) {
            VStack(alignment: .leading, spacing: 16) {
                Text(sideStoreCertificate
                     ? L("Apple won't issue a second signing certificate for this Apple ID. If SideStore made the one it has, SideInstaller can sign with that one too, and nothing is revoked. Revoking it lets the install continue as well — but it can't be undone.")
                     : L("Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone."))
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if sideStoreCertificate {
                    Button {
                        certManager.requestSideStoreCertificate(retryInstall: true)
                    } label: {
                        HStack(spacing: 8) {
                            if certManager.isImporting {
                                ProgressView()
                                Text(L("Checking the certificate"))
                            } else {
                                Image(systemName: "checkmark.seal")
                                Text(L("Use SideStore's certificate"))
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(certManager.isBusy)
                }
                Button {
                    // Load first, so the chooser can name the certificates.
                    certManager.ensureLoaded { showRevokeChooser = true }
                } label: {
                    HStack(spacing: 8) {
                        if certManager.isWorking {
                            ProgressView().controlSize(.small)
                            Text(L("Loading certificates"))
                        } else {
                            Image(systemName: "arrow.clockwise.circle")
                            Text(L("Revoke and retry"))
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.warning), sound: .tap)
                .disabled(certManager.isBusy)
                // A failed load, revoke or import shows as the Certificates
                // popup, under this one.
            }
            .animation(.smooth(duration: 0.3), value: certManager.isWorking)
        }
        .confirmationDialog(L("Which certificate should be revoked?"),
                            isPresented: $showRevokeChooser,
                            titleVisibility: .visible) {
            ForEach(certManager.certs) { cert in
                Button(revokeButtonLabel(for: cert), role: .destructive) {
                    certManager.revoke(cert) {
                        engine.log("Retrying the install after revoking \(cert.displayName).")
                        // B-3 (0.9.177): the revoke takes seconds, so a
                        // batch can have started after the tap — check
                        // the slot here, at the callback, not at the
                        // tap. A running batch keeps the popup up and
                        // the reason on the page; the user can retry
                        // once the batch is done.
                        if engine.batchUpdateRunning {
                            engine.lastError = L("全部更新进行中，等它跑完再安装。")
                            return
                        }
                        engine.runOneClick()
                    }
                }
            }
            Button(L("Cancel"), role: .cancel) { }
        } message: {
            Text(certManager.certs.isEmpty
                 ? L("Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.")
                 : L("Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards."))
        }
    }

    /// Names a certificate in the chooser, with its machine and expiry.
    private func revokeButtonLabel(for cert: DevCert) -> String {
        var label = cert.displayName
        if let machine = cert.machineLabel { label += " — \(machine)" }
        if cert.isExpired { label += L(" (expired)") }
        return label
    }
}

// MARK: - Toolbar

extension View {
    /// The gear button that opens Settings, shared by every screen.
    func settingsToolbarItem(isPresented: Binding<Bool>) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isPresented.wrappedValue = true } label: {
                Image(systemName: "gearshape")
            }
            // 全站蓝（Theme.accent）：indigo 是旧工具页设置行的颜色，
            // 工具页已删（0.9.102），全仓只剩这一处 indigo，与顶栏/
            // 按钮/链接的蓝色不合；本 helper 全 App 共用，改色即全页同色。
            .tint(Theme.accent)
        }
    }
}

// MARK: - Install surface

private extension AnyTransition {
    /// Content changing places inside a surface that is changing shape: the old
    /// is all but gone before the new comes in, so the two don't show through
    /// each other.
    static var surfaceSwap: AnyTransition {
        .asymmetric(insertion: .opacity.animation(.easeIn(duration: 0.28).delay(0.1)),
                    removal: .opacity.animation(.easeOut(duration: 0.15)))
    }

    /// A fade that's over before what's below has moved up into its place.
    static var quickFade: AnyTransition {
        .opacity.animation(.easeOut(duration: 0.12))
    }

    /// The Install button leaving as a run starts: up and under the progress
    /// card above it.
    static var tuckUnder: AnyTransition {
        .opacity
            .combined(with: .scale(scale: 0.94, anchor: .top))
            .combined(with: .offset(y: -28))
            // Gone before what's below has moved up into its place.
            .animation(.easeOut(duration: 0.22))
    }
}

// MARK: - Progress bar

/// Install progress bar: one solid fill on a quiet track, growing as the run
/// goes. Side by Side shows its runs with it too.
struct InstallProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let full = geo.size.width
            // Minimum width so the bar is visible at 0%.
            let filled = max(8, full * min(max(progress, 0), 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.control)
                Capsule()
                    .fill(tint)
                    .frame(width: filled)
                    .animation(.smooth(duration: 0.45), value: filled)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Step row

/// One row of the install timeline: a status node, the title, and a badge.
private struct StepRow: View {
    let step: Step
    let title: String
    let state: StepState
    let installProgress: Double
    let isLast: Bool
    let waitingForPairingPort: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timelineColumn
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(state == .pending ? Theme.muted : .primary)
                    Spacer()
                    StepBadge(step: step, state: state, installProgress: installProgress,
                              waitingForPairingPort: waitingForPairingPort)
                }
                .frame(minHeight: 24)
                if !isLast { Spacer(minLength: 12) }
            }
        }
        .frame(minHeight: 44, alignment: .top)
        .animation(.smooth(duration: 0.3), value: state)
    }

    /// The node plus the line that runs down to the next node.
    private var timelineColumn: some View {
        VStack(spacing: 0) {
            StepNode(state: state)
            if !isLast {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 24)
    }
}

// MARK: - Collapsed step row

/// What the timeline shows when it is closed: the step in flight, its place in
/// the run, and the same badge the full row would carry.
private struct CurrentStepRow: View {
    let step: Step
    let title: String
    let state: StepState
    let installProgress: Double
    let index: Int
    let total: Int
    let waitingForPairingPort: Bool

    var body: some View {
        HStack(spacing: 12) {
            StepNode(state: state)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(L("Step %@ of %@", "\(index)", "\(total)"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            StepBadge(step: step, state: state, installProgress: installProgress,
                      waitingForPairingPort: waitingForPairingPort)
        }
        .animation(.smooth(duration: 0.3), value: state)
    }
}

// MARK: - Step parts

/// Status mark for a step, used by both timelines and by Side by Side's: an
/// empty ring while it waits its turn, the system spinner while it runs, and
/// a check, a cross or a hand once it has an outcome.
struct StepNode: View {
    let state: StepState

    var body: some View {
        ZStack {
            Circle().fill(fill)
            Circle().strokeBorder(stroke, lineWidth: 1)
            icon
        }
        .frame(width: 24, height: 24)
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .active:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
                .transition(.opacity)
        case .pending:
            EmptyView()
        default:
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
                .transition(.opacity)
        }
    }

    private var iconName: String {
        switch state {
        case .waiting: "hand.tap"
        case .failed:  "xmark"
        default:       "checkmark"
        }
    }

    /// The mark's colour. A finished step is quiet, so the one in flight and
    /// one that needs the user stand out.
    private var color: Color {
        switch state {
        case .failed:  Theme.negative
        case .waiting: Theme.warning
        default:       .secondary
        }
    }

    private var fill: Color {
        switch state {
        case .done:            Theme.control
        case .failed, .waiting: color.opacity(0.14)
        case .pending:         Theme.muted.opacity(0.08)
        default:               .clear
        }
    }

    private var stroke: Color {
        switch state {
        case .pending: Theme.muted.opacity(0.5)
        case .active:  Theme.accent
        case .done:    Theme.hairline
        default:       color.opacity(0.4)
        }
    }
}

/// The right-hand side of a step: how far the install has got, or a call for
/// the user to do something.
private struct StepBadge: View {
    let step: Step
    let state: StepState
    let installProgress: Double
    let waitingForPairingPort: Bool

    var body: some View {
        if step == .install, state == .active {
            Text("\(Int(installProgress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText(value: installProgress))
                .animation(.smooth(duration: 0.3), value: installProgress)
                .transition(.opacity)
        } else if state == .active, waitingForPairingPort, step == .connect || step == .sign {
            // L2 (0.9.195): the first refused probe waits up to 30 s for the
            // listener — say so in the badge instead of looking stuck on a
            // spinner. The L4a pre-sign re-dial waits the same way, on the
            // sign step's row (its step is marked active before the re-dial).
            Text(L("Waiting for the device pairing port…"))
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.accent)
                .transition(.opacity)
        } else if step == .sign, state == .active {
            // C6: signing takes a while with no percentage to show — say so
            // in the badge, where the install step shows its own percent.
            Text(L("正在签名，请稍候…"))
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.accent)
                .transition(.opacity)
        } else if state == .waiting {
            Text(L("Action needed"))
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.warning)
                .transition(.opacity)
        }
    }
}

// MARK: - File picker

extension UTType {
    /// The `.ipa` type exported in Info.plist. Without that declaration the
    /// picker shows .ipa files but won't let them be selected.
    static let ipa: UTType = UTType(filenameExtension: "ipa") ?? .data

    /// The `.mobiledevicepairing` type written by jitterbugpair, declared the
    /// same way.
    static let mobileDevicePairing: UTType = UTType(filenameExtension: "mobiledevicepairing") ?? .data

    /// What the pairing-file picker accepts: jitterbugpair's extension, and the
    /// plain `.plist` pymobiledevice3 and idevicepair write.
    static var pairingFileTypes: [UTType] { [mobileDevicePairing, .propertyList, .xml] }
}

/// `UIDocumentPickerViewController` wrapped for SwiftUI and shown as a sheet
/// (as Feather does). Used instead of `.fileImporter`, whose rows can't be
/// tapped on iOS 27.
///
/// `asCopy: true` makes iOS hand over a temporary copy of the file instead of a
/// security-scoped URL to the original.
struct FileImporterRepresentableView: UIViewControllerRepresentable {
    var allowedContentTypes: [UTType]
    var allowsMultipleSelection = false
    var onDocumentsPicked: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentsPicked: onDocumentsPicked)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes,
                                                    asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowsMultipleSelection
        // An `.ipa` is told apart by its extension, so show it.
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onDocumentsPicked: ([URL]) -> Void

        init(onDocumentsPicked: @escaping ([URL]) -> Void) {
            self.onDocumentsPicked = onDocumentsPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            onDocumentsPicked(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDocumentsPicked([])
        }
    }
}

// MARK: - App icons

extension InstallSource {
    /// The app's own icon in the asset catalog: the official SideStore,
    /// LiveContainer, Madeira and AltStore icons from their repositories
    /// (AGPL-3.0 and GPL-3.0), at 256 px. Nil for a custom IPA.
    var iconImage: String? {
        switch self {
        case .sideStore:     return "SideStoreLogo"
        case .liveContainer: return "LiveContainerLogo"
        case .madeira:       return "MadeiraLogo"
        case .altStore:      return "AltStoreLogo"
        case .custom:        return nil
        }
    }

    /// The symbol on a custom IPA's plain tile, which has no icon to show.
    var iconSymbol: String { "app.dashed" }
}

/// An app's tile on the Install tab: its own icon, in its own colours so each
/// app is easy to tell apart, or a symbol on a plain tile for a custom IPA.
struct AppIconTile: View {
    let source: InstallSource
    var side: CGFloat = 28

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: side * 23 / 86, style: .continuous)
        Group {
            if let image = source.iconImage {
                Image(image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Theme.raised)
                    Image(systemName: source.iconSymbol)
                        .font(.system(size: side * 0.5, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(tile)
        // A dark icon would melt into the field without it.
        .overlay(tile.strokeBorder(Theme.hairline, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// An app's tile drawn into an image for its row in a menu. A menu draws a
/// plain image as a template, in the text colour; this one keeps its own
/// colours and corners.
@MainActor
enum AppIconMenuImage {
    private static var drawn: [InstallSource: UIImage] = [:]

    static func image(for source: InstallSource) -> UIImage {
        if let image = drawn[source] { return image }
        let renderer = ImageRenderer(content: AppIconTile(source: source, side: 28)
            .environment(\.colorScheme, .dark))
        renderer.scale = 3
        let image = (renderer.uiImage ?? UIImage()).withRenderingMode(.alwaysOriginal)
        drawn[source] = image
        return image
    }
}

/// F-2 (0.9.178): the full release notes behind the "What's new" preview —
/// shared by the Install banner and About, so the two sections can't drift
/// apart. The notes only ever describe a verified newer release
/// (`UpdateChecker.releaseNotes`).
struct ReleaseNotesSheet: View {
    @ObservedObject var updateChecker: UpdateChecker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let notes = updateChecker.releaseNotes {
                    Text(notes)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            }
            .navigationTitle(L("What's new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
    }
}
