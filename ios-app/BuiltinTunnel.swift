//
//  BuiltinTunnel.swift
//  Side+
//
//  Side+ 自带的本地隧道：Packet Tunnel 扩展（TunnelProv，移植自开源的
//  LocalDevVPN —— 同为 SideStore 团队的 StosVPN 许可）建一条
//  10.7.0.0/24 的回环隧道，扩展把发往 10.7.0.1 的包原路反射回来，
//  minimuxer 因此能连上本机的 lockdown 服务，地址与 LocalDevVPN
//  完全一致，Engine/NetworkStatus 那侧不用改。
//
//  需要隧道时 Engine.tunnelUp() 先走这里；起不来（比如签名把网络
//  扩展权限剥掉了）才回退去唤起独立装的 LocalDevVPN。
//

import Foundation
import NetworkExtension

enum BuiltinTunnel {

    /// 扩展的 Bundle ID：主 App 的 ID + ".TunnelProv"（与 project.yml
    /// 里 TunnelProv 目标的 PRODUCT_BUNDLE_IDENTIFIER 必须一致）。
    static var providerBundleID: String {
        (Bundle.main.bundleIdentifier ?? "com.frizzle.sideinstaller") + ".TunnelProv"
    }

    /// 扩展在包里是否真的存在（PlugIns/TunnelProv.appex）。
    static var isBundled: Bool {
        Bundle.main.path(forResource: "TunnelProv", ofType: "appex", inDirectory: "PlugIns") != nil
    }

    /// 本机这份签名能不能建隧道：看描述文件（embedded.mobileprovision）
    /// 的权限表里有没有 packet-tunnel 的网络扩展权限。企业证书和开了
    /// 该能力的付费开发者描述文件都有；免费个人 ID 的 7 天描述文件
    /// 没有——那种签名下内置隧道根本起不来（LOC 同理，它也是隧道）。
    static var profileGrantsTunnel: Bool { cachedProfileGrantsTunnel }

    /// 签名在运行时不会变，解析一次就缓存（界面刷新会反复读）。
    private static let cachedProfileGrantsTunnel: Bool = {
        guard let profile = embeddedProfile(),
              let entitlements = profile["Entitlements"] as? [String: Any],
              let providers = entitlements["com.apple.developer.networking.networkextension"] as? [String] else {
            return false
        }
        return providers.contains("packet-tunnel-provider") || providers.contains("packet-tunnel")
    }()

    /// 内置隧道在这台设备上真能用：扩展在包里且签名带隧道权限。
    /// 安装/续签那些入口按这个分支：能用就直走内置隧道，不弹
    /// LocalDevVPN 的任何提示；不能用就回到原来的 LOC 提示。
    static var useBuiltinDirectly: Bool { isBundled && profileGrantsTunnel }

    /// embedded.mobileprovision 是 CMS 签名包着的一份 plist：按
    /// latin1 逐字节映射成字符串（字节不错位）截出 XML 段再解析。
    /// 只读 Entitlements（纯 ASCII），团队名之类非 ASCII 字段不碰。
    private static func embeddedProfile() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>", options: .backwards) else {
            return nil
        }
        let xml = String(text[start.lowerBound..<end.upperBound])
        guard let xmlData = xml.data(using: .utf8) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: xmlData, options: [], format: nil)) as? [String: Any]
    }

    /// 隧道在系统 VPN 列表里显示的名字，与 App 显示名一致。
    static let tunnelDisplayName = "SideInstaller"

    /// 内置隧道本端地址的 UserDefaults 键（设置页「隧道」段可改，
    /// SettingsView 的 @AppStorage 用同一键）。
    static let ifaceIPDefaultsKey = "CZFBuiltinTunnelIfaceIP"

    /// 当前生效的本端地址：读设置值，缺省或格式非法时回
    /// LocalDevVPN 的默认值。
    static var ifaceCIDR: String {
        let stored = (UserDefaults.standard.string(forKey: ifaceIPDefaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty,
           (try? CIDRValidator.shared.validateCIDR(
               stored, isRouteDestination: false, allowIntermediateAddresses: true)) != nil {
            return stored
        }
        return TunnelConstants.defaultIfaceIP
    }

    /// 当前生效的对端地址：与设置里的设备 IP 是同一个值（minimuxer
    /// 连的就是它），统一补成 /32。设备 IP 本身可能带 /32 后缀，
    /// NetworkStatus.host 先剥掉再拼。
    static var peerCIDR: String {
        NetworkStatus.host(Engine.shared.deviceIP) + "/32"
    }

    /// What one wait for the tunnel ended with.
    private enum TunnelWaitResult {
        case connected
        case invalid
        case timedOut
        case cancelled
    }

    /// One wait's shared state: the status notification, the timeout, and
    /// cancellation all settle through here, exactly once. A resume that
    /// lands before the continuation is stored is replayed to it, so no
    /// path can strand the wait and none can resume it twice.
    private final class TunnelWaitState: @unchecked Sendable {
        private let lock = NSLock()
        private var resumed = false
        private var result: TunnelWaitResult?
        private var observer: NSObjectProtocol?
        private var continuation: CheckedContinuation<TunnelWaitResult, Never>?

        func set(continuation: CheckedContinuation<TunnelWaitResult, Never>,
                 observer: NSObjectProtocol?) {
            lock.lock()
            self.continuation = continuation
            self.observer = observer
            let already = resumed
            let result = self.result
            lock.unlock()
            if already, let result { continuation.resume(returning: result) }
        }

        func resume(_ result: TunnelWaitResult) {
            lock.lock()
            guard !resumed else { lock.unlock(); return }
            resumed = true
            self.result = result
            let observer = self.observer
            let continuation = self.continuation
            self.observer = nil
            self.continuation = nil
            lock.unlock()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            continuation?.resume(returning: result)
        }
    }

    /// Waits for the tunnel to connect, go invalid, or time out — one
    /// status notification instead of polling every 300ms (S7). The timeout
    /// still bounds the wait when the notification never comes, and
    /// cancellation answers at once instead of waiting it out.
    @MainActor
    private static func waitForStatus(manager: NETunnelProviderManager,
                                     timeout: TimeInterval) async -> TunnelWaitResult {
        switch manager.connection.status {
        case .connected: return .connected
        case .invalid: return .invalid
        default: break
        }
        let state = TunnelWaitState()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<TunnelWaitResult, Never>) in
                // Subscribe first, then re-check: a change between the fast
                // path above and the subscription can't strand us. The
                // callback runs on the main queue, so the state is only ever
                // touched from the main actor and the lock-guarded paths.
                let observer = NotificationCenter.default.addObserver(
                    forName: .NEVPNStatusDidChange, object: manager.connection, queue: .main
                ) { _ in
                    switch manager.connection.status {
                    case .connected: state.resume(.connected)
                    case .invalid: state.resume(.invalid)
                    default: break
                    }
                }
                state.set(continuation: continuation, observer: observer)
                switch manager.connection.status {
                case .connected: state.resume(.connected)
                case .invalid: state.resume(.invalid)
                default: break
                }
                // Timeout fallback: the extension may die silently without
                // ever posting, so the wait is still bounded.
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(max(timeout, 0) * 1_000_000_000))
                    state.resume(.timedOut)
                }
            }
        } onCancel: {
            state.resume(.cancelled)
        }
    }

    /// 确保内置隧道已连接：没有配置就建（首次会弹系统的 VPN 许可
    /// 提示），已在连/已连上直接等结果。给两次机会：第一次若是刚
    /// 保存完配置、系统还没就绪而失败，重新读一遍配置再启一次。
    /// 成功返回 true；两次都失败返回 false，交给调用方回退
    /// LocalDevVPN。失败原因写进 App 日志，方便定位。
    @MainActor
    static func startAndWait(timeout: TimeInterval = 10) async -> Bool {
        guard isBundled else {
            Engine.shared.log("Built-in tunnel: TunnelProv.appex is missing from the app bundle.")
            return false
        }
        guard profileGrantsTunnel else {
            // 签名描述文件不带隧道权限（个人 ID 等）：系统不会让
            // 扩展起来，直接放弃，别白等两轮超时。
            Engine.shared.log("Built-in tunnel: provisioning profile has no packet-tunnel entitlement (personal-ID signing?) — built-in tunnel unavailable.")
            return false
        }
        for attempt in 1...2 {
            let manager: NETunnelProviderManager
            do {
                manager = try await loadOrCreateManager()
            } catch {
                Engine.shared.log("Built-in tunnel: load/create configuration failed on attempt \(attempt): \(error.localizedDescription)")
                continue
            }
            if manager.connection.status == .connected { return true }
            do {
                try manager.connection.startVPNTunnel()
            } catch {
                Engine.shared.log("Built-in tunnel: startVPNTunnel failed on attempt \(attempt): \(error.localizedDescription) (enabled=\(manager.isEnabled))")
                continue
            }
            // S7：等一次状态通知，不再 300ms 轮询；超时与取消仍有交代。
            switch await waitForStatus(manager: manager, timeout: timeout) {
            case .connected:
                return true
            case .invalid:
                Engine.shared.log("Built-in tunnel: connection went invalid on attempt \(attempt).")
            case .timedOut:
                break
            case .cancelled:
                return false
            }
        }
        Engine.shared.log("Built-in tunnel: not connected after 2 attempts.")
        return false
    }

    /// 停掉内置隧道。调用方：企业回环安装前（隧道会干扰 installd 的
    /// localhost 连接，v65 实证）、pill 手动关、租约闲置停（SIDE-2）。
    /// 注意“企业安装不需要隧道”只对回环路成立——Engine 配对路的企业
    /// 安装仍要隧道（见 Engine.runEnterpriseCertInstall）。尽力而为：
    /// 没配置、未连接、停失败都不阻断调用方（只写日志）。ID 操作需要时
    /// tunnelUp/startAndWait 会自动再拉起来，这里不用重起。
    static func stop() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            guard let manager = managers.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerBundleID
            }) else { return }
            // 未连接时 stopVPNTunnel 是空操作，不用先查状态。
            manager.connection.stopVPNTunnel()
        } catch {
            // 停失败不阻断安装：企业安装不依赖隧道，继续走本地服务。
            // 只抓 message（String）进主队列闭包，不抓 error 本身。
            let message = error.localizedDescription
            DispatchQueue.main.async {
                Engine.shared.log("Built-in tunnel: stop before enterprise install failed: \(message) (install continues)")
            }
        }
    }

    /// 找到我们自己的 VPN 配置；没有就建一份：本端读设置（默认
    /// 10.7.1.1/32），对端跟设备 IP 设置走（默认 10.7.0.1/32 ——
    /// minimuxer 连的就是对端地址）。
    private static func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existing = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerBundleID
        }) {
            // 漂移同步：显示名、本端/对端地址、启用状态任一项与当前
            // 期望不符，合并成一次保存＋重读，再交给启动流程。
            // 启用状态必须修：禁用配置调 startVPNTunnel 会立刻抛
            // NEVPNErrorDomain error 2（ConfigurationDisabled，#18）。
            var changed = false
            if existing.localizedDescription != tunnelDisplayName {
                existing.localizedDescription = tunnelDisplayName
                changed = true
            }
            if let proto = existing.protocolConfiguration as? NETunnelProviderProtocol {
                let currentIface = proto.providerConfiguration?[TunnelConstants.ifaceIPConfigurationKey] as? String
                let currentPeer = proto.providerConfiguration?[TunnelConstants.peerIPConfigurationKey] as? String
                if currentIface != ifaceCIDR || currentPeer != peerCIDR {
                    var config = proto.providerConfiguration ?? [:]
                    config[TunnelConstants.ifaceIPConfigurationKey] = ifaceCIDR
                    config[TunnelConstants.peerIPConfigurationKey] = peerCIDR
                    proto.providerConfiguration = config
                    changed = true
                }
            }
            if !existing.isEnabled {
                existing.isEnabled = true
                changed = true
            }
            if changed {
                try await existing.saveToPreferences()
                try await existing.loadFromPreferences()
                Engine.shared.log("Built-in tunnel: configuration updated (name/addresses/enabled).")
            }
            return existing
        }
        let manager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleID
        proto.serverAddress = NetworkStatus.host(Engine.shared.deviceIP)
        proto.providerConfiguration = [
            TunnelConstants.ifaceIPConfigurationKey: ifaceCIDR,
            TunnelConstants.peerIPConfigurationKey: peerCIDR,
        ]
        manager.protocolConfiguration = proto
        manager.localizedDescription = tunnelDisplayName
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        return manager
    }
}
