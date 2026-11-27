import AppIntents

/// 快捷指令里的现成条目：之前只有 RefreshAllAppsIntent 这个动作，
/// 用户得自己在快捷指令里拼；现在直接给一个“一键续签全部”，
/// 在快捷指令 App 里搜“全部续签”就能找到、一点就跑。
/// 续签范围跟界面上的“全部续签”同一套：只续当前 Apple ID
/// 团队签的 App，证书签的一律排除（见 AppsView 的硬过滤）。
///
/// 上游 2.2.0 的 Siri/Spotlight 条目也合进来（位置、装应用、
/// 连 LocalDevVPN）；上游的 Refresh All Apps 报告版改名
/// RefreshAllAppsReportIntent，免得与 fork 的全部续签重名。
/// 注意：上游短语里的参数位 \(\\.$place)/\(\\.$app) 在 fork 模块里
/// 编不过（checks 三轮：单斜杠报 AppShortcutPhraseToken 无 $place 成员，
/// 双斜杠报 key path 缺路径；同字节上游能过、Summary 里同款也能过，
/// 根因未明）。先去掉参数位、只留应用名，Siri 改为运行时问值；
/// intent 本身不动，快捷指令 App 里照常能用。
struct SideInstallerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshAllAppsIntent(),
            phrases: [
                // App Shortcuts 的硬性规则：每条短语里必须带一次应用名，
                // 少一条编译期就直接报错（这次 #44 就是挂在这里）。
                "用 \(.applicationName) 全部续签",
                "用 \(.applicationName) 续签全部应用",
                "在 \(.applicationName) 里全部续签"
            ],
            shortTitle: "全部续签",
            systemImageName: "checkmark.seal.fill"
        )
        AppShortcut(intent: SetSavedPlaceIntent(),
                    phrases: ["Spoof my location to a saved place with \(.applicationName)",
                              "Set my \(.applicationName) location to a saved place",
                              "Spoof my location with \(.applicationName)"],
                    shortTitle: "Spoof Location",
                    systemImageName: "location.fill")
        AppShortcut(intent: ResetLocationIntent(),
                    phrases: ["Reset my location with \(.applicationName)",
                              "Stop spoofing my location with \(.applicationName)"],
                    shortTitle: "Reset Location",
                    systemImageName: "location.slash")
        AppShortcut(intent: StopRouteIntent(),
                    phrases: ["Stop the route in \(.applicationName)"],
                    shortTitle: "Stop Route",
                    systemImageName: "stop.circle")
        AppShortcut(intent: GetSpoofedLocationIntent(),
                    phrases: ["Where is my \(.applicationName) location"],
                    shortTitle: "Spoofed Location",
                    systemImageName: "mappin.and.ellipse")
        AppShortcut(intent: RefreshAllAppsReportIntent(),
                    phrases: ["Refresh my apps with \(.applicationName)",
                              "Refresh my sideloaded apps with \(.applicationName)"],
                    shortTitle: "Refresh All Apps",
                    systemImageName: "arrow.clockwise")
        AppShortcut(intent: InstallAppIntent(),
                    phrases: ["Install an app with \(.applicationName)"],
                    shortTitle: "Install App",
                    systemImageName: "square.and.arrow.down")
        AppShortcut(intent: ConnectLocalDevVPNIntent(),
                    phrases: ["Connect LocalDevVPN with \(.applicationName)"],
                    shortTitle: "Connect LocalDevVPN",
                    systemImageName: "network")
    }
}
