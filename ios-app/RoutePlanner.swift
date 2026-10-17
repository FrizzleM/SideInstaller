import Foundation
import CoreLocation
import MapKit

// MARK: - Travel modes

/// How a planned route is travelled: which roads it may take, and how fast it
/// goes along them.
enum TravelMode: String, CaseIterable, Identifiable {
    case drive
    case cycle
    case walk

    var id: Self { self }

    var title: String {
        switch self {
        case .drive: return L("Drive")
        case .cycle: return L("Cycle")
        case .walk:  return L("Walk")
        }
    }

    var systemImage: String {
        switch self {
        case .drive: return "car.fill"
        case .cycle: return "bicycle"
        case .walk:  return "figure.walk"
        }
    }

    /// Valhalla's costing model for it.
    fileprivate var costing: String {
        switch self {
        case .drive: return "auto"
        case .cycle: return "bicycle"
        case .walk:  return "pedestrian"
        }
    }

    /// What a stretch the server gave no speed for goes at (the paces in
    /// `RouteSpeed`).
    fileprivate var fallbackMetersPerSecond: CLLocationSpeed {
        switch self {
        case .drive: return 13.4
        case .cycle: return 5.5
        case .walk:  return 1.4
        }
    }
}

// MARK: - Stops

/// A place a planned route goes to. Stops are visited in the order they're
/// listed.
struct RouteStop: Identifiable, Equatable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    /// The place's name, once the lookup answers; nil shows the coordinate.
    var name: String?

    init(coordinate: CLLocationCoordinate2D, name: String?) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        self.name = name
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Speed limits

/// A speed as a sign shows it: km/h, or mph where roads are signed in miles.
struct RoadSpeed: Equatable {
    let value: Int
    let inMiles: Bool

    /// Countries (ISO codes) that sign roads in mph.
    static let mileCountries: Set<String> = [
        "US", "PR", "GU", "VI", "AS", "MP", "GB", "IM", "JE", "GG", "LR", "BS", "BZ", "AG", "DM",
        "GD", "LC", "KN", "VC", "KY", "TC", "VG", "AI", "MS", "FK", "SH",
    ]

    /// `kmh` (how Valhalla gives every limit) as signed in `country`. An mph
    /// limit comes back as the number on its sign; an estimate goes to the
    /// nearest 5 mph, as signs go.
    init(kmh: Int, country: String?, estimate: Bool = false) {
        inMiles = country.map(Self.mileCountries.contains) ?? false
        guard inMiles else {
            value = kmh
            return
        }
        let mph = Double(kmh) / 1.609344
        value = estimate ? max(5, Int((mph / 5).rounded()) * 5) : Int(mph.rounded())
    }

    var metersPerSecond: CLLocationSpeed {
        inMiles ? Double(value) * 0.44704 : Double(value) / 3.6
    }
}

/// The speed limit a drive keeps to on one stretch.
enum SpeedLimit: Equatable {
    /// As mapped in OpenStreetMap, or mapped on the rest of the same street.
    case posted(RoadSpeed)
    /// No limit, as on parts of the German Autobahn. Driven at 130 km/h, the
    /// advisory speed there.
    case unlimited
    /// Nothing mapped for the road: the usual limit for its kind of road.
    case estimated(RoadSpeed)

    var metersPerSecond: CLLocationSpeed {
        switch self {
        case .posted(let speed), .estimated(let speed): return speed.metersPerSecond
        case .unlimited:                                return 130 / 3.6
        }
    }

    var isEstimated: Bool {
        if case .estimated = self { return true }
        return false
    }
}

// MARK: - Planned routes

/// A route planned over OpenStreetMap, and how fast to go along each part of
/// it.
struct PlannedRoute: Identifiable {
    /// A run of the route along one road, all at one speed.
    struct Stretch: Equatable {
        /// The road's name, if it has one.
        let name: String?
        /// Nil when the speed isn't a limit: walking, cycling, ferries, and
        /// parts Valhalla couldn't give limits for.
        let limit: SpeedLimit?
        let metersPerSecond: CLLocationSpeed
    }

    let id = UUID()
    let mode: TravelMode
    /// Where the device was when the route was planned from it; nil when it
    /// starts at the first stop.
    var deviceStart: CLLocationCoordinate2D?
    let points: [CLLocationCoordinate2D]
    let stretches: [Stretch]
    /// `stretchIndex[i]` is the stretch the segment from `points[i]` to
    /// `points[i + 1]` is on.
    let stretchIndex: [Int]
    let timeline: RouteTimeline
    /// Length along `points`, in meters.
    let distance: CLLocationDistance
    /// How much of a drive (0…1, by distance) goes by a mapped limit rather
    /// than an estimate. Nil when the route has no limits at all.
    let mappedLimitShare: Double?

    var duration: TimeInterval { timeline.duration }

    init(mode: TravelMode, points: [CLLocationCoordinate2D], stretches: [Stretch],
         stretchIndex: [Int]) {
        self.mode = mode
        self.points = points
        self.stretches = stretches
        self.stretchIndex = stretchIndex
        var distance: CLLocationDistance = 0
        var mapped: CLLocationDistance = 0
        var limited: CLLocationDistance = 0
        var speeds: [CLLocationSpeed] = []
        speeds.reserveCapacity(stretchIndex.count)
        for (segment, index) in stretchIndex.enumerated() {
            let stretch = stretches[index]
            let meters = CLLocation(latitude: points[segment].latitude,
                                    longitude: points[segment].longitude)
                .distance(from: CLLocation(latitude: points[segment + 1].latitude,
                                           longitude: points[segment + 1].longitude))
            distance += meters
            if let limit = stretch.limit {
                limited += meters
                if !limit.isEstimated { mapped += meters }
            }
            speeds.append(stretch.metersPerSecond)
        }
        self.distance = distance
        mappedLimitShare = limited > 0 ? mapped / limited : nil
        timeline = RouteTimeline(points: points, metersPerSecond: speeds)
    }

    /// The stretch a playing route is on.
    func stretch(atSegment segment: Int) -> Stretch? {
        guard stretchIndex.indices.contains(segment) else {
            return stretchIndex.last.map { stretches[$0] }
        }
        return stretches[stretchIndex[segment]]
    }
}

// MARK: - Planning

/// Plans routes on FOSSGIS's public Valhalla server, which routes over
/// OpenStreetMap.
///
/// A drive takes a `route` request for the path, then a `trace_attributes`
/// request per leg for the speed limit of each road on it: the route itself
/// only carries Valhalla's travel-time estimates, which in town are around
/// half the limit. Walking and cycling go at those estimates (Valhalla's
/// walking and cycling paces), so they skip the second step.
///
/// The OSRM servers that also run on OpenStreetMap data don't return speed
/// limits (`annotations=maxspeed` is refused as malformed).
enum RoutePlanner {

    /// Points sent in one `trace_attributes` request. 4,928 (Milan to Rome)
    /// went through in one; longer legs are split.
    private static let traceChunk = 4000

    /// A route from the first of `waypoints` through each of the others in
    /// turn.
    static func plan(through waypoints: [CLLocationCoordinate2D],
                     mode: TravelMode) async throws -> PlannedRoute {
        let request = RouteRequest(locations: waypoints.map(ValhallaLocation.init),
                                   costing: mode.costing)
        let response: RouteResponse = try await Valhalla.shared.request("route", request)

        var points: [CLLocationCoordinate2D] = []
        var stretches: [PlannedRoute.Stretch] = []
        var stretchIndex: [Int] = []
        let fallback = PlannedRoute.Stretch(name: nil, limit: nil,
                                            metersPerSecond: mode.fallbackMetersPerSecond)
        for leg in response.trip.legs {
            let legPoints = Polyline.decode(leg.shape)
            guard legPoints.count >= 2 else { continue }
            var speeds = LegSpeeds(segments: legPoints.count - 1)
            if mode == .drive {
                let edges = try await traceEdges(along: legPoints)
                for (edge, limit) in zip(edges, resolveLimits(edges)) {
                    let stretch: PlannedRoute.Stretch
                    if let limit {
                        stretch = .init(name: edge.names?.first, limit: limit,
                                        metersPerSecond: limit.metersPerSecond)
                    } else if let kmh = edge.speed, kmh > 0 {
                        // A ferry, at its own speed.
                        stretch = .init(name: edge.names?.first, limit: nil,
                                        metersPerSecond: kmh / 3.6)
                    } else {
                        continue
                    }
                    speeds.assign(stretch, from: edge.beginShapeIndex, to: edge.endShapeIndex)
                }
            }
            // On foot and by bike, and wherever a drive got no limits:
            // Valhalla's own pace for each maneuver.
            for maneuver in leg.maneuvers ?? [] where maneuver.time > 0 && maneuver.length > 0 {
                speeds.assign(.init(name: maneuver.streetNames?.first, limit: nil,
                                    metersPerSecond: maneuver.length * 1000 / maneuver.time),
                              from: maneuver.beginShapeIndex, to: maneuver.endShapeIndex)
            }
            let (legStretches, legIndex) = speeds.resolved(fallback: fallback)
            // Each leg starts where the one before ended; keep that point once.
            points += points.isEmpty ? legPoints : Array(legPoints.dropFirst())
            stretchIndex += legIndex.map { $0 + stretches.count }
            stretches += legStretches
        }
        guard points.count >= 2 else { throw ValhallaError.noRoute }
        return PlannedRoute(mode: mode, points: points, stretches: stretches,
                            stretchIndex: stretchIndex)
    }

    /// Valhalla's roads along a drive's `points`, with their limits, in order.
    /// Indices are into `points`. A part Valhalla can't follow is left out,
    /// for the route's own estimates to cover.
    private static func traceEdges(along points: [CLLocationCoordinate2D]) async throws -> [TraceEdge] {
        var edges: [TraceEdge] = []
        for piece in pieces(of: points, in: 0...(points.count - 1), maxPoints: traceChunk) {
            if let found = try await trace(points, piece, edgeWalk: true) {
                edges += found
                continue
            }
            // Valhalla couldn't follow its own route edge by edge, as when the
            // route starts on a private road (London's New Palace Yard).
            // Map matching copes, over at most 200 km a request.
            for part in pieces(of: points, in: piece, maxMeters: mapMatchMeters) {
                edges += try await trace(points, part, edgeWalk: false) ?? []
            }
        }
        return edges
    }

    /// Kept under the server's 200 km limit for map matching.
    private static let mapMatchMeters: CLLocationDistance = 150_000

    /// The edges along `points[range]`, or nil when Valhalla can't match them.
    ///
    /// Edge walking follows the shape exactly and says where each edge begins
    /// and ends in it. Map matching says instead which edge each point is on;
    /// a segment is taken to be on its end point's edge, which agreed with
    /// edge walking on 99.7% of segments in Milan and 99.9% from Munich to
    /// Augsburg.
    private static func trace(_ points: [CLLocationCoordinate2D], _ range: ClosedRange<Int>,
                              edgeWalk: Bool) async throws -> [TraceEdge]? {
        let request = TraceRequest(shape: points[range].map(ValhallaLocation.init),
                                   shapeMatch: edgeWalk ? "edge_walk" : "map_snap")
        let response: TraceResponse
        do {
            response = try await Valhalla.shared.request("trace_attributes", request)
        } catch let error as ValhallaError where error.isBadRequest {
            // Usually "edge_walk algorithm failed to find exact route match".
            return nil
        }
        var edges = response.edges
        if !edgeWalk {
            let matched = response.matchedPoints ?? []
            func edgeIndex(at point: Int) -> Int? {
                matched.indices.contains(point) ? matched[point].edgeIndex : nil
            }
            var spans = [Range<Int>?](repeating: nil, count: edges.count)
            for segment in 0..<(range.count - 1) {
                guard let edge = edgeIndex(at: segment + 1) ?? edgeIndex(at: segment),
                      spans.indices.contains(edge) else { continue }
                spans[edge] = spans[edge].map { min($0.lowerBound, segment)..<(segment + 1) }
                    ?? segment..<(segment + 1)
            }
            for (index, span) in spans.enumerated() {
                edges[index].beginShapeIndex = span?.lowerBound ?? 0
                edges[index].endShapeIndex = span?.upperBound ?? 0
            }
        }
        let countries = response.admins?.map(\.countryCode) ?? []
        return edges.map { edge in
            var edge = edge.shifted(by: range.lowerBound)
            if let admin = edge.endNode?.adminIndex, countries.indices.contains(admin) {
                edge.country = countries[admin]
            }
            return edge
        }
    }

    /// `range` cut into consecutive pieces of at most `maxPoints` points or
    /// about `maxMeters`, each starting on the point the last one ended on.
    private static func pieces(of points: [CLLocationCoordinate2D], in range: ClosedRange<Int>,
                               maxPoints: Int = .max,
                               maxMeters: CLLocationDistance = .infinity) -> [ClosedRange<Int>] {
        var pieces: [ClosedRange<Int>] = []
        var start = range.lowerBound
        var meters: CLLocationDistance = 0
        for index in range.dropFirst() {
            meters += CLLocation(latitude: points[index - 1].latitude, longitude: points[index - 1].longitude)
                .distance(from: CLLocation(latitude: points[index].latitude, longitude: points[index].longitude))
            if index - start + 1 >= maxPoints || meters >= maxMeters || index == range.upperBound {
                pieces.append(start...index)
                start = index
                meters = 0
            }
        }
        return pieces
    }

    /// The limit to drive each edge at; nil for a ferry.
    ///
    /// An edge with no limit mapped takes the nearest one mapped on the same
    /// street: OpenStreetMap often has a street in pieces, a few of them
    /// untagged. Failing that, the usual limit for its kind of road.
    private static func resolveLimits(_ edges: [TraceEdge]) -> [SpeedLimit?] {
        let mapped: [SpeedLimit?] = edges.map { edge in
            switch edge.speedLimit {
            case .kmh(let kmh)?: return .posted(RoadSpeed(kmh: kmh, country: edge.country))
            case .unlimited?:    return .unlimited
            default:             return nil
            }
        }
        return edges.indices.map { index in
            if let limit = mapped[index] { return limit }
            let edge = edges[index]
            if edge.isFerry { return nil }
            return sameStreetLimit(index, edges, mapped)
                ?? .estimated(RoadSpeed(kmh: typicalLimit(edge), country: edge.country, estimate: true))
        }
    }

    private static func sameStreetLimit(_ index: Int, _ edges: [TraceEdge],
                                        _ mapped: [SpeedLimit?]) -> SpeedLimit? {
        let names = Set(edges[index].names ?? [])
        guard !names.isEmpty else { return nil }
        /// The nearest mapped limit going `step` at a time while the street
        /// carries on, and how many edges away it is.
        func search(_ step: Int) -> (distance: Int, limit: SpeedLimit)? {
            var other = index + step
            while edges.indices.contains(other), !names.isDisjoint(with: edges[other].names ?? []) {
                if let limit = mapped[other] { return (abs(other - index), limit) }
                other += step
            }
            return nil
        }
        switch (search(-1), search(1)) {
        case let (before?, after?): return before.distance <= after.distance ? before.limit : after.limit
        case let (before?, nil):    return before.limit
        case let (nil, after?):     return after.limit
        case (nil, nil):            return nil
        }
    }

    /// A cautious guess at a road's limit, in km/h: the lower usual values
    /// across Europe and North America, in town (a Valhalla road density of 9
    /// or more) or out of it.
    private static func typicalLimit(_ edge: TraceEdge) -> Int {
        let builtUp = (edge.density ?? 0) >= 9
        switch edge.use {
        case "ramp":
            return builtUp ? 40 : 60
        case "turn_channel":
            return 40
        case "track":
            return 30
        case "living_street", "footway", "pedestrian", "path", "sidewalk", "steps", "cycleway",
             "bridleway", "pedestrian_crossing", "mountain_bike":
            return 10
        case "driveway", "alley", "parking_aisle", "drive_through", "culdesac", "service_road",
             "emergency_access", "rest_area", "service_area":
            return 20
        default:
            break
        }
        switch edge.roadClass {
        case "motorway":     return builtUp ? 80 : 110
        case "trunk":        return builtUp ? 50 : 90
        case "primary":      return builtUp ? 50 : 80
        case "secondary":    return builtUp ? 50 : 70
        case "tertiary":     return builtUp ? 50 : 60
        case "unclassified": return 50
        case "residential":  return 30
        default:             return 20
        }
    }

    // MARK: Place names

    /// A short name for what's at `coordinate` (a place or an address), from
    /// Apple's geocoder, in the app's language.
    static func placeName(at coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
            request.preferredLocale = Localizer.locale
            guard let item = try? await request.mapItems.first else { return nil }
            return item.name ?? item.address?.shortAddress
        } else {
            let placemarks = try? await CLGeocoder()
                .reverseGeocodeLocation(location, preferredLocale: Localizer.locale)
            guard let placemark = placemarks?.first else { return nil }
            return placemark.name ?? placemark.thoroughfare
        }
    }
}

/// Collects which stretch each segment of a leg is on. The first stretch to
/// claim a segment keeps it, so limits go in before the estimates that fill
/// the gaps.
private struct LegSpeeds {
    private var stretches: [PlannedRoute.Stretch] = []
    private var index: [Int?]

    init(segments: Int) {
        index = Array(repeating: nil, count: segments)
    }

    /// Claims segments `begin..<end` that nothing has yet.
    mutating func assign(_ stretch: PlannedRoute.Stretch, from begin: Int, to end: Int) {
        let range = max(0, begin)..<min(end, index.count)
        guard !range.isEmpty, range.contains(where: { index[$0] == nil }) else { return }
        // Edges come in pieces; one stretch per run keeps the list short.
        if stretches.last != stretch { stretches.append(stretch) }
        let claimed = stretches.count - 1
        for segment in range where index[segment] == nil {
            index[segment] = claimed
        }
    }

    /// Every segment's stretch: one nothing claimed takes the stretch before
    /// it (or after it, at the start).
    func resolved(fallback: PlannedRoute.Stretch) -> (stretches: [PlannedRoute.Stretch], index: [Int]) {
        guard let first = index.lazy.compactMap({ $0 }).first else {
            return ([fallback], Array(repeating: 0, count: index.count))
        }
        var previous = first
        let filled = index.map { claimed -> Int in
            if let claimed { previous = claimed }
            return previous
        }
        return (stretches, filled)
    }
}

// MARK: - Valhalla

/// FOSSGIS's public Valhalla server, valhalla1.openstreetmap.de (the one
/// valhalla.openstreetmap.de's map uses). Free to use fairly, which it
/// enforces at about one request a second from each user, so requests here
/// queue at that pace.
private actor Valhalla {
    static let shared = Valhalla()

    private static let endpoint = URL(string: "https://valhalla1.openstreetmap.de")!
    private static let spacing: Duration = .milliseconds(1100)
    /// Identifies the app, as fair use asks.
    private static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "SideInstaller/\(version) (+https://github.com/FrizzleM/SideInstaller)"
    }()

    /// The earliest the next request may go out.
    private var nextSlot = ContinuousClock.now

    func request<Response: Decodable>(_ action: String, _ body: some Encodable) async throws -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        var request = URLRequest(url: Self.endpoint.appendingPathComponent(action))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try encoder.encode(body)

        for attempt in 1...2 {
            // Taken before waiting, so a request made meanwhile queues behind.
            let slot = max(nextSlot, .now)
            nextSlot = slot + Self.spacing
            try await Task.sleep(until: slot, clock: .continuous)

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 429, attempt == 1 {
                nextSlot = .now + .seconds(3)
                continue
            }
            guard (200..<300).contains(status) else {
                throw ValhallaError(status: status, data: data)
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Response.self, from: data)
        }
        throw ValhallaError(status: 429, data: Data())
    }
}

/// A request Valhalla turned down, as it explains it.
private struct ValhallaError: LocalizedError {
    let status: Int
    /// Valhalla's own code, documented under "HTTP status codes and
    /// conditions" in its API reference.
    let code: Int?
    let message: String?

    static let noRoute = ValhallaError(status: 400, code: 442, message: nil)

    init(status: Int, code: Int?, message: String?) {
        self.status = status
        self.code = code
        self.message = message
    }

    init(status: Int, data: Data) {
        struct Body: Decodable {
            let errorCode: Int?
            let error: String?
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let body = try? decoder.decode(Body.self, from: data)
        self.init(status: status, code: body?.errorCode, message: body?.error)
    }

    var isBadRequest: Bool { status == 400 }

    var errorDescription: String? {
        switch code {
        case 170, 442:
            return L("No route found between these stops. Move them onto roads or paths, or travel another way.")
        case 171:
            return L("A stop is too far from any road or path. Move it closer and try again.")
        case 150:
            return L("Too many stops for the route server. Take some out and try again.")
        case 154, 155:
            return L("That route is too long for the route server. Make it shorter, or split it up.")
        default:
            if status == 429 { return L("The route server is busy. Try again in a minute.") }
            return L("The route server couldn't plan this route (%@).", message ?? "HTTP \(status)")
        }
    }
}

private struct ValhallaLocation: Encodable {
    let lat: Double
    let lon: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        lat = coordinate.latitude
        lon = coordinate.longitude
    }
}

private struct RouteRequest: Encodable {
    let locations: [ValhallaLocation]
    let costing: String
    /// Maneuvers carry the times; their spoken instructions aren't needed.
    let directionsType = "maneuvers"
    let units = "kilometers"
}

private struct RouteResponse: Decodable {
    struct Trip: Decodable {
        let legs: [Leg]
    }

    struct Leg: Decodable {
        /// Encoded polyline, six decimal places.
        let shape: String
        let maneuvers: [Maneuver]?
    }

    struct Maneuver: Decodable {
        /// Seconds.
        let time: Double
        /// Kilometers.
        let length: Double
        let beginShapeIndex: Int
        let endShapeIndex: Int
        let streetNames: [String]?
    }

    let trip: Trip
}

/// Asks for the roads along a route Valhalla planned, and what it knows of
/// each.
private struct TraceRequest: Encodable {
    struct Filters: Encodable {
        let attributes = ["edge.speed_limit", "edge.begin_shape_index", "edge.end_shape_index",
                          "edge.road_class", "edge.use", "edge.names", "edge.density", "edge.speed",
                          "node.admin_index", "admin.country_code", "matched.edge_index"]
        let action = "include"
    }

    let shape: [ValhallaLocation]
    /// `edge_walk` follows the shape edge by edge, which works on Valhalla's
    /// own routes but for private roads; `map_snap` matches it as a GPS
    /// trace.
    let shapeMatch: String
    let costing = "auto"
    let units = "kilometers"
    let filters = Filters()
}

private struct TraceResponse: Decodable {
    struct Admin: Decodable {
        let countryCode: String?
    }

    /// The edge each shape point is on (map matching only).
    struct MatchedPoint: Decodable {
        let edgeIndex: Int?
    }

    let edges: [TraceEdge]
    /// The countries the edges' nodes point into.
    let admins: [Admin]?
    let matchedPoints: [MatchedPoint]?
}

private struct TraceEdge: Decodable {
    /// A number in km/h, `"unlimited"`, or missing when nothing's mapped.
    enum Limit: Decodable {
        case kmh(Int)
        case unlimited
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let kmh = try? container.decode(Double.self) {
                self = kmh > 0 ? .kmh(Int(kmh.rounded())) : .unknown
            } else if (try? container.decode(String.self)) == "unlimited" {
                self = .unlimited
            } else {
                self = .unknown
            }
        }
    }

    let speedLimit: Limit?
    var beginShapeIndex: Int
    var endShapeIndex: Int
    let roadClass: String?
    let use: String?
    let names: [String]?
    /// Valhalla's road density, 0 (open country) to 15.
    let density: Double?
    /// Valhalla's estimated speed, km/h.
    let speed: Double?
    let endNode: EndNode?
    /// Where the edge ends, from `endNode` and the response's `admins`.
    var country: String?

    struct EndNode: Decodable {
        let adminIndex: Int?
    }

    var isFerry: Bool { use == "ferry" || use == "rail-ferry" }

    func shifted(by offset: Int) -> TraceEdge {
        var edge = self
        edge.beginShapeIndex += offset
        edge.endShapeIndex += offset
        return edge
    }
}

/// Valhalla's shapes: Google's encoded polyline format, at six decimal
/// places rather than five.
private enum Polyline {
    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        let bytes = Array(encoded.utf8)
        var position = 0
        func nextValue() -> Int? {
            var result = 0
            var shift = 0
            while position < bytes.count {
                let chunk = Int(bytes[position]) - 63
                position += 1
                result |= (chunk & 0x1F) << shift
                shift += 5
                if chunk < 0x20 {
                    return result & 1 != 0 ? ~(result >> 1) : result >> 1
                }
            }
            return nil
        }
        var points: [CLLocationCoordinate2D] = []
        var latitude = 0
        var longitude = 0
        while let deltaLatitude = nextValue(), let deltaLongitude = nextValue() {
            latitude += deltaLatitude
            longitude += deltaLongitude
            points.append(CLLocationCoordinate2D(latitude: Double(latitude) / 1e6,
                                                 longitude: Double(longitude) / 1e6))
        }
        return points
    }
}
