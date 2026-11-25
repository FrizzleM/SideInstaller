import SwiftUI
import SideInstallerFFI

// MARK: - Teams

/// One of an Apple Account's developer teams, as a sign-in lists them when it
/// asks which signs (`SITeamCb` in sideinstaller.h documents the JSON). An
/// Apple Account is on the free team every account has, and on a paid Apple
/// Developer Program membership too when there is one, its own or a company's.
/// The pick is remembered for the Apple ID (`AccountStore.team(for:)`).
struct DeveloperTeam: Codable, Hashable, Identifiable {
    /// Free or paid, which decides how long what the team signs lasts. Rust
    /// tells them apart the way AltSign does (`team.rs`).
    enum Kind: String, Codable {
        /// The free team every Apple Account has: its apps last 7 days.
        case free
        /// An Apple Developer Program membership: its apps last a year.
        case paid
        /// Apple's listing didn't tell.
        case unknown
    }

    let teamId: String
    /// Apple's name for the team; empty when it gave none.
    let name: String
    let kind: Kind

    var id: String { teamId }

    /// "Frizzle (ABCDE12345)", or the ID alone for a team without a name.
    var named: String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? teamId : "\(name) (\(teamId))"
    }

    /// "Paid · Frizzle (ABCDE12345)": the kind first, as siboot lists it, so a
    /// line cut short still shows it. A team of unknown kind goes without one.
    var label: String {
        switch kind {
        case .free:    L("Free · %@", named)
        case .paid:    L("Paid · %@", named)
        case .unknown: named
        }
    }

    /// The teams a sign-in's question lists, or nil when `json` isn't that.
    static func list(json: String) -> [DeveloperTeam]? {
        try? JSONDecoder().decode([DeveloperTeam].self, from: Data(json.utf8))
    }

    /// The team a question starts on: the one that signed this copy of
    /// SideInstaller when it's one of `teams`, so a copy siboot installed with
    /// another team than Apple's first keeps renewing itself in place;
    /// otherwise Apple's first, the team that signed before teams could be
    /// picked.
    static func suggested(in teams: [DeveloperTeam],
                          signer: String? = InstalledSigner.teamID) -> DeveloperTeam? {
        teams.first { $0.teamId == signer } ?? teams.first
    }
}

/// The team that signed this copy of SideInstaller, read from its embedded
/// provisioning profile. Its bundle ID ends in that team's ID, so only that
/// team can refresh it in place.
enum InstalledSigner {
    /// Nil without a readable profile, as in the simulator.
    static let teamID: String? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let profile = ProvisioningProfile(data: data) else { return nil }
        let team = profile.entitlements["com.apple.developer.team-identifier"] as? String
            ?? profile.teamIdentifier
        return team?.isEmpty == false ? team : nil
    }()
}

// MARK: - The question

/// The team sheet's state: the question it shows, and whose it is.
struct TeamQuestion: Equatable {
    /// The request the sheet answers (`TeamRequests`).
    let request: Int
    /// The sign-in that asks (`AppleSignInTicket.id`).
    let signIn: Int
    /// The Apple ID whose teams these are.
    let appleID: String
    /// The account's teams, in Apple's order.
    let teams: [DeveloperTeam]
    /// The team the sheet starts on (`DeveloperTeam.suggested`).
    let suggested: DeveloperTeam
    /// True when the pick is remembered for the Apple ID, as it is for one
    /// saved in Settings › Account. Side by Side's sign-in with someone
    /// else's Apple ID keeps nothing.
    let remembers: Bool
}

/// The team callback every Apple ID sign-in hands Rust, with its
/// `AppleSignInTicket` as the context, as the 2FA callback has.
let appleSignInTeamCallback: SITeamCb = { ctx, teams, outBuf, bufLen in
    guard let ticket = AppleSignInTicket.from(context: ctx) else { return 0 }
    return Engine.shared.answerTeam(request: teams, outBuf: outBuf, len: Int(bufLen), for: ticket)
}

// MARK: - Team sheet

/// Asks which developer team signs, when a sign-in finds the Apple Account on
/// more than one and none of them picked yet. Starts on the suggested team;
/// closing it stops the sign-in. Shown in the sheet the 2FA prompt uses, which
/// it takes over once the code has gone through.
struct TeamSheet: View {
    @Environment(Engine.self) private var engine
    /// Declared so every label redraws when the language changes.
    @EnvironmentObject private var loc: Localizer

    let question: TeamQuestion

    /// The team tapped, if one was: until then the suggested one is ticked.
    @State private var picked: String?

    private var selected: DeveloperTeam {
        question.teams.first { $0.teamId == picked } ?? question.suggested
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L("This Apple Account is on %d developer teams. Pick the one that signs.",
                           question.teams.count))
                        .foregroundStyle(.secondary)
                    // Enumerated, so a language switch relabels every row.
                    ForEach(Array(question.teams.enumerated()), id: \.element.id) { _, team in
                        Button { picked = team.teamId } label: { row(team) }
                            .buttonStyle(.plain, sound: .tick)
                    }
                } footer: {
                    // Whose teams they are: Side by Side can sign in with
                    // someone else's Apple ID.
                    Label(question.appleID, systemImage: "person.crop.circle")
                }
                Section {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("Which Team?"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Cancel")) { engine.cancelTeamQuestion(question) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Continue")) { engine.answerTeamQuestion(selected, to: question) }
                        .fontWeight(.semibold)
                }
            }
        }
        // Another sign-in's question starts on its own suggestion.
        .onChange(of: question.request) { _, _ in picked = nil }
    }

    /// One team: its label, ticked when it's the one that would sign.
    private func row(_ team: DeveloperTeam) -> some View {
        let isSelected = team.teamId == selected.teamId
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(team.label)
                    .font(.subheadline.weight(isSelected ? .medium : .regular))
                if team.teamId == InstalledSigner.teamID {
                    Text(L("Signed this copy of SideInstaller"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .opacity(isSelected ? 1 : 0)
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// What the pick decides, and how long it holds.
    private var note: String {
        var text = L("A free team's apps last 7 days; a paid team's last a year.")
            + " " + L("An app installed with another team isn't replaced: signing it with this one installs a second copy.")
        if question.remembers {
            text += " " + L("SideInstaller remembers the pick for this Apple ID. To pick again, open Settings › Account, swipe the Apple ID left and tap Team.")
        }
        return text
    }
}
