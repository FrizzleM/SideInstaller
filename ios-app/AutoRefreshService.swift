import Foundation
import UserNotifications

/// 常驻后台自动续签（照 Seal 的配方拼现成件）：无声音频＋定位双保活让进程
/// 留在后台，每 30 分钟巡检一次；描述文件 3 天内到期且隧道已连上时，只续
/// 到期的那几个。两轮自动续签至少间隔 6 小时，避免反复打扰苹果接口。
/// 隧道没通时不硬跑：清单里有今天/明天就过期的 App 时，一天最多提醒一次。
@MainActor
final class AutoRefreshService {

    static let shared = AutoRefreshService()

    /// 设置页开关的 UserDefaults 键（SettingsView 的 @AppStorage 用同一键）。
    /// nonisolated：常量字符串，不碰任何 actor 状态，BG 任务的非隔离
    /// 上下文（SIDAutoRefresh.isEnabled）读它才不会在 Swift 6 模式下
    /// 报错；原来是 warning（Engine.swift:4104），Swift 6 下会变 error。
    nonisolated static let enabledKey = "SIDAutoRefreshEnabled"
    private static let lastRoundKey = "SIDAutoRefreshLastRound"
    private static let lastAlertKey = "SIDAutoRefreshLastAlert"
    private static let lastTickKey = "SIDAutoRefreshLastTick"

    /// 巡检间隔：30 分钟。
    private static let checkInterval: UInt64 = 30 * 60 * 1_000_000_000
    /// 两轮自动续签的最小间隔：6 小时。
    private static let minRoundInterval: TimeInterval = 6 * 3600
    /// 到期提醒（隧道没通时）的最小间隔：12 小时。
    private static let minAlertInterval: TimeInterval = 12 * 3600
    /// 两轮巡检的最小间隔：10 分钟。30 分钟循环、BG 唤醒、回前台
    /// 三路都可能短时间内各触发一轮巡检；这是来源去重——上一轮
    /// 刚跑过就静默跳过。6 小时那道只管“真续签”冷却，不管巡检本身。
    private static let minTickInterval: TimeInterval = 10 * 60

    private let keepAlive = KeepAlive()
    private var loopTask: Task<Void, Never>?
    private var isRunning = false

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    /// 定位降级状态（Seal 同款明示）：定位被拒/受限或系统定位总开关
    /// 关了时为真，这时只有音频保活在撑，锁屏续签可能被挂起。
    /// 设置页开关下面直接写出来，不让用户猜。
    var locationDegraded: Bool { keepAlive.locationUnavailable }

    /// 开关开着且巡检没在跑时启动：双保活＋巡检循环。重复调用无副作用。
    func start() {
        guard isEnabled, !isRunning else { return }
        isRunning = true
        keepAlive.startAudio()
        keepAlive.startLocation()
        Engine.shared.log("Auto refresh: resident patrol started.")
        if keepAlive.locationUnavailable {
            Engine.shared.log("Auto refresh: location unavailable — audio-only keep-alive; lock-screen renewal may be suspended.")
        }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                _ = await self.tick()
                try? await Task.sleep(nanoseconds: Self.checkInterval)
            }
        }
    }

    /// 停巡检并撤双保活。正在跑的续签由 manager 自己的保活撑完，不受影响。
    func stop() {
        guard isRunning else { return }
        isRunning = false
        loopTask?.cancel()
        loopTask = nil
        keepAlive.stopAll()
        Engine.shared.log("Auto refresh: resident patrol stopped.")
    }

    /// 设置页开关变化时调用：开→启动，关→停止。
    func applySetting() {
        if isEnabled {
            start()
        } else {
            stop()
        }
    }

    /// 立刻单跑一轮巡检（BGAppRefreshTask 把进程唤醒时用：
    /// 那时没有常驻循环可借，直接调巡检本体）。
    /// 返回值见 `tick`：后台唤醒凭它决定 `finish(true/false)`（C11）。
    func runCheck() async -> Bool {
        await tick()
    }

    // MARK: - 巡检

    /// One patrol round. Returns whether the round reached a decision:
    /// `true` when it checked the list and decided (nothing due, throttled,
    /// a refresh started — and also "feature off" / "checked recently",
    /// which are decisions, not failures); `false` only when a transient
    /// blocker kept it from checking at all (tunnel down, list failed or
    /// still loading, another refresh/install running). The background wake
    /// uses this to decide `finish(true/false)` (C11).
    private func tick() async -> Bool {
        let manager = SideloadedAppsManager.shared
        let engine = Engine.shared
        guard isEnabled else { return true }
        guard !manager.isRefreshing, !engine.isRunning else { return false }

        // 来源去重：上一轮巡检 10 分钟内跑过就静默跳过。BG 唤醒、
        // 30 分钟循环、回前台三路撞在一起时，只留一轮干活。
        let tickNow = Date().timeIntervalSince1970
        let lastTick = UserDefaults.standard.double(forKey: Self.lastTickKey)
        guard tickNow - lastTick >= Self.minTickInterval else { return true }
        UserDefaults.standard.set(tickNow, forKey: Self.lastTickKey)

        engine.refreshNetworkStatus()
        guard engine.vpnConnected else {
            await alertIfCritical(manager: manager)
            return false
        }

        // 读一次设备清单（安静模式，失败就等下一轮）。
        let failedBefore = manager.lastLoadFailed
        manager.load(quiet: true)
        for _ in 0..<40 {
            if !manager.isWorking { break }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        guard !manager.isRefreshing else { return false }
        if manager.isWorking {
            engine.log("Auto refresh: device list still loading after 20s, skipping this round.")
            return false
        }
        // C5：本轮读设备失败时不用旧清单做决策——旧的到期天数可能已变，
        // 对已删 App 发起续签只会白跑一趟。成功加载会清掉失败标记，
        // 标记与调用前不同，就是本轮刚失败；旧标记原样不动不算。
        if let failed = manager.lastLoadFailed, failed != failedBefore {
            engine.log("Auto refresh: device list failed to load (\(manager.lastLoadError ?? "unknown")), skipping this round.")
            return false
        }
        guard manager.hasLoaded else { return false }

        // 到期通知排期：每轮巡检拿到新清单就重排一次（本地通知，
        // 不用服务器）；旧的先清掉，新的按到期日排。
        ExpiryNotificationScheduler.reschedule(for: manager.entries)

        // 可续签的 App 里，描述文件已过期或 3 天内到期的才算到期。
        let dueIDs = Set(manager.refreshable.filter { job in
            guard let entry = manager.entries.first(where: { $0.app.bundleID == job.bundleID })
            else { return false }
            switch ExpiryUrgency.of(entry.current) {
            case .expired, .critical, .soon: return true
            default: return false
            }
        }.map(\.bundleID))
        guard !dueIDs.isEmpty else { return true }

        // 最短间隔：上一轮自动续签在 6 小时内就不重复跑。
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: Self.lastRoundKey)
        guard now - last >= Self.minRoundInterval else { return true }

        engine.log("Auto refresh: \(dueIDs.count) app(s) due within 3 days; refreshing.")
        manager.refreshAll(onlyBundleIDs: dueIDs)
        // 确认这一轮真的开跑了才记冷却时间：refreshAll 若被别的守卫
        // 静默拦下（没开跑），不白白等 6 小时，下一轮巡检还能重试。
        if manager.isRefreshing {
            UserDefaults.standard.set(now, forKey: Self.lastRoundKey)
        }
        return true
    }

    /// 隧道没通时没法续签；若已加载的清单显示有 App 今天/明天就过期，
    /// 12 小时最多提醒一次，让用户去连 LocalDevVPN。
    private func alertIfCritical(manager: SideloadedAppsManager) async {
        guard manager.hasLoaded else { return }
        let critical = manager.entries.filter {
            switch ExpiryUrgency.of($0.current) {
            case .expired, .critical: return true
            default: return false
            }
        }
        guard !critical.isEmpty else { return }
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: Self.lastAlertKey)
        guard now - last >= Self.minAlertInterval else { return }
        UserDefaults.standard.set(now, forKey: Self.lastAlertKey)
        await postNotification(
            title: L("续签提醒"),
            body: L("有 %d 个应用即将过期，但隧道未连接。连接隧道后将自动续签。", critical.count))
    }

    private func postNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "resign-auto-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // C11：到期提醒本身也可能发不出去——记一行日志，
            // 别用 try? 静默吞掉。
            Engine.shared.log("Auto refresh: notification failed to send (\(error.localizedDescription)).")
        }
    }
}

/// 到期通知排期（Seal 的 ExpiryNotificationScheduler，本机本地通知，
/// 不用服务器）：每轮巡检拿到新清单就重排一次。先清掉旧的
/// expiry-<bundleID>，再给 3 天内到期的 App 各排一条——到期前
/// 1 天提醒；24 小时内就到期的，1 小时后提醒。续签完到期日变了，
/// 下一轮巡检会自动重排，旧提醒不会赖着不走。
enum ExpiryNotificationScheduler {

    private static let prefix = "expiry-"

    static func reschedule(for entries: [SideloadedAppStatus]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let stale = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
            if !stale.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: stale)
            }
            let now = Date()
            for entry in entries {
                guard let current = entry.current,
                      let expiration = current.expirationDate else { continue }
                guard !current.isExpired,
                      let days = current.daysRemaining, days <= 3 else { continue }
                // 到期前 1 天提醒；不足 1 天的，1 小时后提醒。
                let fireDate = expiration.timeIntervalSince(now) <= 24 * 3600
                    ? now.addingTimeInterval(3600)
                    : expiration.addingTimeInterval(-24 * 3600)
                guard fireDate > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = L("续签提醒")
                let dateText = expiration.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Localizer.locale))
                content.body = L("%@ 将在 %@ 过期，打开 SideInstaller 续签。", entry.app.name, dateText)
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: fireDate),
                    repeats: false)
                let request = UNNotificationRequest(
                    identifier: prefix + entry.app.bundleID, content: content, trigger: trigger)
                Task { try? await center.add(request) }
            }
        }
    }
}
