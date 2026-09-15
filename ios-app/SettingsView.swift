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

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                languageSection
                tunnelSection
                downloadsSection
                anisetteSection
                advancedSection
                logSection
            }
            .sheet(item: $editorTarget) { AccountEditor(target: $0) }
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

    /// LocalDevVPN controls: start on launch, or start now. Uses LocalDevVPN's
    /// `localdevvpn://enable` URL, which connects and then returns to this app.
    @ViewBuilder
    private var tunnelSection: some View {
        Section {
            Toggle(L("Start LocalDevVPN on launch"), isOn: $engine.autoStartVPN)
            Button {
                engine.startLocalDevVPN()
            } label: {
                Label(L("Start LocalDevVPN now"), systemImage: "bolt.horizontal.circle")
            }
            .disabled(!engine.localDevVPNInstalled)
        } header: {
            Text(L("Tunnel"))
        } footer: {
            // Explain why the button is disabled.
            if !engine.localDevVPNInstalled {
                Text(L("LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you."))
            }
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
                ForEach(engine.anisetteServers) { server in
                    Text(server.name).tag(Optional(server.address))
                }
                Divider()
                Text(L("Custom…")).tag(String?.none)
            }
            if anisetteIsCustom {
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
        }
    }

    /// The menu's selection: a server's address, or nil for "Custom…".
    private var anisetteSelection: Binding<String?> {
        Binding(
            get: { anisetteIsCustom ? nil : engine.anisetteURL },
            set: { newValue in
                if let address = newValue {
                    anisetteIsCustom = false
                    engine.anisetteURL = address
                } else {
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
        } header: {
            Text(L("Activity Log (%d)", engine.lines.count))
        }
    }
}
