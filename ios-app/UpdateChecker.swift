import Foundation

/// Compares this build's version against the tag of the latest GitHub release
/// and reveals the Install screen's update banner if that one is newer. Betas
/// (prereleases) and drafts are never "latest", so they don't trigger it.
/// Every failure is silent: it only ever means there's nothing to show.
@MainActor
final class UpdateChecker: ObservableObject {

    /// The newest published, non-prerelease release; its `tag_name` is e.g. "v1.5.3".
    static let latestReleaseAPIURL =
        "https://api.github.com/repos/FrizzleM/SideInstaller/releases/latest"
    /// The install page the banner offers first, which carries the OTA links.
    static let installPageURL = "https://sideinstaller.net/"
    /// The latest release's unsigned IPA, for the banner's other two ways:
    /// signed with the Apple ID's certificate, or installed in LiveContainer.
    static let releaseIPAURL =
        "https://github.com/FrizzleM/SideInstaller/releases/latest/download/SideInstaller.ipa"

    /// The newest version GitHub advertises, once fetched.
    @Published private(set) var latestVersion: String?
    /// True once a newer version is found, until the banner is dismissed.
    @Published private(set) var showBanner = false

    /// This build's marketing version, e.g. "0.5.0".
    let currentVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"

    private struct Release: Decodable {
        let tag_name: String
    }

    /// Fetch the latest release's tag and reveal the banner if it's newer.
    func check() async {
        guard let url = URL(string: Self.latestReleaseAPIURL) else { return }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data),
              let latest = Self.version(fromTag: release.tag_name) else { return }

        latestVersion = latest
        showBanner = Self.isNewer(latest, than: currentVersion)
    }

    /// "v1.5.3" → "1.5.3". Nil for an empty tag.
    static func version(fromTag tag: String) -> String? {
        var v = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.first == "v" || v.first == "V" { v.removeFirst() }
        return v.isEmpty ? nil : v
    }

    /// Close the banner for this launch.
    func dismiss() { showBanner = false }

    /// Compare dotted versions numerically, so "0.10.0" > "0.9.0". Anything
    /// after a "-" (e.g. "-beta.1") is ignored.
    static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        func parts(_ v: String) -> [Int] {
            let core = v.split(separator: "-", maxSplits: 1).first ?? ""
            return core.split(separator: ".").map { Int($0) ?? 0 }
        }
        let a = parts(lhs)
        let b = parts(rhs)
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
