import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The Install screen: an Apple ID, a build, and a step timeline while it runs.
struct ContentView: View {
    @EnvironmentObject private var engine: Engine
    @EnvironmentObject private var updateChecker: UpdateChecker
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @Environment(\.openURL) private var openURL
    @State private var showSettings = false
    @State private var showImporter = false
    /// True while the pairing-file picker is up.
    @State private var showPairingImporter = false
    /// When false, the Advanced section under the Install button shows only its
    /// title.
    @State private var advancedExpanded = false
    /// When false, the timeline shows only the current step.
    @State private var stepsExpanded = false
    /// True while the Install button is held down. Its surface is drawn outside
    /// the button, so the press is passed out to it.
    @State private var installPressed = false
    /// Shows the "are you sure" alert before the progress card's X stops a run.
    @State private var confirmingCancel = false
    /// Text in the IPA download-link field.
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
                    // Below iOS 27 a pairing file must be imported, so show the
                    // import card.
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
                        // Not when Install starts LocalDevVPN itself.
                        } else if !engine.tunnelAvailable {
                            vpnRequirement.cascadeItem(cascade(2))
                        }
                    }
                    // The Install button, which grows into the run's progress.
                    // Drawn over what follows, so the button below tucks in
                    // under it.
                    installSurface
                        .cascadeItem(cascade(3))
                        .zIndex(1)
                    // The progress outlives its run, so the button comes back
                    // under it. The cascade handles its entrance (including
                    // on a tab switch), so the transition only covers removal.
                    if showProgress && !engine.isRunning {
                        installButton
                            .cascadeItem(cascade(4))
                            .transition(.asymmetric(insertion: .identity, removal: .tuckUnder))
                    }
                    // The build's version, and from iOS 27 (which pairs itself)
                    // the optional pairing-file import, folded away. Like the
                    // button above, the cascade brings it back after a run.
                    if showsAdvanced {
                        advancedSection
                            .cascadeItem(cascade(5))
                            .transition(.asymmetric(insertion: .identity, removal: .quickFade))
                    }
                    // Guides, the pairing code, errors and success show as
                    // `InstallPopup`, which `RootView` lays over the app.
                    footer.cascadeItem(cascade(6))
                }
                .padding(20)
                // One modifier per piece of state, so only its own card animates.
                .animation(.smooth(duration: 0.35), value: updateChecker.showBanner)
                .animation(.smooth(duration: 0.35), value: engine.vpnConnected)
                .animation(.smooth(duration: 0.35), value: engine.wifiConnected)
                // The surface's change of shape, and what it pushes along.
                .animation(.smooth(duration: 0.45), value: showProgress)
                .animation(.smooth(duration: 0.4, extraBounce: 0.12), value: engine.finished)
                .animation(.smooth(duration: 0.35), value: engine.deviceSummary)
                .animation(.smooth(duration: 0.3), value: engine.isRunning)
                .animation(.smooth(duration: 0.35), value: engine.importedPairingName)
                .animation(.smooth(duration: 0.35), value: advancedExpanded)
                .animation(.smooth(duration: 0.35), value: showsAdvanced)
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

    /// True when Advanced has something to hold: a version to pick (not for a
    /// custom IPA), or the optional pairing file (iOS 27 and above). A run
    /// can't take a change to either, so it's away while one goes.
    private var showsAdvanced: Bool {
        !engine.isRunning && (engine.installSource != .custom || engine.canSelfPair)
    }

    /// Cascade index for items below the pairing-file card, shifted by one when
    /// that card is shown.
    private func cascade(_ position: Int) -> Int {
        showsPairingCard ? position + 1 : position
    }

    /// True once a step has failed; turns the progress card red.
    private var runFailed: Bool {
        engine.stepStates.values.contains(.failed)
    }

    /// The active, waiting or failed step; otherwise the last completed one.
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
        } else if engine.startsVPNWhenNeeded {
            // Install starts it, so this isn't a problem to flag.
            StatusPill(text: L("Tunnel off"), systemImage: "shield.slash.fill", color: .orange, glass: true)
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
                Menu {
                    updateOptions
                } label: {
                    HStack(spacing: 4) {
                        Text(L("Get the latest version"))
                        Image(systemName: "chevron.down")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                }
            }
        }
    }

    /// The ways to get the new version: the website's signed build, the
    /// release signed and installed here with the Apple ID's certificate, or,
    /// with LiveContainer on this iPhone, the release installed inside it.
    @ViewBuilder
    private var updateOptions: some View {
        Button {
            if let url = URL(string: UpdateChecker.installPageURL) { openURL(url) }
        } label: {
            Label(L("From the website"), systemImage: "safari")
        }
        Button {
            if let url = URL(string: UpdateChecker.releaseIPAURL) { engine.installLinkedIPA(url) }
        } label: {
            Label(L("Sign it with your Apple ID"), systemImage: "signature")
        }
        .disabled(engine.isRunning || engine.isImportingIPA)
        if engine.liveContainerInstalled {
            Button {
                if let url = URL(string: UpdateChecker.releaseIPAURL) { engine.installInLiveContainer(url) }
            } label: {
                Label(L("Install it in LiveContainer"), systemImage: "shippingbox")
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

                // A custom IPA has no release, so the importer takes that slot;
                // a build with no nightly has nothing to pick and no slot.
                if engine.installSource == .custom || engine.installSource.hasNightly {
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
                    .transition(.opacity)
                }
            }
            // On the whole card, so it also resizes smoothly when the slot goes.
            .animation(.smooth(duration: 0.28), value: engine.installSource)
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

    /// "or" divider between the file picker and the link field.
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

    /// Import button showing the loaded file's name, or progress while importing.
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

    /// Text field for importing an IPA from a direct download link.
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
            // Progress bar for link downloads (file copies report no progress).
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

    /// The Install button and the progress card it turns into, as one surface:
    /// starting a run reshapes the button instead of swapping it for a card.
    /// Only the two sets of content cross-fade; the surface itself changes
    /// size and corners, and the button's gradient gives way to the card's
    /// fill.
    private var installSurface: some View {
        let shape = RoundedRectangle(cornerRadius: showProgress ? 22 : 18, style: .continuous)
        return ZStack(alignment: .top) {
            if showProgress {
                progressContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .transition(.surfaceSwap)
            } else {
                Button(action: startInstall) {
                    installLabel
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressReportingButtonStyle(isPressed: $installPressed))
                .transition(.surfaceSwap)
            }
        }
        .frame(maxWidth: .infinity)
        // Clips the incoming content to the surface while it's still growing.
        .clipShape(shape)
        // The button's gradient and glow, which give way to the card's fill.
        .background(
            shape
                .fill(Theme.brand)
                .shadow(color: Theme.accent.opacity(0.4), radius: 16, x: 0, y: 8)
                .opacity(showProgress ? 0 : 1)
        )
        .cardSurface(in: shape, shown: showProgress)
        // The press `PrimaryButtonStyle` draws, kept apart from the reshaping.
        .animation(.snappy(duration: 0.22)) { surface in
            surface
                .scaleEffect(surfacePressed ? 0.97 : 1)
                .opacity(surfacePressed ? 0.92 : 1)
        }
        .alert(L("Cancel the install?"), isPresented: $confirmingCancel) {
            Button(L("Yes"), role: .destructive) { engine.cancelOneClick() }
            Button(L("No"), role: .cancel) { }
        }
        .onChange(of: engine.isRunning) { _, running in
            // A run that ended by itself leaves nothing to cancel.
            if !running { confirmingCancel = false }
        }
    }

    /// True while the surface is the button and is held down.
    private var surfacePressed: Bool {
        installPressed && !showProgress
    }

    /// Starts the run straight from the tap. The surface reshapes because the
    /// run is going, so nothing waits on the animation.
    private func startInstall() {
        installPressed = false
        engine.runOneClick()
    }

    /// The button under a run's progress once it has ended.
    private var installButton: some View {
        Button(action: startInstall) { installLabel }
            .buttonStyle(PrimaryButtonStyle())
    }

    private var installLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: engine.finished ? "arrow.clockwise" : "square.and.arrow.down.fill")
                .contentTransition(.symbolEffect(.replace))
            Text(engine.finished ? L("Reinstall") : L("Install %@", installTargetName))
        }
    }

    /// The build the Install button names, with its version when one is picked.
    private var installTargetName: String {
        let name = engine.installSource.shortName
        return engine.selectedVersion.map { "\(name) \($0.title)" } ?? name
    }

    // MARK: iOS version requirement

    /// Shown when iOS is below the minimum supported version.
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

    // MARK: Pairing file

    /// SideStore's guide to creating a pairing file on a computer.
    private static let pairingDocsURL =
        "https://docs.sidestore.io/docs/advanced/alternative#pairing"

    /// Pairing-file import card, shown when this iPhone can't pair with itself
    /// (below iOS 27).
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
                if engine.sideStoreInstalled {
                    orDivider
                    sideStorePairingButton
                }
                pairingDocsLink
            }
        }
        .disabled(engine.isRunning)
    }

    /// Asks SideStore for the pairing file it already has. SideStore opens and
    /// sends it back, and the import asks before replacing anything.
    private var sideStorePairingButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { engine.requestSideStorePairing() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundStyle(.secondary)
                    Text(L("Get it from SideStore"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent2)
                }
                .fieldBackground()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(engine.isImportingPairing)
            Text(L("SideStore opens and sends back the pairing file it has."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Link to SideStore's guide to making a pairing file.
    private var pairingDocsLink: some View {
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

    // MARK: Advanced

    /// Advanced section under the Install button, collapsed until its title is
    /// tapped. Holds the build's version and, from iOS 27, the optional
    /// pairing-file import.
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { advancedExpanded.toggle() } label: {
                HStack(spacing: 8) {
                    sectionTitle(L("Advanced"), systemImage: "slider.horizontal.3")
                    Spacer(minLength: 4)
                    // Collapsed, this is the only sign an imported file is in use.
                    if engine.canSelfPair, engine.importedPairingName != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                    disclosureChevron(expanded: advancedExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if advancedExpanded {
                VStack(alignment: .leading, spacing: 22) {
                    if engine.installSource != .custom {
                        versionOption
                    }
                    if engine.canSelfPair {
                        pairingFileOption
                    }
                }
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        // No card behind it; inset to line up with the card contents above.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
    }

    /// Which release of the selected build to install. The list follows the
    /// channel picked above; "Latest" is the default.
    private var versionOption: some View {
        let source = engine.installSource
        let catalog = engine.releaseCatalogs[source]
        let latest = catalog?.latest[engine.selectedChannel]
        let shown = engine.selectedVersion ?? latest
        return VStack(alignment: .leading, spacing: 12) {
            Label(L("%@ version", source.shortName), systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold))
            Menu {
                Picker(L("Version"), selection: $engine.selectedVersion) {
                    Text(latestLabel(latest)).tag(ReleaseVersion?.none)
                    ForEach(catalog?.others[engine.selectedChannel] ?? []) { version in
                        Text(version.menuTitle).tag(Optional(version))
                    }
                }
            } label: {
                HStack {
                    Text(engine.selectedVersion?.title ?? latestLabel(latest))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    if engine.loadingCatalog == source {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .fieldBackground()
                .contentShape(Rectangle())
            }
            // A release's title can carry the maintainers' warning ("DO NOT USE").
            if let shown, shown.hasRemark {
                Label(shown.menuTitle, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = engine.catalogErrors[source] {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Couldn't load the other versions: %@", error))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L("Try again")) {
                        Task { await engine.loadReleaseCatalog(for: source, force: true) }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                    .buttonStyle(.plain)
                }
            }
        }
        // Fetched when the section opens, and again for another build.
        .task(id: source) { await engine.loadReleaseCatalog(for: source) }
    }

    /// "Latest", naming the release it stands for when that has a version.
    private func latestLabel(_ latest: ReleaseVersion?) -> String {
        // The nightly tag names no version, so it isn't repeated.
        guard let latest, latest.tag != "nightly" else { return L("Latest") }
        return L("Latest (%@)", latest.title)
    }

    /// The optional pairing-file import (iOS 27 and above).
    private var pairingFileOption: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L("Pairing file"), systemImage: "lock.doc.fill")
                .font(.subheadline.weight(.semibold))
            Text(L("(Optional)"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            pairingImportButton
            pairingDocsLink
        }
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

    /// Shown while the tunnel is off. Names LocalDevVPN, though any loopback VPN
    /// works.
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

    /// What the install surface holds as a card; `installSurface` draws the
    /// card itself.
    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text(progressTitle)
                    .font(.headline)
                    .contentTransition(.opacity)
                Spacer(minLength: 4)
                Text("\(Int(engine.overallProgress * 100))%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(progressTint)
                    .contentTransition(.numericText(value: engine.overallProgress))
                    .animation(.smooth(duration: 0.3), value: engine.overallProgress)
                stepsDisclosure
                // Only a run in flight can be cancelled.
                if engine.isRunning {
                    cancelButton
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }

            InstallProgressBar(progress: engine.overallProgress,
                               tint: progressTint,
                               gradient: progressGradient,
                               animating: engine.isRunning && !engine.finished && !runFailed)

            stepSection
        }
    }

    private var progressTitle: String {
        if engine.finished { return L("Installed") }
        return engine.isCancelling ? L("Cancelling") : L("Installing")
    }

    /// The X in the card's corner, which stops the run after asking. It dims
    /// once the run is stopping, which waits for the step in flight.
    private var cancelButton: some View {
        Button {
            confirmingCancel = true
        } label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(7)
                .background(Circle().fill(.white.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(engine.isCancelling)
        .opacity(engine.isCancelling ? 0.4 : 1)
        .accessibilityLabel(L("Cancel"))
    }

    /// Progress color: red on failure, green when finished, brand blue while
    /// running.
    private var progressTint: Color {
        if runFailed { return .red }
        return engine.finished ? .green : Theme.accent
    }

    private var progressGradient: LinearGradient {
        if runFailed { return Theme.gradient(.red) }
        return engine.finished ? Theme.gradient(.green) : Theme.brand
    }

    /// Chevron that expands/collapses the step timeline. Placed in the header so
    /// it stays put in both states.
    private var stepsDisclosure: some View {
        Button {
            stepsExpanded.toggle()
        } label: {
            disclosureChevron(expanded: stepsExpanded)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stepsExpanded ? L("Show fewer steps") : L("Show all steps"))
    }

    /// Circled chevron that flips to point up while its section is open.
    private func disclosureChevron(expanded: Bool) -> some View {
        Image(systemName: "chevron.down")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(expanded ? 180 : 0))
            .padding(7)
            .background(Circle().fill(.white.opacity(0.08)))
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

    /// Collapsed timeline: the current step, pushed out when the next one starts.
    /// Tap to expand.
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
        // Clip only vertically (for the push transition); the active node's
        // halo grows past the row's leading edge and must not be cut.
        .padding(.horizontal, 10)
        .clipped()
        .padding(.horizontal, -10)
        .contentShape(Rectangle())
        .onTapGesture { stepsExpanded = true }
        .animation(.smooth(duration: 0.35), value: step)
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

// MARK: - Popup

/// One of the Install tab's popups, which `RootView` stacks over the whole app:
/// what a waiting step needs (Wi-Fi, the tunnel, the pairing code), a guide for
/// a run that couldn't start, or how the run ended. See `Engine.Popup`.
struct InstallPopup: View {
    let popup: Engine.Popup

    @EnvironmentObject private var engine: Engine
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    /// Shared with the Certificates page; revoke-and-retry runs through it.
    @EnvironmentObject private var certManager: CertManager
    @Environment(\.openURL) private var openURL
    /// Shows the dialog for choosing which certificate to revoke.
    @State private var showRevokeChooser = false
    /// Shows the Report a problem sheet from the error popup.
    @State private var showReport = false

    var body: some View {
        switch popup {
        case .pairingCode(let pin):
            PairingCodePopup(pin: pin, caption: L("Type this into the prompt in Settings."),
                             onClose: close)
        case .certConflict:
            certConflictPopup
        case .guide(let guide):
            guidePopup(guide)
        case .error(let message, let stoppedRun):
            PopupCard(title: Self.errorTitle(stoppedRun: stoppedRun),
                      systemImage: "exclamationmark.triangle.fill",
                      tint: .red,
                      onClose: close) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(message)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { errorButtons(message) }
                        VStack(alignment: .leading, spacing: 10) { errorButtons(message) }
                    }
                }
            }
            .sheet(isPresented: $showReport) { ReportProblemView() }
        case .success(let name, let leads):
            PopupCard(title: L("Installed"), systemImage: "checkmark.seal.fill", tint: .green,
                      onClose: close) {
                Text(leads ? L("%@ is installed. Finish the trust step below to open it.", name)
                           : L("%@ is installed. Finish the trust step above to open it.", name))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .liveContainerImport:
            guidePopup(Guides.liveContainerImport)
        case .appIDCost(let cost):
            appIDCostPopup(cost)
        case .link(let link):
            linkPopup(link)
        }
    }

    private func close() { engine.closePopup(popup) }

    /// The error popup's buttons. Copy logs shows only when nothing explains
    /// the fix: no guide or revoke-and-retry popup beside it, and a message
    /// that doesn't say what to do itself.
    @ViewBuilder
    private func errorButtons(_ message: String) -> some View {
        Button { showReport = true } label: {
            Label(L("Report this problem"), systemImage: "exclamationmark.bubble")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(.red)
        if engine.guide == nil, !engine.certConflict, !ErrorHelp.isExplained(message) {
            CopyLogsButton()
        }
    }

    /// The error popup's title, which also titles the group it's in.
    static func errorTitle(stoppedRun: Bool) -> String {
        stoppedRun ? L("Install stopped") : L("Something went wrong")
    }

    // MARK: Guides

    /// A guide's steps, and its link out when it has one.
    private func guidePopup(_ guide: Guide) -> some View {
        PopupCard(title: guide.title, systemImage: guide.systemImage, tint: Theme.accent,
                  onClose: close) {
            VStack(alignment: .leading, spacing: 14) {
                NumberedSteps(steps: guide.steps)
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

    // MARK: App ID cost

    /// What signing an imported IPA costs in App IDs and how many are left,
    /// before the run signs it. With too few left, it can only be cancelled.
    private func appIDCostPopup(_ cost: AppIDCost) -> some View {
        PopupCard(title: L("App IDs for this app"), systemImage: "number.square.fill",
                  tint: cost.isAffordable ? Theme.accent : .orange,
                  onClose: close) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    appIDTile(L("Cost"), "\(cost.cost)", tint: cost.isAffordable ? .primary : .orange)
                    appIDTile(L("Left now"), cost.available.map { "\($0)" } ?? "–", tint: .primary)
                    appIDTile(L("Left after"),
                              cost.isAffordable ? cost.remainingAfter.map { "\($0)" } ?? "–" : "–",
                              tint: .primary)
                }
                Text(appIDCostMessage(cost))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !cost.newIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("New App IDs"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(cost.newIDs, id: \.self) { id in
                            Text(id)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                VStack(spacing: 10) {
                    if cost.isAffordable {
                        Button { engine.answerAppIDCost(true) } label: {
                            Label(L("Install"), systemImage: "arrow.down.app.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    Button(role: .cancel) { engine.answerAppIDCost(false) } label: {
                        Text(L("Cancel"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(cost.isAffordable ? Color.secondary : .orange)
                }
            }
        }
    }

    /// One number in the App ID cost popup, with what it counts.
    private func appIDTile(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(0.06)))
    }

    private func appIDCostMessage(_ cost: AppIDCost) -> String {
        guard cost.isAffordable else {
            var text = L("This Apple ID doesn't have enough App IDs left: this app needs %d, and %d are left. Each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.",
                         cost.cost, cost.available ?? 0)
            if let next = cost.nextExpiry {
                let when = next.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)
                    .locale(Localizer.locale))
                text += " " + L("The next one frees up on %@.", when)
            }
            return text
        }
        if cost.cost == 0 {
            return L("Your Apple ID already has every App ID this app needs, so installing it uses none.")
        }
        let base = L("Signing registers one App ID for the app, and its extensions share it. It counts for 7 days.")
        guard let limit = cost.limit else { return base }
        return base + " " + L("This Apple ID can register %d a week.", limit)
    }

    // MARK: Links

    /// A `sideinstaller://` link, with what it would do, waiting for a yes.
    @ViewBuilder
    private func linkPopup(_ link: DeepLink) -> some View {
        switch link {
        case .install(let url):
            PopupCard(title: L("Install from a link?"), systemImage: "link.circle.fill",
                      tint: Theme.accent, onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(url.host ?? url.absoluteString)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(url.absoluteString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    Text(installLinkMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    linkButtons(L("Download and install"), systemImage: "arrow.down.app.fill")
                }
            }
        case .pairingFile(let file):
            PopupCard(title: file.fromSideStore ? L("Use SideStore's pairing file?")
                                                : L("Import this pairing file?"),
                      systemImage: "lock.doc.fill", tint: Theme.accent, onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    if let udid = file.kind.udid {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("UDID")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(udid)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Text(pairingLinkMessage(file))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    linkButtons(L("Import"), systemImage: "square.and.arrow.down.fill")
                }
            }
        case .certificate:
            // Only an unasked-for one asks here; SideStore's reply is imported
            // straight away.
            PopupCard(title: L("Sign with this certificate?"), systemImage: "checkmark.seal.fill",
                      tint: Theme.accent, onClose: close) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("A link sent SideInstaller a signing certificate. Only use it if you asked for one: SideInstaller will sign apps with it from now on, in place of its own. It's used only if it's one of your Apple ID's certificates."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    linkButtons(L("Use it"), systemImage: "checkmark.seal.fill")
                }
            }
        }
    }

    /// The link popup's go-ahead and Cancel.
    private func linkButtons(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Button { engine.answerLink(true) } label: {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(PrimaryButtonStyle())
            Button(role: .cancel) { engine.answerLink(false) } label: {
                Text(L("Cancel"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }

    private var installLinkMessage: String {
        let base = L("SideInstaller will download this .ipa, then sign it with your Apple ID and install it. Only go ahead if you trust where the link came from.")
        guard let current = engine.customIPAName else { return base }
        return base + " " + L("It replaces %@, the custom .ipa you have now.", current)
    }

    private func pairingLinkMessage(_ file: LinkedPairingFile) -> String {
        let base = file.fromSideStore
            ? L("SideStore sent back the pairing file it has. SideInstaller will connect to this iPhone with it.")
            : L("A link sent SideInstaller a pairing file. Only import it if you asked for one: SideInstaller will connect to this iPhone with it.")
        if let current = engine.importedPairingName {
            return base + " " + L("It replaces %@.", current)
        }
        return engine.hasPairingFile ? base + " " + L("It replaces the pairing file in use now.") : base
    }

    // MARK: Certificate conflict (Apple error 7460)

    /// Shown on error 7460. With SideStore on the iPhone, the first button
    /// asks it for its certificate, signs with that and retries the install.
    /// The other loads the certificates; the dialog asks which one to revoke,
    /// then retries the install.
    private var certConflictPopup: some View {
        let sideStoreInstalled = engine.sideStoreInstalled
        return PopupCard(title: L("A certificate already exists"),
                         systemImage: "exclamationmark.shield.fill",
                         tint: .orange,
                         onClose: close) {
            VStack(alignment: .leading, spacing: 14) {
                Text(sideStoreInstalled
                     ? L("Apple won't issue a second signing certificate for this Apple ID. If SideStore made the one it has, SideInstaller can sign with that one too, and nothing is revoked. Revoking it lets the install continue as well — but it can't be undone.")
                     : L("Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if sideStoreInstalled {
                    Button {
                        certManager.requestSideStoreCertificate(retryInstall: true)
                    } label: {
                        HStack(spacing: 8) {
                            if certManager.isImporting {
                                ProgressView().tint(.white)
                                Text(L("Checking the certificate"))
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                                Text(L("Use SideStore's certificate"))
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(certManager.isBusy)
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
                .disabled(certManager.isBusy)
                // A failed load, revoke or import shows as the Certificates
                // popup, under this one.
            }
            .animation(.smooth(duration: 0.3), value: certManager.isWorking)
            .animation(.smooth(duration: 0.3), value: certManager.isImporting)
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

// MARK: - Install surface

/// A button that draws nothing of its own and reports its press, for a surface
/// drawn outside the button to show.
private struct PressReportingButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in isPressed = pressed }
    }
}

private extension AnyTransition {
    /// Content changing places inside a surface that is changing shape: the old
    /// is all but gone before the new comes in, so the two don't show through
    /// each other.
    static var surfaceSwap: AnyTransition {
        .asymmetric(insertion: .opacity.animation(.easeIn(duration: 0.28).delay(0.1)),
                    removal: .opacity.animation(.easeOut(duration: 0.15)))
    }

    /// A fade that's over before what's below has moved up into its place.
    static var quickFade: AnyTransition {
        .opacity.animation(.easeOut(duration: 0.12))
    }

    /// The Install button leaving as a run starts: up and under the progress
    /// card above it.
    static var tuckUnder: AnyTransition {
        .opacity
            .combined(with: .scale(scale: 0.94, anchor: .top))
            .combined(with: .offset(y: -28))
            // Gone before what's below has moved up into its place.
            .animation(.easeOut(duration: 0.22))
    }
}

// MARK: - Progress bar

/// Install progress bar: a gradient fill with a moving sheen and a glowing head
/// while running. Both effects are driven by `TimelineView` time rather than a
/// repeating animation, so progress changes don't disrupt them.
private struct InstallProgressBar: View {
    let progress: Double
    let tint: Color
    let gradient: LinearGradient
    /// False once the run has finished or stopped, leaving the bar at rest.
    let animating: Bool

    /// Width of the moving highlight.
    private let sheenWidth: CGFloat = 96
    /// Seconds per sheen pass.
    private let sheenPeriod: Double = 1.9

    var body: some View {
        GeometryReader { geo in
            let full = geo.size.width
            // Minimum width so the bar is visible at 0%.
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
                // Overlays, not siblings: the sheen can be wider than the fill,
                // and as a sibling it would stretch the fill past the track.
                .overlay(alignment: .leading) { if animating { sheen(at: t, across: full) } }
                .overlay(alignment: .trailing) { if animating { head(at: t) } }
                // Keeps the sheen's blend inside the fill instead of over the card.
                .compositingGroup()
                .clipShape(Capsule())
        }
        .shadow(color: tint.opacity(0.5), radius: 9)
    }

    /// Highlight that moves across the full track width, so its speed doesn't
    /// depend on progress. The capsule clips it to the filled part.
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

/// Status circle for a step, used by both timelines. The active step gets a
/// pulsing halo.
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

    /// Driven by clock time rather than a repeating animation.
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
        // Nothing of its own: the card shows through.
        default:       return .clear
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
    /// The `.ipa` type exported in Info.plist. Without that declaration the
    /// picker shows .ipa files but won't let them be selected.
    static let ipa: UTType = UTType(filenameExtension: "ipa") ?? .data

    /// The `.mobiledevicepairing` type written by jitterbugpair, declared the
    /// same way.
    static let mobileDevicePairing: UTType = UTType(filenameExtension: "mobiledevicepairing") ?? .data

    /// What the pairing-file picker accepts: jitterbugpair's extension, and the
    /// plain `.plist` pymobiledevice3 and idevicepair write.
    static var pairingFileTypes: [UTType] { [mobileDevicePairing, .propertyList, .xml] }
}

/// `UIDocumentPickerViewController` wrapped for SwiftUI and shown as a sheet
/// (as Feather does). Used instead of `.fileImporter`, whose rows can't be
/// tapped on iOS 27.
///
/// `asCopy: true` makes iOS hand over a temporary copy of the file instead of a
/// security-scoped URL to the original.
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
