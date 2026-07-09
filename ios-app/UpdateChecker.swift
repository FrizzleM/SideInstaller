import Foundation

/// Checks GitHub for a newer release on launch and drives the "update available"
/// banner on the Install screen.
///
/// The latest published version lives in a one-line text file at the repo root
/// (`latest_version.txt`). On startup we fetch its raw contents over HTTPS and
/// compare against this build's `CFBundleShortVersionString`; if the remote is
/// newer, the banner is revealed until the user closes it. Every failure path
/// (no network, missing file, unparseable body) is silent — it just means
/// "nothing to show", never an error in the user's face.
@MainActor
final class UpdateChecker: ObservableObject {

    /// Raw contents of the version file on the default branch.
    static let versionFileURL =
        "https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/latest_version.txt"
    /// Where the banner sends the user to grab a newer build — the install page
    /// (index.html), which carries the OTA install links.
    static let installPageURL = "https://frizzlem.github.io/SideInstaller/"

    /// The newest version GitHub advertises, once fetched.
    @Published private(set) var latestVersion: String?
    /// True once a newer version is found and the user hasn't dismissed the banner.
    @Published private(set) var showBanner = false

    /// This build's marketing version, e.g. "0.5.0".
    let currentVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"

    /// Fetch the remote version and reveal the banner if it's newer than this
    /// build. Silent on any failure.
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

    /// Compare two dotted numeric versions component by component so that, e.g.,
    /// "0.10.0" > "0.9.0". Missing / non-numeric components count as 0.
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
