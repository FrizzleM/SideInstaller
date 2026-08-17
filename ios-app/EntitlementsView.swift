import SwiftUI
import SideInstallerFFI

// MARK: - Catalogue

/// One developer-portal capability, as Apple's JSON:API names it.
///
/// The names are Apple's own feature names and stay in English, like every
/// other product name in this app — only the chrome around them is translated.
struct Entitlement: Identifiable, Hashable {
    /// Apple's capability id, e.g. `INCREASED_MEMORY_LIMIT`.
    let id: String
    let name: String
    /// Which section of the list it sits in.
    let group: Group
    /// Selected by default: the ones sideloaded apps actually want, and the
    /// only ones a free Apple ID is known to be granted.
    let recommended: Bool

    enum Group: String, CaseIterable, Identifiable {
        case memory, other
        var id: String { rawValue }

        var title: String {
            switch self {
            case .memory: return L("Memory and performance")
            case .other:  return L("Other free capabilities")
            }
        }
    }

    /// What a **free** Apple ID can actually be granted. A paid membership
    /// unlocks far more (Push Notifications, iCloud, Associated Domains, Apple
    /// Pay, SiriKit, Network Extensions and the rest), but offering those here
    /// would just be a list of things Apple refuses — the accounts sideloading
    /// runs on are free ones.
    ///
    /// Increased Memory Limit is the proven case: it is what GetMoreRam exists
    /// to turn on for free-signed apps. App Groups is the other certain one —
    /// AltStore and SideStore both rely on it while free-signed. The remainder
    /// are the capabilities Apple's free provisioning has historically allowed;
    /// each is still sent as its own request, so anything that turns out to need
    /// a paid account fails alone and says why.
    static let all: [Entitlement] = [
        // Why this tool exists: the memory family, selected by default.
        .init(id: "INCREASED_MEMORY_LIMIT", name: "Increased Memory Limit", group: .memory, recommended: true),
        .init(id: "EXTENDED_VIRTUAL_ADDRESSING", name: "Extended Virtual Addressing", group: .memory, recommended: true),
        .init(id: "INCREASED_DEBUGGING_MEMORY_LIMIT", name: "Increased Debugging Memory Limit", group: .memory, recommended: true),

        // The rest of what a free account can hold.
        .init(id: "APP_GROUPS", name: "App Groups", group: .other, recommended: false),
        .init(id: "GAME_CENTER", name: "Game Center", group: .other, recommended: false),
        .init(id: "IN_APP_PURCHASE", name: "In-App Purchase", group: .other, recommended: false),
        .init(id: "INTER_APP_AUDIO", name: "Inter-App Audio", group: .other, recommended: false),
        .init(id: "HEALTHKIT", name: "HealthKit", group: .other, recommended: false),
        .init(id: "HOMEKIT", name: "HomeKit", group: .other, recommended: false),
        .init(id: "PERSONAL_VPN", name: "Personal VPN", group: .other, recommended: false),
        .init(id: "WIRELESS_ACCESSORY_CONFIGURATION", name: "Wireless Accessory Configuration", group: .other, recommended: false),
        .init(id: "DATA_PROTECTION", name: "Data Protection", group: .other, recommended: false),
    ]

    static var recommendedIDs: Set<String> {
        Set(all.filter(\.recommended).map(\.id))
    }

    static func named(_ id: String) -> String {
        all.first { $0.id == id }?.name ?? id
    }

    static func inGroup(_ group: Group) -> [Entitlement] {
        all.filter { $0.group == group }
    }
}

// MARK: - Models

/// One App ID on the team, decoded from `si_appid_list`.
struct AppIdentifier: Identifiable, Decodable, Equatable {
    /// Apple's opaque id — what the capability call addresses.
    let appIdId: String
    /// The reverse-DNS bundle identifier.
    let identifier: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case appIdId = "app_id_id"
        case identifier, name
    }

    var id: String { appIdId }
    var displayName: String { name.isEmpty ? identifier : name }
}

/// What Apple said about one capability, decoded from `si_appid_enable`.
struct EntitlementOutcome: Identifiable, Decodable, Equatable {
    let capability: String
    let ok: Bool
    let error: String

    var id: String { capability }
    var name: String { Entitlement.named(capability) }
}

// MARK: - Manager

/// Lists the team's App IDs and turns developer-portal capabilities on for one.
/// Same shape as `CertManager`, and the same underlying session type — this is
/// a developer-portal call, so no device, pairing or tunnel is involved.
final class EntitlementsManager: ObservableObject {

    @Published private(set) var apps: [AppIdentifier] = []
    @Published private(set) var teamSummary: String?
    @Published private(set) var isWorking = false
    /// `id` of the App ID currently being written to, if any.
    @Published private(set) var applyingID: String?
    /// Last run's per-capability outcomes, keyed by App ID.
    @Published private(set) var outcomes: [String: [EntitlementOutcome]] = [:]
    @Published var lastError: String?
    @Published private(set) var hasLoaded = false

    private var session: OpaquePointer?            // CertSession*
    private let queue = DispatchQueue(label: "sideinstaller.entitlements")

    private var engine: Engine { Engine.shared }

    /// True once the page has loaded on its own. Keeps `autoLoad` to a single
    /// attempt, so a sign-in that failed — or a 2FA prompt the user dismissed —
    /// isn't put back in front of them every time the page opens.
    private var didAutoLoad = false

    deinit {
        if let session { si_cert_session_free(session) }
    }

    var isBusy: Bool { isWorking || applyingID != nil }

    // MARK: Actions

    /// Load the App IDs on the page's own when it opens. Quiet when there's no
    /// Apple ID saved: arriving on the page shouldn't paint an error nobody
    /// asked for, and the button below says it plainly enough.
    @MainActor
    func autoLoad() {
        guard !didAutoLoad, !hasLoaded, !isBusy else { return }
        guard !engine.normalizedAppleID.isEmpty, !engine.applePassword.isEmpty else { return }
        didAutoLoad = true
        loadApps()
    }

    /// Sign in if needed, then load the team's App IDs.
    @MainActor
    func loadApps() {
        guard !isBusy else { return }
        let id = engine.normalizedAppleID, pw = engine.applePassword
        guard !id.isEmpty, !pw.isEmpty else {
            lastError = L("No Apple ID saved. Add one in Settings › Account.")
            return
        }
        isWorking = true
        lastError = nil
        engine.log("=== Entitlements: loading App IDs ===")
        Task { @MainActor in
            do {
                if session == nil { try await signIn(id: id, pw: pw) }
                let list = try await onQueue { try self.performList() }
                apps = list.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                hasLoaded = true
                engine.log("Entitlements: \(list.count) App ID(s).")
            } catch {
                lastError = short(error)
                engine.log("⛔️ Entitlements: \(lastError ?? "failed")")
            }
            isWorking = false
        }
    }

    /// Ask Apple to enable `ids` on `app`. Each is a separate request, so the
    /// result is per-capability rather than one pass/fail.
    @MainActor
    func enable(_ ids: [String], on app: AppIdentifier) {
        guard session != nil, !isBusy, !ids.isEmpty else { return }
        applyingID = app.id
        lastError = nil
        outcomes[app.id] = nil
        engine.log("Entitlements: enabling \(ids.count) capability(ies) on \(app.identifier) …")
        Task { @MainActor in
            do {
                let results = try await onQueue { try self.performEnable(appIdId: app.appIdId, ids: ids) }
                outcomes[app.id] = results
                let granted = results.filter(\.ok).count
                engine.log("Entitlements: Apple accepted \(granted)/\(results.count) on \(app.identifier).")
            } catch {
                lastError = short(error)
                engine.log("⛔️ Entitlements: \(lastError ?? "failed")")
            }
            applyingID = nil
        }
    }

    /// Forget the session, to switch Apple ID. A no-op when nothing was signed
    /// in, so switching account doesn't log a phantom.
    @MainActor
    func signOut() {
        guard let session else { return }
        si_cert_session_free(session)
        self.session = nil
        teamSummary = nil
        apps = []
        outcomes = [:]
        hasLoaded = false
        didAutoLoad = false
        lastError = nil
        engine.log("Entitlements: signed out.")
    }

    // MARK: Sign-in

    @MainActor
    private func signIn(id: String, pw: String) async throws {
        let servers = anisetteCandidates()
        let dir = storageDir
        engine.twoFactorWasCancelled = false
        var lastError = "no anisette servers configured"

        for (idx, ani) in servers.enumerated() {
            do {
                let summary = try await onQueue {
                    try self.performSignIn(id: id, pw: pw, ani: ani, dir: dir)
                }
                engine.anisetteURL = ani
                teamSummary = summary
                engine.log("Entitlements: signed in (\(summary)).")
                return
            } catch let error as EngineError {
                lastError = error.errorDescription ?? "sign-in failed"
                if engine.twoFactorWasCancelled {
                    throw EngineError.message(L("Two-factor verification was cancelled."))
                }
                if Engine.isCredentialError(lastError) {
                    throw EngineError.message(Engine.credentialErrorMessage)
                }
                engine.log("Entitlements: anisette \(idx + 1)/\(servers.count) failed: \(lastError)")
            }
        }
        let tried = servers.count == 1
            ? L("the anisette server")
            : L("all %d anisette servers", servers.count)
        throw EngineError.message(L("Apple ID sign-in failed on %@. Last error: %@", tried, lastError))
    }

    private func performSignIn(id: String, pw: String, ani: String, dir: String) throws -> String {
        var newSession: OpaquePointer?
        var summary: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_cert_signin(id, pw, ani, "SideInstaller", dir,
                                entitlementsTwoFactorCallback, nil,
                                &newSession, &summary, &error)
        if rc == 0 {
            if let old = self.session { si_cert_session_free(old) }
            self.session = newSession
            let s = summary.map { String(cString: $0) } ?? ""
            summary.map { si_string_free($0) }
            return s
        } else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message(msg)
        }
    }

    // MARK: FFI

    private func performList() throws -> [AppIdentifier] {
        guard let session = self.session else { throw EngineError.message("Not signed in.") }
        var json: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_appid_list(session, &json, &error)
        if rc == 0 {
            let s = json.map { String(cString: $0) } ?? "[]"
            json.map { si_string_free($0) }
            do {
                return try JSONDecoder().decode([AppIdentifier].self, from: Data(s.utf8))
            } catch {
                throw EngineError.message("Couldn't read the App ID list: \(error)")
            }
        } else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message("Listing App IDs failed: \(msg)")
        }
    }

    private func performEnable(appIdId: String, ids: [String]) throws -> [EntitlementOutcome] {
        guard let session = self.session else { throw EngineError.message("Not signed in.") }
        var json: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let rc = si_appid_enable(session, appIdId, ids.joined(separator: ","), &json, &error)
        if rc == 0 {
            let s = json.map { String(cString: $0) } ?? "[]"
            json.map { si_string_free($0) }
            do {
                return try JSONDecoder().decode([EntitlementOutcome].self, from: Data(s.utf8))
            } catch {
                throw EngineError.message("Couldn't read Apple's reply: \(error)")
            }
        } else {
            let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
            error.map { si_string_free($0) }
            throw EngineError.message("Enabling entitlements failed: \(msg)")
        }
    }

    // MARK: Helpers

    private func anisetteCandidates() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for addr in [engine.anisetteURL] + engine.anisetteServers.map(\.address) {
            let a = addr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty, seen.insert(a).inserted { out.append(a) }
        }
        return out
    }

    private var storageDir: String { PrivateStore.isideload.path }

    private func short(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    private func onQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { cont.resume(returning: try work()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}

/// Bridges a 2FA request during entitlement sign-in to the engine's prompt.
private let entitlementsTwoFactorCallback: SITwoFactorCb = { _, outBuf, bufLen in
    guard let outBuf = outBuf else { return 0 }
    return Engine.shared.provideTwoFactorCode(outBuf, Int(bufLen))
}

// MARK: - View

/// The Entitlements page: sign in, list the Apple ID's App IDs, and ask Apple to
/// enable capabilities on one. Pushed from Tools, whose `NavigationStack` this
/// relies on.
struct EntitlementsView: View {
    @EnvironmentObject private var engine: Engine
    /// Declared so every label on this screen redraws when the language changes.
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var manager: EntitlementsManager

    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header.cascadeItem(0)
                loadButton.cascadeItem(1)
                if let error = manager.lastError {
                    errorCallout(error).transition(.cardAppear)
                }
                appList
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: manager.lastError)
            .animation(.smooth(duration: 0.35), value: manager.apps)
            .animation(.smooth(duration: 0.3), value: manager.isWorking)
            .animation(.smooth(duration: 0.35), value: manager.teamSummary)
        }
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { manager.autoLoad() }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "checklist", image: "EntitlementsLogo", title: L("Entitlements")) {
            if let team = manager.teamSummary {
                StatusPill(text: team, systemImage: "person.2.fill", color: .green)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
            }
        }
    }

    private var loadButton: some View {
        Button { manager.loadApps() } label: {
            HStack(spacing: 10) {
                if manager.isWorking {
                    ProgressView().tint(.white)
                    Text(manager.teamSummary == nil ? L("Signing in") : L("Refreshing"))
                } else {
                    Image(systemName: manager.hasLoaded ? "arrow.clockwise" : "list.bullet.rectangle")
                        .contentTransition(.symbolEffect(.replace))
                    Text(manager.hasLoaded ? L("Refresh") : L("Load apps"))
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(manager.isBusy || engine.isRunning)
    }

    // MARK: App list

    @ViewBuilder
    private var appList: some View {
        if manager.hasLoaded && manager.apps.isEmpty && !manager.isWorking {
            emptyApps.transition(.cardAppear)
        } else if !manager.apps.isEmpty {
            VStack(spacing: 14) {
                HStack {
                    Text(manager.apps.count == 1
                         ? L("%d App ID", manager.apps.count)
                         : L("%d App IDs", manager.apps.count))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .cascadeItem(2)
                ForEach(Array(manager.apps.enumerated()), id: \.element.id) { idx, app in
                    NavigationLink {
                        EntitlementPicker(app: app, manager: manager)
                    } label: {
                        appRow(app)
                    }
                    .buttonStyle(.plain)
                    .cascadeItem(3 + idx)
                }
            }
        }
    }

    private func appRow(_ app: AppIdentifier) -> some View {
        PanelCard {
            HStack(spacing: 12) {
                Image(systemName: "app.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(Theme.brand)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(app.identifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let results = manager.outcomes[app.id] {
                        Text(L("%d of %d enabled", results.filter(\.ok).count, results.count))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(results.contains(where: \.ok) ? .green : .orange)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyApps: some View {
        PanelCard {
            VStack(spacing: 8) {
                Image(systemName: "questionmark.app.dashed")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.brand)
                Text(L("No App IDs"))
                    .font(.headline)
                Text(L("This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func errorCallout(_ message: String) -> some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Something went wrong"))
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

}

// MARK: - Picker

/// Pick the capabilities to ask for on one App ID, then see what Apple said.
private struct EntitlementPicker: View {
    let app: AppIdentifier
    @ObservedObject var manager: EntitlementsManager

    @EnvironmentObject private var loc: Localizer
    @State private var selected: Set<String> = Entitlement.recommendedIDs

    private var isApplying: Bool { manager.applyingID == app.id }
    private var results: [EntitlementOutcome]? { manager.outcomes[app.id] }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                appCard.cascadeItem(0)
                if let results { resultsCard(results).cascadeItem(1) }
                ForEach(Array(Entitlement.Group.allCases.enumerated()), id: \.element.id) { idx, group in
                    groupCard(group).cascadeItem(2 + idx)
                }
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: manager.outcomes[app.id])
            .animation(.smooth(duration: 0.3), value: manager.applyingID)
        }
        .background(AppBackground())
        .safeAreaInset(edge: .bottom) { applyBar }
    }

    private var appCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(app.displayName)
                    .font(.title3.weight(.bold))
                Text(app.identifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button(L("Recommended")) { selected = Entitlement.recommendedIDs }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(Theme.accent)
                    Button(L("Select all")) { selected = Set(Entitlement.all.map(\.id)) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(Theme.accent)
                    Button(L("None")) { selected = [] }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private func groupCard(_ group: Entitlement.Group) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(group.title)
                        .font(.headline)
                    // Only the memory family is proven on a free account; the
                    // rest are Apple's historical free-provisioning set and
                    // haven't been confirmed one by one.
                    if group == .other {
                        Text(L("Beta"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent2)
                    }
                    Spacer(minLength: 0)
                }
                ForEach(Entitlement.inGroup(group)) { entitlement in
                    row(entitlement)
                    if entitlement.id != Entitlement.inGroup(group).last?.id {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
        }
    }

    private func row(_ entitlement: Entitlement) -> some View {
        Button {
            if selected.contains(entitlement.id) { selected.remove(entitlement.id) }
            else { selected.insert(entitlement.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected.contains(entitlement.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected.contains(entitlement.id) ? Theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entitlement.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(entitlement.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 6)
                if let outcome = results?.first(where: { $0.capability == entitlement.id }) {
                    Image(systemName: outcome.ok ? "checkmark.seal.fill" : "xmark.circle.fill")
                        .foregroundStyle(outcome.ok ? .green : .orange)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// What Apple accepted, and why it refused the rest.
    private func resultsCard(_ results: [EntitlementOutcome]) -> some View {
        let granted = results.filter(\.ok)
        let refused = results.filter { !$0.ok }
        return CalloutCard(tint: granted.isEmpty ? .orange : .green) {
            VStack(alignment: .leading, spacing: 10) {
                Label(L("%d of %d enabled", granted.count, results.count),
                      systemImage: granted.isEmpty ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                if !granted.isEmpty {
                    Text(L("Install the app again for these to take effect."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(refused) { outcome in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(outcome.name)
                            .font(.caption.weight(.semibold))
                        Text(outcome.error)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var applyBar: some View {
        Button { manager.enable(Array(selected), on: app) } label: {
            HStack(spacing: 10) {
                if isApplying {
                    ProgressView().tint(.white)
                    Text(L("Asking Apple"))
                } else {
                    Image(systemName: "checkmark.seal")
                    Text(L("Enable %d selected", selected.count))
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(selected.isEmpty || manager.isBusy)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }
}
