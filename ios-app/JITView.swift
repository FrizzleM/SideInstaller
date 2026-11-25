import SwiftUI

/// The JIT page: the apps a debugger can attach to, each opened with JIT on in
/// a tap, and the session while one runs. Pushed from Tools (relies on its
/// `NavigationStack`).
struct JITView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var manager: JITManager

    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header.cascadeItem(0)
                sessionCard
                loadButton.cascadeItem(1)
                // Errors show as a popup, which `RootView` lays over the app.
                appList
            }
            .padding(20)
            .pageColumn()
            .animation(.smooth(duration: 0.35), value: manager.apps)
            .animation(.smooth(duration: 0.3), value: manager.isLoading)
            .animation(.smooth(duration: 0.35), value: manager.status)
        }
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { manager.autoLoad() }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "bolt", image: "JITLogo", title: L("JIT")) {
            if let status = manager.status, status.phase == .attached {
                StatusDot(text: L("JIT on for %@", status.app.name), color: Theme.positive)
                    .transition(.opacity)
            } else if manager.hasLoaded {
                let count = manager.apps.count
                StatusDot(text: count == 1 ? L("%d app can use JIT", count) : L("%d apps can use JIT", count),
                          color: Theme.positive, idle: count == 0)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Session

    /// The session while it runs: what it's doing, and the way to end it
    /// while the debugger stays attached.
    @ViewBuilder
    private var sessionCard: some View {
        if let status = manager.status {
            PanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        SectionTitle(title: status.app.name, systemImage: "bolt.fill")
                        Spacer(minLength: 8)
                        if status.phase != .attached {
                            ProgressView().controlSize(.small)
                        }
                    }
                    Text(phaseText(status))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                    if status.preparedBytes > 0 {
                        Text(L("%@ of JIT memory prepared", Self.format(bytes: status.preparedBytes)))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.positive)
                            .contentTransition(.numericText())
                    }
                    if status.phase == .attached {
                        Button(role: .destructive) { manager.quit() } label: {
                            Text(L("Quit %@", status.app.name)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    }
                }
            }
            .transition(.cardAppear)
        }
    }

    private func phaseText(_ status: JITManager.Status) -> String {
        switch status.phase {
        case .connecting: L("Connecting to this iPhone's debugger")
        case .launching: L("Opening %@", status.app.name)
        case .attaching: L("Attaching the debugger")
        case .attached, .ended:
            L("JIT is on. SideInstaller stays attached while %@ runs: keep SideInstaller in the background, since closing it ends JIT.",
              status.app.name)
        }
    }

    // MARK: Primary action

    private var loadButton: some View {
        Button {
            manager.load()
        } label: {
            HStack(spacing: 8) {
                if manager.isLoading {
                    ProgressView()
                    // A missing pairing file is generated first.
                    Text(manager.isPairing ? L("Pairing…") : L("Reading the device"))
                } else {
                    Image(systemName: manager.hasLoaded ? "arrow.clockwise" : "list.bullet.rectangle")
                        .contentTransition(.symbolEffect(.replace))
                    Text(manager.hasLoaded ? L("Refresh") : L("Load apps"))
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(manager.isLoading)
    }

    // MARK: App list

    @ViewBuilder
    private var appList: some View {
        if manager.hasLoaded && manager.apps.isEmpty && !manager.isLoading {
            emptyState.transition(.cardAppear)
        } else if !manager.apps.isEmpty {
            VStack(spacing: 12) {
                // Enumerated so rows redraw on a language change.
                ForEach(Array(manager.apps.enumerated()), id: \.element.id) { index, app in
                    appRow(app).cascadeItem(2 + index)
                }
            }
        }
    }

    private func appRow(_ app: JITApp) -> some View {
        PanelCard {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.subheadline.weight(.medium))
                    Text(app.bundleID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    modeMenu(app)
                        .padding(.top, 2)
                }
                Spacer(minLength: 8)
                enableButton(app)
            }
        }
    }

    /// How JIT stays on for the app, and the menu to change it.
    private func modeMenu(_ app: JITApp) -> some View {
        let mode = manager.mode(for: app)
        let resolved = manager.jitProtocol(for: app)
        return Menu {
            Picker(selection: Binding(get: { manager.mode(for: app) },
                                      set: { manager.setMode($0, for: app) })) {
                ForEach(JITMode.allCases) { choice in
                    Text(title(of: choice)).tag(choice)
                }
            } label: {
                EmptyView()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: resolved.staysAttached ? "link" : "bolt")
                Text(mode == .automatic ? L("Auto: %@", resolved.title) : resolved.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.accent)
        }
        .disabled(manager.isBusy)
    }

    private func title(of mode: JITMode) -> String {
        switch mode {
        case .automatic: L("Auto")
        case .detach: JITProtocol.detach.title
        case .universal: JITProtocol.universal.title
        case .legacy: JITProtocol.legacy(regions: 1).title
        case .geode: JITProtocol.geode.title
        }
    }

    private func enableButton(_ app: JITApp) -> some View {
        Button {
            manager.enable(app)
        } label: {
            HStack(spacing: 6) {
                if manager.startingBundleID == app.bundleID
                    || (manager.status?.app == app && manager.status?.phase != .attached) {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text(L("Enable JIT"))
            }
        }
        .buttonStyle(SecondaryButtonStyle(tint: Theme.accent), sound: .tap)
        .controlSize(.small)
        .disabled(manager.isBusy)
    }

    private var emptyState: some View {
        PanelCard {
            VStack(spacing: 8) {
                Image(systemName: "bolt.slash")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.muted)
                Text(L("No apps can use JIT"))
                    .font(.headline)
                Text(L("No app on this iPhone is signed for development, which a debugger needs. Install the app with SideStore or SideInstaller, which sign apps that way, then load the apps again."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private static func format(bytes: UInt64) -> String {
        Int64(clamping: bytes).formatted(.byteCount(style: .memory).locale(Localizer.locale))
    }
}
