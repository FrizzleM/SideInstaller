import SwiftUI
import UIKit

/// The Install screen: enter an Apple ID, choose a build, and install it in one
/// tap. While the pipeline runs, an animated step timeline and contextual
/// callouts guide the user through anything they need to do by hand.
struct ContentView: View {
    @EnvironmentObject private var engine: Engine
    @Environment(\.openURL) private var openURL
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    appleIDCard.cascadeItem(1)
                    buildCard.cascadeItem(2)
                    if !engine.vpnConnected && !engine.isRunning {
                        vpnRequirement.cascadeItem(3)
                    }
                    installButton.cascadeItem(4)
                    if showProgress {
                        progressCard.transition(.cardAppear)
                    }
                    if let pin = engine.pairingPIN {
                        pinCallout(pin).transition(.cardAppear)
                    }
                    if let guide = engine.guide {
                        guideCallout(guide).transition(.cardAppear)
                    }
                    if showError, let error = engine.lastError {
                        errorCallout(error).transition(.cardAppear)
                    }
                    // After a LiveContainer + SideStore install, the user still
                    // needs to import SideStore's certificate into LiveContainer.
                    // Show that step *above* the success note so the remaining
                    // manual action is the first thing they see.
                    if engine.finished, engine.installedIsLiveContainer {
                        guideCallout(Guides.liveContainerImport).transition(.cardAppear)
                    }
                    if engine.finished {
                        successCallout.transition(.cardAppear)
                    }
                }
                .padding(20)
                // Each modifier watches one piece of state so a change animates
                // only its own card swap rather than the whole screen.
                .animation(.smooth(duration: 0.35), value: engine.vpnConnected)
                .animation(.smooth(duration: 0.35), value: showProgress)
                .animation(.smooth(duration: 0.35), value: engine.pairingPIN)
                .animation(.smooth(duration: 0.35), value: engine.guide?.title)
                .animation(.smooth(duration: 0.35), value: showError)
                .animation(.smooth(duration: 0.4, extraBounce: 0.12), value: engine.finished)
                .animation(.smooth(duration: 0.35), value: engine.deviceSummary)
                .animation(.smooth(duration: 0.3), value: engine.isRunning)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: Derived visibility

    private var showProgress: Bool {
        engine.isRunning || engine.overallProgress > 0 || engine.finished
    }

    private var showError: Bool {
        engine.lastError != nil && !engine.isRunning
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "arrow.down.app.fill", image: "AppLogo", title: "SideInstaller",
                    animateIcon: engine.isRunning) {
            VStack(spacing: 12) {
                Text("an app by Frizzle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                statusPill
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                    .id(statusPillID)
            }
        }
    }

    /// A stable identity so the pill cross-fades when its meaning changes.
    private var statusPillID: String {
        engine.deviceSummary ?? (engine.vpnConnected ? "up" : "down")
    }

    @ViewBuilder
    private var statusPill: some View {
        if let summary = engine.deviceSummary {
            StatusPill(text: summary, systemImage: "iphone", color: .green)
        } else if engine.vpnConnected {
            StatusPill(text: "Tunnel connected", systemImage: "checkmark.shield.fill", color: .green)
        } else {
            StatusPill(text: "Tunnel off", systemImage: "shield.slash.fill", color: .red)
        }
    }

    // MARK: Apple ID

    private var appleIDCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Apple ID", systemImage: "person.crop.circle.fill")
                TextField("Email", text: $engine.appleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textFieldStyle(.plain)
                    .fieldBackground()
                SecureField("Password", text: $engine.applePassword)
                    .textContentType(.password)
                    .textFieldStyle(.plain)
                    .fieldBackground()
            }
        }
        .disabled(engine.isRunning)
    }

    // MARK: Build picker

    private var buildCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Build", systemImage: "square.stack.3d.up.fill")
                Picker("Build", selection: $engine.installSource) {
                    ForEach(InstallSource.allCases) { src in
                        Text(src.shortName).tag(src)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .disabled(engine.isRunning)
    }

    // MARK: Primary action

    private var installButton: some View {
        Button {
            if engine.isRunning { engine.cancelOneClick() } else { engine.runOneClick() }
        } label: {
            HStack(spacing: 10) {
                if engine.isRunning {
                    ProgressView().tint(.white)
                    Text("Cancel")
                } else {
                    Image(systemName: engine.finished ? "arrow.clockwise" : "square.and.arrow.down.fill")
                        .contentTransition(.symbolEffect(.replace))
                    Text(engine.finished ? "Reinstall" : "Install \(engine.installSource.shortName)")
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle(
            gradient: engine.isRunning
                ? LinearGradient(colors: [.red, Color(red: 0.9, green: 0.3, blue: 0.35)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                : Theme.brand,
            glow: engine.isRunning ? .red : Theme.accent))
        .animation(.smooth(duration: 0.3), value: engine.isRunning)
    }

    // MARK: LocalDevVPN requirement

    /// Shown above the Install button while the LocalDevVPN tunnel is off — the
    /// whole install runs over it, so it must be on before tapping Install.
    private var vpnRequirement: some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 6) {
                    Text("LocalDevVPN required")
                        .font(.subheadline.weight(.semibold))
                    Text("Open LocalDevVPN and tap Connect. The install runs over its tunnel.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let label = Guides.vpn.actionLabel, let url = Guides.vpn.actionURL {
                        Button { openURL(url) } label: {
                            Label(label, systemImage: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    // MARK: Progress + step timeline

    private var progressCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(engine.finished ? "Installed" : "Installing")
                        .font(.headline)
                        .contentTransition(.opacity)
                    Spacer()
                    Text("\(Int(engine.overallProgress * 100))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(engine.finished ? .green : Theme.accent)
                        .contentTransition(.numericText(value: engine.overallProgress))
                        .animation(.smooth(duration: 0.3), value: engine.overallProgress)
                }

                progressBar

                VStack(spacing: 0) {
                    ForEach(Array(Step.allCases.enumerated()), id: \.element) { idx, step in
                        StepRow(step: step,
                                source: engine.installSource,
                                state: engine.stepStates[step] ?? .pending,
                                installProgress: engine.installProgress,
                                isLast: idx == Step.allCases.count - 1)
                    }
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(engine.finished ? Theme.gradient(.green) : Theme.brand)
                    .frame(width: max(6, geo.size.width * engine.overallProgress))
            }
        }
        .frame(height: 8)
        .animation(.smooth(duration: 0.3), value: engine.overallProgress)
        .animation(.smooth(duration: 0.3), value: engine.finished)
    }

    // MARK: PIN callout

    private func pinCallout(_ pin: String) -> some View {
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

    // MARK: Guidance callout

    private func guideCallout(_ guide: Guide) -> some View {
        CalloutCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(guide.title, systemImage: guide.systemImage)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(guide.steps.enumerated()), id: \.offset) { idx, step in
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
                if let label = guide.actionLabel, let url = guide.actionURL {
                    Button { openURL(url) } label: {
                        Label(label, systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                }
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
                    Text("Install stopped")
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var successCallout: some View {
        CalloutCard(tint: .green) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, options: .nonRepeating, value: engine.finished)
                Text("\(engine.installedSourceName) is installed. Finish the trust step above to open it.")
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
}

// MARK: - Toolbar

extension View {
    /// A gear button that opens the Settings / diagnostics sheet, shared by both
    /// tabs so it sits in the same spot everywhere.
    func settingsToolbarItem(isPresented: Binding<Bool>) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isPresented.wrappedValue = true } label: {
                Image(systemName: "gearshape")
            }
            .tint(.primary)
        }
    }
}

// MARK: - Step row

/// One row of the install timeline: a status node connected by a vertical line
/// to the next step, the step title, and a trailing badge (live percentage
/// while installing, or an "Action needed" cue when blocked on the user).
private struct StepRow: View {
    let step: Step
    let source: InstallSource
    let state: StepState
    let installProgress: Double
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            timelineColumn
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(step.title(for: source))
                        .font(.subheadline.weight(state == .pending ? .regular : .medium))
                        .foregroundStyle(state == .pending ? .secondary : .primary)
                    Spacer()
                    trailing
                }
                .frame(minHeight: 28)
                if !isLast { Spacer(minLength: 14) }
            }
        }
        .animation(.smooth(duration: 0.3), value: state)
    }

    /// The node plus the connecting line that runs down to the next node.
    private var timelineColumn: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(nodeFill).frame(width: 28, height: 28)
                Circle().strokeBorder(nodeStroke, lineWidth: 1.5).frame(width: 28, height: 28)
                icon
            }
            if !isLast {
                Rectangle()
                    .fill(state == .done ? Color.green.opacity(0.5) : Color(.tertiarySystemFill))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 28)
    }

    @ViewBuilder
    private var trailing: some View {
        if step == .install, state == .active {
            Text("\(Int(installProgress * 100))%")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText(value: installProgress))
                .animation(.smooth(duration: 0.3), value: installProgress)
                .transition(.opacity)
        } else if state == .waiting {
            Text("Action needed")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.16)))
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .active:
            ProgressView()
                .controlSize(.small)
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
        default:
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(iconColor)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, options: .nonRepeating, value: state == .done)
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
        }
    }

    private var iconName: String {
        switch state {
        case .pending: return "circle"
        case .active:  return "circle"          // unused (ProgressView shown)
        case .waiting: return "hand.tap.fill"
        case .done:    return "checkmark"
        case .failed:  return "xmark"
        }
    }

    private var iconColor: Color {
        switch state {
        case .pending: return Color(.tertiaryLabel)
        case .active:  return Theme.accent
        case .waiting: return .white
        case .done:    return .white
        case .failed:  return .white
        }
    }

    private var nodeFill: Color {
        switch state {
        case .done:    return .green
        case .failed:  return .red
        case .waiting: return .orange
        default:       return Color(.secondarySystemBackground)
        }
    }

    private var nodeStroke: Color {
        switch state {
        case .pending: return Color(.separator)
        case .active:  return Theme.accent
        case .waiting: return .orange
        case .done:    return .green
        case .failed:  return .red
        }
    }
}
