import Foundation

/// What to install. Both are SideStore builds — the difference is which
/// GitHub release the IPA is fetched from (LiveContainer + SideStore is
/// SideStore with LiveContainer integrated). SideStore pulls its latest stable
/// release; LiveContainer pulls its rolling `nightly` pre-release, which is
/// where the freshest LiveContainer + SideStore IPA is published. The rest of
/// the pipeline (sign, install, write pairing) is identical.
enum InstallSource: String, CaseIterable, Identifiable {
    case sideStore
    case liveContainer

    var id: String { rawValue }

    /// Full name, used in logs.
    var displayName: String {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer + SideStore"
        }
    }

    /// Short label for the segmented picker / button.
    var shortName: String {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "SS + LiveContainer"
        }
    }

    /// GitHub "owner/repo" whose release holds the IPA.
    var repo: String {
        switch self {
        case .sideStore:     return "SideStore/SideStore"
        case .liveContainer: return "LiveContainer/LiveContainer"
        }
    }

    /// GitHub releases API endpoint to read the IPA from. SideStore uses the
    /// latest stable release; LiveContainer uses its rolling `nightly`
    /// pre-release (the `/releases/latest` endpoint skips pre-releases, so we
    /// fetch the `nightly` tag directly).
    var releaseAPI: URL {
        let base = "https://api.github.com/repos/\(repo)/releases"
        switch self {
        case .sideStore:     return URL(string: "\(base)/latest")!
        case .liveContainer: return URL(string: "\(base)/tags/nightly")!
        }
    }

    /// Local filename for the downloaded IPA.
    var fileName: String {
        switch self {
        case .sideStore:     return "SideStore.ipa"
        case .liveContainer: return "LiveContainer+SideStore.ipa"
        }
    }

    // MARK: Pairing-file placement
    //
    // After install, the device pairing file is written into the *installed*
    // host app's container so SideStore can find it. The host app and the path
    // it reads differ between the two builds — mirrored from iLoader's
    // PAIRING_APPS table (src-tauri/src/pairing.rs).

    /// CFBundleDisplayName of the installed host app that receives the pairing
    /// file. installation_proxy reports this; matching on the display name
    /// (rather than a bundle id, which isideload rewrites) is how iLoader
    /// locates the target app.
    var pairingAppDisplayName: String {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer"
        }
    }

    /// Base bundle id of the installed host app — fallback for resolving the
    /// install when the display-name lookup misses. isideload appends
    /// ".<teamID>" to this.
    var pairingBundleIDBase: String {
        switch self {
        case .sideStore:     return "com.SideStore.SideStore"
        case .liveContainer: return "com.kdt.livecontainer"
        }
    }

    /// Where the pairing file must land, relative to the host app's Documents
    /// directory. Plain SideStore reads it at the Documents root. Under
    /// LiveContainer, SideStore runs as a guest whose Documents live in a
    /// nested folder, so the file goes there instead.
    var pairingRemoteRelativePath: String {
        switch self {
        case .sideStore:     return "ALTPairingFile.mobiledevicepairing"
        case .liveContainer: return "SideStore/Documents/ALTPairingFile.mobiledevicepairing"
        }
    }

    /// Pick the right `.ipa` asset out of a release's assets.
    func selectAsset(from assets: [SideStoreDownloader.GHAsset]) -> SideStoreDownloader.GHAsset? {
        switch self {
        case .sideStore:
            return assets.first { $0.name.hasSuffix(".ipa") }
        case .liveContainer:
            // Prefer the exact published bundle; fall back to any SideStore-
            // flavored .ipa in case the asset is renamed in a future release.
            return assets.first { $0.name == "LiveContainer+SideStore.ipa" }
                ?? assets.first { $0.name.lowercased().contains("sidestore") && $0.name.hasSuffix(".ipa") }
        }
    }
}

/// Downloads the latest release IPA for the chosen `InstallSource` into Documents.
enum SideStoreDownloader {

    struct GHAsset: Decodable {
        let name: String
        let browser_download_url: String
        let size: Int
    }
    struct GHRelease: Decodable {
        let tag_name: String
        let assets: [GHAsset]
    }

    enum DownloadError: Error, CustomStringConvertible {
        case noIPAAsset(String)
        case badURL
        var description: String {
            switch self {
            case let .noIPAAsset(source): return "couldn't find the IPA in the latest \(source) release"
            case .badURL: return "bad asset URL"
            }
        }
    }

    /// Returns the local path of the downloaded IPA. `log` receives progress.
    static func downloadLatest(source: InstallSource,
                               log: @escaping (String) -> Void) async throws -> String {
        var req = URLRequest(url: source.releaseAPI)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: req)
        let release = try JSONDecoder().decode(GHRelease.self, from: data)
        log("Latest \(source.displayName) release: \(release.tag_name) with \(release.assets.count) assets")

        guard let asset = source.selectAsset(from: release.assets) else {
            throw DownloadError.noIPAAsset(source.displayName)
        }
        guard let assetURL = URL(string: asset.browser_download_url) else {
            throw DownloadError.badURL
        }
        log("Downloading \(asset.name) (\(asset.size) bytes) …")

        let (tmp, response) = try await URLSession.shared.download(from: assetURL)
        if let http = response as? HTTPURLResponse {
            log("HTTP \(http.statusCode) for \(asset.name)")
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(source.fileName)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        return dest.path
    }
}
