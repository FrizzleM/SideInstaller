import Foundation

/// Compares this build's version against `latest_version.txt` in the repo and
/// reveals the Install screen's update banner if that one is newer. Every
/// failure is silent: it only ever means there's nothing to show.
@MainActor
final class UpdateChecker: ObservableObject {

    /// Raw contents of the version file on the default branch.
    static let versionFileURL =
        "https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/latest_version.txt"
    /// The install page the banner opens, which carries the OTA links.
    static let installPageURL = "https://frizzlem.github.io/SideInstaller/"

    /// The newest version GitHub advertises, once fetched.
    @Published private(set) var latestVersion: String?
    /// True once a newer version is found, until the banner is dismissed.
    @Published private(set) var showBanner = false

    /// This build's marketing version, e.g. "0.5.0".
    let currentVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"

    /// Fetch the remote version and reveal the banner if it's newer.
    func check() async {
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
