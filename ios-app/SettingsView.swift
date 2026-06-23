import SwiftUI
import UIKit

/// Settings & diagnostics, presented as a sheet from the toolbar gear. Holds the
/// occasional-use configuration (anisette server, device IP) and the activity
/// log for troubleshooting — kept out of the main flow so it stays uncluttered.
struct SettingsView: View {
    @EnvironmentObject private var engine: Engine
    @Environment(\.dismiss) private var dismiss

    /// `true` once the user picks "Custom…", revealing the free-form URL field.
    @State private var anisetteIsCustom = false

    var body: some View {
        NavigationStack {
            Form {
                anisetteSection
                advancedSection
                logSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            anisetteIsCustom = !engine.anisetteServers.contains { $0.address == engine.anisetteURL }
        }
    }

    // MARK: Anisette server

    private var anisetteSection: some View {
        Section {
            Picker("Server", selection: anisetteSelection) {
                ForEach(engine.anisetteServers) { server in
                    Text(server.name).tag(Optional(server.address))
                }
                Divider()
                Text("Custom…").tag(String?.none)
            }
            if anisetteIsCustom {
                TextField("Server URL", text: $engine.anisetteURL)
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
            Text("Anisette Server")
        } footer: {
            Text("Used to sign in to Apple. The app retries the others automatically if one is down.")
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
                Text("Device IP")
                Spacer()
                TextField("10.7.0.1", text: $engine.deviceIP)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Advanced")
        } footer: {
            Text("The LocalDevVPN tunnel target. Leave the default unless you've changed it.")
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
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Spacer()
                Button(role: .destructive) {
                    engine.clearLog()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
            .font(.subheadline)
        } header: {
            Text("Activity Log (\(engine.lines.count))")
        }
    }
}
