import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The Install screen: an Apple ID, a build, and a step timeline while it runs.
struct ContentView: View {
    @EnvironmentObject private var engine: Engine
    @EnvironmentObject private var updateChecker: UpdateChecker
    /// Declared so every label on this screen redraws when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// Shared with the Certificates page — see `certConflictCallout`.
    @EnvironmentObject private var certManager: CertManager
    @Environment(\.openURL) private var openURL
    @State private var showSettings = false
    @State private var showImporter = false
    /// True while the pairing-file picker is up, on an iPhone below iOS 27.
    @State private var showPairingImporter = false
    /// True while the certificate chooser is showing; each certificate there is
    /// its own destructive button, so nothing is revoked without a choice.
    @State private var showRevokeChooser = false
    /// The timeline shows only the step in flight until this is set.
    @State private var stepsExpanded = false
    /// The link typed into the import field, kept until it downloads.
    @State private var ipaLink = ""
    @FocusState private var linkFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    if updateChecker.showBanner {
                        updateBanner.transition(.cardAppear)
                    }
                    appCard.cascadeItem(1)
                    // Below iOS 27 this iPhone can't pair with itself, so the
                    // file has to come in from a computer. It sits with the app
                    // picker because both are things to choose before installing.
                    if showsPairingCard {
                        pairingFileCard.cascadeItem(2)
                    }
                    // Most-blocking requirement first: an unsupported iOS, then
                    // Wi-Fi if this run must pair, then the missing tunnel.
                    if !engine.isRunning {
                        if !engine.osSupported {
                            osRequirement.cascadeItem(cascade(2))
                        // Only a run that pairs itself needs Wi-Fi; an imported
                        // pairing file never touches the local network.
                        } else if !engine.wifiConnected, engine.needsFreshPairing, engine.canSelfPair {
                            wifiRequirement.cascadeItem(cascade(2))
                        } else if !engine.vpnConnected {
                            vpnRequirement.cascadeItem(cascade(2))
                        }
                    }
                    // Above the button, so a run in flight reads top-down —
                    // what it is doing, then the Cancel that stops it.
                    if showProgress {
                        progressCard.transition(.cardAppear)
                    }
                    installButton.cascadeItem(cascade(3))
                    if let pin = engine.pairingPIN {
                        pinCallout(pin).transition(.cardAppear)
                    }
                    // The one-tap version of what the guide below explains.
                    if engine.certConflict, !engine.isRunning {
                        certConflictCallout.transition(.cardAppear)
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
                    // LiveContainer still needs SideStore's certificate imported.
                    if engine.finished, engine.installedIsLiveContainer {
                        guideCallout(Guides.liveContainerImport).transition(.cardAppear)
                    }
                    footer.cascadeItem(cascade(4))
                }
                .padding(20)
                // One modifier per piece of state, so only its own card animates.
                .animation(.smooth(duration: 0.35), value: updateChecker.showBanner)
                .animation(.smooth(duration: 0.35), value: engine.vpnConnected)
                .animation(.smooth(duration: 0.35), value: engine.wifiConnected)
                .animation(.smooth(duration: 0.35), value: showProgress)
                .animation(.smooth(duration: 0.35), value: engine.pairingPIN)
                .animation(.smooth(duration: 0.35), value: engine.guide?.title)
                .animation(.smooth(duration: 0.35), value: engine.certConflict)
                .animation(.smooth(duration: 0.3), value: certManager.isWorking)
                .animation(.smooth(duration: 0.35), value: showError)
                .animation(.smooth(duration: 0.4, extraBounce: 0.12), value: engine.finished)
                .animation(.smooth(duration: 0.35), value: engine.deviceSummary)
                .animation(.smooth(duration: 0.3), value: engine.isRunning)
                .animation(.smooth(duration: 0.35), value: engine.importedPairingName)
            }
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showImporter) {
                FileImporterRepresentableView(allowedContentTypes: [.ipa]) { urls in
                    guard let url = urls.first else { return }   // empty means cancelled
                    Task { await engine.importCustomIPA(from: url) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPairingImporter) {
                FileImporterRepresentableView(allowedContentTypes: UTType.pairingFileTypes) { urls in
                    guard let url = urls.first else { return }   // empty means cancelled
                    Task { await engine.importPairingFile(from: url) }
                }
                .ignoresSafeArea()
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: Derived visibility

    private var showProgress: Bool {
        engine.isRunning || engine.overallProgress > 0 || engine.finished
    }

    /// True on an iPhone new enough to install but too old to pair itself.
    private var showsPairingCard: Bool {
        engine.osSupported && !engine.canSelfPair
    }

    /// Entrance order for everything below the pairing-file card, so the
    /// cascade closes up on the iPhones that don't show one.
    private func cascade(_ position: Int) -> Int {
        showsPairingCard ? position + 1 : position
    }

    private var showError: Bool {
        engine.lastError != nil && !engine.isRunning
    }

    /// True once a step has stopped the run, which recolours the whole card.
    private var runFailed: Bool {
        engine.stepStates.values.contains(.failed)
    }

    /// The step the run is on: whatever is in flight, or the last one that
    /// moved once nothing is.
    private var currentStep: Step {
        if let live = Step.allCases.first(where: {
            let state = engine.stepStates[$0]
            return state == .active || state == .waiting || state == .failed
        }) {
            return live
        }
        return Step.allCases.last { engine.stepStates[$0] == .done } ?? .network
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

    /// A quiet brand credit at the foot of the screen.
    private var footer: some View {
        Text(L("an app by Frizzle"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
    }

    // MARK: Update banner

    /// Notice shown when GitHub advertises a newer version than this build.
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

                // A custom IPA has no release, so the importer takes that slot.
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

    /// The two ways in for a custom build: pick a file, or paste a link.
    private var importControl: some View {
        VStack(spacing: 10) {
            filePickerButton
            orDivider
            linkField
        }
    }

    /// Reads the link field as an alternative to the button above it, rather
    /// than as a second step after it.
    private var orDivider: some View {
        HStack(spacing: 10) {
            hairline
            Text(L("or"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            hairline
        }
        .padding(.vertical, 2)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
    }

    /// Import button, labelled with the loaded file's name, or with the import's
    /// progress while one is coming in from iCloud Drive, a USB drive or a link.
    private var filePickerButton: some View {
        Button {
            linkFieldFocused = false
            showImporter = true
        } label: {
            HStack(spacing: 8) {
                if engine.isImportingIPA {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: engine.customIPAName == nil
                          ? "square.and.arrow.down" : "checkmark.circle.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(engine.customIPAName == nil ? Color.secondary : Theme.accent2)
                }
                Text(importLabel)
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

    /// The button's caption: what an import is doing, or what is loaded.
    private var importLabel: String {
        guard engine.isImportingIPA else { return engine.customIPAName ?? L("Import .ipa") }
        // A file copy reports no fraction; a link download does.
        guard let fraction = engine.importProgress else { return L("Importing…") }
        return L("Downloading… %d%%", Int(fraction * 100))
    }

    /// Paste a direct link instead, for a build that isn't on this iPhone yet
    /// and can't be brought over on a second device.
    private var linkField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(L("Paste a download link"), text: $ipaLink)
                    .textFieldStyle(.plain)
                    .focused($linkFieldFocused)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .lineLimit(1)
                    .onSubmit(downloadFromLink)
                if !ipaLink.isEmpty {
                    Button { ipaLink = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: downloadFromLink) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(linkIsUsable ? Theme.accent2 : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!linkIsUsable)
            }
            .fieldBackground()
            // Only a link download knows its size, so this is its bar alone.
            if engine.isImportingIPA, let fraction = engine.importProgress {
                ProgressView(value: fraction)
                    .tint(Theme.accent2)
            }
        }
        .animation(.smooth(duration: 0.25), value: engine.importProgress == nil)
    }

    /// True once the field holds something worth trying to download.
    private var linkIsUsable: Bool {
        !engine.isImportingIPA && Engine.downloadLink(ipaLink) != nil
    }

    private func downloadFromLink() {
        guard linkIsUsable else { return }
        linkFieldFocused = false
        let link = ipaLink
        Task { await engine.importCustomIPA(fromLink: link) }
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

    /// Shown on an iPhone older than the minimum iOS, where nothing can run —
    /// the tunnel every step after pairing runs over doesn't exist there, so an
    /// imported pairing file wouldn't help either.
    private var osRequirement: some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "iphone.gen3.slash")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("iOS %@ required", Engine.minimumTunnelOSText))
                        .font(.subheadline.weight(.semibold))
                    Text(L("This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.",
                           engine.osVersionText, Engine.minimumTunnelOSText))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Pairing file (iOS 26 and below)

    /// SideStore's own write-up of making a pairing file on a computer, which
    /// covers every host OS and stays current without this app reprinting it.
    private static let pairingDocsURL =
        "https://docs.sidestore.io/docs/advanced/alternative#pairing"

    /// The way in for an iPhone that can't pair with itself. Everything else on
    /// this screen works the same once a file is here, so this sits with the
    /// app picker rather than off in the Pairing tab.
    private var pairingFileCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    sectionTitle(L("Pairing file"), systemImage: "lock.doc.fill")
                    Spacer(minLength: 4)
                    if engine.importedPairingName != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }

                pairingImportButton

                Button {
                    if let url = URL(string: Self.pairingDocsURL) { openURL(url) }
                } label: {
                    HStack(spacing: 4) {
                        Text(L("How do I make one?"))
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(engine.isRunning)
    }

    /// Import button, labelled with the imported file's name once one is in.
    private var pairingImportButton: some View {
        Button { showPairingImporter = true } label: {
            HStack(spacing: 8) {
                if engine.isImportingPairing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: engine.importedPairingName == nil
                          ? "square.and.arrow.down" : "checkmark.circle.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(engine.importedPairingName == nil ? Color.secondary : Theme.accent2)
                }
                Text(engine.importedPairingName ?? L("Import pairing file"))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Spacer()
                if engine.importedPairingName != nil, !engine.isImportingPairing {
                    Text(L("Replace"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent2)
                }
            }
            .fieldBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(engine.isImportingPairing)
    }

    // MARK: Wi-Fi requirement

    /// Shown while Wi-Fi is off, which pairing needs.
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

    /// Shown while the tunnel the install runs over is off. Named for
    /// LocalDevVPN, though the engine accepts any loopback VPN.
    private var vpnRequirement: some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("LocalDevVPN required"))
                        .font(.subheadline.weight(.semibold))
                    Text(L("Install LocalDevVPN and connect it. The install runs over its tunnel."))
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
                HStack(spacing: 10) {
                    Text(engine.finished ? L("Installed") : L("Installing"))
                        .font(.headline)
                        .contentTransition(.opacity)
                    Spacer(minLength: 4)
                    Text("\(Int(engine.overallProgress * 100))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(progressTint)
                        .contentTransition(.numericText(value: engine.overallProgress))
                        .animation(.smooth(duration: 0.3), value: engine.overallProgress)
                    stepsDisclosure
                }

                InstallProgressBar(progress: engine.overallProgress,
                                   tint: progressTint,
                                   gradient: progressGradient,
                                   animating: engine.isRunning && !engine.finished && !runFailed)

                stepSection
            }
        }
    }

    /// Where the run has got to, in colour: red once a step stopped it, green
    /// when it finished, the brand blue while it is under way.
    private var progressTint: Color {
        if runFailed { return .red }
        return engine.finished ? .green : Theme.accent
    }

    private var progressGradient: LinearGradient {
        if runFailed { return Theme.gradient(.red) }
        return engine.finished ? Theme.gradient(.green) : Theme.brand
    }

    /// Opens and closes the full timeline. It lives in the header rather than
    /// with the steps so it keeps its place whichever way the card is showing.
    private var stepsDisclosure: some View {
        Button {
            stepsExpanded.toggle()
        } label: {
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(stepsExpanded ? 180 : 0))
                .padding(7)
                .background(Circle().fill(.white.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stepsExpanded ? L("Show fewer steps") : L("Show all steps"))
    }

    // MARK: Step timeline

    /// The checklist, collapsed to the step in flight until it is opened.
    private var stepSection: some View {
        VStack(spacing: 0) {
            if stepsExpanded {
                ForEach(Array(Step.allCases.enumerated()), id: \.element) { idx, step in
                    // Resolved here so the row redraws on a language change.
                    StepRow(step: step,
                            title: step.title(for: engine.installSource),
                            state: engine.stepStates[step] ?? .pending,
                            installProgress: engine.installProgress,
                            isLast: idx == Step.allCases.count - 1)
                        // Staggered, so opening the list reads as it unrolling.
                        .cascadeItem(idx)
                }
            } else {
                collapsedStepRow
            }
        }
        .animation(.smooth(duration: 0.38), value: stepsExpanded)
    }

    /// The one row the timeline collapses to, pushed aside by the next step as
    /// the run moves on. Tapping it opens the rest.
    private var collapsedStepRow: some View {
        let step = currentStep
        return ZStack {
            CurrentStepRow(step: step,
                           title: step.title(for: engine.installSource),
                           state: engine.stepStates[step] ?? .pending,
                           installProgress: engine.installProgress,
                           index: (Step.allCases.firstIndex(of: step) ?? 0) + 1,
                           total: Step.allCases.count)
                .id(step)
                .transition(.push(from: .bottom))
        }
        // Fixed, so the card doesn't breathe as one row replaces another.
        .frame(height: 46)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { stepsExpanded = true }
        .animation(.smooth(duration: 0.35), value: step)
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

    // MARK: Certificate conflict (Apple error 7460)

    /// Shown when signing stopped on a certificate that couldn't be reused. The
    /// button only fetches them; the dialog makes the user name what to revoke.
    private var certConflictCallout: some View {
        CalloutCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("A certificate already exists"))
                            .font(.subheadline.weight(.semibold))
                        Text(L("Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button {
                    // Load first, so the chooser can name the certificates.
                    certManager.ensureLoaded { showRevokeChooser = true }
                } label: {
                    HStack(spacing: 8) {
                        if certManager.isWorking {
                            ProgressView().controlSize(.small)
                            Text(L("Loading certificates"))
                        } else {
                            Image(systemName: "arrow.clockwise.circle")
                            Text(L("Revoke and retry"))
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(certManager.isWorking || certManager.revokingID != nil)

                if let error = certManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .confirmationDialog(L("Which certificate should be revoked?"),
                            isPresented: $showRevokeChooser,
                            titleVisibility: .visible) {
            ForEach(certManager.certs) { cert in
                Button(revokeButtonLabel(for: cert), role: .destructive) {
                    certManager.revoke(cert) {
                        engine.log("Retrying the install after revoking \(cert.displayName).")
                        engine.runOneClick()
                    }
                }
            }
            Button(L("Cancel"), role: .cancel) { }
        } message: {
            Text(certManager.certs.isEmpty
                 ? L("Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.")
                 : L("Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards."))
        }
    }

    /// Names a certificate in the chooser, with its machine and expiry.
    private func revokeButtonLabel(for cert: DevCert) -> String {
        var label = cert.displayName
        if let machine = cert.machineLabel { label += " — \(machine)" }
        if cert.isExpired { label += L(" (expired)") }
        return label
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
    /// The gear button that opens Settings, shared by every screen.
    func settingsToolbarItem(isPresented: Binding<Bool>) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isPresented.wrappedValue = true } label: {
                Image(systemName: "gearshape")
            }
            .tint(.primary)
        }
    }
}

// MARK: - Progress bar

/// The install bar: a gradient fill that glows against the dark card, with a
/// sheen travelling its length and a light pinned to its head while the run is
/// under way. Both are read off the clock rather than driven by a repeating
/// animation, so a fill that moves mid-sweep doesn't drag them out of step.
private struct InstallProgressBar: View {
    let progress: Double
    let tint: Color
    let gradient: LinearGradient
    /// False once the run has finished or stopped, leaving the bar at rest.
    let animating: Bool

    /// Wide enough to read as light crossing the bar rather than a line.
    private let sheenWidth: CGFloat = 96
    /// Seconds per pass — slow enough to stay calm at the edge of vision.
    private let sheenPeriod: Double = 1.9

    var body: some View {
        GeometryReader { geo in
            let full = geo.size.width
            // Never quite empty: a sliver says the run has started.
            let filled = max(12, full * min(max(progress, 0), 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.05), lineWidth: 1))
                fill(across: full)
                    .frame(width: filled)
                    .animation(.smooth(duration: 0.45), value: filled)
            }
        }
        .frame(height: 12)
    }

    private func fill(across full: CGFloat) -> some View {
        TimelineView(.animation(paused: !animating)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Capsule()
                .fill(gradient)
                // A lit top edge, which gives the pill some depth.
                .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.28), .clear],
                                                       startPoint: .top, endPoint: .bottom)))
                // Overlays rather than stacked siblings: the sheen is wider than
                // the fill early in a run, and as a sibling its width would set
                // the fill's own and hang it off the end of the track.
                .overlay(alignment: .leading) { if animating { sheen(at: t, across: full) } }
                .overlay(alignment: .trailing) { if animating { head(at: t) } }
                // Keeps the sheen's blend inside the fill instead of over the card.
                .compositingGroup()
                .clipShape(Capsule())
        }
        .shadow(color: tint.opacity(0.5), radius: 9)
    }

    /// The highlight that runs the length of the bar. It travels the whole
    /// track, not just the filled part, so its pace doesn't change with the
    /// progress; the capsule clips whatever has run past the head.
    private func sheen(at t: TimeInterval, across full: CGFloat) -> some View {
        let phase = t.truncatingRemainder(dividingBy: sheenPeriod) / sheenPeriod
        return Rectangle()
            .fill(LinearGradient(stops: [.init(color: .white.opacity(0), location: 0),
                                         .init(color: .white.opacity(0.5), location: 0.5),
                                         .init(color: .white.opacity(0), location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: sheenWidth)
            .offset(x: -sheenWidth + (full + sheenWidth * 2) * phase)
            .blendMode(.plusLighter)
    }

    /// A soft light at the head of the fill, breathing while it works.
    private func head(at t: TimeInterval) -> some View {
        Capsule()
            .fill(.white)
            .frame(width: 5)
            .blur(radius: 3)
            .opacity(0.45 + 0.35 * sin(t * 3.4))
    }
}

// MARK: - Step row

/// One row of the install timeline: a status node, the title, and a badge.
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
                    StepBadge(step: step, state: state, installProgress: installProgress)
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
            StepNode(state: state)
            if !isLast {
                Rectangle()
                    .fill(state == .done ? Color.green.opacity(0.5) : Color(.tertiarySystemFill))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 28)
    }
}

// MARK: - Collapsed step row

/// What the timeline shows when it is closed: the step in flight, its place in
/// the run, and the same badge the full row would carry.
private struct CurrentStepRow: View {
    let step: Step
    let title: String
    let state: StepState
    let installProgress: Double
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 14) {
            StepNode(state: state)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(L("Step %@ of %@", "\(index)", "\(total)"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            StepBadge(step: step, state: state, installProgress: installProgress)
        }
        .animation(.smooth(duration: 0.3), value: state)
    }
}

// MARK: - Step parts

/// The status dot a step wears, in either timeline. The active one sits under
/// a halo that swells and fades, so the eye lands on the step in flight.
private struct StepNode: View {
    let state: StepState

    var body: some View {
        ZStack {
            if state == .active { halo }
            Circle().fill(nodeFill).frame(width: 28, height: 28)
            Circle().strokeBorder(nodeStroke, lineWidth: 1.5).frame(width: 28, height: 28)
            icon
        }
        .frame(width: 28, height: 28)
    }

    /// Off the clock, so it restarts cleanly every time a step becomes active.
    private var halo: some View {
        TimelineView(.animation) { timeline in
            let p = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.6) / 1.6
            Circle()
                .strokeBorder(Theme.accent.opacity(0.75 * (1 - p)), lineWidth: 2)
                .frame(width: 28, height: 28)
                .scaleEffect(1 + 0.5 * p)
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

/// The right-hand side of a step: how far the install has got, or a call for
/// the user to do something.
private struct StepBadge: View {
    let step: Step
    let state: StepState
    let installProgress: Double

    var body: some View {
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
}

// MARK: - File picker

extension UTType {
    /// The type this app exports for `.ipa` in its Info.plist, which is what
    /// makes the extension resolve to something a picker can match. Without a
    /// declaration iOS mints a dynamic type per device, and files typed that
    /// way are the ones the picker shows but won't let you tap.
    static let ipa: UTType = UTType(filenameExtension: "ipa") ?? .data

    /// The same arrangement for `.mobiledevicepairing`, which jitterbugpair
    /// writes and no system type covers.
    static let mobileDevicePairing: UTType = UTType(filenameExtension: "mobiledevicepairing") ?? .data

    /// What the pairing-file picker accepts: jitterbugpair's extension, and the
    /// plain `.plist` pymobiledevice3 and idevicepair write.
    static var pairingFileTypes: [UTType] { [mobileDevicePairing, .propertyList, .xml] }
}

/// The system document picker behind a representable, shown as a sheet — the
/// arrangement Feather uses, ported here after SwiftUI's own `.fileImporter`
/// left rows inert on iOS 27.
///
/// `asCopy: true` has iOS copy the chosen file into this app's Inbox and hand
/// that over, rather than vend a security-scoped handle on the original.
struct FileImporterRepresentableView: UIViewControllerRepresentable {
    var allowedContentTypes: [UTType]
    var allowsMultipleSelection = false
    var onDocumentsPicked: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentsPicked: onDocumentsPicked)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes,
                                                    asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowsMultipleSelection
        // An `.ipa` is told apart by its extension, so show it.
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onDocumentsPicked: ([URL]) -> Void

        init(onDocumentsPicked: @escaping ([URL]) -> Void) {
            self.onDocumentsPicked = onDocumentsPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            onDocumentsPicked(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDocumentsPicked([])
        }
    }
}
