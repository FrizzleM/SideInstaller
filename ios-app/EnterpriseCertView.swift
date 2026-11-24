import Darwin
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 企业证书页：从设置页推入（0.9.102 UI 重做：原证书页的签名段整块
/// 搬来，应用库段去了文件页的应用文件夹库）。证书材料、签名表单、安装与
/// 诊断日志都在这里；导航标题与蓝顶栏由设置页的栈提供。
struct EnterpriseCertView: View {
    /// Engine（配对安装用：runInstallSignedIPA/isRunning/
    /// installProgress/finished/lastError/guide/cancelOneClick；
    /// 由 SideInstallerApp 注入全 tab 共用，安装 tab 的 ID 线
    /// 与企业页读同一实例——企业页只认自己那次安装的状态，
    /// 完成判定只看 enterpriseInstallInFlight 期间的变化）。
    @Environment(Engine.self) private var engine: Engine
    /// Declared so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @EnvironmentObject private var workspace: CertWorkspace
    /// 步骤/诊断日志的存放处（单例，与文件页共用同一份
    /// diagnosticLog）：企业安装的传输不再走它的 install()，
    /// 只用 appendStepLog/diagnosticLog；文件页安装仍用它。
    @ObservedObject private var localInstall = LocalHTTPInstallServer.shared

    // 证书材料状态
    @State private var hasP12 = EnterpriseCertStore.hasP12
    @State private var hasProvision = EnterpriseCertStore.hasProvision
    @State private var password = EnterpriseCertStore.password
    @State private var provisionInfo = EnterpriseCertStore.provisionInfo
    @State private var certInfo = EnterpriseCertStore.certInfo
    /// 各 profile 描述文件的到期日缓存（A1）：列表行只读这份缓存，不再每
    /// 次 body 求值都重解 mobileprovision；由 refreshCertState 后台填充。
    @State private var profileExpirations: [UUID: Date] = [:]
    /// 上次解析完的证书材料指纹（A1+A2）：与当前指纹相同就跳过重解析。
    /// 初值即创建时的指纹——@State 初值那次解析（:29–30）用的就是这批文件。
    @State private var certParsedFingerprint: String? = EnterpriseCertStore.certStateFingerprint()
    /// 上次解析完时用的证书密码（A1+A2）：密码错误提示只在密码变了才重算。
    /// 初值 nil——进页第一次 refresh 必须跑一次解析，把密码错提示算出来。
    @State private var certParsedPassword: String? = nil
    @State private var showP12Picker = false
    @State private var showProvisionPicker = false
    // 轻松签式“导入证书库”：一次选 .p12 + 描述文件，配对才进。
    @State private var showCertLibraryPicker = false
    @State private var importError: String?
    // 密码解不开 p12 时的红字提示（密码组下显示，不等到签名才说）。
    @State private var certPasswordError: String?
    @State private var confirmingRemoveCert = false
    // 多证书库：profile 列表与激活 profile（见 EnterpriseCertStore）。
    @State private var profiles = EnterpriseCertStore.profiles()
    @State private var activeProfileID: UUID? = EnterpriseCertStore.activeProfile()?.id
    @State private var showNewProfilePicker = false
    @State private var pendingNewProfileP12: URL?
    @State private var pendingNewProfileProvision: URL?
    @State private var newProfilePassword = ""
    @State private var showingNewProfilePasswordAlert = false
    @State private var deletingProfile: EnterpriseCertProfile?
    @State private var showingDeleteProfileAlert = false
    @State private var editingProfileID: UUID?
    @State private var editingProfileName = ""
    // 本机回环安装兜底：回环起不来时弹框，点了才走配对安装。
    // 单例（不用 StateObject 的实例）：切 tab 重建视图也不能
    // 把跑着的回环服务连同视图一起释放掉。
    @ObservedObject private var otaServer = OTAInstallServer.shared
    @State private var showingLoopbackFallbackAlert = false
    @State private var loopbackFailureText: String?
    // 吊销状态（手动刷新，警告不拦截）
    @State private var revocationStatus: CertRevocationStatus = .unknown
    @State private var revocationChecking = false
    @State private var revocationCheckedAt: Date?
    // 待签 IPA 与修改项
    @State private var selectedIPA: URL?
    @State private var mods = CertSignMods()
    @State private var showIPAPicker = false
    @State private var showLibraryPicker = false
    @State private var showPluginPicker = false
    @State private var pluginError: String?
    @State private var iconItem: PhotosPickerItem?
    /// B12-6：新图标的解码缓存——`mods.icon` 是相册原图 Data（数 MB），
    /// `iconRow` 每遍 body 都 `UIImage(data:)` 重解；这里只解一次，
    /// body 只读缓存。`decodedIconData` 记缓存对应哪份 Data，视图
    /// 重建导致任务重跑时不再重复解码。
    @State private var decodedIcon: UIImage?
    @State private var decodedIconData: Data?
    @State private var signOnlyMessage: String?
    @State private var signOnlyFailed = false
    // 点红/仅签名按钮时被前置条件拦住的明说（代替静默禁用）：
    // 显示在按钮正下方，条件一满足就清掉，不残留旧话。
    @State private var signBlockedMessage: String?
    // 轻松签式“签名后立即安装”开关：开 = 开始签名后直接装，
    // 关 = 开始签名只签存已签名；“仅签名”按钮仍在下面。
    @AppStorage("CZFEnterpriseInstallWhenSign") private var installWhenSign = true
    // 轻松签式“更多设置”展开态：默认收起，点底部大蓝按钮展开
    // 预设/插件注入/多开/仅签名（功能全在，不砍，只是收起来）。
    @State private var showMoreSettings = false
    // 选中 IPA 的脱壳预检结果（nil = 还没算出来）：加密的在表单上
    // 直接提示；真正签的时候 startSign 还会再算一次 gate。
    @State private var selectedCryptid: Int?
    /// 选中 IPA 里未脱壳的 .app 名（与 selectedCryptid 同步写）：
    /// 表单提示逐个报名字，不只含糊说“程序”（见 SS2）。
    @State private var selectedUndumpedApps: [String] = []
    /// A-4：选包时存的文件指纹——签时文件没变且脱壳预检已算出，
    /// startSign 直接复用 selectedUndumpedApps，不再解压第二遍。
    @State private var selectedUndumpedFingerprint: String?
    // 多开：数量与起始序号（只对「仅签名」生效，见 multiOpenSection）
    @State private var multiCountText = "1"
    @State private var multiStartText = "1"
    // 签前警告（掉签/未脱壳）：警告不拦截，用户点继续才执行。
    @State private var pendingWarnings: [String] = []
    @State private var pendingSignKind: CertSignKind?
    @State private var pendingSignURL: URL?
    @State private var pendingSignMods = CertSignMods()
    @State private var showingWarningAlert = false
    // 企业安装：走配对安装（Engine 设备链路，v45 那套）。
    // 进行中标志 + 完成弹框（engine.finished 置位才算成功，
    // 取消不算）；重试用的记录，就是这次要装的包；失败原因
    // 快照（见 startEngineInstall 的注释：前置失败当场快照，
    // 跑完由 onChange 按 finished/lastError 快照，不直接绑
    // engine 的全局量，免得别的 tab 的安装状态串到这里）。
    // 配对安装跑完记一条签名日志：签名并安装那路记
    // “签名并安装”，已签名行直装记“仅安装”（kind 由起
    // 手那路定，重试复用同一 kind，跑完时不清掉）。
    @State private var enterpriseInstallInFlight = false
    /// 企业页这次安装的归属凭证（见 startEngineInstall）：起跑时
    /// 快照 engine.installSessionID，结束时只认同一会话；对不上
    /// 说明这段“进行中”是别的安装的，不记日志、不弹框。
    @State private var enterpriseInstallRunID: UUID?
    @State private var engineInstallLogAppName: String?
    @State private var engineInstallLogKind: CertSignLogKind = .signAndInstall
    // 安装诊断日志展开态（默认收起）：只控制展示，不存盘、不进 UserDefaults。
    @State private var showInstallDiagnosticLog = false
    @State private var showingEnterpriseInstallSuccessAlert = false
    @State private var enterpriseInstallRecord: SignedIPARecord?
    @State private var enterpriseInstallErrorText: String?
    /// 签名段的导入错误（源导入/文件库选择传过来的文件找不到了、
    /// 解析失败时明说，不静默空白；选成功就清掉）。
    @State private var signError: String?
    /// 证书组展开态（签名段顶部）：nil = 自动（未就绪默认展开、就绪默认收起），点标题切换后锁定。
    @State private var certGroupExpanded: Bool? = nil
    // 签名预设（签名段）：只存跨 App 通用的项。
    @State private var presets: [CertSignPreset] = []
    @State private var presetNameText = ""
    @State private var presetMessage: String?
    /// 选中 IPA 的 Info.plist 解析结果：select() 时算一次存下来，
    /// 后续表单重绘直接复用，不再每敲一键就重新解压读盘。
    /// select() 是唯一的选中入口（库里点选、别页传过来都走它），
    /// 取消选中时一并清空，不会残留旧值。
    @State private var selectedInfo: IPALibrary.AppInfo?
    /// 已选 IPA 行图标已尝试集合（文件页应用库同款三件套的本页份，只服务
    /// selectedIPASummary 这一行）。图标本体在共享 ThumbnailCache 里
    /// （A-37-3），重绘由 iconEpoch 触发。
    @State private var unsignedIconsTried: Set<String> = []
    @State private var signedIconsTried: Set<String> = []
    @State private var iconEpoch = 0
    /// A-5(c)：已选 IPA 行图标的批量写回（loadLibraryIcon 同款，懒建）。
    @State private var librarySignedIconBatcher: BatchWriteback<String, UIImage>?
    @State private var libraryUnsignedIconBatcher: BatchWriteback<String, UIImage>?
    /// 已选 IPA 图标指纹缓存（A-1）：只在 selectedIPA 变化时重算，
    /// .task(id:) 读缓存值，不再每 body 求值 stat 磁盘。
    @State private var selectedIPAFingerprint = ""

    private var certReady: Bool { hasP12 && hasProvision && !password.isEmpty }
    /// 证书组收起行缺件状态：三件（p12、描述文件、密码）缺哪件说哪件，
    /// 别笼统报“未就绪”；全齐不会走到这里（certReady 分支已处理）。
    private var certStatusText: String {
        if !hasP12 { return L("未导入证书") }
        if !hasProvision { return L("未导入描述文件") }
        return L("缺密码")
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                signCard(proxy)
                    .padding([.horizontal, .top], 20)
                    .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(AppBackground())
        .navigationTitle(L("企业证书"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshCertState()
            presets = CertSignPresetStore.load()
            if let shared = workspace.selectedIPA {
                select(shared)
                workspace.selectedIPA = nil
            }
        }
        .onChange(of: workspace.selectedIPA) { _, shared in
            if let shared {
                select(shared)
                workspace.selectedIPA = nil
            }
        }
        .onChange(of: engine.isRunning) { old, new in
            // 配对安装跑完：finished 置位才算成功（取消不算）。
            // 失败原因快照到页内本地量：engine 的 lastError 是全局
            // 的，直接读会把别的 tab 的安装失败也显示到这里；取消
            // 时 lastError 是 nil，不记失败、不留错误文本。只认
            // enterpriseInstallInFlight 期间的变化，ID 线的安装
            // 跑完不会误弹到这里。
            if old && !new && enterpriseInstallInFlight {
                // 当前又有安装在跑（isRunning 已翻回 true）：这次
                // 投递是上一次安装的滞后投递，不是当前这跑的结束
                // ——不认、不清，新跑的结束投递随后会来；不清的
                // 话新跑结束时 inFlight 还在，不会丢完成。
                guard !engine.isRunning else { return }
                enterpriseInstallInFlight = false
                // 归属凭证：只认自己那次安装的结束。凭证对不上
                // （别的安装在标志立着时结束）时不记日志、不弹框、
                // 不留旧名额，免得把别人的结果记到这条头上。
                let runID = enterpriseInstallRunID
                enterpriseInstallRunID = nil
                let logAppName = engineInstallLogAppName
                guard runID != nil, runID == engine.installSessionID else {
                    engineInstallLogAppName = nil
                    return
                }
                let logKind = engineInstallLogKind
                if engine.finished {
                    showingEnterpriseInstallSuccessAlert = true
                    localInstall.appendStepLog(L("配对安装完成"))
                    CZFHaptics.notification(.success)
                    if let appName = logAppName {
                        CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                            appName: appName, kind: logKind, success: true,
                            detail: logKind == .installOnly ? L("配对安装完成。") : L("已签好，配对安装完成。")))
                    }
                } else if let error = engine.lastError {
                    enterpriseInstallErrorText = error
                    localInstall.appendStepLog(L("配对安装失败：%@", error))
                    CZFHaptics.notification(.error)
                    if let appName = logAppName {
                        CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                            appName: appName, kind: logKind, success: false,
                            detail: error))
                    }
                }
                // 只清名字、不清 kind：失败后“重试配对安装”复用
                // 同一条记录，kind 留着才能继续记对。
                engineInstallLogAppName = nil
            }
        }
        .alert(L("安装完成"), isPresented: $showingEnterpriseInstallSuccessAlert) {
            Button(L("知道了"), role: .cancel) {}
        } message: {
            Text(L("装好了，可以回桌面查看安装进度。"))
        }
        .sheet(isPresented: $showIPAPicker) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]
            ) { urls in
                if let url = urls.first { select(url) }
            }
        }
        .sheet(isPresented: $showLibraryPicker) {
            LibraryIPAPicker { url in
                select(url)
                showLibraryPicker = false
            }
        }
        .onChange(of: iconItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    mods.icon = data
                }
            }
        }
    }

    /// 证书库列表（证书组最顶上）：一行一张证书，点行切换激活；
    /// 只有一个 profile 时就是一行带“激活”，其余界面照常。
    /// 到期日只读各 profile 自己的描述文件（不用切激活就能算）；
    /// 证书名那栏仍是激活那张的（证书卡里已有）。
    @ViewBuilder
    private var profileGroup: some View {
        signGroup(title: L("证书库")) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(profiles) { profile in
                    HStack(spacing: 8) {
                        if editingProfileID == profile.id {
                            TextField("", text: $editingProfileName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    EnterpriseCertStore.renameProfile(profile, to: editingProfileName)
                                    editingProfileID = nil
                                    profiles = EnterpriseCertStore.profiles()
                                }
                        } else {
                            Button {
                                if profile.id != activeProfileID {
                                    EnterpriseCertStore.setActiveProfile(profile)
                                    refreshCertState()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(profile.name)
                                        .font(.footnote.weight(profile.id == activeProfileID ? .semibold : .regular))
                                        .lineLimit(1)
                                    if profile.id == activeProfileID {
                                        Text(L("激活"))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Theme.positive)
                                    }
                                    if let expiration = profileExpirations[profile.id] {
                                        Text(expiration.formatted(date: .abbreviated, time: .omitted) + remainingText(expiration))
                                            .font(.caption)
                                            .foregroundStyle(expirySoon(expiration) ? Theme.negative : Theme.muted)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            if editingProfileID == profile.id {
                                EnterpriseCertStore.renameProfile(profile, to: editingProfileName)
                                editingProfileID = nil
                                profiles = EnterpriseCertStore.profiles()
                            } else {
                                editingProfileID = profile.id
                                editingProfileName = profile.name
                            }
                        } label: {
                            Text(editingProfileID == profile.id ? L("Done") : L("改名"))
                                .font(.footnote)
                        }
                        .buttonStyle(.bordered)
                        Button(role: .destructive) {
                            deletingProfile = profile
                            showingDeleteProfileAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.footnote)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Button {
                    showNewProfilePicker = true
                } label: {
                    Text(L("导入新证书"))
                }
                .buttonStyle(.bordered)
                Text(L("点一行切换当前证书；新证书导入后要填一次它的密码。"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    /// 新证书导入确认：文件已在 picker 里配对过（p12 + 描述文件
    /// 都有），这里按密码建 profile、切激活；失败只报 importError，
    /// 不建半截 profile（importProfile 写失败自删目录）。
    private func confirmNewProfileImport() {
        guard let p12 = pendingNewProfileP12, let provision = pendingNewProfileProvision else { return }
        do {
            _ = try EnterpriseCertStore.importProfile(p12: p12, provision: provision, p12Password: newProfilePassword)
            importError = nil
        } catch {
            importError = L("证书库导入失败：%@", error.localizedDescription)
        }
        pendingNewProfileP12 = nil
        pendingNewProfileProvision = nil
        newProfilePassword = ""
        refreshCertState()
    }

    /// 证书组内容（原证书段，签名段顶部的证书组展开时显示；标题行
    /// 由证书组自己提供，这里不再另起“证书管理”头）。
    private var certCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            profileGroup
            expiryWarning
            if let info = provisionInfo {
                signGroup(title: L("描述文件")) {
                    VStack(alignment: .leading, spacing: 8) {
                        infoRow(L("描述文件"), info.name.isEmpty ? L("（无名称）") : info.name)
                        if !info.teamName.isEmpty {
                            infoRow(L("Team"), info.teamName)
                        }
                        if let expiration = info.expiration {
                            HStack {
                                Text(L("到期"))
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                Text(expiration.formatted(date: .abbreviated, time: .omitted) + remainingText(expiration))
                                    .foregroundStyle(expirySoon(expiration) ? Theme.negative : .primary)
                            }
                            .font(.footnote)
                        }
                        // 轻松签式设备提示：描述文件限定了设备时，拿本机 UDID
                        //（MGCopyAnswer，轻松签同款办法）跟列表比对，能断言
                        // 就断言；读不到 UDID 或列表为空才回落到只提示台数。
                        // 企业证书通常不限设备，这一行也就不出现。
                        if info.provisionedDeviceCount > 0 {
                            if let udid = Self.localDeviceUDID, !info.provisionedDevices.isEmpty {
                                if info.provisionedDevices.contains(udid) {
                                    Text(L("本机在描述文件设备列表里，签名后能装。"))
                                        .font(.footnote)
                                        .foregroundStyle(Theme.positive)
                                } else {
                                    Text(L("此签名证书不包含当前设备，签名后无法在当前设备安装！！！"))
                                        .font(.footnote)
                                        .foregroundStyle(Theme.negative)
                                }
                                Text(udid)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(Theme.muted)
                                    .textSelection(.enabled)
                            } else {
                                Text(L("描述文件限定了设备（共 %d 台）：如果是开发证书且本机不在列表里，签名后装不上；企业证书通常不限设备。", info.provisionedDeviceCount))
                                    .font(.footnote)
                                    .foregroundStyle(Theme.warning)
                            }
                        }
                    }
                }
            }
            if let cert = certInfo, !cert.name.isEmpty {
                signGroup(title: L("Certificates")) {
                    VStack(alignment: .leading, spacing: 8) {
                        infoRow(L("Certificates"), cert.name)
                        if let expiration = cert.expiration {
                            infoRow(L("证书到期日"), "\(expiration.formatted(date: .abbreviated, time: .omitted))\(remainingText(expiration))")
                        }
                    }
                }
            }
            // 吊销状态：手动刷新，系统信任评估联网查（OCSP）。
            // 查不出来（离线、链不全）不报假警告，只显示查不出来。
            signGroup(title: L("吊销状态")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(L("吊销状态"))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                        Text(revocationText)
                            .font(.footnote)
                            .foregroundStyle(revocationColor)
                        Spacer()
                        Button {
                            checkRevocation()
                        } label: {
                            Text(revocationChecking ? L("检查中…") : L("检查吊销状态"))
                                .font(.footnote)
                        }
                        .buttonStyle(.bordered)
                        .disabled(revocationChecking || !hasP12)
                    }
                    if revocationStatus == .revoked {
                        Text(L("证书已经掉签，签名后可能无法安装。"))
                            .font(.footnote)
                            .foregroundStyle(Theme.negative)
                    }
                    if let checked = revocationCheckedAt {
                        Text(L("上次检查：%@", checked.formatted(date: .abbreviated, time: .shortened)))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            signGroup(title: L("导入证书")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Button {
                            showP12Picker = true
                        } label: {
                            Text(hasP12 ? L("证书已导入 ✓") : L("导入 .p12 证书"))
                        }
                        Button {
                            showProvisionPicker = true
                        } label: {
                            Text(hasProvision ? L("描述文件已导入 ✓") : L("导入描述文件"))
                        }
                    }
                    .buttonStyle(.bordered)
                    // 轻松签式“导入证书库”：一次选 .p12 + 描述文件两个，
                    // 配对才进；缺描述文件按轻松签原文报错（单导 p12 走上面）。
                    HStack(spacing: 10) {
                        Button {
                            showCertLibraryPicker = true
                        } label: {
                            Text(L("导入证书库"))
                        }
                    }
                    .buttonStyle(.bordered)
                    Text(L("证书库一次选 .p12 和描述文件两个，配不上会报错；单导 p12 走上面那个按钮。"))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            // 导出给 LiveContainer：只发 .p12 文件和描述文件本身，
            // 密码不一起导出，LiveContainer 导入时再填一次密码。
            // 这样同一张企业证书不用再找原文件就能在另一边用。
            if hasP12 || hasProvision {
                signGroup(title: L("导出证书")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            if hasP12 {
                                ShareLink(item: EnterpriseCertStore.p12URL) {
                                    Label(L("Export certificate (p12)"), systemImage: "square.and.arrow.up")
                                }
                            }
                            if hasProvision {
                                ShareLink(item: EnterpriseCertStore.provisionURL) {
                                    Label(L("导出描述文件"), systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                        .font(.footnote)
                        Text(L("导出后可在 LiveContainer 里导入同一张证书，不用再找原文件；密码不一起导出，导入时再填一次。"))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if certReady {
                Text(L("企业证书装完后，首次打开 App 前要去「设置 → 通用 → VPN 与设备管理」信任这张证书。"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            signGroup(title: L("证书密码")) {
                SecureField(L("证书密码"), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: password) { _, newValue in
                        EnterpriseCertStore.password = newValue
                    }
                    .onSubmit {
                        // 密码输完回车才刷新证书信息：每敲一下都解一次 p12 没必要。
                        refreshCertState()
                    }
            }
            if let certPasswordError {
                Text(certPasswordError)
                    .font(.footnote)
                    .foregroundStyle(Theme.negative)
            }
            if let importError {
                Text(importError)
                    .font(.footnote)
                    .foregroundStyle(Theme.negative)
            }
            if hasP12 || hasProvision {
                Button(role: .destructive) {
                    confirmingRemoveCert = true
                } label: {
                    Text(L("移除证书材料"))
                        .font(.footnote)
                }
            }
        }
        .alert(L("移除证书材料？"), isPresented: $confirmingRemoveCert) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Remove"), role: .destructive) {
                EnterpriseCertStore.removeAll()
                password = ""
                refreshCertState()
            }
        } message: {
            Text(L("会删掉已导入的 .p12、描述文件和保存的密码，之后要重新导入才能签名。"))
        }
        .sheet(isPresented: $showP12Picker) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data]
            ) { urls in
                if let url = urls.first {
                    do {
                        try EnterpriseCertStore.importP12(from: url)
                        importError = nil
                    } catch {
                        importError = L("证书导入失败：%@", error.localizedDescription)
                    }
                    refreshCertState()
                }
            }
        }
        .sheet(isPresented: $showProvisionPicker) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType(filenameExtension: "mobileprovision") ?? .data]
            ) { urls in
                if let url = urls.first {
                    do {
                        try EnterpriseCertStore.importProvision(from: url)
                        importError = nil
                    } catch {
                        importError = L("描述文件导入失败：%@", error.localizedDescription)
                    }
                    refreshCertState()
                }
            }
        }
        .sheet(isPresented: $showCertLibraryPicker) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data,
                                      UTType(filenameExtension: "mobileprovision") ?? .data],
                allowsMultipleSelection: true
            ) { urls in
                importCertLibrary(urls)
            }
        }
        // 新证书导入：先选 p12 + 描述文件（配对才进，跟导入证书库
        // 同一套报错），再弹密码框——密码用来给新 profile 定默认名
        //（证书名）和写进它自己的钥匙串 account；取消就不建 profile。
        .sheet(isPresented: $showNewProfilePicker) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data,
                                      UTType(filenameExtension: "mobileprovision") ?? .data],
                allowsMultipleSelection: true
            ) { urls in
                let p12 = urls.first { $0.pathExtension.lowercased() == "p12" }
                let provision = urls.first { $0.pathExtension.lowercased() == "mobileprovision" }
                guard let p12, let provision else {
                    importError = L("未找到与本证书相匹配的mobileprovision文件，请将mobileprovision文件放在与p12文件相同的目录下。")
                    return
                }
                pendingNewProfileP12 = p12
                pendingNewProfileProvision = provision
                newProfilePassword = ""
                showingNewProfilePasswordAlert = true
            }
        }
        .alert(L("新证书密码"), isPresented: $showingNewProfilePasswordAlert) {
            SecureField(L("证书密码"), text: $newProfilePassword)
            Button(L("Import")) {
                confirmNewProfileImport()
            }
            Button(L("Cancel"), role: .cancel) {
                pendingNewProfileP12 = nil
                pendingNewProfileProvision = nil
                newProfilePassword = ""
            }
        } message: {
            Text(L("输入这张 .p12 的密码，导完就切到这张证书。"))
        }
        .alert(L("删除证书？"), isPresented: $showingDeleteProfileAlert) {
            Button(L("Cancel"), role: .cancel) {
                deletingProfile = nil
            }
            Button(L("Delete"), role: .destructive) {
                if let profile = deletingProfile {
                    EnterpriseCertStore.removeProfile(profile)
                    deletingProfile = nil
                    refreshCertState()
                }
            }
        } message: {
            Text(L("会删掉这张证书的 .p12、描述文件和保存的密码；删的是当前激活的那张时，自动切到另一张。"))
        }
        // 回环兜底：回环起不来时 server 置 unavailableMessage，
        // 这里弹框；点了“改用配对安装”才走 Engine，绝不静默回落。
        .onChange(of: otaServer.unavailableMessage) { _, message in
            if let message {
                loopbackFailureText = message
                showingLoopbackFallbackAlert = true
            }
        }
        .alert(L("本机回环安装起不来"), isPresented: $showingLoopbackFallbackAlert) {
            Button(L("改用配对安装")) {
                if let record = enterpriseInstallRecord {
                    startEngineInstall(record: record)
                }
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(loopbackFailureText ?? "")
        }
    }

    /// 轻松签式“导入证书库”：一次选 .p12 + 描述文件，配对才进；
    /// 只给一个（缺描述文件）就按轻松签原文报错，不单吞 p12
    ///（单导 p12 走上面那个“导入 .p12 证书”按钮）。多选了几个
    /// 时只取每种的第一个，不猜配对。
    private func importCertLibrary(_ urls: [URL]) {
        let p12 = urls.first { $0.pathExtension.lowercased() == "p12" }
        let provision = urls.first { $0.pathExtension.lowercased() == "mobileprovision" }
        guard let p12, let provision else {
            importError = L("未找到与本证书相匹配的mobileprovision文件，请将mobileprovision文件放在与p12文件相同的目录下。")
            return
        }
        // 双文件导入原子化（见 S9）：p12 先换、描述文件失败时
        // 以前是半新半旧（新 p12 + 旧描述文件），下次签名才以
        // 配对不上暴露。先备份旧 p12（KB 级，放内存无妨），第
        // 二步失败时把 p12 滚回旧值；描述文件自身 atomic 写盘，
        // 失败时原文件不动，无需回滚；p12 自身失败时描述文件
        // 根本没动。回滚写盘本身若也失败是磁盘级故障，只能
        // best-effort，原错照常报，不静默吞掉。
        let fm = FileManager.default
        let oldP12 = try? Data(contentsOf: EnterpriseCertStore.p12URL)
        do {
            try EnterpriseCertStore.importP12(from: p12)
            do {
                try EnterpriseCertStore.importProvision(from: provision)
            } catch {
                if let oldP12 {
                    try? oldP12.write(to: EnterpriseCertStore.p12URL, options: .atomic)
                } else {
                    try? fm.removeItem(at: EnterpriseCertStore.p12URL)
                }
                throw error
            }
            importError = nil
            // 导入时就比对配对：对不上就地报错，不要等到签名才发现。
            // p12 解不开（比如密码不对）时查不出来，不在这里重复报错，
            // 密码那档由 refreshCertState 的解锁校验明说。
            if EnterpriseCertStore.certMatchesProvision == false {
                importError = L("描述文件里的证书和已导入的 .p12 对不上，签出来的包装上去也装不上，先换一张和这张证书配对的描述文件。")
            }
        } catch {
            importError = L("证书库导入失败：%@", error.localizedDescription)
        }
        refreshCertState()
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.footnote)
    }

    /// 剩余天数：按自然日对齐（与已装 App 页 AppsView.daysRemaining
    /// 同一套算法，见 S7）。旧算法 dateComponents(from: Date(),
    /// to: expiry) 按不足 24 小时截断，同一到期日在企业页算 0
    /// 天、在 App 页算 1 天，两边说法打架；自然日对齐后“1 =
    /// tomorrow”，到期当天算 0 天（显示“今天到期”）。
    private func remainingDays(to expiration: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: expiration)).day ?? 0
    }

    private func remainingText(_ expiration: Date) -> String {
        let days = remainingDays(to: expiration)
        if days < 0 { return L(" (expired)") }
        if days == 0 { return L("（今天到期）") }
        return L("（剩 %d 天）", days)
    }

    /// 签前到期警告（7 天内到期，只警告不拦截；已过期走 S4
    /// 拦截，不在这里重复报）：复用 S7 的 remainingDays（startOfDay
    /// 自然日）。单签与批量共用同一句，批量一次运行只拼一次。
    private func expiryWarningText() -> String? {
        var parts: [String] = []
        let now = Date()
        if let expiration = certInfo?.expiration, expiration >= now {
            let days = remainingDays(to: expiration)
            if days <= 7 {
                parts.append(days == 0 ? L("证书今天到期") : L("证书 %d 天后到期", days))
            }
        }
        if let expiration = provisionInfo?.expiration, expiration >= now {
            let days = remainingDays(to: expiration)
            if days <= 7 {
                parts.append(days == 0 ? L("描述文件今天到期") : L("描述文件 %d 天后到期", days))
            }
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "，") + L("，仍要签名吗？")
    }

    /// 剩余天数 ≤7 天（已过期也算）即提醒；跟 remainingText 同一套算法。
    private func expirySoon(_ expiration: Date) -> Bool {
        remainingDays(to: expiration) <= 7
    }

    /// 描述文件 7 天内到期（或已过期）时证书管理顶部的红条：
    /// 按 provisionInfo.expiration 实际日期算，永不硬编码。
    /// 纯展示——企业证书 App 内续不了，只能重新导入，所以不给动作。
    /// 证书本身同样亮红条：以前只看描述文件，证书过期时这里
    /// 一声不吭（校验也不拦，见 S4），两条各亮各的、不合并。
    @ViewBuilder
    private var expiryWarning: some View {
        if let expiration = provisionInfo?.expiration, expirySoon(expiration) {
            CalloutCard(tint: Theme.negative) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.negative)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(expiration < Date() ? L("描述文件已过期") : L("描述文件快到期了"))
                            .font(.subheadline.weight(.semibold))
                        Text(expiration < Date()
                             ? L("签出来的包装上去也是闪退。先换一张没过期的描述文件，重新导入。")
                             : L("到期日 %@%@，请及时重新导入。", expiration.formatted(date: .abbreviated, time: .omitted), remainingText(expiration)))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        if let expiration = certInfo?.expiration, expirySoon(expiration) {
            CalloutCard(tint: Theme.negative) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.negative)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(expiration < Date() ? L("证书已过期") : L("证书快到期了"))
                            .font(.subheadline.weight(.semibold))
                        Text(expiration < Date()
                             ? L("签出来的包装上去也是闪退。先换一张没过期的证书，重新导入。")
                             : L("到期日 %@%@，请及时重新导入。", expiration.formatted(date: .abbreviated, time: .omitted), remainingText(expiration)))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func refreshCertState() {
        hasP12 = EnterpriseCertStore.hasP12
        hasProvision = EnterpriseCertStore.hasProvision
        // 多证书库：列表、激活、密码（密码 @State 跟着激活走，
        // 切 profile 后这里重读新 profile 的密码；onChange 写回
        // 的是同一个值，无害）。
        profiles = EnterpriseCertStore.profiles()
        activeProfileID = EnterpriseCertStore.activeProfile(profiles: profiles)?.id
        password = EnterpriseCertStore.password
        // A1+A2：证书解析（读 p12 + SecPKCS12Import + 全量 plist 解析）是主线程
        // 上的重活，9 个调用点每次都同步重跑。指纹没变时跳过重解析——材料
        // 没变，解析结果也不会变；变了才在后台重解析，解析完回主线程写
        // @State。写回时指纹/密码/激活三者须与调用时一致，防切走后旧结果
        // 盖住新表单；两个解析中途的写回内容相同，无害。
        let fingerprint = EnterpriseCertStore.certStateFingerprint(profiles: profiles)
        let storePassword = EnterpriseCertStore.password
        let activeID = activeProfileID
        let currentProfiles = profiles
        // 材料没变、密码没变，解析结果也不会变——跳过重解析（@State 里已是
        // 这批文件 + 这个密码的结果）。密码只在回车提交时才触发 refresh，
        // 所以密码变了一定会进解析，密码错提示不会被跳过。
        guard fingerprint != certParsedFingerprint || storePassword != certParsedPassword else { return }
        Task.detached(priority: .userInitiated) {
            let provision = EnterpriseCertStore.provisionInfo
            let cert = EnterpriseCertStore.certInfo
            let passwordOK = (try? EnterpriseCertStore.identityDERs()) != nil
            var expirations: [UUID: Date] = [:]
            for profile in currentProfiles {
                if let expiration = EnterpriseCertStore.provisionInfo(for: profile)?.expiration {
                    expirations[profile.id] = expiration
                }
            }
            await MainActor.run {
                guard fingerprint == EnterpriseCertStore.certStateFingerprint(profiles: currentProfiles),
                      storePassword == EnterpriseCertStore.password,
                      activeID == EnterpriseCertStore.activeProfile(profiles: currentProfiles)?.id
                else { return }
                self.provisionInfo = provision
                self.certInfo = cert
                self.profileExpirations = expirations
                self.certParsedFingerprint = fingerprint
                self.certParsedPassword = storePassword
                // 密码错不要等到签名才说：p12 解不开就在密码组下红字明说。
                // 只在已导入 p12 时校验；没导入、或解得开，都不提示。
                if self.hasP12, !passwordOK {
                    self.certPasswordError = L("密码错误，请重新输入")
                } else {
                    self.certPasswordError = nil
                }
            }
        }
    }

    private var revocationText: String {
        switch revocationStatus {
        case .revoked: return L("已掉签")
        case .ok: return L("未发现掉签")
        case .unknown: return revocationCheckedAt == nil ? L("未检查") : L("查不出来")
        }
    }

    private var revocationColor: Color {
        switch revocationStatus {
        case .revoked: return Theme.negative
        case .ok: return Theme.positive
        case .unknown: return Theme.muted
        }
    }

    /// 吊销检查放后台线程跑（信任评估可能联网 OCSP）。
    /// 手动按钮：每次都真查（force），不读 A-6 的 24 小时缓存。
    private func checkRevocation() {
        guard !revocationChecking, hasP12 else { return }
        revocationChecking = true
        // 照抄 refreshCertState 的三重守卫模式：调用前抓指纹，
        // 写回前核对未变才写状态；revocationChecking 复位放守卫外，
        // 任何出口都复位。
        let profiles = EnterpriseCertStore.profiles()
        let fingerprint = EnterpriseCertStore.certStateFingerprint(profiles: profiles)
        Task.detached(priority: .userInitiated) {
            let status = CertRevocationChecker.check(force: true)
            await MainActor.run {
                if fingerprint == EnterpriseCertStore.certStateFingerprint(profiles: profiles) {
                    self.revocationStatus = status
                    self.revocationCheckedAt = Date()
                }
                self.revocationChecking = false
            }
        }
    }

    /// 轻松签签名页式分组：标题是卡片上面一行小灰字，内容在卡片里
    ///（PanelCard 的 content 本来就是 @ViewBuilder，组内多行、单行
    /// 都行，不触发普通函数多类型分支问题）。
    private func signGroup<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            PanelCard {
                content()
            }
        }
    }

    /// “选择证书”行显示的当前证书：证书名 + 团队 ID（轻松签签名页
    /// 同款格式）；都没导入就明说去证书组导入，点行展开上方证书组。
    private var certRowText: String {
        if let name = certInfo?.name, !name.isEmpty {
            if let teamID = provisionInfo?.teamID, !teamID.isEmpty {
                return "\(name) (\(teamID))"
            }
            return name
        }
        if let name = provisionInfo?.name, !name.isEmpty {
            return name
        }
        return L("未导入，去上方证书组导入")
    }

    /// “打包文件名”行空着时回落的输出名：源文件主名 +“-已签.ipa”
    ///（改名只改包内名字，不改输出文件名；填了自定义名则以
    /// 自定义名为主名；重名时签名那一刻自动加序号，见 uniqueOutputURL）。
    private var predictedOutputName: String {
        guard let url = selectedIPA else { return "" }
        // 源文件本身已是签过的（主名尾带“-已签”）就不再重复加，
        // 否则占位与实际输出都会成“X-已签-已签.ipa”。
        return "\(SignedIPAStore.stripSignedSuffix(url.deletingPathExtension().lastPathComponent))-已签.ipa"
    }

    /// 打包文件名组下面明说的实际输出名：手填了就按手填的
    /// （没写 .ipa 也补上显示），空着就是推导名。占位灰字
    /// 容易被当成“已经填好了”，这行才是准话；重名仍在签名
    /// 那一刻自动加序号（见 uniqueOutputURL）。
    private var effectiveOutputName: String {
        let custom = mods.outputName.trimmingCharacters(in: .whitespaces)
        if !custom.isEmpty {
            return custom.lowercased().hasSuffix(".ipa") ? custom : "\(custom).ipa"
        }
        return predictedOutputName
    }

    /// 签名段：轻松签签名页式分组列表（v68 UI）。分组标题 + 行：
    /// App 名字 / Bundle Identifier / 版本号 / 最低系统版本 /
    /// 新图标 / 签名后立即安装（开关行）/ 选择证书 / 打包文件名；
    /// 底部两个通栏大按钮：大红“立即签名”、大蓝“更多设置”。
    /// 功能一个不少，只是换版式：框里还是原值、改了才生效；
    /// 预设/插件注入/多开/仅签名收进“更多设置”里，点蓝按钮展开。
    /// 步骤进度/诊断日志/安装状态/提示文案位置跟原来一样，在按钮下面。
    private func signCard(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 证书组（原证书段整体搬进签名段顶部）：未就绪默认展开、
            // 就绪默认收起只留状态行，点标题切换。组 id 供“选择证书”
            // 点开后滚回顶部用（组在视口外时展开了也看不见）。
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    certGroupExpanded = !(certGroupExpanded ?? !certReady)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(certReady ? Theme.muted : Theme.warning)
                        Text(L("Certificates"))
                            .font(.headline)
                        Spacer()
                        if certReady {
                            if let name = certInfo?.name, !name.isEmpty {
                                Text(name)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                            }
                            if let expiration = certInfo?.expiration ?? provisionInfo?.expiration {
                                Text(expiration.formatted(date: .abbreviated, time: .omitted) + remainingText(expiration))
                                    .font(.footnote)
                                    .foregroundStyle(expirySoon(expiration) ? Theme.negative : Theme.muted)
                            }
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.positive)
                        } else {
                            // 收起时也明说到底缺哪一件，别只给一句“未就绪”
                            // 让用户自己展开去猜（轻松签式一眼看全）。
                            Text(certStatusText)
                                .font(.footnote)
                                .foregroundStyle(Theme.warning)
                        }
                        Image(systemName: (certGroupExpanded ?? !certReady) ? "chevron.up" : "chevron.down")
                            .foregroundStyle(Theme.muted)
                            .font(.footnote)
                    }
                }
                .buttonStyle(.plain)
                if certGroupExpanded ?? !certReady {
                    certCard
                }
            }
            .id("certGroup")
            // 证书组与下面签名表单的分界线：收起时只留状态行，分界线
            // 让“证书组到此结束”一眼看出来，展开时同样适用。
            Divider()
            // 导入失败明说（源导入/文件库选择的文件找不到了时）：
            // 段内绝不静默空白——有错就露出来，进口按钮就在下面。
            if let signError {
                Text(signError)
                    .font(.footnote)
                    .foregroundStyle(Theme.negative)
            }
            if let url = selectedIPA {
                PanelCard {
                    selectedIPASummary(url)
                }
                signGroup(title: L("App 名字")) {
                    TextField(selectedInfo?.name ?? "", text: $mods.name)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                signGroup(title: L("Bundle Identifier")) {
                    TextField(selectedInfo?.bundleID ?? "", text: $mods.bundleID)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                signGroup(title: L("版本号")) {
                    TextField(selectedInfo?.version ?? "", text: $mods.version)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                signGroup(title: L("最低系统版本")) {
                    TextField(L("如 15.0"), text: $mods.minOS)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                signGroup(title: L("新图标")) {
                    iconRow
                }
                signGroup(title: L("签名后立即安装")) {
                    // 开 = 签完直接走配对安装，关 = 只签存已签名；
                    // 跟原来 Toggle 同例，只是挪进分组行里。
                    // 组标题已显示，Toggle 标签只留无障碍，不再上下重复。
                    Toggle(L("签名后立即安装"), isOn: $installWhenSign).labelsHidden()
                }
                signGroup(title: L("选择证书")) {
                    Button {
                        certGroupExpanded = true
                        // 证书组在表单顶部，滚下去点这行时展开发生在
                        // 视口外、看着像没反应：直接滚回组顶。
                        Task { @MainActor in
                            withAnimation { proxy.scrollTo("certGroup", anchor: .top) }
                        }
                    } label: {
                        HStack {
                            Text(certRowText)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.muted)
                                .font(.footnote)
                        }
                    }
                    .buttonStyle(.plain)
                }
                signGroup(title: L("打包文件名")) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(predictedOutputName, text: $mods.outputName)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Text(L("将保存为：%@；重名自动加序号", effectiveOutputName))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                // 轻松签式脱壳提示：选好 IPA 就预检，加密的直接在
                // 表单上提示（签时 startSign 还会再算一次 gate）。
                // 多 .app 时逐个报名字（见 SS2）；名字还没算出来
                // 时退回固定文案，不空着。
                if let cryptid = selectedCryptid, cryptid != 0 {
                    Text(selectedUndumpedApps.isEmpty
                         ? L("程序未脱壳，签名后可能无法安装，建议重新脱壳签名。")
                         : L("以下程序未脱壳，签名后可能无法安装，建议重新脱壳签名：%@", selectedUndumpedApps.joined(separator: "、")))
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }
                // 底部两个通栏大按钮（轻松签签名页同款层级）：主按钮
                // 大红实心（走开关：开 = 签名并安装，关 = 仅签名），
                // 次按钮蓝色浅底（展开预设/插件/多开/瘦身/仅签名）。
                // 按压态走 CZFPressButtonStyle（plain 样式按着没反馈，
                // 看着像没点）；前置条件不满足时按钮不直接禁用——点
                // 了必在正下方红字明说原因（批量签名同例），绝不静默。
                // 半透明只是“现在签不了”的视觉提示，不是禁用。
                Button {
                    CZFHaptics.impact(.medium)
                    signFromMainButton(kind: installWhenSign ? .signAndInstall : .signOnly, proxy: proxy)
                } label: {
                    HStack {
                        if workspace.signBusy { ProgressView().tint(.white) }
                        Text(L("立即签名"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.negative)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                    .shadow(color: Theme.negative.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(CZFPressButtonStyle())
                .opacity(workspace.signBusy || engine.isRunning || !certReady ? 0.5 : 1)
                // 按钮正下方的实时状态行（轻松签式一眼看全，优先级
                // 从高到低）：点按被拦的原因 > 正在签名 > 正在安装
                // 的阶段 > 安装失败原因 > 签名结果。原来结果/缺件
                // 提示在诊断日志下面、要翻到底才看见，现挪到这里。
                if let signBlockedMessage {
                    Text(signBlockedMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.negative)
                } else if workspace.signBusy {
                    Text(L("正在签名，请稍候…"))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                } else if enterpriseInstallInFlight {
                    Text(installStageText)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                } else if let error = enterpriseInstallErrorText {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.negative)
                } else if let signOnlyMessage {
                    Text(signOnlyMessage)
                        .font(.footnote)
                        .foregroundStyle(signOnlyFailed ? Theme.negative : Theme.positive)
                }
                // 多开与立即安装静默冲突提示：多开只对“仅签名”生效，
                // 开着“签名后立即安装”时红按钮只签装 1 个——这句以前
                // 只藏在默认收起的更多设置里，红按钮处直接说明，
                // 免得在按钮上踩坑。只加提示，不改签名行为。
                if installWhenSign && multiCount > 1 {
                    Text(L("已开“签名后立即安装”，这次只签装 1 个，多开数量不生效；要签多个请关掉安装开关或用“仅签名”。"))
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }
                Button {
                    CZFHaptics.impact(.light)
                    showMoreSettings.toggle()
                } label: {
                    HStack {
                        Text(L("更多设置"))
                            .font(.headline)
                        Image(systemName: showMoreSettings ? "chevron.up" : "chevron.down")
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.accent.opacity(0.12))
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(16)
                }
                .buttonStyle(CZFPressButtonStyle())
                if showMoreSettings {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 12) {
                            presetSection
                            Divider()
                            pluginSection
                            Divider()
                            multiOpenSection
                            Divider()
                            slimSection
                            Divider()
                            Button {
                                CZFHaptics.impact(.medium)
                                signFromMainButton(kind: .signOnly, proxy: proxy)
                            } label: {
                                HStack {
                                    if workspace.signBusy { ProgressView() }
                                    Text(L("仅签名（存到已签名）"))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .opacity(workspace.signBusy || engine.isRunning || !certReady ? 0.5 : 1)
                            if let signBlockedMessage {
                                Text(signBlockedMessage)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.negative)
                            }
                        }
                    }
                    .id("moreSettingsPanel")
                }
                enterpriseInstallStatus
                enterpriseStepProgress
                installDiagnosticLogSection
            } else {
                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("选一个 IPA，可以先改名称、Bundle ID、版本、最低系统版本和图标，再用企业证书签名。"))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                        HStack(spacing: 10) {
                            Button {
                                showIPAPicker = true
                            } label: {
                                Text(L("从文件导入"))
                            }
                            Button {
                                showLibraryPicker = true
                            } label: {
                                Text(L("从文件库选择"))
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .sheet(isPresented: $showPluginPicker) {
            FileImporterRepresentableView(
                allowedContentTypes: [.item]
            ) { urls in
                for url in urls {
                    if let staged = CertPluginStore.stage(url) {
                        mods.plugins.append(staged)
                        pluginError = nil
                    } else {
                        pluginError = L("插件只支持 .dylib / .deb / .zip")
                    }
                }
            }
        }
        .alert(L("签名提醒"), isPresented: $showingWarningAlert) {
            Button(L("继续签名")) {
                if let kind = pendingSignKind, let url = pendingSignURL {
                    executeSign(kind: kind, url: url, mods: pendingSignMods)
                }
                clearPendingSign()
            }
            Button(L("Cancel"), role: .cancel) {
                clearPendingSign()
            }
        } message: {
            Text(pendingWarnings.joined(separator: "\n"))
        }
        // 更多设置展开后滚到面板顶（按钮在屏底时展开发生在视口外，
        // 看着像没反应）；前置条件一满足就清掉按钮下的拦阻提示。
        .onChange(of: showMoreSettings) { _, expanded in
            if expanded {
                Task { @MainActor in
                    withAnimation { proxy.scrollTo("moreSettingsPanel", anchor: .top) }
                }
            }
        }
        .onChange(of: engine.isRunning || !certReady) { _, blocked in
            if !blocked { signBlockedMessage = nil }
        }
    }

    /// 多开：数量与起始序号。iOS 不给 App 装完回调，逐个自动
    /// 安装做不出来，所以多开只对「仅签名」生效：一次签出 N 个
    /// 副本（Bundle ID 加 .序号区分，名字也加序号），装的时候
    /// 去「已签名」里逐个点安装。数量上限 20，防手滑签一堆。
    private var multiOpenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(L("多开"))
                    .font(.footnote)
                    .frame(width: 92, alignment: .leading)
                Text(L("数量"))
                    .font(.footnote)
                TextField("1", text: $multiCountText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.footnote)
                    .frame(width: 52)
                    .disabled(workspace.signBusy)
                Text(L("起始序号"))
                    .font(.footnote)
                TextField("1", text: $multiStartText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.footnote)
                    .frame(width: 52)
                    .disabled(workspace.signBusy)
                Spacer()
            }
            if multiCount > 1 {
                Text(L("会签出 %d 个副本（Bundle ID 加 .序号区分），多开只对「仅签名」生效；开着「签名后立即安装」时「开始签名」仍只签 1 个。", multiCount))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                Text(L("可选：一次签出多个副本，装到桌面上互不冲突。"))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            // 非法输入以前静默按边界算（“abc”变 1、“99”变 20），
            // 用户不知道自己填错了：非空非法时橙字明说。正在
            // 输入中途（清空了还没填完）不提示，别闪。
            if multiCountTextInvalid {
                Text(L("数量填 1–20 的数字，超出按边界算。"))
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
    }

    /// 多开数量输入是否非法：空着是输入中途，不算；非数字、
    /// 小于 1、大于 20 都算（multiCount 会静默 clamp）。
    private var multiCountTextInvalid: Bool {
        guard !multiCountText.isEmpty else { return false }
        guard let n = Int(multiCountText) else { return true }
        return n < 1 || n > 20
    }

    /// 瘦身与兼容（签名时先改包再签，默认全关）：删 Watch 应用
    /// 与扩展插件能减小体积、去掉设备限制让 iPad 等设备也能装；
    /// 改包只删东西，不动签名流程本身，改坏直接报错不签。
    /// 批量/多开同样带上（走同一份 mods）；不进预设，换 IPA 即清。
    private var slimSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(L("去掉 Watch 应用（瘦身）"), isOn: $mods.stripWatch)
                .font(.footnote)
            Toggle(L("去掉扩展插件（瘦身）"), isOn: $mods.stripExtensions)
                .font(.footnote)
            Toggle(L("去掉设备限制（兼容）"), isOn: $mods.stripDeviceLimits)
                .font(.footnote)
            Text(L("签名时先改包再签：删 Watch / 扩展能减小体积，去设备限制让更多设备能装；顺手清掉包里 .DS_Store 等垃圾。"))
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var multiCount: Int { max(1, min(20, Int(multiCountText) ?? 1)) }
    private var multiStart: Int { max(1, min(999, Int(multiStartText) ?? 1)) }

    /// 签名预设：存跨 App 通用的项（插件、最低系统版本、多开），
    /// 名字/Bundle ID/版本是每 App 自己的，不进预设。
    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(L("预设"))
                    .font(.footnote)
                    .frame(width: 92, alignment: .leading)
                TextField(L("新预设名称"), text: $presetNameText)
                    .textFieldStyle(.roundedBorder)
                    .font(.footnote)
                Button(L("Save")) { saveCurrentPreset() }
                    .font(.footnote)
                    .disabled(presetNameText.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            if presets.isEmpty {
                Text(L("把常用的插件、最低系统版本、多开数量存成预设，下次直接套用（名字、Bundle ID、版本是每 App 自己的，不进预设）。"))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(presets) { preset in
                    HStack(spacing: 8) {
                        Button { applyPreset(preset) } label: {
                            Text(preset.name)
                                .font(.footnote)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button { removePreset(preset) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.muted)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let presetMessage {
                Text(presetMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func saveCurrentPreset() {
        let name = presetNameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        _ = CertSignPresetStore.save(name: name, minOS: mods.minOS,
            multiCount: multiCount, multiStart: multiStart,
            icon: mods.icon, pluginURLs: mods.plugins)
        presets = CertSignPresetStore.load()
        presetNameText = ""
        presetMessage = L("预设“%@”已保存。", name)
    }

    private func applyPreset(_ preset: CertSignPreset) {
        // 先清掉表单里已暂存的插件（跟换 IPA 时 resetMods 同例），
        // 再把预设的插件文件重新暂存一份进表单（预设原件不动）。
        for url in mods.plugins { CertPluginStore.remove(url) }
        mods.plugins = []
        var staged: [URL] = []
        for url in CertSignPresetStore.pluginURLs(for: preset) {
            if let stagedURL = CertPluginStore.stage(url) { staged.append(stagedURL) }
        }
        mods.plugins = staged
        mods.minOS = preset.minOS
        mods.icon = preset.icon
        iconItem = nil
        multiCountText = String(preset.multiCount)
        multiStartText = String(preset.multiStart)
        presetMessage = L("已套用预设“%@”。", preset.name)
    }

    private func removePreset(_ preset: CertSignPreset) {
        CertSignPresetStore.remove(preset)
        presets = CertSignPresetStore.load()
    }

    /// 插件注入：选好的插件（dylib/deb/zip）在签名之前注进
    /// App，不选就是不注入。
    private var pluginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(L("插件注入"))
                    .font(.footnote)
                    .frame(width: 92, alignment: .leading)
                Button {
                    showPluginPicker = true
                } label: {
                    Text(L("添加插件"))
                        .font(.footnote)
                }
                Spacer()
            }
            if mods.plugins.isEmpty {
                Text(L("可选：.dylib / .deb / .zip，签名前注入"))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(mods.plugins, id: \.path) { url in
                    HStack(spacing: 8) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Text(url.lastPathComponent)
                            .font(.footnote)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            mods.plugins.removeAll { $0 == url }
                            CertPluginStore.remove(url)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.muted)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let pluginError {
                Text(pluginError)
                    .font(.footnote)
                    .foregroundStyle(Theme.negative)
            }
        }
    }

    /// 应用库行图标：IPA 里取的真实图标（大圆角 52pt）；还没取到或
    /// 取不到时显示中性灰圆角方块（不是假 App 图，只占位）。
    @ViewBuilder
    private func libraryIcon(for path: String, signed: Bool) -> some View {
        // A-37-3：读 iconEpoch 建立依赖——图标本体在共享缓存里，
        // 批量写回只 bump epoch、不写 @State；不读它，body 不会
        // 重算，图就永远不出现。别把这行当死代码清掉。
        let _ = iconEpoch
        if let image = ThumbnailCache.image(for: path) {
            Image(uiImage: image)
                .resizable()
                .frame(width: 60, height: 60)
                .cornerRadius(13)
        } else {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 60, height: 60)
        }
    }

    /// 行内图标加载（只取可见行，行 .task 触发）：key 已尝试直接跳过
    /// （含取失败，不重复解包）；文件变了 key 就变，先清旧图再取，
    /// 不让旧图标冒充新文件。解包只取图标文件，不整包解压。
    /// A-37-1：调用方有指纹快照时传 fingerprint（已选行传
    /// selectedIPAFingerprint），不再主线程 stat 磁盘；没快照的
    /// 调用方不传，走现查。
    private func loadLibraryIcon(for path: String, signed: Bool, fingerprint: String? = nil) {
        let key = "\(path)#\(fingerprint ?? iconFingerprint(for: path))"
        if signed {
            guard !signedIconsTried.contains(key) else { return }
            signedIconsTried.insert(key)
            // A-37-3：清共享缓存里的旧图 + bump epoch（行回占位，等新图）。
            ThumbnailCache.remove(path)
            iconEpoch += 1
            // A-5(c)：批量写回懒建（首次加载时立一次，此后复用）。
            if librarySignedIconBatcher == nil {
                librarySignedIconBatcher = BatchWriteback { batch in
                    for (path, image) in batch { ThumbnailCache.set(image, for: path) }
                    self.iconEpoch += 1
                }
            }
        } else {
            guard !unsignedIconsTried.contains(key) else { return }
            unsignedIconsTried.insert(key)
            // A-37-3：清共享缓存里的旧图 + bump epoch（行回占位，等新图）。
            ThumbnailCache.remove(path)
            iconEpoch += 1
            if libraryUnsignedIconBatcher == nil {
                libraryUnsignedIconBatcher = BatchWriteback { batch in
                    for (path, image) in batch { ThumbnailCache.set(image, for: path) }
                    self.iconEpoch += 1
                }
            }
        }
        let url = URL(fileURLWithPath: path)
        Task.detached(priority: .userInitiated) {
            guard let data = IPALibrary.iconData(at: url),
                  // A-7：下采样在 detached 里做——行高 60pt，用 120×120 缩略图。
                  let image = IPALibrary.thumbnail(from: data, maxPixelSize: 120) else { return }
            await MainActor.run {
                if signed {
                    self.librarySignedIconBatcher?.enqueue(image, for: path)
                } else {
                    self.libraryUnsignedIconBatcher?.enqueue(image, for: path)
                }
            }
        }
    }

    /// 图标指纹：文件大小 + 修改时间（重签覆盖同路径时变）。
    /// 文件没了就返回空串，key 照样唯一，不会死循环重取。
    private func iconFingerprint(for path: String) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int,
              let modified = attrs[.modificationDate] as? Date else { return "" }
        return "\(size)-\(modified.timeIntervalSince1970)"
    }

    private func selectedIPASummary(_ url: URL) -> some View {
        HStack(spacing: 10) {
            // 签名段已选文件行：显示 IPA 真实图标（应用库同款
            // libraryIcon：取到显示 52×52 真图，取不到/还没取到
            // 显示中性灰方块占位，不造假图）。取图走 unsigned
            // 缓存桶 + loadLibraryIcon（signed: false），与未签名
            // 库行同一套；行 .task(id: 路径#指纹) 触发，换文件重取、
            // 同文件不重复解包、取失败不死循环。行布局/文字/
            // 更换按钮/签名逻辑一律不动。
            libraryIcon(for: url.path, signed: false)
            VStack(alignment: .leading, spacing: 2) {
                // 名字 + 版本放同一行（轻松签式一眼认出是哪个包、
                // 哪个版本），下面依次是 Bundle ID、文件名、用哪个
                // 证书签——IPA 与证书同框，不用翻到证书组去对。
                Text("\(selectedInfo?.name ?? url.lastPathComponent)\(selectedInfo?.version.map { " · V\($0)" } ?? "")")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let info = selectedInfo {
                    Text(info.bundleID)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                if certReady {
                    Text(L("用证书：%@", certRowText))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                } else {
                    Text(L("证书未就绪，签不了"))
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                selectedIPA = nil
                selectedIPAFingerprint = ""
                selectedInfo = nil
                signError = nil
                resetMods()
                signOnlyMessage = nil
                signBlockedMessage = nil
            } label: {
                Text(L("Replace"))
                    .font(.footnote)
            }
        }
        .task(id: "\(url.path)#\(selectedIPAFingerprint)") {
            loadLibraryIcon(for: url.path, signed: false, fingerprint: selectedIPAFingerprint)
        }
    }

    /// 新图标行（分组里用，标题已在组上面，不再另起 92 宽标签）：
    /// 没选显示相册选择，选了显示 40 图 + 清除；两边都有“修复图标”，
    /// 无图标或白图标时补一张默认图标（App 内已有的 AppLogo 资源）。
    private var iconRow: some View {
        HStack(spacing: 10) {
            if let image = decodedIcon {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                Button {
                    mods.icon = nil
                    iconItem = nil
                    decodedIcon = nil
                    decodedIconData = nil
                } label: {
                    Text(L("Clear"))
                        .font(.footnote)
                }
                Button {
                    repairIcon()
                } label: {
                    Text(L("修复图标"))
                        .font(.footnote)
                }
            } else if mods.icon == nil {
                PhotosPicker(selection: $iconItem, matching: .images) {
                    Text(L("从相册选择"))
                        .font(.footnote)
                }
                Button {
                    repairIcon()
                } label: {
                    Text(L("修复图标"))
                        .font(.footnote)
                }
            } else {
                // B12-6：解码中——占位，不闪回“从相册选择”。
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 40, height: 40)
                Button {
                    repairIcon()
                } label: {
                    Text(L("修复图标"))
                        .font(.footnote)
                }
            }
            Spacer()
        }
        .task(id: mods.icon) {
            // B12-6：照抄同文件 S15（loadLibraryIcon :2609）：mods.icon
            // 变时 detached 解一次、写回前核对仍是同一份 Data，旧解码
            // 不覆盖新图；.task 跑在主线程上（Swift 5 靶里 .task 继承
            // MainActor，见核验技能），读写 @State 不用再跳。
            guard let data = mods.icon else {
                decodedIcon = nil
                decodedIconData = nil
                return
            }
            guard decodedIconData != data else { return }
            let decoded = await Task.detached(priority: .userInitiated) {
                // A-7：用户自选图标也在 detached 里下采样——显示 40pt，
                // 用 80×80 缩略图；不是 IPA 内图标，是 Photos picker 选的图。
                IPALibrary.thumbnail(from: data, maxPixelSize: 80)
            }.value
            guard mods.icon == data else { return }
            decodedIcon = decoded
            decodedIconData = data
        }
    }

    /// 修复图标：把 App 内已有的 AppLogo 图设为新图标，走
    /// mods.icon 既有签名路，不新造生成逻辑；资源取不到时不动。
    private func repairIcon() {
        guard let data = UIImage(named: "AppLogo")?.pngData() else { return }
        mods.icon = data
        iconItem = nil
    }

    /// 换一个 IPA 时清掉修改项，并删掉已暂存的插件文件。
    private func resetMods() {
        for url in mods.plugins {
            CertPluginStore.remove(url)
        }
        mods = CertSignMods()
        pluginError = nil
        multiCountText = "1"
        multiStartText = "1"
        selectedCryptid = nil
        selectedUndumpedApps = []
        selectedUndumpedFingerprint = nil
    }

    private func select(_ url: URL) {
        // 源导入/文件库选择传过来的文件若已不在盘上（下载后被移走、
        // 导入槽覆盖），不进一个绑着幽灵文件的表单：切到签名段、
        // 明说文件找不到了、进口按钮就在下面可重试，绝不空白。
        guard FileManager.default.fileExists(atPath: url.path) else {
            selectedIPA = nil
            selectedIPAFingerprint = ""
            selectedInfo = nil
            selectedUndumpedFingerprint = nil
            signError = L("这个文件找不到了，请重新选择。")
            return
        }
        selectedIPA = url
        selectedIPAFingerprint = iconFingerprint(for: url.path)
        // 从库里点选就是来签名的，直接切到签名段，别让用户再往上翻。
        resetMods()
        iconItem = nil
        signOnlyMessage = nil
        signBlockedMessage = nil
        signError = nil
        // 框里预填这个 IPA 的原值，用户在原值上改；解析结果存下来，
        // 后续表单重绘直接复用，不再每敲一键重新解压读盘。
        selectedInfo = IPALibrary.appInfo(at: url)
        if let info = selectedInfo {
            mods.name = info.name
            mods.bundleID = info.bundleID
            mods.version = info.version ?? ""
            mods.minOS = info.minOS ?? ""
        }
        // 脱壳预检（轻松签式）：选好就在后台算，加密的直接
        // 在表单上提示；选中的还是这个 IPA 才写，免得切走后
        // 旧结果盖住新表单。签时 startSign 还会再算一次 gate。
        // 映射：undumpedApps 返回 nil（读不到）→ nil 无提示；
        // 空（全已脱壳）→ 0；非空 → 1，表单只判 != 0（见 SS2）。
        selectedCryptid = nil
        selectedUndumpedApps = []
        // A-4：记下当前文件的指纹——签时文件没变且预检已算出就复用。
        selectedUndumpedFingerprint = IPALibrary.fileFingerprint(of: url)
        Task.detached(priority: .userInitiated) {
            let undumped = IPADecryptionCheck.undumpedAppsFast(of: url) ?? IPADecryptionCheck.undumpedApps(of: url)
            await MainActor.run {
                if self.selectedIPA == url {
                    self.selectedCryptid = undumped.map { $0.isEmpty ? 0 : 1 }
                    self.selectedUndumpedApps = undumped ?? []
                }
            }
        }
    }

    /// 签名时真正提交的改动：框里和原值一样（或被清空）的项不提交，
    /// 免得把原名、原 ID、原版本号原样再写一遍。
    private var effectiveMods: CertSignMods {
        guard let info = selectedInfo else { return mods }
        var result = mods
        let name = result.name.trimmingCharacters(in: .whitespaces)
        result.name = (name.isEmpty || name == info.name) ? "" : name
        let bundleID = result.bundleID.trimmingCharacters(in: .whitespaces)
        result.bundleID = (bundleID.isEmpty || bundleID == info.bundleID) ? "" : bundleID
        let version = result.version.trimmingCharacters(in: .whitespaces)
        result.version = (version.isEmpty || version == (info.version ?? "")) ? "" : version
        let minOS = result.minOS.trimmingCharacters(in: .whitespaces)
        result.minOS = (minOS.isEmpty || minOS == (info.minOS ?? "")) ? "" : minOS
        // 输出名没有“原值”概念：空着就是回落推导名，只清空白。
        result.outputName = result.outputName.trimmingCharacters(in: .whitespaces)
        return result
    }

    /// 红按钮 / 面板内“仅签名”的统一入口：前置条件不满足时
    /// 不静默 return（startSign 原样），而是在按钮下方红字明说
    /// 原因；证书缺件时顺手展开证书组并滚回组顶，让用户一步
    /// 看到缺什么（组在表单顶部，滚下去点按钮时光展开看不见）。
    /// 正在签（按钮里已有转圈）时点按不重复提示。
    private func signFromMainButton(kind: CertSignKind, proxy: ScrollViewProxy) {
        if workspace.signBusy { return }
        // 单签与批量签名互斥：批量跑着时单签不进 signToFile，
        // 否则两路撞同一个输出文件、清单出重复 id（见 S2）。
        if workspace.batchBusy {
            signBlockedMessage = L("批量签名正在进行，等它跑完再签。")
            return
        }
        if engine.isRunning {
            signBlockedMessage = L("Engine 正在运行，等它跑完再签。")
            return
        }
        // B-51-B3：导入进行中不签——下载完 copyImport 会删掉旧导入文件，
        // 正签着它就撞上 Application path does not exist。
        if engine.isImportingIPA {
            signBlockedMessage = L("An import is already running. Wait for it to finish, then try again.")
            return
        }
        if !certReady {
            signBlockedMessage = L("证书还没备齐：点上方证书组，把 .p12、描述文件和密码补齐。")
            certGroupExpanded = true
            Task { @MainActor in
                withAnimation { proxy.scrollTo("certGroup", anchor: .top) }
            }
            return
        }
        signBlockedMessage = nil
        startSign(kind: kind)
    }

    /// 签名入口：先在后台做签前警告检查（脱壳要解压，耗时），
    /// 有警告先弹提醒（警告不拦截，点继续才执行），没警告直接执行。
    /// 吊销状态读上次手动检查的结果——没查过就不警告，不猜。
    private func startSign(kind: CertSignKind) {
        guard let url = selectedIPA, !workspace.signBusy, !workspace.batchBusy, certReady else { return }
        signBlockedMessage = nil
        workspace.signBusy = true
        signOnlyMessage = nil
        let currentMods = effectiveMods
        Task.detached(priority: .userInitiated) {
            // A7：签名前重解析挪进 detached 任务——主线程不再同步解 IPA。
            // 防 stale 语义保留：写回时加 selectedIPA == url 守卫（:1660 同款），
            // 解析失败留旧值，签名那步自会按文件报错。
            let fresh = IPALibrary.appInfo(at: url)
            // A-4：选包时已算过脱壳预检、文件没变时直接复用，不再全量解压
            // 第二次。指纹在 select() 时存；选包 detached 还没算完
            // （selectedCryptid 仍 nil）或文件被替换时照常重算。
            let currentFingerprint = IPALibrary.fileFingerprint(of: url)
            let reusedUndumped: [String]? = await MainActor.run {
                guard self.selectedIPA == url,
                      let fingerprint = self.selectedUndumpedFingerprint,
                      fingerprint == currentFingerprint,
                      self.selectedCryptid != nil
                else { return nil }
                return self.selectedUndumpedApps
            }
            let undumped = reusedUndumped ?? IPADecryptionCheck.undumpedAppsFast(of: url) ?? IPADecryptionCheck.undumpedApps(of: url)
            await MainActor.run {
                if self.selectedIPA == url, let fresh {
                    self.selectedInfo = fresh
                }
                var warnings: [String] = []
                if self.revocationStatus == .revoked {
                    warnings.append(L("证书已经掉签，签名后可能无法安装。"))
                }
                if let undumped, !undumped.isEmpty {
                    // 多 .app 时逐个报名字（见 SS2）；单 app 时
                    // 名字就是包里那个 .app，不再含糊说“程序”。
                    warnings.append(L("以下程序未脱壳，签名后可能无法安装，建议重新脱壳签名：%@", undumped.joined(separator: "、")))
                }
                if let expiry = self.expiryWarningText() {
                    warnings.append(expiry)
                }
                if warnings.isEmpty {
                    self.executeSign(kind: kind, url: url, mods: currentMods)
                } else {
                    self.pendingWarnings = warnings
                    self.pendingSignKind = kind
                    self.pendingSignURL = url
                    self.pendingSignMods = currentMods
                    self.showingWarningAlert = true
                    self.workspace.signBusy = false
                }
            }
        }
    }

    private func clearPendingSign() {
        pendingWarnings = []
        pendingSignKind = nil
        pendingSignURL = nil
        pendingSignMods = CertSignMods()
    }

    /// 签名失败文案：p12 打不开基本就是密码不对（Rust 侧原话就是
    /// “a wrong password reads the same”），按轻松签原文给中文提示，
    /// 其他错误原样透传；日志和界面用同一句，不两张皮。
    private func friendlySignError(_ message: String) -> String {
        if message.contains("PKCS#12") {
            return L("密码错误，请重新输入")
        }
        return message
    }

    private func executeSign(kind: CertSignKind, url: URL, mods: CertSignMods) {
        // B-C8：签前预检期间切了 IPA，照签旧包就错了——预检回主线程
        // 时 selectedIPA 已是新包。入口一处拦两条路（startSign 直调
        // 与警告框“继续签名”都走这里）；只复位 signBusy，不写
        // signError——用户只是切走了包，再点一次签名即走新包。
        guard selectedIPA == url else {
            workspace.signBusy = false
            return
        }
        // 源文件早拦：签名页记住的是旧路径，文件被移走/删掉后
        // 再点签名，isideload 只会报看不懂的 Application path
        // does not exist（2026-11-02 19:17 实证）。这里先验
        // 文件在不在，不在就明说重选，不走到签名那步。
        // 放 executeSign 而不是 startSign：警告弹框的“继续签名”
        // 也走这里，一处拦住两条路。
        guard FileManager.default.fileExists(atPath: url.path) else {
            workspace.signBusy = false
            signBlockedMessage = L("要签的源文件已不在，请从文件库重新选择后再签。")
            return
        }
        // B-51-B3：导入进行中不签（与上面同款：警告框"继续签名"也走这里，
        // 一处拦住两条路）。下载完 copyImport 会删掉旧导入文件。
        guard !engine.isImportingIPA else {
            workspace.signBusy = false
            signBlockedMessage = L("An import is already running. Wait for it to finish, then try again.")
            return
        }
        workspace.signBusy = true
        // B1：签名在跑时把源路径登记进 Engine，文件页/LAN/WebDAV 的删/
        // 移/改名入口会拒掉这个源；两 Task 分支的收尾处注销。
        engine.signingSourcePaths.insert(url.path)
        // 上次安装失败的旧错误在这里清掉：不然一次成功的仅签名
        // 仍在按钮下顶着旧安装错误（状态行优先级里错误排在签名
        // 结果前面），看着像这次又失败了。签名并安装路的安装错
        // 误由 startEngineInstall/onChange 后面重新置，不受影响。
        enterpriseInstallErrorText = nil
        // 步骤日志（只加可见性，不改签名逻辑）：签名开始行进同一份
        // diagnosticLog，后面成功/失败/配对安装开始/完成各补一行，
        // 企业页一步步就在这份日志里看；Engine 自己的管线日志
        // 在 Engine 那边，不进这里。
        localInstall.appendStepLog(L("开始签名：%@", selectedInfo?.name ?? url.deletingPathExtension().lastPathComponent))
        switch kind {
        case .signOnly:
            Task {
                do {
                    if multiCount > 1 {
                        // 多开：同表单、同插件、同图标，逐个换 Bundle ID
                        // 后缀和名字后缀签。原值被 effectiveMods 清空时
                        // 回落到 IPA 本身的名字和 Bundle ID。
                        let baseName = mods.name.isEmpty
                            ? (selectedInfo?.name ?? url.deletingPathExtension().lastPathComponent)
                            : mods.name
                        let baseID = mods.bundleID.isEmpty
                            ? (selectedInfo?.bundleID ?? "")
                            : mods.bundleID
                        // 打包名同样按序号派生（与名字序号同款）：手填
                        // 名先去重再加序号，空着按源文件名派生；不然
                        // 全部副本共用一主名、只靠 2、3… 区分，看不出
                        // 哪个副本是几号。
                        let baseOutput = mods.outputName.isEmpty
                            ? SignedIPAStore.stripSignedSuffix(url.deletingPathExtension().lastPathComponent)
                            : SignedIPAStore.stripSignedSuffix(mods.outputName)
                        // 起始序号循环开始时快照：输入框签名期间已禁用，
                        // 但循环内现读仍是隐患，快照后中途改值也影响不到
                        // 正在签的副本（见 S11）。
                        let startIdx = multiStart
                        // B-9：逐个签、逐个记——某个副本失败不再让整批
                        // 抛错白跑（旧逻辑：循环里一抛，前面签好的副本
                        // 也不报数）；成功/失败各记一条日志，结尾按
                        // 成功数报数，失败了也告诉用户是第几个、为什么。
                        var ok = 0
                        var fail = 0
                        var firstError: String?
                        for j in 0..<multiCount {
                            let idx = startIdx + j
                            var copy = mods
                            copy.name = "\(baseName) \(idx)"
                            // Bundle ID 实在读不出来就不加后缀（签出来
                            // 和原包同 ID，装的时候会顶掉原包，不静默造假）。
                            copy.bundleID = baseID.isEmpty ? "" : "\(baseID).\(idx)"
                            copy.outputName = "\(baseOutput) \(idx)"
                            do {
                                let record = try await CertSigner.signToFile(ipa: url, mods: copy)
                                ok += 1
                                CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                                    appName: record.appName, kind: .signOnly, success: true,
                                    detail: L("已存到「已签名」")))
                            } catch {
                                fail += 1
                                let message = (error as? LocalizedError)?.errorDescription
                                    ?? String(describing: error)
                                let friendly = friendlySignError(message)
                                if firstError == nil { firstError = friendly }
                                CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                                    appName: "\(baseName) \(idx)", kind: .signOnly, success: false,
                                    detail: friendly))
                            }
                        }
                        if fail == 0 {
                            CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                                appName: baseName, kind: .signOnly, success: true,
                                detail: L("已签出 %d 个副本，存到「已签名」。", multiCount)))
                            signOnlyMessage = L("已签出 %d 个副本，存到「应用库 → 已签名」，逐个点安装。", multiCount)
                            localInstall.appendStepLog(L("签名成功：%@（%d 个副本）", baseName, multiCount))
                            CZFHaptics.notification(.success)
                            signOnlyFailed = false
                        } else {
                            signOnlyMessage = L("批量签完：成功 %d 个，失败 %d 个。", ok, fail) + " " + (firstError ?? "")
                            signOnlyFailed = true
                            localInstall.appendStepLog(L("批量签完：成功 %d 个，失败 %d 个。", ok, fail))
                            CZFHaptics.notification(.error)
                        }
                    } else {
                        let record = try await CertSigner.signToFile(ipa: url, mods: mods)
                        CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                            appName: record.appName, kind: .signOnly, success: true,
                            detail: L("已存到「已签名」")))
                        signOnlyMessage = L("签好了，已存到「应用库 → 已签名」。")
                        localInstall.appendStepLog(L("签名成功：%@", record.appName))
                        CZFHaptics.notification(.success)
                        signOnlyFailed = false
                    }
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription
                        ?? String(describing: error)
                    let friendly = friendlySignError(message)
                    signOnlyMessage = friendly
                    signOnlyFailed = true
                    localInstall.appendStepLog(L("Signing failed: %@", friendly))
                    CZFHaptics.notification(.error)
                    CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                        appName: selectedInfo?.name ?? url.deletingPathExtension().lastPathComponent,
                        kind: .signOnly, success: false, detail: friendly))
                }
                // B1：签名收尾，注销源路径（与入口登记配对）。
                engine.signingSourcePaths.remove(url.path)
                workspace.signBusy = false
            }
        case .signAndInstall:
            Task {
                do {
                    // 先签好存进「已签名」，再走配对安装（WiFi 下签装
                    // 直接走通；回环在 0.9.80–0.9.82 上反复弹“无法连接
                    // localhost”，不再当默认入口）。同步失败（Engine
                    // 在跑）才由下面这段记一条失败日志；配对跑完由
                    // onChange 按 finished/lastError 记完成日志。
                    let record = try await CertSigner.signToFile(ipa: url, mods: mods)
                    await MainActor.run {
                        self.localInstall.appendStepLog(L("签名成功：%@", record.appName))
                        self.engineInstallLogAppName = record.appName
                        self.engineInstallLogKind = .signAndInstall
                        self.startEngineInstall(record: record)
                        if let reason = self.enterpriseInstallErrorText {
                            CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                                appName: record.appName, kind: .signAndInstall, success: false,
                                detail: reason))
                            // 同步失败不会触发 onChange，日志名额在这里清，
                            // 不然之后一次已签名行安装跑完会误记成这条。
                            self.engineInstallLogAppName = nil
                        }
                    }
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription
                        ?? String(describing: error)
                    let friendly = friendlySignError(message)
                    signOnlyMessage = friendly
                    signOnlyFailed = true
                    localInstall.appendStepLog(L("Signing failed: %@", friendly))
                    CZFHaptics.notification(.error)
                    CertSignLogStore.append(CertSignLogEntry(id: UUID(), date: Date(),
                        appName: selectedInfo?.name ?? url.deletingPathExtension().lastPathComponent,
                        kind: .signAndInstall, success: false, detail: friendly))
                }
                // B1：签名收尾，注销源路径（与入口登记配对）。
                engine.signingSourcePaths.remove(url.path)
                workspace.signBusy = false
            }
        }
    }

    /// 已签名行「安装」：默认走配对安装（WiFi 下签装直接走通；
    /// 回环在 0.9.80–0.9.82 上反复弹“无法连接 localhost”，不再
    /// 当默认入口）。配对跑完由 onChange 记一条「仅安装」日志。
    private func installSigned(_ record: SignedIPARecord) {
        engineInstallLogKind = .installOnly
        startEngineInstall(record: record)
    }

    /// 本机回环安装（已不是默认入口）：明文 http://localhost +
    /// itms-services，轻松签同款；签好的包只在本机回环上走一圈，
    /// 系统安装器直接装，不走配对、不走隧道、不要 WiFi。
    /// 0.9.80–0.9.82 上反复弹“无法连接 localhost”，默认入口已改
    /// 回配对安装；这函数与 otaServer 留着没删，回环以后想用
    /// 再接回来。回环起不来时不静默回落——兜底弹框让用户点
    /// “改用配对安装”才走 startEngineInstall；
    /// 回环拉起后装成装不成系统安装器那边才知道，App 内不假报
    /// 成功（不记完成日志、不弹成功框，只记一步日志）。
    /// Engine 在跑时不新起（两路安装撞在一起没好处）。
    private func startLoopbackInstall(record: SignedIPARecord) {
        enterpriseInstallRecord = record
        enterpriseInstallErrorText = nil
        guard !engine.isRunning else {
            enterpriseInstallErrorText = L("已有安装在进行，先等当前安装完成再试。")
            if !enterpriseInstallInFlight { engineInstallLogAppName = nil }
            return
        }
        localInstall.appendStepLog(L("本机回环安装开始：%@", record.appName))
        // 0.9.14 曾有、0.9.21 清理 local-HTTP 时误删：回环安装前先停内置隧道。
        // 跑着的隧道会干扰 installd 的 localhost 连接（0.9.14 实证、0.9.21
        // 之后弹窗回归）；fire-and-forget，停失败不阻断安装。ID 操作需要时
        // 隧道会自动再拉起来。别再以“清理”为名删掉这一行。
        Task { await BuiltinTunnel.stop() }
        otaServer.install(ipaURL: SignedIPAStore.url(for: record), appName: record.appName,
                          bundleID: record.bundleID, version: record.version ?? "1.0")
    }

    /// 配对安装兜底入口（本机回环起不来时用户点了“改用配对安装”
    /// 才走它）：调 Engine 的 runInstallSignedIPA（配对设备链路，
    /// 前置检查（配对文件、隧道、设备 IP）不过时 Engine 直接返回、
    /// isRunning 根本没置位——这时就别留着进行中标志（否则之后
    /// 别的 tab 一次成功安装也会误弹），并把原因快照到页内：
    /// 优先用 Engine 的前置向导（标题 + 步骤，告诉用户去补配对
    /// 文件/连隧道）；向导没变（纯日志那两路）或是上一次跑剩的
    /// 旧向导时，一律给通用提示，不把旧向导当成这次的原因；
    /// 不读 lastError——前置失败不置它，读到的只会是上一次跑的
    /// 旧错。重复同一个前置失败时向导值不变，但它仍是这次的
    /// 原因（前置三向导认值，不认新旧）。跑完的成功/失败由
    /// onChange 按 finished/lastError 记日志 + 弹框（见 body 层）。
    private func startEngineInstall(record: SignedIPARecord) {
        enterpriseInstallRecord = record
        enterpriseInstallErrorText = nil
        // 文件页同款守卫（FilesTabView）：Engine 单管线，别的安装
        // 在跑时不新起——runInstallSignedIPA 里静默 return，但
        // 进行中标志若立着，之后别人的安装结束会被误认成这次
        // 的（归属劫持）。签名并安装路同样走这里复查：签名耗时
        // 几秒，点按瞬间没在跑不等于起安装时也没在跑。
        guard !engine.isRunning else {
            enterpriseInstallErrorText = L("已有安装在进行，先等当前安装完成再试。")
            // 名额只在没跑认领时清：正跑着的那次还指着它记日志，
            // 忙时一点就清会把进行中那次的日志名额抹掉。
            if !enterpriseInstallInFlight { engineInstallLogAppName = nil }
            return
        }
        let guideBefore = engine.guide
        let sessionBefore = engine.installSessionID
        localInstall.appendStepLog(L("配对安装开始：%@", record.appName))
        engine.runInstallSignedIPA(ipaURL: SignedIPAStore.url(for: record))
        if !engine.isRunning {
            if !enterpriseInstallInFlight { engineInstallLogAppName = nil }
            if let guide = engine.guide,
               guide != guideBefore
               || guide == Guides.importPairing || guide == Guides.vpn
               || guide == Guides.deviceIPMismatch {
                enterpriseInstallErrorText = ([guide.title] + guide.steps).joined(separator: "\n")
            } else {
                enterpriseInstallErrorText = L("配对安装没能启动：请检查配对文件与隧道是否就绪，或去「安装」页看日志。")
            }
            localInstall.appendStepLog(L("配对安装失败：%@", enterpriseInstallErrorText ?? ""))
            return
        }
        // 真正起跑了才立进行中标志 + 归属凭证：会话没变说明这
        // 次调用根本没起跑（起跑瞬间输了竞态），按“已有安装在
        // 进行”处理，绝不把别人的结束认成自己的；onChange 只
        // 认同一会话的结束（见 body 层）。
        guard engine.installSessionID != sessionBefore, let session = engine.installSessionID else {
            enterpriseInstallErrorText = L("已有安装在进行，先等当前安装完成再试。")
            if !enterpriseInstallInFlight { engineInstallLogAppName = nil }
            return
        }
        enterpriseInstallInFlight = true
        enterpriseInstallRunID = session
        // 日志名额跟这次跑绑定（已签名行直装以前从不设名额，
        // 仅安装的完成日志被悄悄跳过；这里起跑时认领，失败/
        // 忙时上面已清，不会把旧名额留给下一次误认）。
        engineInstallLogAppName = record.appName
    }

    /// 本机 UDID（轻松签同款办法：MobileGestalt 的 MGCopyAnswer，
    /// ESign 二进制里实证有 libMobileGestalt + MGCopyAnswer）。
    /// dlsym 运行时找，找不到或被系统 gate 住返回空就得 nil，
    /// 证书页回落到只提示台数，不崩、不假断言。UDID 在设备上
    /// 不变，进程内只算一次。Side 是侧载包，不走 App Store
    /// 审核，调私有 API 不会被拒。
    private static let localDeviceUDID: String? = {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "MGCopyAnswer") else { return nil }
        typealias MGCopyAnswerFn = @convention(c) (CFString) -> Unmanaged<AnyObject>?
        let fn = unsafeBitCast(sym, to: MGCopyAnswerFn.self)
        guard let value = fn("UniqueDeviceID" as CFString)?.takeRetainedValue() else { return nil }
        return value as? String
    }()

    /// 企业安装状态 + 失败提示 + 配对重试/取消：只在企业页内
    /// 显示，不碰共享「安装」页。进行中显示 Engine 进度 +“取消
    /// 安装”（调 Engine 的 cancelOneClick，中止 pipelineTask；
    /// 取消后 isRunning 落下触发 onChange 清 inFlight，取消不算
    /// 成功也不记失败）；跑完失败时显示快照的原因 +“重试配对
    /// 安装”（原因来自 startEngineInstall / onChange 的快照，
    /// 不直接读 engine 的全局 lastError，免得别的 tab 的失败
    /// 串到这里）。进行中只认 enterpriseInstallInFlight（ID 线
    /// 的安装跑起来时这里不跟着亮，免得串台）。
    @ViewBuilder
    private var enterpriseInstallStatus: some View {
        if enterpriseInstallInFlight {
            HStack(spacing: 8) {
                if engine.installProgress > 0 {
                    Text(L("配对安装进行中（%d%%）", Int(engine.installProgress * 100)))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                } else {
                    Text(L("配对安装进行中"))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button(L("取消安装")) { CZFHaptics.impact(.light); engine.cancelOneClick() }
                .font(.footnote)
            }
        } else if let error = enterpriseInstallErrorText {
            HStack(spacing: 8) {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.negative)
                Spacer()
                if let record = enterpriseInstallRecord {
                    Button(L("重试配对安装")) { CZFHaptics.impact(.light); startEngineInstall(record: record) }
                        .font(.footnote)
                }
            }
        }
    }

    /// 安装诊断日志（只读展示，不动行为）：读单例 localInstall
    /// .diagnosticLog 原样展示（不解析、不重排、不过滤；
    /// 最新行在最下，往下翻）。上面是企业页自己的步骤行
    ///（开始签名/签名成功/失败/配对安装开始/完成/失败），下面一并
    /// 展示 Engine 最近的步骤行（只读，不动 Engine 传输逻辑），
    /// 安装失败不用切到「安装」页也能看到详细步骤。签名/安装
    /// 进行中强制展开，日志当场可见（不再只藏在收起的组里）；
    /// 平时跟随用户手动开关；失败后仍可点开看全文（步骤区另有
    /// 复制按钮，不展开也能复制）。签名段与应用库段各放一处、
    /// 共用同一个展开态与同一份数据；三段切栏一次只显示一段，
    /// 不会同时出现两个。
    private var installDiagnosticLogSection: some View {
        DisclosureGroup(isExpanded: diagnosticLogExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if localInstall.diagnosticLog.isEmpty {
                            Text(L("暂无安装日志。"))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        } else {
                            ForEach(Array(localInstall.diagnosticLog.enumerated()), id: \.offset) { _, line in
                                Text(verbatim: line)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        if !LogStore.shared.lines.isEmpty {
                            Divider()
                            Text(L("Engine 步骤日志（最近 40 行）"))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                            ForEach(Array(LogStore.shared.lines.suffix(40).enumerated()), id: \.offset) { _, entry in
                                Text(verbatim: "\(entry.stamp)  \(entry.text)")
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                Button(L("Copy logs")) {
                    var text = localInstall.diagnosticLog.joined(separator: "\n")
                    let recentEngine = LogStore.shared.lines.suffix(40)
                    if !recentEngine.isEmpty {
                        if !text.isEmpty { text += "\n" }
                        text += "--- Engine ---\n" + recentEngine.map { "\($0.stamp)  \($0.text)" }.joined(separator: "\n")
                    }
                    UIPasteboard.general.string = text
                }
                .font(.footnote)
                .disabled(localInstall.diagnosticLog.isEmpty && LogStore.shared.lines.isEmpty)
                // 禁用态没有视觉提示时看着能点实际点不了（跟红按钮
                // 同例）：没日志就半透明，别让人空点。
                .opacity(localInstall.diagnosticLog.isEmpty && LogStore.shared.lines.isEmpty ? 0.5 : 1)
            }
        } label: {
            Text(L("安装诊断日志"))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
    }

    /// 诊断日志展开态：签名/安装进行中强制展开（get 为 true），
    /// 用户此时点收起也 snap 回展开——进行中日志必须当场可见；
    /// 进行结束恢复用户手动开关（set 只写 showInstallDiagnosticLog）。
    private var diagnosticLogExpanded: Binding<Bool> {
        Binding(
            get: { showInstallDiagnosticLog || workspace.signBusy || enterpriseInstallInFlight },
            set: { showInstallDiagnosticLog = $0 }
        )
    }

    /// 安装进行中的阶段文案（从 Engine 的步骤状态现推，不另起
    /// 状态、不猜阶段）：network 在跑 = 正在连隧道，pair 在跑 =
    /// 正在配对，connect 在跑 = 正在打开设备连接，sign 在跑 =
    /// 正在解包，install 在跑 = 正在上传并安装到设备（AFC 上传 +
    /// installation_proxy 都在这一步里）；都没在跑 = 通用文案。
    /// 只在 enterpriseInstallInFlight 时显示，这一步的 job 就是
    /// 企业这次的安装，不会把 ID 线的步骤读到这里。
    private var installStageText: String {
        let states = engine.stepStates
        if states[.network] == .active || states[.network] == .waiting {
            return L("正在连接隧道…")
        }
        if states[.pair] == .active || states[.pair] == .waiting {
            return L("Pairing…")
        }
        if states[.connect] == .active || states[.connect] == .waiting {
            return L("正在打开设备连接…")
        }
        if states[.sign] == .active {
            return L("正在解包…")
        }
        if states[.install] == .active || states[.install] == .waiting {
            return L("正在上传并安装到设备…")
        }
        return L("配对安装进行中…")
    }

    /// 企业步骤进度（v65 起，一步步，只加可见性）：
    /// 签名 / 打包 / 安装尝试三行常显（不是收起的组），签名与
    /// 打包随同一调用完成（signToFile 签 + 打包一体，故两行状态
    /// 相同，是实话不是造两个进度）；安装行进行中显示 Engine
    /// 流程阶段（从 engine.stepStates 现推：连接/配对/设备连接/
    /// 解包/上传安装，不重复状态区文案），完成 / 失败显示结果。
    /// 平时无操作、无结果时整组隐藏（不占表单地方）；进行中与
    /// 失败后都可见，失败后步骤区可直接复制日志（不展开也能复制）。
    /// 签名失败本身仍由原有 signOnlyMessage 红条显示，这里不重复
    /// 贴（免得同一失败出现两处）。顶层 if 返回 VStack/EmptyView
    /// 两种类型，故必须 @ViewBuilder（见 AGENTS.md）。
    @ViewBuilder
    private var enterpriseStepProgress: some View {
        if workspace.signBusy || enterpriseInstallInFlight
            || enterpriseInstallErrorText != nil || showingEnterpriseInstallSuccessAlert {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if workspace.signBusy {
                        ProgressView()
                    } else if signOnlyFailed {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.negative)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.positive)
                    }
                    Text(workspace.signBusy ? L("签名中…") : (signOnlyFailed ? L("签名失败") : L("签名已完成")))
                        .font(.footnote)
                        .foregroundStyle(workspace.signBusy ? Color.primary : (signOnlyFailed ? Theme.negative : Color.primary))
                }
                HStack(spacing: 6) {
                    if workspace.signBusy {
                        ProgressView()
                    } else if signOnlyFailed {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.negative)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.positive)
                    }
                    Text(workspace.signBusy ? L("打包中…") : (signOnlyFailed ? L("打包未完成") : L("打包已完成")))
                        .font(.footnote)
                        .foregroundStyle(workspace.signBusy ? Color.primary : (signOnlyFailed ? Theme.negative : Color.primary))
                }
                HStack(spacing: 6) {
                    if enterpriseInstallInFlight {
                        ProgressView()
                        Text(installStageText)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    } else if showingEnterpriseInstallSuccessAlert {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.positive)
                        Text(L("配对安装完成，进度回桌面看"))
                            .font(.footnote)
                    } else if let error = enterpriseInstallErrorText {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.negative)
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Theme.negative)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(Theme.muted)
                        Text(L("安装未开始"))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
                if !localInstall.diagnosticLog.isEmpty {
                    Button(L("Copy logs")) {
                        UIPasteboard.general.string = localInstall.diagnosticLog.joined(separator: "\n")
                    }
                    .font(.footnote)
                }
            }
        }
    }
}

/// 签名流程两种去向：仅签名存已签名，或签名后走配对安装。
private enum CertSignKind {
    case signOnly
    case signAndInstall
}

/// 从文件库（Documents 里的全部 IPA）里挑一个。
/// 签名页“从文件库选择”picker：行格式照文件页 IPA 行（图标 +
/// App 名 / V版本 | 大小 | Bundle ID / 文件名），顶部带库内搜索；
/// 图标与信息都只读 central directory + 单条目、不整包解压，
/// 行出现时触发一次，取不到就占位、不死循环（文件页同款）。
private struct LibraryIPAPicker: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (URL) -> Void

    @State private var query = ""
    /// 选择器行图标已试集合（键见 cacheKey）。图标本体在共享
    /// ThumbnailCache 里（A-37-3），重绘由 iconEpoch 触发。
    @State private var iconsTried: Set<String> = []
    @State private var iconEpoch = 0
    @State private var infos: [String: IPALibrary.AppInfo] = [:]
    @State private var infosTried: Set<String> = []
    /// A-5(c)：IPA 选择器行图标 / 信息的批量写回（loadIcon/loadInfo 同款，懒建）。
    @State private var pickerIconBatcher: BatchWriteback<String, UIImage>?
    @State private var pickerInfoBatcher: BatchWriteback<String, IPALibrary.AppInfo>?
    // 3.8.900（SIDE-4/S2）：文件列表只扫一次——原来 ipas 是计算属性，
    // query 每敲一字 → body 重算 → 全量递归扫一遍 Documents。
    // 改 @State + 下方 .task 扫一次；picker 关闭即丢弃，不跨页缓存。
    @State private var ipas: [LocalFileItem] = []

    private var filtered: [LocalFileItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return ipas }
        return ipas.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || infos[$0.url.path]?.name.localizedCaseInsensitiveContains(q) == true
                || infos[$0.url.path]?.bundleID.localizedCaseInsensitiveContains(q) == true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 应用库同款浅灰搜索框：按文件名/App 名/Bundle ID 过滤。
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.muted)
                    TextField(L("搜索"), text: $query)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 8)
                List(filtered) { item in
                    Button {
                        onPick(item.url)
                    } label: {
                        pickerRow(item)
                    }
                    // plain 才能压住 List 里 Button 默认的蓝色字。
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(L("选择 IPA"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
            .task {
                // 3.8.900（SIDE-4/S2）：进 picker 只扫一次；扫盘放
                // Task.detached，扫完回主线程写 ipas（照抄 loadFileIcon 写法）。
                let scanned = await Task.detached {
                    AppFileLibrary.scan().filter { $0.isIPA }
                }.value
                await MainActor.run { ipas = scanned }
            }
        }
    }

    private func cacheKey(_ item: LocalFileItem) -> String {
        "\(item.url.path)#\(item.size)#\(item.modified?.timeIntervalSince1970 ?? 0)"
    }

    private func displayName(_ item: LocalFileItem) -> String {
        if let name = infos[item.url.path]?.name, !name.isEmpty {
            return name
        }
        return (item.name as NSString).deletingPathExtension
    }

    private func secondLine(_ item: LocalFileItem) -> String {
        let size = CZFFormattedSize.size(item.size)
        guard let info = infos[item.url.path] else { return size }
        var parts: [String] = []
        if let version = info.version, !version.isEmpty {
            parts.append("V\(version)")
        }
        parts.append(size)
        if !info.bundleID.isEmpty {
            parts.append(info.bundleID)
        }
        return parts.joined(separator: " | ")
    }

    private func pickerRow(_ item: LocalFileItem) -> some View {
        // A-37-3：读 iconEpoch 建立依赖——图标本体在共享缓存里，
        // 批量写回只 bump epoch、不写 @State；不读它，body 不会
        // 重算，图就永远不出现。别把这行当死代码清掉。
        let _ = iconEpoch
        return HStack(spacing: 8) {
            if let uiImage = ThumbnailCache.image(for: item.url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "doc")
                    .foregroundStyle(Theme.muted)
                    .font(.title3)
                    .frame(width: 52, height: 52)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(secondLine(item))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Text(item.name)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .task(id: cacheKey(item)) { loadInfoAndIcon(for: item) }
    }

    /// A-38-A1：选择器行信息 + 图标一次解析——合流函数一次开包同产两半；
    /// 替换途中文件校验只做一次，覆盖两半；写回仍走各自的
    /// BatchWriteback；两个 tried 集都保留——两半都已尝试才直接返回，
    /// 否则解析一次、按需写回未尝试的那半。
    private func loadInfoAndIcon(for item: LocalFileItem) {
        let key = cacheKey(item)
        let infoTried = infosTried.contains(key)
        let iconTried = iconsTried.contains(key)
        guard !infoTried || !iconTried else { return }
        infosTried.insert(key)
        iconsTried.insert(key)
        // A-5(c)：批量写回懒建（首次加载时立一次，此后复用）。
        if pickerInfoBatcher == nil {
            pickerInfoBatcher = BatchWriteback { batch in
                for (path, info) in batch { self.infos[path] = info }
            }
        }
        if pickerIconBatcher == nil {
            pickerIconBatcher = BatchWriteback { batch in
                // A-37-3：写共享缓存，再 bump iconEpoch 触发重绘。
                for (path, image) in batch { ThumbnailCache.set(image, for: path) }
                self.iconEpoch += 1
            }
        }
        Task.detached { [url = item.url, path = item.url.path,
                         size = item.size, modified = item.modified?.timeIntervalSince1970 ?? 0,
                         infoTried, iconTried] in
            let (info, data) = IPALibrary.appInfoAndIconData(at: url)
            // C30（B12-6 同款核对）：解包途中文件被替换就丢掉旧信息/旧图。
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            let liveSize = attrs?[.size] as? Int
            let liveModified = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            guard liveSize == size, liveModified == modified else { return }
            if !infoTried, let info {
                await MainActor.run { self.pickerInfoBatcher?.enqueue(info, for: path) }
            }
            if !iconTried, let data,
               // A-7：下采样在 detached 里做——选择器行高 52pt，原来用 104×104；
               // A-37-3：共享缓存按路径只存一份，各处取最大 120，行上显示
               // 时再缩到 52pt，不模糊。
               let image = IPALibrary.thumbnail(from: data, maxPixelSize: 120) {
                await MainActor.run { self.pickerIconBatcher?.enqueue(image, for: path) }
            }
        }
    }
}
