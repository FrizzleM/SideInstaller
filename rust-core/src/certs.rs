//! Apple developer certificate management — list and revoke iOS development
//! certificates, wrapping `isideload`'s `DeveloperSession` (the same path
//! iLoader uses for "see and revoke development certificates"). This is fully
//! independent of the install pipeline: revocation is a pure
//! developer-portal API call over the internet, so no device, pairing, or
//! LocalDevVPN tunnel is involved.
//!
//! `si_cert_signin` logs in (driving 2FA through the same Swift callback as
//! `account.rs`), opens a developer session, and selects the first team —
//! returning an opaque `CertSession`. `si_cert_list` returns the team's iOS
//! development certificates as a JSON array; `si_cert_revoke` revokes one by
//! its serial number.

use std::ffi::{c_char, c_void};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::PathBuf;

use isideload::{
    anisette::remote_v3::RemoteV3AnisetteProvider,
    auth::apple_account::AppleAccount,
    dev::{
        certificates::{CertificatesApi, DevelopmentCertificate},
        developer_session::DeveloperSession,
        device_type::DeveloperDeviceType,
        teams::{DeveloperTeam, TeamsApi},
    },
    util::fs_storage::FsStorage,
};
use serde::Serialize;

use crate::account::{make_2fa, TwoFactorCb, TwoFaCtx};
use crate::ffi_util::{cstr, opt_str};

/// Opaque session handle: owns the tokio runtime, the developer session, and
/// the selected team (the team id is needed for every cert request).
pub struct CertSession {
    rt: tokio::runtime::Runtime,
    dev: DeveloperSession,
    team: DeveloperTeam,
}

// Used only through its own runtime, serialized by Swift on one queue.
unsafe impl Send for CertSession {}

/// Flattened, JSON-friendly view of a development certificate. Every field is a
/// plain string so the Swift side can decode it without optionals.
#[derive(Serialize)]
struct CertInfo {
    name: String,
    serial_number: String,
    machine_name: String,
    machine_id: String,
    certificate_id: String,
    platform: String,
    status: String,
    /// RFC3339 expiry (e.g. `2027-01-01T00:00:00Z`), or "" if Apple omitted it.
    expiration: String,
}

impl From<&DevelopmentCertificate> for CertInfo {
    fn from(c: &DevelopmentCertificate) -> Self {
        let s = |o: &Option<String>| o.clone().unwrap_or_default();
        CertInfo {
            name: s(&c.name),
            serial_number: s(&c.serial_number),
            machine_name: s(&c.machine_name),
            machine_id: s(&c.machine_id),
            certificate_id: s(&c.certificate_id),
            platform: s(&c.certificate_platform),
            status: s(&c.status),
            // plist::Date's XML form is RFC3339 (e.g. 2027-01-01T00:00:00Z).
            expiration: c
                .expiration_date
                .as_ref()
                .map(|d| d.to_xml_format())
                .unwrap_or_default(),
        }
    }
}

/// Log in, open a developer session, and select the first team.
///
/// Returns 0 on success (`*out_session` + `*out_summary` set), non-zero on
/// error (`*out_error` set). Free strings with `si_string_free`, the session
/// with `si_cert_session_free`.
///
/// # Safety
/// All `*const c_char` args must be null or valid C strings; the out pointers
/// must be valid and writable.
#[allow(clippy::too_many_arguments)]
pub unsafe fn cert_signin(
    apple_id: *const c_char,
    password: *const c_char,
    anisette_url: *const c_char,
    // Accepted for signature parity with `si_apple_signin` (and a future CSR
    // path); listing/revoking certs needs no machine name.
    _machine_name: *const c_char,
    storage_dir: *const c_char,
    twofa_cb: TwoFactorCb,
    ctx: *mut c_void,
    out_session: *mut *mut CertSession,
    out_summary: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let apple_id = opt_str(apple_id, "");
    let password = opt_str(password, "");
    let anisette_url = opt_str(anisette_url, "https://ani.sidestore.io");
    let storage_dir = opt_str(storage_dir, ".");
    let twofa = make_2fa(twofa_cb, TwoFaCtx(ctx));

    let result = catch_unwind(AssertUnwindSafe(|| {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|e| format!("failed to start runtime: {e}"))?;

        let (dev, team, summary) = rt.block_on(async {
            tracing::info!("Certs: building anisette provider ({anisette_url})");
            let anisette = RemoteV3AnisetteProvider::new(
                &anisette_url,
                Box::new(FsStorage::new(PathBuf::from(&storage_dir))),
                "0".to_string(),
            )
            .map_err(|e| format!("anisette provider: {e}"))?;

            tracing::info!("Certs: logging in {apple_id}");
            let mut account = AppleAccount::builder(&apple_id)
                .anisette_provider(anisette)
                .login(&password, twofa)
                .await
                .map_err(|e| format!("login failed: {e}"))?;
            tracing::info!("Certs: login OK; opening developer session");

            let mut dev = DeveloperSession::from_account(&mut account)
                .await
                .map_err(|e| format!("developer session: {e}"))?;

            let teams = dev
                .list_teams()
                .await
                .map_err(|e| format!("list teams: {e}"))?;
            let team = teams
                .into_iter()
                .next()
                .ok_or_else(|| "no development teams on this Apple ID".to_string())?;
            tracing::info!(
                "Certs: using team {} ({})",
                team.name.as_deref().unwrap_or("<unnamed>"),
                team.team_id
            );

            let summary = format!(
                "team: {} ({})",
                team.name.as_deref().unwrap_or("<unnamed>"),
                team.team_id
            );
            Ok::<_, String>((dev, team, summary))
        })?;

        Ok::<_, String>((rt, dev, team, summary))
    }));

    match result {
        Ok(Ok((rt, dev, team, summary))) => {
            let session = Box::new(CertSession { rt, dev, team });
            *out_session = Box::into_raw(session);
            *out_summary = cstr(summary);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during certificate sign-in");
            2
        }
    }
}

/// List the team's iOS development certificates as a JSON array of objects
/// (see `CertInfo`). Returns 0 on success (`*out_json` set), non-zero on error.
///
/// # Safety
/// `session` must be a valid pointer from `cert_signin`; out pointers valid.
pub unsafe fn cert_list(
    session: *mut CertSession,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() {
        *out_error = cstr("null session");
        return 2;
    }
    let session = &mut *session;

    let result = catch_unwind(AssertUnwindSafe(|| {
        session.rt.block_on(async {
            let certs = session
                .dev
                .list_ios_certs(&session.team)
                .await
                .map_err(|e| format!("list certs failed: {e}"))?;
            tracing::info!("Certs: {} iOS development certificate(s)", certs.len());
            let infos: Vec<CertInfo> = certs.iter().map(CertInfo::from).collect();
            serde_json::to_string(&infos).map_err(|e| format!("serialize certs: {e}"))
        })
    }));

    match result {
        Ok(Ok(json)) => {
            *out_json = cstr(json);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic while listing certificates");
            2
        }
    }
}

/// Revoke the development certificate with `serial_number`. Returns 0 on
/// success, non-zero on error (`*out_error` set).
///
/// # Safety
/// `session` must be a valid pointer from `cert_signin`; `serial_number` a
/// valid C string; `out_error` valid and writable.
pub unsafe fn cert_revoke(
    session: *mut CertSession,
    serial_number: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() {
        *out_error = cstr("null session");
        return 2;
    }
    let session = &mut *session;
    let serial = opt_str(serial_number, "");
    if serial.is_empty() {
        *out_error = cstr("empty serial number");
        return 2;
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        session.rt.block_on(async {
            tracing::info!("Certs: revoking certificate {serial}");
            session
                .dev
                .revoke_development_cert(&session.team, &serial, DeveloperDeviceType::Ios)
                .await
                .map_err(|e| format!("revoke failed: {e}"))?;
            Ok::<_, String>(())
        })
    }));

    match result {
        Ok(Ok(())) => {
            tracing::info!("Certs: revoked {serial}");
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic while revoking certificate");
            2
        }
    }
}

/// Free a `CertSession`.
///
/// # Safety
/// `session` must be null or a pointer from `cert_signin`.
pub unsafe fn cert_session_free(session: *mut CertSession) {
    if !session.is_null() {
        drop(Box::from_raw(session));
    }
}
