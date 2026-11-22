import Foundation

/// Compares this build's version against `latest_version.txt` in the repo and
/// reveals the Install screen's update banner if that one is newer. Every
/// failure is silent: it only ever means there's nothing to show.
/// 发版铁律：每次发版必须同步改 latest_version.txt 到新版本号，
/// 否则旧版永远不提示、新版误提示（1.5.2 stale 误提示实证：
/// txt 一度停在 1.5.2，比 0.9.x 全线都“新”，恢复调用前必须先
/// 把 txt 改回当前版本）。
@MainActor
final class UpdateChecker: ObservableObject {

    /// Raw contents of the version file on the default branch.
    static let versionFileURL =
        "https://raw.githubusercontent.com/wozofa-ship-it/SideInstaller/main/latest_version.txt"
    /// The install page the banner opens, which carries the OTA links.
    static let installPageURL = "https://github.com/wozofa-ship-it/SideInstaller"

    /// The newest version GitHub advertises, once fetched.
    @Published private(set) var latestVersion: String?
    /// True once a newer version is found, until the banner is dismissed.
    @Published private(set) var showBanner = false

    /// This build's marketing version, e.g. "0.5.0".
    let currentVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"

    /// UserDefaults key for the last check date: the version file changes
    /// every few days at most, so one check a day is enough (S6).
    private static let lastCheckKey = "SIDUpdateCheckerLastCheck"

    /// Fetch the remote version and reveal the banner if it's newer.
    func check() async {
        // One check a day: skip when the last check was recent, even if it
        // failed — failures are silent and the banner can wait a day.
        let now = Date()
        if let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date,
           now.timeIntervalSince(last) < 24 * 3600 { return }
        UserDefaults.standard.set(now, forKey: Self.lastCheckKey)
        guard let url = URL(string: Self.versionFileURL) else { return }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let body = String(data: data, encoding: .utf8) else { return }

        let latest = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latest.isEmpty else { return }
        latestVersion = latest
        showBanner = Self.isNewer(latest, than: currentVersion)
    }

    /// Close the banner for this launch.
    func dismiss() { showBanner = false }

    /// Compare dotted versions numerically, so "0.10.0" > "0.9.0".
    static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let a = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let b = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
