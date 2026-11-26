import Foundation

/// One finished one-click install: what landed, when, and with whose
/// certificate. Successes are recorded at `Engine.finishSuccess`;
/// failures are recorded too (F-A, 0.9.155), at the pipeline's catch, so
/// the row can say why it failed and offer the same one-tap reinstall.
/// No password or pairing material is kept — just the Apple ID (or
/// certificate label) the install was signed with.
struct InstallHistoryEntry: Codable, Identifiable {
    var id: UUID
    var date: Date
    var appName: String
    /// The installed build's version when known (a release download's tag,
    /// or the signed app's own version); nil for a custom IPA that carries
    /// no version the pipeline reads.
    var version: String?
    /// Who signed it: the Apple ID for a one-click install.
    var identity: String
    /// F-1 (0.9.168): the installed app's bundle ID (the signed one —
    /// personal-ID signing appends `.<teamID>`, so `historyIPAURL`
    /// matches its IPA by that prefix too). Two same-name clones
    /// (multi-open) share a name but never an ID, so this is what
    /// tells them apart in search and in reinstall. Optional: entries
    /// written before 0.9.168 have no such key and decode to nil — the
    /// synthesized decoder reads a defaulted property with
    /// `decodeIfPresent`, it doesn't demand the key — and a failed run
    /// that never got as far as signing records nil rather than an
    /// invented ID.
    var bundleID: String? = nil
    /// False for a run that failed; `failureReason` then says why. Defaults
    /// to true so entries written before 0.9.155 (no such key) still decode
    /// — the synthesized decoder reads a defaulted property with
    /// `decodeIfPresent`, it doesn't demand the key.
    var success: Bool = true
    /// The user-facing reason the run stopped, for failed entries only.
    var failureReason: String? = nil

    /// "SideStore 0.6.2", or just the name when no version is known.
    var title: String {
        guard let version, !version.isEmpty else { return appName }
        return "\(appName) \(version)"
    }
}

/// The install-history list: stored in Application Support, newest first,
/// at most 100 entries. Same shape as `CertSignLogStore` (a locked
/// read-modify-write on a JSON file); `record` runs on the main thread from
/// `Engine.finishSuccess`, the same thread the sign log's install path uses.
enum InstallHistoryStore {

    /// How many entries to keep; the oldest are dropped first.
    private static let maxEntries = 100

    private static let logLock = NSLock()

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("InstallHistory.json")
    }

    /// The entries, newest first; an unreadable file just means none yet.
    static func load() -> [InstallHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([InstallHistoryEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.date > $1.date }
    }

    private static func save(_ entries: [InstallHistoryEntry]) {
        // B-cand-3 (0.9.154): the old code swallowed write failures whole
        // (try? twice) — a full disk lost history with no trace. Log the
        // failure; the behaviour (best-effort write) is unchanged.
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Engine.shared.log("⛔️ InstallHistory: couldn't save (\(error.localizedDescription)).")
        }
    }

    /// Record one successful install.
    static func record(appName: String, version: String?, identity: String, bundleID: String? = nil) {
        logLock.lock()
        defer { logLock.unlock() }
        var entries = load()
        entries.insert(InstallHistoryEntry(id: UUID(), date: Date(),
                                           appName: appName, version: version,
                                           identity: identity, bundleID: bundleID), at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        save(entries)
    }

    /// F-A (0.9.155): record one failed install, with the user-facing
    /// reason it stopped — the same row the success path writes, so the
    /// history shows the failure and its one-tap reinstall instead of
    /// leaving no trace of the run.
    static func recordFailure(appName: String, version: String?, identity: String, reason: String, bundleID: String? = nil) {
        logLock.lock()
        defer { logLock.unlock() }
        var entries = load()
        entries.insert(InstallHistoryEntry(id: UUID(), date: Date(),
                                           appName: appName, version: version,
                                           identity: identity, success: false,
                                           failureReason: reason, bundleID: bundleID), at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        save(entries)
    }

    /// F3 (0.9.148): empty the history (`LogStore.clear` 同款：只清列表，
    /// 已装的 App 不受影响）。
    static func clear() {
        logLock.lock()
        defer { logLock.unlock() }
        save([])
    }
}
