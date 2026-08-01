import SwiftUI
import UIKit

/// Settings & diagnostics, presented as a sheet from the toolbar gear. Holds the
/// occasional-use configuration (anisette server, device IP) and the activity
/// log for troubleshooting — kept out of the main flow so it stays uncluttered.
struct SettingsView: View {
    @EnvironmentObject private var engine: Engine
    /// The language setting lives here, so this sheet both drives it and
    /// redraws itself the instant it changes.
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    /// Lists / deletes the IPAs the app has cached in Documents. Owned here (rather
    /// than injected) because it's pure, cheap file-system work keyed off
    /// `Engine.shared` — a fresh instance just re-scans the disk when the sheet opens.
    @StateObject private var downloadsManager = DownloadsManager()
    /// The IPA the user swiped to delete, pending confirmation.
    @State private var pendingDelete: DownloadedIPA?

    /// `true` once the user picks "Custom…", revealing the free-form URL field.
    @State private var anisetteIsCustom = false

    var body: some View {
        NavigationStack {
            Form {
                languageSection
                downloadsSection
                anisetteSection
                advancedSection
                logSection
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

    // MARK: Language

    /// App-wide language. "Auto" tracks the iPhone's own language; picking a
    /// language pins the app to it whatever the phone is set to. The change
    /// lands immediately — every screen observes `Localizer`.
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

    // MARK: Downloaded IPAs

    /// A compact download manager pinned to the top of Settings: every release
    /// IPA the install flow has cached, its size and age, and swipe-to-delete to
    /// reclaim space. Deleting is non-destructive — the next install re-fetches.
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
                    // Nothing was downloaded for a file the user brought in, so
                    // the timestamp is when it arrived rather than when it was
                    // fetched.
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

    /// Drives the menu: a server's address when one is selected, `nil` for
    /// "Custom…". Selecting a server also stores its address as the URL we use.
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
