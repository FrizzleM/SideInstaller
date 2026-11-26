import SwiftUI
import MapKit
import CoreLocation
import UniformTypeIdentifiers

// MARK: - Developer disk image

/// Apple's developer disk image in the two forms iOS takes it in, and where
/// each is stored. Having it on the device enables DVT services such as
/// location simulation, and debugserver for JIT. Downloaded on first use
/// rather than bundled.
///
/// Source: doronz88/DeveloperDiskImage (the same mirror StikDebug uses). These
/// are Apple's unmodified files, which the device has Apple personalize for it.
enum DeveloperDiskImage {

    enum Variant: CaseIterable {
        /// Mounted by the image mounter. Each of its build identities names a
        /// chip and board, so it only covers the devices Xcode knew when it was
        /// built: 27.1's stops at iPhone18,5.
        case personalized
        /// Installed by cryptexd as a Cryptex1. Its build identity names no
        /// device (`Cryptex1,UseProductClass`), so newer iPhones take it too,
        /// as the mirror's README says.
        case cryptex

        /// The mirror's folder for it.
        fileprivate var folder: String {
            switch self {
            case .personalized: "Xcode_iOS_DDI_Personalized"
            case .cryptex: "Xcode_iOS_DDI_Cryptex"
            }
        }

        /// Files to download (same name remotely and locally). The mirror
        /// rewrites the cryptex's BuildManifest.plist to name these, so its
        /// folder loads as a Restore directory as it is.
        fileprivate var files: [String] {
            switch self {
            case .personalized:
                ["BuildManifest.plist", "Image.dmg", "Image.dmg.trustcache"]
            case .cryptex:
                ["BuildManifest.plist", "Image.dmg", "Image.dmg.trustcache",
                 "Image.dmg.cryptex_info", "Image.dmg.root_hash"]
            }
        }

        /// Where its files are kept. The personalized image keeps the folder
        /// it always had.
        var directory: URL {
            switch self {
            case .personalized:
                URL.documentsDirectory.appendingPathComponent("DDI", isDirectory: true)
            case .cryptex:
                URL.documentsDirectory.appendingPathComponent("DDI-Cryptex", isDirectory: true)
            }
        }

        /// What the log calls it.
        var logName: String {
            switch self {
            case .personalized: "personalized image"
            case .cryptex: "cryptex"
            }
        }
    }

    /// From iOS 26.4 the image goes on as a cryptex, as StikDebug installs it
    /// there (and pymobiledevice3 over a tunnel).
    static var installsAsCryptex: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0))
    }

    /// The forms to try on this iOS, best first. From 26.4 the personalized
    /// image is the fallback, for an iPhone its identities cover.
    static var variants: [Variant] {
        installsAsCryptex ? [.cryptex, .personalized] : [.personalized]
    }

    /// The form tried first.
    static var preferred: Variant { variants[0] }

    static var imagePath: String { Variant.personalized.directory.appendingPathComponent("Image.dmg").path }
    static var trustcachePath: String { Variant.personalized.directory.appendingPathComponent("Image.dmg.trustcache").path }
    static var manifestPath: String { Variant.personalized.directory.appendingPathComponent("BuildManifest.plist").path }
    /// The cryptex's Restore directory, which cryptex1_assets_load reads.
    static var cryptexDirectory: String { Variant.cryptex.directory.path }

    /// True when the form tried first is on disk.
    static var isDownloaded: Bool { isDownloaded(preferred) }

    /// True when all of `variant`'s files are on disk and non-empty.
    static func isDownloaded(_ variant: Variant) -> Bool {
        variant.files.allSatisfy { name in
            let path = variant.directory.appendingPathComponent(name).path
            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            return (attributes?[.size] as? Int ?? 0) > 0
        }
    }

    /// Fetches whichever of the preferred form's files are missing.
    static func downloadMissing(progress: @escaping (Double) -> Void) async throws {
        try await downloadMissing(preferred, progress: progress)
    }

    /// Fetch whichever of `variant`'s files are missing, reporting 0…1 across
    /// the whole set rather than per file.
    static func downloadMissing(_ variant: Variant, progress: @escaping (Double) -> Void) async throws {
        let directory = variant.directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let missing = variant.files.filter { name in
            let path = directory.appendingPathComponent(name).path
            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            return (attributes?[.size] as? Int ?? 0) == 0
        }
        guard !missing.isEmpty else { progress(1); return }

        let baseURL = "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/\(variant.folder)"
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
            Engine.shared.log("DDI: downloaded \(name) (\(variant.logName)).")
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

// MARK: - Imported routes

extension UTType {
    /// GPX, declared in Info.plist under the identifier other apps use for it.
    /// Without the declaration the picker shows .gpx files but won't let them
    /// be selected.
    static let gpx = UTType(importedAs: "com.topografix.gpx", conformingTo: .xml)
    /// KML, the format of Google Earth and My Maps exports, declared in
    /// Info.plist for the same reason.
    static let kml = UTType(importedAs: "com.google.earth.kml", conformingTo: .xml)

    /// What a route can be imported from: the formats StikDebug reads.
    static var routeFiles: [UTType] {
        var types: [UTType] = [.gpx, .kml, .json, .xml, .commaSeparatedText, .plainText]
        if #available(iOS 18.0, *) { types.insert(.geoJSON, at: 2) }
        return types
    }
}

/// A route read from a file: GPX, KML, GeoJSON, other JSON with latitudes and
/// longitudes, or CSV or plain text with a coordinate on each line, the
/// formats StikDebug imports (`RouteFile`).
///
/// StikDebug takes every point a file has, in file order. Here a file's path
/// wins (a GPX track, then its route; a KML or GeoJSON line), then its single
/// places, so the points of interest a track file often carries don't end up
/// in the path.
struct GPXRoute {
    let name: String
    /// The points in file order, invalid ones dropped.
    let points: [CLLocationCoordinate2D]
    /// When each point was recorded, if every one has a time and they never go
    /// backwards: a GPX `<time>`, or a KML track's `<when>`. Playing "as
    /// recorded" follows these.
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
        let found = try RouteFile.points(in: data, fileName: fileName)
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

/// One point of an imported route, with when it was recorded if the file says.
struct RoutePoint {
    var coordinate: CLLocationCoordinate2D
    var time: Date?

    /// Nil unless `latitude` and `longitude` are a place on Earth.
    init?(latitude: Double, longitude: Double, time: Date? = nil) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        self.coordinate = coordinate
        self.time = time
    }

    /// A pair of numbers in the order a format puts them in, or the other way
    /// round when that order isn't a place and the other is, as StikDebug
    /// reads them.
    init?(_ first: Double, _ second: Double, longitudeFirst: Bool) {
        let (latitude, longitude) = longitudeFirst ? (second, first) : (first, second)
        guard let point = RoutePoint(latitude: latitude, longitude: longitude)
                ?? RoutePoint(latitude: longitude, longitude: latitude) else { return nil }
        self = point
    }
}

/// Reads an imported route's points out of a file. What's in it decides how
/// it's read, not its name: a file saved from the web, or handed over by
/// Shortcuts, often has no extension or the wrong one.
enum RouteFile {
    static func points(in data: Data, fileName: String) throws -> [RoutePoint] {
        switch kind(of: data) {
        case .xml:
            let reader = RouteXMLReader()
            let parser = XMLParser(data: data)
            parser.delegate = reader
            guard parser.parse() else {
                throw EngineError.message(reader.isKML
                    ? unreadable(fileName) : L("Couldn't read %@ as a GPX file.", fileName))
            }
            return reader.best
        case .json:
            guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
                throw EngineError.message(unreadable(fileName))
            }
            return JSONCoordinates.points(in: object)
        case .text:
            guard let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .utf16)
                    ?? String(data: data, encoding: .windowsCP1252) else {
                throw EngineError.message(unreadable(fileName))
            }
            return TextCoordinates.points(in: text)
        }
    }

    private enum Kind { case xml, json, text }

    /// XML starts with `<`, JSON with `{` or `[`; anything else is read as
    /// lines of coordinates.
    private static func kind(of data: Data) -> Kind {
        let start = String(decoding: data.prefix(256), as: UTF8.self)
            .drop(while: { $0.isWhitespace || $0 == "\u{FEFF}" })
        switch start.first {
        case "<"?: return .xml
        case "{"?, "["?: return .json
        default: return .text
        }
    }

    private static func unreadable(_ fileName: String) -> String {
        L("Couldn't read %@ as a route. Import a GPX, KML or GeoJSON file, or one with a latitude and longitude on each line.", fileName)
    }
}

/// Collects a GPX or KML file's points, each with its time if it has one.
///
/// GPX: `trkpt`, `rtept` and `wpt`, each with its `<time>`. KML: the
/// `coordinates` of a `LineString` or `LinearRing` (the path) and of a `Point`
/// (a place), and a `gx:Track`'s `gx:coord`s, timed by its `when`s.
private final class RouteXMLReader: NSObject, XMLParserDelegate {
    private(set) var trackPoints: [RoutePoint] = []
    private(set) var routePoints: [RoutePoint] = []
    private(set) var waypoints: [RoutePoint] = []
    /// True when the root element is `kml`.
    private(set) var isKML = false

    /// The path when there is one: a track, then a route; else the places.
    var best: [RoutePoint] {
        [trackPoints, routePoints, waypoints].first { !$0.isEmpty } ?? []
    }

    /// The GPX point being read and the element it came from.
    private var current: (element: String, point: RoutePoint)?
    /// The text of the element being read, when it's one that's kept: a GPX
    /// `time`, or a KML `coordinates`, `when` or `gx:coord`.
    private var text: String?
    private var sawRoot = false
    /// The KML geometry whose `coordinates` come next: point, linestring or
    /// linearring.
    private var geometry: String?
    /// Inside a KML `gx:Track`, its `when`s and `gx:coord`s so far, which it
    /// lists separately in the same order.
    private var inTrack = false
    private var trackTimes: [Date?] = []
    private var trackCoordinates: [RoutePoint] = []

    // Not `ISO8601DateFormatter`, which took 4 of the 5 seconds a
    // 50,000-point track needed to load.
    private let timeStyle = Date.ISO8601FormatStyle()
    private let fractionalTimeStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// Element names without a namespace prefix (`gpx:trkpt` → `trkpt`,
    /// `gx:coord` → `coord`).
    private func localName(_ name: String) -> String {
        String(name.split(separator: ":").last ?? Substring(name)).lowercased()
    }

    private func time(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return (try? timeStyle.parse(text)) ?? (try? fractionalTimeStyle.parse(text))
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        let name = localName(elementName)
        if !sawRoot {
            sawRoot = true
            isKML = name == "kml"
        }
        switch name {
        case "trkpt", "rtept", "wpt":
            guard let latitude = Double(attributes["lat"] ?? ""),
                  let longitude = Double(attributes["lon"] ?? ""),
                  let point = RoutePoint(latitude: latitude, longitude: longitude) else { return }
            current = (name, point)
        case "time" where current != nil:
            text = ""
        case "point", "linestring", "linearring":
            geometry = name
        case "coordinates" where geometry != nil:
            text = ""
        case "track":
            inTrack = true
            trackTimes = []
            trackCoordinates = []
        case "when" where inTrack, "coord" where inTrack:
            text = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text? += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        switch localName(elementName) {
        case "time":
            if text != nil { current?.point.time = time(text) }
            text = nil
        case "trkpt":
            if let current { trackPoints.append(current.point) }
            current = nil
        case "rtept":
            if let current { routePoints.append(current.point) }
            current = nil
        case "wpt":
            if let current { waypoints.append(current.point) }
            current = nil
        case "coordinates":
            if let text, let geometry {
                // `longitude,latitude[,altitude]`, one tuple per space.
                let points = text.split(whereSeparator: \.isWhitespace).compactMap { tuple -> RoutePoint? in
                    let values = tuple.split(separator: ",").compactMap { Double($0) }
                    guard values.count >= 2 else { return nil }
                    return RoutePoint(latitude: values[1], longitude: values[0])
                }
                if geometry == "point" { waypoints += points } else { trackPoints += points }
            }
            text = nil
        case "point", "linestring", "linearring":
            geometry = nil
        case "when" where inTrack:
            trackTimes.append(time(text))
            text = nil
        case "coord" where inTrack:
            // `longitude latitude altitude`.
            let values = (text ?? "").split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
            if values.count >= 2, let point = RoutePoint(latitude: values[1], longitude: values[0]) {
                trackCoordinates.append(point)
            }
            text = nil
        case "track":
            // The times only fit when there's one per point.
            let timed = trackTimes.count == trackCoordinates.count
            for (index, point) in trackCoordinates.enumerated() {
                var point = point
                point.time = timed ? trackTimes[index] : nil
                trackPoints.append(point)
            }
            inTrack = false
            trackTimes = []
            trackCoordinates = []
        default:
            break
        }
    }
}

/// Coordinates out of JSON: GeoJSON, whose positions are `[longitude,
/// latitude]`, or any other JSON whose objects carry latitude and longitude
/// keys, or whose pairs are `[latitude, longitude]`, as StikDebug reads it.
/// GeoJSON's lines and polygon rings are the path, its points the places;
/// anything else is the path, in the order it's listed.
enum JSONCoordinates {
    static func points(in object: Any) -> [RoutePoint] {
        var path: [RoutePoint] = []
        var places: [RoutePoint] = []
        collect(object, path: &path, places: &places)
        return path.isEmpty ? places : path
    }

    private static func collect(_ object: Any, path: inout [RoutePoint], places: inout [RoutePoint]) {
        if let dictionary = object as? [String: Any] {
            let coordinates = dictionary["coordinates"]
            switch (dictionary["type"] as? String)?.lowercased() {
            case "featurecollection":
                for feature in dictionary["features"] as? [Any] ?? [] {
                    collect(feature, path: &path, places: &places)
                }
                return
            case "feature":
                if let geometry = dictionary["geometry"] { collect(geometry, path: &path, places: &places) }
                return
            case "geometrycollection":
                for geometry in dictionary["geometries"] as? [Any] ?? [] {
                    collect(geometry, path: &path, places: &places)
                }
                return
            case "point":
                if let point = position(coordinates) { places.append(point) }
                return
            case "multipoint":
                places += positions(coordinates)
                return
            case "linestring":
                path += positions(coordinates)
                return
            case "multilinestring":
                for line in coordinates as? [Any] ?? [] { path += positions(line) }
                return
            case "polygon":
                // The outer ring.
                path += positions((coordinates as? [Any])?.first)
                return
            case "multipolygon":
                for polygon in coordinates as? [Any] ?? [] { path += positions((polygon as? [Any])?.first) }
                return
            default:
                break
            }
            if let point = keyedPoint(dictionary) {
                path.append(point)
                return
            }
            // A wrapper: its keys come in no particular order.
            for value in dictionary.values { collect(value, path: &path, places: &places) }
            return
        }
        guard let array = object as? [Any] else { return }
        if array.count >= 2, let first = number(array[0]), let second = number(array[1]) {
            if let point = RoutePoint(first, second, longitudeFirst: false) { path.append(point) }
            return
        }
        for element in array { collect(element, path: &path, places: &places) }
    }

    /// A GeoJSON position.
    private static func position(_ value: Any?) -> RoutePoint? {
        guard let pair = value as? [Any], pair.count >= 2,
              let longitude = number(pair[0]), let latitude = number(pair[1]) else { return nil }
        return RoutePoint(latitude: latitude, longitude: longitude)
    }

    private static func positions(_ value: Any?) -> [RoutePoint] {
        (value as? [Any] ?? []).compactMap(position)
    }

    /// An object with latitude and longitude keys, in any case.
    private static func keyedPoint(_ dictionary: [String: Any]) -> RoutePoint? {
        let keyed = Dictionary(dictionary.map { ($0.key.lowercased(), $0.value) }) { first, _ in first }
        guard let latitude = ["latitude", "lat"].lazy.compactMap({ keyed[$0].flatMap(number) }).first,
              let longitude = ["longitude", "lon", "lng", "long"].lazy.compactMap({ keyed[$0].flatMap(number) }).first
        else { return nil }
        return RoutePoint(latitude: latitude, longitude: longitude)
    }

    private static func number(_ value: Any) -> Double? {
        // A JSON `true` is an NSNumber too.
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            return number.doubleValue
        }
        return (value as? String).flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }
}

/// Coordinates out of CSV or plain text, one point a line: from the columns
/// a header line names (`lat` or `latitude`, `lon`, `lng`, `long` or
/// `longitude`), or else the first two numbers on the line, latitude first,
/// as maps copy them. StikDebug reads text the same way.
enum TextCoordinates {
    static func points(in text: String) -> [RoutePoint] {
        var columns: (latitude: Int, longitude: Int)?
        var points: [RoutePoint] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split { $0 == "," || $0 == ";" || $0 == "\t" }
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if columns == nil, let header = headerColumns(fields) {
                columns = header
                continue
            }
            if let columns, fields.indices.contains(max(columns.latitude, columns.longitude)),
               let latitude = numbers(in: fields[columns.latitude]).first,
               let longitude = numbers(in: fields[columns.longitude]).first {
                if let point = RoutePoint(latitude: latitude, longitude: longitude) { points.append(point) }
                continue
            }
            let values = numbers(in: String(line))
            if values.count >= 2, let point = RoutePoint(values[0], values[1], longitudeFirst: false) {
                points.append(point)
            }
        }
        return points
    }

    private static func headerColumns(_ fields: [String]) -> (latitude: Int, longitude: Int)? {
        let names = fields.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
        guard let latitude = names.firstIndex(where: { $0 == "lat" || $0 == "latitude" }),
              let longitude = names.firstIndex(where: { ["lon", "lng", "long", "longitude"].contains($0) })
        else { return nil }
        return (latitude, longitude)
    }

    private static let number = #/[-+]?(?:\d+(?:\.\d*)?|\.\d+)/#

    private static func numbers(in text: String) -> [Double] {
        text.matches(of: number).compactMap { Double($0.output) }
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
///
/// One for the app, so Shortcuts actions (LocationShortcuts.swift) drive the
/// same session as the page, even when iOS starts the app in the background
/// for them and no page exists.
@MainActor
final class LocationManager: ObservableObject {

    static let shared = LocationManager()

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
        _ = try await engine.prepareLocationSimulation { fraction in
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
        guard Self.isValid(coordinate) else {
            lastError = ErrorHelp.explained(L("That isn't a valid coordinate."))
            return
        }
        cancelPlayback()
        isBusy = true
        lastError = nil
        lastSuccess = nil
        Task {
            do {
                try await performSimulate(coordinate)
                lastSuccess = L("Location set to %@.", name ?? Self.format(coordinate))
            } catch {
                lastError = message(error)
            }
            isBusy = false
        }
    }

    /// Sets up if needed, sets `coordinate` and keeps re-sending it. The
    /// caller holds `isBusy`.
    private func performSimulate(_ coordinate: CLLocationCoordinate2D) async throws {
        do {
            try await ensureReady()
            try await engine.simulateLocation(latitude: coordinate.latitude,
                                              longitude: coordinate.longitude)
            simulated = coordinate
            keepAlive.startAudio()
            startResending()
            // A planned route starting at the device would start elsewhere now.
            if startsFromDevice { dropPlannedRoute() }
            engine.log("Location: simulating \(Self.format(coordinate)).")
        } catch {
            // A dropped session can't be re-used; setup has to run again.
            stage = .notReady
            simulated = nil
            stopResending()
            throw error
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
                try await performStop()
                lastSuccess = L("Location reset. The device is using its own again.")
            } catch {
                lastError = message(error)
            }
            isBusy = false
        }
    }

    /// Stops playback and re-sending, gives the device its own location back,
    /// and leaves setup to run again next time, even when the reset fails.
    /// The caller holds `isBusy`.
    private func performStop() async throws {
        cancelPlayback()
        stopResending()
        defer {
            simulated = nil
            if startsFromDevice { dropPlannedRoute() }
            stage = .notReady
            keepAlive.stopAll()
        }
        try await engine.stopSimulatingLocation()
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
    @discardableResult
    func savePlace(named name: String, at coordinate: CLLocationCoordinate2D) -> SavedPlace {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = SavedPlace(name: trimmed.isEmpty ? Self.format(coordinate) : trimmed,
                               latitude: coordinate.latitude,
                               longitude: coordinate.longitude)
        savedPlaces.append(place)
        storeSavedPlaces()
        return place
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
        // Siri's "Spoof my location to …" phrases name the saved places.
        SideInstallerShortcuts.updateAppShortcutParameters()
    }

    // MARK: Routes

    /// Reads a route file (GPX, KML, GeoJSON, JSON, CSV or text) off the main
    /// thread. A path is kept as `route`; a
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
        guard !timeline.points.isEmpty else { return }
        isBusy = true
        lastError = nil
        lastSuccess = nil
        Task {
            do {
                try await beginPlayback(timeline, name: name)
            } catch {
                lastError = message(error)
            }
            isBusy = false
        }
    }

    /// Sets up if needed, puts the device on the timeline's first point and
    /// starts moving it. The caller holds `isBusy`.
    private func beginPlayback(_ timeline: RouteTimeline, name: String) async throws {
        guard let start = timeline.points.first else { return }
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
            throw error
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

    // MARK: Shortcuts
    //
    // What the Shortcuts actions run (LocationShortcuts.swift): the page's own
    // steps, each waiting its turn behind whatever the page is doing and
    // returning once the device has the result, which they report themselves.
    // A popup left from an earlier tap would be out of date by then, so it
    // goes.

    /// Sets the device's location to `coordinate` and keeps re-sending it, as
    /// Set location does. Stops a playing route.
    func setLocation(_ coordinate: CLLocationCoordinate2D) async throws {
        guard Self.isValid(coordinate) else {
            throw EngineError.message(L("That isn't a valid coordinate."))
        }
        try await beginShortcutStep()
        defer { endShortcutStep() }
        cancelPlayback()
        try await performSimulate(coordinate)
    }

    /// Hands the device its real location back, as Reset to real location
    /// does. Nothing happens when nothing is simulated.
    func resetLocation() async throws {
        try await waitUntilIdle()
        isBusy = true
        defer { isBusy = false }
        lastError = nil
        lastSuccess = nil
        try await performStop()
    }

    /// Loads `imported` as the page's route and plays it at `speed`, in place
    /// of any route playing now.
    func play(_ imported: GPXRoute, at speed: RouteSpeed) async throws {
        try await beginShortcutStep()
        defer { endShortcutStep() }
        cancelPlayback()
        dropPlannedRoute()
        route = imported
        routeSpeed = imported.speeds.contains(speed) ? speed : .walk
        try await beginPlayback(RouteTimeline(route: imported, speed: routeSpeed), name: imported.name)
    }

    /// Plans a route to `destination` over OpenStreetMap and plays it, as
    /// Find route then Play route do. It starts at `start`, or where the
    /// device is simulated now when that's nil.
    func travel(to destination: RouteStop, from start: RouteStop?,
                by mode: TravelMode) async throws -> PlannedRoute {
        try await beginShortcutStep()
        defer { endShortcutStep() }
        guard let origin = start?.coordinate ?? simulated else {
            throw EngineError.message(L("Pick where the route starts, or set a location first."))
        }
        cancelPlayback()
        // The page shows the route as if it had been planned there.
        startsFromDevice = start == nil
        travelMode = mode
        stops = [start, destination].compactMap { $0 }
        isPlanningRoute = true
        var planned: PlannedRoute
        do {
            planned = try await RoutePlanner.plan(through: [origin, destination.coordinate], mode: mode)
        } catch {
            isPlanningRoute = false
            throw error
        }
        isPlanningRoute = false
        planned.deviceStart = start == nil ? origin : nil
        route = nil
        plannedRoute = planned
        engine.log("Location: planned a \(mode.rawValue) route over OpenStreetMap for Shortcuts "
                   + "(\(planned.points.count) points, \(Int(planned.distance)) m, \(Int(planned.duration)) s).")
        try await beginPlayback(planned.timeline, name: "the planned \(mode.rawValue) route")
        return planned
    }

    /// Stops a playing route where it is. False when none was playing.
    @discardableResult
    func stopRouteForShortcut() -> Bool {
        guard isPlayingRoute else { return false }
        endPlayback()
        lastError = nil
        lastSuccess = nil
        engine.log("Location: route stopped.")
        return true
    }

    /// Waits for the page's work, refuses during an install (it rebuilds the
    /// tunnel the session runs over), then takes `isBusy`.
    ///
    /// An action usually runs with SideInstaller in the background, where iOS
    /// gives it only so long, and a first setup (the disk image's download and
    /// mount) or a long drive's plan can take longer. The silent audio that
    /// holds a location keeps the app running through those too.
    private func beginShortcutStep() async throws {
        try await waitUntilIdle()
        guard !engine.isRunning else {
            throw EngineError.message(L("An install is already running. Wait for it to finish, then try again."))
        }
        isBusy = true
        lastError = nil
        lastSuccess = nil
        keepAlive.startAudio()
    }

    /// Ends what `beginShortcutStep` began. The audio plays on only while the
    /// device is being told a location.
    private func endShortcutStep() {
        isBusy = false
        if simulated == nil { keepAlive.stopAll() }
    }

    /// Returns once nothing is setting up, setting or resetting. Setup ends
    /// one way or the other: a stalled download times out.
    private func waitUntilIdle() async throws {
        while isBusy {
            try await Task.sleep(for: .milliseconds(200))
        }
    }

    // MARK: Helpers

    nonisolated static func format(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    nonisolated static func isValid(_ coordinate: CLLocationCoordinate2D) -> Bool {
        (-90...90).contains(coordinate.latitude) && (-180...180).contains(coordinate.longitude)
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
    @Environment(Engine.self) private var engine
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
                VStack(spacing: 16) {
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
            FileImporterRepresentableView(allowedContentTypes: UTType.routeFiles) { urls in
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
        .onAppear {
            manager.prepareQuietly()
            // Show where the device is, which a shortcut may have set while
            // the page was closed.
            if let simulated = manager.simulated { moveMap(to: simulated) }
        }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "location", image: "LocationLogo", title: L("Location spoofing")) {
            statusPill
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        if let progress = manager.routeProgress {
            StatusDot(text: L("Playing route · %d%%", Int(progress.fraction * 100)),
                       color: Theme.positive)
        } else if let simulated = manager.simulated {
            StatusDot(text: LocationManager.format(simulated),
                       color: Theme.positive)
        } else {
            StatusDot(text: L("Not simulating"), color: Theme.warning, idle: true)
        }
    }

    private var vpnNote: some View {
        PanelCard {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(Theme.negative)
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
            VStack(alignment: .leading, spacing: 16) {
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
                                .tint(Theme.warning)
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
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))

                // Icons only where the coordinate and both labels don't fit.
                ViewThatFits(in: .horizontal) {
                    pinActions(labelled: true)
                    pinActions(labelled: false)
                }

                // On first use, the spinner also covers disk image setup.
                Button { manager.simulate(target) } label: {
                    HStack(spacing: 8) {
                        if manager.isBusy {
                            ProgressView()
                            Text(L("Setting"))
                        } else {
                            Image(systemName: "location")
                            Text(L("Set location"))
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSetLocation)

                if manager.isSimulating {
                    Button { manager.stop() } label: {
                        Label(L("Reset to real location"), systemImage: "location.slash")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    .controlSize(.regular)
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
        .buttonStyle(SecondaryButtonStyle(), sound: .tap)
        .controlSize(.small)
    }

    @ViewBuilder
    private func pinActionLabel(_ title: String, systemImage: String, labelled: Bool) -> some View {
        if labelled {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
        } else {
            Image(systemName: systemImage)
                .font(.caption.weight(.medium))
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
        HStack(spacing: 8) {
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
            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
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
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle(L("Plan a route"), systemImage: "signpost.right.and.left")

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
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Theme.positive))
                    } trailing: {
                        EmptyView()
                    }
                }
                ForEach(Array(manager.stops.enumerated()), id: \.element.id) { index, stop in
                    stopRow(title: stop.name ?? L("Stop %d", index + 1), coordinate: stop.coordinate) {
                        Text(verbatim: "\(index + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Theme.warning))
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
                        .font(.caption.weight(.medium))
                }
                Spacer()
                Button(role: .destructive) { manager.removeAllStops() } label: {
                    Label(L("Clear stops"), systemImage: "trash")
                        .font(.caption.weight(.medium))
                }
                .tint(Theme.negative)
            }
            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
            .controlSize(.small)
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
                    .font(.subheadline.weight(.medium))
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
            HStack(spacing: 8) {
                if manager.isPlanningRoute {
                    ProgressView()
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
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Self.formatDistance(planned.distance)) · "
                     + Self.formatDuration(planned.duration))
                    .font(.subheadline.weight(.medium))
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
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.control))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stretch.name ?? L("No street name"))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(Self.roadDetail(stretch))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
            .fill(Theme.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
            .strokeBorder(Theme.hairline, lineWidth: 1))
        .animation(.smooth(duration: 0.3), value: stretch)
    }

    // MARK: Saved places

    private var savedPlacesCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L("Saved places"), systemImage: "bookmark")
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
        HStack(spacing: 8) {
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
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(LocationManager.format(place.coordinate))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
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
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle(L("Play a GPX route"),
                             systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                if let route = manager.route {
                    loadedRoute(route)
                } else {
                    Text(L("Import a GPX, KML or GeoJSON file, or a list of coordinates, and the device moves along it at the speed you pick, then stays at its last point."))
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
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(), sound: .tap)
                    .controlSize(.regular)
                    .disabled(manager.isImportingRoute)
                }
            }
        }
    }

    @ViewBuilder
    private func loadedRoute(_ route: GPXRoute) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.subheadline.weight(.medium))
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
                    .font(.footnote.weight(.medium))
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
            VStack(alignment: .leading, spacing: 4) {
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
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(), sound: .tap)
            .controlSize(.regular)
        } else {
            Button { manager.playRoute() } label: {
                HStack(spacing: 8) {
                    if manager.isBusy {
                        ProgressView()
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

    static func formatDistance(_ meters: CLLocationDistance) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(Localizer.locale))
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
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
        SectionTitle(title: title, systemImage: systemImage)
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
                    .padding(8)
            case .unlimited:
                Stripes()
                    .stroke(.black, lineWidth: 1.6)
                    .clipShape(Circle())
                    .padding(8)
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
