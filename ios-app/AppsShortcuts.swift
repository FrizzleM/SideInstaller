import AppIntents
import Foundation

// MARK: - Sideloaded apps and install actions
//
// The Sideloaded apps page (list, Refresh all) and the Install tab as
// Shortcuts actions. Refreshing runs in the background like the rest; an
// install brings SideInstaller forward, since it can stop to ask things only
// the app shows (the pairing code, the App IDs an imported IPA costs, the
// trust step).

// MARK: Sideloaded apps

/// An app on this iPhone installed with a provisioning profile, as the
/// Sideloaded apps page lists it.
struct SideloadedAppEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Sideloaded App"
    static let defaultQuery = SideloadedAppQuery()

    /// The bundle identifier.
    let id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Bundle ID")
    var bundleID: String

    @Property(title: "Version")
    var version: String?

    @Property(title: "Expiration Date")
    var expirationDate: Date?

    /// Calendar days until it expires: 0 is today, negative once it has.
    @Property(title: "Days Left")
    var daysLeft: Int?

    /// True when SideInstaller has the app's IPA to sign it again from.
    @Property(title: "Can Be Refreshed")
    var canBeRefreshed: Bool

    /// "Expires in 3 days — 26 Nov", as the page says it.
    private let expiry: String

    init(_ status: SideloadedAppStatus, canBeRefreshed: Bool) {
        // The plain stored properties first: setting a @Property goes through self.
        id = status.app.bundleID
        expiry = ExpiryUrgency.text(for: status.current)
        name = status.app.name
        bundleID = status.app.bundleID
        version = status.app.version
        expirationDate = status.current?.expirationDate
        daysLeft = status.current?.daysRemaining
        self.canBeRefreshed = canBeRefreshed
    }

    /// Stands in for an app chosen in a shortcut before the device was read
    /// in this run; the action reads it then.
    init(placeholder bundleID: String) {
        id = bundleID
        expiry = ""
        name = bundleID
        self.bundleID = bundleID
        version = nil
        expirationDate = nil
        daysLeft = nil
        canBeRefreshed = false
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)",
                              subtitle: expiry.isEmpty ? nil : "\(expiry)",
                              image: DisplayRepresentation.Image(systemName: "app.badge"))
    }
}

struct SideloadedAppQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [SideloadedAppEntity.ID]) async throws -> [SideloadedAppEntity] {
        let known = SideloadedAppsManager.shared.appEntities
        return identifiers.map { id in
            known.first { $0.id == id } ?? SideloadedAppEntity(placeholder: id)
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [SideloadedAppEntity] {
        let manager = SideloadedAppsManager.shared
        do {
            try await Shortcuts.run("List sideloaded apps") {
                try await manager.loadForShortcut()
            }
        } catch {
            // The last list read is better than none.
            guard manager.hasLoaded else { throw error }
        }
        return manager.appEntities
    }
}

extension SideloadedAppsManager {
    /// The page's list as Shortcuts entities.
    var appEntities: [SideloadedAppEntity] {
        let refreshableIDs = Set(refreshable.map(\.bundleID))
        return entries.map {
            SideloadedAppEntity($0, canBeRefreshed: refreshableIDs.contains($0.app.bundleID))
        }
    }
}

struct GetSideloadedAppsIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Get Sideloaded Apps"
    static let description = IntentDescription(
        "Lists the apps on this iPhone installed with a provisioning profile, each with the day it expires, soonest first, as the Sideloaded apps page does. Runs over LocalDevVPN.",
        categoryName: "Sideloaded Apps",
        searchKeywords: ["expire", "expiry", "profile", "apps", "days"])

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[SideloadedAppEntity]> {
        try await Shortcuts.run("Get Sideloaded Apps") {
            try await Shortcuts.ensureTunnel(for: self)
            try await SideloadedAppsManager.shared.loadForShortcut()
        }
        return .result(value: SideloadedAppsManager.shared.appEntities)
    }
}

struct RefreshAllAppsIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Refresh All Apps"
    static let description = IntentDescription(
        "Signs every sideloaded app SideInstaller has the IPA of again with your Apple ID and installs it over itself, so its seven days start over, as Refresh all does. The apps keep their data. Runs over LocalDevVPN.",
        categoryName: "Sideloaded Apps",
        searchKeywords: ["refresh", "resign", "renew", "expire", "seven days"])

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let outcome = try await Shortcuts.run("Refresh All Apps") {
            try await Shortcuts.ensureTunnel(for: self)
            return try await Shortcuts.answeringSignIn(for: self) {
                try await SideloadedAppsManager.shared.refreshForShortcut()
            }
        }
        let report = try Shortcuts.report(outcome)
        return .result(value: report, dialog: Shortcuts.dialog(report))
    }
}

struct RefreshAppIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Refresh App"
    static let description = IntentDescription(
        "Signs one sideloaded app again with your Apple ID and installs it over itself, so its seven days start over. SideInstaller needs the app's IPA for that. Runs over LocalDevVPN.",
        categoryName: "Sideloaded Apps",
        searchKeywords: ["refresh", "resign", "renew", "expire"])

    @Parameter(title: "App", requestValueDialog: "Which app?")
    var app: SideloadedAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Refresh \(\.$app)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let bundleID = app.id
        let outcome = try await Shortcuts.run("Refresh App") {
            try await Shortcuts.ensureTunnel(for: self)
            return try await Shortcuts.answeringSignIn(for: self) {
                try await SideloadedAppsManager.shared.refreshForShortcut([bundleID])
            }
        }
        let report = try Shortcuts.report(outcome)
        return .result(value: report, dialog: Shortcuts.dialog(report))
    }
}

extension Shortcuts {
    /// How a refresh went, in the page's words, with each failure's reason.
    /// Throws it when nothing was refreshed.
    static func report(_ outcome: SideloadedAppsManager.RefreshOutcome) throws -> String {
        let jobs = outcome.jobs
        let refreshed = outcome.refreshed
        let headline = jobs.count == 1
            ? (refreshed == 1 ? L("Refreshed. Its seven days start again now.")
                              : L("Nothing was refreshed."))
            : L("Refreshed %d of %d apps.", refreshed, jobs.count)
        let failures = jobs.compactMap { job -> String? in
            guard case .failed(let reason) = job.state else { return nil }
            return "\(job.name): \(reason)"
        }
        let report = ([headline] + failures).joined(separator: "\n")
        guard refreshed > 0 else { throw ShortcutError(report) }
        return report
    }
}

// MARK: Install

/// The builds Install offers, other than an imported IPA.
enum InstallableApp: String, AppEnum {
    case sideStore
    case liveContainer
    case madeira
    case altStore

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "App"
    static let caseDisplayRepresentations: [InstallableApp: DisplayRepresentation] = [
        .sideStore: "SideStore",
        .liveContainer: "LiveContainer + SideStore",
        .madeira: "Madeira",
        .altStore: "AltStore",
    ]

    var source: InstallSource {
        switch self {
        case .sideStore:     return .sideStore
        case .liveContainer: return .liveContainer
        case .madeira:       return .madeira
        case .altStore:      return .altStore
        }
    }
}

/// Stable or nightly (`ReleaseChannel`).
enum ReleaseTrack: String, AppEnum {
    case stable
    case nightly

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Release"
    static let caseDisplayRepresentations: [ReleaseTrack: DisplayRepresentation] = [
        .stable: "Stable",
        .nightly: "Nightly",
    ]

    var channel: ReleaseChannel {
        switch self {
        case .stable:  return .stable
        case .nightly: return .nightly
        }
    }
}

struct InstallAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Install App"
    static let description = IntentDescription(
        "Opens SideInstaller and installs SideStore, LiveContainer + SideStore, Madeira or AltStore with your Apple ID, as Install does, then finishes when the install does. A build with only one release installs that one.",
        categoryName: "Install",
        searchKeywords: ["sidestore", "livecontainer", "madeira", "altstore", "sideload", "reinstall"])
    static let openAppWhenRun = true

    @Parameter(title: "App", default: .sideStore)
    var app: InstallableApp

    @Parameter(title: "Release", default: .stable)
    var release: ReleaseTrack

    static var parameterSummary: some ParameterSummary {
        Summary("Install \(\.$app)") {
            \.$release
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let source = app.source
        let message = try await Shortcuts.run("Install \(source.displayName)") { () -> String in
            let engine = Engine.shared
            try Shortcuts.requireNoInstall()
            engine.installSource = source
            // Madeira offers Stable once its first stable release is out.
            await engine.checkStableRelease(for: source)
            engine.releaseChannel = release.channel
            return try await Shortcuts.install(named: source.displayName)
        }
        return .result(dialog: Shortcuts.dialog(message))
    }
}

struct InstallIPAIntent: AppIntent {
    static let title: LocalizedStringResource = "Install IPA"
    static let description = IntentDescription(
        "Opens SideInstaller and installs an .ipa file with your Apple ID, as Custom .ipa does under Install. It asks there before signing uses up App IDs.",
        categoryName: "Install",
        searchKeywords: ["ipa", "sideload", "custom", "app"])
    static let openAppWhenRun = true

    @Parameter(title: "IPA File")
    var file: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Install \(\.$file)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await Shortcuts.run("Install IPA") { () -> String in
            let engine = Engine.shared
            try Shortcuts.requireNoInstall()
            let copy = try Shortcuts.temporaryCopy(of: file, defaultName: "App.ipa")
            defer { Shortcuts.discard(copy) }
            engine.installSource = .custom
            engine.lastError = nil
            await engine.importCustomIPA(from: copy)
            if let error = engine.lastError { throw ShortcutError(error) }
            return try await Shortcuts.install(named: engine.customIPAName ?? copy.lastPathComponent)
        }
        return .result(dialog: Shortcuts.dialog(message))
    }
}

struct InstallIPAFromURLIntent: AppIntent {
    static let title: LocalizedStringResource = "Install IPA from URL"
    static let description = IntentDescription(
        "Opens SideInstaller, downloads an .ipa from a link and installs it with your Apple ID, as a sideinstaller://install link does. The link has to download the .ipa itself.",
        categoryName: "Install",
        searchKeywords: ["ipa", "link", "download", "sideload"])
    static let openAppWhenRun = true

    @Parameter(title: "URL")
    var url: URL

    static var parameterSummary: some ParameterSummary {
        Summary("Install the IPA at \(\.$url)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let link = url
        let message = try await Shortcuts.run("Install IPA from URL") { () -> String in
            let engine = Engine.shared
            try Shortcuts.requireNoInstall()
            engine.installSource = .custom
            engine.lastError = nil
            guard await engine.importCustomIPA(fromLink: link.absoluteString) else {
                throw ShortcutError(engine.lastError ?? L("The install didn't start. Open SideInstaller to see why."))
            }
            return try await Shortcuts.install(named: engine.customIPAName ?? link.lastPathComponent)
        }
        return .result(dialog: Shortcuts.dialog(message))
    }
}

extension Shortcuts {
    /// Stops an action that would clash with an install already running.
    static func requireNoInstall() throws {
        guard !Engine.shared.isRunning else {
            throw ShortcutError(L("An install is already running. Wait for it to finish, then try again."))
        }
    }

    /// Runs Install for the build already picked, and waits for it to finish.
    /// When it can't start, it says why, as the Install tab does.
    static func install(named name: String) async throws -> String {
        let engine = Engine.shared
        let guideBefore = engine.guide
        engine.runOneClick()
        // A full-tunnel VPN's probe holds the start back half a second at most.
        var waited = 0.0
        while !engine.isRunning, waited < 3 {
            try await Task.sleep(for: .milliseconds(100))
            waited += 0.1
        }
        guard engine.isRunning else {
            if let error = engine.lastError { throw ShortcutError(error) }
            if let guide = engine.guide, guide != guideBefore {
                throw ShortcutError(([guide.title] + guide.steps).joined(separator: "\n"))
            }
            throw ShortcutError(L("The install didn't start. Open SideInstaller to see why."))
        }
        // Stopping the shortcut leaves the install to finish in the app.
        while engine.isRunning {
            try await Task.sleep(for: .milliseconds(500))
        }
        guard engine.finished else {
            throw ShortcutError(engine.lastError ?? L("Install stopped"))
        }
        return L("%@ is installed.", name)
    }
}
