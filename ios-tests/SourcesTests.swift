import Foundation
import Testing
@testable import SideInstaller

/// Reading AltStore-format sources, and what the Sources page makes of them.
@MainActor
@Suite("Sources")
struct SourcesTests {

    private func source(_ json: String) throws -> AppSource {
        try JSONDecoder().decode(AppSource.self, from: Data(json.utf8))
    }

    private let sourceURL = URL(string: "https://example.com/source.json")!

    @Test("An app is read from its versions, or from its top-level version")
    func versions() throws {
        let decoded = try source("""
        {"name": "Test", "apps": [
          {"bundleIdentifier": "com.example.listed", "name": "Listed",
           "versions": [
             {"version": "2.0", "date": "2026-11-01", "downloadURL": "https://example.com/2.ipa", "size": 10},
             {"version": "1.0", "date": "2026-10-01T10:00:00Z", "downloadURL": "https://example.com/1.ipa"}]},
          {"bundleIdentifier": "com.example.flat", "name": "Flat", "version": "3.1",
           "versionDate": "2026-09-01", "downloadURL": "https://example.com/flat.ipa"}
        ]}
        """)
        #expect(decoded.apps.map(\.bundleIdentifier) == ["com.example.listed", "com.example.flat"])
        let listed = decoded.apps[0], flat = decoded.apps[1]
        #expect(listed.latest?.version == "2.0")
        #expect(listed.latest?.size == 10)
        #expect(listed.versions.allSatisfy { $0.date != nil })
        #expect(flat.versions.count == 1)
        #expect(flat.latest?.version == "3.1")
        #expect(flat.latest?.downloadURL.absoluteString == "https://example.com/flat.ipa")
    }

    @Test("Apps with nothing to download, or only for Patreon backers, are left out")
    func leftOut() throws {
        let decoded = try source("""
        {"name": "Test", "apps": [
          {"bundleIdentifier": "com.example.ok", "name": "OK",
           "versions": [{"version": "1.0", "downloadURL": "https://example.com/ok.ipa"}]},
          {"bundleIdentifier": "com.example.none", "name": "Nothing", "versions": []},
          {"bundleIdentifier": "com.example.ftp", "name": "Not the web",
           "versions": [{"version": "1.0", "downloadURL": "ftp://example.com/ftp.ipa"}]},
          {"bundleIdentifier": "com.example.Beta", "name": "Backers", "beta": true,
           "patreon": {"pledge": 3, "currency": "USD"},
           "versions": [{"version": "1.1b", "downloadURL": "https://www.patreon.com/file?h=1&m=2"}]},
          {"bundleIdentifier": "com.example.free", "name": "Free", "patreon": null,
           "versions": [{"version": "1.0", "downloadURL": "https://example.com/free.ipa"}]},
          {"name": "No bundle id",
           "versions": [{"version": "1.0", "downloadURL": "https://example.com/none.ipa"}]}
        ]}
        """)
        #expect(decoded.apps.map(\.bundleIdentifier) == ["com.example.ok", "com.example.free"])
    }

    @Test("A source link: its https address, or AltStore's and SideStore's add links")
    func sourceLinks() {
        let json = sourceURL.absoluteString
        #expect(SourcesManager.sourceLink(json) == sourceURL)
        #expect(SourcesManager.sourceLink("  example.com/source.json\n") == sourceURL)
        #expect(SourcesManager.sourceLink("altstore://source?url=\(json)") == sourceURL)
        #expect(SourcesManager.sourceLink("sidestore://source?URL=\(json)") == sourceURL)
        #expect(SourcesManager.sourceLink("sidestore://pairing?urlname=x") == nil)
        #expect(SourcesManager.sourceLink("not a link") == nil)
    }

    @Test("Installed as SideInstaller signs it, an app is the source's, with updates and downgrades")
    func installedVersions() throws {
        let app = try #require(try source("""
        {"name": "SideStore", "apps": [{"bundleIdentifier": "com.SideStore.SideStore", "name": "SideStore",
          "versions": [{"version": "0.6.2", "downloadURL": "https://example.com/0.6.2.ipa"},
                       {"version": "0.5.10", "downloadURL": "https://example.com/0.5.10.ipa"}]}]}
        """).apps.first)
        func installed(_ bundleID: String, _ version: String) throws -> SideloadedAppStatus {
            let plist: [String: Any] = ["ProfileValidated": true, "CFBundleIdentifier": bundleID,
                                        "CFBundleShortVersionString": version]
            return SideloadedAppStatus(app: try #require(SideloadedApp(plist: plist)), profiles: [])
        }
        #expect(SourcesManager.installedVersion(of: app, in: [
            try installed("com.SideStore.SideStore.X53M69UJ7U", "0.6.4")]) == "0.6.4")
        #expect(SourcesManager.installedVersion(of: app, in: [
            try installed("com.SideStore.SideStore.Widget", "0.6.4")]) == nil)

        func listing(_ version: String?) -> SourceListing {
            SourceListing(app: app, sourceURL: sourceURL, sourceName: "SideStore", installedVersion: version)
        }
        let newest = try #require(app.latest), older = app.versions[1]
        #expect(listing("0.5.10").hasUpdate)
        #expect(!listing("0.6.2").hasUpdate)
        #expect(!listing(nil).hasUpdate)
        // The source behind the iPhone: its newest goes back a version.
        #expect(!listing("0.6.4").hasUpdate)
        #expect(listing("0.6.4").isDowngrade(to: newest))
        #expect(!listing("0.6.2").isDowngrade(to: newest))
        #expect(listing("0.6.2").isDowngrade(to: older))
        #expect(!listing(nil).isDowngrade(to: older))
    }

    @Test("Builds of one app listed side by side keep apart")
    func listingIDs() throws {
        let apps = try source("""
        {"name": "Test", "apps": [
          {"bundleIdentifier": "com.example.app", "name": "App",
           "versions": [{"version": "1.0", "downloadURL": "https://example.com/plain.ipa"}]},
          {"bundleIdentifier": "com.example.app", "name": "App (tweaked)",
           "versions": [{"version": "1.0", "downloadURL": "https://example.com/tweaked.ipa"}]}
        ]}
        """).apps
        let ids = apps.map { SourceListing(app: $0, sourceURL: sourceURL, sourceName: "Test",
                                           installedVersion: nil).id }
        #expect(Set(ids).count == 2)
    }

    @Test("The GitHub account a source comes from")
    func gitHubOwners() {
        func owner(_ link: String) -> String? { SourcesManager.gitHubOwner(of: URL(string: link)!) }
        #expect(owner("https://example.github.io/repo/source.json") == "example")
        #expect(owner("https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/frizzlem.json") == "FrizzleM")
        #expect(owner("https://apps.sidestore.io") == "SideStore")
        #expect(owner("https://example.com/source.json") == nil)
    }

    @Test("Release notes: headings, bullets and paragraphs, with links to web pages only")
    func releaseNotes() {
        #expect(ReleaseNotesText.blocks("## New\r\n- One\n* Two\n\n  Plain  ") ==
                [.heading("New"), .bullet("One"), .bullet("Two"), .paragraph("Plain")])
        #expect(ReleaseNotesText.opensLink(URL(string: "https://example.com/notes")!))
        #expect(ReleaseNotesText.opensLink(URL(string: "HTTP://example.com")!))
        #expect(!ReleaseNotesText.opensLink(URL(string: "sidestore://pairing?urlname=x")!))
        #expect(!ReleaseNotesText.opensLink(URL(string: "sideinstaller://install?url=https://example.com/a.ipa")!))
    }
}
