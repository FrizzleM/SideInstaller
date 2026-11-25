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
    /// The latest stable release's download for this app's own IPA.
    /// The packaging workflow publishes each version as release `v<version>`
    /// with this asset (0.9.149), so this URL only ever serves the current
    /// release — never an older one, as long as the release gate below
    /// confirms the tag names `latestVersion`.
    static let releaseDownloadURL =
        "https://github.com/wozofa-ship-it/SideInstaller/releases/latest/download/SideInstaller.ipa"
    /// The API that names the latest release and its assets.
    static let latestReleaseAPIURL =
        "https://api.github.com/repos/wozofa-ship-it/SideInstaller/releases/latest"
    /// The asset the release must carry for the self-update to light up.
    static let releaseAssetName = "SideInstaller.ipa"

    /// The newest version GitHub advertises, once fetched.
    @Published private(set) var latestVersion: String?
    /// True once a newer version is found, until the banner is dismissed.
    @Published private(set) var showBanner = false
    /// True only when the latest release's tag names the same version as
    /// `latestVersion` AND it carries the IPA asset: the safety gate for the
    /// About page's self-update (0.9.149). A stale or missing release, or
    /// any fetch failure, leaves this false and the update row stays
    /// static — never install an older build.
    @Published private(set) var updateAssetVerified = false

    /// This build's marketing version, e.g. "0.5.0".
    let currentVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"

    /// UserDefaults key for the last check date: the version file changes
    /// every few days at most, so one check a day is enough (S6).
    private static let lastCheckKey = "SIDUpdateCheckerLastCheck"

    /// What a check found. `.skipped` means the daily gate held and no
    /// request went out (only when `force` is false).
    enum CheckResult: Equatable {
        case skipped
        case upToDate
        case newer(String)
        case failed
    }

    /// Fetch the remote version and reveal the banner if it's newer.
    /// B2 (0.9.142): the stamp is only set once a version was really fetched.
    /// A failed check used to stamp too, so a launch with no network on the
    /// day a new version shipped silenced the banner for the next 24 hours.
    @discardableResult
    func check(force: Bool = false) async -> CheckResult {
        // One check a day: skip when the last successful check was recent.
        // A failed check stamps nothing, so the next launch tries again.
        let now = Date()
        if !force,
           let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date,
           now.timeIntervalSince(last) < 24 * 3600 { return .skipped }
        guard let url = URL(string: Self.versionFileURL) else { return .failed }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        // B5 (0.9.146): 15 seconds, not URLSession's 60-second default, so a
        // manual check on a weak network fails fast instead of sitting on
        // "Checking for updates…" for a minute.
        req.timeoutInterval = 15
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let body = String(data: data, encoding: .utf8) else { return .failed }

        let latest = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latest.isEmpty else { return .failed }
        latestVersion = latest
        showBanner = Self.isNewer(latest, than: currentVersion)
        // The release gate only runs when there is something newer: a
        // second request on every launch would be pure cost. A failed
        // gate leaves the banner as it is — the banner only opens a web
        // page — but the About row stays static.
        // B5 (0.9.153): the daily stamp is only set once the gate has
        // passed — or there is nothing newer to gate. A failed gate used
        // to stamp too, so the About row stayed static for the next 24
        // hours even though the release never verified. The "up to date"
        // stamp is unchanged: no gate runs, nothing to fail.
        let verified = showBanner ? await verifyReleaseAsset(for: latest) : true
        updateAssetVerified = showBanner ? verified : false
        guard verified else { return .newer(latest) }
        UserDefaults.standard.set(now, forKey: Self.lastCheckKey)
        return showBanner ? .newer(latest) : .upToDate
    }

    /// Checks the latest release against `latest`: it must be a formal
    /// release (not a draft or prerelease), its tag must name exactly that
    /// version, and its assets must include `SideInstaller.ipa`.
    /// Fails closed — any fetch or parse failure returns false.
    private func verifyReleaseAsset(for latest: String) async -> Bool {
        guard let url = URL(string: Self.latestReleaseAPIURL) else { return false }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        // Same 15-second bound as the version check (B5, 0.9.146).
        req.timeoutInterval = 15
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["draft"] as? Bool) == false,
              (json["prerelease"] as? Bool) == false,
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]] else { return false }
        // The tag names the version with a "v" in front ("v0.9.149").
        let tagVersion = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        // Equal, not just newer: a release for another version — older or
        // newer than the version file — is not the one to install.
        guard !Self.isNewer(tagVersion, than: latest), !Self.isNewer(latest, than: tagVersion) else { return false }
        return assets.contains { ($0["name"] as? String) == Self.releaseAssetName }
    }

    /// Close the banner for this launch.
    func dismiss() { showBanner = false }

    /// Compare dotted versions numerically, so "0.10.0" > "0.9.0". Anything
    /// after a "-" (e.g. "-beta.1") is ignored.
    nonisolated static func isNewer(_ lhs: String, than rhs: String) -> Bool {
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
