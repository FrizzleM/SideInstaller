import Foundation
import Testing
@testable import SideInstaller

/// Reading an imported route out of the formats StikDebug imports.
@Suite("Location: route files")
struct RouteFileTests {

    private func points(_ text: String) throws -> [RoutePoint] {
        try RouteFile.points(in: Data(text.utf8), fileName: "route")
    }

    private func pairs(_ points: [RoutePoint]) -> [[Double]] {
        points.map { [$0.coordinate.latitude, $0.coordinate.longitude] }
    }

    @Test("GPX: the track wins over the waypoints a track file carries, with its times")
    func gpxTrack() throws {
        let read = try points("""
            <?xml version="1.0"?>
            <gpx version="1.1"><wpt lat="1" lon="1"/>
              <trk><trkseg>
                <trkpt lat="48.85" lon="2.35"><time>2026-11-01T10:00:00Z</time></trkpt>
                <trkpt lat="48.86" lon="2.36"><time>2026-11-01T10:00:30.5Z</time></trkpt>
              </trkseg></trk>
            </gpx>
            """)
        #expect(pairs(read) == [[48.85, 2.35], [48.86, 2.36]])
        #expect(read.allSatisfy { $0.time != nil })
    }

    @Test("KML: a LineString is the path, `longitude,latitude` tuples; Points are only places")
    func kmlLine() throws {
        let read = try points("""
            <kml xmlns="http://www.opengis.net/kml/2.2"><Document>
              <Placemark><Point><coordinates>9.0,45.0,0</coordinates></Point></Placemark>
              <Placemark><LineString><coordinates>
                2.35,48.85,0 2.36,48.86,0
                2.37,48.87
              </coordinates></LineString></Placemark>
            </Document></kml>
            """)
        #expect(pairs(read) == [[48.85, 2.35], [48.86, 2.36], [48.87, 2.37]])

        let places = try points("""
            <kml><Placemark><Point><coordinates>9.19,45.46,0</coordinates></Point></Placemark></kml>
            """)
        #expect(pairs(places) == [[45.46, 9.19]])
    }

    @Test("KML: a gx:Track's coords are timed by its whens, in order")
    func kmlTrack() throws {
        let read = try points("""
            <kml xmlns:gx="http://www.google.com/kml/ext/2.2"><Placemark><gx:Track>
              <when>2026-11-01T10:00:00Z</when><when>2026-11-01T10:01:00Z</when>
              <gx:coord>2.35 48.85 0</gx:coord><gx:coord>2.36 48.86 0</gx:coord>
            </gx:Track></Placemark></kml>
            """)
        #expect(pairs(read) == [[48.85, 2.35], [48.86, 2.36]])
        #expect(read.map(\.time) == [
            try Date("2026-11-01T10:00:00Z", strategy: .iso8601),
            try Date("2026-11-01T10:01:00Z", strategy: .iso8601),
        ])
    }

    @Test("GeoJSON: positions are `[longitude, latitude]`, lines are the path")
    func geoJSON() throws {
        let read = try points("""
            {"type": "FeatureCollection", "features": [
              {"type": "Feature", "geometry": {"type": "Point", "coordinates": [9.0, 45.0]}},
              {"type": "Feature", "geometry": {"type": "LineString",
                "coordinates": [[2.35, 48.85], [2.36, 48.86, 30]]}}
            ]}
            """)
        #expect(pairs(read) == [[48.85, 2.35], [48.86, 2.36]])

        let place = try points(#"{"type": "Point", "coordinates": [139.69, 35.68]}"#)
        #expect(pairs(place) == [[35.68, 139.69]])
    }

    @Test("Other JSON: objects with latitude and longitude keys, or `[latitude, longitude]` pairs")
    func keyedJSON() throws {
        let keyed = try points(#"[{"Lat": 48.85, "lng": "2.35"}, {"latitude": 48.86, "longitude": 2.36}]"#)
        #expect(pairs(keyed) == [[48.85, 2.35], [48.86, 2.36]])

        // A pair that can't be latitude first is read the other way round.
        let pairsRead = try points("[[48.85, 2.35], [139.69, 35.68]]")
        #expect(pairs(pairsRead) == [[48.85, 2.35], [35.68, 139.69]])
    }

    @Test("CSV: the columns a header names, else the first two numbers on each line")
    func text() throws {
        let csv = try points("""
            name,lon,lat
            Tour Eiffel,2.2945,48.8584
            Louvre;2.3376;48.8606
            """)
        #expect(pairs(csv) == [[48.8584, 2.2945], [48.8606, 2.3376]])

        let copied = try points("""
            48.8584, 2.2945

            -33.8568 151.2153
            not a coordinate
            """)
        #expect(pairs(copied) == [[48.8584, 2.2945], [-33.8568, 151.2153]])
    }

    @Test("A file of neither, or broken XML, is refused with what to import instead")
    func refused() throws {
        #expect(try points("no numbers here").isEmpty)
        #expect(throws: EngineError.self) { try points("<kml><Placemark>") }
        #expect(throws: EngineError.self) { try points("{\"type\": ") }
    }
}
