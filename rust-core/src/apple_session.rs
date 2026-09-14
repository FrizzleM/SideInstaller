//! Keeps the developer-portal session between sign-ins, the way SideStore does.
//!
//! A full Apple ID sign-in costs two GrandSlam SRP requests plus an `apptokens`
//! request, all over again after 2FA, and Apple answers HTTP 429 to an account
//! or network that repeats that too often. The portal itself only needs the
//! account's `adsid` and its `com.apple.gs.xcode.auth` token, which Apple issues
//! with an expiry. SideStore's `AuthManager` keeps exactly those two and builds
//! every portal session from them; iLoader keeps one logged-in session for the
//! app's lifetime. This saves them beside the account's signing key and reuses
//! them in every feature and across launches, signing in again only when the
//! token has expired or Apple stops accepting it.

use std::future::Future;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use isideload::{
    anisette::remote_v3::RemoteV3AnisetteProvider,
    auth::apple_account::{
        AppToken, AppleAccount, TwoFactorCallbackParams, TwoFactorCallbackResponse,
    },
    dev::{
        developer_session::DeveloperSession,
        teams::{DeveloperTeam, TeamsApi},
    },
    util::fs_storage::FsStorage,
};
use rootcause::Report;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

/// Sign in again this long before Apple's stated expiry rather than race it.
const EXPIRY_MARGIN_SECS: u64 = 10 * 60;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
struct SavedSession {
    apple_id: String,
    adsid: String,
    token: String,
    /// Both as Apple sent them in the app-token response.
    duration: u64,
    expiry: u64,
    /// Unix seconds.
    saved_at: u64,
}

impl SavedSession {
    fn new(apple_id: &str, adsid: &str, token: &AppToken, now: u64) -> Self {
        SavedSession {
            apple_id: apple_id.to_string(),
            adsid: adsid.to_string(),
            token: token.token.clone(),
            duration: token.duration,
            expiry: token.expiry,
            saved_at: now,
        }
    }

    /// Unix seconds the token stops working, when that can be told. Apple
    /// doesn't document the unit, so milliseconds and seconds are both read; a
    /// token with neither is tried anyway, and the portal says if it's stale.
    fn expires_at(&self) -> Option<u64> {
        match self.expiry {
            e if e >= 100_000_000_000 => Some(e / 1000),
            e if e >= 1_000_000_000 => Some(e),
            _ if self.duration > 0 => Some(self.saved_at.saturating_add(self.duration)),
            _ => None,
        }
    }

    fn usable_for(&self, apple_id: &str, now: u64) -> bool {
        self.apple_id == apple_id
            && self
                .expires_at()
                .is_none_or(|expires| now.saturating_add(EXPIRY_MARGIN_SECS) < expires)
    }

    fn app_token(&self) -> AppToken {
        AppToken {
            token: self.token.clone(),
            duration: self.duration,
            expiry: self.expiry,
        }
    }

    /// For the console: how long Apple said the token lasts from `now`.
    fn describe_lifetime(&self, now: u64) -> String {
        match self.expires_at() {
            Some(expires) if expires > now => {
                let left = expires - now;
                format!(
                    " (Apple's token lasts {}d {}h more; expiry={}, duration={})",
                    left / 86_400,
                    left % 86_400 / 3_600,
                    self.expiry,
                    self.duration
                )
            }
            Some(_) => format!(" (expiry={}, duration={})", self.expiry, self.duration),
            None => " (Apple gave no expiry)".to_string(),
        }
    }
}

/// Where an account's session lives: beside isideload's `<sha256(email)>/key`,
/// hashed the same way, so both sit in that Apple ID's directory.
fn session_path(storage_dir: &Path, apple_id: &str) -> PathBuf {
    let hash = hex::encode(Sha256::digest(apple_id.as_bytes()));
    storage_dir.join(hash).join("developer_session.json")
}

fn load(storage_dir: &Path, apple_id: &str) -> Option<SavedSession> {
    let bytes = std::fs::read(session_path(storage_dir, apple_id)).ok()?;
    serde_json::from_slice(&bytes).ok()
}

/// Written to a temporary file and renamed, so a concurrent sign-in never reads
/// half a session.
fn store(storage_dir: &Path, session: &SavedSession) -> std::io::Result<()> {
    let path = session_path(storage_dir, &session.apple_id);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension("json.tmp");
    std::fs::write(&tmp, serde_json::to_vec(session).map_err(std::io::Error::other)?)?;
    std::fs::rename(tmp, path)
}

/// Drop an account's saved session. Returns whether there was one.
pub(crate) fn forget(storage_dir: &Path, apple_id: &str) -> bool {
    std::fs::remove_file(session_path(storage_dir, apple_id)).is_ok()
}

/// Whether a failure to use the saved session says nothing about the token —
/// the network, the anisette server, or Apple being busy. Those go back to the
/// caller's retry as they are. Anything else, such as a portal error or a 401,
/// means Apple no longer takes the token, which costs a fresh sign-in.
fn is_transient(error: &str) -> bool {
    let e = error.to_lowercase();
    e.contains("anisette")
        || e.contains("error sending request")
        || e.contains("timed out")
        || e.contains("(429 ")
        || e.contains("server error (5")
}

fn first_line(text: &str) -> &str {
    text.lines()
        .map(|line| line.trim_start_matches([' ', '●']).trim())
        .find(|line| !line.is_empty())
        .unwrap_or(text)
}

fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// A developer session for `apple_id`, with its teams. With `remember`, the
/// saved token is tried first and a fresh sign-in's token is saved; without it
/// (Side by Side, which signs in as someone else) nothing is read or kept.
pub(crate) async fn open<C, Fut>(
    apple_id: &str,
    password: &str,
    anisette_url: &str,
    storage_dir: &Path,
    remember: bool,
    two_factor: C,
    label: &str,
) -> Result<(DeveloperSession, Vec<DeveloperTeam>), String>
where
    C: Fn(TwoFactorCallbackParams) -> Fut + Send + Sync,
    Fut: Future<Output = Result<TwoFactorCallbackResponse, Report>> + Send,
{
    tracing::info!("{label}: building anisette provider ({anisette_url})");
    let anisette = RemoteV3AnisetteProvider::new(
        anisette_url,
        Box::new(FsStorage::new(storage_dir.to_path_buf())),
        "0".to_string(),
    )
    .map_err(|e| format!("anisette provider: {e}"))?;

    // Client info and the URL bag only: nothing here signs in.
    let mut account = AppleAccount::builder(apple_id)
        .anisette_provider(anisette)
        .build()
        .await
        .map_err(|e| format!("login failed: {e}"))?;

    let now = unix_now();
    let saved = if remember { load(storage_dir, apple_id) } else { None };
    if let Some(saved) = saved {
        if saved.usable_for(apple_id, now) {
            let mut dev = DeveloperSession::new(
                saved.app_token(),
                saved.adsid.clone(),
                account.grandslam_client.clone(),
                account.anisette_generator.clone(),
            );
            match dev.list_teams().await {
                Ok(teams) => {
                    tracing::info!(
                        "{label}: reused the saved developer session, so no Apple ID sign-in{}",
                        saved.describe_lifetime(now)
                    );
                    return Ok((dev, teams));
                }
                Err(e) => {
                    let text = format!("{e}");
                    if is_transient(&text) {
                        return Err(format!("developer session: {text}"));
                    }
                    tracing::info!(
                        "{label}: Apple no longer accepts the saved session ({}); signing in again",
                        first_line(&text)
                    );
                    forget(storage_dir, apple_id);
                }
            }
        } else {
            tracing::info!("{label}: the saved developer session has expired; signing in again");
            forget(storage_dir, apple_id);
        }
    }

    tracing::info!("{label}: logging in {apple_id}");
    account
        .login(password, two_factor)
        .await
        .map_err(|e| format!("login failed: {e}"))?;
    tracing::info!("{label}: login OK; opening developer session");

    let token = account
        .get_app_token("xcode.auth")
        .await
        .map_err(|e| format!("developer session: {e}"))?;
    let adsid = account
        .spd
        .as_ref()
        .and_then(|spd| spd.get("adsid"))
        .and_then(|value| value.as_string())
        .ok_or("developer session: the sign-in response carried no adsid")?
        .to_string();

    if remember {
        let saved = SavedSession::new(apple_id, &adsid, &token, now);
        match store(storage_dir, &saved) {
            Ok(()) => tracing::info!(
                "{label}: saved the developer session for later sign-ins{}",
                saved.describe_lifetime(now)
            ),
            Err(e) => tracing::warn!(
                "{label}: couldn't save the developer session ({e}); the next sign-in logs in again"
            ),
        }
    }

    let mut dev = DeveloperSession::new(
        token,
        adsid,
        account.grandslam_client.clone(),
        account.anisette_generator.clone(),
    );
    let teams = dev
        .list_teams()
        .await
        .map_err(|e| format!("list teams: {e}"))?;
    Ok((dev, teams))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn saved(expiry: u64, duration: u64, saved_at: u64) -> SavedSession {
        SavedSession {
            apple_id: "someone@example.com".into(),
            adsid: "001234-05-abcdef".into(),
            token: "AAAABLwIAAAAAGW".into(),
            duration,
            expiry,
            saved_at,
        }
    }

    const NOW: u64 = 1_789_300_000;

    #[test]
    fn reads_expiry_in_milliseconds_or_seconds() {
        assert_eq!(saved(1_789_400_000_000, 0, NOW).expires_at(), Some(1_789_400_000));
        assert_eq!(saved(1_789_400_000, 0, NOW).expires_at(), Some(1_789_400_000));
    }

    #[test]
    fn falls_back_to_duration_then_to_trying_the_token() {
        assert_eq!(saved(0, 3_600, NOW).expires_at(), Some(NOW + 3_600));
        assert_eq!(saved(0, 0, NOW).expires_at(), None);
        assert!(saved(0, 0, NOW).usable_for("someone@example.com", NOW));
    }

    #[test]
    fn signs_in_again_ahead_of_expiry_and_only_for_the_same_apple_id() {
        let session = saved(NOW + EXPIRY_MARGIN_SECS + 60, 0, NOW);
        assert!(session.usable_for("someone@example.com", NOW));
        assert!(!session.usable_for("someone@example.com", NOW + 120));
        assert!(!session.usable_for("someone.else@example.com", NOW));
        assert!(!saved(NOW - 1, 0, NOW - 100).usable_for("someone@example.com", NOW));
    }

    #[test]
    fn lives_beside_the_signing_key() {
        // isideload keys `<sha256(email)>/key`; SHA-256("abc") is the FIPS vector.
        assert_eq!(
            session_path(Path::new("/store"), "abc"),
            PathBuf::from(
                "/store/ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad/developer_session.json"
            )
        );
    }

    #[test]
    fn round_trips_and_forgets() {
        let dir = std::env::temp_dir().join(format!("si-session-test-{}", std::process::id()));
        let session = saved(1_789_400_000_000, 31_536_000, NOW);
        assert!(load(&dir, &session.apple_id).is_none());
        store(&dir, &session).unwrap();
        assert_eq!(load(&dir, &session.apple_id), Some(session.clone()));
        assert!(forget(&dir, &session.apple_id));
        assert!(load(&dir, &session.apple_id).is_none());
        assert!(!forget(&dir, &session.apple_id));
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn a_corrupt_file_reads_as_no_session() {
        let dir = std::env::temp_dir().join(format!("si-session-corrupt-{}", std::process::id()));
        let path = session_path(&dir, "someone@example.com");
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, b"{not json").unwrap();
        assert!(load(&dir, "someone@example.com").is_none());
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn only_network_anisette_and_busy_errors_keep_the_token() {
        for transient in [
            " ● Failed to get anisette headers\n ● HTTP status server error (522 <unknown status code>)",
            " ● error sending request for url (https://developerservices2.apple.com/services/QH65B2/listTeams.action)",
            " ● HTTP status client error (429 Too Many Requests) for url (https://developerservices2.apple.com/)",
            " ● Developer request failed\n ● HTTP status server error (503 Service Unavailable)",
        ] {
            assert!(is_transient(transient), "{transient}");
        }
        for rejected in [
            " ● Developer error 1100: Your session has expired. Please log in.",
            " ● Developer request failed\n ● HTTP status client error (401 Unauthorized) for url (https://developerservices2.apple.com/)",
            " ● Failed to extract developer request result",
        ] {
            assert!(!is_transient(rejected), "{rejected}");
        }
    }

    #[test]
    fn logs_the_first_meaningful_line() {
        assert_eq!(
            first_line("\n ● Developer error 1100: expired\n ├ src/dev.rs:1"),
            "Developer error 1100: expired"
        );
    }
}
