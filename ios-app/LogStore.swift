import Foundation
import Observation

/// The activity log: every line Swift and the Rust core log, redacted, for the
/// console in Settings, Copy logs and problem reports.
///
/// Kept apart from `Engine` so a new line redraws only what shows the log.
/// Each line is redacted and stamped on a queue of its own, so neither the
/// main thread nor the Rust thread that logged it waits on `LogRedactor`. The
/// lines then reach `lines` on the main thread in the order they were logged,
/// several at a time when they come quickly.
@Observable
final class LogStore {

    static let shared = LogStore()

    struct Entry: Identifiable {
        let id = UUID()
        let stamp: String
        let text: String
    }

    /// The lines kept, oldest first. Changes on the main thread only.
    private(set) var lines: [Entry] = []

    /// How many lines to keep; the oldest are dropped first.
    private static let maxLines = 2000

    /// True when launched with `SIDEINSTALLER_LOG_STDOUT` set, which mirrors every
    /// line to stdout so a run on an iPhone can be followed and timed from a Mac
    /// (`xcrun devicectl device process launch --console`).
    private static let mirrorsToStdout =
        ProcessInfo.processInfo.environment["SIDEINSTALLER_LOG_STDOUT"] != nil

    private static let stampFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// Redacts, stamps and mirrors lines, one at a time in the order logged.
    /// `.utility` fell seconds behind a burst of 2000 lines in the simulator;
    /// this keeps up in a fifth of a second.
    @ObservationIgnored private let queue = DispatchQueue(label: "sideinstaller.log", qos: .userInitiated)
    /// Lines ready for `lines`, waiting for the main thread. Guarded by `lock`.
    @ObservationIgnored private var pending: [Entry] = []
    @ObservationIgnored private let lock = NSLock()

    private init() {}

    /// Adds a line. Safe to call from any thread; it shows up a moment later.
    func append(_ raw: String) {
        // Stamped with when it was logged, not when the queue got to it.
        let date = Date()
        queue.async { self.prepare(raw, loggedAt: date) }
    }

    /// Empties the log. Main thread only.
    func clear() {
        lines.removeAll()
    }

    /// The whole log as one string, for Copy logs.
    var text: String {
        lines.map { "\($0.stamp)  \($0.text)" }.joined(separator: "\n")
    }

    // MARK: Private

    private func prepare(_ raw: String, loggedAt date: Date) {
        // Before anything keeps it: the console, Copy logs, and the stdout mirror.
        let entry = Entry(stamp: Self.stampFormat.string(from: date), text: LogRedactor.redact(raw))
        if Self.mirrorsToStdout {
            fputs("\(entry.stamp)  \(entry.text)\n", stdout)
            fflush(stdout)
        }
        lock.lock()
        let flushNeeded = pending.isEmpty
        pending.append(entry)
        lock.unlock()
        // One trip to the main thread takes every line that's ready by then.
        if flushNeeded {
            DispatchQueue.main.async { self.flush() }
        }
    }

    private func flush() {
        lock.lock()
        let batch = pending
        pending.removeAll()
        lock.unlock()
        guard !batch.isEmpty else { return }
        lines.append(contentsOf: batch)
        if lines.count > Self.maxLines {
            lines.removeFirst(lines.count - Self.maxLines)
        }
    }
}
