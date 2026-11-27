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
    /// B-1 (0.9.178): when the last patrol round reached a decision
    /// (nothing due / a refresh started). `lastTickKey` stays the 10-minute
    /// dedup stamp — a skipped round must not move it (C26) — so the
    /// Settings footer reads this one, not the dedup stamp.
    private static let lastPatrolDecisionKey = "SIDAutoRefreshLastPatrolDecision"

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

    /// F-3 (0.9.177): when the last patrol round really ran (`tick()`
    /// stamping `lastTickKey`) and when the last automatic renewal
    /// round started (`lastRoundKey`) — read-only, for the Settings
    /// page's footer. Nil when that round never ran.
    /// B-1 (0.9.178): the patrol date now reads the decision stamp
    /// (`lastPatrolDecisionKey`), not the 10-minute dedup stamp — the
    /// A-3 early return (nothing due from the in-memory list) is a
    /// decision too, so it stamps as well; a nil stamp now truly means
    /// no patrol round ever decided.
    var lastPatrolDate: Date? {
        let t = UserDefaults.standard.double(forKey: Self.lastPatrolDecisionKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
    var lastRoundDate: Date? {
        let t = UserDefaults.standard.double(forKey: Self.lastRoundKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

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
        // B-3 (0.9.176): 批跑下载间隙 `isRunning` 也是 false——巡检
        // 放行会起跑续签、占住隧道，批跑后续项逐个撞
        // `guard !isRefreshing` 失败。返回 false（瞬时阻挡，与
        // 安装进行中同款），后台唤醒据此 finish(false)。
        guard !manager.isRefreshing, !engine.isRunning, !engine.batchUpdateRunning else { return false }

        // 来源去重：上一轮巡检 10 分钟内跑过就静默跳过。BG 唤醒、
        // 30 分钟循环、回前台三路撞在一起时，只留一轮干活。
        let tickNow = Date().timeIntervalSince1970
        let lastTick = UserDefaults.standard.double(forKey: Self.lastTickKey)
        guard tickNow - lastTick >= Self.minTickInterval else { return true }

        engine.refreshNetworkStatus()
        guard engine.vpnConnected else {
            await alertIfCritical(manager: manager)
            return false
        }

        // 到期判定（抽成小 helper：下面的跳过判断与正式决策用同一份定义）。
        func dueBundleIDs() -> Set<String> {
            Set(manager.refreshable.filter { job in
                guard let entry = manager.entries.first(where: { $0.app.bundleID == job.bundleID })
                else { return false }
                switch ExpiryUrgency.of(entry.current) {
                case .expired, .critical, .soon: return true
                default: return false
                }
            }.map(\.bundleID))
        }

        // A-3：内存清单已够判到期，就不拉隧道读设备——99% 的轮次结论
        // 都是“无到期”。四条全满足才跳过；任一条不满足走下面的全量 load。
        // 跳过时直接 return true（与“无到期”同一返回值），不盖去重戳、
        // 不重排到期通知——下次真 load 时再排。
        // B-1 (0.9.178): the decision stamp IS stamped here — "nothing
        // due" is a decision, so the footer moves even when every round
        // early-returns; only the 10-minute dedup stamp stays unstamped.
        if manager.hasLoaded,
           let lastRefreshed = manager.lastRefreshed,
           Date().timeIntervalSince(lastRefreshed) < 24 * 3600,
           manager.lastLoadFailed.map({ $0 < lastRefreshed }) ?? true,
           dueBundleIDs().isEmpty {
            UserDefaults.standard.set(tickNow, forKey: Self.lastPatrolDecisionKey)
            return true
        }

        // 读一次设备清单（安静模式，失败就等下一轮）。
        let failedBefore = manager.lastLoadFailed
        // A-4（SIDE-33）：load 起的那只 Task（没起跑时等那只在途的）
        // 与 20 秒 sleep 竞速，先到者恢复 continuation；load 的
        // Task<Void, Never>.value 不响应取消，task group 限不住时限，
        // 改用单次恢复守卫的 continuation 竞速，落败的 helper 空转
        // 结束、无害。两只都没有（正刷续签、load 起不来）时直接往下
        // 走判定，与旧的“isWorking 为假即跳出”同义。
        let loadTask = manager.load(quiet: true) ?? manager.inFlightLoadTask
        var loadTimedOut = false
        if let loadTask {
            // B-3 (0.9.162): S1 (0.9.159) 同款 — a bare continuation never
            // resumes when only the waiting task is cancelled: BG expiry
            // cancels the work Task and stop() cancels the loop Task, so
            // the patrol would hang until the 20 s sleep race fires and
            // `finish(ran)` would miss the BG deadline. `onCancel`
            // resumes through the same single-fire gate; the helpers keep
            // their claim() shape. The gate is hoisted out of the
            // continuation closure so `onCancel` can reach it, and the
            // `Task.isCancelled` recheck covers an `onCancel` that fired
            // before the continuation was stored (cancellation is sticky,
            // so the check still sees it).
            let gate = SingleResume()
            let finished: Bool = await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    gate.store(continuation)
                    if Task.isCancelled {
                        gate.resumeStored(returning: false)
                        return
                    }
                    Task {
                        await loadTask.value
                        if gate.claim() { continuation.resume(returning: true) }
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                        if gate.claim() { continuation.resume(returning: false) }
                    }
                }
            } onCancel: {
                gate.resumeStored(returning: false)
            }
            loadTimedOut = !finished
        }
        guard !manager.isRefreshing else { return false }
        if loadTimedOut {
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

        // C26：去重戳只在检查真正跑起来后才盖——盖在入口处会让隧道不通/
        // 清单失败的一轮也吃掉 10 分钟窗口（对照：lastRoundKey 在 :163
        // 确认真开跑才记）。hasLoaded 通过之后才算“这一轮真的查了”。
        // B-1 (0.9.178): the decision stamp lands here too — the same
        // round, the same decision point as the A-3 early return above.
        UserDefaults.standard.set(tickNow, forKey: Self.lastTickKey)
        UserDefaults.standard.set(tickNow, forKey: Self.lastPatrolDecisionKey)

        // 到期通知排期：每轮巡检拿到新清单就重排一次（本地通知，
        // 不用服务器）；旧的先清掉，新的按到期日排。
        ExpiryNotificationScheduler.reschedule(for: manager.entries)
        // F-3 (0.9.157): 企业证书/描述文件的到期通知同款重排 — 巡检
        // 每 30 分钟跑一次，证书重导后到期日变了也能跟上。
        EnterpriseCertExpiryNotifier.reschedule()

        // 可续签的 App 里，描述文件已过期或 3 天内到期的才算到期。
        let dueIDs = dueBundleIDs()
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
        guard await postNotification(
            title: L("续签提醒"),
            body: L("有 %d 个应用即将过期，但隧道未连接。连接隧道后将自动续签。", critical.count))
        else { return }
        UserDefaults.standard.set(now, forKey: Self.lastAlertKey)
    }

    private func postNotification(title: String, body: String) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "resign-auto-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            // C11：到期提醒本身也可能发不出去——记一行日志，
            // 别用 try? 静默吞掉。
            Engine.shared.log("Auto refresh: notification failed to send (\(error.localizedDescription)).")
            return false
        }
    }
}

/// Single-fire gate for the load/timeout race in `tick()`: whichever helper
/// wins resumes the continuation, the loser is a no-op (BuiltinTunnel 的
/// TunnelWaitState 同款：NSLock + resumed 标志）。
private final class SingleResume: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    /// True only for the first caller.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        resumed = true
        return true
    }

    /// B-3 (0.9.162): the continuation this gate guards, so
    /// `withTaskCancellationHandler`'s non-isolated `onCancel` can resume
    /// the wait `tick()` is stuck in. Stored under the same lock — the
    /// handler may run while the wait is still being set up, before the
    /// continuation exists.
    private var continuation: CheckedContinuation<Bool, Never>?
    func store(_ continuation: CheckedContinuation<Bool, Never>) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation = continuation
    }
    /// Resume the stored continuation once with `value` — first caller
    /// wins, later ones no-op. Deliberately does NOT claim the gate when
    /// nothing is stored yet: an `onCancel` that fires before `store`
    /// must not eat the claim, or the `Task.isCancelled` recheck after
    /// `store` would find the gate spent and the wait would hang until
    /// the 20 s sleep fires.
    func resumeStored(returning value: Bool) {
        lock.lock()
        guard !resumed, let continuation else {
            lock.unlock()
            return
        }
        resumed = true
        lock.unlock()
        continuation.resume(returning: value)
    }
}

/// F-3 (0.9.157): the enterprise certificate / provisioning profile's
/// expiry notice — the same local-notification shape as
/// `ExpiryNotificationScheduler`, but for the enterprise materials,
/// which otherwise only warn inside their own page: without the app open
/// nobody sees them expire. One notice each, 3 days before expiry; a
/// material already inside its last 3 days gets one an hour from now, so
/// opening the page still warns in time. Re-scheduling clears the old
/// ones first, so a re-import moves the notice with the new date — and a
/// removed certificate leaves no stale notice behind.
///
/// Permission is the launch flow's (`SideInstallerApp` asks once at
/// startup): this only schedules when the system says notifications are
/// allowed, and never asks by itself — a background patrol must not pop
/// a permission prompt. It touches nothing about renewal.
enum EnterpriseCertExpiryNotifier {

    private static let prefix = "enterprise-cert-expiry-"
    /// Days before expiry the notice fires.
    private static let advanceNotice: TimeInterval = 3 * 24 * 3600

    static func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }
            center.getPendingNotificationRequests { requests in
                let stale = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
                if !stale.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: stale)
                }
                schedule(center: center, kind: "cert",
                         expiration: EnterpriseCertStore.certInfo?.expiration)
                schedule(center: center, kind: "profile",
                         expiration: EnterpriseCertStore.provisionInfo?.expiration)
            }
        }
    }

    private static func schedule(center: UNUserNotificationCenter, kind: String, expiration: Date?) {
        guard let expiration else { return }
        let now = Date()
        guard expiration > now else { return }
        // 3 days before expiry; already inside the last 3 days, an hour
        // from now — the same "too soon to schedule ahead" shape the app
        // expiry scheduler uses.
        let fireDate = expiration.timeIntervalSince(now) <= advanceNotice
            ? now.addingTimeInterval(3600)
            : expiration.addingTimeInterval(-advanceNotice)
        guard fireDate > now, fireDate < expiration else { return }
        let content = UNMutableNotificationContent()
        content.title = L("Enterprise certificate expiring")
        let dateText = expiration.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Localizer.locale))
        content.body = kind == "cert"
            ? L("The enterprise certificate expires on %@. Re-import it in time.", dateText)
            : L("The enterprise provisioning profile expires on %@. Re-import it in time.", dateText)
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false)
        let request = UNNotificationRequest(
            identifier: prefix + kind, content: content, trigger: trigger)
        Task { try? await center.add(request) }
    }
}

/// F-3 (0.9.159): the iOS development certificate's expiry notice — the
/// same local-notification shape as `EnterpriseCertExpiryNotifier`, but for
/// the Apple ID's own certificates, which otherwise only warn inside their
/// own page: a free certificate lasts 7 days, so it expires more often
/// than anything else, and with the app closed nobody sees it coming —
/// then the next install just fails. One notice per certificate, 1 day
/// before expiry; a certificate already inside its last day gets one an
/// hour from now, so opening the page still warns in time. Re-scheduling
/// clears the old ones first, so a re-import moves the notice with the new
/// date, a revoked certificate leaves no stale notice behind, and signing
/// out clears them all. Expired certificates get no notice.
///
/// Permission is the launch flow's (`SideInstallerApp` asks once at
/// startup): this only schedules when the system says notifications are
/// allowed, and never asks by itself. It touches nothing about renewal.
enum DevCertExpiryNotifier {

    private static let prefix = "dev-cert-expiry-"
    /// Days before expiry the notice fires.
    private static let advanceNotice: TimeInterval = 24 * 3600

    static func reschedule(certs: [DevCert]) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }
            center.getPendingNotificationRequests { requests in
                let stale = requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
                if !stale.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: stale)
                }
                for cert in certs {
                    schedule(center: center, cert: cert)
                }
            }
        }
    }

    private static func schedule(center: UNUserNotificationCenter, cert: DevCert) {
        guard let expiration = cert.expiresAt else { return }
        let now = Date()
        guard expiration > now else { return }
        // 1 day before expiry; already inside the last day, an hour from
        // now — the same "too soon to schedule ahead" shape the enterprise
        // notifier uses.
        let fireDate = expiration.timeIntervalSince(now) <= advanceNotice
            ? now.addingTimeInterval(3600)
            : expiration.addingTimeInterval(-advanceNotice)
        guard fireDate > now, fireDate < expiration else { return }
        let content = UNMutableNotificationContent()
        content.title = L("Development certificate expiring")
        let dateText = expiration.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Localizer.locale))
        content.body = L("The development certificate \"%@\" expires on %@. Renew it in time, or installs will fail.",
                         cert.displayName, dateText)
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false)
        let request = UNNotificationRequest(
            identifier: prefix + cert.id, content: content, trigger: trigger)
        Task { try? await center.add(request) }
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
