import SwiftUI
import UIKit

/// The "Pairing" tab — manage the device pairing file on its own, the way
/// iLoader's "Manage Pairing files" does. Generate (extract) the pairing file,
/// export it (share / Save to Files), and write it into a supported app installed
/// on this iPhone (SideStore, StikDebug, Feather, …) over LocalDevVPN.
struct PairingView: View {
    @EnvironmentObject private var engine: Engine
    @ObservedObject var manager: PairingManager

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    pairingFileCard.cascadeItem(1)
                    if let pin = engine.pairingPIN {
                        pinCard(pin).transition(.cardAppear)
                    }
                    if manager.isGenerating {
                        generatingSteps.transition(.cardAppear)
                    }
                    installCard.cascadeItem(2)
                    if let error = manager.lastError {
                        errorCallout(error).transition(.cardAppear)
                    }
                    if let success = manager.lastSuccess {
                        successCallout(success).transition(.cardAppear)
                    }
                    targetList
                }
                .padding(20)
                .animation(.smooth(duration: 0.35), value: manager.pairingFileExists)
                .animation(.smooth(duration: 0.35), value: engine.pairingPIN)
                .animation(.smooth(duration: 0.35), value: manager.isGenerating)
                .animation(.smooth(duration: 0.35), value: manager.lastError)
                .animation(.smooth(duration: 0.35), value: manager.lastSuccess)
                .animation(.smooth(duration: 0.35), value: manager.targets)
                .animation(.smooth(duration: 0.3), value: engine.deviceSummary)
                .animation(.smooth(duration: 0.3), value: engine.vpnConnected)
                .animation(.smooth(duration: 0.3), value: engine.wifiConnected)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .onAppear { manager.refresh() }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "lock.doc.fill", image: "PairingLogo", title: "Pairing") {
            statusPill
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                .id(statusID)
        }
    }

    /// Stable identity so the pill cross-fades when its meaning changes.
    private var statusID: String {
        engine.deviceSummary ?? (manager.pairingFileExists ? "ready" : "none")
    }

    @ViewBuilder
    private var statusPill: some View {
        if let summary = engine.deviceSummary {
            StatusPill(text: summary, systemImage: "iphone", color: .green)
        } else if manager.pairingFileExists {
            StatusPill(text: "Pairing file ready", systemImage: "checkmark.seal.fill", color: .green)
        } else {
            StatusPill(text: "No pairing file", systemImage: "lock.slash.fill", color: .orange, glass: true)
        }
    }

    // MARK: Pairing file (generate + export)

    private var pairingFileCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Pairing file", systemImage: "lock.doc.fill")

                Button { manager.generate() } label: {
                    HStack(spacing: 10) {
                        if manager.isGenerating {
                            ProgressView().tint(.white)
                            Text("Pairing…")
                        } else {
                            Image(systemName: manager.pairingFileExists ? "arrow.clockwise" : "lock.iphone")
                                .contentTransition(.symbolEffect(.replace))
                            Text(manager.pairingFileExists ? "Regenerate" : "Generate pairing file")
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(manager.isBusy || engine.isRunning)

                if let url = manager.exportURL {
                    ShareLink(item: url) {
                        Label("Export pairing file", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .tint(Theme.accent)
                    .disabled(manager.isBusy)
                }
            }
        }
    }

    // MARK: Pairing-code callout (shown while the RPPairing host is running)

    private func pinCard(_ pin: String) -> some View {
        CalloutCard(tint: .orange) {
            VStack(spacing: 12) {
                sectionTitle("Pairing code", systemImage: "lock.iphone")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(pin)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .tracking(8)
                    .frame(maxWidth: .infinity)
                Text("Type this into the prompt in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    UIPasteboard.general.string = pin
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
    }

    private var generatingSteps: some View {
        CalloutCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Pair in Settings", systemImage: "gearshape")
                stepsList(Guides.pairing.steps)
                if !engine.pairingStatus.isEmpty {
                    Text(engine.pairingStatus)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Install into an app

    private var installCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Install into an app", systemImage: "tray.and.arrow.down.fill")

                // Wi-Fi is the prerequisite for the tunnel, so it takes priority:
                // no Wi-Fi → Wi-Fi note; Wi-Fi but no tunnel → LocalDevVPN note.
                if !engine.wifiConnected {
                    wifiNote
                } else if !engine.vpnConnected {
                    vpnNote
                }

                Button { manager.scan() } label: {
                    HStack(spacing: 10) {
                        if manager.isScanning {
                            ProgressView().tint(.white)
                            Text("Scanning")
                        } else {
                            Image(systemName: manager.hasScanned ? "arrow.clockwise" : "magnifyingglass")
                                .contentTransition(.symbolEffect(.replace))
                            Text(manager.hasScanned ? "Rescan apps" : "Scan installed apps")
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(manager.isBusy || !manager.pairingFileExists || !engine.wifiConnected || !engine.vpnConnected || engine.isRunning)
            }
        }
    }

    private var wifiNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.red)
            Text("Connect to Wi-Fi to scan and install. LocalDevVPN's tunnel runs over it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.12)))
    }

    private var vpnNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(.red)
            Text("Turn on LocalDevVPN to scan and install. The write runs over its tunnel.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.12)))
    }

    // MARK: Scanned targets

    @ViewBuilder
    private var targetList: some View {
        if manager.hasScanned && manager.targets.isEmpty && !manager.isScanning {
            emptyTargets.transition(.cardAppear)
        } else if !manager.targets.isEmpty {
            VStack(spacing: 14) {
                HStack {
                    Text("\(manager.targets.count) supported \(manager.targets.count == 1 ? "app" : "apps") installed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .cascadeItem(3)
                ForEach(Array(manager.targets.enumerated()), id: \.element.id) { idx, target in
                    targetRow(target).cascadeItem(4 + idx)
                }
            }
        }
    }

    private var emptyTargets: some View {
        PanelCard {
            VStack(spacing: 8) {
                Image(systemName: "questionmark.app.dashed")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.brand)
                Text("No supported apps found")
                    .font(.headline)
                Text("Install an app like SideStore, StikDebug, or Feather first, then rescan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func targetRow(_ target: InstalledPairingTarget) -> some View {
        let installing = manager.installingTargetID == target.id
        return PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "app.dashed")
                        .font(.title3)
                        .foregroundStyle(Theme.brand)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.name)
                            .font(.subheadline.weight(.semibold))
                        Text(target.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }

                Button { manager.install(into: target) } label: {
                    HStack(spacing: 6) {
                        if installing {
                            ProgressView().controlSize(.small)
                            Text("Installing")
                        } else {
                            Image(systemName: "arrow.down.doc")
                            Text("Install pairing")
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .controlSize(.regular)
                .disabled(manager.isBusy || engine.isRunning)
            }
        }
    }

    // MARK: Error / success

    private func errorCallout(_ message: String) -> some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Something went wrong")
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func successCallout(_ message: String) -> some View {
        CalloutCard(tint: .green) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.brand)
        }
    }

    private func stepsList(_ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(idx + 1)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.brand))
                    Text(step)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
