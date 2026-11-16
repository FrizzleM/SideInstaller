//! Which developer team signs. Apple lists every team an Apple Account is on:
//! the free one every account has (Xcode's Personal Team), and a paid Apple
//! Developer Program membership too when there is one, the account's own or a
//! company's. Until now the first one signed. Now the caller names the team it
//! remembers, and when that isn't one of them and there's more than one, it's
//! asked which, each team marked free or paid, since that decides how long
//! what it signs lasts: 7 days or a year.
//!
//! The free-or-paid rule is siboot's (`minis/src/team.rs` in FrizzleM/siboot),
//! which is AltSign's: AltStore and SideStore go by it.

use std::collections::HashMap;

use isideload::dev::{
    developer_session::DeveloperSession,
    device_type::{dev_url, DeveloperDeviceType},
    teams::{DeveloperTeam, TeamsApi},
};
use rootcause::Report;
use serde::{Deserialize, Serialize};

use crate::apple_session::first_line;
use crate::error_text::report_text;

/// The error a sign-in stops with when the question went unanswered.
pub(crate) const NONE_PICKED: &str = "No developer team picked.";

/// What a team is, as far as signing goes.
#[derive(Serialize, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub(crate) enum Kind {
    /// The free team every Apple Account has: what it signs lasts 7 days.
    Free,
    /// An Apple Developer Program membership, the account's own or a
    /// company's: what it signs lasts a year.
    Paid,
    /// Apple's listing didn't say, or couldn't be read.
    Unknown,
}

impl Kind {
    /// From a team's `type` in Apple's listTeams and the names of its
    /// memberships, the way AltSign's `ALTTeam` reads them: a company's or
    /// organization's team is paid; an individual's is free when its one
    /// membership is named as free, and paid otherwise. One with no
    /// membership listed isn't guessed at.
    pub(crate) fn of(team_type: Option<&str>, memberships: &[String]) -> Kind {
        match (team_type, memberships) {
            (Some("Company/Organization"), _) => Kind::Paid,
            (Some("Individual"), [only]) if only.to_lowercase().contains("free") => Kind::Free,
            (Some("Individual"), [_, ..]) => Kind::Paid,
            _ => Kind::Unknown,
        }
    }
}

/// A team in Apple's listTeams answer, with what isideload's `DeveloperTeam`
/// leaves out.
#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Listed {
    team_id: String,
    r#type: Option<String>,
    #[serde(default)]
    memberships: Vec<Membership>,
}

#[derive(Deserialize, Debug)]
struct Membership {
    #[serde(default)]
    name: String,
}

/// Each listed team's kind, by team ID.
pub(crate) fn kinds(listed: &[Listed]) -> HashMap<String, Kind> {
    listed
        .iter()
        .map(|team| {
            let names: Vec<String> = team.memberships.iter().map(|m| m.name.clone()).collect();
            (team.team_id.clone(), Kind::of(team.r#type.as_deref(), &names))
        })
        .collect()
}

/// One of the account's teams as the question lists it, the JSON Swift reads
/// (`SITeamCb` in sideinstaller.h).
#[derive(Serialize, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Choice {
    pub(crate) team_id: String,
    /// Apple's name for the team; empty when it gave none.
    name: String,
    kind: Kind,
}

/// The teams in Apple's order, each with its kind; one `kinds` doesn't have
/// is of unknown kind.
pub(crate) fn choices(teams: &[DeveloperTeam], kinds: &HashMap<String, Kind>) -> Vec<Choice> {
    teams
        .iter()
        .map(|team| Choice {
            team_id: team.team_id.clone(),
            name: team.name.clone().unwrap_or_default(),
            kind: kinds.get(&team.team_id).copied().unwrap_or(Kind::Unknown),
        })
        .collect()
}

/// Which team signs, or that the question decides.
#[derive(Debug, PartialEq)]
pub(crate) enum Pick {
    /// The team at this index in Apple's list.
    Team(usize),
    Ask,
}

/// `wanted` when the account is on it, the only team when there's one, and
/// otherwise the question.
pub(crate) fn decide(teams: &[DeveloperTeam], wanted: Option<&str>) -> Pick {
    if let Some(index) = wanted.and_then(|id| teams.iter().position(|t| t.team_id == id)) {
        return Pick::Team(index);
    }
    if teams.len() == 1 {
        Pick::Team(0)
    } else {
        Pick::Ask
    }
}

/// The listed team an answer names. One the account isn't on is refused, so a
/// stale answer can't sign with a team Apple didn't offer.
pub(crate) fn answered(teams: &[DeveloperTeam], answer: &str) -> Result<usize, String> {
    let answer = answer.trim();
    teams
        .iter()
        .position(|t| t.team_id == answer)
        .ok_or_else(|| format!("the team picked, {answer}, isn't one of this Apple Account's teams"))
}

/// "team: Frizzle (ABCDE12345)", how a sign-in names the team that signs.
/// Swift reads the team ID from it, and its log masks the name.
pub(crate) fn summary(team: &DeveloperTeam) -> String {
    format!(
        "team: {} ({})",
        team.name.as_deref().unwrap_or("<unnamed>"),
        team.team_id
    )
}

/// The team that signs, from the teams `apple_session::open` listed: `wanted`
/// when the account is on it, the only one when there's one, and otherwise
/// the one `ask` picks from the teams marked free or paid. `ask` gets them in
/// Apple's order and returns the picked team's ID, or None to stop the
/// sign-in. `label` names the sign-in in the log.
pub(crate) async fn pick(
    dev: &mut DeveloperSession,
    mut teams: Vec<DeveloperTeam>,
    wanted: Option<&str>,
    ask: impl FnOnce(&[Choice]) -> Option<String>,
    label: &str,
) -> Result<DeveloperTeam, String> {
    if teams.is_empty() {
        // Asked once more, as isideload's `get_team` did when no team was set.
        teams = dev
            .list_teams()
            .await
            .map_err(|e| format!("list teams: {}", report_text(&e)))?;
    }
    if teams.is_empty() {
        return Err("no development teams on this Apple ID".to_string());
    }
    if let Some(id) = wanted.filter(|id| !teams.iter().any(|t| t.team_id == *id)) {
        tracing::info!("{label}: team {id} isn't one of this Apple Account's teams any more");
    }
    let index = match decide(&teams, wanted) {
        Pick::Team(index) => index,
        Pick::Ask => {
            let kinds = match list_kinds(dev).await {
                Ok(kinds) => kinds,
                Err(e) => {
                    tracing::warn!(
                        "{label}: couldn't tell free teams from paid ones, so none is marked: {}",
                        first_line(&report_text(&e))
                    );
                    HashMap::new()
                }
            };
            let choices = choices(&teams, &kinds);
            let marked: Vec<&str> = choices
                .iter()
                .map(|c| match c.kind {
                    Kind::Free => "free",
                    Kind::Paid => "paid",
                    Kind::Unknown => "unknown",
                })
                .collect();
            tracing::info!(
                "{label}: {} teams on this Apple Account ({}); asking which signs",
                choices.len(),
                marked.join(", ")
            );
            let answer = ask(&choices).ok_or_else(|| NONE_PICKED.to_string())?;
            answered(&teams, &answer)?
        }
    };
    Ok(teams.swap_remove(index))
}

/// Each team's kind, from Apple's listTeams asked again: isideload's
/// `DeveloperTeam` leaves out the memberships, and they're what tells a free
/// team from a paid one. Only asked when there's a question.
async fn list_kinds(dev: &mut DeveloperSession) -> Result<HashMap<String, Kind>, Report> {
    let listed: Vec<Listed> = dev
        .send_dev_request(&dev_url("listTeams", DeveloperDeviceType::Any), None, "teams")
        .await?;
    Ok(kinds(&listed))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn names(list: &[&str]) -> Vec<String> {
        list.iter().map(|s| s.to_string()).collect()
    }

    fn team(id: &str, name: Option<&str>) -> DeveloperTeam {
        DeveloperTeam {
            name: name.map(str::to_string),
            team_id: id.to_string(),
            r#type: Some("Individual".to_string()),
            status: Some("active".to_string()),
        }
    }

    fn two_teams() -> Vec<DeveloperTeam> {
        vec![team("ABCDE12345", Some("Frizzle")), team("FGHIJ67890", Some("Frizzle"))]
    }

    #[test]
    fn free_and_paid_as_altsign_tells_them() {
        let individual = Some("Individual");
        let company = Some("Company/Organization");
        assert_eq!(Kind::of(individual, &names(&["Some Free Program"])), Kind::Free);
        assert_eq!(Kind::of(individual, &names(&["free"])), Kind::Free);
        assert_eq!(Kind::of(individual, &names(&["Apple Developer Program"])), Kind::Paid);
        // More than one membership: paid, even with a free one among them.
        assert_eq!(
            Kind::of(individual, &names(&["Free", "Apple Developer Program"])),
            Kind::Paid
        );
        assert_eq!(Kind::of(company, &names(&["Apple Developer Program"])), Kind::Paid);
        assert_eq!(Kind::of(company, &[]), Kind::Paid);
        // Nothing to go by.
        assert_eq!(Kind::of(individual, &[]), Kind::Unknown);
        assert_eq!(Kind::of(Some("Something Else"), &names(&["Free"])), Kind::Unknown);
        assert_eq!(Kind::of(None, &names(&["Free"])), Kind::Unknown);
    }

    /// A listTeams answer as isideload gets it, read the way its
    /// `send_dev_request` reads one (`plist::from_value` on "teams"). The
    /// membership names are made up: only "free" in them counts.
    #[test]
    fn kinds_come_from_a_list_teams_answer() {
        let answer = br#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>resultCode</key><integer>0</integer>
  <key>teams</key>
  <array>
    <dict>
      <key>name</key><string>Frizzle</string>
      <key>teamId</key><string>ABCDE12345</string>
      <key>type</key><string>Individual</string>
      <key>status</key><string>active</string>
      <key>dateCreated</key><date>2024-05-01T10:00:00Z</date>
      <key>memberships</key>
      <array>
        <dict>
          <key>name</key><string>Xcode Free Provisioning</string>
          <key>platform</key><string>ios</string>
          <key>dateStart</key><date>2024-05-01T10:00:00Z</date>
        </dict>
      </array>
    </dict>
    <dict>
      <key>name</key><string>Frizzle</string>
      <key>teamId</key><string>FGHIJ67890</string>
      <key>type</key><string>Individual</string>
      <key>memberships</key>
      <array>
        <dict><key>name</key><string>Apple Developer Program</string></dict>
      </array>
    </dict>
    <dict>
      <key>name</key><string>Example Ltd</string>
      <key>teamId</key><string>KLMNO24680</string>
      <key>type</key><string>Company/Organization</string>
    </dict>
    <dict>
      <key>teamId</key><string>PQRST13579</string>
      <key>type</key><string>Individual</string>
    </dict>
  </array>
</dict>
</plist>"#;
        let dict: plist::Dictionary = plist::from_bytes(answer).unwrap();
        let listed: Vec<Listed> = plist::from_value(dict.get("teams").unwrap()).unwrap();
        let kinds = kinds(&listed);
        assert_eq!(kinds["ABCDE12345"], Kind::Free);
        assert_eq!(kinds["FGHIJ67890"], Kind::Paid);
        assert_eq!(kinds["KLMNO24680"], Kind::Paid);
        assert_eq!(kinds["PQRST13579"], Kind::Unknown);

        // isideload reads the same answer into its own teams, which the
        // question then lists in Apple's order.
        let teams: Vec<DeveloperTeam> = plist::from_value(dict.get("teams").unwrap()).unwrap();
        let json = serde_json::to_value(choices(&teams, &kinds)).unwrap();
        assert_eq!(
            json,
            serde_json::json!([
                {"teamId": "ABCDE12345", "name": "Frizzle", "kind": "free"},
                {"teamId": "FGHIJ67890", "name": "Frizzle", "kind": "paid"},
                {"teamId": "KLMNO24680", "name": "Example Ltd", "kind": "paid"},
                {"teamId": "PQRST13579", "name": "", "kind": "unknown"},
            ])
        );
    }

    #[test]
    fn a_team_list_teams_didnt_mark_is_unknown() {
        let choices = choices(&two_teams(), &HashMap::new());
        assert!(choices.iter().all(|c| c.kind == Kind::Unknown));
        assert_eq!(choices[1].team_id, "FGHIJ67890");
    }

    #[test]
    fn the_remembered_team_signs_without_a_question() {
        let teams = two_teams();
        assert_eq!(decide(&teams, Some("FGHIJ67890")), Pick::Team(1));
        assert_eq!(decide(&teams, Some("ABCDE12345")), Pick::Team(0));
    }

    #[test]
    fn more_than_one_team_and_none_remembered_asks() {
        let teams = two_teams();
        assert_eq!(decide(&teams, None), Pick::Ask);
        // A team the account is no longer on.
        assert_eq!(decide(&teams, Some("ZZZZZ99999")), Pick::Ask);
    }

    #[test]
    fn one_team_signs_whatever_was_remembered() {
        let teams = vec![team("ABCDE12345", Some("Frizzle"))];
        assert_eq!(decide(&teams, None), Pick::Team(0));
        assert_eq!(decide(&teams, Some("FGHIJ67890")), Pick::Team(0));
    }

    #[test]
    fn only_a_listed_team_is_taken_as_the_answer() {
        let teams = two_teams();
        assert_eq!(answered(&teams, "FGHIJ67890"), Ok(1));
        assert_eq!(answered(&teams, " ABCDE12345\n"), Ok(0));
        assert!(answered(&teams, "ZZZZZ99999").unwrap_err().contains("ZZZZZ99999"));
        assert!(answered(&teams, "").is_err());
    }

    #[test]
    fn the_summary_names_the_team_as_swift_reads_it() {
        assert_eq!(summary(&team("ABCDE12345", Some("Frizzle"))), "team: Frizzle (ABCDE12345)");
        assert_eq!(summary(&team("ABCDE12345", None)), "team: <unnamed> (ABCDE12345)");
    }
}
