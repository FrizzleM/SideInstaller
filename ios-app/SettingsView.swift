import Combine
import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The settings sheet: occasional configuration and the activity log, kept out
/// of the main flow.
struct SettingsView: View {
    /// U-UI：当设置页本身就是一个 tab 时 true（标题 L("设置")、无 Done 钮）。
    var isTab: Bool = false
    /// U-UI：文件页/源页要求打开企业证书区时置位；企业区 NavigationLink
    /// 认它，打开后自己清掉。
    var enterpriseRequest: Binding<Bool> = .constant(false)
    /// P0-2 (0.9.185): the error popup's "View log" asks for the
    /// activity log; the body scrolls to it, then clears the flag
    /// (enterpriseRequest 同款 one-shot).
    var logRequest: Binding<Bool> = .constant(false)
    /// P1-1/P1-4 (0.9.186): a "Go to Settings" action asks for the
    /// Account section; the body scrolls to it, then clears the flag
    /// (logRequest 同款 one-shot).
    var accountRequest: Binding<Bool> = .constant(false)
    /// P1-4 (0.9.186): a failed refresh asks for the Certificates
    /// page; the tools NavigationLink opens it, then clears the flag
    /// (enterpriseRequest 同款 one-shot).
    var certRequest: Binding<Bool> = .constant(false)
    @Environment(Engine.self) private var engine
    /// Observed for the language picker, and to redraw on language change.
    @EnvironmentObject private var loc: Localizer
    /// The saved Apple IDs the Account section manages.
    @EnvironmentObject private var accounts: AccountStore
    // U-UI：工具区 5 行要的目的地（RootView 注入，见 U2）。
    @EnvironmentObject private var pairingManager: PairingManager
    @EnvironmentObject private var certManager: CertManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var entitlementsManager: EntitlementsManager
    @EnvironmentObject private var sideBySideManager: SideBySideManager
    /// 0.9.140: the JIT and Sources pages moved here from the dead Tools tab
    /// (RootView injects both, next to the other tool managers above).
    @EnvironmentObject private var sourcesManager: SourcesManager
    @EnvironmentObject private var jitManager: JITManager
    /// B-48-B2：续签进行中时账号区禁用，读这个 live flag。
    @EnvironmentObject private var appsManager: SideloadedAppsManager
    @Environment(\.dismiss) private var dismiss

    /// Owned here; a new instance just rescans the disk.
    // U-UI：webdavCard 从 ToolsView 搬来（共享开关的唯一 Owner）。
    @StateObject private var webdav = CZFWebDAVServer.shared
    /// U-UI：关于区“关于”行打开 AboutView 的开关。
    @State private var showingAbout = false
    /// The IPA the user swiped to delete, pending confirmation.
    /// The Apple ID the user swiped to remove, pending confirmation.
    @State private var pendingRemove: SavedAccount?
    /// The Apple ID whose team the user swiped to pick again, pending
    /// confirmation.
    @State private var pendingTeamReset: SavedAccount?
    /// Set while the add/edit sheet is up, and for which account.
    @State private var editorTarget: AccountEditorTarget?

    /// True once "Custom…" is picked, revealing the free-form URL field.
    @State private var anisetteIsCustom = false

    /// 常驻后台自动续签开关，与 AutoRefreshService 共用同一 UserDefaults 键。
    @AppStorage("SIDAutoRefreshEnabled") private var autoRefreshEnabled = false

    /// F-G (0.9.156): "Wi-Fi only downloads" — with it on, a big download
    /// over cellular data asks first. Off by default. The key lives on
    /// `Engine` so the download paths read the same value.
    @AppStorage(Engine.wifiOnlyDownloadsKey) private var wifiOnlyDownloads = false

    /// F-1 (0.9.159): "Delete the IPA after installing" — with it on, a
    /// successful install deletes its source IPA. Off by default. The key
    /// lives on `Engine` so the success path reads the same value.
    @AppStorage(Engine.deleteAfterInstallKey) private var deleteAfterInstall = false

    /// 内置隧道本端地址，与 BuiltinTunnel 共用同一 UserDefaults 键。
    @AppStorage("CZFBuiltinTunnelIfaceIP") private var builtinTunnelIfaceIP = "10.7.1.1/32"
    /// Device IP 填非法时弹一次提示（Tunnel 节和 Advanced 节两处栏共用）。
    @State private var showDeviceIPResetAlert = false
    /// Set when “Start LocalDevVPN now” opened nothing: how a missing
    /// LocalDevVPN shows inside LiveContainer, where `canOpenURL` can't tell.
    /// Set while a Developer Mode request runs.
    @State private var developerModeBusy = false
    /// How the last Developer Mode request went.
    @State private var developerModeNote: DeveloperModeNote?
    @State private var localDevVPNDidntOpen = false
    /// Set while the restart warning is up, before Developer Mode is turned on.
    @State private var confirmEnableDeveloperMode = false
    @State private var showingClearLogConfirm = false
    /// Buttons, switches and messages make sounds; see `SoundEffects`.
    @AppStorage(SoundEffects.enabledKey) private var soundEffects = true
    /// F-2 (0.9.171): bumped when an ignored version is removed here,
    /// so the list below (read straight from UserDefaults) redraws.
    @State private var ignoredVersionsNonce = 0
    /// B-1 (0.9.178): bumped when the page appears and every 60 seconds
    /// after, so the auto-refresh footer below (read straight from
    /// UserDefaults through `AutoRefreshService`, which is not an
    /// ObservableObject) redraws — `ignoredVersionsNonce` 同款.
    @State private var patrolFooterNonce = 0
    /// B-3 (0.9.181): the 60-second footer timer's subscription —
    /// built on appear, cancelled on disappear. The TabView keeps
    /// every tab alive, so an `autoconnect` publisher on the section
    /// would tick forever after switching away (and a second
    /// SettingsView in a JIT/Certs sheet would add a second one).
    @State private var patrolFooterTimer: AnyCancellable?
    /// F-2 (0.9.171): true while the clear-all-ignored confirm stands.
    @State private var showingClearIgnoredConfirm = false

    /// 界面外观，与 App 入口共用同一 UserDefaults 键，改完立即生效。
    @AppStorage("SIDAppearance") private var appearance: AppAppearance = .system

    private struct DeveloperModeNote {
        let text: String
        let failed: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                accountSection.id("account")
                enterpriseSection
                toolsSection
                languageSection
                appearanceSection
                soundsSection
                tunnelSection
                developerModeSection
                autoRefreshSection
                downloadsSection
                ignoredUpdatesSection
                anisetteSection
                advancedSection
                logSection.id("activityLog")
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .sheet(item: $editorTarget) { AccountEditor(target: $0) }
            // B-1 (0.9.182): the About sheet lives here, at the body root
            // next to the editor sheet — it used to hang off `aboutSection`
            // deep inside the Form, and the live-refreshing activity-log
            // area could drop it (S-3/S-9 同类：宿主太深，刷新顶掉 sheet)。
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            // Attached to the Form, apart from the download alert below, so the
            // two alerts don't conflict.
            .alert(L("Remove this Apple ID?"),
                   isPresented: Binding(get: { pendingRemove != nil },
                                        set: { if !$0 { pendingRemove = nil } })) {
                Button(L("Remove"), role: .destructive) {
                    // B6：安装/续签进行中不删账号（同上，revision bump 会掉 session）。
                    if let account = pendingRemove, !engine.isRunning, !appsManager.isRefreshing { accounts.remove(account) }
                    pendingRemove = nil
                }
                Button(L("Cancel"), role: .cancel) { pendingRemove = nil }
            } message: {
                if let account = pendingRemove {
                    Text(L("“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.",
                           account.appleID))
                }
            }
            .navigationTitle(L("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isTab {
                        Button(L("Done")) { dismiss() }
                    }
            }
            }
            // P0-2 (0.9.185): the error popup's "View log" — scroll
            // the activity log into view, then clear the flag (the
            // enterpriseRequest 同款 one-shot). If the id isn't
            // found the scroll is a no-op and the user still lands
            // on the Settings tab.
            .onChange(of: logRequest.wrappedValue) { _, requested in
                guard requested else { return }
                logRequest.wrappedValue = false
                proxy.scrollTo("activityLog", anchor: .top)
            }
            // P1-1/P1-4 (0.9.186): a "Go to Settings" action — scroll
            // the Account section into view, then clear the flag
            // (logRequest 同款 one-shot).
            .onChange(of: accountRequest.wrappedValue) { _, requested in
                guard requested else { return }
                accountRequest.wrappedValue = false
                proxy.scrollTo("account", anchor: .top)
            }
            }
        }
        .onAppear {
            anisetteIsCustom = !engine.anisetteServers.contains { $0.address == engine.anisetteURL }
        }
        // Device IP 非法重置的提示：挂在 Form 链上，与上面两个 alert
        // 分开，避免同时弹出冲突。
        .blueTopBar()
        .alert(L("Invalid device IP"), isPresented: $showDeviceIPResetAlert) {
            Button(L("OK"), role: .cancel) { }
        } message: {
            Text(L("The address was invalid, reset to 10.7.0.1."))
        }
    }

    // MARK: Account

    /// Saved Apple IDs: tap to make one active, swipe to edit or remove one or
    /// pick its team again, or add a new one.
    private var accountSection: some View {
        Section {
            ForEach(accounts.accounts) { account in
                Button { accounts.activate(account) } label: { accountRow(account) }
                    // `.plain` keeps the row text from using the accent color.
                    .buttonStyle(.plain, sound: .tick)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingRemove = account
                        } label: {
                            Label(L("Remove"), systemImage: "trash")
                        }
                        // Set explicitly: the row's `.plain` style removes the
                        // destructive red.
                        .tint(Theme.negative)
                        Button {
                            editorTarget = .existing(account)
                        } label: {
                            Label(L("Edit"), systemImage: "pencil")
                        }
                        .tint(Theme.accent)
                        // Only once a team was picked, which an Apple ID on
                        // more than one is asked for.
                        if accounts.team(for: account.normalized) != nil {
                            Button {
                                pendingTeamReset = account
                            } label: {
                                Label(L("Team"), systemImage: "person.2")
                            }
                            .tint(Theme.warning)
                        }
                    }
            }
            if accounts.accounts.isEmpty {
                Text(L("No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in."))
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Button { editorTarget = .new } label: {
                Label(L("Add Apple ID"), systemImage: "plus.circle")
            }
            if let warning = accounts.keychainWarning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
            // B6：安装进行中时切账号会掉登录 session（见本节注释），
            // 整区禁用 + 一行说明，装完再切。
            // B-48-B2：续签进行中同理禁用——切账号会清掉续签在用的
            // signingTeamID，同组剩下的任务全撞第二道闸假失败。
            if engine.isRunning {
                Text(L("An install is already running. Wait for it to finish, then try again."))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            } else if appsManager.isRefreshing {
                Text(L("A refresh is already running. Wait for it to finish, then try again."))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        } header: {
            Text(L("Account"))
        }
        .disabled(engine.isRunning || appsManager.isRefreshing)
        // On the section, apart from the Form's alerts, so they don't conflict.
        .alert(L("Pick the team again?"),
               isPresented: Binding(get: { pendingTeamReset != nil },
                                    set: { if !$0 { pendingTeamReset = nil } })) {
            Button(L("Pick Again")) {
                if let account = pendingTeamReset { accounts.forgetTeam(for: account.normalized) }
                pendingTeamReset = nil
            }
            Button(L("Cancel"), role: .cancel) { pendingTeamReset = nil }
        } message: {
            if let account = pendingTeamReset {
                Text(L("The next sign-in with “%@” asks which developer team signs.", account.appleID))
            }
        }
    }
    /// U-UI：企业证书区（签名段从原证书页搬到 EnterpriseCertView 后，
    /// 设置页只留这一行摘要 + 推入链接；证书本身的表单全在那一页）。
    private var enterpriseSection: some View {
        Section {
            NavigationLink(destination: EnterpriseCertView(), isActive: enterpriseRequest) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .foregroundStyle(Theme.accent2)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("企业证书"))
                            .font(.body)
                        Text(enterpriseCertName)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if let exp = enterpriseCertExpiration {
                        Text(exp.formatted(Date.FormatStyle(date: .abbreviated).locale(Localizer.locale)))
                            .font(.footnote)
                            .foregroundStyle(enterpriseCertExpirationSoon ? Theme.negative : Theme.muted)
                    }
                }
            }
        }
    }

    /// 企业证书是否就绪（表单里的 P12 + 描述文件 + 密码都在）。
    private var enterpriseCertReady: Bool { EnterpriseCertStore.ready }

    /// 企业证书摘要行第二行：证书名 / 描述文件名，哪个有写哪个，都没有写“未导入证书”。
    private var enterpriseCertName: String {
        if let name = EnterpriseCertStore.certInfo?.name, !name.isEmpty { return name }
        if let name = EnterpriseCertStore.provisionInfo?.name, !name.isEmpty { return name }
        return L("未导入证书")
    }

    /// 企业证书到期日（证书优先，空了退回描述文件）。
    private var enterpriseCertExpiration: Date? {
        EnterpriseCertStore.certInfo?.expiration ?? EnterpriseCertStore.provisionInfo?.expiration
    }

    /// 企业证书 30 天内到期就红字提醒。
    private var enterpriseCertExpirationSoon: Bool {
        guard let exp = enterpriseCertExpiration else { return false }
        return exp.timeIntervalSinceNow < 30 * 24 * 3600
    }

    /// U-UI：工具区（旧 ToolsView 的行，0.9.140 起 JIT 与 Sources 也回
    /// 到这里；Sideloaded apps → 应用 tab，下载 → 下载 tab，设置 →
    /// 本页，3 行去掉）。
    private var toolsSection: some View {
        Group {
            Section {
                NavigationLink { SideBySideView(manager: sideBySideManager) } label: {
                    ToolRow(icon: "square.on.square", color: Theme.tilePurple, title: L("Side by Side"), beta: true)
                }
                if Engine.deviceCanSelfPair {
                    NavigationLink { PairingView(manager: pairingManager) } label: {
                        ToolRow(icon: "link", color: Theme.tileTeal, title: L("Pairing"))
                    }
                }
                NavigationLink { JITView(manager: jitManager) } label: {
                    ToolRow(icon: "bolt.fill", color: Theme.badgeWarning, title: L("JIT"))
                }
                NavigationLink(destination: CertsView(manager: certManager), isActive: certRequest) {
                    ToolRow(icon: "checkmark.seal", color: Theme.blue, title: L("Apple ID 证书"))
                }
                NavigationLink { EntitlementsView(manager: entitlementsManager) } label: {
                    ToolRow(icon: "checklist", color: Theme.badgeWarning, title: L("Entitlements"))
                }
                NavigationLink { LocationView(manager: locationManager) } label: {
                    ToolRow(icon: "location.fill", color: Theme.badgePositive, title: L("Location spoofing"))
                }
                NavigationLink { AppSourcesView(manager: sourcesManager, appsManager: appsManager) } label: {
                    ToolRow(icon: "square.stack.3d.down.right", color: Theme.tileTeal, title: L("Sources"),
                            count: sourcesManager.updateCount(installed: appsManager.entries))
                }
                NavigationLink { InstallHistoryView() } label: {
                    ToolRow(icon: "clock.arrow.circlepath", color: Theme.tileTeal, title: L("Install history"))
                }
            } header: {
                Text(L("Tools"))
            }
            webdavCard
        }
    }

    /// U-UI：关于区（AboutView 本体不动；点行弹 sheet）。
    private var aboutSection: some View {
        Section {
            HStack {
                Text(L("Version"))
                Spacer()
                Text(aboutVersionText)
                    .foregroundStyle(Theme.muted)
            }
            Button(L("About")) { showingAbout = true }
                .foregroundStyle(Theme.accent2)
        } header: {
            Text(L("About"))
        }
    }

    /// 关于区版本号：纯 "短版 (build)"，不套 L()（AboutView:44-49 的
    /// fallbacks "0"/"1" 照抄）。
    private var aboutVersionText: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
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
                            Rectangle().fill(Theme.tileCyan)
                            Image(systemName: "server.rack")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("WebDAV file service"))
                                .font(.headline)
                            Text(L("Transfer files to Documents over LAN"))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
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
                            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                            .controlSize(.small)
                        }
                    } else {
                        Text(L("Wi-Fi not connected"))
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    Text(L("Anyone on your LAN can access it without a password. Turn it off when done."))
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error = webdav.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.negative)
                }
            }
        }
    }



    /// One saved Apple ID, ticked when it is the one in use, with the
    /// developer team it signs with when one was picked.
    private func accountRow(_ account: SavedAccount) -> some View {
        let isActive = accounts.isActive(account)
        return HStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.title3)
                .foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.appleID)
                    .font(.subheadline.weight(isActive ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if isActive {
                    Text(L("In use"))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                if let team = accounts.team(for: account.normalized) {
                    Text(team.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if isActive {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }

    // MARK: Language

    /// App-wide language, applied immediately since every screen observes it.
    private var languageSection: some View {
        Section {
            Picker(L("App language"), selection: $loc.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
        } header: {
            Text(L("Language"))
        }
    }

    // MARK: Appearance

    /// 外观三档：跟随系统 / 浅色 / 深色，由 App 入口统一应用到整个窗口。
    private var appearanceSection: some View {
        Section {
            Picker(L("Appearance"), selection: $appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(L("Appearance"))
        }
    }

    // MARK: Sounds

    private var soundsSection: some View {
        Section {
            Toggle(L("Sound effects"), isOn: $soundEffects)
        } header: {
            Text(L("Sounds"))
        }
    }

    /// Device IP 校验：照抄本端地址栏的做法（trim → 校验 → 非法重置），
    /// 只是 Device IP 是裸地址不是 CIDR，所以 requireExplicitCIDR 传 false
    ///（裸 IPv4 按 /32 算）；非法时重置回 10.7.0.1 并弹提示。
    private func validateDeviceIP() {
        let trimmed = engine.deviceIP.trimmingCharacters(in: .whitespacesAndNewlines)
        if (try? CIDRValidator.shared.validateCIDR(
            trimmed, isRouteDestination: false,
            allowIntermediateAddresses: true,
            requireExplicitCIDR: false)) != nil {
            engine.deviceIP = trimmed
        } else {
            engine.deviceIP = "10.7.0.1"
            showDeviceIPResetAlert = true
        }
    }

    // MARK: Tunnel

    /// LocalDevVPN controls: start it whenever something needs the tunnel, or
    /// start it now. Uses LocalDevVPN's `localdevvpn://enable` URL, which
    /// connects and then returns to this app.
    @ViewBuilder
    private var tunnelSection: some View {
        Section {
            Toggle(L("Start LocalDevVPN when needed"), isOn: Bindable(engine).autoStartVPN)
            Button {
                Task {
                    let opened = await engine.startLocalDevVPN()
                    localDevVPNDidntOpen = !opened
                }
            } label: {
                Label(L("Start LocalDevVPN now"), systemImage: "bolt.horizontal.circle")
            }
            HStack {
                Text(L("Built-in tunnel interface"))
                Spacer()
                TextField("10.7.1.1/32", text: $builtinTunnelIfaceIP)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
                    .onSubmit {
                        // 写坏了就回默认，别把非法地址存进隧道配置。
                        let trimmed = builtinTunnelIfaceIP
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if (try? CIDRValidator.shared.validateCIDR(
                            trimmed, isRouteDestination: false,
                            allowIntermediateAddresses: true)) != nil {
                            builtinTunnelIfaceIP = trimmed
                        } else {
                            builtinTunnelIfaceIP = "10.7.1.1/32"
                        }
                    }
            }
            HStack {
                Text(L("Tunnel peer (device IP)"))
                Spacer()
                TextField("10.7.0.1", text: Bindable(engine).deviceIP)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
                    .onSubmit { validateDeviceIP() }
            }
        } header: {
            Text(L("Tunnel"))
        } footer: {
            // 只留内置隧道：说明地址默认值与生效时机。
            if localDevVPNDidntOpen {
                Text(L("LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you."))
            }
            Text(L("Built-in tunnel: interface 10.7.1.1/32 and peer 10.7.0.1/32 by default. Address changes take effect the next time the tunnel connects."))
            Text(L("When on, operations that need the tunnel try the built-in tunnel first and start LocalDevVPN when needed. When off, LocalDevVPN is never started automatically; the built-in tunnel still starts on demand, and the manual pill switch is unaffected."))
        }
    }

    // MARK: Auto refresh

    /// 常驻后台自动续签：开了之后 AutoRefreshService 双保活巡检，
    /// 描述文件 3 天内到期的 App 自动续签，不用再靠手动或快捷指令触发。
    // MARK: Developer Mode

    /// Asks this iPhone to show Developer Mode in Settings, or to turn it on.
    /// Both need a link that already works, so they can't help where the link
    /// itself needs Developer Mode (iOS 27).
    private var developerModeSection: some View {
        Section {
            Button {
                runDeveloperMode(.reveal)
            } label: {
                Label(L("Show Developer Mode in Settings"), systemImage: "eye")
            }
            .disabled(developerModeBusy || engine.isRunning)
            Button {
                confirmEnableDeveloperMode = true
            } label: {
                Label(L("Turn on Developer Mode"), systemImage: "hammer")
            }
            .disabled(developerModeBusy || engine.isRunning)
            if developerModeBusy {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L("Asking this iPhone…"))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            } else if let note = developerModeNote {
                Label(note.text, systemImage: note.failed ? "exclamationmark.triangle"
                                                          : "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(note.failed ? AnyShapeStyle(Theme.negative) : AnyShapeStyle(Theme.muted))
            }
        } header: {
            Text(L("Developer Mode"))
        }
        // On the section, apart from the Form's alerts, so they don't conflict.
        .alert(L("Turn on Developer Mode?"), isPresented: $confirmEnableDeveloperMode) {
            Button(L("Turn On and Restart"), role: .destructive) { runDeveloperMode(.enable) }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("This iPhone restarts right away. Once you unlock it, tap Turn On in the alert that appears. iOS allows this only while the iPhone has no passcode."))
        }
    }

    private func runDeveloperMode(_ request: DeviceConnection.DeveloperModeRequest) {
        guard !developerModeBusy else { return }
        developerModeBusy = true
        developerModeNote = nil
        // B-3：View struct 的普通方法本就非隔离，裸 Task 写 @State 落在主线程外。
        Task { @MainActor in
            do {
                let text: String
                switch try await engine.requestDeveloperMode(request) {
                case .alreadyOn:
                    text = L("Developer Mode is already on.")
                case .revealed:
                    text = L("Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.")
                case .enabling:
                    text = L("Developer Mode is set to turn on, and this iPhone restarts now. Once you unlock it, tap Turn On.")
                }
                developerModeNote = DeveloperModeNote(text: text, failed: false)
                SoundEffects.play(.success)
            } catch {
                developerModeNote = DeveloperModeNote(
                    text: userFacingErrorMessage(error),
                    failed: true)
                SoundEffects.play(.error)
            }
            developerModeBusy = false
        }
    }


    private var autoRefreshSection: some View {
        Section {
            Toggle(L("Refresh apps automatically in background"), isOn: $autoRefreshEnabled)
                .onChange(of: autoRefreshEnabled) { _, _ in
                    AutoRefreshService.shared.applySetting()
                    // 刚打开时就把下一次系统后台唤醒交上去。
                    if autoRefreshEnabled {
                        SIDAutoRefresh.scheduleBackgroundWake()
                    }
                }
        } header: {
            Text(L("Auto Refresh"))
        } footer: {
            autoRefreshFooter
        }
        // B-1 (0.9.178): the footer reads UserDefaults straight through
        // `AutoRefreshService` (not an ObservableObject), so nothing
        // redraws it on its own — bump the nonce when the section
        // appears and every 60 seconds after, so "x 分钟前" keeps up
        // with a patrol that landed while the page stood open.
        // B-3 (0.9.181): the timer lives only while the page is
        // visible — see `startPatrolFooterTimer`.
        .onAppear {
            patrolFooterNonce += 1
            startPatrolFooterTimer()
        }
        .onDisappear { stopPatrolFooterTimer() }
    }

    /// B-3 (0.9.181): (re)build the footer timer — one tick a minute
    /// while the page is visible, so "x 分钟前" keeps up with a patrol
    /// that landed while the page stood open.
    private func startPatrolFooterTimer() {
        stopPatrolFooterTimer()
        patrolFooterTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in patrolFooterNonce += 1 }
    }

    /// B-3 (0.9.181): cancel the footer timer — the page is hidden,
    /// so no tick may bump the nonce (and the body) until it returns.
    private func stopPatrolFooterTimer() {
        patrolFooterTimer?.cancel()
        patrolFooterTimer = nil
    }

    /// 定位降级明示（Seal 同款）：定位没给“始终”时，巡检只有音频
    /// 保活在撑，锁屏续签可能被挂起——直接写在开关下面，不让用户猜。
    /// 只在开关开着时显示；开关关着时巡检本来就不跑，写了也没意义。
    private var autoRefreshFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("SideInstaller stays alive in the background (silent audio + location) and checks every 30 minutes. Apps whose signing expires within 3 days are re-signed automatically. Location access must be set to “Always” and the tunnel must stay connected (the built-in tunnel is enough). The system also wakes the app in the background from time to time to run a check — don't swipe it away from the app switcher."))
            if autoRefreshEnabled && AutoRefreshService.shared.locationDegraded {
                Text(L("Location is not set to “Always”, so only silent audio is keeping the app alive — renewal from the lock screen may be suspended. Set Location to “Always” in Settings."))
                    .foregroundStyle(Theme.warning)
            }
            // F-3 (0.9.177): when the last patrol ran — only while the
            // switch is on; off means no patrol runs at all.
            // F-3 (0.9.178): and when the last automatic renewal round
            // started — same shape, "从未自动续签" when it never ran
            // (B-2, 0.9.182: a bare "—" says nothing).
            if autoRefreshEnabled {
                Text(lastPatrolText)
                Text(lastRoundText)
            }
        }
    }

    /// F-3 (0.9.177): "上次巡检：x 分钟前" — the relative time is
    /// `SourcesView.checkedText` 同款; no patrol yet reads "从未巡检".
    /// B-1 (0.9.178): the nil copy is "从未巡检" now, not "—" — the
    /// decision stamp is covered on every decision round, so a nil stamp
    /// truly means no patrol ever ran.
    private var lastPatrolText: String {
        guard let last = AutoRefreshService.shared.lastPatrolDate else {
            return L("上次巡检：%@", L("从未巡检"))
        }
        return L("上次巡检：%@", SourcesView.checkedText(for: last))
    }

    /// F-3 (0.9.178): "上次自动续签：x 分钟前" — `lastRoundDate` only
    /// stamps when a renewal round really starts (6-hour cooldown), so
    /// nil truly means it never automatically renewed.
    /// B-2 (0.9.182): the nil copy is "从未自动续签" now, not "—" —
    /// the last bare "—" placeholder in the app (lastPatrolText got the
    /// same treatment in 0.9.178).
    private var lastRoundText: String {
        guard let last = AutoRefreshService.shared.lastRoundDate else {
            return L("上次自动续签：%@", L("从未自动续签"))
        }
        return L("上次自动续签：%@", SourcesView.checkedText(for: last))
    }

    // MARK: Downloaded IPAs

    /// F-G (0.9.156): "Wi-Fi only downloads" — off by default, so nothing
    /// changes until the user turns it on. On, a source install, link
    /// import or build download over cellular data asks first, showing the
    /// file's size (or that it's unknown) before it uses mobile data.
    private var downloadsSection: some View {
        Section {
            Toggle(L("Wi-Fi only downloads"), isOn: $wifiOnlyDownloads)
            Toggle(L("Delete the IPA after installing"), isOn: $deleteAfterInstall)
        } header: {
            Text(L("Downloads"))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("When on, a download over cellular data asks first, so a large IPA doesn't use your mobile data."))
                Text(L("Deletes the source IPA after a successful install. Files used for renewal are kept."))
            }
        }
    }

    /// F-2 (0.9.171): the update versions the user ignored, with a way
    /// back — swiping one away (or clearing all) re-arms its update
    /// prompt at once: `hasUpdate` reads the same map, and the change
    /// notification recounts the badge. Before this there was no UI to
    /// un-ignore at all, so a mis-tapped ignore silenced that version
    /// until the source shipped a newer one.
    private var ignoredUpdatesSection: some View {
        Section {
            let ignored = IgnoredUpdateVersions.all()
            if ignored.isEmpty {
                Text(L("没有已忽略的更新。"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(ignored, id: \.bundleID) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        // F-3 (0.9.172): the app's name, not just its
                        // bundle ID — a bare ID doesn't say which app
                        // it is. Falls back to the ID when no loaded
                        // source lists it.
                        Text(sourcesManager.appName(for: entry.bundleID) ?? entry.bundleID)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(entry.version)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            IgnoredUpdateVersions.remove(bundleID: entry.bundleID)
                            ignoredVersionsNonce += 1
                        } label: {
                            Label(L("Remove"), systemImage: "trash")
                        }
                    }
                }
                Button(L("清空全部"), role: .destructive) {
                    showingClearIgnoredConfirm = true
                }
            }
        } header: {
            Text(L("已忽略的更新"))
        }
        .alert(L("清空全部"), isPresented: $showingClearIgnoredConfirm) {
            Button(L("清空全部"), role: .destructive) {
                IgnoredUpdateVersions.removeAll()
                ignoredVersionsNonce += 1
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("所有已忽略的版本都将重新提示更新。"))
        }
    }

    // MARK: Anisette server

    private var anisetteSection: some View {
        Section {
            Picker(L("Server"), selection: anisetteSelection) {
                ForEach(engine.anisetteServers) { server in
                    Text(server.name).tag(Optional(server.address))
                }
                Divider()
                Text(L("Custom…")).tag(String?.none)
            }
            if engine.anisetteAuto {
                Text(L("Starts with %@", anisetteName))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else if anisetteIsCustom {
                TextField(L("Server URL"), text: Bindable(engine).anisetteURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } else {
                Text(engine.anisetteURL)
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } header: {
            Text(L("Anisette Server"))
        }
    }

    /// The menu's selection: a server's address, or nil for "Custom…".
    /// The server Auto starts with, by its name on the list if it has one.
    private var anisetteName: String {
        engine.anisetteServers.first { $0.address == engine.anisetteURL }?.name ?? engine.anisetteURL
    }

    private var anisetteSelection: Binding<String?> {
        Binding(
            get: { anisetteIsCustom ? nil : engine.anisetteURL },
            set: { newValue in
                if let address = newValue {
                    anisetteIsCustom = false
                    engine.anisetteURL = address
                } else {
                    anisetteIsCustom = true
                }
            }
        )
    }

    // MARK: Advanced

    private var advancedSection: some View {
        Section {
            HStack {
                Text(L("Device IP"))
                Spacer()
                TextField("10.7.0.1", text: Bindable(engine).deviceIP)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
                    .onSubmit { validateDeviceIP() }
            }
        } header: {
            Text(L("Advanced"))
        }
    }

    // MARK: Activity log

    // The lines are read only in `LogConsole` and `LogHeader`, so a new one
    // redraws those two and not the rest of Settings.
    private var logSection: some View {
        Section {
            LogConsole()
            HStack {
                Button {
                    UIPasteboard.general.string = LogStore.shared.text
                } label: {
                    Label(L("Copy"), systemImage: "doc.on.doc")
                }
                // F5 (0.9.154): share the log as a .txt file (see
                // LogExportFile — the file is written only when the share
                // actually happens, so this never reads the log in body).
                // preview 是必填的：自定义 Transferable 作 item 时没有
                // 默认预览，只有 URL/String 两路自带（两轮红字同因）。
                ShareLink(item: LogExportFile(), preview: SharePreview(L("导出日志"), image: Image(systemName: "doc.text"))) {
                    Label(L("导出日志"), systemImage: "square.and.arrow.up")
                }
                Spacer()
                Button(role: .destructive) {
                    showingClearLogConfirm = true
                } label: {
                    Label(L("Clear"), systemImage: "trash")
                }
                .alert(L("Clear"), isPresented: $showingClearLogConfirm) {
                    Button(L("Delete"), role: .destructive) { LogStore.shared.clear() }
                    Button(L("Cancel"), role: .cancel) {}
                } message: {
                    Text(L("删除后无法恢复"))
                }
            }
            .font(.subheadline)
            // 上游 1ae5489 的 Verbose logging 开关（只拿开关 + 下面的
            // footer 说明）；“Report a problem”按钮不搬回，仍留
            // AboutView（fork 2026-11-05 的位置），用户 2026-11-06 批准。
            Toggle(L("Verbose logging"), isOn: Bindable(engine).verboseLogging)
        } header: {
            LogHeader()
        } footer: {
            Text(L("Adds the messages exchanged with iOS to the log, for tracking down a connection problem. Leave it off otherwise, as they quickly fill the log."))
        }
    }
}

/// F5 (0.9.154): the activity log as a shareable .txt file. The struct
/// carries no log text itself — the exporting closure reads
/// `LogStore.shared.text` and writes the tmp file only when the share
/// actually happens, so building the ShareLink never reads the log in
/// `body` (the log lines stay observed only by LogConsole/LogHeader,
/// see logSection). The tmp file is overwritten on every export.
private struct LogExportFile: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // 修法（checks 两轮红：ShareLink 找不到通用 Transferable 初始化）：
        // 自定义 Transferable 作 item 时 preview 是必填的，只有 URL/String
        // 两路自带默认预览——第一轮“具名参数 + 显式特化钉 Item”的修法
        // 没动红字，与 FileRepresentation 的写法无关；传了 preview 才
        // 命中通用初始化（Apple 的 Photo/BlogPost 同款写法）。
        FileRepresentation<LogExportFile>(exportedContentType: .plainText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("SideInstaller-log.txt")
            try LogStore.shared.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url, allowAccessingOriginalFile: false)
        }
    }
}

/// The activity log's lines, following the newest. F4 (0.9.146): a search
/// field above the list filters the rows by keyword.
private struct LogConsole: View {
    private var log: LogStore { .shared }
    /// The console's filter text; blank shows the whole log.
    @State private var searchText = ""

    /// The lines shown: the whole log, or only the rows matching the
    /// search text (the app list's `filteredEntries` 同款取法).
    private var lines: [LogStore.Entry] {
        log.filteredLines(matching: searchText)
    }

    /// True when a search is running and nothing matched it.
    private var hasNoMatch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && lines.isEmpty
    }

    /// P0-6 (0.9.185): the error rows among the shown lines — the
    /// ⛔️-marked failures plus the failure sentences that never got
    /// the marker (LogStore.Entry has no level field, so the screen
    /// reads the text; the ⛔️ convention covers most of it).
    private var errorLines: [LogStore.Entry] {
        lines.filter(Self.isErrorLine)
    }

    private static func isErrorLine(_ line: LogStore.Entry) -> Bool {
        let text = line.text.lowercased()
        return text.contains("⛔️")
            || text.contains("failed")
            || text.contains("couldn't")
            || text.contains("didn't")
            || text.contains("error")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // P0-6 (0.9.185): errors pinned on top, red, in their own
            // short scroll — Feather's critical-errors section. The
            // full console below (and its scroll-to-bottom anchor)
            // is untouched; the section follows the same search.
            if !errorLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("错误 (%d)", errorLines.count))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Theme.negative)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(errorLines) { line in
                                Text(line.stamp + "  " + line.text)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Theme.negative)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 120)
                }
            }
            SearchBar(text: $searchText, placeholder: L("搜索"))
            if hasNoMatch {
                Text(L("没有匹配的日志。"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(lines) { line in
                                Text(line.stamp + "  " + line.text)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 240)
                    // The last line, not the count, which stops changing once the log is full.
                    .onChange(of: lines.last?.id) { _, last in
                        if let last { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
    }
}

/// “Activity Log (n)”.
private struct LogHeader: View {
    /// Observed to redraw on language change.
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        Text(L("Activity Log (%d)", LogStore.shared.lines.count))
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
    /// A count in a capsule before the chevron, such as the updates Sources
    /// found. 0 hides it. (0.9.140: the Sources row's badge, ex-Tools tile.)
    var count: Int = 0

    var body: some View {
        PanelCard {
            HStack(spacing: 14) {
                glyph
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.headline)
                if beta { BetaBadge() }
                Spacer(minLength: 8)
                if count > 0 {
                    Text("\(count)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 24, minHeight: 24)
                        .padding(.horizontal, count > 9 ? 4 : 0)
                        .background(Capsule().fill(Theme.warning))
                        .accessibilityLabel(count == 1 ? L("%d update", count) : L("%d updates", count))
                }
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted.opacity(0.6))
            }
        }
    }

    /// Single branch now (no if/switch over View types), so no
    /// @ViewBuilder needed here; the 46×46 frame + cornerRadius 12
    /// in body are untouched.
    private var glyph: some View {
        ZStack {
            // B-11：瓦填充去透明渐变——Theme.gradient 第二站 0.72 透明，
            // 浅色卡上会把深瓦色冲淡到底角 3.14–3.55:1；调用方传的已是
            // 深瓦色，纯色填充即是满值。
            Rectangle().fill(color)
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
