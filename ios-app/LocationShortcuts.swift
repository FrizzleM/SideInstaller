import AppIntents
import Contacts
import CoreLocation
import Foundation
import Intents
import UniformTypeIdentifiers

// MARK: - Location spoofing actions
//
// The Location spoofing page's controls as Shortcuts actions. Each one waits
// its turn behind whatever the page is doing, and returns once the device has
// the result. A location set from Shortcuts stays set, re-sent every few
// seconds, until Reset Location, as one set on the page does.

// MARK: Saved places

/// A place saved on the Location spoofing page.
struct SavedPlaceEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Saved Place"
    static let defaultQuery = SavedPlaceQuery()

    let id: UUID

    @Property(title: "Name")
    var name: String

    @Property(title: "Latitude")
    var latitude: Double

    @Property(title: "Longitude")
    var longitude: Double

    /// The same spot as a location other actions take, such as Show in Maps.
    @Property(title: "Location")
    var location: CLPlacemark?

    init(_ place: SavedPlace) {
        id = place.id
        name = place.name
        latitude = place.latitude
        longitude = place.longitude
        location = CLPlacemark.at(place.coordinate, named: place.name)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)",
                              subtitle: "\(LocationManager.format(coordinate))",
                              image: DisplayRepresentation.Image(systemName: "mappin.circle.fill"))
    }
}

struct SavedPlaceQuery: EnumerableEntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [SavedPlaceEntity.ID]) async throws -> [SavedPlaceEntity] {
        LocationManager.shared.savedPlaces
            .filter { identifiers.contains($0.id) }
            .map(SavedPlaceEntity.init)
    }

    @MainActor
    func allEntities() async throws -> [SavedPlaceEntity] {
        LocationManager.shared.savedPlaces.map(SavedPlaceEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [SavedPlaceEntity] {
        try await allEntities()
    }

    @MainActor
    func entities(matching string: String) async throws -> [SavedPlaceEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return LocationManager.shared.savedPlaces
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .map(SavedPlaceEntity.init)
    }
}

// MARK: Setting the location

struct SetLocationIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Set Location"
    static let description = IntentDescription(
        "Moves this iPhone's location to a place, as Set location does on SideInstaller's Location spoofing page. It stays there until Reset Location, another place or a route moves it. Runs over LocalDevVPN, which has to be connected.",
        categoryName: "Location Spoofing",
        searchKeywords: ["spoof", "fake", "gps", "location", "teleport"])

    @Parameter(title: "Place", description: "Where this iPhone should be. Pick on the map, type an address, or pass a location from another action.")
    var place: CLPlacemark

    static var parameterSummary: some ParameterSummary {
        Summary("Set location to \(\.$place)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<CLPlacemark> & ProvidesDialog {
        let coordinate = try place.requiredCoordinate()
        let name = place.shortcutName ?? LocationManager.format(coordinate)
        try await Shortcuts.run("Set Location to \(LocationManager.format(coordinate))") {
            try await Shortcuts.ensureTunnel(for: self)
            try await LocationManager.shared.setLocation(coordinate)
        }
        return .result(value: place, dialog: Shortcuts.dialog(L("Location set to %@.", name)))
    }
}

struct SetCoordinatesIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Set Location to Coordinates"
    static let description = IntentDescription(
        "Moves this iPhone's location to a latitude and longitude in degrees, such as 45.46421 and 9.19000. It stays there until Reset Location, another place or a route moves it.",
        categoryName: "Location Spoofing",
        searchKeywords: ["spoof", "fake", "gps", "latitude", "longitude"])

    @Parameter(title: "Latitude", description: "From -90 (south) to 90 (north).",
               controlStyle: .field, inclusiveRange: (-90, 90))
    var latitude: Double

    @Parameter(title: "Longitude", description: "From -180 (west) to 180 (east).",
               controlStyle: .field, inclusiveRange: (-180, 180))
    var longitude: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Set location to \(\.$latitude), \(\.$longitude)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<CLPlacemark> & ProvidesDialog {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard LocationManager.isValid(coordinate) else {
            throw ShortcutError(L("That isn't a valid coordinate."))
        }
        try await Shortcuts.run("Set Location to \(LocationManager.format(coordinate))") {
            try await Shortcuts.ensureTunnel(for: self)
            try await LocationManager.shared.setLocation(coordinate)
        }
        let text = LocationManager.format(coordinate)
        return .result(value: CLPlacemark.at(coordinate, named: text),
                       dialog: Shortcuts.dialog(L("Location set to %@.", text)))
    }
}

struct SetSavedPlaceIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Set Location to Saved Place"
    static let description = IntentDescription(
        "Moves this iPhone's location to one of the places saved on the Location spoofing page, as tapping it there does.",
        categoryName: "Location Spoofing",
        searchKeywords: ["spoof", "fake", "gps", "saved", "favorite"])

    @Parameter(title: "Saved Place", requestValueDialog: "Which saved place?")
    var place: SavedPlaceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Set location to \(\.$place)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<SavedPlaceEntity> & ProvidesDialog {
        let coordinate = place.coordinate
        try await Shortcuts.run("Set Location to a saved place") {
            try await Shortcuts.ensureTunnel(for: self)
            try await LocationManager.shared.setLocation(coordinate)
        }
        return .result(value: place, dialog: Shortcuts.dialog(L("Location set to %@.", place.name)))
    }
}

struct ResetLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Reset Location"
    static let description = IntentDescription(
        "Gives this iPhone its real location back, and stops a route that's playing, as Reset to real location does.",
        categoryName: "Location Spoofing",
        searchKeywords: ["spoof", "stop", "real", "gps"])

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await Shortcuts.run("Reset Location") {
            try await LocationManager.shared.resetLocation()
        }
        return .result(dialog: Shortcuts.dialog(L("Location reset. The device is using its own again.")))
    }
}

// MARK: Reading the location

struct GetSpoofedLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Spoofed Location"
    static let description = IntentDescription(
        "Gives the location SideInstaller is setting now, named after what's there, or nothing when the location isn't spoofed. While a route plays, it's the point the route has got to.",
        categoryName: "Location Spoofing",
        searchKeywords: ["spoof", "current", "where", "gps"])

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<CLPlacemark?> & ProvidesDialog {
        guard let simulated = LocationManager.shared.simulated else {
            return .result(value: nil, dialog: Shortcuts.dialog(L("Not simulating")))
        }
        let name = await RoutePlanner.placeName(at: simulated) ?? LocationManager.format(simulated)
        return .result(value: CLPlacemark.at(simulated, named: name), dialog: Shortcuts.dialog(name))
    }
}

struct IsLocationSpoofedIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Location Spoofed"
    static let description = IntentDescription(
        "True while SideInstaller is setting this iPhone's location, a route playing included; false once it's reset.",
        categoryName: "Location Spoofing",
        searchKeywords: ["spoof", "status", "gps"])

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: LocationManager.shared.isSimulating)
    }
}

// MARK: Saving places

struct SavePlaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Place"
    static let description = IntentDescription(
        "Adds a place to the saved places on the Location spoofing page, ready for Set Location to Saved Place. Left without a name, it's saved under its coordinates.",
        categoryName: "Location Spoofing",
        searchKeywords: ["bookmark", "favorite", "saved"])

    @Parameter(title: "Place")
    var place: CLPlacemark

    @Parameter(title: "Name")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$place) as \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<SavedPlaceEntity> {
        let coordinate = try place.requiredCoordinate()
        let saved = try await Shortcuts.run("Save Place") {
            LocationManager.shared.savePlace(named: name ?? place.shortcutName ?? "", at: coordinate)
        }
        return .result(value: SavedPlaceEntity(saved))
    }
}

struct DeleteSavedPlaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Saved Place"
    static let description = IntentDescription(
        "Removes a place from the saved places on the Location spoofing page.",
        categoryName: "Location Spoofing")

    @Parameter(title: "Saved Place")
    var place: SavedPlaceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$place)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await Shortcuts.run("Delete Saved Place") {
            let manager = LocationManager.shared
            if let saved = manager.savedPlaces.first(where: { $0.id == place.id }) {
                manager.deletePlace(saved)
            }
        }
        return .result()
    }
}

// MARK: Routes

/// How fast a GPX route plays (`RouteSpeed`).
enum RouteSpeedOption: String, AppEnum {
    case recorded
    case walk
    case cycle
    case drive

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Speed"
    static let caseDisplayRepresentations: [RouteSpeedOption: DisplayRepresentation] = [
        .recorded: DisplayRepresentation(title: "As Recorded",
                                         subtitle: "The file's own times, when it has them"),
        .walk: DisplayRepresentation(title: "Walk", subtitle: "About 5 km/h"),
        .cycle: DisplayRepresentation(title: "Cycle", subtitle: "About 20 km/h"),
        .drive: DisplayRepresentation(title: "Drive", subtitle: "About 48 km/h"),
    ]

    var speed: RouteSpeed {
        switch self {
        case .recorded: return .recorded
        case .walk:     return .walk
        case .cycle:    return .cycle
        case .drive:    return .drive
        }
    }
}

/// How a planned route is travelled (`TravelMode`).
enum TravelModeOption: String, AppEnum {
    case walk
    case cycle
    case drive

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Travel Mode"
    static let caseDisplayRepresentations: [TravelModeOption: DisplayRepresentation] = [
        .walk: DisplayRepresentation(title: "Walk", subtitle: "Streets and paths, at a walking pace"),
        .cycle: DisplayRepresentation(title: "Cycle", subtitle: "Where a bike can go, at a cycling pace"),
        .drive: DisplayRepresentation(title: "Drive", subtitle: "Roads, at each one's speed limit"),
    ]

    var mode: TravelMode {
        switch self {
        case .walk:  return .walk
        case .cycle: return .cycle
        case .drive: return .drive
        }
    }
}

struct PlayGPXRouteIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Play GPX Route"
    static let description = IntentDescription(
        "Moves this iPhone's location along a GPX file's track, route or waypoints, as Play a GPX route does, then leaves it at the last point. A file with a single point just sets the location there.",
        categoryName: "Location Spoofing",
        searchKeywords: ["spoof", "gpx", "track", "route", "walk", "joystick"])

    // Type identifiers rather than UTTypes, which need iOS 18. Any file
    // goes, since one saved from the web is often typed as plain data: KML,
    // GeoJSON and lists of coordinates are read too (`RouteFile`).
    @Parameter(title: "GPX File",
               supportedTypeIdentifiers: ["com.topografix.gpx", "com.google.earth.kml",
                                          "public.geojson", "public.json", "public.xml",
                                          "public.comma-separated-values-text", "public.plain-text",
                                          "public.data"])
    var file: IntentFile

    @Parameter(title: "Speed",
               description: "Left empty, it follows the file's own times when it has them, and walks otherwise.")
    var speed: RouteSpeedOption?

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$file)") {
            \.$speed
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await Shortcuts.run("Play GPX Route") { () -> String in
            let copy = try Shortcuts.temporaryCopy(of: file, defaultName: "Route.gpx")
            defer { Shortcuts.discard(copy) }
            let route = try await Task.detached(priority: .userInitiated) {
                try GPXRoute(contentsOf: copy)
            }.value
            try await Shortcuts.ensureTunnel(for: self)
            let manager = LocationManager.shared
            if route.isSinglePlace, let point = route.points.first {
                try await manager.setLocation(point)
                return L("Location set to %@.", route.name)
            }
            let chosen = speed?.speed ?? (route.times == nil ? .walk : .recorded)
            try await manager.play(route, at: chosen)
            return Self.started(distance: route.distance, duration: route.duration(at: manager.routeSpeed))
        }
        return .result(dialog: Shortcuts.dialog(message))
    }

    static func started(distance: CLLocationDistance, duration: TimeInterval) -> String {
        L("Route started: %@, about %@.", LocationView.formatDistance(distance),
          LocationView.formatDuration(duration))
    }
}

struct TravelToPlaceIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Travel to Place"
    static let description = IntentDescription(
        "Plans a route over OpenStreetMap and moves this iPhone's location along it, as Plan a route does on the Location spoofing page. Driving keeps to each road's speed limit. At the end the location stays at the destination.",
        categoryName: "Location Spoofing",
        searchKeywords: ["spoof", "route", "walk", "drive", "cycle", "navigate", "travel"])

    @Parameter(title: "Destination")
    var destination: CLPlacemark

    @Parameter(title: "Travel By", default: .walk)
    var mode: TravelModeOption

    @Parameter(title: "Start",
               description: "Left empty, the route starts where the location is set now.")
    var start: CLPlacemark?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$mode) to \(\.$destination)") {
            \.$start
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let to = try destination.requiredCoordinate()
        let from = try start?.requiredCoordinate()
        let message = try await Shortcuts.run("Travel to Place by \(mode.rawValue)") { () -> String in
            try await Shortcuts.ensureTunnel(for: self)
            let planned = try await LocationManager.shared.travel(
                to: RouteStop(coordinate: to, name: destination.shortcutName),
                from: from.map { RouteStop(coordinate: $0, name: start?.shortcutName) },
                by: mode.mode)
            return PlayGPXRouteIntent.started(distance: planned.distance, duration: planned.duration)
        }
        return .result(dialog: Shortcuts.dialog(message))
    }
}

struct StopRouteIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Route"
    static let description = IntentDescription(
        "Stops a route that's playing. The location stays where the route got to, until Reset Location.",
        categoryName: "Location Spoofing",
        searchKeywords: ["spoof", "pause", "route"])

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let stopped = try await Shortcuts.run("Stop Route") {
            LocationManager.shared.stopRouteForShortcut()
        }
        return .result(dialog: stopped ? Shortcuts.dialog(L("Route stopped. The device stays where it got to."))
                                       : Shortcuts.dialog(L("No route is playing.")))
    }
}

// MARK: - Helpers

extension CLPlacemark {
    /// A placemark at `coordinate` under `name`, for actions to hand on.
    static func at(_ coordinate: CLLocationCoordinate2D, named name: String?) -> CLPlacemark {
        CLPlacemark(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    name: name, postalAddress: nil)
    }

    /// What to call the place: its name, else its street or town.
    var shortcutName: String? {
        [name, thoroughfare, locality].lazy.compactMap { $0 }.first { !$0.isEmpty }
    }

    /// The place's coordinate, or the error an action stops with without one.
    func requiredCoordinate() throws -> CLLocationCoordinate2D {
        guard let coordinate = location?.coordinate, LocationManager.isValid(coordinate) else {
            throw ShortcutError(L("That place has no coordinates. Pick it on the map, or type its address."))
        }
        return coordinate
    }
}
