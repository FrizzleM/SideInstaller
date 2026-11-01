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
            Detail(label: "Device IP", value: engine.deviceHost),
            pairingFile(engine),
            developerMode,
            liveContainer,
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

    /// Whether Developer Mode is on, as iOS tells apps (`Engine.developerModeIsOn`).
    private static var developerMode: Detail {
        switch Engine.developerModeIsOn {
        case true?:  return Detail(label: "Developer Mode", value: "on", shown: L("on"))
        case false?: return Detail(label: "Developer Mode", value: "off", shown: L("off"))
        case nil:    return Detail(label: "Developer Mode", value: "unknown", shown: L("unknown"))
        }
    }

    /// Whether SideInstaller runs as a LiveContainer guest. iOS then reads
    /// LiveContainer's Info.plist instead of SideInstaller's, which turns off
    /// whatever needs a key only SideInstaller's has (#38, #69, #100).
    private static var liveContainer: Detail {
        let inside = Engine.runsInLiveContainer
        return Detail(label: "Runs inside LiveContainer", value: inside ? "yes" : "no",
                      shown: inside ? L("yes") : L("no"))
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
    /// On My iPhone (`reportsFolder`), so the issue form's file picker reaches
    /// it. Only the newest few reports are kept.
    func save(_ text: String) throws -> URL {
        let fm = FileManager.default
        let folder = Self.reportsURL
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

    private static var reportsURL: URL {
        IPALibrary.documentsDir.appendingPathComponent("Reports", isDirectory: true)
    }

    /// Where the Files app shows the reports, after `onMyIPhone` (“Files › On
    /// My iPhone”, in the language wanted). Inside LiveContainer the folder is
    /// in LiveContainer's own, under the guest's data folder.
    static func reportsFolder(onMyIPhone: String) -> String {
        guard let home = getenv("LC_HOME_PATH").map({ String(cString: $0) }) else {
            return "\(onMyIPhone) › SideInstaller › Reports"
        }
        let documents = URL(fileURLWithPath: home).appendingPathComponent("Documents")
            .resolvingSymlinksInPath().path + "/"
        let reports = reportsURL.resolvingSymlinksInPath().path
        let name = Engine.liveContainerName ?? "LiveContainer"
        // A data folder in LiveContainer's app group, which Files doesn't show.
        guard reports.hasPrefix(documents) else { return "\(onMyIPhone) › \(name)" }
        let inside = reports.dropFirst(documents.count).split(separator: "/")
        return ([onMyIPhone, name] + inside.map(String.init)).joined(separator: " › ")
    }

    // MARK: The issue

    /// A GitHub issue ready to open: the link with the title and body filled
    /// in, and what the link had no room for, to paste at the end of the body.
    struct IssueDraft: Identifiable {
        let url: URL
        /// Markdown with the whole activity log, the crash logs, and the
        /// description when the link had to shorten it. Nil when the link
        /// carries everything.
        let pasteText: String?
        var id: URL { url }
    }

    /// The longest link opened, as GitHub's sign-in page gets it
    /// (`signInLength`). GitHub answers 414 from about 8 KB, and an in-app
    /// browser that isn't signed in is sent on to the sign-in page with the
    /// whole link in it, which fails with a 500 from about 6.6 KB (measured
    /// 2026-10-27).
    static let maxURLLength = 6000

    /// How long the sign-in link GitHub sends a signed-out browser to is for
    /// `url`: its path and query escaped into `return_to`, which lengthens
    /// each `%`, `&`, `=`, `/` and `?` by two, after about 60 characters of
    /// its own. Never shorter than `url`, so it's the one length to check.
    private static func signInLength(_ url: URL) -> Int {
        let pathAndQuery = url.absoluteString.dropFirst("https://github.com".count)
        let escaped = pathAndQuery.reduce(0) { $0 + ("%&=/?".contains($1) ? 2 : 0) }
        return 60 + pathAndQuery.count + escaped
    }

    /// The most the body may hold once the paste is in. GitHub stops at 65,536
    /// characters; the rest is left for what the user adds.
    private static let maxBodyLength = 62_000

    /// The issue for this report. GitHub can't take a file through a link, and
    /// the saved file was easily left behind (#100), so the log goes in the
    /// body: in the link when it fits, and otherwise copied, for the user to
    /// paste below what the link fills in (the description, the details, the
    /// error and the log's last lines).
    func issueDraft(description: String, deviceCrashes: [DeviceCrashLog],
                    ownCrashes: [CrashDiagnostics.Crash]) -> IssueDraft {
        let written = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let crashes = ownCrashes.map(Self.ownCrashSection) + deviceCrashes.map(Self.deviceCrashSection)
        if crashes.isEmpty {
            let url = issueLink(title: issueTitle(written),
                                body: issueBody(description: written, log: .whole))
            if Self.signInLength(url) <= Self.maxURLLength { return IssueDraft(url: url, pasteText: nil) }
        }
        // The log's tail shortens first, then the description, the error and
        // the title; the paste has whatever was cut whole. A Chinese character
        // takes 15 of the sign-in link's, so all of them may have to go.
        var tail = min(15, logLines.count)
        var kept = written.count
        var errorKept = Int.max
        var titleKept = 80
        while true {
            let shortened = kept < written.count
            let shown = !shortened ? written
                : kept > 0 ? String(written.prefix(kept)) + " … (all of it is pasted below)"
                : "(Too long for the link: it's pasted below.)"
            let body = issueBody(description: shown, log: .pasted(tail: tail, crashes: crashes.count),
                                 errorLimit: errorKept)
            let url = issueLink(title: issueTitle(written, limit: titleKept), body: body)
            if Self.signInLength(url) <= Self.maxURLLength || titleKept <= 30 {
                let errorCut = error.map { $0.count > errorKept } ?? false
                let paste = pasteText(description: shortened ? written : nil,
                                      error: errorCut ? error : nil, crashes: crashes,
                                      room: Self.maxBodyLength - Self.submittedLength(body))
                return IssueDraft(url: url, pasteText: paste)
            }
            if tail > 0 {
                tail = max(0, tail - 5)
            } else if kept > 0 {
                kept = kept > 100 ? kept / 2 : 0
            } else if errorKept > 0 {
                errorKept = errorKept > 150 ? 150 : 0
            } else {
                titleKept = 30
            }
        }
    }

    private func issueLink(title: String, body: String) -> URL {
        let query = [("title", title), ("body", body), ("labels", "bug")]
            .map { "\($0)=\(Self.queryEncoded($1))" }
            .joined(separator: "&")
        return URL(string: "https://github.com/\(Self.repository)/issues/new?\(query)")!
    }

    /// The first line of what the user wrote, after the step a run stopped at
    /// while its error is still up (an older failure may be another problem).
    /// A pasted log line says nothing as a title, so the error's first
    /// sentence stands in for it (#100).
    private func issueTitle(_ description: String, limit: Int = 80) -> String {
        var firstLine = description.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        // A log line starts with its time: `12:20:18.335`, with AM/PM on an
        // iPhone set to 12-hour time.
        if firstLine.firstMatch(of: #/^\s*\d{1,2}:\d{2}:\d{2}\.\d{3}/#) != nil, let error {
            firstLine = Self.firstSentence(error)
        }
        if firstLine.count > limit { firstLine = String(firstLine.prefix(limit - 1)) + "…" }
        guard error != nil, let failedStepName else { return firstLine }
        return "Stopped at “\(failedStepName)”: \(firstLine)"
    }

    private static func firstSentence(_ text: String) -> String {
        let ends = [". ", "。", "! ", "? ", "\n"].compactMap { text.range(of: $0)?.lowerBound }
        guard let end = ends.min() else { return text }
        return String(text[..<end])
    }

    /// How much of the log the body carries.
    private enum BodyLog {
        /// All of it.
        case whole
        /// Its last `tail` lines, with the whole log and `crashes` crash logs
        /// to paste below.
        case pasted(tail: Int, crashes: Int)
    }

    private func issueBody(description: String, log: BodyLog, errorLimit: Int = .max) -> String {
        var body = "### What happened\n\n\(description)\n\n### Details\n\n"
        body += details.map { "- **\($0.label):** \($0.value)\n" }.joined()
        if let error {
            let shown = errorLimit > 0 ? Self.capped(error.replacingOccurrences(of: "\n", with: " "), errorLimit)
                : "(too long for the link: it's pasted below)"
            body += "- **Error:** \(shown)\n"
        }
        body += "\n### Activity log\n\n"
        switch log {
        case .whole:
            body += Self.collapsed("\(logLines.count) lines, redacted",
                                   Self.fenced(logLines.joined(separator: "\n")))
        case let .pasted(tail, crashes):
            if tail > 0 {
                let lines = logLines.suffix(tail).map { Self.capped($0, 300) }
                body += Self.collapsed("Last \(lines.count) of \(logLines.count) lines",
                                       Self.fenced(lines.joined(separator: "\n"))) + "\n"
            }
            let copied = crashes == 0 ? "the full log (\(logLines.count) lines)"
                : "the full log (\(logLines.count) lines) and \(crashes) crash log\(crashes == 1 ? "" : "s")"
            body += "The report file, `\(fileName)`, has all of it too: "
            body += "\(Self.reportsFolder(onMyIPhone: "Files › On My iPhone")).\n\n"
            body += "📋 **SideInstaller copied \(copied). Paste below this line:**\n\n"
        }
        return body
    }

    /// What goes below the body, at most `room` long as GitHub counts it: the
    /// error if the link cut it, the description if the link shortened it
    /// (often the log again, pasted into it, as in #100), the log (its newest
    /// lines, when all of them won't fit), then each crash log there's still
    /// room for. Room goes to the error, then the log, then the rest.
    private func pasteText(description: String?, error: String?, crashes: [(title: String, text: String)],
                           room: Int) -> String {
        // An error the link had to cut goes first: it's short, and it's what
        // the issue is about.
        let errorPart = error.map { "### Error, in full\n\n\(Self.capped($0, submitted: 4000))\n" }
        // Room for the headings and the note on what's left out, too.
        var left = room - 300 - (errorPart.map(Self.submittedLength) ?? 0)
        var kept: [String] = []
        var size = 0
        for line in logLines.reversed() {
            let length = Self.submittedLength(line) + 2
            guard size + length <= left else { break }
            kept.append(line)
            size += length
        }
        kept.reverse()
        var log = "### Full activity log\n\n"
        if kept.count < logLines.count {
            log += "The first \(logLines.count - kept.count) lines are left out for length; the report file has them.\n\n"
        }
        log += Self.collapsed("\(kept.count) lines, redacted", Self.fenced(kept.joined(separator: "\n")))
        left -= Self.submittedLength(log)
        var parts = errorPart.map { [$0] } ?? []
        if let description, left > 500 {
            let whole = "### What happened, in full\n\n\(Self.capped(description, submitted: left - 200))\n"
            parts.append(whole)
            left -= Self.submittedLength(whole)
        }
        parts.append(log)
        var leftOut: [String] = []
        for crash in crashes {
            let length = Self.submittedLength(crash.text)
            if length <= left {
                parts.append(crash.text)
                left -= length
            } else {
                leftOut.append(crash.title)
            }
        }
        if !leftOut.isEmpty {
            parts.append("Left out for length, in the report file: \(leftOut.joined(separator: ", ")).\n")
        }
        return parts.joined(separator: "\n")
    }

    private static func ownCrashSection(_ crash: CrashDiagnostics.Crash) -> (title: String, text: String) {
        let title = "SideInstaller crash (\(shortDate(crash.date)))"
        let text = "### \(title)\n\nVersion: \(crash.appVersion) · What ended it: \(crash.summary)\n\n"
            + collapsed("MetricKit diagnostic", fenced(crash.json, language: "json"))
        return (title, text)
    }

    private static func deviceCrashSection(_ crash: DeviceCrashLog) -> (title: String, text: String) {
        let title = "\(crash.app) crash (\(crash.date.map(shortDate) ?? crash.name))"
        return (title, "### \(title)\n\n" + collapsed(crash.name, fenced(crash.text)))
    }

    /// `text` as a code block, fenced with more backticks than any run inside it.
    private static func fenced(_ text: String, language: String = "text") -> String {
        var longest = 0, run = 0
        for character in text {
            run = character == "`" ? run + 1 : 0
            longest = max(longest, run)
        }
        let fence = String(repeating: "`", count: max(3, longest + 1))
        return "\(fence)\(language)\n\(text)\n\(fence)\n"
    }

    /// `content` folded away under `summary`, as GitHub shows `<details>`.
    private static func collapsed(_ summary: String, _ content: String) -> String {
        let summary = summary.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return "<details><summary>\(summary)</summary>\n\n\(content)\n</details>\n"
    }

    private static func capped(_ text: String, _ limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(max(0, limit))) + " …"
    }

    /// `text` cut to at most `limit` as GitHub counts it (`submittedLength`).
    private static func capped(_ text: String, submitted limit: Int) -> String {
        var used = 0
        for index in text.indices {
            used += submittedLength(String(text[index]))
            if used > limit { return String(text[..<index]) + " …" }
        }
        return text
    }

    /// `text`'s length as GitHub counts it against its limit: Unicode scalars,
    /// with line breaks twice, since a browser sends them as CR LF.
    private static func submittedLength(_ text: String) -> Int {
        text.unicodeScalars.reduce(0) { $0 + ($1 == "\n" ? 2 : 1) }
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
