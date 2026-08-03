import Foundation

/// Which release track to pull the IPA from. Both supported repos publish a
/// stable tagged release *and* a rolling `nightly` pre-release carrying the same
/// asset names, so the choice is orthogonal to `InstallSource`.
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

    /// Filename suffix, so a stable and a nightly download of the same app can
    /// coexist in Documents instead of overwriting each other.
    var fileSuffix: String {
        switch self {
        case .stable:  return ""
        case .nightly: return "-nightly"
        }
    }
}

/// What to install. `sideStore` and `liveContainer` are both SideStore builds —
/// the difference is which GitHub repo the IPA is fetched from (LiveContainer
/// + SideStore is SideStore with LiveContainer integrated). Which *release* of
/// that repo is picked comes from the `ReleaseChannel` the user selected.
///
/// `custom` is neither: it's whatever IPA the user handed the app, which is the
/// only route that works at all where GitHub is unreachable. Nothing about it
/// can be known ahead of time, so the properties that describe a *known* build
/// — the repo, the app the pairing file belongs to — are optional, and the code
/// that needs them has to say what it does without.
enum InstallSource: String, CaseIterable, Identifiable {
    case sideStore
    case liveContainer
    case custom

    var id: String { rawValue }

    /// Full name, used in logs.
    var displayName: String {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer + SideStore"
        case .custom:        return L("Custom .ipa")
        }
    }

    /// Short label for the segmented picker / button.
    var shortName: String {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "SS + LiveContainer"
        case .custom:        return L("Custom .ipa")
        }
    }

    /// GitHub "owner/repo" whose release holds the IPA — nil for a build that
    /// doesn't come from a release.
    var repo: String? {
        switch self {
        case .sideStore:     return "SideStore/SideStore"
        case .liveContainer: return "LiveContainer/LiveContainer"
        case .custom:        return nil
        }
    }

    /// GitHub releases API endpoint for a channel. `/releases/latest` skips
    /// pre-releases, so the nightly build is fetched by its `nightly` tag. Nil
    /// when there's no release to ask about.
    func releaseAPI(_ channel: ReleaseChannel) -> URL? {
        guard let repo else { return nil }
        let base = "https://api.github.com/repos/\(repo)/releases"
        switch channel {
        case .stable:  return URL(string: "\(base)/latest")!
        case .nightly: return URL(string: "\(base)/tags/nightly")!
        }
    }

    /// Local filename for the downloaded IPA, e.g. "SideStore-nightly.ipa".
    /// An imported IPA keeps its own name instead (see `IPALibrary.customDir`),
    /// so this is only ever a placeholder for `custom`.
    func fileName(_ channel: ReleaseChannel) -> String {
        let base: String
        switch self {
        case .sideStore:     base = "SideStore"
        case .liveContainer: base = "LiveContainer+SideStore"
        case .custom:        return "Custom.ipa"
        }
        return "\(base)\(channel.fileSuffix).ipa"
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
    /// locates the target app. Nil for an imported IPA — there's nothing to
    /// match on until it's been signed, so the caller reads it off the signed
    /// bundle instead.
    var pairingAppDisplayName: String? {
        switch self {
        case .sideStore:     return "SideStore"
        case .liveContainer: return "LiveContainer"
        case .custom:        return nil
        }
    }

    /// Base bundle id of the installed host app — fallback for resolving the
    /// install when the display-name lookup misses. isideload appends
    /// ".<teamID>" to this. Nil for the same reason as above.
    var pairingBundleIDBase: String? {
        switch self {
        case .sideStore:     return "com.SideStore.SideStore"
        case .liveContainer: return "com.kdt.livecontainer"
        case .custom:        return nil
        }
    }

    /// Where the pairing file must land, relative to the host app's Documents
    /// directory. Plain SideStore reads it at the Documents root. Under
    /// LiveContainer, SideStore runs as a guest whose Documents live in a
    /// nested folder, so the file goes there instead. An imported IPA gets the
    /// root path: it's what every AltStore-family app but LiveContainer uses,
    /// and for an IPA that wants no pairing file at all the write is harmless.
    var pairingRemoteRelativePath: String {
        switch self {
        case .sideStore, .custom: return "ALTPairingFile.mobiledevicepairing"
        case .liveContainer:      return "SideStore/Documents/ALTPairingFile.mobiledevicepairing"
        }
    }

    /// Pick the right `.ipa` asset out of a release's assets.
    func selectAsset(from assets: [SideStoreDownloader.GHAsset]) -> SideStoreDownloader.GHAsset? {
        switch self {
        case .sideStore:
            // Publishes a single `.ipa` per release.
            return assets.first { $0.name.hasSuffix(".ipa") }
        case .liveContainer:
            // Prefer the exact published bundle; fall back to any SideStore-
            // flavored .ipa in case the asset is renamed in a future release.
            return assets.first { $0.name == "LiveContainer+SideStore.ipa" }
                ?? assets.first { $0.name.lowercased().contains("sidestore") && $0.name.hasSuffix(".ipa") }
        case .custom:
            // No release to pick from.
            return nil
        }
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
    }

    enum DownloadError: Error, CustomStringConvertible {
        case noIPAAsset(String, ReleaseChannel)
        case noRelease(String, ReleaseChannel)
        case badURL
        /// The chosen source has no release to download — `.custom`, which is
        /// supplied by the user rather than fetched.
        case notDownloadable
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
            }
        }
    }

    /// Returns the local path of the downloaded IPA. `log` receives progress.
    static func downloadLatest(source: InstallSource,
                               channel: ReleaseChannel,
                               log: @escaping (String) -> Void) async throws -> String {
        guard let api = source.releaseAPI(channel) else { throw DownloadError.notDownloadable }
        var req = URLRequest(url: api)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")

        let (data, releaseResponse) = try await URLSession.shared.data(for: req)
        // A repo that has dropped (or never published) the `nightly` tag answers
        // 404 — report that as a missing channel rather than a decode failure.
        if let http = releaseResponse as? HTTPURLResponse, http.statusCode == 404 {
            throw DownloadError.noRelease(source.displayName, channel)
        }
        let release = try JSONDecoder().decode(GHRelease.self, from: data)
        log("\(channel.displayName) \(source.displayName) release: \(release.tag_name) with \(release.assets.count) assets")

        guard let asset = source.selectAsset(from: release.assets) else {
            throw DownloadError.noIPAAsset(source.displayName, channel)
        }
        guard let assetURL = URL(string: asset.browser_download_url) else {
            throw DownloadError.badURL
        }
        log("Downloading \(asset.name) (\(asset.size) bytes) …")

        let (tmp, response) = try await URLSession.shared.download(from: assetURL)
        if let http = response as? HTTPURLResponse {
            log("HTTP \(http.statusCode) for \(asset.name)")
        }

        let dest = IPALibrary.documentsDir.appendingPathComponent(source.fileName(channel))
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        // Claim the file, so a later run knows this copy came off GitHub and is
        // safe to replace — unlike one the user put there by hand.
        DownloadLedger.record(dest)
        return dest.path
    }
}

// MARK: - IPAs already on disk

/// The IPAs sitting in the app's Documents directory, however they got there.
///
/// Downloading isn't possible everywhere. The tunnel this install runs over is
/// loopback-only and iOS allows one VPN at a time, so while it's up there's no
/// proxy left to reach GitHub through — and in some countries GitHub is blocked
/// outright. The way around that is to fetch the IPA by hand, on any machine
/// and from any mirror, and copy it into SideInstaller's folder in the Files
/// app (`UIFileSharingEnabled` in Info.plist is what puts it there). The
/// install then reads it from disk instead of the network.
enum IPALibrary {

    /// Where both the downloader and the Files app write.
    static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Where an IPA imported for `InstallSource.custom` is kept. Its own folder,
    /// rather than a reserved filename in Documents, for two reasons: a custom
    /// IPA can be called anything — including the exact name a download uses —
    /// and keeping it apart means it never has to be renamed, so the user can
    /// still recognise what they picked.
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
        /// True when the app didn't download this file — the user supplied it.
        /// The install treats those two cases differently (see `Engine.download`).
        let isImported: Bool
    }

    /// Which build a filename names, or nil if it names neither. Deliberately
    /// loose about case, separators and version suffixes: someone saving a
    /// release asset by hand just as often ends up with `sidestore.ipa` or
    /// `SideStore_1.0.ipa` as with the exact name the downloader would write.
    static func classify(_ fileName: String) -> (source: InstallSource, channel: ReleaseChannel)? {
        let name = fileName.lowercased()
        guard name.hasSuffix(".ipa") else { return nil }
        let source: InstallSource
        // LiveContainer's asset carries "SideStore" in its name too, so the more
        // specific test has to run first or every LiveContainer build would read
        // as plain SideStore.
        if name.contains("livecontainer")     { source = .liveContainer }
        else if name.contains("sidestore")    { source = .sideStore }
        else { return nil }
        return (source, name.contains("nightly") ? .nightly : .stable)
    }

    /// Every IPA the app can install, newest first: the recognisable ones in
    /// Documents plus whatever has been imported for the custom source.
    static func scan() -> [Entry] {
        let entries = describe(namesIn: documentsDir).compactMap { (name, url, attrs) -> Entry? in
            guard let kind = classify(name) else { return nil }
            return Entry(source: kind.source, channel: kind.channel, url: url,
                         size: (attrs[.size] as? Int) ?? 0,
                         modified: attrs[.modificationDate] as? Date,
                         isImported: !DownloadLedger.isManaged(url))
        }
        return (entries + [customImport()].compactMap { $0 })
            .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    /// The IPA imported for `InstallSource.custom`, if there is one. Only ever
    /// one at a time — importing replaces — so the newest file wins if a stale
    /// one somehow survives.
    static func customImport() -> Entry? {
        describe(namesIn: customDir)
            .filter { $0.name.lowercased().hasSuffix(".ipa") }
            .map { (name, url, attrs) in
                Entry(source: .custom, channel: .stable, url: url,
                      size: (attrs[.size] as? Int) ?? 0,
                      modified: attrs[.modificationDate] as? Date,
                      isImported: true)
            }
            .max { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
    }

    /// Directory listing paired with each entry's file attributes, skipping
    /// anything that has vanished between the two calls.
    private static func describe(namesIn dir: URL) -> [(name: String, url: URL, attrs: [FileAttributeKey: Any])] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.compactMap { name in
            let url = dir.appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return nil }
            return (name, url, attrs)
        }
    }

    /// The IPA to install for one build, or nil if there's none on disk.
    ///
    /// An import outranks a download of the same build — it's there because
    /// someone chose to put it there — and within that, the exact filename the
    /// downloader writes wins, being the unambiguous one. `scan()` is already
    /// newest-first, and `min(by:)` keeps the first of equally ranked entries,
    /// so ties fall to the most recent file.
    static func entry(source: InstallSource, channel: ReleaseChannel) -> Entry? {
        guard source != .custom else { return customImport() }
        let canonical = source.fileName(channel)
        func rank(_ e: Entry) -> Int {
            (e.isImported ? 0 : 2) + (e.url.lastPathComponent == canonical ? 0 : 1)
        }
        return scan()
            .filter { $0.source == source && $0.channel == channel }
            .min { rank($0) < rank($1) }
    }

    /// Why an import didn't take. Separate from the file-system errors so the
    /// caller can tell "you picked the wrong file" — which needs its own advice
    /// — from "the copy failed".
    enum ImportError: Error {
        case notAnIPA
    }

    /// Replace the custom import with `url`, copying it into `customDir` under
    /// its own name. Returns the new location. Blocking (it copies, and may wait
    /// on an iCloud download) — call it off the main thread. The caller is
    /// responsible for any security-scoped access `url` needs.
    ///
    /// The extension is forced to `.ipa`: an IPA is a zip, and a browser that
    /// saved one may well have named it `.zip`. Since the picker accepts any
    /// file and the contents are what get checked, normalising here is what
    /// keeps such a file findable afterwards.
    ///
    /// The copy lands in a staging directory and is checked there, so the
    /// previous import survives everything that can go wrong — a full disk, a
    /// cloud file that never materialises, a wrong pick. Only a complete, valid
    /// IPA replaces it, and the replacement itself is a rename.
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

        // One import at a time: clearing the folder keeps "the custom IPA"
        // unambiguous, and stops old picks accumulating invisibly.
        try? fm.removeItem(at: customDir)
        try fm.createDirectory(at: customDir, withIntermediateDirectories: true)
        let dest = customDir.appendingPathComponent(name).appendingPathExtension("ipa")
        // Same volume as the staging dir, so this is a rename, not a second copy.
        try fm.moveItem(at: staged, to: dest)
        return dest
    }

    /// Copy `src` to `dest`, coordinated so a file picked out of iCloud Drive
    /// works.
    ///
    /// The picker hands back a URL for an item that may still be a placeholder —
    /// nothing has been downloaded yet — and a plain `copyItem` on one of those
    /// just fails. Asking for the download and then reading under a file
    /// coordinator is what makes the wait happen instead: the coordinator blocks
    /// until the file is really there. iCloud Drive is one of the sources the
    /// import guide names, so this is the advertised path, not an edge case.
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

    /// True when the file is a complete zip, which every `.ipa` is.
    ///
    /// Worth checking before an imported file is signed, because the population
    /// that imports is the population with an unreliable route to GitHub: a
    /// blocked download saves the block page under the name you asked for, and
    /// a copy through Files can stop halfway. Either way the file is only found
    /// out much later, as an opaque signing failure.
    ///
    /// Both halves are needed. The `PK` header rejects the block page; only the
    /// end-of-central-directory record rejects the truncated copy, because a
    /// half-written zip still opens with a perfectly good header. EOCD is the
    /// last thing a zip writer emits and sits within the final 65557 bytes (22
    /// fixed, plus a trailing comment of at most 65535), so finding it there is
    /// what says the whole archive arrived.
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

    /// `.ipa` files in Documents whose names identify no known build — worth
    /// mentioning when a download fails, since a misnamed import looks from the
    /// outside exactly like one that was ignored for no reason.
    static func unrecognized() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: documentsDir.path)) ?? []
        return names.filter { $0.lowercased().hasSuffix(".ipa") && classify($0) == nil }.sorted()
    }
}

/// Everything the app keeps that shouldn't be handed to the user in Files.
///
/// Documents is a shared surface as of 0.7.0: `UIFileSharingEnabled` (see
/// Info.plist) puts it in Files › On My iPhone › SideInstaller so an IPA can be
/// dropped in where GitHub is unreachable. That switch is all-or-nothing — it
/// exposes the whole directory, not a chosen subfolder — so anything in there
/// is visible, movable and deletable by hand, and travels wherever the folder
/// gets shared.
///
/// Two things must not be. The device pairing record is what authorises a host
/// to talk to this iPhone. isideload's storage holds the anisette machine
/// provisioning and the developer signing certificate — in plain files, because
/// this build uses its `fs-storage` backend rather than the keychain. Both live
/// in Application Support instead, which file sharing doesn't reach.
enum PrivateStore {

    /// The device pairing file produced by the RPPairing host.
    static var pairingFile: URL {
        resolve(private: directory.appendingPathComponent("rp_pairing_file.plist"),
                legacy: IPALibrary.documentsDir.appendingPathComponent("rp_pairing_file.plist"))
    }

    /// isideload's `FsStorage` root — anisette provisioning plus the developer
    /// certificate. Created on demand, since isideload expects it to exist.
    static var isideload: URL {
        let url = resolve(private: directory.appendingPathComponent("isideload", isDirectory: true),
                          legacy: IPALibrary.documentsDir.appendingPathComponent("isideload", isDirectory: true))
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Application Support, created on demand. Unlike Documents, iOS doesn't
    /// make this directory for you.
    private static var directory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The private location — unless the migration couldn't get the file there
    /// and a usable copy is still in Documents, in which case keep using that.
    /// Failing over rather than insisting is what stops a migration that didn't
    /// work from costing the user a re-pair or a certificate slot.
    private static func resolve(private url: URL, legacy: URL) -> URL {
        _ = migrated
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { return url }
        if fm.fileExists(atPath: legacy.path) { return legacy }
        return url          // nothing yet: new state goes to the private location
    }

    /// Runs `migrate()` exactly once per launch, before the first path is
    /// handed out. A `static let` is Swift's dispatch-once.
    private static let migrated: Void = migrate()

    /// Bring 0.6.x's files across from Documents, where file sharing now
    /// exposes them.
    private static func migrate() {
        let docs = IPALibrary.documentsDir
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        for name in ["rp_pairing_file.plist", "isideload"] {
            relocate(docs.appendingPathComponent(name), to: support.appendingPathComponent(name))
        }
    }

    /// Copy, verify, then delete the original — not `moveItem`.
    ///
    /// A move that dies partway leaves nothing behind, and losing either of
    /// these costs real work: no pairing file means pairing the device again,
    /// and no isideload store means isideload re-bootstraps and may mint a fresh
    /// signing certificate, burning one of the three slots Apple allows per
    /// Apple ID. So the original is only removed once the copy is provably
    /// complete, and anything short of that leaves Documents untouched for
    /// `resolve` to fall back to.
    private static func relocate(_ src: URL, to dest: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: src.path) else { return }
        // A destination that already exists is either a finished migration or
        // newer state; either way the leftover in Documents is the stale one.
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

    /// (file count, total bytes) under `url` — enough to tell a complete copy
    /// from a partial one without hashing megabytes. Nil if it can't be read.
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

/// Remembers which IPAs the app downloaded itself, so those can be told apart
/// from the ones a user dropped into Documents. The distinction is what lets
/// `Engine.download()` refresh its own stale copy from GitHub while leaving an
/// imported file — placed there deliberately, and possibly the only copy that
/// machine can get — untouched.
enum DownloadLedger {

    private static let defaultsKey = "managedIPAs"

    /// Size + modification time. Keying on the name alone would keep counting a
    /// file as ours after the user replaced it with their own build under the
    /// same name; a fingerprint stops matching the moment the bytes change.
    ///
    /// This assumes nothing downstream rewrites the IPA in place — signing reads
    /// it and emits a separate `.app` bundle (see `Engine.performSign`). If that
    /// ever changed, the app's own downloads would start reading as imported and
    /// it would quietly stop refreshing them from GitHub.
    private static func fingerprint(_ url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let size = (attrs[.size] as? Int) ?? 0
        let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)@\(Int(modified))"
    }

    /// A file's entry key: its path *relative to Documents*.
    ///
    /// Relative, not absolute, because the container path carries a UUID that
    /// iOS changes on every app update — absolute keys would stop matching
    /// after one. And a path rather than a bare filename, because IPAs live in
    /// two directories: a custom import called `SideStore.ipa` (the obvious
    /// name, since that's what GitHub hands you) would otherwise share an entry
    /// with the download of the same name, and deleting the import would erase
    /// the download's claim — leaving a file the app fetched itself reading as
    /// user-supplied, never refreshed from GitHub again.
    ///
    /// Downloads live at the Documents root, so their keys are unchanged from
    /// the filename-only scheme and existing entries carry over as they are.
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

    static func record(_ url: URL) {
        guard let fp = fingerprint(url) else { return }
        var t = table
        t[key(url)] = fp
        table = t
    }

    static func forget(_ url: URL) {
        var t = table
        t.removeValue(forKey: key(url))
        table = t
    }
}
