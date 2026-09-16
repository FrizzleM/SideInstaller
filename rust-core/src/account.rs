//! Apple ID sign-in and IPA signing via `isideload`. Only its signing path is
//! used; installing happens over the app's own RSD tunnel.
//!
//! `si_apple_signin` logs in, opens a developer session on the first team, and
//! returns an opaque `SignSession`. `si_sign_ipa` then signs an IPA with it,
//! registering the App ID, profile and certificate along the way.

use std::ffi::{c_char, c_void, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::{Path, PathBuf};

use base64::{prelude::BASE64_STANDARD, Engine as _};
use isideload::{
    anisette::remote_v3::state::AnisetteState,
    auth::apple_account::{TwoFactorCallbackParams, TwoFactorCallbackResponse},
    sideload::{
        builder::MaxCertsBehavior, cert_identity::CertificateIdentity, sideloader::Sideloader,
        SideloaderBuilder, TeamSelection,
    },
    util::{fs_storage::FsStorage, storage::SideloadingStorage},
};

use rootcause::Report;
use serde::{Deserialize, Serialize};

use crate::apple_session;
use crate::ffi_util::cstr;

/// `int (*)(void *ctx, const char *request_json, char *out_buf, size_t buf_len)`.
///
/// `request_json` is a [`TwoFactorRequest`]: what Apple is waiting for. Swift
/// writes a NUL-terminated [`TwoFactorAnswer`] as JSON into `out_buf` and
/// returns 1, or returns 0 if the user cancelled.
pub type TwoFactorCb = Option<
    extern "C" fn(
        ctx: *mut c_void,
        request_json: *const c_char,
        out_buf: *mut c_char,
        buf_len: usize,
    ) -> i32,
>;

/// What the 2FA prompt is being asked for.
#[derive(Serialize, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub(crate) struct TwoFactorRequest {
    /// Where the pending code went: `device`, `sms` or `voice`. `choose` when
    /// the last method failed and nothing is pending.
    method: &'static str,
    selected_number_id: Option<u32>,
    last_error: Option<String>,
    numbers: Vec<TwoFactorNumber>,
}

#[derive(Serialize, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub(crate) struct TwoFactorNumber {
    id: u32,
    /// Masked by Apple, as in `+39 ••• ••• ••89`.
    number: String,
    /// `sms` or `voice`, or empty when Apple doesn't say. A `voice` number
    /// can't take a text.
    push_mode: String,
}

impl From<&TwoFactorCallbackParams> for TwoFactorRequest {
    fn from(params: &TwoFactorCallbackParams) -> Self {
        let method = if params.unknown {
            "choose"
        } else if params.voice {
            "voice"
        } else if params.sms {
            "sms"
        } else {
            "device"
        };
        TwoFactorRequest {
            method,
            selected_number_id: params.selected_number_id,
            last_error: params.last_error.clone(),
            numbers: params
                .numbers
                .iter()
                .map(|n| TwoFactorNumber {
                    id: n.id,
                    number: n.number_with_dial_code.clone(),
                    push_mode: n.push_mode.clone(),
                })
                .collect(),
        }
    }
}

/// The user's reply, as Swift sends it.
#[derive(Deserialize, Debug, PartialEq)]
#[serde(tag = "action", rename_all = "lowercase")]
pub(crate) enum TwoFactorAnswer {
    Code { code: String },
    Sms { id: u32 },
    Voice { id: u32 },
    Devices,
    Resend,
}

impl From<TwoFactorAnswer> for TwoFactorCallbackResponse {
    fn from(answer: TwoFactorAnswer) -> Self {
        match answer {
            TwoFactorAnswer::Code { code } => Self::SubmitCode(code.trim().to_string()),
            TwoFactorAnswer::Sms { id } => Self::SendSms(id),
            TwoFactorAnswer::Voice { id } => Self::CallNumber(id),
            TwoFactorAnswer::Devices => Self::SendToDevices,
            TwoFactorAnswer::Resend => Self::ResendCode,
        }
    }
}

/// Opaque handle owning the tokio runtime and the built Sideloader.
pub struct SignSession {
    rt: tokio::runtime::Runtime,
    sideloader: Sideloader,
    /// Stored because `Sideloader` doesn't expose them; `account_config` needs
    /// both to look up the signing identity the same way `sign_app` does.
    machine_name: String,
    storage_dir: PathBuf,
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

/// Build the 2FA closure that bridges to Swift, shared with `certs.rs`. The
/// callback blocks until the user answers, so the future is already resolved.
pub(crate) fn make_2fa(
    cb: TwoFactorCb,
    ctx: TwoFaCtx,
) -> impl Fn(TwoFactorCallbackParams) -> std::future::Ready<Result<TwoFactorCallbackResponse, Report>>
       + Send
       + Sync {
    move |params| std::future::ready(Ok(ask_swift(cb, &ctx, &params)))
}

fn ask_swift(
    cb: TwoFactorCb,
    ctx: &TwoFaCtx,
    params: &TwoFactorCallbackParams,
) -> TwoFactorCallbackResponse {
    let Some(cb) = cb else {
        return TwoFactorCallbackResponse::Abort;
    };
    let request = serde_json::to_string(&TwoFactorRequest::from(params))
        .ok()
        .and_then(|json| CString::new(json).ok());
    let Some(request) = request else {
        tracing::error!("2FA: couldn't encode the prompt for Swift; aborting");
        return TwoFactorCallbackResponse::Abort;
    };
    let mut buf = vec![0u8; 512];
    let rc = cb(ctx.0, request.as_ptr(), buf.as_mut_ptr() as *mut c_char, buf.len());
    if rc == 0 {
        return TwoFactorCallbackResponse::Abort;
    }
    // Read the NUL-terminated answer Swift wrote into the buffer.
    let end = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
    parse_answer(&buf[..end])
}

fn parse_answer(bytes: &[u8]) -> TwoFactorCallbackResponse {
    match serde_json::from_slice::<TwoFactorAnswer>(bytes) {
        Ok(answer) => answer.into(),
        Err(e) => {
            tracing::error!("2FA: unreadable answer from Swift ({e}); aborting");
            TwoFactorCallbackResponse::Abort
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
    remember_session: i32,
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
            let (dev_session, teams) = apple_session::open(
                &apple_id,
                &password,
                &anisette_url,
                Path::new(&storage_dir),
                remember_session != 0,
                twofa,
                "Apple ID",
            )
            .await?;
            tracing::info!("Developer session OK; building sideloader (first team)");

            let mut sideloader = SideloaderBuilder::new(dev_session, apple_id.clone())
                .team_selection(TeamSelection::First)
                .max_certs_behavior(MaxCertsBehavior::Error)
                .storage(Box::new(FsStorage::new(PathBuf::from(&storage_dir))))
                .machine_name(machine_name.clone())
                .build();
            // `open` has just listed the teams, and TeamSelection::First takes
            // the first of them, so it's handed over rather than listed again.
            if let Some(first) = teams.into_iter().next() {
                sideloader.set_team(first);
            }

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
            let session = Box::new(SignSession {
                rt,
                sideloader,
                machine_name,
                storage_dir: PathBuf::from(&storage_dir),
            });
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
            // The provisioning profile needs a registered device; `sign_app`
            // registers it alongside its other requests to Apple.
            let name = if device_name.is_empty() {
                "iPhone"
            } else {
                device_name.as_str()
            };
            let device = if udid.is_empty() {
                tracing::warn!(
                    "No device UDID provided; skipping registration — provisioning \
                     profile download may fail with developer error 8220."
                );
                None
            } else {
                tracing::info!("Registering device {udid} ({name}) with the team while signing");
                Some((name, udid.as_str()))
            };

            tracing::info!("Signing IPA at {ipa_path}");
            let (signed, _special) = session
                .sideloader
                .sign_app(PathBuf::from(&ipa_path), None, false, device)
                .await
                .map_err(|e| {
                    // Left unprefixed so the app still recognises a failed
                    // registration and shows its guide.
                    let message = e.to_string();
                    if message.starts_with("device registration failed") {
                        message
                    } else {
                        format!("sign_app failed: {message}")
                    }
                })?;
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

/// Build the `Account.sideconf` JSON that SideStore imports on launch, setting
/// `*out_json` to it.
///
/// SideStore can only sign with a certificate whose private key it has; without
/// this file it revokes our certificate and re-signs itself on first sign-in.
/// `LaunchViewController.detectAndImportAccountFile` reads the file from
/// SideStore's Documents, imports the certificate and deletes the file. Swift
/// writes it there over the tunnel.
///
/// The Apple ID password is **not** included: SideStore asks for it anyway, and
/// the file sits as plaintext in a Files-visible folder until it's imported.
///
/// Only looks up an existing certificate (never creates or revokes one), so an
/// IPA must have been signed first.
///
/// # Safety
/// `session` must be a valid pointer from `apple_signin`; out pointers valid.
pub unsafe fn account_config(
    session: *mut SignSession,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() {
        *out_error = cstr("null session");
        return 2;
    }
    let session = &mut *session;

    let result = catch_unwind(AssertUnwindSafe(|| {
        let machine_name = session.machine_name.clone();
        let storage = FsStorage::new(session.storage_dir.clone());

        // SideStore wants the same two values isideload hands the anisette
        // server, encoded the same way: base64 of the 16 identifier bytes, and
        // base64 of the provisioned adi.pb.
        let (anisette_identifier, anisette_adi_blob) = {
            let raw = storage
                .retrieve_data("anisette_state")
                .map_err(|e| format!("could not read the anisette state: {e}"))?
                .ok_or("no anisette state stored yet — sign in first")?;
            let state: AnisetteState = plist::from_bytes(&raw)
                .map_err(|e| format!("could not parse the anisette state: {e}"))?;
            let adi_pb = state
                .adi_pb
                .ok_or("this device hasn't been provisioned with the anisette server yet")?;
            (
                BASE64_STANDARD.encode(state.keychain_identifier),
                BASE64_STANDARD.encode(adi_pb),
            )
        };

        session.rt.block_on(async {
            let team = session
                .sideloader
                .get_team()
                .await
                .map_err(|e| format!("get_team: {e}"))?;
            let email = session.sideloader.get_email().to_string();

            tracing::info!("Looking up the '{machine_name}' certificate to hand over");
            let identity = CertificateIdentity::retrieve_existing(
                &machine_name,
                &email,
                session.sideloader.get_dev_session(),
                &team,
                &storage,
            )
            .await
            .map_err(|e| format!("certificate lookup failed: {e}"))?
            .ok_or_else(|| {
                format!(
                    "no '{machine_name}' certificate on this Apple ID yet — install \
                     an app first, which is what creates it"
                )
            })?;

            // The machine id is the password AltStore-family apps expect a
            // handed-over p12 to carry.
            let cert_password = identity.machine_id.clone();
            let p12 = identity
                .as_p12(&cert_password)
                .await
                .map_err(|e| format!("failed to build the PKCS#12 archive: {e}"))?;

            let payload = serde_json::json!({
                "version": "2.0",
                "email": email,
                "certificateData": BASE64_STANDARD.encode(&p12),
                "certType": "encrypted",
                "certificatePassword": cert_password,
                "anisetteIdentifier": anisette_identifier,
                "anisetteAdiBlob": anisette_adi_blob,
            });

            tracing::info!(
                "Built account config for certificate {} ({} byte p12)",
                identity.get_serial_number(),
                p12.len()
            );
            Ok::<_, String>(payload.to_string())
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
            *out_error = cstr("panic while building the account config");
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

#[cfg(test)]
mod two_factor_bridge_tests {
    use super::*;
    use isideload::auth::apple_account::TrustedNumber;

    fn numbers() -> Vec<TrustedNumber> {
        serde_json::from_str(
            r#"[{"numberWithDialCode":"+39 ••• ••• ••89","lastTwoDigits":"89","pushMode":"sms","id":1},
                {"numberWithDialCode":"+39 ••• ••• ••12","lastTwoDigits":"12","pushMode":"voice","id":4}]"#,
        )
        .unwrap()
    }

    fn params(unknown: bool, sms: bool, voice: bool, selected: Option<u32>) -> TwoFactorCallbackParams {
        TwoFactorCallbackParams {
            last_error: None,
            unknown,
            sms,
            voice,
            numbers: numbers(),
            selected_number_id: selected,
        }
    }

    fn request_json(p: &TwoFactorCallbackParams) -> serde_json::Value {
        serde_json::to_value(TwoFactorRequest::from(p)).unwrap()
    }

    #[test]
    fn device_prompt_lists_the_numbers_without_selecting_one() {
        let json = request_json(&params(false, false, false, None));
        assert_eq!(json["method"], "device");
        assert_eq!(json["selectedNumberId"], serde_json::Value::Null);
        assert_eq!(json["numbers"][1]["number"], "+39 ••• ••• ••12");
        assert_eq!(json["numbers"][1]["pushMode"], "voice");
    }

    #[test]
    fn phone_prompts_name_the_method_and_the_number() {
        let sms = request_json(&params(false, true, false, Some(1)));
        assert_eq!(sms["method"], "sms");
        assert_eq!(sms["selectedNumberId"], 1);
        let call = request_json(&params(false, true, true, Some(4)));
        assert_eq!(call["method"], "voice");
    }

    #[test]
    fn a_failed_method_asks_the_user_to_choose() {
        let mut p = params(true, false, false, None);
        p.last_error = Some("Unknown 2FA method - try another".into());
        let json = request_json(&p);
        assert_eq!(json["method"], "choose");
        assert_eq!(json["lastError"], "Unknown 2FA method - try another");
    }

    #[test]
    fn answers_map_onto_isideload_responses() {
        use TwoFactorCallbackResponse as R;
        assert!(matches!(parse_answer(br#"{"action":"code","code":" 123456 "}"#), R::SubmitCode(c) if c == "123456"));
        assert!(matches!(parse_answer(br#"{"action":"sms","id":1}"#), R::SendSms(1)));
        assert!(matches!(parse_answer(br#"{"action":"voice","id":4}"#), R::CallNumber(4)));
        assert!(matches!(parse_answer(br#"{"action":"devices"}"#), R::SendToDevices));
        assert!(matches!(parse_answer(br#"{"action":"resend"}"#), R::ResendCode));
        // Swift's JSONEncoder puts the tag last, byte for byte like this.
        assert!(matches!(parse_answer(br#"{"id":4,"action":"voice"}"#), R::CallNumber(4)));
        assert!(matches!(parse_answer(br#"{"code":"123456","action":"code"}"#), R::SubmitCode(c) if c == "123456"));
    }

    #[test]
    fn an_unreadable_answer_aborts() {
        use TwoFactorCallbackResponse as R;
        assert!(matches!(parse_answer(b"123456"), R::Abort));
        assert!(matches!(parse_answer(br#"{"action":"sms"}"#), R::Abort));
        assert!(matches!(parse_answer(b""), R::Abort));
    }

    extern "C" fn texting_callback(
        _ctx: *mut c_void,
        request_json: *const c_char,
        out_buf: *mut c_char,
        buf_len: usize,
    ) -> i32 {
        let request = unsafe { CStr::from_ptr(request_json) }.to_str().unwrap();
        let json: serde_json::Value = serde_json::from_str(request).unwrap();
        assert_eq!(json["method"], "device");
        let answer = b"{\"action\":\"sms\",\"id\":1}\0";
        assert!(answer.len() <= buf_len);
        unsafe { std::ptr::copy_nonoverlapping(answer.as_ptr(), out_buf as *mut u8, answer.len()) };
        1
    }

    extern "C" fn cancelling_callback(
        _ctx: *mut c_void,
        _request_json: *const c_char,
        _out_buf: *mut c_char,
        _buf_len: usize,
    ) -> i32 {
        0
    }

    #[test]
    fn round_trips_through_a_c_callback() {
        use TwoFactorCallbackResponse as R;
        let p = params(false, false, false, None);
        let ctx = TwoFaCtx(std::ptr::null_mut());
        assert!(matches!(ask_swift(Some(texting_callback), &ctx, &p), R::SendSms(1)));
        assert!(matches!(ask_swift(Some(cancelling_callback), &ctx, &p), R::Abort));
        assert!(matches!(ask_swift(None, &ctx, &p), R::Abort));
    }
}
