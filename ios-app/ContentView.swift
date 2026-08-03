import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The Install screen: enter an Apple ID, choose a build, and install it in one
/// tap. While the pipeline runs, an animated step timeline and contextual
/// callouts guide the user through anything they need to do by hand.
struct ContentView: View {
    @EnvironmentObject private var engine: Engine
    @EnvironmentObject private var updateChecker: UpdateChecker
    /// Declared so every label on this screen redraws when the language changes.
    @EnvironmentObject private var loc: Localizer
    @Environment(\.openURL) private var openURL
    @State private var showSettings = false
    @State private var showImporter = false

    /// What the import picker will let you choose.
    ///
    /// Deliberately just "any file". iOS declares no UTType for `.ipa`, so the
    /// obvious `UTType(filenameExtension: "ipa")` mints a *dynamic* type — and a
    /// file only becomes selectable if the type its storage provider resolved
    /// happens to be that same dynamic type. When it isn't (iCloud Drive, a
    /// share sheet, a third-party provider often report the file as a zip or as
    /// plain data), the picker shows the file as normal and then silently
    /// ignores every tap on it: no selection, no dismissal, no callback.
    ///
    /// So the filter accepts everything and `Engine.importCustomIPA` does the
    /// real checking, by looking inside the file rather than trusting a label.
    private static let importableTypes: [UTType] = [.data]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    if updateChecker.showBanner {
                        updateBanner.transition(.cardAppear)
                    }
                    appleIDCard.cascadeItem(1)
                    appCard.cascadeItem(2)
                    // Most-blocking requirement first: an unsupported iOS can't
                    // be worked around at all, so it pre-empts the other two.
                    // Then Wi-Fi, but only for a run that has to pair — with a
                    // pairing file already saved the tunnel is pure loopback and
                    // cellular carries the rest, so there's nothing to warn
                    // about. Wi-Fi settled but no tunnel → loopback-VPN callout.
                    if !engine.isRunning {
                        if !engine.osSupported {
                            osRequirement.cascadeItem(3)
                        } else if !engine.wifiConnected, engine.needsFreshPairing {
                            wifiRequirement.cascadeItem(3)
                        } else if !engine.vpnConnected {
                            vpnRequirement.cascadeItem(3)
                        }
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
                    if engine.finished {
                        successCallout.transition(.cardAppear)
                    }
                    // After a LiveContainer + SideStore install, the user still
                    // needs to import SideStore's certificate into LiveContainer.
                    if engine.finished, engine.installedIsLiveContainer {
                        guideCallout(Guides.liveContainerImport).transition(.cardAppear)
                    }
                    footer.cascadeItem(5)
                }
                .padding(20)
                // Each modifier watches one piece of state so a change animates
                // only its own card swap rather than the whole screen.
                .animation(.smooth(duration: 0.35), value: updateChecker.showBanner)
                .animation(.smooth(duration: 0.35), value: engine.vpnConnected)
                .animation(.smooth(duration: 0.35), value: engine.wifiConnected)
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
            // Attached here rather than on the card that owns the button: the
            // card carries `.disabled(engine.isRunning)`, and a presentation
            // inherits the environment of wherever its modifier lives, which
            // can leave the picked file unresponsive to taps.
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: Self.importableTypes) { result in
                switch result {
                case let .success(url):   Task { await engine.importCustomIPA(from: url) }
                case let .failure(error): engine.log("⛔️ Import cancelled: \(error.localizedDescription)")
                }
            }
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
            statusPill
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                .id(statusPillID)
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
            StatusPill(text: L("Tunnel connected"), systemImage: "checkmark.shield.fill", color: .green)
        } else {
            StatusPill(text: L("Tunnel off"), systemImage: "shield.slash.fill", color: .red)
        }
    }

    // MARK: Footer

    /// A quiet brand credit at the foot of the screen, tucked below the flow so it
    /// stays visible without crowding the header.
    private var footer: some View {
        Text(L("an app by Frizzle"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
    }

    // MARK: Apple ID

    private var appleIDCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Apple ID", systemImage: "person.crop.circle.fill")
                TextField(L("Email"), text: $engine.appleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textFieldStyle(.plain)
                    .fieldBackground()
                SecureField(L("Password"), text: $engine.applePassword)
                    .textContentType(.password)
                    .textFieldStyle(.plain)
                    .fieldBackground()
            }
        }
        .disabled(engine.isRunning)
    }

    // MARK: Update banner

    /// Closable notice shown when GitHub advertises a newer version than this
    /// build (see `UpdateChecker`). Tapping the body opens the install page; the
    /// ✕ dismisses it for this launch.
    private var updateBanner: some View {
        CalloutCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.brand)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Update available"))
                            .font(.subheadline.weight(.semibold))
                        Text(L("SideInstaller %@ is available — you're on %@.",
                               updateChecker.latestVersion ?? "", updateChecker.currentVersion))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Button {
                        updateChecker.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Circle().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    if let url = URL(string: UpdateChecker.installPageURL) { openURL(url) }
                } label: {
                    HStack(spacing: 4) {
                        Text(L("Get the latest version"))
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: App picker

    private var appCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L("Install"), systemImage: "square.and.arrow.down.fill")
                Menu {
                    Picker(L("Install"), selection: $engine.installSource) {
                        ForEach(InstallSource.allCases) { src in
                            Text(src.displayName).tag(src)
                        }
                    }
                } label: {
                    HStack {
                        Text(engine.installSource.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .fieldBackground()
                    .contentShape(Rectangle())
                }

                // A custom IPA has no release to choose between, so the channel
                // picker gives its place up to the importer that replaces it.
                ZStack {
                    if engine.installSource == .custom {
                        importControl.transition(.opacity)
                    } else {
                        Picker(L("Release"), selection: $engine.releaseChannel) {
                            ForEach(ReleaseChannel.allCases) { channel in
                                Text(channel.displayName).tag(channel)
                            }
                        }
                        .pickerStyle(.segmented)
                        .transition(.opacity)
                    }
                }
                .animation(.smooth(duration: 0.28), value: engine.installSource)
            }
        }
        .disabled(engine.isRunning)
    }

    /// Import button, which doubles as the readout of what's loaded: once a file
    /// is in, its name is the label, so the card always answers "which IPA will
    /// this install?" without a second row of text.
    ///
    /// While the copy runs it says so. Bringing a file over from iCloud Drive or
    /// a USB drive is slow enough that a button which simply sat there would
    /// read as a button that didn't work.
    private var importControl: some View {
        Button { showImporter = true } label: {
            HStack(spacing: 8) {
                if engine.isImportingIPA {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: engine.customIPAName == nil
                          ? "square.and.arrow.down" : "checkmark.circle.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(engine.customIPAName == nil ? Color.secondary : Theme.accent2)
                }
                Text(engine.isImportingIPA ? L("Importing…")
                                           : (engine.customIPAName ?? L("Import .ipa")))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Spacer()
                if engine.customIPAName != nil, !engine.isImportingIPA {
                    Text(L("Replace"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent2)
                }
            }
            .fieldBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(engine.isImportingIPA)
    }

    // MARK: Primary action

    private var installButton: some View {
        Button {
            if engine.isRunning { engine.cancelOneClick() } else { engine.runOneClick() }
        } label: {
            HStack(spacing: 10) {
                if engine.isRunning {
                    ProgressView().tint(.white)
                    Text(L("Cancel"))
                } else {
                    Image(systemName: engine.finished ? "arrow.clockwise" : "square.and.arrow.down.fill")
                        .contentTransition(.symbolEffect(.replace))
                    Text(engine.finished ? L("Reinstall")
                                         : L("Install %@", engine.installSource.shortName))
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

    // MARK: iOS version requirement

    /// Shown above the Install button on an iPhone older than the minimum iOS.
    /// Unlike the Wi-Fi and loopback-VPN callouts this one isn't a "do this and
    /// carry on" — the install can't run here at all — so it replaces both.
    private var osRequirement: some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "iphone.gen3.slash")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("iOS %@ required", Engine.minimumOSText))
                        .font(.subheadline.weight(.semibold))
                    Text(L("This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.",
                           engine.osVersionText, Engine.minimumOSText))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Wi-Fi requirement

    /// Shown above the Install button while Wi-Fi is off. The tunnel — and so the
    /// whole install — rides on Wi-Fi, so it's the first thing to fix; enabling
    /// it reveals the loopback-VPN callout next if the tunnel is still down.
    private var wifiRequirement: some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "wifi.slash")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Wi-Fi required"))
                        .font(.subheadline.weight(.semibold))
                    Text(L("Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Loopback-VPN requirement

    /// Shown above the Install button while the loopback tunnel is off — the
    /// whole install runs over it, so it must be on before tapping Install.
    private var vpnRequirement: some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Loopback VPN required"))
                        .font(.subheadline.weight(.semibold))
                    Text(L("Turn on a loopback VPN — LocalDevVPN, ClashMi, or any app that tunnels to this iPhone. The install runs over it."))
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
                    Text(engine.finished ? L("Installed") : L("Installing"))
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
                        // The title is resolved here, not inside the row: it's
                        // the stored property whose change makes the row redraw
                        // when the language switches.
                        StepRow(step: step,
                                title: step.title(for: engine.installSource),
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
                sectionTitle(L("Pairing code"), systemImage: "lock.iphone")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(pin)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .tracking(8)
                    .frame(maxWidth: .infinity)
                Text(L("Type this into the prompt in Settings."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    UIPasteboard.general.string = pin
                } label: {
                    Label(L("Copy"), systemImage: "doc.on.doc")
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
                    Text(L("Install stopped"))
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
                Text(L("%@ is installed. Finish the trust step above to open it.",
                       engine.installedSourceName))
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
    let title: String
    let state: StepState
    let installProgress: Double
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            timelineColumn
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title)
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
            Text(L("Action needed"))
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
