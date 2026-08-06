//! Apple ID sign-in and IPA signing through `isideload`, using only its
//! sign-only path, since the install runs over our own RSD tunnel.
//!
//! `si_apple_signin` logs in, opens a developer session on the first team, and
//! returns an opaque `SignSession`. `si_sign_ipa` then signs an IPA with it,
//! registering the App ID, profile and certificate along the way.

use std::ffi::{c_char, c_void, CStr};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::PathBuf;

use isideload::{
    anisette::remote_v3::RemoteV3AnisetteProvider,
    auth::apple_account::AppleAccount,
    dev::{developer_session::DeveloperSession, devices::DevicesApi},
    sideload::{builder::MaxCertsBehavior, sideloader::Sideloader, SideloaderBuilder, TeamSelection},
    util::fs_storage::FsStorage,
};

use crate::ffi_util::cstr;

/// `int (*)(void *ctx, char *out_buf, size_t buf_len)` — fills `out_buf` with a
/// NUL-terminated 2FA code and returns 1, or returns 0 if the user cancelled.
pub type TwoFactorCb =
    Option<extern "C" fn(ctx: *mut c_void, out_buf: *mut c_char, buf_len: usize) -> i32>;

/// Opaque handle owning the tokio runtime and the built Sideloader.
pub struct SignSession {
    rt: tokio::runtime::Runtime,
    sideloader: Sideloader,
}

// Used only through its own runtime, serialized by Swift on one queue.
unsafe impl Send for SignSession {}

/// Wraps the 2FA callback context so it can cross thread boundaries.
pub(crate) struct TwoFaCtx(pub(crate) *mut c_void);
unsafe impl Send for TwoFaCtx {}
unsafe impl Sync for TwoFaCtx {}

unsafe fn opt(p: *const c_char, default: &str) -> String {
    if p.is_null() {
        return default.to_string();
    }
    CStr::from_ptr(p).to_str().unwrap_or(default).to_string()
}

/// Build the 2FA closure that bridges to Swift, shared with `certs.rs`.
pub(crate) fn make_2fa(cb: TwoFactorCb, ctx: TwoFaCtx) -> impl Fn() -> Option<String> {
    move || {
        let cb = cb?;
        let mut buf = vec![0u8; 128];
        let rc = cb(ctx.0, buf.as_mut_ptr() as *mut c_char, buf.len());
        if rc == 0 {
            return None;
        }
        // Read the NUL-terminated code Swift wrote into the buffer.
        let end = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
        let s = String::from_utf8_lossy(&buf[..end]).trim().to_string();
        if s.is_empty() {
            None
        } else {
            Some(s)
        }
    }
}

/// Log in, open a developer session, and build a Sideloader. Returns 0 on
/// success; free the session with `si_sign_session_free`.
///
/// # Safety
/// All `*const c_char` args must be null or valid C strings; the out pointers
/// must be valid and writable.
#[allow(clippy::too_many_arguments)]
pub unsafe fn apple_signin(
    apple_id: *const c_char,
    password: *const c_char,
    anisette_url: *const c_char,
    machine_name: *const c_char,
    storage_dir: *const c_char,
    twofa_cb: TwoFactorCb,
    ctx: *mut c_void,
    out_session: *mut *mut SignSession,
    out_summary: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let apple_id = opt(apple_id, "");
    let password = opt(password, "");
    let anisette_url = opt(anisette_url, "https://ani.sidestore.io");
    let machine_name = opt(machine_name, "SideInstaller");
    let storage_dir = opt(storage_dir, ".");
    let twofa = make_2fa(twofa_cb, TwoFaCtx(ctx));

    let result = catch_unwind(AssertUnwindSafe(|| {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|e| format!("failed to start runtime: {e}"))?;

        let sideloader = rt.block_on(async {
            tracing::info!("Apple ID: building anisette provider ({anisette_url})");
            let anisette = RemoteV3AnisetteProvider::new(
                &anisette_url,
                Box::new(FsStorage::new(PathBuf::from(&storage_dir))),
                "0".to_string(),
            )
            .map_err(|e| format!("anisette provider: {e}"))?;

            tracing::info!("Apple ID: logging in {apple_id}");
            let mut account = AppleAccount::builder(&apple_id)
                .anisette_provider(anisette)
                .login(&password, twofa)
                .await
                .map_err(|e| format!("login failed: {e}"))?;
            tracing::info!("Apple ID: login OK; opening developer session");

            let dev_session = DeveloperSession::from_account(&mut account)
                .await
                .map_err(|e| format!("developer session: {e}"))?;
            tracing::info!("Developer session OK; building sideloader (first team)");

            let mut sideloader = SideloaderBuilder::new(dev_session, apple_id.clone())
                .team_selection(TeamSelection::First)
                .max_certs_behavior(MaxCertsBehavior::Error)
                .storage(Box::new(FsStorage::new(PathBuf::from(&storage_dir))))
                .machine_name(machine_name.clone())
                .build();

            // Surface the selected team for the summary.
            let team = sideloader
                .get_team()
                .await
                .map_err(|e| format!("get_team: {e}"))?;
            let summary = format!(
                "team: {} ({})",
                team.name.as_deref().unwrap_or("<unnamed>"),
                team.team_id
            );
            Ok::<_, String>((sideloader, summary))
        })?;

        Ok::<_, String>((rt, sideloader))
    }));

    match result {
        Ok(Ok((rt, (sideloader, summary)))) => {
            let session = Box::new(SignSession { rt, sideloader });
            *out_session = Box::into_raw(session);
            *out_summary = cstr(summary);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during Apple ID sign-in");
            2
        }
    }
}

/// Sign the IPA at `ipa_path`, setting `*out_signed_path` to the `.app` bundle.
///
/// `udid` is registered with the team before the profile is requested, or Apple
/// rejects it with error 8220. A failure there is prefixed `device registration
/// failed for UDID <udid>:` so the caller can show it. Empty `udid` skips this.
///
/// # Safety
/// `session` must be a valid pointer from `apple_signin`; out pointers valid.
pub unsafe fn sign_ipa(
    session: *mut SignSession,
    ipa_path: *const c_char,
    udid: *const c_char,
    device_name: *const c_char,
    out_signed_path: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() {
        *out_error = cstr("null session");
        return 2;
    }
    let session = &mut *session;
    let ipa_path = opt(ipa_path, "");
    let udid = opt(udid, "");
    let device_name = opt(device_name, "");

    let result = catch_unwind(AssertUnwindSafe(|| {
        session.rt.block_on(async {
            // The profile needs a device to bind to, and `sign_app` never
            // registers one; only isideload's unused `install_app` does.
            if udid.is_empty() {
                tracing::warn!(
                    "No device UDID provided; skipping registration — provisioning \
                     profile download may fail with developer error 8220."
                );
            } else {
                let team = session
                    .sideloader
                    .get_team()
                    .await
                    .map_err(|e| format!("device registration failed for UDID {udid}: {e}"))?;
                let name = if device_name.is_empty() {
                    "iPhone"
                } else {
                    device_name.as_str()
                };
                tracing::info!("Ensuring device {udid} ({name}) is registered on team {}", team.team_id);
                session
                    .sideloader
                    .get_dev_session()
                    .ensure_device_registered(&team, name, &udid, None)
                    .await
                    .map_err(|e| format!("device registration failed for UDID {udid}: {e}"))?;
                tracing::info!("Device {udid} is registered on the team");
            }

            tracing::info!("Signing IPA at {ipa_path}");
            let (signed, _special) = session
                .sideloader
                .sign_app(PathBuf::from(&ipa_path), None, false)
                .await
                .map_err(|e| format!("sign_app failed: {e}"))?;
            Ok::<_, String>(signed.to_string_lossy().to_string())
        })
    }));

    match result {
        Ok(Ok(path)) => {
            tracing::info!("Signed bundle at {path}");
            *out_signed_path = cstr(path);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during signing");
            2
        }
    }
}

/// Free a `SignSession`.
///
/// # Safety
/// `session` must be null or a pointer from `apple_signin`.
pub unsafe fn sign_session_free(session: *mut SignSession) {
    if !session.is_null() {
        drop(Box::from_raw(session));
    }
}
