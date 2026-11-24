import SwiftUI
import UIKit

/// The settings sheet: occasional configuration and the activity log, kept out
/// of the main flow.
struct SettingsView: View {
    /// U-UI：当设置页本身就是一个 tab 时 true（标题 L("设置")、无 Done 钮）。
    var isTab: Bool = false
    /// U-UI：文件页/源页要求打开企业证书区时置位；企业区 NavigationLink
    /// 认它，打开后自己清掉。
    var enterpriseRequest: Binding<Bool> = .constant(false)
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
    @Environment(\.dismiss) private var dismiss

    /// Owned here; a new instance just rescans the disk.
    // U-UI：webdavCard 从 ToolsView 搬来（共享开关的唯一 Owner）。
    @StateObject private var webdav = CZFWebDAVServer.shared
    /// U-UI：关于区“关于”行打开 AboutView 的开关。
    @State private var showingAbout = false
    /// The IPA the user swiped to delete, pending confirmation.
    /// The Apple ID the user swiped to remove, pending confirmation.
    @State private var pendingRemove: SavedAccount?
    /// Set while the add/edit sheet is up, and for which account.
    @State private var editorTarget: AccountEditorTarget?

    /// True once "Custom…" is picked, revealing the free-form URL field.
    @State private var anisetteIsCustom = false

    /// 常驻后台自动续签开关，与 AutoRefreshService 共用同一 UserDefaults 键。
    @AppStorage("SIDAutoRefreshEnabled") private var autoRefreshEnabled = false

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

    /// 界面外观，与 App 入口共用同一 UserDefaults 键，改完立即生效。
    @AppStorage("SIDAppearance") private var appearance: AppAppearance = .system

    private struct DeveloperModeNote {
        let text: String
        let failed: Bool
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                enterpriseSection
                toolsSection
                languageSection
                appearanceSection
                soundsSection
                tunnelSection
                developerModeSection
                autoRefreshSection
                anisetteSection
                advancedSection
                logSection
                aboutSection
            }
            .sheet(item: $editorTarget) { AccountEditor(target: $0) }
            // Attached to the Form, apart from the download alert below, so the
            // two alerts don't conflict.
            .alert(L("Remove this Apple ID?"),
                   isPresented: Binding(get: { pendingRemove != nil },
                                        set: { if !$0 { pendingRemove = nil } })) {
                Button(L("Remove"), role: .destructive) {
                    // B6：安装进行中不删账号（同上，revision bump 会掉 session）。
                    if let account = pendingRemove, !engine.isRunning { accounts.remove(account) }
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

    /// Saved Apple IDs: tap to make one active, swipe to edit or remove, or add
    /// a new one.
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
            if engine.isRunning {
                Text(L("An install is already running. Wait for it to finish, then try again."))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        } header: {
            Text(L("Account"))
        }
        .disabled(engine.isRunning)
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

    /// U-UI：工具区（ToolsView 的 9 行里剩下的 5 行；Sideloaded apps →
    /// 应用 tab，下载 → 下载 tab，设置 → 本页，3 行去掉）。
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
                NavigationLink { CertsView(manager: certManager) } label: {
                    ToolRow(icon: "checkmark.seal", color: Theme.blue, title: L("Apple ID 证书"))
                }
                NavigationLink { EntitlementsView(manager: entitlementsManager) } label: {
                    ToolRow(icon: "checklist", color: Theme.badgeWarning, title: L("Entitlements"))
                }
                NavigationLink { LocationView(manager: locationManager) } label: {
                    ToolRow(icon: "location.fill", color: Theme.badgePositive, title: L("Location spoofing"))
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
        .sheet(isPresented: $showingAbout) {
            AboutView()
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
                        .frame(width: 46, height: 46)
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
                            .buttonStyle(.bordered, sound: .tap)
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



    /// One saved Apple ID, ticked when it is the one in use.
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
                    text: (error as? LocalizedError)?.errorDescription ?? String(describing: error),
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
        }
    }

    // MARK: Downloaded IPAs



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

/// The activity log's lines, following the newest.
private struct LogConsole: View {
    private var log: LogStore { .shared }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(log.lines) { line in
                        Text("\(line.stamp)  \(line.text)")
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 240)
            // The last line, not the count, which stops changing once the log is full.
            .onChange(of: log.lines.last?.id) { _, last in
                if let last { proxy.scrollTo(last, anchor: .bottom) }
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
                    .foregroundStyle(Theme.muted)
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
