import SwiftUI
import MapKit
import CoreLocation

// MARK: - Developer disk image

/// The three files of Apple's personalized developer disk image and where they
/// are stored. Mounting the image enables DVT services such as location
/// simulation. Downloaded on first use rather than bundled.
///
/// Source: doronz88/DeveloperDiskImage (the same mirror StikDebug uses). These
/// are Apple's unmodified files; the device personalizes the image against its
/// chip ID at mount time.
enum DeveloperDiskImage {

    private static let baseURL =
        "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized"

    /// Files to download (same name remotely and locally).
    private static let files = [
        "BuildManifest.plist",
        "Image.dmg",
        "Image.dmg.trustcache",
    ]

    static var directory: URL {
        URL.documentsDirectory.appendingPathComponent("DDI", isDirectory: true)
    }

    static var imagePath: String { directory.appendingPathComponent("Image.dmg").path }
    static var trustcachePath: String { directory.appendingPathComponent("Image.dmg.trustcache").path }
    static var manifestPath: String { directory.appendingPathComponent("BuildManifest.plist").path }

    /// True when all three files are on disk and non-empty.
    static var isDownloaded: Bool {
        files.allSatisfy { name in
            let path = directory.appendingPathComponent(name).path
            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            return (attributes?[.size] as? Int ?? 0) > 0
        }
    }

    /// Fetch whichever of the three files are missing, reporting 0…1 across the
    /// whole set rather than per file.
    static func downloadMissing(progress: @escaping (Double) -> Void) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let missing = files.filter { name in
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
        }
        guard !missing.isEmpty else { progress(1); return }

        for (index, name) in missing.enumerated() {
            progress(Double(index) / Double(missing.count))
            guard let url = URL(string: "\(baseURL)/\(name)") else {
                throw EngineError.message(L("Couldn't build the download URL for %@.", name))
            }
            let (tmp, response) = try await URLSession.shared.download(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw EngineError.message(L("Downloading %@ failed (HTTP %d).", name, code))
            }
            let destination = directory.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: tmp, to: destination)
            Engine.shared.log("DDI: downloaded \(name).")
        }
        progress(1)
    }
}

// MARK: - Manager

/// Drives the Location page: fetch and mount the developer disk image, then
/// hold a DVT session open and keep pushing the chosen coordinate at it. Only
/// UI state lives here — the shared `Engine` owns the device connection.
@MainActor
final class LocationManager: ObservableObject {

    /// Setup progress (not shown in the UI). Resets to `.notReady` on any
    /// session error, since re-pairing tears down the device link.
    enum Stage: Equatable {
        case notReady
        case downloading
        case mounting
        case ready
    }

    @Published private(set) var stage: Stage = .notReady
    @Published private(set) var isBusy = false
    /// The coordinate the device is currently being told it is at.
    @Published private(set) var simulated: CLLocationCoordinate2D?
    @Published var lastError: String?
    @Published var lastSuccess: String?

    private var engine: Engine { Engine.shared }
    /// Silent audio, so backgrounding the app doesn't close the DVT session.
    private let keepAlive = KeepAlive()
    /// iOS drops a simulated location that isn't refreshed, so it's re-sent
    /// every 4s (as StikDebug does).
    private var resendTimer: Timer?
    private static let resendInterval: TimeInterval = 4

    var isSimulating: Bool { simulated != nil }

    // MARK: Setup

    /// Runs setup in the background: downloads the disk image, mounts it if the
    /// device has none, and opens the DVT session.
    ///
    /// Called when the page opens. Failures (usually no tunnel yet) are only
    /// logged; `simulate` repeats the setup and shows errors to the user.
    ///
    /// Uses its own task, so leaving the page doesn't cancel it.
    func prepareQuietly() {
        guard stage != .ready, !isBusy else { return }
        isBusy = true
        Task {
            do { try await ensureReady() }
            catch is CancellationError { }
            catch { engine.log("Location: not ready yet (\(message(error)))") }
            isBusy = false
        }
    }

    /// Download the image if it's missing, mount it if the device has none, and
    /// open the location session. Every step is a no-op once it has run, so this
    /// is cheap to call again.
    private func ensureReady() async throws {
        guard stage != .ready else { return }
        if !DeveloperDiskImage.isDownloaded {
            stage = .downloading
            try await DeveloperDiskImage.downloadMissing { _ in }
        }
        stage = .mounting
        // Mount progress goes to the activity log only.
        var lastLogged = -1
        _ = try await engine.prepareLocationSimulation(
            imagePath: DeveloperDiskImage.imagePath,
            trustcachePath: DeveloperDiskImage.trustcachePath,
            manifestPath: DeveloperDiskImage.manifestPath) { fraction in
                let step = Int(fraction * 4) * 25
                guard step > lastLogged else { return }
                lastLogged = step
                Engine.shared.log("DDI mount: \(step)%")
            }
        stage = .ready
    }

    // MARK: Simulating

    /// Sets the device's location to `coordinate` and keeps re-sending it.
    ///
    /// Runs setup first if it hasn't finished (often the tunnel wasn't up when
    /// the page opened). Setup errors are shown to the user here.
    func simulate(_ coordinate: CLLocationCoordinate2D) {
        guard !isBusy else { return }
        guard (-90...90).contains(coordinate.latitude),
              (-180...180).contains(coordinate.longitude) else {
            lastError = L("That isn't a valid coordinate.")
            return
        }
        isBusy = true
        lastError = nil
        lastSuccess = nil
        Task {
            do {
                try await ensureReady()
                try await engine.simulateLocation(latitude: coordinate.latitude,
                                                  longitude: coordinate.longitude)
                simulated = coordinate
                keepAlive.startAudio()
                startResending()
                lastSuccess = L("Location set to %@.", Self.format(coordinate))
                engine.log("Location: simulating \(Self.format(coordinate)).")
            } catch {
                // A dropped session can't be re-used; setup has to run again.
                stage = .notReady
                simulated = nil
                stopResending()
                lastError = message(error)
            }
            isBusy = false
        }
    }

    /// Hand the device its real location back.
    func stop() {
        guard !isBusy else { return }
        isBusy = true
        lastError = nil
        lastSuccess = nil
        stopResending()
        Task {
            do {
                try await engine.stopSimulatingLocation()
                lastSuccess = L("Location reset. The device is using its own again.")
            } catch {
                lastError = message(error)
            }
            simulated = nil
            stage = .notReady
            keepAlive.stopAll()
            isBusy = false
        }
    }

    /// Re-sends `simulated` on a timer. Individual send failures are ignored
    /// (the next tick usually works), but a closed session is reported, since
    /// anything that rebuilds the tunnel (an install, a re-pair) closes it.
    private func startResending() {
        stopResending()
        // Capture `self` weakly in the timer closure: the timer retains the
        // closure until invalidated, so a strong capture would keep the manager
        // alive.
        resendTimer = Timer.scheduledTimer(withTimeInterval: Self.resendInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let simulated = self.simulated else { return }
                guard self.engine.connection.isSimulatingLocation else {
                    self.sessionClosed()
                    return
                }
                try? await self.engine.simulateLocation(latitude: simulated.latitude,
                                                        longitude: simulated.longitude)
            }
        }
    }

    /// The session went away underneath us; setup has to run again.
    private func sessionClosed() {
        stopResending()
        simulated = nil
        stage = .notReady
        keepAlive.stopAll()
        lastSuccess = nil
        lastError = L("Location session closed — set it up again.")
    }

    private func stopResending() {
        resendTimer?.invalidate()
        resendTimer = nil
    }

    // MARK: Helpers

    static func format(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    private func message(_ error: Error) -> String {
        if let engineError = error as? EngineError { return engineError.localizedDescription }
        return error.localizedDescription
    }
}

// MARK: - View

/// The Location page: a map to pick a point, and the controls that push it to
/// the device. Pushed from Tools, whose `NavigationStack` this relies on.
struct LocationView: View {
    @EnvironmentObject private var engine: Engine
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var manager: LocationManager

    @State private var showSettings = false
    /// Where the map is looking, and the point under the crosshair.
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                           span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)))
    @State private var target = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    @State private var query = ""
    @State private var isSearching = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header.cascadeItem(0)
                if !engine.vpnConnected {
                    vpnNote.cascadeItem(1)
                }
                mapCard.cascadeItem(2)
                if let error = manager.lastError {
                    errorCallout(error).transition(.cardAppear)
                }
                if let success = manager.lastSuccess {
                    successCallout(success).transition(.cardAppear)
                }
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: manager.stage)
            .animation(.smooth(duration: 0.35), value: manager.lastError)
            .animation(.smooth(duration: 0.35), value: manager.lastSuccess)
            .animation(.smooth(duration: 0.3), value: manager.isBusy)
            .animation(.smooth(duration: 0.3), value: engine.vpnConnected)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        // Start setup in the background so it's ready when the user picks a
        // place. See `prepareQuietly`.
        .onAppear { manager.prepareQuietly() }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "location.fill", image: "LocationLogo", title: L("Location spoofing"),
                    animateIcon: manager.isSimulating) {
            statusPill
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        if let simulated = manager.simulated {
            StatusPill(text: LocationManager.format(simulated),
                       systemImage: "location.fill", color: .green)
        } else {
            StatusPill(text: L("Not simulating"), systemImage: "location.slash",
                       color: .orange, glass: true)
        }
    }

    private var vpnNote: some View {
        CalloutCard(tint: .red) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(.red)
                Text(L("Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Map

    private var mapCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(L("Pick a place"), systemImage: "mappin.and.ellipse")

                searchField

                ZStack {
                    Map(position: $camera) {
                        if let simulated = manager.simulated {
                            Marker(L("Simulated"), systemImage: "location.fill",
                                   coordinate: simulated)
                                .tint(Theme.accent)
                        }
                    }
                    .mapStyle(.standard(elevation: .flat))
                    .onMapCameraChange(frequency: .continuous) { context in
                        target = context.region.center
                    }
                    // The pin marks the map's center, so panning moves it. A
                    // draggable annotation would conflict with the scroll view.
                    crosshair
                        .allowsHitTesting(false)
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack {
                    Label(LocationManager.format(target), systemImage: "scope")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }

                // On first use, the spinner also covers disk image setup.
                Button { manager.simulate(target) } label: {
                    HStack(spacing: 10) {
                        if manager.isBusy {
                            ProgressView().tint(.white)
                            Text(L("Setting"))
                        } else {
                            Image(systemName: "location.fill")
                            Text(L("Set location"))
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(manager.isBusy || !engine.vpnConnected || engine.isRunning)

                if manager.isSimulating {
                    Button { manager.stop() } label: {
                        Label(L("Reset to real location"), systemImage: "location.slash")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .tint(.orange)
                    .disabled(manager.isBusy)
                }
            }
        }
    }

    private var crosshair: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 30))
            .foregroundStyle(.white, Theme.accent)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            TextField(L("Search for a place"), text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { search() }
                .fieldBackground()
            Button { search() } label: {
                if isSearching {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "magnifyingglass")
                }
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
        }
    }

    /// Move the map to the first match, leaving the coordinate to the crosshair.
    private func search() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isSearching else { return }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        Task {
            defer { isSearching = false }
            guard let response = try? await MKLocalSearch(request: request).start(),
                  let first = response.mapItems.first else {
                manager.lastError = L("Nothing found for “%@”.", text)
                return
            }
            manager.lastError = nil
            // `location` replaces the deprecated `placemark` on iOS 26+; older
            // iOS still uses `placemark`.
            let coordinate: CLLocationCoordinate2D
            if #available(iOS 26.0, *) {
                coordinate = first.location.coordinate
            } else {
                coordinate = first.placemark.coordinate
            }
            withAnimation(.smooth(duration: 0.4)) {
                camera = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            }
            target = coordinate
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
                    Text(L("Something went wrong"))
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

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.brand)
        }
    }
}
