import Foundation

/// One finished one-click install: what landed, when, and with whose
/// certificate. Only successes are recorded, at `Engine.finishSuccess`;
/// a failed run leaves no entry. No password or pairing material is kept —
/// just the Apple ID (or certificate label) the install was signed with.
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
    static func record(appName: String, version: String?, identity: String) {
        logLock.lock()
        defer { logLock.unlock() }
        var entries = load()
        entries.insert(InstallHistoryEntry(id: UUID(), date: Date(),
                                           appName: appName, version: version,
                                           identity: identity), at: 0)
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
