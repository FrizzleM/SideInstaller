import SwiftUI
import UIKit

/// The settings sheet: occasional configuration and the activity log, kept out
/// of the main flow.
struct SettingsView: View {
    @EnvironmentObject private var engine: Engine
    /// Observed for the language picker, and to redraw on language change.
    @EnvironmentObject private var loc: Localizer
    /// The saved Apple IDs the Account section manages.
    @EnvironmentObject private var accounts: AccountStore
    @Environment(\.dismiss) private var dismiss

    /// Owned here; a new instance just rescans the disk.
    @StateObject private var downloadsManager = DownloadsManager()
    /// The IPA the user swiped to delete, pending confirmation.
    @State private var pendingDelete: DownloadedIPA?
    /// The Apple ID the user swiped to remove, pending confirmation.
    @State private var pendingRemove: SavedAccount?
    /// Set while the add/edit sheet is up, and for which account.
    @State private var editorTarget: AccountEditorTarget?

    /// True once "Custom…" is picked, revealing the free-form URL field.
    @State private var anisetteIsCustom = false

    /// What the anisette Server menu shows as picked.
    private enum AnisetteChoice: Hashable {
        case auto
        case server(String)
        case custom
    }

    /// Set while a Developer Mode request runs.
    @State private var developerModeBusy = false
    /// How the last Developer Mode request went.
    @State private var developerModeNote: DeveloperModeNote?
    /// Set when “Start LocalDevVPN now” opened nothing: how a missing
    /// LocalDevVPN shows inside LiveContainer, where `canOpenURL` can't tell.
    @State private var localDevVPNDidntOpen = false
    /// Set while the restart warning is up, before Developer Mode is turned on.
    @State private var confirmEnableDeveloperMode = false
    /// Set while the Report a problem sheet is up.
    @State private var showReport = false

    private struct DeveloperModeNote {
        let text: String
        let failed: Bool
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                languageSection
                tunnelSection
                developerModeSection
                downloadsSection
                anisetteSection
                advancedSection
                logSection
            }
            .sheet(item: $editorTarget) { AccountEditor(target: $0) }
            .sheet(isPresented: $showReport) { ReportProblemView() }
            // Attached to the Form, apart from the download alert below, so the
            // two alerts don't conflict.
            .alert(L("Remove this Apple ID?"),
                   isPresented: Binding(get: { pendingRemove != nil },
                                        set: { if !$0 { pendingRemove = nil } })) {
                Button(L("Remove"), role: .destructive) {
                    if let account = pendingRemove { accounts.remove(account) }
                    pendingRemove = nil
                }
                Button(L("Cancel"), role: .cancel) { pendingRemove = nil }
            } message: {
                if let account = pendingRemove {
                    Text(L("“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.",
                           account.appleID))
                }
            }
            .navigationTitle(L("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
        .onAppear {
            anisetteIsCustom = !engine.anisetteServers.contains { $0.address == engine.anisetteURL }
            downloadsManager.refresh()
        }
        .alert(L("Delete this download?"),
               isPresented: Binding(get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } })) {
            Button(L("Delete"), role: .destructive) {
                if let item = pendingDelete { downloadsManager.delete(item) }
                pendingDelete = nil
            }
            Button(L("Cancel"), role: .cancel) { pendingDelete = nil }
        } message: {
            if let item = pendingDelete {
                Text(L("“%@” (%@) will be removed. You can download it again any time from the Install tab.",
                       item.fileName, item.sizeText))
            }
        }
    }

    // MARK: Account

    /// Saved Apple IDs: tap to make one active, swipe to edit or remove, or add
    /// a new one.
    private var accountSection: some View {
        Section {
            ForEach(accounts.accounts) { account in
                Button { accounts.activate(account) } label: { accountRow(account) }
                    // `.plain` keeps the row text from using the accent color.
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingRemove = account
                        } label: {
                            Label(L("Remove"), systemImage: "trash")
                        }
                        // Set explicitly: the row's `.plain` style removes the
                        // destructive red.
                        .tint(.red)
                        Button {
                            editorTarget = .existing(account)
                        } label: {
                            Label(L("Edit"), systemImage: "pencil")
                        }
                        .tint(Theme.accent)
                    }
            }
            if accounts.accounts.isEmpty {
                Text(L("No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button { editorTarget = .new } label: {
                Label(L("Add Apple ID"), systemImage: "plus.circle.fill")
            }
            if let warning = accounts.keychainWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text(L("Account"))
        }
    }

    /// One saved Apple ID, ticked when it is the one in use.
    private func accountRow(_ account: SavedAccount) -> some View {
        let isActive = accounts.isActive(account)
        return HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundStyle(isActive ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(.secondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(account.appleID)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if isActive {
                    Text(L("In use"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if isActive {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent2)
            }
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }

    // MARK: Language

    /// App-wide language, applied immediately since every screen observes it.
    private var languageSection: some View {
        Section {
            Picker(L("App language"), selection: $loc.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
        } header: {
            Text(L("Language"))
        }
    }

    // MARK: Tunnel

    /// LocalDevVPN controls: start it whenever something needs the tunnel, or
    /// start it now. Uses LocalDevVPN's `localdevvpn://enable` URL, which
    /// connects and then returns to this app.
    @ViewBuilder
    private var tunnelSection: some View {
        Section {
            Toggle(L("Start LocalDevVPN when needed"), isOn: $engine.autoStartVPN)
            Button {
                Task {
                    let opened = await engine.startLocalDevVPN()
                    localDevVPNDidntOpen = !opened
                }
            } label: {
                Label(L("Start LocalDevVPN now"), systemImage: "bolt.horizontal.circle")
            }
            .disabled(!engine.localDevVPNInstalled)
        } header: {
            Text(L("Tunnel"))
        } footer: {
            // Explain why the button is disabled, or why it did nothing.
            if !engine.localDevVPNInstalled || localDevVPNDidntOpen {
                Text(L("LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you."))
            }
        }
    }

    // MARK: Developer Mode

    /// Asks this iPhone to show Developer Mode in Settings, or to turn it on.
    /// Both need a link that already works, so they can't help where the link
    /// itself needs Developer Mode (iOS 27).
    private var developerModeSection: some View {
        Section {
            Button {
                runDeveloperMode(.reveal)
            } label: {
                Label(L("Show Developer Mode in Settings"), systemImage: "eye")
            }
            .disabled(developerModeBusy || engine.isRunning)
            Button {
                confirmEnableDeveloperMode = true
            } label: {
                Label(L("Turn on Developer Mode"), systemImage: "hammer")
            }
            .disabled(developerModeBusy || engine.isRunning)
            if developerModeBusy {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L("Asking this iPhone…"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let note = developerModeNote {
                Label(note.text, systemImage: note.failed ? "exclamationmark.triangle.fill"
                                                          : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(note.failed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            }
        } header: {
            Text(L("Developer Mode"))
        }
        // On the section, apart from the Form's alerts, so they don't conflict.
        .alert(L("Turn on Developer Mode?"), isPresented: $confirmEnableDeveloperMode) {
            Button(L("Turn On and Restart"), role: .destructive) { runDeveloperMode(.enable) }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("This iPhone restarts right away. Once you unlock it, tap Turn On in the alert that appears. iOS allows this only while the iPhone has no passcode."))
        }
    }

    private func runDeveloperMode(_ request: DeviceConnection.DeveloperModeRequest) {
        guard !developerModeBusy else { return }
        developerModeBusy = true
        developerModeNote = nil
        Task {
            do {
                let text: String
                switch try await engine.requestDeveloperMode(request) {
                case .alreadyOn:
                    text = L("Developer Mode is already on.")
                case .revealed:
                    text = L("Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.")
                case .enabling:
                    text = L("Developer Mode is set to turn on, and this iPhone restarts now. Once you unlock it, tap Turn On.")
                }
                developerModeNote = DeveloperModeNote(text: text, failed: false)
            } catch {
                developerModeNote = DeveloperModeNote(
                    text: (error as? LocalizedError)?.errorDescription ?? String(describing: error),
                    failed: true)
            }
            developerModeBusy = false
        }
    }

    // MARK: Downloaded IPAs

    /// The cached IPAs with their size and age, and swipe-to-delete.
    private var downloadsSection: some View {
        Section {
            if let error = downloadsManager.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if downloadsManager.hasLoaded && downloadsManager.downloads.isEmpty {
                Text(L("No downloaded IPAs. Ones you install from the Install tab are cached here."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(downloadsManager.downloads) { item in
                    downloadRow(item)
                }
                .onDelete { offsets in
                    if let idx = offsets.first {
                        pendingDelete = downloadsManager.downloads[idx]
                    }
                }
            }
        } header: {
            HStack {
                Text(L("Downloaded IPAs"))
                Spacer()
                if !downloadsManager.downloads.isEmpty {
                    Text(L("%@ used", downloadsManager.totalSizeText))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func downloadRow(_ item: DownloadedIPA) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(Theme.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.subheadline.weight(.medium))
                if let modified = item.modified {
                    let when = modified.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened)
                            .locale(Localizer.locale))
                    // An imported file's timestamp is when it arrived.
                    Text(item.isImported ? L("Added %@", when) : L("Downloaded %@", when))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(item.sizeText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.accent2)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.accent.opacity(0.16)))
        }
    }

    // MARK: Anisette server

    private var anisetteSection: some View {
        Section {
            Picker(L("Server"), selection: anisetteSelection) {
                Text(L("Auto")).tag(AnisetteChoice.auto)
                Divider()
                ForEach(engine.anisetteServers) { server in
                    Text(server.name).tag(AnisetteChoice.server(server.address))
                }
                Divider()
                Text(L("Custom…")).tag(AnisetteChoice.custom)
            }
            if engine.anisetteAuto {
                Text(L("Starts with %@", anisetteName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else if anisetteIsCustom {
                TextField(L("Server URL"), text: $engine.anisetteURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } else {
                Text(engine.anisetteURL)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } header: {
            Text(L("Anisette Server"))
        } footer: {
            Text(engine.anisetteAuto
                 ? L("Auto starts with the server that signed in last, then tries the others, the ones most likely to work first.")
                 : L("Only this server is tried. If it fails, so does sign-in: choose Auto to have SideInstaller try the others."))
        }
    }

    /// The server Auto starts with, by its name on the list if it has one.
    private var anisetteName: String {
        engine.anisetteServers.first { $0.address == engine.anisetteURL }?.name ?? engine.anisetteURL
    }

    /// The menu's selection. Picking a server or "Custom…" turns Auto off;
    /// picking Auto keeps the server in use, as the one it starts with.
    private var anisetteSelection: Binding<AnisetteChoice> {
        Binding(
            get: {
                if engine.anisetteAuto { return .auto }
                return anisetteIsCustom ? .custom : .server(engine.anisetteURL)
            },
            set: { choice in
                switch choice {
                case .auto:
                    engine.anisetteAuto = true
                case .server(let address):
                    engine.anisetteAuto = false
                    anisetteIsCustom = false
                    engine.anisetteURL = address
                case .custom:
                    engine.anisetteAuto = false
                    anisetteIsCustom = true
                }
            }
        )
    }

    // MARK: Advanced

    private var advancedSection: some View {
        Section {
            HStack {
                Text(L("Device IP"))
                Spacer()
                TextField("10.7.0.1", text: $engine.deviceIP)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L("Advanced"))
        }
    }

    // MARK: Activity log

    private var logSection: some View {
        Section {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(engine.lines) { line in
                            Text("\(line.stamp)  \(line.text)")
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 240)
                .onChange(of: engine.lines.count) { _, _ in
                    if let last = engine.lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            HStack {
                Button {
                    UIPasteboard.general.string = engine.logText()
                } label: {
                    Label(L("Copy"), systemImage: "doc.on.doc")
                }
                Spacer()
                Button(role: .destructive) {
                    engine.clearLog()
                } label: {
                    Label(L("Clear"), systemImage: "trash")
                }
            }
            .font(.subheadline)
            Button { showReport = true } label: {
                Label(L("Report a problem"), systemImage: "exclamationmark.bubble")
            }
            .font(.subheadline)
        } header: {
            Text(L("Activity Log (%d)", engine.lines.count))
        }
    }
}
