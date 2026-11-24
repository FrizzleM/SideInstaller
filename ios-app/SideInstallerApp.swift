import BackgroundTasks
import SwiftUI
import UserNotifications

/// Shows notifications even when the app is in foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct SideInstallerApp: App {
    // The one engine, handed to every screen through the environment.
    @State private var engine = Engine.shared
    // Checks GitHub for a newer release and drives the update banner.
    @StateObject private var updateChecker = UpdateChecker()
    // Held here so every screen redraws when the language setting changes.
    @StateObject private var localizer = Localizer.shared
    // The saved Apple IDs, shared by every screen that signs in.
    @StateObject private var accounts = AccountStore.shared
    /// False until account setup is completed or skipped. Never reset, even if
    /// all accounts are removed later.
    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false
    // 0.9.89（SIDE-2 修复）：下面 5 个声明是合并时丢的，从提交历史原样恢复——
    // hasAcceptedTOS（@AppStorage，WelcomeView 写同一键）、appearance（SIDAppearance，
    // 与设置页同一键）、scenePhase、notificationDelegate、keepAlive。
    @AppStorage("hasAcceptedTOS") private var hasAcceptedTOS = false
    @AppStorage("SIDAppearance") private var appearance: AppAppearance = .system
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = NotificationDelegate()
    private let keepAlive = KeepAlive()

    init() {
        // A pairing code still up from a run that was killed means nothing now.
        PairingLiveActivity.shared.endLeftovers()
        PairingNotification.shared.reset()
        // Show resign notifications even in foreground.
        UNUserNotificationCenter.current().delegate = notificationDelegate
        // Request notification permission for resign alerts.
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
        // 后台唤醒续签：BGTask 处理入口必须在启动结束前注册，
        // 系统日后唤醒时才有地方接。
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SIDAutoRefresh.bgTaskIdentifier, using: nil
        ) { task in
            SIDAutoRefresh.handleBackgroundWake(task as! BGAppRefreshTask)
        }
        // So is an install's progress.
        InstallActivity.shared.endLeftovers()
        // iOS hands over the last crash's diagnostic now, for Report a problem.
        CrashDiagnostics.shared.start()
        // Drawn now so the first tap already has its sound.
        SoundEffects.prepare()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasAcceptedTOS && hasCompletedAccountSetup {
                    RootView()
                        .environment(engine)
                        .environmentObject(updateChecker)
                        .environmentObject(localizer)
                        .environmentObject(accounts)
                        // 更新检查：只在 latest_version.txt 比本机新时才亮横幅，
                        // 相等/取不到都不打扰；txt 由发版同步改（见 UpdateChecker）。
                        .task { await updateChecker.check() }
                        .onAppear {
                            // Start background keep-alive for Shortcuts resign
                            keepAlive.startAudio()
                            // 自动续签开关开着时，拉起常驻巡检（内部自查开关）
                            AutoRefreshService.shared.start()
                        }
                        .transition(.opacity)
                } else if hasAcceptedTOS {
                    AccountSetupView()
                        .environmentObject(localizer)
                        .environmentObject(accounts)
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 1.06))))
                        // Layered between the welcome page and the app, so each
                        // zooms out over the next screen.
                        .zIndex(0.5)
                } else {
                    WelcomeView()
                        .environmentObject(localizer)
                        // Zoom past the camera while the app fades in beneath.
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 1.06))))
                        .zIndex(1)
                }
            }

            .animation(.smooth(duration: 0.5), value: hasAcceptedTOS)
            .animation(.smooth(duration: 0.5), value: hasCompletedAccountSetup)
            // 外观统一在窗口根上应用，三个页面（欢迎/账户/主界面）都跟着走。
            .preferredColorScheme(appearance.colorScheme)
            // LocalDevVPN 连好跳回来（或 App 从后台回前台）时，
            // 若有快捷指令留下的待续签标记，接着把续签跑完。
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    SideloadedAppsManager.shared.consumePendingRefresh()
                    // 回前台时确保自动续签巡检在跑（开关内部自查）。
                    SIDAutoRefresh.consider()
                    // SIDE-2 S1：回前台重起状态轮询（进后台时已停）。
                    engine.startStatusMonitor()
                } else if phase == .background {
                    // 进后台时把下一次系统唤醒交上去（开关开着才提交）。
                    SIDAutoRefresh.scheduleBackgroundWake()
                    // SIDE-2 S1：进后台停掉隧道状态轮询——自动续签保活常驻
                    // 后台时它每 5 秒醒 CPU 空转系统调用；唤醒续签入口自己
                    // 会调 refreshNetworkStatus，不依赖轮询。
                    engine.stopStatusMonitor()
                }
            }
            // Every switch in the app clicks on and off.
            .toggleStyle(SoundingToggleStyle())
            // Files opened in the app (share sheet, "Open with", other apps), as
            // an alternative to the document picker.
            .onOpenURL { url in
                // Handle `sideinstaller://` links: refresh-all from Shortcuts
                // runs at once; every other link goes through the Engine's
                // confirmation popup and does nothing until the user says yes.
                // LocalDevVPN returning to the app carries no action, so it
                // parses as ignored and is safely dropped.
                if url.scheme == "sideinstaller" {
                    if url.host == "refresh-all" {
                        // SIDE-2 C2：以前这里先 post 通知、再直调 refreshAllFromShortcut，
                        // 应用页在前台时通知同步跑 refreshAll() 抢掉 isRefreshing，直调的
                        // LocalDevVPN 交接分支永远走不到。只留直调一个入口。
                        Task { await SideloadedAppsManager.shared.refreshAllFromShortcut() }
                    } else {
                        Task { @MainActor in engine.receiveLink(url) }
                    }
                    return
                }
                guard url.isFileURL else { return }
                // `.mobiledevicepairing`/`.plist` are pairing files; anything else
                // is treated as an IPA.
                if ["mobiledevicepairing", "plist"].contains(url.pathExtension.lowercased()) {
                    Task { await engine.importPairingFile(from: url) }
                } else {
                    engine.installSource = .custom
                    Task {
                        // 从分享/“打开方式”进来的 IPA 直接装：只有这次导入成功
                        // 才起管线（C12：凭返回值判，不再凭 lastError + 旧文件）。
                        // 导入失败时 importCustomIPA 会写 lastError，管线不启动。
                        // B3：安装进行中时导入本身已被拒（importCustomIPA 入口守卫），
                        // 这里的 wasRunning 分支已不可达——删掉，导入成功就直接起管线。
                        // 管线自己的 guards 会在缺证书/配对/WiFi 时停下并给出指引，
                        // 与点安装按钮同一套。
                        guard await engine.importCustomIPA(from: url) else { return }
                        if IPALibrary.customImport() != nil {
                            // 先跳安装页：管线在跑时进度在那一页，guard 停下时
                            // 指引卡也在那一页，不用用户自己再去安装页找。
                            engine.sharedIPAReady = true
                            engine.runOneClick()
                        }
                    }
                }
            }
        }
    }
}
