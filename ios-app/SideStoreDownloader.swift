import Compression
import CryptoKit
import Foundation

/// Which release track to pull the IPA from.
enum ReleaseChannel: String, CaseIterable, Identifiable {
    case stable
    case nightly

    var id: String { rawValue }

    /// Label for the picker.
    var displayName: String {
        switch self {
        case .stable:  return L("Stable")
        case .nightly: return L("Nightly")
        }
    }

    /// Filename suffix, so stable and nightly downloads can coexist.
    var fileSuffix: String {
        switch self {
        case .stable:  return ""
        case .nightly: return "-nightly"
        }
    }
}

/// A copy of a build's IPA on someone else's repository, for while the build's
/// own is gone from GitHub.
struct Mirror {
    /// GitHub "owner/repo" holding the copy.
    let repo: String
    let url: URL
    let assetName: String
    /// The channel the copied build was published on.
    let channel: ReleaseChannel
    /// SHA-256 of the one file accepted from there, in lowercase hex.
    let sha256: String
}

/// A build that a repository's GitHub Actions workflow makes of a branch, for
/// a build installed from CI rather than from a release.
///
/// GitHub serves a workflow's artifacts only to a signed-in account, so the
/// zip is downloaded through nightly.link, which fetches it for anyone, and
/// checked against the SHA-256 GitHub's own API records for it.
struct ActionsBuild {
    /// GitHub "owner/repo" whose workflow makes the build.
    let repo: String
    /// The workflow's file name in `.github/workflows`.
    let workflow: String
    let branch: String
    /// The name the workflow uploads the IPA under: a zip holding it.
    let artifact: String

    /// Where nightly.link serves artifact `id` of `repo`.
    func relayURL(artifactID id: Int) -> URL? {
        URL(string: "https://nightly.link/\(repo)/actions/artifacts/\(id).zip")
    }
}

/// What to install: two SideStore builds and Madeira, fetched from GitHub, or a
/// user-supplied IPA. Nothing is known about the latter, so its release
/// properties are nil.
enum InstallSource: String, CaseIterable, Identifiable {
    case sideStore
    case liveContainer
    case madeira
    case custom

    var id: String { rawValue }

    /// Full name, used in logs.
    var displayName: String {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer + SideStore"
        case .madeira:       return "Madeira"
        case .custom:        return L("Custom .ipa")
        }
    }

    /// Short label for the segmented picker / button.
    var shortName: String {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "SS + LiveContainer"
        case .madeira:       return "Madeira"
        case .custom:        return L("Custom .ipa")
        }
    }

    /// GitHub "owner/repo" the IPA comes from: its releases, or for Madeira its
    /// Actions builds (`actionsBuild`).
    var repo: String? {
        switch self {
        case .sideStore:     return "SideStore/SideStore"
        case .liveContainer: return "LiveContainer/LiveContainer"
        case .madeira:       return "willfaust/Madeira"
        case .custom:        return nil
        }
    }

    /// The workflow whose newest build is installed, for a build taken from
    /// GitHub Actions instead of a release.
    ///
    /// Madeira's CI builds every push to main. Its newest release (0.1.3)
    /// predates the self-refresh (willfaust/Madeira#264, merged 28 October
    /// 2026) that SideInstaller hands its sign-in to.
    var actionsBuild: ActionsBuild? {
        switch self {
        case .madeira:
            return ActionsBuild(repo: "willfaust/Madeira", workflow: "build.yml",
                                branch: "main", artifact: "Madeira-ipa")
        case .sideStore, .liveContainer, .custom:
            return nil
        }
    }

    /// False for a build with no nightly release, which is always installed
    /// from the stable channel.
    var hasNightly: Bool {
        switch self {
        case .sideStore, .liveContainer: return true
        case .madeira, .custom:          return false
        }
    }

    /// The oldest iOS the build runs on, when that is newer than what
    /// SideInstaller itself installs on. Madeira's JIT helper needs iOS 26.
    var minimumOSMajorVersion: Int? {
        switch self {
        case .madeira:                            return 26
        case .sideStore, .liveContainer, .custom: return nil
        }
    }

    /// GitHub Releases API URL for a channel, used only when the direct download
    /// 404s. Nightly uses the `nightly` tag since `/releases/latest` skips
    /// pre-releases.
    func releaseAPI(_ channel: ReleaseChannel) -> URL? {
        guard let repo else { return nil }
        let base = "https://api.github.com/repos/\(repo)/releases"
        switch channel {
        case .stable:  return URL(string: "\(base)/latest")!
        case .nightly: return URL(string: "\(base)/tags/nightly")!
        }
    }

    /// Published `.ipa` asset name, used to build the direct download URL. Nil
    /// for Madeira, which comes from GitHub Actions.
    var assetFileName: String? {
        switch self {
        case .sideStore:        return "SideStore.ipa"
        case .liveContainer:    return "LiveContainer+SideStore.ipa"
        case .madeira, .custom: return nil
        }
    }

    /// True when a release's title only repeats the build's name and the
    /// version its tag carries ("SideStore 0.6.3" on "0.6.3").
    func titleRestatesTag(_ title: String, tag: String) -> Bool {
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return [version, tag].contains {
            title.caseInsensitiveCompare("\(displayName) \($0)") == .orderedSame
        }
    }

    /// Direct github.com download URL. Preferred over the API, which has a
    /// per-IP rate limit.
    func downloadURL(_ channel: ReleaseChannel) -> URL? {
        guard let repo, let assetFileName else { return nil }
        let base = "https://github.com/\(repo)/releases"
        switch channel {
        case .stable:  return URL(string: "\(base)/latest/download/\(assetFileName)")
        // The nightly tag is fixed, so nothing needs resolving.
        case .nightly: return URL(string: "\(base)/download/nightly/\(assetFileName)")
        }
    }

    /// A copy to install while `repo` is gone from GitHub, as LiveContainer's
    /// has been since GitHub hid its organization in October 2026.
    ///
    /// The copy is its last nightly (18 September 2026, commit 4dbe0f9), put up
    /// by someone who isn't a maintainer, so only that file is taken, by its
    /// hash. The hash is the one Atticus2077/lc-sidestore-nightly-source's CI
    /// recorded for the official asset on 25 September, before the takedown,
    /// and the copy that CI kept matches this one file for file. Anything else
    /// under the same link is refused, and no other build stands in for it.
    var mirror: Mirror? {
        switch self {
        case .liveContainer:
            return Mirror(
                repo: "LiveContainerMirror/LiveContainer",
                url: URL(string: "https://github.com/LiveContainerMirror/LiveContainer/releases/download/nightly/LiveContainer+SideStore.ipa")!,
                assetName: "LiveContainer+SideStore.ipa",
                channel: .nightly,
                sha256: "bec41bc21d75a0f2e85a0aa589ce5772e24e410deb017486758a3bc0503c8de7")
        case .sideStore, .madeira, .custom:
            return nil
        }
    }

    /// Local filename for the downloaded IPA, e.g. "SideStore-nightly.ipa", or
    /// "SideStore (0.6.3).ipa" for a version picked under Advanced.
    func fileName(_ channel: ReleaseChannel, version: String? = nil) -> String {
        guard let stem = fileStem else { return "Custom.ipa" }
        guard let version else { return "\(stem)\(channel.fileSuffix).ipa" }
        // A tag may hold a path separator.
        let safe = version.replacingOccurrences(of: "/", with: "-")
        return "\(stem)\(channel.fileSuffix) (\(safe)).ipa"
    }

    /// The version in a name `fileName(_:version:)` wrote, e.g. "0.6.3" in
    /// "SideStore (0.6.3).ipa"; nil for any other name.
    func version(inFileName name: String, channel: ReleaseChannel) -> String? {
        guard let stem = fileStem else { return nil }
        let prefix = "\(stem)\(channel.fileSuffix) (", suffix = ").ipa"
        guard name.hasPrefix(prefix), name.hasSuffix(suffix),
              name.count > prefix.count + suffix.count else { return nil }
        return String(name.dropFirst(prefix.count).dropLast(suffix.count))
    }

    /// Start of every downloaded filename; nil for a custom IPA.
    private var fileStem: String? {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer+SideStore"
        case .madeira:       return "Madeira"
        case .custom:        return nil
        }
    }

    // MARK: Pairing-file placement
    //
    // After install, the pairing file is written into the host app's container.
    // The app and path depend on the build (like iLoader's PAIRING_APPS table).

    /// Display name of the host app receiving the file, as installation_proxy
    /// reports it; isideload rewrites bundle ids, so names are matched instead.
    var pairingAppDisplayName: String? {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer"
        case .madeira:       return MadeiraPairingHandoff.appName
        case .custom:        return nil
        }
    }

    /// Base bundle id of the host app, which isideload suffixes with ".<teamID>".
    var pairingBundleIDBase: String? {
        switch self {
        case .sideStore:     return "com.SideStore.SideStore"
        case .liveContainer: return "com.kdt.livecontainer"
        case .madeira:       return MadeiraPairingHandoff.bundleID
        case .custom:        return nil
        }
    }

    /// Where the pairing file lands inside the host app's Documents; under
    /// LiveContainer, SideStore is a guest with a nested Documents folder.
    var pairingRemoteRelativePath: String {
        switch self {
        case .sideStore, .custom: return "ALTPairingFile.mobiledevicepairing"
        case .liveContainer:      return "SideStore/Documents/ALTPairingFile.mobiledevicepairing"
        case .madeira:            return MadeiraPairingHandoff.remoteRelativePath
        }
    }

    /// True when the app works without the pairing file, so failing to place
    /// it doesn't fail the install: Madeira can pair itself or use StikDebug,
    /// and nothing is known about a custom IPA.
    var pairingIsOptional: Bool {
        switch self {
        case .sideStore, .liveContainer: return false
        case .madeira, .custom:          return true
        }
    }

    /// Where SideStore lives in the installed app. Nil for a custom IPA, which
    /// only the signed bundle id can identify.
    var sideStoreHome: SideStoreHome? {
        switch self {
        case .sideStore:        return .standalone
        case .liveContainer:    return .liveContainer
        case .madeira, .custom: return nil
        }
    }

    /// Pick the right `.ipa` asset out of a release's assets.
    func selectAsset(from assets: [SideStoreDownloader.GHAsset]) -> SideStoreDownloader.GHAsset? {
        switch self {
        case .sideStore:
            // Publishes a single `.ipa` per release.
            return assets.first { $0.name.hasSuffix(".ipa") }
        case .liveContainer:
            // Prefer the published name, in case the asset is renamed later.
            return assets.first { $0.name == "LiveContainer+SideStore.ipa" }
                ?? assets.first { $0.name.lowercased().contains("sidestore") && $0.name.hasSuffix(".ipa") }
        case .madeira, .custom:
            // No release to pick from: Madeira comes from GitHub Actions.
            return nil
        }
    }
}

// MARK: - Versions to pick from

/// One release of a build, as the version picker under Advanced offers it, or
/// one GitHub Actions build of it.
struct ReleaseVersion: Identifiable, Hashable {
    /// The release's tag, e.g. "0.6.3" or "alpha"; for an Actions build, its
    /// short commit ("e96065a").
    let tag: String
    /// The release's title, which can carry a warning: "0.6.4 (DO NOT USE)".
    /// An Actions build's gives its date: "e96065a · 28 Oct 2026".
    let name: String
    /// The build's `.ipa` on this release, or an Actions build's zip.
    let assetName: String
    let assetURL: URL
    /// For an Actions build: the SHA-256 GitHub recorded for its zip, in
    /// lowercase hex. The download must match it, and the IPA is unpacked
    /// from the zip. Nil for a release, whose asset is the IPA itself.
    var artifactSHA256: String? = nil

    var id: String { tag }

    /// Short label: the tag, or the title when the two differ only in case
    /// ("Alpha").
    var title: String {
        name.caseInsensitiveCompare(tag) == .orderedSame ? name : tag
    }

    /// Menu label: the whole title when it starts with the tag, so the
    /// maintainers' remarks show; otherwise the tag and the title.
    var menuTitle: String {
        if name.isEmpty || name.caseInsensitiveCompare(tag) == .orderedSame { return title }
        return name.lowercased().hasPrefix(tag.lowercased()) ? name : "\(tag) – \(name)"
    }

    /// True when the title says more than the version.
    var hasRemark: Bool { menuTitle != title }

    // Identity is the tag, so a pick stays selected when the list reloads.
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.tag == rhs.tag }
    func hash(into hasher: inout Hasher) { hasher.combine(tag) }
}

/// A build's releases on GitHub, sorted into the two channels for the picker.
struct ReleaseCatalog {
    /// The release "Latest" installs on each channel, when the list has it.
    let latest: [ReleaseChannel: ReleaseVersion]
    /// Each channel's other releases carrying the build, newest first.
    let others: [ReleaseChannel: [ReleaseVersion]]
    let fetched: Date

    /// `releases` newest first, the order GitHub answers in.
    init(source: InstallSource, releases: [SideStoreDownloader.GHRelease], fetched: Date = Date()) {
        let offered = releases.compactMap { release -> (release: SideStoreDownloader.GHRelease,
                                                        version: ReleaseVersion)? in
            guard release.draft != true,
                  let asset = source.selectAsset(from: release.assets),
                  let url = URL(string: asset.browser_download_url) else { return nil }
            var name = (release.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // "Madeira 0.1.3" on the tag "v0.1.3" is no remark: it says what
            // the tag says.
            if source.titleRestatesTag(name, tag: release.tag_name) { name = release.tag_name }
            return (release, ReleaseVersion(tag: release.tag_name, name: name,
                                            assetName: asset.name, assetURL: url))
        }

        // Resolved as the download resolves "Latest": GitHub's newest full
        // release, and the fixed nightly tag, else the newest of either kind.
        var latest: [ReleaseChannel: ReleaseVersion] = [:]
        latest[.stable] = offered.first { $0.release.prerelease != true }?.version
        latest[.nightly] = (offered.first { $0.release.tag_name == "nightly" } ?? offered.first)?.version

        var others: [ReleaseChannel: [ReleaseVersion]] = [:]
        for (release, version) in offered {
            guard let channel = Self.channel(of: release), version != latest[channel] else { continue }
            others[channel, default: []].append(version)
        }
        self.latest = latest
        self.others = others
        self.fetched = fetched
    }

    /// For a build from GitHub Actions, which has no nightly: `builds` newest
    /// first, the first of them being what "Latest" installs.
    init(builds: [ReleaseVersion], fetched: Date = Date()) {
        latest = builds.first.map { [.stable: $0] } ?? [:]
        others = builds.count > 1 ? [.stable: Array(builds.dropFirst())] : [:]
        self.fetched = fetched
    }

    /// Nightly for a pre-release, whether GitHub flags it or its version says so
    /// ("0.7.0-alpha"); stable for a plain version number. Other tags
    /// ("auto-update-test") belong on neither.
    private static func channel(of release: SideStoreDownloader.GHRelease) -> ReleaseChannel? {
        let tag = release.tag_name
        let numbered = tag.drop(while: { $0 == "v" }).first?.isNumber == true
        // Semantic versioning puts a pre-release label after the first hyphen.
        let labelled = tag.split(separator: "-", maxSplits: 1).dropFirst().first?
            .contains(where: \.isLetter) == true
        if release.prerelease == true || (numbered && labelled) { return .nightly }
        return numbered ? .stable : nil
    }
}

/// Downloads the newest IPA on the chosen `InstallSource` + `ReleaseChannel`
/// into Documents.
enum SideStoreDownloader {

    struct GHAsset: Decodable {
        let name: String
        let browser_download_url: String
        let size: Int
    }
    struct GHRelease: Decodable {
        let tag_name: String
        let assets: [GHAsset]
        /// Optional so decoding doesn't depend on it. Used by the release scan to
        /// keep stable requests off pre-releases.
        let prerelease: Bool?
        /// The release's title. Optional, like `prerelease`.
        let name: String?
        let draft: Bool?
    }

    enum DownloadError: Error, CustomStringConvertible {
        case noIPAAsset(String, ReleaseChannel)
        case noRelease(String, ReleaseChannel)
        case badURL
        /// The chosen source has no release to download.
        case notDownloadable
        /// GitHub answered with a status rather than a release or an IPA,
        /// carrying its explanation and, for a rate limit, when it clears.
        case badStatus(status: Int, detail: String?, retryAfter: Date?)
        /// GitHub has no such repository ("owner/repo"): taken down, moved or
        /// made private. No network reaches the build, only the user's own copy.
        case repoUnavailable(String)
        /// The request never reached GitHub: offline, DNS, TLS, timeout, blocked.
        case unreachable(URLError)
        /// A 2xx whose body isn't the release JSON this app models.
        case badRelease(String)
        /// The bytes arrived and aren't an IPA.
        case notAnIPA(String)
        /// A pasted link returned a non-2xx status (kept separate from the
        /// GitHub-specific `badStatus`).
        case linkStatus(Int)
        /// GitHub lists no build of the branch an Actions build comes from
        /// ("Madeira", "main").
        case noBuild(String, branch: String)
        /// nightly.link, which an Actions build is downloaded through, didn't
        /// hand it over: its status, or why it couldn't be reached.
        case relayFailed(String, detail: String)
        /// What arrived for an Actions build isn't the zip GitHub recorded.
        case unverifiedBuild(String)

        var description: String {
            switch self {
            case let .noIPAAsset(source, channel):
                return L("couldn't find the IPA in the %@ %@ release",
                         channel.displayName.lowercased(), source)
            case let .noRelease(source, channel):
                return L("%@ has no %@ release right now",
                         source, channel.displayName.lowercased())
            case .badURL:
                return L("bad asset URL")
            case .notDownloadable:
                return L("there's nothing to download for a custom IPA — import one first")
            case let .badStatus(status, detail, retryAfter):
                // Replace GitHub's rate-limit text with when to retry.
                if let retryAfter {
                    return L("GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.",
                             Self.relative(retryAfter))
                }
                return L("GitHub answered HTTP %d%@", status, detail.map { ": \($0)" } ?? "")
            case let .repoUnavailable(repo):
                return L("GitHub isn't serving %@ right now — the repository has been taken down, moved or made private, so there's nothing to download. Nothing is wrong with this iPhone or its network.",
                         repo)
            case let .unreachable(error):
                return L("couldn't reach GitHub: %@", error.localizedDescription)
            case let .badRelease(detail):
                return L("GitHub's answer wasn't release information (%@) — something on this network may have replaced it.",
                         detail)
            case let .notAnIPA(name):
                return L("what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.",
                         name)
            case let .linkStatus(status):
                // Usually 401/403: the link requires signing in.
                return L("that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.",
                         status)
            case let .noBuild(source, branch):
                return L("GitHub has no build of %@'s %@ branch to download right now.", source, branch)
            case let .relayFailed(source, detail):
                return L("couldn't download %@ through nightly.link, which passes on GitHub's builds: %@",
                         source, detail)
            case let .unverifiedBuild(source):
                return L("the %@ build that arrived isn't the file GitHub recorded, so it isn't installed. Try again later.",
                         source)
            }
        }

        /// True when downloading the IPA another way would help (network
        /// interference), not for rate limits or missing releases.
        var manualSideloadHelps: Bool {
            switch self {
            case .unreachable, .badRelease, .notAnIPA, .relayFailed, .unverifiedBuild:
                return true
            case .noIPAAsset, .noRelease, .badURL, .notDownloadable, .linkStatus, .repoUnavailable,
                 .noBuild:
                return false
            case let .badStatus(_, _, retryAfter):
                return retryAfter == nil
            }
        }

        /// True when the build's repository is gone from GitHub, so only a copy
        /// the user brings can be installed.
        var isRepoUnavailable: Bool {
            if case .repoUnavailable = self { return true }
            return false
        }

        /// A 404 on the derived URL: the asset isn't under the expected name.
        var isAssetMissing: Bool {
            if case let .badStatus(status, _, _) = self { return status == 404 }
            return false
        }

        /// GitHub turned the request down for good, rather than asking to wait.
        var isRefused: Bool {
            if case let .badStatus(_, _, retryAfter) = self { return retryAfter == nil }
            return false
        }

        /// True when the channel's release is missing or has no usable IPA, so
        /// the repo's other releases should be scanned.
        var isChannelEmpty: Bool {
            switch self {
            case .noIPAAsset, .noRelease:
                return true
            case .badURL, .notDownloadable, .badStatus, .repoUnavailable, .unreachable,
                 .badRelease, .notAnIPA, .linkStatus, .noBuild, .relayFailed, .unverifiedBuild:
                return false
            }
        }

        /// "in 12 minutes", in the language of the surrounding sentence.
        private static func relative(_ date: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Localizer.locale
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }

    /// An IPA downloaded to a temporary file, whichever route found it.
    private struct Fetched {
        let file: URL
        /// The asset name GitHub gave it, which may differ from the one asked for.
        let name: String
        /// Channel of the release the file actually came from (can differ from
        /// the requested one after `fetchViaReleaseScan`). Used for the filename.
        let channel: ReleaseChannel
        /// GitHub's ETag for the file, so a later run can tell it hasn't changed.
        let etag: String?
    }

    /// Returns the local path of the downloaded IPA. `log` receives progress.
    static func downloadLatest(source: InstallSource,
                               channel: ReleaseChannel,
                               log: @escaping (String) -> Void) async throws -> String {
        guard source.repo != nil else { throw DownloadError.notDownloadable }
        if let actions = source.actionsBuild {
            let build = try await latestBuild(actions, of: source)
            log("Newest \(source.displayName) build of \(actions.repo)'s \(actions.branch) branch: \(build.menuTitle).")
            let dest = IPALibrary.documentsDir.appendingPathComponent(source.fileName(.stable))
            try await downloadArtifact(build, of: source, to: dest, log: log)
            return dest.path
        }

        let existing = IPALibrary.documentsDir.appendingPathComponent(source.fileName(channel))
        // What the log calls the asset until its name is known.
        var assetName = source.assetFileName ?? "\(source.displayName) IPA"
        let fetched: Fetched
        do {
            let asset = try await latestAsset(of: source, channel: channel)
            assetName = asset.name
            // Tens of megabytes aren't fetched again while the copy from an
            // earlier run is still the file GitHub serves.
            if let current = await unchangedDownload(existing, at: asset.url, log: log) {
                return current.path
            }
            fetched = try await fetch(asset.url, named: asset.name, from: channel, log: log)
        } catch let error as DownloadError where error.isRefused {
            // Either the asset was renamed, or the repository itself is gone.
            if let mirror = source.mirror, let repo = source.repo, await isGone(repo) {
                return try await downloadCopy(on: mirror, of: source, standingInFor: repo, log: log)
            }
            guard error.isAssetMissing else { throw error }
            log("No \(assetName) on that release — asking GitHub's API what the asset is called now.")
            do {
                fetched = try await fetchViaAPI(source: source, channel: channel, log: log)
            } catch let error as DownloadError where error.isChannelEmpty {
                fetched = try await fetchViaReleaseScan(source: source, channel: channel, log: log)
            }
        }

        let dest = IPALibrary.documentsDir.appendingPathComponent(source.fileName(fetched.channel))
        try store(fetched, as: dest)
        return dest.path
    }

    /// True when GitHub turns down a request for `repo`'s own page: taken down,
    /// private, blocked, or not being served. The website is asked, which has
    /// no hourly limit as the API does. False when it can't be told: no answer,
    /// or a rate limit.
    private static func isGone(_ repo: String) async -> Bool {
        guard let page = URL(string: "https://github.com/\(repo)") else { return false }
        var req = URLRequest(url: page, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        req.httpMethod = "HEAD"
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        guard let (_, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse else { return false }
        return !(200...299).contains(http.statusCode) && http.statusCode != 429 && retryAfter(http) == nil
    }

    /// Takes the build from the copy on `mirror` while `repo` is gone, and
    /// returns its local path. Only the file the mirror is trusted for is taken: a missing
    /// or different one is reported as the repository being unavailable.
    private static func downloadCopy(on mirror: Mirror, of source: InstallSource,
                                     standingInFor repo: String,
                                     log: @escaping (String) -> Void) async throws -> String {
        // Saved under the copy's own channel, whichever was asked for.
        let dest = IPALibrary.documentsDir.appendingPathComponent(source.fileName(mirror.channel))
        log("\(repo) isn't on GitHub right now — taking its last \(mirror.channel.displayName.lowercased()) build from the copy on \(mirror.repo).")

        if IPALibrary.sha256(of: dest) == mirror.sha256 {
            log("\(dest.lastPathComponent) is already that file — skipping the download.")
            return dest.path
        }
        // A file of that name the user put there isn't replaced.
        if FileManager.default.fileExists(atPath: dest.path), !DownloadLedger.isManaged(dest) {
            log("Using your own \(dest.lastPathComponent) instead — skipping the download.")
            return dest.path
        }

        let fetched: Fetched
        do {
            fetched = try await fetch(mirror.url, named: mirror.assetName, from: mirror.channel, log: log)
        } catch let error as DownloadError where error.isRefused {
            log("⚠️ \(mirror.repo) doesn't have it either: \(error)")
            throw DownloadError.repoUnavailable(repo)
        }
        guard IPALibrary.sha256(of: fetched.file) == mirror.sha256 else {
            try? FileManager.default.removeItem(at: fetched.file)
            log("⚠️ \(mirror.assetName) on \(mirror.repo) isn't the file SideInstaller accepts from there (SHA-256 \(mirror.sha256)) — it has been replaced, so it isn't installed.")
            throw DownloadError.repoUnavailable(repo)
        }
        log("\(mirror.assetName) is the file expected from there (SHA-256 \(mirror.sha256.prefix(12))…).")
        try store(fetched, as: dest)
        return dest.path
    }

    /// Where the channel's newest IPA is and what it's called, without asking
    /// the API.
    private static func latestAsset(of source: InstallSource,
                                    channel: ReleaseChannel) async throws -> (url: URL, name: String) {
        guard let direct = source.downloadURL(channel), let name = source.assetFileName else {
            throw DownloadError.notDownloadable
        }
        return (direct, name)
    }

    /// Downloads one release picked under Advanced. It's saved under its own
    /// name, so it never replaces the latest build or an IPA the user placed in
    /// Documents. Returns the local path; `log` receives progress.
    static func download(_ version: ReleaseVersion,
                         source: InstallSource,
                         channel: ReleaseChannel,
                         log: @escaping (String) -> Void) async throws -> String {
        let dest = IPALibrary.documentsDir
            .appendingPathComponent(source.fileName(channel, version: version.tag))
        if version.artifactSHA256 != nil {
            try await downloadArtifact(version, of: source, to: dest, log: log)
        } else {
            if let current = await unchangedDownload(dest, at: version.assetURL, log: log) {
                return current.path
            }
            let fetched = try await fetch(version.assetURL, named: version.assetName, from: channel, log: log)
            try store(fetched, as: dest)
        }

        // Keep one picked version per build and channel: drop the app's others.
        for other in IPALibrary.scan()
        where other.source == source && other.channel == channel
            && other.version != nil && other.url.lastPathComponent != dest.lastPathComponent {
            try? FileManager.default.removeItem(at: other.url)
            DownloadLedger.forget(other.url)
        }
        return dest.path
    }

    /// Moves a finished download into Documents as `dest`.
    private static func store(_ fetched: Fetched, as dest: URL) throws {
        // Validate now, so an error page or truncated download doesn't fail
        // later during signing.
        guard IPALibrary.looksLikeIPA(fetched.file) else {
            try? FileManager.default.removeItem(at: fetched.file)
            throw DownloadError.notAnIPA(fetched.name)
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: fetched.file, to: dest)
        // Mark as app-downloaded, so later runs may replace it, or reuse it while
        // GitHub still serves the same file.
        DownloadLedger.record(dest, etag: fetched.etag)
    }

    /// `file`, an IPA an earlier run downloaded, if GitHub still serves that
    /// exact file at `url`.
    ///
    /// Only the headers are fetched (a HEAD request). The file must be one this
    /// app downloaded and nothing has touched since, its recorded ETag must match
    /// GitHub's current one, and its size the Content-Length. Anything else,
    /// including a failed request, returns nil so the caller downloads as usual.
    private static func unchangedDownload(_ file: URL, at url: URL,
                                          log: @escaping (String) -> Void) async -> URL? {
        guard let recorded = DownloadLedger.etag(for: file),
              let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? Int
        else { return nil }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.httpMethod = "HEAD"
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let redirects = ReleaseTagRecorder()
        guard let result = try? await URLSession.shared.data(for: req, delegate: redirects),
              let http = result.1 as? HTTPURLResponse, http.statusCode == 200,
              http.value(forHTTPHeaderField: "ETag") == recorded,
              http.value(forHTTPHeaderField: "Content-Length").flatMap(Int.init) == size,
              IPALibrary.looksLikeIPA(file)
        else { return nil }

        let tag = redirects.tag.map { " (release \($0))" } ?? ""
        log("\(file.lastPathComponent) is already the file GitHub serves\(tag) — skipping the download.")
        return file
    }

    /// Download one URL to a temporary file, if the response isn't a refusal.
    private static func fetch(_ url: URL, named name: String, from channel: ReleaseChannel,
                              log: @escaping (String) -> Void) async throws -> Fetched {
        var req = URLRequest(url: url)
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let redirects = ReleaseTagRecorder()

        log("Downloading \(name) …")
        let (file, response) = try await perform(log: log) {
            try await URLSession.shared.download(for: req, delegate: redirects)
        }
        do {
            // No body to quote: the download host refuses in plain text, not JSON.
            try check(response)
        } catch {
            try? FileManager.default.removeItem(at: file)
            throw error
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let tag = redirects.tag.map { ", release \($0)" } ?? ""
        log("HTTP \(status) for \(name) — \(response.expectedContentLength) bytes\(tag)")
        return Fetched(file: file, name: name, channel: channel,
                       etag: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag"))
    }

    /// Downloads a pasted link into its own temp directory, saved as `name`.
    /// `progress` is called on an arbitrary queue.
    ///
    /// Separate from `fetch`: there's no release tag to record, and errors refer
    /// to the link rather than GitHub.
    static func fetchDirect(_ url: URL,
                            named name: String,
                            progress: @escaping (Double) -> Void) async throws -> URL {
        var req = URLRequest(url: url)
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("ipa-link-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let dest = staging.appendingPathComponent(name)

        return try await withCheckedThrowingContinuation { cont in
            // Progress is observed via KVO on the task's `Progress` instead of
            // a download delegate, which would conflict over the downloaded file.
            var observation: NSKeyValueObservation?
            let task = URLSession.shared.downloadTask(with: req) { file, response, error in
                observation?.invalidate()
                do {
                    if let error { throw error }
                    guard let file, let http = response as? HTTPURLResponse else {
                        throw DownloadError.badURL
                    }
                    guard (200...299).contains(http.statusCode) else {
                        throw DownloadError.linkStatus(http.statusCode)
                    }
                    // The temp file is deleted when this handler returns, so
                    // move it now.
                    try FileManager.default.moveItem(at: file, to: dest)
                    cont.resume(returning: dest)
                } catch let urlError as URLError {
                    cont.resume(throwing: urlError.code == .cancelled
                                ? CancellationError() : DownloadError.unreachable(urlError))
                } catch {
                    cont.resume(throwing: error)
                }
            }
            observation = task.progress.observe(\.fractionCompleted) { done, _ in
                progress(done.fractionCompleted)
            }
            task.resume()
        }
    }

    /// Ask the releases API where the IPA is, once the derived URL has 404'd.
    private static func fetchViaAPI(source: InstallSource,
                                    channel: ReleaseChannel,
                                    log: @escaping (String) -> Void) async throws -> Fetched {
        guard let api = source.releaseAPI(channel) else { throw DownloadError.notDownloadable }
        var req = URLRequest(url: api)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await perform(log: log) { try await URLSession.shared.data(for: req) }
        // A repo with no `nightly` tag answers 404: a missing channel, not a status.
        if (response as? HTTPURLResponse)?.statusCode == 404 {
            throw DownloadError.noRelease(source.displayName, channel)
        }
        try check(response, body: data)

        let release: GHRelease
        do {
            release = try JSONDecoder().decode(GHRelease.self, from: data)
        } catch {
            // The status was 2xx, so this is a real decode failure.
            throw DownloadError.badRelease(String(describing: error))
        }
        log("\(channel.displayName) \(source.displayName) release: \(release.tag_name) with \(release.assets.count) assets")

        guard let asset = source.selectAsset(from: release.assets) else {
            throw DownloadError.noIPAAsset(source.displayName, channel)
        }
        guard let assetURL = URL(string: asset.browser_download_url) else {
            throw DownloadError.badURL
        }
        return try await fetch(assetURL, named: asset.name, from: channel, log: log)
    }

    /// Scans the repo's recent releases for the newest one that has this build,
    /// used when the channel's own release doesn't.
    ///
    /// Needed for LiveContainer: its rolling `nightly` release can carry only
    /// `LiveContainer.ipa`, so the newest `LiveContainer+SideStore.ipa` is on a
    /// tagged release.
    ///
    /// Stable requests never fall back to a pre-release. Nightly requests take
    /// the newest release of either kind.
    private static func fetchViaReleaseScan(source: InstallSource,
                                            channel: ReleaseChannel,
                                            log: @escaping (String) -> Void) async throws -> Fetched {
        guard let repo = source.repo else { throw DownloadError.notDownloadable }
        log("That release has no \(source.displayName) IPA — looking through \(repo)'s other releases for one.")
        let releases = try await recentReleases(of: repo, count: 20)

        // Newest first, which is the order GitHub answers in.
        for release in releases {
            if channel == .stable, release.prerelease == true { continue }
            guard let asset = source.selectAsset(from: release.assets),
                  let assetURL = URL(string: asset.browser_download_url) else { continue }
            // Save under the release's actual channel, not the requested one.
            let served: ReleaseChannel = release.prerelease == true ? .nightly : .stable
            log("\(source.displayName) isn't published on the \(channel.displayName.lowercased()) release — taking \(asset.name) from release \(release.tag_name) instead.")
            return try await fetch(assetURL, named: asset.name, from: served, log: log)
        }
        throw DownloadError.noIPAAsset(source.displayName, channel)
    }

    /// Every release of `source` the version picker can offer, from one API
    /// call; for a build from GitHub Actions, its recent builds.
    static func releaseCatalog(source: InstallSource) async throws -> ReleaseCatalog {
        guard let repo = source.repo else { throw DownloadError.notDownloadable }
        if let actions = source.actionsBuild {
            let builds = try await recentBuilds(actions)
            // None among the newest uploads: "Latest" is still looked up.
            return ReleaseCatalog(builds: builds.isEmpty ? [try await newestRunBuild(actions, of: source)] : builds)
        }
        do {
            return ReleaseCatalog(source: source, releases: try await recentReleases(of: repo, count: 100))
        } catch let error as DownloadError where error.isRepoUnavailable && source.mirror != nil {
            // The copy is one build, which "Latest" installs: no others to offer.
            return ReleaseCatalog(source: source, releases: [])
        }
    }

    /// A repo's `count` newest releases, newest first.
    private static func recentReleases(of repo: String, count: Int) async throws -> [GHRelease] {
        try await apiGet("releases?per_page=\(count)", of: repo)
    }

    /// One answer of GitHub's API about `repo`, decoded. Every path asked for
    /// answers 200 when there's nothing to list, so a 404 is the repository
    /// itself.
    private static func apiGet<T: Decodable>(_ path: String, of repo: String) async throws -> T {
        guard let api = URL(string: "https://api.github.com/repos/\(repo)/\(path)")
        else { throw DownloadError.badURL }
        var req = URLRequest(url: api)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await perform { try await URLSession.shared.data(for: req) }
        if (response as? HTTPURLResponse)?.statusCode == 404 {
            throw DownloadError.repoUnavailable(repo)
        }
        try check(response, body: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw DownloadError.badRelease(String(describing: error))
        }
    }

    // MARK: Builds from GitHub Actions

    /// One upload of a workflow's artifact, as GitHub's API lists it.
    private struct GHArtifact: Decodable {
        struct Run: Decodable {
            let repository_id: Int
            let head_repository_id: Int?
            let head_branch: String?
            let head_sha: String
        }
        let id: Int
        let name: String
        let expired: Bool
        /// "sha256:<hex>" of the zip GitHub stores.
        let digest: String?
        let created_at: String?
        let workflow_run: Run?
    }
    private struct GHArtifactList: Decodable {
        let artifacts: [GHArtifact]
    }
    private struct GHRunList: Decodable {
        struct Run: Decodable {
            struct Repo: Decodable { let id: Int }
            let id: Int
            let event: String
            let repository: Repo
            let head_repository: Repo?
        }
        let workflow_runs: [Run]
    }

    /// The newest build of the branch, which "Latest" installs.
    private static func latestBuild(_ actions: ActionsBuild,
                                    of source: InstallSource) async throws -> ReleaseVersion {
        if let newest = try await recentBuilds(actions).first { return newest }
        return try await newestRunBuild(actions, of: source)
    }

    /// The branch's builds among the artifact's 100 newest uploads, newest
    /// first and one per commit, from one API call.
    ///
    /// Pull requests upload the artifact too, so only uploads by a run of the
    /// branch in the repository itself count: a fork's pull request runs with
    /// the fork as its head repository, even from a branch of the same name.
    private static func recentBuilds(_ actions: ActionsBuild) async throws -> [ReleaseVersion] {
        let list: GHArtifactList = try await apiGet(
            "actions/artifacts?name=\(actions.artifact)&per_page=100", of: actions.repo)
        var seen = Set<String>()
        return list.artifacts
            .filter { artifact in
                guard let run = artifact.workflow_run else { return false }
                return run.head_branch == actions.branch && run.head_repository_id == run.repository_id
            }
            // GitHub answers newest first already; ISO 8601 times sort as text.
            .sorted { ($0.created_at ?? "") > ($1.created_at ?? "") }
            .compactMap { version(of: $0, actions) }
            .filter { seen.insert($0.tag).inserted }
    }

    /// The build of the branch's newest successful run, from two API calls:
    /// for when the artifact's newest uploads are all pull requests'.
    private static func newestRunBuild(_ actions: ActionsBuild,
                                       of source: InstallSource) async throws -> ReleaseVersion {
        let runs: GHRunList = try await apiGet(
            "actions/workflows/\(actions.workflow)/runs?branch=\(actions.branch)&status=success&per_page=20",
            of: actions.repo)
        // The branch filter matches a fork's pull request from a branch of that
        // name too.
        guard let run = runs.workflow_runs.first(where: {
            !$0.event.hasPrefix("pull_request") && $0.head_repository?.id == $0.repository.id
        }) else { throw DownloadError.noBuild(source.displayName, branch: actions.branch) }
        let list: GHArtifactList = try await apiGet(
            "actions/runs/\(run.id)/artifacts?name=\(actions.artifact)", of: actions.repo)
        guard let build = list.artifacts.lazy.compactMap({ version(of: $0, actions) }).first
        else { throw DownloadError.noBuild(source.displayName, branch: actions.branch) }
        return build
    }

    /// An upload as the version picker shows it: its short commit, and the date
    /// it was built. Nil for one that's gone, or that GitHub records no SHA-256
    /// for, since nothing could vouch for what nightly.link hands over.
    private static func version(of artifact: GHArtifact, _ actions: ActionsBuild) -> ReleaseVersion? {
        guard artifact.name == actions.artifact, !artifact.expired,
              let commit = artifact.workflow_run?.head_sha, commit.count >= 7,
              let digest = artifact.digest?.lowercased(), digest.hasPrefix("sha256:"),
              let url = actions.relayURL(artifactID: artifact.id) else { return nil }
        let sha256 = String(digest.dropFirst("sha256:".count))
        guard sha256.count == 64, sha256.allSatisfy(\.isHexDigit) else { return nil }
        let short = String(commit.prefix(7))
        let built = artifact.created_at.flatMap { ISO8601DateFormatter().date(from: $0) }
        let name = built.map {
            "\(short) · \($0.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: Localizer.locale)))"
        } ?? short
        return ReleaseVersion(tag: short, name: name, assetName: "\(actions.artifact).zip",
                              assetURL: url, artifactSHA256: sha256)
    }

    /// Downloads Actions build `build` through nightly.link and keeps the IPA
    /// inside it as `dest`, unless `dest` is that build already. The zip must
    /// be the one GitHub recorded.
    private static func downloadArtifact(_ build: ReleaseVersion, of source: InstallSource, to dest: URL,
                                         log: @escaping (String) -> Void) async throws {
        guard let expected = build.artifactSHA256 else {
            throw DownloadError.unverifiedBuild(source.displayName)
        }
        // The ledger keeps the zip's checksum as the IPA's ETag.
        if DownloadLedger.etag(for: dest) == expected, IPALibrary.looksLikeIPA(dest) {
            log("\(dest.lastPathComponent) is already build \(build.tag) — skipping the download.")
            return
        }

        let fetched: Fetched
        do {
            fetched = try await fetchResuming(build.assetURL, named: build.assetName, log: log)
        } catch DownloadError.badStatus(let status, _, _) {
            throw DownloadError.relayFailed(source.displayName, detail: "HTTP \(status)")
        } catch DownloadError.unreachable(let error) {
            throw DownloadError.relayFailed(source.displayName, detail: error.localizedDescription)
        }
        defer { try? FileManager.default.removeItem(at: fetched.file) }
        guard IPALibrary.sha256(of: fetched.file) == expected else {
            log("⚠️ \(build.assetName) from nightly.link isn't the file GitHub recorded for build \(build.tag) (SHA-256 \(expected)), so it isn't installed.")
            throw DownloadError.unverifiedBuild(source.displayName)
        }
        log("\(build.assetName) is the file GitHub recorded for build \(build.tag) (SHA-256 \(expected.prefix(12))…) — unpacking the IPA.")

        let ipa = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).ipa")
        guard let member = IPALibrary.extractIPA(fromArtifact: fetched.file, to: ipa) else {
            try? FileManager.default.removeItem(at: ipa)
            throw DownloadError.notAnIPA(build.assetName)
        }
        try store(Fetched(file: ipa, name: member, channel: .stable, etag: expected), as: dest)
    }

    /// `fetch` for a file large enough that its transfer may stall: a stalled
    /// or dropped connection carries on from the bytes already saved. Throws
    /// what `fetch` throws.
    private static func fetchResuming(_ url: URL, named name: String, idleTimeout: TimeInterval = 30,
                              log: @escaping (String) -> Void) async throws -> Fetched {
        log("Downloading \(name) …")
        let download = ResumingDownload(from: url, name: name, idleTimeout: idleTimeout, log: log)
        do {
            let file = try await download.run()
            log("\(name): \(download.written) bytes\(download.resumes > 0 ? ", resumed \(download.resumes)×" : "")")
            return Fetched(file: file, name: name, channel: .stable, etag: nil)
        } catch {
            try? FileManager.default.removeItem(at: download.file)
            throw error
        }
    }

    /// Runs a URLSession call, mapping `URLError` to `.unreachable` (or to
    /// `CancellationError` when cancelled).
    ///
    /// A connection that drops is tried again, twice: the download overlaps the
    /// VPN coming up, which changes the network under a transfer already going,
    /// and a connection GitHub kept open from an earlier request can be dead by
    /// the time it's reused.
    private static func perform<T>(log: ((String) -> Void)? = nil,
                                   _ work: () async throws -> T) async throws -> T {
        var pauses: [UInt64] = [1, 3]
        while true {
            do {
                return try await work()
            } catch let error as URLError {
                // A cancelled install arrives as a URLError, and isn't a failure.
                if error.code == .cancelled { throw CancellationError() }
                guard droppedConnection.contains(error.code), !pauses.isEmpty else {
                    throw DownloadError.unreachable(error)
                }
                let pause = pauses.removeFirst()
                log?("Connection to GitHub dropped (\(error.localizedDescription)) — trying again in \(pause) s.")
                // Throws when the install is cancelled meanwhile.
                try await Task.sleep(nanoseconds: pause * 1_000_000_000)
            }
        }
    }

    /// Failures that arrive at once and can pass by themselves. A timeout isn't
    /// one: where GitHub is blocked, retrying would triple a minute's wait.
    private static let droppedConnection: Set<URLError.Code> = [
        .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost,
        .cannotFindHost, .dnsLookupFailed,
    ]

    /// Throws `badStatus` for a non-2xx response, before the body is decoded.
    private static func check(_ response: URLResponse, body: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw DownloadError.badStatus(status: http.statusCode,
                                          detail: body.flatMap(errorMessage(in:)),
                                          retryAfter: retryAfter(http))
        }
    }

    /// Retry time for a GitHub rate limit: from `retry-after` (seconds), or from
    /// `x-ratelimit-reset` (Unix time) when the hourly quota is used up.
    private static func retryAfter(_ http: HTTPURLResponse) -> Date? {
        if let seconds = http.value(forHTTPHeaderField: "retry-after").flatMap(Double.init) {
            return Date().addingTimeInterval(seconds)
        }
        guard http.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0",
              let reset = http.value(forHTTPHeaderField: "x-ratelimit-reset").flatMap(Double.init)
        else { return nil }
        return Date(timeIntervalSince1970: reset)
    }

    /// The `message` field of GitHub's JSON error body.
    private static func errorMessage(in data: Data) -> String? {
        struct Envelope: Decodable { let message: String }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              !envelope.message.isEmpty else { return nil }
        return envelope.message
    }
}

/// Downloads one file to disk, carrying on from the bytes already saved when
/// the transfer stalls or drops, instead of starting over.
///
/// Made for Actions builds: a couple of hundred megabytes from GitHub's
/// artifact storage, which can crawl and then stall. The start link
/// (nightly.link) redirects to a signed storage URL that works for about ten
/// minutes, so a later attempt asks that URL for the rest with a Range request,
/// and once it refuses, gets a fresh one from the start link.
private final class ResumingDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {

    /// The pause before each attempt in a row that got no new bytes; one more
    /// such attempt than there are pauses gives up.
    private static let pauses: [UInt64] = [1, 2, 4, 8, 15]

    /// Failures a moment later may not repeat. A TLS failure isn't one: on a
    /// network that intercepts it, it would only repeat.
    private static let passing: Set<URLError.Code> = [
        .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost,
        .cannotFindHost, .dnsLookupFailed,
    ]

    let file: URL
    private let start: URL
    private let name: String
    /// A transfer that gets no data for this long has stalled.
    private let idleTimeout: TimeInterval
    private let log: (String) -> Void
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // Written on `queue` while an attempt runs, read once it has ended.
    private var output: FileHandle?
    private(set) var written = 0
    private(set) var resumes = 0
    /// The file's full size, once a response has said it.
    private var total: Int?
    /// The signed URL the start link redirected to, while it's thought to work.
    private var storage: URL?
    private var status = 0
    /// A 206 that doesn't start at the byte asked for.
    private var misaligned = false
    private var writeError: Error?
    private var finish: CheckedContinuation<Error?, Never>?

    init(from start: URL, name: String, idleTimeout: TimeInterval, log: @escaping (String) -> Void) {
        self.start = start
        self.name = name
        self.idleTimeout = idleTimeout
        self.log = log
        file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).download")
    }

    /// Returns the downloaded file, `file`.
    func run() async throws -> URL {
        guard FileManager.default.createFile(atPath: file.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: file) else {
            throw CocoaError(.fileWriteUnknown)
        }
        output = handle
        defer { try? handle.close() }

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = idleTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        // The session holds on to its delegate until it's invalidated.
        defer { session.invalidateAndCancel() }

        var idle = 0
        while true {
            try Task.checkCancellation()
            let before = written, fromStorage = storage != nil
            let error = await attempt(in: session)
            if Task.isCancelled { throw CancellationError() }
            if let writeError { throw writeError }

            let transferred = status == 200 || status == 206
            if transferred, error == nil, !misaligned, total.map({ written >= $0 }) ?? true {
                return file
            }
            // Asked for the bytes after the last one: there are none.
            if status == 416, let total, written == total { return file }

            let reason: SideStoreDownloader.DownloadError
            // What the log says went wrong, when HTTP's status doesn't.
            var why: String?
            if misaligned || status == 416 {
                // Not the bytes asked for: start again from the first.
                why = "the server sent other bytes than the ones asked for, so it starts over"
                truncate()
                storage = nil
                reason = .badStatus(status: status, detail: nil, retryAfter: nil)
            } else if transferred || status == 0 {
                // The connection stalled or dropped, before or during the body.
                let urlError = (error as? URLError) ?? URLError(.networkConnectionLost)
                guard Self.passing.contains(urlError.code) else { throw SideStoreDownloader.DownloadError.unreachable(urlError) }
                reason = .unreachable(urlError)
            } else {
                reason = .badStatus(status: status, detail: nil, retryAfter: nil)
                if fromStorage {
                    // Expired, most likely: straight back to the start link,
                    // whose answer comes from a new storage link or not at all.
                    log("The storage link for \(name) answered HTTP \(status) — asking \(start.host ?? "the start link") for a new one.")
                    storage = nil
                    continue
                }
                guard status == 429 || (500...599).contains(status) else { throw reason }
            }

            idle = written > before ? 0 : idle + 1
            guard idle < Self.pauses.count else { throw reason }
            let pause = Self.pauses[idle]
            let cause = why ?? Self.describe(reason)
            if written > 0 {
                resumes += 1
                log("\(name) stopped at \(Self.megabytes(written)) of \(total.map(Self.megabytes) ?? "?") (\(cause)) — carrying on from there in \(pause) s.")
            } else {
                log("\(name) didn't arrive (\(cause)) — trying again in \(pause) s.")
            }
            try await Task.sleep(nanoseconds: pause * 1_000_000_000)
        }
    }

    /// One request for the bytes still missing. Returns how the transfer
    /// ended: nil when it ran to its end.
    private func attempt(in session: URLSession) async -> Error? {
        var request = URLRequest(url: storage ?? start)
        request.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        if written > 0 { request.setValue("bytes=\(written)-", forHTTPHeaderField: "Range") }
        status = 0
        misaligned = false
        let task = session.dataTask(with: request)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Set on the delegate queue, before anything can arrive there.
                queue.addOperation {
                    self.finish = continuation
                    task.resume()
                }
            }
        } onCancel: {
            task.cancel()
        }
    }

    // MARK: URLSessionDataDelegate, on `queue`

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // The range goes on to the storage URL.
        var next = request
        if written > 0 { next.setValue("bytes=\(written)-", forHTTPHeaderField: "Range") }
        completionHandler(next)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let http = response as? HTTPURLResponse
        status = http?.statusCode ?? 0
        switch status {
        case 200:
            // The whole file, from its first byte.
            truncate()
            total = response.expectedContentLength > 0 ? Int(response.expectedContentLength) : nil
        case 206:
            // "bytes <first>-<last>/<size>"
            let range = http?.value(forHTTPHeaderField: "Content-Range") ?? ""
            let numbers = range.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            guard numbers.first == written else {
                misaligned = true
                completionHandler(.cancel)
                return
            }
            if numbers.count == 3 { total = numbers[2] }
        default:
            completionHandler(.cancel)
            return
        }
        storage = response.url
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            try output?.write(contentsOf: data)
            written += data.count
        } catch {
            writeError = error
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish?.resume(returning: error)
        finish = nil
    }

    // MARK: Helpers

    /// Drops what was saved, for a response that starts from the first byte.
    private func truncate() {
        try? output?.truncate(atOffset: 0)
        written = 0
    }

    private static func megabytes(_ bytes: Int) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_000_000)
    }

    private static func describe(_ error: SideStoreDownloader.DownloadError) -> String {
        switch error {
        case let .unreachable(urlError): return urlError.localizedDescription
        case let .badStatus(status, _, _): return "HTTP \(status)"
        default: return error.description
        }
    }
}

/// Reads the release tag out of GitHub's redirect chain, since the download
/// passes through `releases/download/<tag>/<asset>` on its way to the bytes.
private final class ReleaseTagRecorder: NSObject, URLSessionTaskDelegate {

    /// Written on the delegate queue during the download, read once it's done.
    private(set) var tag: String?

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let found = Self.tag(in: request.url) { tag = found }
        guard task.originalRequest?.httpMethod == "HEAD" else {
            completionHandler(request)      // follow it, unchanged
            return
        }
        // A HEAD stays a HEAD all the way down, so checking a file never downloads it.
        var head = request
        head.httpMethod = "HEAD"
        head.cachePolicy = .reloadIgnoringLocalCacheData
        completionHandler(head)
    }

    /// The `<tag>` in `…/releases/download/<tag>/<asset>`, or nil for any other
    /// shape, including the `…/latest/download/<asset>` the chain starts from.
    static func tag(in url: URL?) -> String? {
        let parts = url?.pathComponents ?? []
        guard let download = parts.lastIndex(of: "download"),
              download > 0, parts[download - 1] == "releases",
              download + 2 < parts.count            // a tag *and* an asset after it
        else { return nil }
        return parts[download + 1]
    }
}

// MARK: - IPAs already on disk

/// IPAs in the app's Documents directory, whether downloaded, imported, or
/// copied in with the Files app.
enum IPALibrary {

    /// Where both the downloader and the Files app write.
    static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Folder for the imported custom IPA, separate so its name can't clash with
    /// a download.
    static var customDir: URL {
        documentsDir.appendingPathComponent("Custom", isDirectory: true)
    }

    /// One `.ipa` in Documents, tagged with the build its name identifies.
    struct Entry {
        let source: InstallSource
        let channel: ReleaseChannel
        let url: URL
        let size: Int
        let modified: Date?
        /// True when the user supplied this file rather than the app fetching it.
        let isImported: Bool
        /// The release picked under Advanced that the app downloaded this as;
        /// nil for the latest build, and for anything the user supplied.
        let version: String?
    }

    /// Which build a filename names, loose about case, separators and versions,
    /// since a hand-saved asset rarely keeps the exact published name.
    static func classify(_ fileName: String) -> (source: InstallSource, channel: ReleaseChannel)? {
        let name = fileName.lowercased()
        guard name.hasSuffix(".ipa") else { return nil }
        let source: InstallSource
        // LiveContainer's asset also carries "SideStore", so test it first.
        if name.contains("livecontainer")     { source = .liveContainer }
        else if name.contains("sidestore")    { source = .sideStore }
        else if name.contains("madeira")      { source = .madeira }
        else { return nil }
        return (source, name.contains("nightly") ? .nightly : .stable)
    }

    /// Every IPA the app can install, newest first.
    static func scan() -> [Entry] {
        let entries = describe(namesIn: documentsDir).compactMap { (name, url, attrs) -> Entry? in
            guard let kind = classify(name) else { return nil }
            let isManaged = DownloadLedger.isManaged(url)
            return Entry(source: kind.source, channel: kind.channel, url: url,
                         size: (attrs[.size] as? Int) ?? 0,
                         modified: attrs[.modificationDate] as? Date,
                         isImported: !isManaged,
                         // Read only off the app's own files: a user's
                         // "SideStore (1).ipa" names no version.
                         version: isManaged
                             ? kind.source.version(inFileName: name, channel: kind.channel) : nil)
        }
        return (entries + [customImport()].compactMap { $0 })
            .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    /// The imported IPA, if there is one; the newest wins if a stale one survives.
    static func customImport() -> Entry? {
        describe(namesIn: customDir)
            .filter { $0.name.lowercased().hasSuffix(".ipa") }
            .map { (name, url, attrs) in
                Entry(source: .custom, channel: .stable, url: url,
                      size: (attrs[.size] as? Int) ?? 0,
                      modified: attrs[.modificationDate] as? Date,
                      isImported: true, version: nil)
            }
            .max { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
    }

    /// Directory listing paired with each entry's attributes.
    private static func describe(namesIn dir: URL) -> [(name: String, url: URL, attrs: [FileAttributeKey: Any])] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.compactMap { name in
            let url = dir.appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return nil }
            return (name, url, attrs)
        }
    }

    /// The IPA to install for one build's latest release: an import outranks a
    /// download, the canonical filename outranks any other, and ties fall to the
    /// newest. Versions picked under Advanced are left out.
    static func entry(source: InstallSource, channel: ReleaseChannel) -> Entry? {
        guard source != .custom else { return customImport() }
        let canonical = source.fileName(channel)
        func rank(_ e: Entry) -> Int {
            (e.isImported ? 0 : 2) + (e.url.lastPathComponent == canonical ? 0 : 1)
        }
        return scan()
            .filter { $0.source == source && $0.channel == channel && $0.version == nil }
            .min { rank($0) < rank($1) }
    }

    /// The app's earlier download of a version picked under Advanced, if it's
    /// still intact.
    static func pickedDownload(_ version: String, source: InstallSource,
                               channel: ReleaseChannel) -> URL? {
        let url = documentsDir.appendingPathComponent(source.fileName(channel, version: version))
        return looksLikeIPA(url) ? url : nil
    }

    /// Thrown when the picked file isn't an IPA.
    enum ImportError: Error {
        case notAnIPA
    }

    /// Replaces the custom import with `url`, forcing a `.ipa` extension.
    /// Blocking. Copies to a staging directory first, so only a complete, valid
    /// IPA replaces the old one. The caller handles security-scoped access.
    static func replaceCustomImport(with url: URL) throws -> URL {
        let fm = FileManager.default
        let name = url.deletingPathExtension().lastPathComponent
        let staging = fm.temporaryDirectory
            .appendingPathComponent("ipa-import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        let staged = staging.appendingPathComponent(name).appendingPathExtension("ipa")

        try copy(url, to: staged)
        guard looksLikeIPA(staged) else { throw ImportError.notAnIPA }

        // One import at a time, so "the custom IPA" stays unambiguous.
        try? fm.removeItem(at: customDir)
        try fm.createDirectory(at: customDir, withIntermediateDirectories: true)
        let dest = customDir.appendingPathComponent(name).appendingPathExtension("ipa")
        // Same volume as the staging dir, so this is a rename, not a second copy.
        try fm.moveItem(at: staged, to: dest)
        return dest
    }

    /// Copy `src` to `dest` under a file coordinator, which waits for an iCloud
    /// placeholder to download instead of failing on it.
    private static func copy(_ src: URL, to dest: URL) throws {
        let fm = FileManager.default
        try? fm.startDownloadingUbiquitousItem(at: src)   // throws for non-iCloud items
        var copyError: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: src, options: [], error: &coordinationError) { readURL in
            do { try fm.copyItem(at: readURL, to: dest) } catch { copyError = error }
        }
        if let copyError { throw copyError }
        if let coordinationError { throw coordinationError }
    }

    /// True when the file is a complete zip, which every `.ipa` is. The `PK`
    /// header rejects a block page; the end-of-central-directory record, which
    /// sits in the last 65557 bytes, rejects a copy that stopped partway.
    static func looksLikeIPA(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard (try? handle.read(upToCount: 2)) == Data([0x50, 0x4B]) else { return false }   // "PK"

        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int,
              size >= 22 else { return false }
        let tailLength = min(size, 65_557)
        guard (try? handle.seek(toOffset: UInt64(size - tailLength))) != nil,
              let tail = try? handle.readToEnd() else { return false }
        return tail.range(of: Data([0x50, 0x4B, 0x05, 0x06])) != nil
    }

    /// A file's SHA-256 in lowercase hex, or nil if it can't be read.
    static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        // A megabyte at a time: an IPA is tens or hundreds of them, each
        // released before the next is read.
        while true {
            let more: Bool? = autoreleasepool {
                do {
                    // Nil or empty at the end of the file.
                    guard let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty else { return false }
                    hasher.update(data: chunk)
                    return true
                } catch {
                    return nil
                }
            }
            guard let more else { return nil }
            if !more { break }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// `.ipa` files in Documents whose names identify no known build.
    static func unrecognized() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: documentsDir.path)) ?? []
        return names.filter { $0.lowercased().hasSuffix(".ipa") && classify($0) == nil }.sorted()
    }
}

// MARK: - What an IPA will install

/// Reads `Payload/<name>.app/Info.plist` directly from an IPA using the zip
/// central directory, without unpacking the archive. The Sideloaded apps page
/// uses this to match IPAs on disk to installed apps. ZIP64 isn't supported.
extension IPALibrary {

    /// What an `.ipa` says it will put on the device.
    struct AppInfo: Equatable {
        /// Bundle ID as published. After isideload signs it, the installed app's
        /// ID has `.<teamID>` appended, so matching must allow for that.
        let bundleID: String
        let name: String
        let version: String?
    }

    /// IPAs on disk with their app info, newest first, one per bundle ID (the
    /// same build can exist as both a download and an import).
    static func installable() -> [(entry: Entry, info: AppInfo)] {
        var seen = Set<String>()
        return scan().compactMap { entry in
            guard let info = appInfo(at: entry.url),
                  seen.insert(info.bundleID).inserted else { return nil }
            return (entry, info)
        }
    }

    /// Reads an IPA's main `Info.plist`. Nil if it can't be read; such files are
    /// left out of the refresh list.
    static func appInfo(at url: URL) -> AppInfo? {
        guard let raw = infoPlist(inIPA: url),
              let plist = try? PropertyListSerialization.propertyList(from: raw, format: nil),
              let dict = plist as? [String: Any],
              let bundleID = dict["CFBundleIdentifier"] as? String, !bundleID.isEmpty
        else { return nil }
        let display = dict["CFBundleDisplayName"] as? String
        let bundleName = dict["CFBundleName"] as? String
        let name = display?.isEmpty == false ? display!
            : (bundleName?.isEmpty == false ? bundleName! : bundleID)
        return AppInfo(bundleID: bundleID, name: name,
                       version: dict["CFBundleShortVersionString"] as? String)
    }

    /// One file inside an IPA, for copying it out without unpacking the rest.
    struct ArchiveFile {
        /// Path inside the archive, e.g. "Payload/SideStore.app/Assets.car".
        let path: String
        let size: Int
        let crc: UInt32
        /// Has an executable Unix mode: a Mach-O, which signing always rewrites.
        let isExecutable: Bool
        fileprivate let entry: ZipEntry
    }

    /// The regular files in the IPA at `url`, or nil if its central directory
    /// can't be read.
    static func archiveFiles(at url: URL) -> [ArchiveFile]? {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int,
              size > 22,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let directory = centralDirectory(handle, fileSize: size) else { return nil }
        return directory.compactMap { entry in
            let mode = entry.externalAttributes >> 16
            // Directories and symlinks aren't regular files.
            guard !entry.name.hasSuffix("/"), mode & 0o170000 != 0o120000 else { return nil }
            return ArchiveFile(path: entry.name, size: entry.uncompressedSize, crc: entry.crc,
                               isExecutable: mode & 0o111 != 0, entry: entry)
        }
    }

    /// A file's uncompressed bytes, or nil if they can't be read.
    static func contents(of file: ArchiveFile, in url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return contents(of: file.entry, handle, maxSize: 1 << 30)
    }

    /// One entry of the archive's central directory.
    fileprivate struct ZipEntry {
        let name: String
        let method: Int
        let crc: UInt32
        let compressedSize: Int
        let uncompressedSize: Int
        /// The Unix mode sits in the high 16 bits for an archive made on Unix.
        let externalAttributes: UInt32
        let localHeaderOffset: Int
    }

    private static func infoPlist(inIPA url: URL) -> Data? {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int,
              size > 22,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let directory = centralDirectory(handle, fileSize: size),
              let entry = mainInfoPlist(in: directory) else { return nil }
        return contents(of: entry, handle)
    }

    /// The central directory, found through the end-of-central-directory record
    /// in the archive's last 64 KB.
    private static func centralDirectory(_ handle: FileHandle, fileSize: Int) -> [ZipEntry]? {
        let tailLength = min(fileSize, 65_557)      // the record plus a full comment
        guard (try? handle.seek(toOffset: UInt64(fileSize - tailLength))) != nil,
              let tail = try? handle.readToEnd(),
              let found = tail.range(of: Data([0x50, 0x4B, 0x05, 0x06]), options: .backwards)
        else { return nil }
        let record = tail[found.lowerBound...]
        guard record.count >= 22 else { return nil }
        let offset = u32(record, 16)
        let length = u32(record, 12)
        // 0xFFFFFFFF puts the real numbers in a ZIP64 record this doesn't read.
        guard offset != 0xFFFF_FFFF, length > 0, offset + length <= fileSize,
              (try? handle.seek(toOffset: UInt64(offset))) != nil,
              let raw = try? handle.read(upToCount: length), raw.count == length
        else { return nil }
        return entries(in: raw)
    }

    private static func entries(in directory: Data) -> [ZipEntry] {
        var out: [ZipEntry] = []
        var cursor = 0
        while cursor + 46 <= directory.count {
            let header = directory[(directory.startIndex + cursor)...]
            guard u32(header, 0) == 0x0201_4B50 else { break }      // "PK\u{01}\u{02}"
            let nameLength = u16(header, 28)
            let total = 46 + nameLength + u16(header, 30) + u16(header, 32)
            guard cursor + total <= directory.count else { break }
            let start = header.startIndex + 46
            if let name = String(data: header[start..<(start + nameLength)], encoding: .utf8) {
                out.append(ZipEntry(name: name,
                                    method: u16(header, 10),
                                    crc: UInt32(truncatingIfNeeded: u32(header, 16)),
                                    compressedSize: u32(header, 20),
                                    uncompressedSize: u32(header, 24),
                                    externalAttributes: UInt32(truncatingIfNeeded: u32(header, 38)),
                                    localHeaderOffset: u32(header, 42)))
            }
            cursor += total
        }
        return out
    }

    /// The one app's own `Info.plist`: exactly `Payload/<name>.app/Info.plist`,
    /// which leaves out the ones inside nested extensions and frameworks.
    private static func mainInfoPlist(in entries: [ZipEntry]) -> ZipEntry? {
        entries.first { entry in
            let parts = entry.name.split(separator: "/", omittingEmptySubsequences: false)
            return parts.count == 3 && parts[0] == "Payload"
                && parts[1].hasSuffix(".app") && parts[2] == "Info.plist"
        }
    }

    private static func contents(of entry: ZipEntry, _ handle: FileHandle, maxSize: Int = 4 << 20) -> Data? {
        // Sanity limit: an Info.plist is only kilobytes, and the inflate below
        // allocates this size.
        guard entry.uncompressedSize > 0, entry.uncompressedSize < maxSize,
              entry.compressedSize > 0,
              let start = dataOffset(of: entry, handle),
              (try? handle.seek(toOffset: UInt64(start))) != nil,
              let raw = try? handle.read(upToCount: entry.compressedSize),
              raw.count == entry.compressedSize else { return nil }
        switch entry.method {
        case 0: return raw                                          // stored
        case 8: return inflate(raw, to: entry.uncompressedSize)      // deflated
        default: return nil
        }
    }

    /// Where an entry's bytes start. The local header before them repeats the
    /// name and carries its own extra field, whose length routinely differs
    /// from the central directory's.
    private static func dataOffset(of entry: ZipEntry, _ handle: FileHandle) -> Int? {
        guard (try? handle.seek(toOffset: UInt64(entry.localHeaderOffset))) != nil,
              let header = try? handle.read(upToCount: 30), header.count == 30,
              u32(header, 0) == 0x0403_4B50                        // "PK\u{03}\u{04}"
        else { return nil }
        return entry.localHeaderOffset + 30 + u16(header, 26) + u16(header, 28)
    }

    /// Unpacks the `.ipa` a GitHub Actions artifact wraps (a zip around the one
    /// file) into `dest`. Streamed, since it's hundreds of megabytes. Returns
    /// the IPA's name, or nil when the zip holds none or it can't be read.
    static func extractIPA(fromArtifact zip: URL, to dest: URL) -> String? {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: zip.path)[.size]) as? Int,
              size > 22,
              let input = try? FileHandle(forReadingFrom: zip) else { return nil }
        defer { try? input.close() }
        guard let entry = centralDirectory(input, fileSize: size)?
                .first(where: { $0.name.lowercased().hasSuffix(".ipa") }),
              entry.compressedSize > 0,
              let start = dataOffset(of: entry, input),
              (try? input.seek(toOffset: UInt64(start))) != nil,
              FileManager.default.createFile(atPath: dest.path, contents: nil),
              let output = try? FileHandle(forWritingTo: dest) else { return nil }
        defer { try? output.close() }

        // Madeira's workflow uploads it stored (`compression-level: 0`), but
        // upload-artifact deflates by default.
        let written: Int?
        switch entry.method {
        case 0:  written = copy(entry.compressedSize, from: input, to: output)
        case 8:  written = inflate(entry.compressedSize, from: input, to: output)
        default: written = nil
        }
        guard written == entry.uncompressedSize else { return nil }
        return (entry.name as NSString).lastPathComponent
    }

    /// Copies the next `count` bytes of `input` to `output`, a megabyte at a
    /// time. Returns how many it wrote, or nil when a read or write fails.
    private static func copy(_ count: Int, from input: FileHandle, to output: FileHandle) -> Int? {
        var left = count
        while left > 0 {
            // Each chunk is released before the next is read.
            let copied: Int? = autoreleasepool {
                guard let chunk = try? input.read(upToCount: min(left, 1 << 20)), !chunk.isEmpty,
                      (try? output.write(contentsOf: chunk)) != nil else { return nil }
                return chunk.count
            }
            guard let copied else { return nil }
            left -= copied
        }
        return count
    }

    /// Inflates the next `count` bytes of `input`, raw DEFLATE, into `output`,
    /// a megabyte at a time. Returns how many bytes it wrote, or nil when the
    /// data is damaged or cut short, or a read or write fails.
    private static func inflate(_ count: Int, from input: FileHandle, to output: FileHandle) -> Int? {
        let chunkSize = 1 << 20
        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }
        guard compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
                == COMPRESSION_STATUS_OK else { return nil }
        defer { compression_stream_destroy(stream) }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }

        var left = count, written = 0
        while left > 0 {
            // True at the end of the stream, false once a chunk is used up.
            let ended: Bool? = autoreleasepool {
                guard let chunk = try? input.read(upToCount: min(left, chunkSize)), !chunk.isEmpty
                else { return nil }
                left -= chunk.count
                let flags = left == 0 ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                return chunk.withUnsafeBytes { raw -> Bool? in
                    stream.pointee.src_ptr = raw.bindMemory(to: UInt8.self).baseAddress!
                    stream.pointee.src_size = raw.count
                    var idle = 0
                    while true {
                        stream.pointee.dst_ptr = buffer
                        stream.pointee.dst_size = chunkSize
                        let status = compression_stream_process(stream, flags)
                        let produced = chunkSize - stream.pointee.dst_size
                        if produced > 0 {
                            let out = Data(bytesNoCopy: buffer, count: produced, deallocator: .none)
                            guard (try? output.write(contentsOf: out)) != nil else { return nil }
                            written += produced
                        }
                        switch status {
                        case COMPRESSION_STATUS_END:
                            return true
                        case COMPRESSION_STATUS_OK:
                            // Input used up with room to spare: the next chunk.
                            // Finishing, there's none, and it still holds output,
                            // so it's called until the end unless it stops moving.
                            guard stream.pointee.src_size == 0, stream.pointee.dst_size > 0 else { continue }
                            if flags == 0 { return false }
                            idle = produced == 0 ? idle + 1 : 0
                            if idle == 3 { return nil }
                        default:
                            return nil
                        }
                    }
                }
            }
            guard let ended else { return nil }
            if ended { return written }
        }
        return nil          // the zip ended before the stream did
    }

    /// `COMPRESSION_ZLIB` is raw DEFLATE with no zlib wrapper, which is exactly
    /// what a zip member holds.
    private static func inflate(_ data: Data, to size: Int) -> Data? {
        var out = Data(count: size)
        let written = out.withUnsafeMutableBytes { dst -> Int in
            guard let target = dst.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return data.withUnsafeBytes { src -> Int in
                guard let source = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(target, size, source, data.count, nil,
                                                 COMPRESSION_ZLIB)
            }
        }
        return written == size ? out : nil
    }

    /// Little-endian reads relative to a slice's own start, which is where every
    /// offset in the format above is measured from.
    private static func u16(_ data: Data, _ at: Int) -> Int {
        let i = data.startIndex + at
        guard i >= data.startIndex, i + 1 < data.endIndex else { return 0 }
        return Int(data[i]) | Int(data[i + 1]) << 8
    }

    private static func u32(_ data: Data, _ at: Int) -> Int {
        u16(data, at) | u16(data, at + 2) << 16
    }
}

/// State kept in Application Support rather than the file-sharing-visible
/// Documents: the device pairing record, and isideload's certificate store.
enum PrivateStore {

    /// The device pairing file (from the RPPairing host, or imported).
    static var pairingFile: URL {
        resolve(private: directory.appendingPathComponent("rp_pairing_file.plist"),
                legacy: IPALibrary.documentsDir.appendingPathComponent("rp_pairing_file.plist"))
    }

    /// The classic lockdown pair record, minted over the tunnel. Cached because
    /// producing it is interactive and takes one of the device's pairing slots.
    static var lockdownPairRecord: URL {
        directory.appendingPathComponent("lockdown_pair_record.plist")
    }

    /// The pairing file handed to other apps: the RPPairing and lockdown records
    /// merged into one plist. Rebuilt from those two whenever it's needed.
    static var combinedPairingFile: URL {
        directory.appendingPathComponent("combined_pairing_file.plist")
    }

    /// Lockdown pair record for another device on the LAN (Side by Side), one
    /// file per IP address. Separate from `lockdownPairRecord`, which belongs to
    /// this iPhone.
    ///
    /// Keyed by address because the UDID isn't known before connecting. A record
    /// that stops working is created again.
    static func peerPairRecord(host: String) -> URL {
        peerPairingsFile(prefix: "lockdown", host: host)
    }

    /// RPPairing file for another device on the LAN (Side by Side), written when
    /// it pairs from its own Settings — the only way iOS 27 pairs over Wi-Fi.
    /// Separate from `pairingFile`, which belongs to this iPhone. Keyed by
    /// address like `peerPairRecord`.
    static func peerRemotePairing(host: String) -> URL {
        peerPairingsFile(prefix: "remote", host: host)
    }

    /// Where Side by Side pairs another device that has no address typed in.
    /// The pairing reports the address it connected from, and the file then
    /// moves to `peerRemotePairing(host:)`.
    static var unaddressedPeerRemotePairing: URL {
        peerPairingsDirectory.appendingPathComponent("remote-new.plist")
    }

    /// True while any pair record for another device is saved.
    static var hasPeerPairings: Bool {
        let files = try? FileManager.default.contentsOfDirectory(atPath: peerPairingsDirectory.path)
        return files?.isEmpty == false
    }

    /// Deletes every pair record saved for another device, so this iPhone keeps
    /// no working pairing with someone else's.
    static func forgetPeerPairings() {
        try? FileManager.default.removeItem(at: peerPairingsDirectory)
    }

    private static func peerPairingsFile(prefix: String, host: String) -> URL {
        // Keep only digits and dots for a safe filename.
        let key = host.filter { $0.isNumber || $0 == "." }
        return peerPairingsDirectory.appendingPathComponent("\(prefix)-\(key.isEmpty ? "unknown" : key).plist")
    }

    private static var peerPairingsDirectory: URL {
        let dir = directory.appendingPathComponent("peer-pairings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// isideload's `FsStorage` root, created on demand as isideload expects.
    static var isideload: URL {
        let url = resolve(private: directory.appendingPathComponent("isideload", isDirectory: true),
                          legacy: IPALibrary.documentsDir.appendingPathComponent("isideload", isDirectory: true))
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Application Support, which iOS doesn't create for you.
    private static var directory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The private location, or the old Documents copy if migration left one
    /// there.
    private static func resolve(private url: URL, legacy: URL) -> URL {
        _ = migrated
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { return url }
        if fm.fileExists(atPath: legacy.path) { return legacy }
        return url          // nothing yet: new state goes to the private location
    }

    /// Runs `migrate()` once per launch, before the first path is handed out.
    private static let migrated: Void = migrate()

    /// Moves files that were stored in Documents into Application Support.
    private static func migrate() {
        let docs = IPALibrary.documentsDir
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        for name in ["rp_pairing_file.plist", "isideload"] {
            relocate(docs.appendingPathComponent(name), to: support.appendingPathComponent(name))
        }
    }

    /// Copy, verify, then delete rather than move: a half-finished move would
    /// cost a re-pair or one of Apple's three certificate slots.
    private static func relocate(_ src: URL, to dest: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: src.path) else { return }
        // An existing destination means the leftover in Documents is stale.
        guard !fm.fileExists(atPath: dest.path) else {
            try? fm.removeItem(at: src)
            return
        }
        do {
            try fm.copyItem(at: src, to: dest)
            guard let before = tally(src), let after = tally(dest), before == after else {
                try? fm.removeItem(at: dest)
                return
            }
            try? fm.removeItem(at: src)
        } catch {
            try? fm.removeItem(at: dest)
        }
    }

    /// (file count, total bytes) under `url`, or nil if it can't be read.
    private static func tally(_ url: URL) -> (Int, Int)? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }
        guard isDir.boolValue else {
            guard let size = (try? fm.attributesOfItem(atPath: url.path)[.size]) as? Int else { return nil }
            return (1, size)
        }
        guard let walker = fm.enumerator(atPath: url.path) else { return nil }
        var count = 0, bytes = 0
        for case let name as String in walker {
            let child = url.appendingPathComponent(name)
            var childIsDir: ObjCBool = false
            guard fm.fileExists(atPath: child.path, isDirectory: &childIsDir), !childIsDir.boolValue
            else { continue }
            guard let size = (try? fm.attributesOfItem(atPath: child.path)[.size]) as? Int else { return nil }
            count += 1
            bytes += size
        }
        return (count, bytes)
    }
}

/// Remembers which IPAs the app downloaded itself, so it can refresh those
/// while leaving a file the user placed in Documents untouched.
enum DownloadLedger {

    private static let defaultsKey = "managedIPAs"
    private static let etagsKey = "managedIPAETags"

    /// Size and modification time, so a file replaced under the same name stops
    /// matching. Assumes nothing downstream rewrites the IPA in place.
    private static func fingerprint(_ url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let size = (attrs[.size] as? Int) ?? 0
        let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)@\(Int(modified))"
    }

    /// Ledger key: the path relative to Documents (the container path changes on
    /// app updates, and an import can share a filename with a download).
    private static func key(_ url: URL) -> String {
        let docs = IPALibrary.documentsDir.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(docs + "/") else { return url.lastPathComponent }
        return String(path.dropFirst(docs.count + 1))
    }

    private static var table: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// True only for a file this app downloaded and nothing has touched since.
    static func isManaged(_ url: URL) -> Bool {
        guard let fp = fingerprint(url) else { return false }
        return table[key(url)] == fp
    }

    /// ETags by ledger key, each stored as "<fingerprint>|<etag>" so it only ever
    /// describes the exact file it was recorded with.
    private static var etags: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: etagsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: etagsKey) }
    }

    static func record(_ url: URL, etag: String? = nil) {
        guard let fp = fingerprint(url) else { return }
        var t = table
        t[key(url)] = fp
        table = t
        // Replaced, or dropped when this download came without one.
        var e = etags
        e[key(url)] = etag.map { "\(fp)|\($0)" }
        etags = e
    }

    /// The ETag GitHub served `url` with, while the file is still exactly the one
    /// that was downloaded.
    static func etag(for url: URL) -> String? {
        guard let fp = fingerprint(url), table[key(url)] == fp,
              let entry = etags[key(url)], entry.hasPrefix(fp + "|") else { return nil }
        return String(entry.dropFirst(fp.count + 1))
    }

    static func forget(_ url: URL) {
        var t = table
        t.removeValue(forKey: key(url))
        table = t
        var e = etags
        e.removeValue(forKey: key(url))
        etags = e
    }
}
