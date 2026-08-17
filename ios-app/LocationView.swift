import SwiftUI
import MapKit
import CoreLocation

// MARK: - Developer disk image

/// The three files Apple's personalized developer disk image is made of, and
/// where they live on disk. Mounting one is what makes the DVT services — the
/// location simulation among them — reachable at all, so this is downloaded on
/// first use rather than shipped in the app.
///
/// The files come from doronz88/DeveloperDiskImage, the same public mirror
/// StikDebug pulls them from. They are Apple's, unmodified: the device
/// personalizes and signs its own copy at mount time against its chip id, so a
/// mirror can't substitute an image the device would accept.
enum DeveloperDiskImage {

    private static let baseURL =
        "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized"

    /// One downloaded file: its remote name and its local file name.
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

    /// How far along setup is. Internal only — the page never shows it. The
    /// device link is torn down by anything that re-pairs, so this drops back to
    /// `.notReady` on any session error.
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
    /// iOS lets a simulated location lapse; StikDebug re-sends every 4s, so do
    /// the same rather than discovering the interval the hard way.
    private var resendTimer: Timer?
    private static let resendInterval: TimeInterval = 4

    var isSimulating: Bool { simulated != nil }

    // MARK: Setup

    /// Get everything in place without saying so: fetch the disk image, mount it
    /// unless the device already has one, and open the DVT session. None of that
    /// is a decision the user can usefully make, so the page never mentions it —
    /// the only visible consequence is that Set location works.
    ///
    /// Called when the page opens, where it does as much as it can and gives up
    /// quietly on anything it can't (no tunnel yet, most often). Failures are
    /// logged, not shown: the page hasn't been asked to do anything yet, so
    /// there is nothing to report. `simulate` runs the same work when the user
    /// does ask, and surfaces errors then.
    ///
    /// Runs as its own task rather than the view's, so walking back to Tools
    /// mid-download doesn't cancel it.
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
        // Progress goes to the activity log rather than the page — a mount the
        // user was never told about shouldn't grow a progress bar.
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

    /// Tell the device it is at `coordinate`, and keep telling it.
    ///
    /// Does the setup itself if the quiet pass hasn't finished — the tunnel is
    /// usually the thing that wasn't up yet when the page opened. This is where
    /// setup failures finally get shown, since now the user has asked for
    /// something and deserves to know why it didn't happen.
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

    /// Re-send whatever `simulated` holds on a timer. A failed send is left
    /// alone — the next tick usually lands, and an alert every 4s would be
    /// unreadable — but a session that's gone is reported, since anything that
    /// rebuilds the tunnel (an install, a re-pair) closes this one and the page
    /// would otherwise keep claiming the location is still being held.
    private func startResending() {
        stopResending()
        resendTimer = Timer.scheduledTimer(withTimeInterval: Self.resendInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
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
    /// Declared so every label on this screen redraws when the language changes.
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
        // Fetch the disk image, mount it and open the session in the background,
        // so that by the time the user picks a place there is nothing to wait
        // for. Says nothing either way — see `prepareQuietly`.
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
                    // The pin is the map's centre, so panning aims it. A dropped
                    // annotation would fight the scroll view for the same drag.
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

                // The spinner covers the setup too, on the first tap of a fresh
                // install: the user asked for a location, not for a disk image,
                // so the wait is presented as one thing.
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
            // `placemark` is deprecated as of iOS 26; `location` is its
            // replacement for the coordinate, which is all this needs — and it
            // only exists from 26, so older releases keep the deprecated one.
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
