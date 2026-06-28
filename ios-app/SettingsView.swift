import SwiftUI
import UIKit

/// Settings & diagnostics, presented as a sheet from the toolbar gear. Holds the
/// occasional-use configuration (anisette server, device IP) and the activity
/// log for troubleshooting — kept out of the main flow so it stays uncluttered.
struct SettingsView: View {
    @EnvironmentObject private var engine: Engine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// `true` once the user picks "Custom…", revealing the free-form URL field.
    @State private var anisetteIsCustom = false

    var body: some View {
        NavigationStack {
            Form {
                linksSection
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

    // MARK: Links

    /// Project links — source, support, and community — kept at the very top so
    /// they're the first thing the user sees in Settings.
    private var linksSection: some View {
        Section {
            HStack(spacing: 10) {
                linkButton("GitHub",
                           systemImage: "chevron.left.forwardslash.chevron.right",
                           tint: .primary,
                           url: "https://github.com/FrizzleM/SideInstaller")
                linkButton("Ko-fi",
                           systemImage: "cup.and.saucer.fill",
                           tint: Color(red: 1.0, green: 0.37, blue: 0.36),
                           url: "https://ko-fi.com/frizzlem")
                linkButton("Discord",
                           systemImage: "bubble.left.and.bubble.right.fill",
                           tint: Color(red: 0.35, green: 0.40, blue: 0.95),
                           url: "https://discord.gg/sQ5Y8vbYJS")
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    /// One pill in the links row: a tinted tile with a glyph over its label that
    /// opens `url` in the browser.
    private func linkButton(_ title: String, systemImage: String,
                            tint: Color, url: String) -> some View {
        Button {
            if let url = URL(string: url) { openURL(url) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
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
