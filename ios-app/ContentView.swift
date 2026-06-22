import SwiftUI
import UIKit

/// Friendly, guided one-click installer. The default flow runs every step in
/// order with a progress bar and contextual instructions; the raw per-stage
/// harness lives in a collapsible “Advanced” section at the bottom.
struct ContentView: View {
    @EnvironmentObject private var engine: Engine
    @Environment(\.openURL) private var openURL
    @State private var showAdvanced = false
    /// `true` once the user picks "Custom…" in the anisette server menu, which
    /// reveals the free-form URL field.
    @State private var anisetteIsCustom = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                credentials
                sourcePicker
                if !engine.vpnConnected {
                    vpnBanner.transition(.cardAppear)
                }
                actionButton
                if showProgress {
                    progressSection.transition(.cardAppear)
                }
                if let pin = engine.pairingPIN {
                    pinCard(pin).transition(.cardAppear)
                }
                if let guide = engine.guide {
                    guideCard(guide).transition(.cardAppear)
                }
                if showError, let error = engine.lastError {
                    errorCard(error).transition(.cardAppear)
                }
                if engine.finished {
                    successCard.transition(.cardAppear)
                }
                // After a LiveContainer + SideStore install, point the user at
                // the extra step of importing SideStore's certificate into
                // LiveContainer. Only shown for that build.
                if engine.finished, engine.installedIsLiveContainer {
                    guideCard(Guides.liveContainerImport).transition(.cardAppear)
                }
                advancedSection
            }
            .padding(16)
            // Drive the card insert/remove transitions above. Each modifier
            // watches one piece of state, so a change animates only its own
            // card swap rather than the whole screen at once.
            .animation(.smooth(duration: 0.35), value: engine.vpnConnected)
            .animation(.smooth(duration: 0.35), value: showProgress)
            .animation(.smooth(duration: 0.35), value: engine.pairingPIN)
            .animation(.smooth(duration: 0.35), value: engine.guide?.title)
            .animation(.smooth(duration: 0.35), value: showError)
            .animation(.smooth(duration: 0.4, extraBounce: 0.12), value: engine.finished)
            .animation(.smooth(duration: 0.35), value: engine.deviceSummary)
            .animation(.smooth(duration: 0.3), value: engine.isRunning)
        }
        // The 2FA alert lives in RootView so it presents from either tab.
    }

    // MARK: Derived visibility (kept here so the transitions above can key off
    // a single stable value instead of a compound condition).

    /// The progress card is visible once a run starts and stays up afterwards.
    private var showProgress: Bool {
        engine.isRunning || engine.overallProgress > 0 || engine.finished
    }

    /// The error card only shows a stored error while nothing is running.
    private var showError: Bool {
        engine.lastError != nil && !engine.isRunning
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                // Gentle "alive" cue: the icon breathes while the install runs.
                .symbolEffect(.pulse, isActive: engine.isRunning)
            Text("SideInstaller")
                .font(.largeTitle.bold())
            if let summary = engine.deviceSummary {
                Label(summary, systemImage: "iphone")
                    .font(.caption.bold())
                    .padding(.top, 2)
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: What to install

    private var sourcePicker: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("What to install", systemImage: "shippingbox")
                    .font(.headline)
                Picker("Version", selection: $engine.installSource) {
                    ForEach(InstallSource.allCases) { src in
                        Text(src.shortName).tag(src)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .disabled(engine.isRunning)
    }

    // MARK: Credentials

    private var credentials: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Apple ID", systemImage: "person.crop.circle")
                    .font(.headline)
                TextField("Apple ID email", text: $engine.appleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                SecureField("Apple ID password", text: $engine.applePassword)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .disabled(engine.isRunning)
    }

    // MARK: Primary action

    private var actionButton: some View {
        Button {
            if engine.isRunning { engine.cancelOneClick() } else { engine.runOneClick() }
        } label: {
            HStack {
                if engine.isRunning {
                    ProgressView().tint(.white)
                    Text("Cancel")
                } else {
                    Image(systemName: engine.finished ? "arrow.clockwise" : "square.and.arrow.down")
                        .contentTransition(.symbolEffect(.replace))
                    Text(engine.finished ? "Run again" : "Install \(engine.installSource.shortName)")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(engine.isRunning ? .red : .accentColor)
    }

    // MARK: LocalDevVPN status banner

    /// Shown above the Install button only while the LocalDevVPN tunnel is *off*,
    /// so the requirement is visible before the user taps. Install is gated on
    /// the tunnel being up (see `Engine.runOneClick`).
    private var vpnBanner: some View {
        card(tint: .orange) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 3) {
                    Text("LocalDevVPN is off")
                        .font(.subheadline.bold())
                    Text("Open LocalDevVPN and tap Connect before installing. The whole install runs over its tunnel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let label = Guides.vpn.actionLabel, let url = Guides.vpn.actionURL {
                        Button { openURL(url) } label: {
                            Label(label, systemImage: "arrow.up.right.square")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 2)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: Progress + checklist

    private var progressSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(engine.finished ? "Complete" : "Progress")
                        .font(.headline)
                        .contentTransition(.opacity)
                    Spacer()
                    Text("\(Int(engine.overallProgress * 100))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: engine.overallProgress))
                        .animation(.smooth(duration: 0.3), value: engine.overallProgress)
                }
                ProgressView(value: engine.overallProgress)
                    .tint(engine.finished ? .green : .accentColor)
                    .animation(.smooth(duration: 0.3), value: engine.overallProgress)

                VStack(spacing: 0) {
                    ForEach(Step.allCases) { step in
                        StepRow(step: step,
                                state: engine.stepStates[step] ?? .pending,
                                installProgress: engine.installProgress)
                    }
                }
            }
        }
    }

    // MARK: PIN card

    private func pinCard(_ pin: String) -> some View {
        card(tint: .orange) {
            VStack(spacing: 8) {
                Label("Pairing PIN", systemImage: "lock.iphone")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(pin)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .tracking(8)
                    .frame(maxWidth: .infinity)
                Text("Type this code into the prompt in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    UIPasteboard.general.string = pin
                } label: {
                    Label("Copy PIN", systemImage: "doc.on.doc")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Guide card

    private func guideCard(_ guide: Guide) -> some View {
        card(tint: .accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                Label(guide.title, systemImage: guide.systemImage)
                    .font(.headline)
                ForEach(Array(guide.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.tint)
                        Text(step)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let label = guide.actionLabel, let url = guide.actionURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label(label, systemImage: "arrow.up.right.square")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: Error / success

    private func errorCard(_ message: String) -> some View {
        card(tint: .red) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Stopped", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Fix the issue above, then tap “Install SideStore” to try again. Copy diagnostics from Advanced if you need help.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var successCard: some View {
        card(tint: .green) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, options: .nonRepeating, value: engine.finished)
                Text("SideStore is installed. Finish the trust step in the card above, then open SideStore.")
                    .font(.subheadline)
            }
        }
    }

    // MARK: Advanced (the old raw harness)

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 12) {
                advancedInputs
                advancedActions
                Divider()
                console
            }
            .padding(.top, 8)
        } label: {
            Label("Advanced", systemImage: "wrench.and.screwdriver")
                .font(.subheadline.bold())
        }
        .padding(.top, 4)
    }

    // MARK: Anisette server picker

    /// Pick an anisette server from the community list (same one SideStore /
    /// iLoader use) instead of typing a URL. "Custom…" reveals the URL field.
    private var anisetteServerPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Anisette server")
                Spacer()
                Picker("Anisette server", selection: anisetteSelection) {
                    ForEach(engine.anisetteServers) { server in
                        Text(server.name).tag(Optional(server.address))
                    }
                    Divider()
                    Text("Custom…").tag(String?.none)
                }
                .pickerStyle(.menu)
            }
            .font(.caption)
            if anisetteIsCustom {
                TextField("Anisette server URL", text: $engine.anisetteURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(engine.anisetteURL)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .onAppear {
            // Treat an address that isn't in the list as a custom one.
            anisetteIsCustom = !engine.anisetteServers.contains { $0.address == engine.anisetteURL }
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

    private var advancedInputs: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings").font(.caption.bold()).foregroundStyle(.secondary)
            anisetteServerPicker
            TextField("Device IP (LocalDevVPN target)", text: $engine.deviceIP)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
            Group {
                Text("VPN: \(engine.vpnStatus)   Wi-Fi: \(engine.wifiStatus)")
                Text("Pairing: \(engine.pairingStatus)")
                Text("Sign-in: \(engine.signInStatus)")
                Text("IPA: \(shortPath(engine.downloadedIPAPath))   Signed: \(shortPath(engine.signedAppPath))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var advancedActions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Run steps individually").font(.caption.bold()).foregroundStyle(.secondary)
            Button("Ping Rust core") { engine.ping() }
            Group {
                Text("Step 2 — pairing + connection").font(.caption2).bold()
                Button("Check VPN + Wi-Fi") { engine.checkVPNAndWifi() }
                Button("Generate pairing file (RPPairing)") { engine.generatePairingFile() }
                Button("Connect + read device info") { engine.connectAndReadDeviceInfo() }
                Button("List installed apps") { engine.listInstalledApps() }
            }
            Group {
                Text("Step 3 — Apple ID + signing").font(.caption2).bold()
                Button("Apple ID sign in") { engine.appleSignIn() }
                Button("Fetch cert + App ID + profile") { engine.fetchCertAndProfile() }
                Button("Download latest SideStore IPA") { engine.downloadLatestSideStore() }
                Button("Sign IPA") { engine.signIPA() }
            }
            Group {
                Text("Step 4 — install + finalize").font(.caption2).bold()
                Button("Install SideStore") { engine.installSideStore() }
                Button("Write pairing file into SideStore") { engine.writePairingIntoSideStore() }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var console: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Log (\(engine.lines.count))").font(.caption).bold()
                Spacer()
                Button("Copy") { UIPasteboard.general.string = engine.logText() }
                Button("Clear") { engine.clearLog() }
            }
            .font(.caption)
            .padding(.vertical, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(engine.lines) { line in
                            Text("\(line.stamp)  \(line.text)")
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(height: 220)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: engine.lines.count) { _, _ in
                    if let last = engine.lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: Helpers

    private func shortPath(_ p: String?) -> String {
        guard let p else { return "—" }
        return (p as NSString).lastPathComponent
    }

    /// A rounded, subtly-tinted container used for every section.
    private func card<Content: View>(tint: Color = .secondary,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tint.opacity(0.25), lineWidth: 1)
            )
    }
}

/// One row of the step checklist: an icon reflecting state + the step title,
/// with a live percentage while installing.
private struct StepRow: View {
    let step: Step
    let state: StepState
    let installProgress: Double

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 22, height: 22)
            Text(step.title)
                .font(.subheadline)
                .foregroundStyle(state == .pending ? .secondary : .primary)
            Spacer()
            if step == .install, state == .active {
                Text("\(Int(installProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: installProgress))
                    .animation(.smooth(duration: 0.3), value: installProgress)
                    .transition(.opacity)
            } else if state == .waiting {
                Text("needs you")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.vertical, 6)
        // Animate every state change for this row: the icon morphs, the
        // trailing label fades, and the title colour eases in.
        .animation(.smooth(duration: 0.3), value: state)
    }

    /// A spinner while the step runs; otherwise a single SF Symbol that morphs
    /// between states (the symbol "replace" effect visually links the old and
    /// new status), with a one-shot bounce the moment the step completes.
    @ViewBuilder
    private var icon: some View {
        switch state {
        case .active:
            ProgressView()
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
        default:
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, options: .nonRepeating, value: state == .done)
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
        }
    }

    private var iconName: String {
        switch state {
        case .pending: return "circle"
        case .active:  return "circle"                  // unused (ProgressView shown)
        case .waiting: return "hand.point.up.left.fill"
        case .done:    return "checkmark.circle.fill"
        case .failed:  return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .pending: return Color(.tertiaryLabel)
        case .active:  return .accentColor
        case .waiting: return .orange
        case .done:    return .green
        case .failed:  return .red
        }
    }
}

extension AnyTransition {
    /// Shared insert/remove used by every status card: eases down and scales up
    /// while fading in, then fades + shrinks slightly on the way out.
    static var cardAppear: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.97, anchor: .top))
                .combined(with: .offset(y: -8)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
        )
    }
}
