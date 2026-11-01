import SwiftUI
import MapKit
import CoreLocation
import UniformTypeIdentifiers

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

// MARK: - Saved places

/// A spot saved on the Location page so it can be set again in one tap.
/// Stored as JSON in UserDefaults, as StikDebug stores its bookmarks.
struct SavedPlace: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - GPX routes

extension UTType {
    /// GPX, declared in Info.plist under the identifier other apps use for it.
    /// Without the declaration the picker shows .gpx files but won't let them
    /// be selected.
    static let gpx = UTType(importedAs: "com.topografix.gpx", conformingTo: .xml)
}

/// A route read from a GPX file.
///
/// StikDebug takes every `trkpt`, `rtept` and `wpt` in file order. Here a
/// file's track wins, then its route, then its waypoints, so the points of
/// interest a track file often carries don't end up in the path.
struct GPXRoute {
    let name: String
    /// The points in file order, invalid ones dropped.
    let points: [CLLocationCoordinate2D]
    /// When each point was recorded, if every one has a `<time>` and they never
    /// go backwards. Playing "as recorded" follows these.
    let times: [Date]?
    /// Length along the points, in meters.
    let distance: CLLocationDistance

    /// One spot rather than a path (a lone waypoint, or a track that never
    /// moved). The page moves the map there instead of keeping a route, as
    /// StikDebug does with a single coordinate.
    var isSinglePlace: Bool { distance == 0 }

    var recordedDuration: TimeInterval? {
        guard let times, let first = times.first, let last = times.last else { return nil }
        return last.timeIntervalSince(first)
    }

    /// The speeds this route can play at: "as recorded" needs times.
    var speeds: [RouteSpeed] {
        RouteSpeed.allCases.filter { $0 != .recorded || times != nil }
    }

    /// How long playing at `speed` takes, without building the timeline.
    func duration(at speed: RouteSpeed) -> TimeInterval {
        if speed == .recorded, let recordedDuration { return recordedDuration }
        return distance / (speed.metersPerSecond ?? RouteSpeed.fallbackMetersPerSecond)
    }

    init(contentsOf url: URL) throws {
        let fileName = url.lastPathComponent
        let data = try Data(contentsOf: url)
        let reader = GPXReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        guard parser.parse() else {
            throw EngineError.message(L("Couldn't read %@ as a GPX file.", fileName))
        }
        let found = [reader.trackPoints, reader.routePoints, reader.waypoints]
            .first { !$0.isEmpty } ?? []
        guard !found.isEmpty else {
            throw EngineError.message(L("%@ has no track, route or waypoints in it.", fileName))
        }

        name = url.deletingPathExtension().lastPathComponent
        points = found.map(\.coordinate)
        distance = Self.distanceAlong(points)
        let times = found.compactMap(\.time)
        let inOrder = zip(times, times.dropFirst()).allSatisfy { $0 <= $1 }
        if times.count == found.count, inOrder, let first = times.first, let last = times.last,
           last > first {
            self.times = times
        } else {
            self.times = nil
        }
    }

    private static func distanceAlong(_ points: [CLLocationCoordinate2D]) -> CLLocationDistance {
        zip(points, points.dropFirst()).reduce(0) { total, pair in
            total + CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude))
        }
    }
}

/// Collects a GPX file's points, each with its `<time>` if it has one.
private final class GPXReader: NSObject, XMLParserDelegate {
    struct Point {
        var coordinate: CLLocationCoordinate2D
        var time: Date?
    }

    private(set) var trackPoints: [Point] = []
    private(set) var routePoints: [Point] = []
    private(set) var waypoints: [Point] = []

    /// The point being read and the element it came from.
    private var current: (element: String, point: Point)?
    private var timeText: String?

    // Not `ISO8601DateFormatter`, which took 4 of the 5 seconds a
    // 50,000-point track needed to load.
    private let timeStyle = Date.ISO8601FormatStyle()
    private let fractionalTimeStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// Element names without a namespace prefix (`gpx:trkpt` → `trkpt`).
    private func localName(_ name: String) -> String {
        String(name.split(separator: ":").last ?? Substring(name)).lowercased()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        let name = localName(elementName)
        switch name {
        case "trkpt", "rtept", "wpt":
            guard let latitude = Double(attributes["lat"] ?? ""),
                  let longitude = Double(attributes["lon"] ?? "") else { return }
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return }
            current = (name, Point(coordinate: coordinate))
        case "time" where current != nil:
            timeText = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        timeText? += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        switch localName(elementName) {
        case "time":
            if let text = timeText?.trimmingCharacters(in: .whitespacesAndNewlines) {
                current?.point.time = (try? timeStyle.parse(text))
                    ?? (try? fractionalTimeStyle.parse(text))
            }
            timeText = nil
        case "trkpt":
            if let current { trackPoints.append(current.point) }
            current = nil
        case "rtept":
            if let current { routePoints.append(current.point) }
            current = nil
        case "wpt":
            if let current { waypoints.append(current.point) }
            current = nil
        default:
            break
        }
    }
}

/// How fast a route plays.
enum RouteSpeed: String, CaseIterable, Identifiable {
    /// The file's own timestamps.
    case recorded
    case walk
    case cycle
    case drive

    var id: Self { self }

    /// Walking pace (about 5 km/h), also used if `.recorded` is asked of a
    /// route without times, which the page doesn't offer.
    static let fallbackMetersPerSecond: CLLocationSpeed = 1.4

    /// Nil for `.recorded`, which follows the file's times.
    var metersPerSecond: CLLocationSpeed? {
        switch self {
        case .recorded: return nil
        case .walk:     return Self.fallbackMetersPerSecond
        case .cycle:    return 5.5
        // StikDebug's speed for imported routes (about 48 km/h).
        case .drive:    return 13.4
        }
    }

    var title: String {
        switch self {
        case .recorded: return L("As recorded")
        case .walk:     return L("Walk")
        case .cycle:    return L("Cycle")
        case .drive:    return L("Drive")
        }
    }
}

/// When playback reaches each point of a route, in seconds from the start.
///
/// StikDebug cuts the route into half-second steps up front and sleeps between
/// them, which drifts by however long each send takes. Here each tick asks
/// where the route should be at the time that has actually passed.
struct RouteTimeline {
    let points: [CLLocationCoordinate2D]
    /// `offsets[i]` is when `points[i]` is reached; never decreasing.
    let offsets: [TimeInterval]

    var duration: TimeInterval { offsets.last ?? 0 }

    init(route: GPXRoute, speed: RouteSpeed) {
        points = route.points
        if let times = route.times, let first = times.first, speed == .recorded {
            offsets = times.map { $0.timeIntervalSince(first) }
            return
        }
        let metersPerSecond = speed.metersPerSecond ?? RouteSpeed.fallbackMetersPerSecond
        offsets = Self.offsets(along: route.points) { _ in metersPerSecond }
    }

    /// A route that goes at `metersPerSecond[i]` from `points[i]` to
    /// `points[i + 1]`, as a planned route keeps to each road's limit.
    init(points: [CLLocationCoordinate2D], metersPerSecond: [CLLocationSpeed]) {
        self.points = points
        offsets = Self.offsets(along: points) { segment in
            metersPerSecond.indices.contains(segment) ? metersPerSecond[segment]
                                                      : RouteSpeed.fallbackMetersPerSecond
        }
    }

    private static func offsets(along points: [CLLocationCoordinate2D],
                                speed: (Int) -> CLLocationSpeed) -> [TimeInterval] {
        var elapsed: TimeInterval = 0
        var offsets: [TimeInterval] = [0]
        for (segment, (start, end)) in zip(points, points.dropFirst()).enumerated() {
            let meters = CLLocation(latitude: start.latitude, longitude: start.longitude)
                .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
            elapsed += meters / max(speed(segment), 0.1)
            offsets.append(elapsed)
        }
        return offsets
    }

    /// The segment (from `points[i]` to `points[i + 1]`) the route is on
    /// `elapsed` seconds in.
    func segment(at elapsed: TimeInterval) -> Int {
        max(0, firstReached(after: elapsed) - 1)
    }

    /// The first point reached after `elapsed`, at least 1.
    private func firstReached(after elapsed: TimeInterval) -> Int {
        var low = 1
        var high = max(1, offsets.count - 1)
        while low < high {
            let middle = (low + high) / 2
            if offsets[middle] > elapsed { high = middle } else { low = middle + 1 }
        }
        return low
    }

    /// Where the route is `elapsed` seconds in, between the two points around
    /// that time.
    func coordinate(at elapsed: TimeInterval) -> CLLocationCoordinate2D {
        guard let first = points.first, let last = points.last else {
            return CLLocationCoordinate2D()
        }
        guard elapsed > 0 else { return first }
        guard elapsed < duration else { return last }
        let low = firstReached(after: elapsed)
        let start = points[low - 1]
        let end = points[low]
        let span = offsets[low] - offsets[low - 1]
        let fraction = span > 0 ? (elapsed - offsets[low - 1]) / span : 1
        return CLLocationCoordinate2D(
            latitude: start.latitude + (end.latitude - start.latitude) * fraction,
            longitude: start.longitude + (end.longitude - start.longitude) * fraction)
    }
}

/// How far a playing route has got.
struct RouteProgress: Equatable {
    var elapsed: TimeInterval
    var duration: TimeInterval
    /// The timeline segment it's on, for a planned route's current road.
    var segment = 0

    var fraction: Double { duration > 0 ? min(1, elapsed / duration) : 1 }
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
    @Published private(set) var savedPlaces: [SavedPlace] = LocationManager.loadSavedPlaces()
    /// The imported GPX route, drawn on the map until it's removed.
    @Published private(set) var route: GPXRoute?
    @Published var routeSpeed: RouteSpeed = .walk
    /// Set while a route is playing.
    @Published private(set) var routeProgress: RouteProgress?
    @Published private(set) var isImportingRoute = false
    /// Where a planned route goes, in order.
    @Published private(set) var stops: [RouteStop] = []
    @Published var travelMode: TravelMode = .drive {
        didSet { if travelMode != oldValue { dropPlannedRoute() } }
    }
    /// While simulating, a planned route starts where the device is, not at
    /// the first stop.
    @Published var startsFromDevice = true {
        didSet { if startsFromDevice != oldValue { dropPlannedRoute() } }
    }
    /// The route planned through `stops`, until they change. Only one route
    /// is loaded at a time: planning one removes the GPX route, and the other
    /// way round.
    @Published private(set) var plannedRoute: PlannedRoute?
    @Published private(set) var isPlanningRoute = false
    private var planningTask: Task<Void, Never>?

    private var engine: Engine { Engine.shared }
    /// Silent audio, so backgrounding the app doesn't close the DVT session.
    private let keepAlive = KeepAlive()
    /// iOS drops a simulated location that isn't refreshed, so it's re-sent
    /// every 4s (as StikDebug does).
    private var resendTimer: Timer?
    private static let resendInterval: TimeInterval = 4
    /// Moves the location along `route`. The resend timer is off meanwhile,
    /// since this sends more often.
    private var playbackTask: Task<Void, Never>?
    /// How often a playing route sends a new point (StikDebug's step).
    private static let playbackTick: TimeInterval = 0.5
    private static let savedPlacesKey = "locationSavedPlaces"

    var isSimulating: Bool { simulated != nil }
    var isPlayingRoute: Bool { routeProgress != nil }
    var isPlayingPlannedRoute: Bool { isPlayingRoute && plannedRoute != nil }
    /// True when a planned route would start where the device is.
    var startsAtDevice: Bool { startsFromDevice && simulated != nil }
    /// What a route would be planned through: the device's spot, then the
    /// stops.
    var routeWaypoints: [CLLocationCoordinate2D] {
        let stopCoordinates = stops.map(\.coordinate)
        if startsAtDevice, let simulated { return [simulated] + stopCoordinates }
        return stopCoordinates
    }
    var canPlanRoute: Bool {
        routeWaypoints.count >= 2 && !isPlanningRoute && !isPlayingRoute
    }

    // MARK: Popups

    /// How the last action went, as popups `RootView` stacks over the app.
    var popups: [ToolPopup] {
        [lastError.map(ToolPopup.error), lastSuccess.map(ToolPopup.success)].compactMap { $0 }
    }

    func closePopup(_ popup: ToolPopup) {
        switch popup {
        case .error:   lastError = nil
        case .success: lastSuccess = nil
        }
    }

    // MARK: Setup

    /// Runs setup in the background: downloads the disk image, mounts it if the
    /// device has none, and opens the DVT session.
    ///
    /// Called when the page opens. Without a tunnel it stops after the
    /// download, since opening the page doesn't start LocalDevVPN. Failures are
    /// only logged; `simulate` repeats the setup and shows errors to the user.
    ///
    /// Uses its own task, so leaving the page doesn't cancel it.
    func prepareQuietly() {
        guard stage != .ready, !isBusy else { return }
        isBusy = true
        Task {
            do { try await ensureReady(quietly: true) }
            catch is CancellationError { }
            catch { engine.log("Location: not ready yet (\(message(error)))") }
            isBusy = false
        }
    }

    /// Download the image if it's missing, mount it if the device has none, and
    /// open the location session. Every step is a no-op once it has run, so this
    /// is cheap to call again. `quietly` leaves the device alone unless the
    /// tunnel is already up.
    private func ensureReady(quietly: Bool = false) async throws {
        guard stage != .ready else { return }
        if !DeveloperDiskImage.isDownloaded {
            stage = .downloading
            try await DeveloperDiskImage.downloadMissing { _ in }
        }
        if quietly {
            engine.refreshNetworkStatus()
            guard engine.vpnConnected else {
                stage = .notReady
                return
            }
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
    /// `name` is a saved place's, for the confirmation. Stops a playing route.
    ///
    /// Runs setup first if it hasn't finished (often the tunnel wasn't up when
    /// the page opened). Setup errors are shown to the user here.
    func simulate(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        guard !isBusy else { return }
        guard (-90...90).contains(coordinate.latitude),
              (-180...180).contains(coordinate.longitude) else {
            lastError = ErrorHelp.explained(L("That isn't a valid coordinate."))
            return
        }
        cancelPlayback()
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
                // A planned route starting at the device would start elsewhere now.
                if startsFromDevice { dropPlannedRoute() }
                lastSuccess = L("Location set to %@.", name ?? Self.format(coordinate))
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
        cancelPlayback()
        stopResending()
        Task {
            do {
                try await engine.stopSimulatingLocation()
                lastSuccess = L("Location reset. The device is using its own again.")
            } catch {
                lastError = message(error)
            }
            simulated = nil
            if startsFromDevice { dropPlannedRoute() }
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
        cancelPlayback()
        stopResending()
        simulated = nil
        stage = .notReady
        keepAlive.stopAll()
        lastSuccess = nil
        lastError = ErrorHelp.explained(L("Location session closed — set it up again."))
    }

    private func stopResending() {
        resendTimer?.invalidate()
        resendTimer = nil
    }

    // MARK: Saved places

    /// Saves `coordinate` under `name`, or under the coordinate itself when the
    /// name is left blank (as StikDebug does).
    func savePlace(named name: String, at coordinate: CLLocationCoordinate2D) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        savedPlaces.append(SavedPlace(name: trimmed.isEmpty ? Self.format(coordinate) : trimmed,
                                      latitude: coordinate.latitude,
                                      longitude: coordinate.longitude))
        storeSavedPlaces()
    }

    func deletePlace(_ place: SavedPlace) {
        savedPlaces.removeAll { $0.id == place.id }
        storeSavedPlaces()
    }

    private static func loadSavedPlaces() -> [SavedPlace] {
        guard let data = UserDefaults.standard.data(forKey: savedPlacesKey) else { return [] }
        return (try? JSONDecoder().decode([SavedPlace].self, from: data)) ?? []
    }

    private func storeSavedPlaces() {
        guard let data = try? JSONEncoder().encode(savedPlaces) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedPlacesKey)
    }

    // MARK: Routes

    /// Reads a GPX file off the main thread. A path is kept as `route`; a
    /// single place is only returned, for the page to move the map to.
    func importRoute(from url: URL) async -> GPXRoute? {
        guard !isImportingRoute, !isPlayingRoute else { return nil }
        isImportingRoute = true
        defer { isImportingRoute = false }
        lastError = nil
        do {
            let imported = try await Task.detached(priority: .userInitiated) {
                try GPXRoute(contentsOf: url)
            }.value
            if !imported.isSinglePlace {
                dropPlannedRoute()
                route = imported
                routeSpeed = imported.times == nil ? .walk : .recorded
                engine.log("Location: loaded route \(imported.name) "
                           + "(\(imported.points.count) points, \(Int(imported.distance)) m).")
            }
            return imported
        } catch {
            lastError = message(error)
            return nil
        }
    }

    func removeRoute() {
        guard !isPlayingRoute else { return }
        route = nil
    }

    /// Sets the location to the route's first point, then moves it along the
    /// route: a GPX route at `routeSpeed`, a planned one at each road's speed.
    /// At the end it stays on the last point.
    ///
    /// Sets up first, like `simulate`.
    func playRoute() {
        guard !isBusy, !isPlayingRoute else { return }
        let timeline: RouteTimeline
        let name: String
        if let plannedRoute {
            timeline = plannedRoute.timeline
            name = "the planned \(plannedRoute.mode.rawValue) route"
        } else if let route {
            timeline = RouteTimeline(route: route, speed: routeSpeed)
            name = route.name
        } else {
            return
        }
        guard let start = timeline.points.first else { return }
        isBusy = true
        lastError = nil
        lastSuccess = nil
        Task {
            do {
                try await ensureReady()
                try await engine.simulateLocation(latitude: start.latitude,
                                                  longitude: start.longitude)
                simulated = start
                keepAlive.startAudio()
                startPlayback(timeline)
                engine.log("Location: playing \(name) over \(Int(timeline.duration)) s.")
            } catch {
                stage = .notReady
                simulated = nil
                stopResending()
                lastError = message(error)
            }
            isBusy = false
        }
    }

    /// Stops a playing route where it is, and keeps the device there.
    func stopRoute() {
        guard isPlayingRoute else { return }
        endPlayback()
        lastError = nil
        lastSuccess = L("Route stopped. The device stays where it got to.")
        engine.log("Location: route stopped.")
    }

    /// Sends where the route should be every `playbackTick`, going by the time
    /// that has actually passed. Stops at the first failed send and holds the
    /// last point that went through, as StikDebug does.
    private func startPlayback(_ timeline: RouteTimeline) {
        stopResending()
        let started = Date()
        routeProgress = RouteProgress(elapsed: 0, duration: timeline.duration)
        playbackTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(Self.playbackTick))
                guard let self, !Task.isCancelled else { return }
                guard self.engine.connection.isSimulatingLocation else {
                    self.sessionClosed()
                    return
                }
                let elapsed = min(Date().timeIntervalSince(started), timeline.duration)
                let coordinate = timeline.coordinate(at: elapsed)
                do {
                    try await self.engine.simulateLocation(latitude: coordinate.latitude,
                                                           longitude: coordinate.longitude)
                } catch {
                    guard !Task.isCancelled else { return }
                    self.endPlayback()
                    self.lastSuccess = nil
                    self.lastError = L("Route playback stopped: %@", self.message(error))
                    return
                }
                // Stopped or replaced while that was sending.
                guard !Task.isCancelled else { return }
                self.simulated = coordinate
                self.routeProgress = RouteProgress(elapsed: elapsed, duration: timeline.duration,
                                                   segment: timeline.segment(at: elapsed))
                if elapsed >= timeline.duration {
                    self.endPlayback()
                    self.lastError = nil
                    self.lastSuccess = L("Route finished. The device stays at its last point.")
                    self.engine.log("Location: route finished.")
                    return
                }
            }
        }
    }

    /// Stops moving and goes back to re-sending wherever playback got to.
    private func endPlayback() {
        cancelPlayback()
        if simulated != nil { startResending() }
    }

    private func cancelPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        routeProgress = nil
    }

    // MARK: Planned routes

    /// Adds a stop at the end. Without a `name`, it's looked up and filled in
    /// when the geocoder answers.
    func addStop(at coordinate: CLLocationCoordinate2D, name: String? = nil) {
        guard !isPlayingPlannedRoute else { return }
        let stop = RouteStop(coordinate: coordinate, name: name)
        stops.append(stop)
        dropPlannedRoute()
        guard name == nil else { return }
        Task {
            guard let found = await RoutePlanner.placeName(at: coordinate),
                  let index = stops.firstIndex(where: { $0.id == stop.id }) else { return }
            stops[index].name = found
        }
    }

    func removeStop(_ stop: RouteStop) {
        guard !isPlayingPlannedRoute else { return }
        stops.removeAll { $0.id == stop.id }
        dropPlannedRoute()
    }

    /// Moves a stop `offset` places earlier (negative) or later in the order.
    func moveStop(_ stop: RouteStop, by offset: Int) {
        guard !isPlayingPlannedRoute, let index = stops.firstIndex(where: { $0.id == stop.id }) else { return }
        let destination = index + offset
        guard stops.indices.contains(destination) else { return }
        stops.swapAt(index, destination)
        dropPlannedRoute()
    }

    func removeAllStops() {
        guard !isPlayingPlannedRoute else { return }
        stops.removeAll()
        dropPlannedRoute()
    }

    /// Plans a route through `routeWaypoints` over OpenStreetMap. It replaces
    /// the GPX route, if there is one.
    func planRoute() {
        let waypoints = routeWaypoints
        guard canPlanRoute else { return }
        let mode = travelMode
        let deviceStart = startsAtDevice ? waypoints.first : nil
        isPlanningRoute = true
        lastError = nil
        lastSuccess = nil
        planningTask = Task {
            do {
                var planned = try await RoutePlanner.plan(through: waypoints, mode: mode)
                planned.deviceStart = deviceStart
                try Task.checkCancellation()
                route = nil
                plannedRoute = planned
                let mapped = planned.mappedLimitShare.map { ", \(Int($0 * 100))% of limits mapped" } ?? ""
                engine.log("Location: planned a \(mode.rawValue) route over OpenStreetMap "
                           + "(\(waypoints.count) places, \(planned.points.count) points, "
                           + "\(Int(planned.distance)) m, \(Int(planned.duration)) s\(mapped)).")
            } catch {
                // Changing the stops or the mode cancels a plan on its way.
                guard !Task.isCancelled else { return }
                lastError = message(error)
            }
            isPlanningRoute = false
            planningTask = nil
        }
    }

    func removePlannedRoute() {
        guard !isPlayingRoute else { return }
        dropPlannedRoute()
    }

    /// Forgets the planned route, and any plan on its way, after the stops or
    /// the mode change. A route that's playing is left alone.
    private func dropPlannedRoute() {
        guard !isPlayingPlannedRoute else { return }
        planningTask?.cancel()
        planningTask = nil
        isPlanningRoute = false
        plannedRoute = nil
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
    /// The last search's match, so a stop added there takes its name.
    @State private var searchMatch: (name: String, coordinate: CLLocationCoordinate2D)?
    /// The crosshair's coordinate when Save was tapped, while the name prompt
    /// is up.
    @State private var placeToSave: CLLocationCoordinate2D?
    @State private var placeName = ""
    @State private var showRouteImporter = false
    /// Bumped to scroll the map into view after moving it from further down.
    @State private var mapRequests = 0
    private static let mapCardID = "map"

    /// Set location and the saved places need the same things.
    private var canSetLocation: Bool {
        !manager.isBusy && engine.tunnelAvailable && !engine.isRunning
    }

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    // No note when Set location starts LocalDevVPN itself.
                    if !engine.tunnelAvailable {
                        vpnNote.cascadeItem(1)
                    }
                    mapCard.cascadeItem(2)
                        .id(Self.mapCardID)
                    plannerCard.cascadeItem(3)
                    savedPlacesCard.cascadeItem(4)
                    routeCard.cascadeItem(5)
                    // Errors and confirmations show as popups, which `RootView`
                    // lays over the app.
                }
                .padding(20)
                .pageColumn()
                .animation(.smooth(duration: 0.35), value: manager.stage)
                .animation(.smooth(duration: 0.3), value: manager.isBusy)
                .animation(.smooth(duration: 0.3), value: engine.vpnConnected)
                .animation(.smooth(duration: 0.3), value: manager.savedPlaces)
                .animation(.smooth(duration: 0.3), value: manager.isPlayingRoute)
                .animation(.smooth(duration: 0.3), value: manager.route?.name)
                .animation(.smooth(duration: 0.3), value: manager.stops)
                .animation(.smooth(duration: 0.3), value: manager.plannedRoute?.id)
                .animation(.smooth(duration: 0.3), value: manager.isPlanningRoute)
            }
            .onChange(of: mapRequests) {
                withAnimation(.smooth(duration: 0.4)) {
                    scroller.scrollTo(Self.mapCardID, anchor: .top)
                }
            }
            // Show a newly planned route whole. The page stays where it is,
            // by the Play button.
            .onChange(of: manager.plannedRoute?.id) {
                if let planned = manager.plannedRoute { fitMap(to: planned.points) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .toolbar { settingsToolbarItem(isPresented: $showSettings) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showRouteImporter) {
            FileImporterRepresentableView(allowedContentTypes: [.gpx, .xml]) { urls in
                guard let url = urls.first else { return }   // empty means cancelled
                importRoute(from: url)
            }
            .ignoresSafeArea()
        }
        .alert(L("Save this place"),
               isPresented: Binding(get: { placeToSave != nil },
                                    set: { if !$0 { placeToSave = nil } })) {
            TextField(L("Name"), text: $placeName)
            Button(L("Save")) {
                if let placeToSave { manager.savePlace(named: placeName, at: placeToSave) }
                placeToSave = nil
            }
            Button(L("Cancel"), role: .cancel) { placeToSave = nil }
        } message: {
            if let placeToSave {
                Text(LocationManager.format(placeToSave))
            }
        }
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
        if let progress = manager.routeProgress {
            StatusPill(text: L("Playing route · %d%%", Int(progress.fraction * 100)),
                       systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill",
                       color: .green)
        } else if let simulated = manager.simulated {
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
                        if let route = manager.route {
                            MapPolyline(coordinates: route.points)
                                .stroke(Theme.accent.opacity(0.8), lineWidth: 4)
                        }
                        if let planned = manager.plannedRoute {
                            MapPolyline(coordinates: planned.points)
                                .stroke(Theme.accent.opacity(0.85), lineWidth: 5)
                        }
                        ForEach(Array(manager.stops.enumerated()), id: \.element.id) { index, stop in
                            Marker(stop.name ?? LocationManager.format(stop.coordinate),
                                   monogram: Text(verbatim: "\(index + 1)"),
                                   coordinate: stop.coordinate)
                                .tint(.orange)
                        }
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

                // Icons only where the coordinate and both labels don't fit.
                ViewThatFits(in: .horizontal) {
                    pinActions(labelled: true)
                    pinActions(labelled: false)
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
                .disabled(!canSetLocation)

                if manager.isSimulating {
                    Button { manager.stop() } label: {
                        Label(L("Reset to real location"), systemImage: "location.slash")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered, sound: .tap)
                    .controlSize(.regular)
                    .tint(.orange)
                    .disabled(manager.isBusy)
                }
            }
        }
    }

    /// The crosshair's coordinate, with Add stop and Save for it.
    private func pinActions(labelled: Bool) -> some View {
        HStack(spacing: 8) {
            Label(LocationManager.format(target), systemImage: "scope")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button { addStopAtPin() } label: {
                pinActionLabel(L("Add stop"), systemImage: "plus", labelled: labelled)
            }
            .disabled(manager.isPlayingPlannedRoute)
            Button {
                placeName = ""
                placeToSave = target
            } label: {
                pinActionLabel(L("Save"), systemImage: "bookmark", labelled: labelled)
            }
        }
        .buttonStyle(.bordered, sound: .tap)
        .controlSize(.small)
        .tint(Theme.accent)
    }

    @ViewBuilder
    private func pinActionLabel(_ title: String, systemImage: String, labelled: Bool) -> some View {
        if labelled {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
        } else {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .accessibilityLabel(title)
        }
    }

    /// Adds the crosshair's spot as a stop, named after the search match when
    /// the map is still on it.
    private func addStopAtPin() {
        var name: String?
        if let searchMatch {
            let meters = CLLocation(latitude: target.latitude, longitude: target.longitude)
                .distance(from: CLLocation(latitude: searchMatch.coordinate.latitude,
                                           longitude: searchMatch.coordinate.longitude))
            if meters < 15 { name = searchMatch.name }
        }
        manager.addStop(at: target, name: name)
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
            .buttonStyle(.bordered, sound: .tap)
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
                manager.lastError = ErrorHelp.explained(L("Nothing found for “%@”.", text))
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
            searchMatch = (first.name ?? text, coordinate)
            moveMap(to: coordinate)
        }
    }

    /// Centers the map, and so the crosshair, on `coordinate`.
    private func moveMap(to coordinate: CLLocationCoordinate2D) {
        withAnimation(.smooth(duration: 0.4)) {
            camera = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        }
        target = coordinate
    }

    // MARK: Planned route

    /// Stops, a way of travelling, and the route OpenStreetMap gives through
    /// them, played at each road's speed limit when driving.
    private var plannerCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(L("Plan a route"), systemImage: "signpost.right.and.left.fill")

                Picker(L("Travel by"), selection: $manager.travelMode) {
                    ForEach(TravelMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(manager.isPlayingPlannedRoute)

                Text(Self.modeExplanation(manager.travelMode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Playing moves the device, which isn't where the route started.
                if manager.isSimulating, !manager.isPlayingPlannedRoute {
                    Toggle(L("Start where the device is"), isOn: $manager.startsFromDevice)
                        .font(.subheadline)
                        .tint(Theme.accent)
                }

                stopList

                if let planned = manager.plannedRoute {
                    plannedRouteSummary(planned)
                    playbackControls { progress in
                        if let stretch = planned.stretch(atSegment: progress.segment) {
                            currentRoad(stretch, mode: planned.mode)
                        }
                    }
                } else {
                    findRouteButton
                }

                Link(destination: URL(string: "https://www.openstreetmap.org/copyright")!) {
                    Text(L("Routes from OpenStreetMap, © OpenStreetMap contributors"))
                        .multilineTextAlignment(.leading)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var stopList: some View {
        if manager.stops.isEmpty {
            Text(L("Move the map so the pin is on a place, then tap Add stop. Add as many as you like: the route goes to each in order."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: 2) {
                if let deviceStart = routeDeviceStart {
                    stopRow(title: L("The device's location"), coordinate: deviceStart) {
                        Image(systemName: "location.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.green))
                    } trailing: {
                        EmptyView()
                    }
                }
                ForEach(Array(manager.stops.enumerated()), id: \.element.id) { index, stop in
                    stopRow(title: stop.name ?? L("Stop %d", index + 1), coordinate: stop.coordinate) {
                        Text(verbatim: "\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.orange))
                    } trailing: {
                        Menu { stopMenu(stop, index: index) } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .disabled(manager.isPlayingPlannedRoute)
                    }
                }
            }

            HStack {
                Button { addStopAtPin() } label: {
                    Label(L("Add stop"), systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                Spacer()
                Button(role: .destructive) { manager.removeAllStops() } label: {
                    Label(L("Clear stops"), systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
                .tint(.red)
            }
            .buttonStyle(.bordered, sound: .tap)
            .controlSize(.small)
            .tint(Theme.accent)
            .disabled(manager.isPlayingPlannedRoute)
        }
    }

    /// The device's spot heading the stops: where a planned route started, or
    /// where the next one would.
    private var routeDeviceStart: CLLocationCoordinate2D? {
        if let planned = manager.plannedRoute { return planned.deviceStart }
        return manager.startsAtDevice ? manager.simulated : nil
    }

    private func stopRow<Badge: View, Trailing: View>(
        title: String, coordinate: CLLocationCoordinate2D,
        @ViewBuilder badge: () -> Badge, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            badge()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(LocationManager.format(coordinate))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .frame(minHeight: 36)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func stopMenu(_ stop: RouteStop, index: Int) -> some View {
        Button {
            moveMap(to: stop.coordinate)
            mapRequests += 1
        } label: {
            Label(L("Show on map"), systemImage: "map")
        }
        if index > 0 {
            Button { manager.moveStop(stop, by: -1) } label: {
                Label(L("Move up"), systemImage: "arrow.up")
            }
        }
        if index < manager.stops.count - 1 {
            Button { manager.moveStop(stop, by: 1) } label: {
                Label(L("Move down"), systemImage: "arrow.down")
            }
        }
        Button(role: .destructive) { manager.removeStop(stop) } label: {
            Label(L("Remove"), systemImage: "trash")
        }
    }

    @ViewBuilder
    private var findRouteButton: some View {
        Button { manager.planRoute() } label: {
            HStack(spacing: 10) {
                if manager.isPlanningRoute {
                    ProgressView().tint(.white)
                    Text(L("Finding route"))
                } else {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    Text(L("Find route"))
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!manager.canPlanRoute)

        if manager.routeWaypoints.count == 1 {
            Text(L("Add one more stop to plan a route."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Length and time, how much of a drive has mapped limits, and buttons to
    /// show it or take it away.
    private func plannedRouteSummary(_ planned: PlannedRoute) -> some View {
        HStack(spacing: 12) {
            Image(systemName: planned.mode.systemImage)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Self.formatDistance(planned.distance)) · "
                     + Self.formatDuration(planned.duration))
                    .font(.subheadline.weight(.semibold))
                Text(Self.routeDetail(planned))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                fitMap(to: planned.points)
                mapRequests += 1
            } label: {
                Image(systemName: "map")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(L("Show on map"))
            Button { manager.removePlannedRoute() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(L("Remove"))
            .disabled(manager.isPlayingRoute)
        }
    }

    /// The road a playing route is on, with its limit sign when driving.
    private func currentRoad(_ stretch: PlannedRoute.Stretch, mode: TravelMode) -> some View {
        HStack(spacing: 12) {
            if let limit = stretch.limit {
                SpeedLimitSign(limit: limit)
            } else {
                Image(systemName: mode.systemImage)
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stretch.name ?? L("No street name"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(Self.roadDetail(stretch))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.06)))
        .animation(.smooth(duration: 0.3), value: stretch)
    }

    // MARK: Saved places

    private var savedPlacesCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L("Saved places"), systemImage: "bookmark.fill")
                if manager.savedPlaces.isEmpty {
                    Text(L("Tap Save under the map to keep the spot under the pin. Tapping a saved place sets it straight away."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 2) {
                        ForEach(manager.savedPlaces) { place in
                            savedPlaceRow(place)
                        }
                    }
                }
            }
        }
    }

    /// Tap to set the place; the menu shows it on the map or deletes it.
    private func savedPlaceRow(_ place: SavedPlace) -> some View {
        HStack(spacing: 10) {
            Button {
                moveMap(to: place.coordinate)
                manager.simulate(place.coordinate, name: place.name)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(LocationManager.format(place.coordinate))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain, sound: .tap)
            .disabled(!canSetLocation)
            // `.plain` doesn't dim a disabled row on its own.
            .opacity(canSetLocation ? 1 : 0.5)

            Menu {
                Button {
                    moveMap(to: place.coordinate)
                    mapRequests += 1
                } label: {
                    Label(L("Show on map"), systemImage: "map")
                }
                Button {
                    manager.addStop(at: place.coordinate, name: place.name)
                } label: {
                    Label(L("Add as stop"), systemImage: "plus")
                }
                .disabled(manager.isPlayingPlannedRoute)
                Button(role: .destructive) {
                    manager.deletePlace(place)
                } label: {
                    Label(L("Delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
    }

    // MARK: Route

    private var routeCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(L("Play a GPX route"),
                             systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                if let route = manager.route {
                    loadedRoute(route)
                } else {
                    Text(L("Import a .gpx file and the device moves along it at the speed you pick, then stays at its last point."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { showRouteImporter = true } label: {
                        HStack(spacing: 8) {
                            if manager.isImportingRoute {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text(L("Import GPX file"))
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered, sound: .tap)
                    .controlSize(.regular)
                    .tint(Theme.accent)
                    .disabled(manager.isImportingRoute)
                }
            }
        }
    }

    @ViewBuilder
    private func loadedRoute(_ route: GPXRoute) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(route.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(Self.formatDistance(route.distance)) · "
                     + Self.formatDuration(route.duration(at: manager.routeSpeed)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                fitMap(to: route.points)
                mapRequests += 1
            } label: {
                Image(systemName: "map")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(L("Show on map"))
            Button { manager.removeRoute() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(L("Remove"))
            .disabled(manager.isPlayingRoute)
        }

        Menu {
            Picker(L("Speed"), selection: $manager.routeSpeed) {
                ForEach(route.speeds) { speed in
                    Text(Self.speedTitle(speed)).tag(speed)
                }
            }
        } label: {
            HStack {
                Text(Self.speedTitle(manager.routeSpeed))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .fieldBackground()
            .contentShape(Rectangle())
        }
        .disabled(manager.isPlayingRoute)

        playbackControls { _ in EmptyView() }
    }

    /// Play, or while playing the progress, `current` (what the route is on
    /// now) and Stop here. Shared by both kinds of route.
    @ViewBuilder
    private func playbackControls<Current: View>(
        @ViewBuilder current: (RouteProgress) -> Current) -> some View {
        if let progress = manager.routeProgress {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress.fraction)
                    .tint(Theme.accent)
                Text(L("%@ of %@",
                       Self.formatClock(progress.elapsed, total: progress.duration),
                       Self.formatClock(progress.duration, total: progress.duration)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)

            current(progress)

            Button { manager.stopRoute() } label: {
                Label(L("Stop here"), systemImage: "pause.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered, sound: .tap)
            .controlSize(.regular)
            .tint(.orange)
        } else {
            Button { manager.playRoute() } label: {
                HStack(spacing: 10) {
                    if manager.isBusy {
                        ProgressView().tint(.white)
                        Text(L("Setting"))
                    } else {
                        Image(systemName: "play.fill")
                        Text(L("Play route"))
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSetLocation)
        }
    }

    /// Reads the picked file. A route is fitted on the map; a file that's one
    /// place moves the crosshair there. Either way the map scrolls into view.
    private func importRoute(from url: URL) {
        Task {
            guard let route = await manager.importRoute(from: url),
                  let first = route.points.first else { return }
            if route.isSinglePlace {
                moveMap(to: first)
            } else {
                fitMap(to: route.points)
            }
            mapRequests += 1
        }
    }

    private func fitMap(to points: [CLLocationCoordinate2D]) {
        let rect = MKPolyline(coordinates: points, count: points.count).boundingMapRect
        // A margin so the ends aren't under the card's rounded corners.
        let margin = max(rect.width, rect.height) * 0.15 + 200
        withAnimation(.smooth(duration: 0.4)) {
            camera = .rect(rect.insetBy(dx: -margin, dy: -margin))
        }
    }

    // MARK: Formatting

    private static func modeExplanation(_ mode: TravelMode) -> String {
        switch mode {
        case .drive:
            return L("Goes along each street at its speed limit, from OpenStreetMap. A street without one mapped gets the usual limit for its kind of road.")
        case .cycle:
            return L("Rides streets and paths a bike can take, at a cycling pace.")
        case .walk:
            return L("Walks streets and paths at a walking pace.")
        }
    }

    /// Under a planned route's length: how much of a drive has mapped limits,
    /// or the average pace on foot or by bike.
    private static func routeDetail(_ planned: PlannedRoute) -> String {
        if let share = planned.mappedLimitShare {
            let percent = Int((share * 100).rounded(.down))
            return percent >= 100 ? L("Speed limits are mapped for all of it.")
                                  : L("Speed limits are mapped for %d%% of it; the rest is estimated.", percent)
        }
        let average = planned.duration > 0 ? planned.distance / planned.duration : 0
        return L("Average %@", formatSpeed(average))
    }

    /// Limits read as their signs do (30 km/h in Milan, 25 mph in San
    /// Francisco); other speeds go in the app's units.
    private static func roadDetail(_ stretch: PlannedRoute.Stretch) -> String {
        switch stretch.limit {
        case .posted(let speed)?:
            return L("Speed limit %@", speed.text)
        case .unlimited?:
            return L("No speed limit · going %@", formatSpeed(stretch.metersPerSecond))
        case .estimated(let speed)?:
            return L("No limit mapped · going %@", speed.text)
        case nil:
            return L("Going %@", formatSpeed(stretch.metersPerSecond))
        }
    }

    /// km/h, or mph where the app's region drives in miles, for speeds that
    /// aren't a road's limit.
    private static var roadSpeedUnit: UnitSpeed {
        Localizer.locale.measurementSystem == .metric ? .kilometersPerHour : .milesPerHour
    }

    /// A road speed, e.g. "50 km/h", in `roadSpeedUnit`.
    private static func formatSpeed(_ metersPerSecond: CLLocationSpeed) -> String {
        Measurement(value: metersPerSecond, unit: UnitSpeed.metersPerSecond)
            .converted(to: roadSpeedUnit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(0)))
                .locale(Localizer.locale))
    }

    /// A speed choice as the menu lists it, e.g. "Walk · 5 km/h".
    private static func speedTitle(_ speed: RouteSpeed) -> String {
        guard let metersPerSecond = speed.metersPerSecond else { return speed.title }
        let rate = Measurement(value: metersPerSecond, unit: UnitSpeed.metersPerSecond)
            .formatted(.measurement(width: .abbreviated, usage: .general,
                                    numberFormatStyle: .number.precision(.fractionLength(0)))
                .locale(Localizer.locale))
        return "\(speed.title) · \(rate)"
    }

    private static func formatDistance(_ meters: CLLocationDistance) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(Localizer.locale))
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated,
                              maximumUnitCount: 2)
                .locale(Localizer.locale))
    }

    /// A playback position like "12:03", with hours once the route needs them.
    /// Rounded like `formatDuration`, so the total matches the summary.
    private static func formatClock(_ seconds: TimeInterval, total: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.time(pattern: total >= 3600 ? .hourMinuteSecond : .minuteSecond))
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

// MARK: - Speed limit sign

/// A round limit sign as most of the world posts them: a red ring round the
/// number, gray when the limit is only estimated, and the struck-through white
/// disc of an end-of-limits sign where there's none. White in dark mode too,
/// like the real thing.
private struct SpeedLimitSign: View {
    var limit: SpeedLimit

    var body: some View {
        ZStack {
            Circle().fill(.white)
            switch limit {
            case .posted(let speed), .estimated(let speed):
                Circle()
                    .strokeBorder(limit.isEstimated ? Color.gray : Color.red, lineWidth: 4.5)
                Text(verbatim: "\(speed.value)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(7)
            case .unlimited:
                Stripes()
                    .stroke(.black, lineWidth: 1.6)
                    .clipShape(Circle())
                    .padding(6)
                Circle()
                    .strokeBorder(.black.opacity(0.2), lineWidth: 1)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch limit {
        case .posted(let speed):    return L("Speed limit %@", speed.text)
        case .estimated(let speed): return L("Estimated speed limit %@", speed.text)
        case .unlimited:            return L("No speed limit")
        }
    }

    /// Five parallel lines rising to the right, as across an end-of-limits
    /// sign.
    private struct Stripes: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let spacing = rect.width * 0.12
            let reach = rect.width
            for line in -2...2 {
                // Stepped across the lines, which run up and to the right.
                let offset = CGFloat(line) * spacing / 2.squareRoot()
                let middle = CGPoint(x: center.x + offset, y: center.y + offset)
                path.move(to: CGPoint(x: middle.x - reach, y: middle.y + reach))
                path.addLine(to: CGPoint(x: middle.x + reach, y: middle.y - reach))
            }
            return path
        }
    }
}

extension RoadSpeed {
    /// As its sign reads, with the unit: "30 km/h", "25 mph".
    var text: String {
        Measurement(value: Double(value), unit: inMiles ? UnitSpeed.milesPerHour : .kilometersPerHour)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(0)))
                .locale(Localizer.locale))
    }
}
