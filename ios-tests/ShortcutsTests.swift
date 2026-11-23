import AppIntents
import CoreLocation
import Foundation
import Testing
@testable import SideInstaller

/// The parts of the Shortcuts actions that don't need a device: what they
/// report, the values they hand on, and the files they're handed.
@Suite("Shortcuts actions")
@MainActor
struct ShortcutsTests {

    private func job(_ name: String, _ state: RefreshJob.State) -> RefreshJob {
        RefreshJob(bundleID: "com.example.\(name)", name: name,
                   ipa: URL(fileURLWithPath: "/tmp/\(name).ipa"), teamID: nil, state: state)
    }

    /// The headline is translated, so only its line is counted.
    @Test("A refresh report counts what was refreshed and says why the rest wasn't")
    func report() throws {
        let outcome = SideloadedAppsManager.RefreshOutcome(jobs: [
            job("SideStore", .done),
            job("Feather", .failed("No route to host")),
            job("StikDebug", .done),
        ])
        #expect(outcome.refreshed == 2)
        let lines = try Shortcuts.report(outcome).components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines.last == "Feather: No route to host")
    }

    @Test("A refresh that refreshed nothing stops the shortcut, saying why")
    func reportThrows() {
        let outcome = SideloadedAppsManager.RefreshOutcome(jobs: [
            job("SideStore", .failed("Signed by another team")),
        ])
        #expect(throws: ShortcutError.self) { try Shortcuts.report(outcome) }
        do {
            _ = try Shortcuts.report(outcome)
        } catch let error as ShortcutError {
            #expect(error.message.hasSuffix("SideStore: Signed by another team"))
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test("A place handed on keeps its spot and its name")
    func placemark() throws {
        let spot = CLLocationCoordinate2D(latitude: 45.46421, longitude: 9.19)
        let placemark = CLPlacemark.at(spot, named: "Duomo")
        #expect(placemark.name == "Duomo")
        #expect(placemark.shortcutName == "Duomo")
        let coordinate = try placemark.requiredCoordinate()
        #expect(coordinate.latitude == spot.latitude)
        #expect(coordinate.longitude == spot.longitude)
    }

    @Test("Coordinates off the globe aren't set")
    func validity() {
        #expect(LocationManager.isValid(CLLocationCoordinate2D(latitude: 90, longitude: -180)))
        #expect(!LocationManager.isValid(CLLocationCoordinate2D(latitude: 90.1, longitude: 0)))
        #expect(!LocationManager.isValid(CLLocationCoordinate2D(latitude: 0, longitude: 180.5)))
        #expect(!LocationManager.isValid(CLLocationCoordinate2D(latitude: .nan, longitude: 0)))
    }

    @Test("A saved place reads the same as an entity")
    func savedPlace() {
        let place = SavedPlace(name: "Home", latitude: 41.9, longitude: 12.5)
        let entity = SavedPlaceEntity(place)
        #expect(entity.id == place.id)
        #expect(entity.name == "Home")
        #expect(entity.coordinate.latitude == 41.9)
        #expect(entity.coordinate.longitude == 12.5)
        #expect(entity.location?.name == "Home")
    }

    @Test("An app picked before the device was read stands in under its bundle ID")
    func placeholderApp() {
        let app = SideloadedAppEntity(placeholder: "com.example.app")
        #expect(app.id == "com.example.app")
        #expect(app.name == "com.example.app")
        #expect(app.canBeRefreshed == false)
    }

    @Test("Each option is the app's own value")
    func options() {
        #expect(RouteSpeedOption.allCases.map(\.speed) == [.recorded, .walk, .cycle, .drive])
        #expect(TravelModeOption.allCases.map(\.mode) == [.walk, .cycle, .drive])
        #expect(InstallableApp.allCases.map(\.source) == [.sideStore, .liveContainer, .madeira, .altStore])
        #expect(ReleaseTrack.allCases.map(\.channel) == [.stable, .nightly])
    }

    @Test("A file handed over is copied into a folder of its own, and goes with it")
    func temporaryCopy() throws {
        let contents = Data("<gpx/>".utf8)
        // A name with a path in it stays in the folder.
        let file = IntentFile(data: contents, filename: "../Walk.gpx")
        let copy = try Shortcuts.temporaryCopy(of: file, defaultName: "Route.gpx")
        #expect(copy.lastPathComponent == "Walk.gpx")
        #expect(copy.deletingLastPathComponent().lastPathComponent.hasPrefix("ShortcutsInput-"))
        #expect(try Data(contentsOf: copy) == contents)
        Shortcuts.discard(copy)
        #expect(!FileManager.default.fileExists(atPath: copy.deletingLastPathComponent().path))
    }
}
