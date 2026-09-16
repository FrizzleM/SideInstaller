//! Saves and reuses the developer-portal session between sign-ins, like
//! SideStore's `AuthManager`.
//!
//! A full sign-in (GrandSlam SRP requests, 2FA, `apptokens`) is rate-limited by
//! Apple (HTTP 429). The portal only needs the account's `adsid` and its
//! `com.apple.gs.xcode.auth` token, which has an expiry. Both are saved next to
//! the account's signing key and reused across features and launches; a full
//! sign-in happens only when the token expires or is rejected.

use std::future::Future;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use isideload::{
    anisette::{remote_v3::RemoteV3AnisetteProvider, AnisetteDataGenerator, AnisetteProvider},
    auth::{
        apple_account::{AppToken, AppleAccount, TwoFactorCallbackParams, TwoFactorCallbackResponse},
        grandslam::GrandSlam,
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
use tokio::sync::RwLock;

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

    /// Unix time (seconds) when the token expires, if known. Apple doesn't
    /// document the unit, so both milliseconds and seconds are handled. A token
    /// without an expiry is tried anyway.
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

/// Path of an account's saved session: `<sha256(email)>/developer_session.json`,
/// next to isideload's `<sha256(email)>/key`.
fn session_path(storage_dir: &Path, apple_id: &str) -> PathBuf {
    let hash = hex::encode(Sha256::digest(apple_id.as_bytes()));
    storage_dir.join(hash).join("developer_session.json")
}

fn load(storage_dir: &Path, apple_id: &str) -> Option<SavedSession> {
    let bytes = std::fs::read(session_path(storage_dir, apple_id)).ok()?;
    serde_json::from_slice(&bytes).ok()
}

/// Writes to a temp file and renames it, so a concurrent reader never sees a
/// partial file.
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

/// True for errors unrelated to the token (network, anisette server, Apple
/// busy); these are returned to the caller as-is. Other errors (portal error,
/// 401) mean the token was rejected, so a full sign-in follows.
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

/// Opens a developer session for `apple_id` and lists its teams. With
/// `remember`, the saved token is tried first and a new one is saved; without
/// it (Side by Side, which uses someone else's account) nothing is read or saved.
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
    let now = unix_now();
    let saved = if remember { load(storage_dir, apple_id) } else { None };

    // Reusing a saved session only talks to the developer portal, which needs no
    // GrandSlam URL bag, so that's tried first without fetching one. If anything
    // goes wrong there, the path below checks the session again as it always has.
    if let Some(saved) = saved.as_ref().filter(|s| s.usable_for(apple_id, now)) {
        match reuse_without_url_bag(saved, anisette_url, storage_dir).await {
            Ok(opened) => {
                tracing::info!(
                    "{label}: reused the saved developer session, so no Apple ID sign-in{}",
                    saved.describe_lifetime(now)
                );
                return Ok(opened);
            }
            Err(e) => tracing::info!(
                "{label}: couldn't reuse the saved session straight away ({}); checking it with a full sign-in client",
                first_line(&e)
            ),
        }
    }

    tracing::info!("{label}: building anisette provider ({anisette_url})");
    let anisette = RemoteV3AnisetteProvider::new(
        anisette_url,
        Box::new(FsStorage::new(storage_dir.to_path_buf())),
        "0".to_string(),
    )
    .map_err(|e| format!("anisette provider: {e}"))?;

    // Only fetches client info and the URL bag; doesn't sign in.
    let mut account = AppleAccount::builder(apple_id)
        .anisette_provider(anisette)
        .build()
        .await
        .map_err(|e| format!("login failed: {e}"))?;

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

/// Opens a saved session on a GrandSlam client that skipped the URL bag, and
/// lists its teams. Anisette state already on disk is used as it is; state that
/// still needs provisioning (which reads the bag) makes this fail, and the
/// caller then takes the full path.
async fn reuse_without_url_bag(
    saved: &SavedSession,
    anisette_url: &str,
    storage_dir: &Path,
) -> Result<(DeveloperSession, Vec<DeveloperTeam>), String> {
    let anisette = RemoteV3AnisetteProvider::new(
        anisette_url,
        Box::new(FsStorage::new(storage_dir.to_path_buf())),
        "0".to_string(),
    )
    .map_err(|e| format!("anisette provider: {e}"))?;
    let client_info = anisette
        .get_client_info()
        .await
        .map_err(|e| format!("anisette client info: {e}"))?;
    let client = GrandSlam::without_url_bag(client_info, false)
        .map_err(|e| format!("GrandSlam client: {e}"))?;
    let mut dev = DeveloperSession::new(
        saved.app_token(),
        saved.adsid.clone(),
        Arc::new(client),
        AnisetteDataGenerator::new(Arc::new(RwLock::new(anisette))),
    );
    let teams = dev.list_teams().await.map_err(|e| format!("{e}"))?;
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
