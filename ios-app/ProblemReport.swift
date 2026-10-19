import Foundation
import UIKit
import MetricKit
import CryptoKit

// MARK: - The report

/// A problem report for GitHub: what the user wrote, where SideInstaller
/// stands (version, iOS, device, the step that failed), the redacted log and
/// the crash logs picked. It's saved as a file the issue gets attached, and a
/// prefilled issue names that file.
///
/// Labels and values are in English, for the issue; the sheet translates the
/// labels.
struct ProblemReport {

    struct Detail: Identifiable {
        /// English, and the key the sheet translates it with.
        let label: String
        /// English, for the issue.
        let value: String
        /// The value as the sheet shows it, where it's words to translate.
        var shown: String? = nil
        var id: String { label }
    }

    /// Version, iOS, device and the run's settings.
    let details: [Detail]
    /// The English name of the step the last run stopped at, if it failed.
    let failedStepName: String?
    /// The error the Install tab shows, redacted like the log.
    let error: String?
    /// The activity log, already redacted line by line (`Engine.appendLine`).
    let logLines: [String]
    let created = Date()

    static let repository = "FrizzleM/SideInstaller"

    /// Where SideInstaller stands now.
    @MainActor
    static func current(_ engine: Engine) -> ProblemReport {
        let source = engine.installSource
        let failed = Step.allCases.first { engine.stepStates[$0] == .failed }
        var details = [
            Detail(label: "SideInstaller", value: appVersion),
            Detail(label: "iOS", value: osVersion),
            Detail(label: "Device", value: deviceModel),
            installing(engine),
        ]
        if let failed {
            details.append(Detail(label: "Stopped at", value: englishTitle(failed, source),
                                  shown: failed.title(for: source)))
        }
        details += [
            connection("LocalDevVPN", engine.vpnConnected),
            connection("Wi-Fi", engine.wifiConnected),
            pairingFile(engine),
            anisette(engine),
            Detail(label: "Language", value: Localizer.shared.language.resolved.rawValue,
                   shown: Localizer.shared.language.resolved.displayName),
        ]
        return ProblemReport(details: details,
                             failedStepName: failed.map { englishTitle($0, source) },
                             error: engine.lastError.map(LogRedactor.redact),
                             logLines: engine.lines.map { "\($0.stamp)  \($0.text)" })
    }

    // MARK: Details

    static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// "27.0 (24A5260b)": the version and build.
    static var osVersion: String {
        let version = UIDevice.current.systemVersion
        return sysctlString("kern.osversion").map { "\(version) (\($0))" } ?? version
    }

    /// The hardware model, e.g. "iPhone17,3"; the simulated one in the simulator.
    static var deviceModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "\(simulated) (simulator)"
        }
        return sysctlString("hw.machine") ?? UIDevice.current.model
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let text = String(cString: buffer)
        return text.isEmpty ? nil : text
    }

    /// The build, its channel and the version picked: "SideStore, nightly, latest".
    @MainActor
    private static func installing(_ engine: Engine) -> Detail {
        let source = engine.installSource
        guard source != .custom else {
            return Detail(label: "App", value: "imported IPA", shown: source.displayName)
        }
        let channel = source.hasNightly ? engine.selectedChannel : nil
        let version = engine.selectedVersion?.tag
        let value = [source.displayName, channel?.rawValue, version ?? "latest"].compactMap { $0 }
        let shown = [source.displayName, channel?.displayName, version ?? L("latest")].compactMap { $0 }
        return Detail(label: "App", value: value.joined(separator: ", "),
                      shown: shown.joined(separator: ", "))
    }

    private static func connection(_ label: String, _ connected: Bool) -> Detail {
        Detail(label: label, value: connected ? "connected" : "not connected",
               shown: connected ? L("connected") : L("not connected"))
    }

    /// Whether there's a pairing file and where it came from. The imported
    /// file's name is left out, since people name them after themselves.
    @MainActor
    private static func pairingFile(_ engine: Engine) -> Detail {
        let (value, shown) = !engine.hasPairingFile ? ("none", L("none"))
            : engine.importedPairingName == nil ? ("made on this iPhone", L("made on this iPhone"))
            : ("imported", L("imported"))
        return Detail(label: "Pairing file", value: value, shown: shown)
    }

    /// The anisette server picked. A custom address is left out: it can be
    /// someone's own server.
    @MainActor
    private static func anisette(_ engine: Engine) -> Detail {
        let server = engine.anisetteServers.first { $0.address == engine.anisetteURL }?.name
        let name = server ?? "custom server", shownName = server ?? L("custom server")
        return Detail(label: "Anisette",
                      value: engine.anisetteAuto ? "Auto, starts with \(name)" : name,
                      shown: engine.anisetteAuto ? L("Auto, starts with %@", shownName) : shownName)
    }

    /// `Step.title(for:)` in English, whatever language the app shows.
    private static func englishTitle(_ step: Step, _ source: InstallSource) -> String {
        switch step {
        case .network:      return "Connect the VPN"
        case .pair:         return "Get pairing file"
        case .connect:      return "Open the device link"
        case .signIn:       return "Sign in to Apple ID"
        case .download:     return source == .custom ? "Use your imported IPA" : "Download \(source.shortName)"
        case .sign:         return "Sign the app"
        case .install:      return source == .custom ? "Install the imported IPA" : "Install \(source.shortName)"
        case .writePairing: return "Finish setup"
        }
    }

    // MARK: The file

    /// The report's filename, e.g. `SideInstaller-report-2026-10-17-153012.txt`.
    var fileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "SideInstaller-report-\(formatter.string(from: created)).txt"
    }

    /// Everything, as the attached file has it.
    func fileText(description: String, deviceCrashes: [DeviceCrashLog],
                  ownCrashes: [CrashDiagnostics.Crash]) -> String {
        var text = """
        SideInstaller problem report
        Created \(created.formatted(.iso8601))

        ## What happened

        \(description.trimmingCharacters(in: .whitespacesAndNewlines))

        ## Details

        """
        text += "\n" + details.map { "\($0.label): \($0.value)\n" }.joined()
        if let error { text += "Error: \(error)\n" }
        text += "\n## Activity log (\(logLines.count) lines, redacted)\n\n"
        text += logLines.joined(separator: "\n") + "\n"
        for crash in ownCrashes {
            text += "\n## SideInstaller crash, reported by iOS \(crash.date.formatted(.iso8601)) (MetricKit)\n\n"
            text += "Version: \(crash.appVersion)\nWhat ended it: \(crash.summary)\n\n\(crash.json)\n"
        }
        for crash in deviceCrashes {
            text += "\n## \(crash.app) crash log from this iPhone: \(crash.name)\n\n\(crash.text)\n"
        }
        return text
    }

    /// Saves the file to Documents/Reports, which the Files app shows under
    /// On My iPhone › SideInstaller, so the issue form's file picker reaches it.
    /// Only the newest few reports are kept.
    func save(_ text: String) throws -> URL {
        let fm = FileManager.default
        let folder = IPALibrary.documentsDir.appendingPathComponent("Reports", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        let older = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for stale in older.filter({ $0.lastPathComponent.hasPrefix("SideInstaller-report-") })
            .sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
            .dropFirst(Self.reportsKept) {
            try? fm.removeItem(at: stale)
        }
        return url
    }

    private static let reportsKept = 5

    // MARK: The issue

    /// A new GitHub issue with the title and body filled in. Files can't be
    /// attached through a link, so the body names the saved file and says
    /// where to find it, and carries the end of the log in case it isn't.
    func issueURL(description: String, deviceCrashes: [DeviceCrashLog],
                  ownCrashes: [CrashDiagnostics.Crash]) -> URL {
        let written = description.trimmingCharacters(in: .whitespacesAndNewlines)
        // GitHub refuses links much over 8 KB, so the log's tail shortens
        // first, then the description; the file has both whole.
        var tail = min(40, logLines.count)
        var kept = written.count
        while true {
            let description = kept < written.count
                ? String(written.prefix(kept)) + " … (the rest is in the attached report)" : written
            let body = issueBody(description: description, deviceCrashes: deviceCrashes,
                                 ownCrashes: ownCrashes, logTail: logLines.suffix(tail))
            let query = [("title", issueTitle(description)), ("body", body), ("labels", "bug")]
                .map { "\($0)=\(Self.queryEncoded($1))" }
                .joined(separator: "&")
            let url = URL(string: "https://github.com/\(Self.repository)/issues/new?\(query)")!
            if url.absoluteString.count <= 7500 { return url }
            if tail > 0 {
                tail = max(0, tail - 10)
            } else if kept > 200 {
                kept /= 2
            } else {
                return url
            }
        }
    }

    /// The first line of what the user wrote, after the step a run stopped at
    /// while its error is still up (an older failure may be another problem).
    private func issueTitle(_ description: String) -> String {
        var firstLine = description.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        if firstLine.count > 80 { firstLine = String(firstLine.prefix(79)) + "…" }
        guard error != nil, let failedStepName else { return firstLine }
        return "Stopped at “\(failedStepName)”: \(firstLine)"
    }

    private func issueBody(description: String, deviceCrashes: [DeviceCrashLog],
                           ownCrashes: [CrashDiagnostics.Crash], logTail: ArraySlice<String>) -> String {
        var body = "### What happened\n\n\(description)\n\n### Details\n\n"
        body += details.map { "- **\($0.label):** \($0.value)\n" }.joined()
        if let error {
            body += "- **Error:** \(error.replacingOccurrences(of: "\n", with: " "))\n"
        }
        var crashes = ownCrashes.map { "SideInstaller (\(Self.shortDate($0.date)))" }
        crashes += deviceCrashes.map { "\($0.app) (\($0.date.map(Self.shortDate) ?? $0.name))" }
        body += "\n### Report file\n\n"
        body += "📎 **Attach `\(fileName)` to this issue.** It's in Files › On My iPhone › SideInstaller › Reports. "
        body += "It has the redacted activity log (\(logLines.count) lines)"
        body += crashes.isEmpty ? ".\n" : " and \(crashes.count) crash log\(crashes.count == 1 ? "" : "s"): \(crashes.joined(separator: ", ")).\n"
        if !logTail.isEmpty {
            body += "\n<details><summary>Last \(logTail.count) log lines</summary>\n\n```\n"
            body += logTail.joined(separator: "\n")
            body += "\n```\n\n</details>\n"
        }
        return body
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Locale(identifier: "en_US")))
    }

    /// Percent-encodes everything but unreserved ASCII: `+` would otherwise
    /// arrive as a space, and `&` would end the value.
    private static func queryEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

// MARK: - Crash logs from this iPhone

/// A crash report iOS kept for one of the apps SideInstaller installs, read over
/// the device link (`Engine.deviceCrashLogs`).
struct DeviceCrashLog: Identifiable, Hashable {
    /// The report's filename, e.g. `SideStore-2026-10-17-101010.ips`.
    let name: String
    /// The app it belongs to: SideStore, LiveContainer or Madeira.
    let app: String
    /// When it crashed, from the filename, in the iPhone's time zone.
    let date: Date?
    /// The report, redacted (see `redact`).
    let text: String

    var id: String { name }

    /// How far back reports are read, in days.
    static let maxAgeDays = 30
    /// The newest this many are read for each app.
    private static let perApp = 3

    /// The processes whose reports are read, and the app each belongs to.
    /// LiveProcess is LiveContainer's multitasking extension, and
    /// MadeiraJITHelper is Madeira's JIT extension.
    private static let processes: [String: String] = [
        "SideStore": "SideStore",
        "LiveContainer": "LiveContainer", "LiveProcess": "LiveContainer",
        "Madeira": "Madeira", "MadeiraJITHelper": "Madeira",
    ]

    /// From every path the crash folders list, each app's newest reports from
    /// the last `maxAgeDays` days.
    static func select(_ paths: [String]) -> [String] {
        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 86_400)
        var seen = Set<String>()
        let reports = paths.compactMap { path -> (path: String, app: String, date: Date)? in
            let name = fileName(path)
            guard seen.insert(name).inserted, let parsed = parse(name),
                  let app = processes[parsed.process], parsed.date >= cutoff else { return nil }
            return (path, app, parsed.date)
        }
        return Dictionary(grouping: reports, by: \.app).values
            .flatMap { $0.sorted { $0.date > $1.date }.prefix(perApp) }
            .sorted { $0.date > $1.date }
            .map(\.path)
    }

    init(path: String, data: Data) {
        name = Self.fileName(path)
        let parsed = Self.parse(name)
        app = parsed.flatMap { Self.processes[$0.process] } ?? name
        date = parsed?.date
        text = Self.redact(String(decoding: data, as: UTF8.self))
    }

    private static func fileName(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// `SideStore-2026-10-17-101010.ips` → ("SideStore", its date).
    private static func parse(_ name: String) -> (process: String, date: Date)? {
        guard let match = name.firstMatch(of: #/^(.+)-(\d{4}-\d{2}-\d{2}-\d{6})\.ips/#),
              let date = fileDate.date(from: String(match.2)) else { return nil }
        return (String(match.1), date)
    }

    private static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    /// Takes out the device's stable crash reporter key, the vendor ID and any
    /// email address, keeping the report valid JSON so it still symbolicates.
    /// The rest (model, iOS build, binaries, threads) is what a crash needs.
    private static func redact(_ report: String) -> String {
        report
            .replacingOccurrences(of: #""(crashReporterKey|deviceIdentifierForVendor)"\s*:\s*"[^"]*""#,
                                  with: #""$1":"‹redacted›""#, options: .regularExpression)
            .replacing(#/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/#) { match in
                LogRedactor.maskAppleID(String(match.output))
            }
    }
}

// MARK: - SideInstaller's own crashes (MetricKit)

/// SideInstaller's own crashes, from MetricKit. iOS hands a crash's diagnostic
/// over the next time the app opens; each is kept in Application Support (the
/// newest few, for a month) until a report takes it along.
final class CrashDiagnostics: NSObject, ObservableObject, MXMetricManagerSubscriber {

    static let shared = CrashDiagnostics()

    struct Crash: Codable, Identifiable, Hashable {
        /// A hash of the diagnostic, so one delivered twice is kept once.
        let id: String
        /// When iOS delivered it: the end of the window the crash fell in.
        let date: Date
        let appVersion: String
        /// What ended the app, e.g. "EXC_BAD_ACCESS · SIGSEGV".
        let summary: String
        /// The diagnostic as MetricKit gives it: metadata and call stacks.
        let json: String
    }

    /// Newest first.
    @Published private(set) var crashes: [Crash] = []

    private static let kept = 10
    private static let maxAgeDays = 30

    /// Loads what's saved and starts listening. Called once, at launch.
    func start() {
        crashes = Self.load()
        MXMetricManager.shared.add(self)
        // What iOS delivered before anything was listening.
        receive(MXMetricManager.shared.pastDiagnosticPayloads)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        receive(payloads)
    }

    private func receive(_ payloads: [MXDiagnosticPayload]) {
        let new = payloads.flatMap { payload in
            (payload.crashDiagnostics ?? []).map { Self.crash($0, date: payload.timeStampEnd) }
        }
        guard !new.isEmpty else { return }
        DispatchQueue.main.async {
            let known = Set(self.crashes.map(\.id))
            let added = new.filter { !known.contains($0.id) }
            guard !added.isEmpty else { return }
            added.forEach(Self.save)
            self.crashes = Self.prune(self.crashes + added)
            Engine.shared.log("MetricKit: \(added.count) SideInstaller crash\(added.count == 1 ? "" : "es") saved for Report a problem: \(added.map(\.summary).joined(separator: "; ")).")
        }
    }

    private static func crash(_ diagnostic: MXCrashDiagnostic, date: Date) -> Crash {
        let data = diagnostic.jsonRepresentation()
        let id = SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
        return Crash(id: id, date: date, appVersion: diagnostic.applicationVersion,
                     summary: summary(diagnostic),
                     json: String(decoding: data, as: UTF8.self))
    }

    private static func summary(_ diagnostic: MXCrashDiagnostic) -> String {
        var parts: [String] = []
        if let type = diagnostic.exceptionType?.int32Value {
            parts.append(exceptionNames[type] ?? "exception \(type)")
        }
        if let signal = diagnostic.signal?.int32Value {
            parts.append(signalNames[signal] ?? "signal \(signal)")
        }
        if let reason = diagnostic.exceptionReason {
            parts.append("\(reason.exceptionName): \(reason.composedMessage)")
        }
        return parts.isEmpty ? "crash" : parts.joined(separator: " · ")
    }

    private static let exceptionNames: [Int32: String] = [
        EXC_BAD_ACCESS: "EXC_BAD_ACCESS", EXC_BAD_INSTRUCTION: "EXC_BAD_INSTRUCTION",
        EXC_ARITHMETIC: "EXC_ARITHMETIC", EXC_SOFTWARE: "EXC_SOFTWARE",
        EXC_BREAKPOINT: "EXC_BREAKPOINT", EXC_CRASH: "EXC_CRASH",
        EXC_RESOURCE: "EXC_RESOURCE", EXC_GUARD: "EXC_GUARD",
    ]

    private static let signalNames: [Int32: String] = [
        SIGILL: "SIGILL", SIGTRAP: "SIGTRAP", SIGABRT: "SIGABRT", SIGFPE: "SIGFPE",
        SIGKILL: "SIGKILL", SIGBUS: "SIGBUS", SIGSEGV: "SIGSEGV", SIGSYS: "SIGSYS",
    ]

    // MARK: Storage

    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("crash-diagnostics", isDirectory: true)
    }

    private static func load() -> [Crash] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let crashes = files.compactMap { url in
            (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Crash.self, from: $0) }
        }
        return prune(crashes)
    }

    private static func save(_ crash: Crash) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(crash) else { return }
        try? data.write(to: folder.appendingPathComponent("\(crash.id).json"), options: .atomic)
    }

    /// Newest first; drops the oldest beyond `kept` and any past `maxAgeDays`,
    /// from disk too.
    private static func prune(_ crashes: [Crash]) -> [Crash] {
        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 86_400)
        let sorted = crashes.sorted { $0.date > $1.date }
        let keep = Array(sorted.filter { $0.date >= cutoff }.prefix(kept))
        let kept = Set(keep.map(\.id))
        for crash in sorted where !kept.contains(crash.id) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent("\(crash.id).json"))
        }
        return keep
    }
}
