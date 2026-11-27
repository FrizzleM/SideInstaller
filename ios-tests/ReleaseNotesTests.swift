import Foundation
import Testing
@testable import SideInstaller

/// The version log: reading GitHub's releases, and splitting their notes.
@Suite("Release notes")
struct ReleaseNotesTests {

    @Test("Releases come newest version first, without betas or drafts")
    func releases() throws {
        let json = """
        [
          {"tag_name": "v1.10.0", "body": "ten", "html_url": "https://github.com/x/y/releases/tag/v1.10.0",
           "published_at": "2026-11-24T07:55:43Z", "draft": false, "prerelease": false},
          {"tag_name": "v2.0.0-beta.1", "body": "beta", "draft": false, "prerelease": true},
          {"tag_name": "v1.9.0", "body": null, "published_at": "2026-11-01T00:00:00Z",
           "draft": false, "prerelease": false},
          {"tag_name": "v3.0.0", "body": "draft", "draft": true, "prerelease": false},
          {"tag_name": "v1.11.0", "body": "eleven", "draft": false, "prerelease": false}
        ]
        """
        let notes = try ReleaseNotesStore.notes(from: Data(json.utf8))
        #expect(notes.map(\.version) == ["1.11.0", "1.10.0", "1.9.0"])
        #expect(notes[1].body == "ten")
        #expect(notes[1].url?.absoluteString == "https://github.com/x/y/releases/tag/v1.10.0")
        #expect(notes[1].published == ISO8601DateFormatter().date(from: "2026-11-24T07:55:43Z"))
        #expect(notes[2].body == "")
    }

    @Test("Headings, nested lists and paragraphs are told apart")
    func blocks() {
        let markdown = """
        # Main changes:
        - Installs keep going
            - On iOS 26 it runs in the background
            - Below iOS 26, a Live Activity
        - Certificate changes
        wrapped onto a second line

        ## Fixes
        * Fixed #54
        carried on, as GitHub carries it on

        Some words
        on two lines

        ---
        **Full Changelog**: https://github.com/FrizzleM/SideInstaller/compare/v1.5.3...v1.6.0
        """
        #expect(ReleaseNotesStore.blocks(from: markdown) == [
            .heading("Main changes"),
            .bullet("Installs keep going", depth: 0),
            .bullet("On iOS 26 it runs in the background", depth: 1),
            .bullet("Below iOS 26, a Live Activity", depth: 1),
            .bullet("Certificate changes wrapped onto a second line", depth: 0),
            .heading("Fixes"),
            .bullet("Fixed #54 carried on, as GitHub carries it on", depth: 0),
            .paragraph("Some words\non two lines"),
        ])
    }

    @Test("A hashtag or a dash in a sentence isn't a heading or a list")
    func notMarkers() {
        #expect(ReleaseNotesStore.blocks(from: "#54 is fixed\n-5 degrees") == [
            .paragraph("#54 is fixed\n-5 degrees"),
        ])
        #expect(ReleaseNotesStore.blocks(from: "\r\n\r\n") == [])
    }

    @Test("Inline Markdown and bare links are drawn")
    func inline() {
        let text = ReleaseNotesStore.inline(#"**Bold** and [a link](https://example.com), see https://sideinstaller.net, \"quoted\""#)
        #expect(String(text.characters) == #"Bold and a link, see https://sideinstaller.net, "quoted""#)
        let links = text.runs.compactMap(\.link).map(\.absoluteString)
        #expect(links == ["https://example.com", "https://sideinstaller.net"])
    }
}
