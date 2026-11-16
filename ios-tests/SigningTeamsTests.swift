import Foundation
import Testing
@testable import SideInstaller

// What rust-core's team callback hands over (`team::choices`, whose test
// `kinds_come_from_a_list_teams_answer` checks the same shape). Made up.
private let listed = #"""
[{"teamId":"ABCDE12345","name":"Frizzle","kind":"free"},
 {"teamId":"FGHIJ67890","name":"Frizzle","kind":"paid"},
 {"teamId":"PQRST13579","name":"","kind":"unknown"}]
"""#

@Suite("Developer teams")
struct DeveloperTeamTests {

    @Test("The question's teams decode from Rust's JSON, in Apple's order")
    func decodes() throws {
        let teams = try #require(DeveloperTeam.list(json: listed))
        #expect(teams.map(\.teamId) == ["ABCDE12345", "FGHIJ67890", "PQRST13579"])
        #expect(teams.map(\.kind) == [.free, .paid, .unknown])
        #expect(DeveloperTeam.list(json: "{}") == nil)
    }

    /// Checked without the words for free and paid, which are translated.
    @Test("A label leads with the kind; a team of unknown kind goes without")
    func labels() throws {
        let teams = try #require(DeveloperTeam.list(json: listed))
        #expect(teams[0].named == "Frizzle (ABCDE12345)")
        #expect(teams[0].label.hasSuffix(" · Frizzle (ABCDE12345)"))
        #expect(teams[1].label.hasSuffix(" · Frizzle (FGHIJ67890)"))
        #expect(teams[0].label != teams[1].label.replacingOccurrences(of: "FGHIJ67890", with: "ABCDE12345"))
        // No kind, and no name: the ID alone.
        #expect(teams[2].label == "PQRST13579")
    }

    @Test("The question starts on the team that signed SideInstaller, else Apple's first")
    func suggested() throws {
        let teams = try #require(DeveloperTeam.list(json: listed))
        // siboot installed it with the paid team.
        #expect(DeveloperTeam.suggested(in: teams, signer: "FGHIJ67890")?.teamId == "FGHIJ67890")
        // Signed by a team that isn't this account's, or not read (the simulator).
        #expect(DeveloperTeam.suggested(in: teams, signer: "ZZZZZ99999")?.teamId == "ABCDE12345")
        #expect(DeveloperTeam.suggested(in: teams, signer: nil)?.teamId == "ABCDE12345")
        #expect(DeveloperTeam.suggested(in: [], signer: nil) == nil)
    }

    @Test("A picked team reads back as AccountStore saves it")
    func persists() throws {
        let team = try #require(DeveloperTeam.list(json: listed)?[1])
        let saved = try JSONEncoder().encode(["someone@example.com": team])
        let read = try JSONDecoder().decode([String: DeveloperTeam].self, from: saved)
        #expect(read["someone@example.com"] == team)
    }

    @Test("The signing team's ID comes back out of the sign-in's summary")
    func summary() {
        // As rust-core's `team::summary` writes it.
        #expect(Engine.teamID(inSummary: "team: Frizzle (FGHIJ67890)") == "FGHIJ67890")
        #expect(Engine.teamID(inSummary: "team: <unnamed> (FGHIJ67890)") == "FGHIJ67890")
    }
}
