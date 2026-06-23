//! SideInstaller Rust core — C FFI shim over `idevice` (and later `isideload`).
//!
//! Module map (filled in gate-by-gate per the build order):
//!   * `logging`    — tracing -> FFI callback (STEP 1, done)
//!   * `ffi_util`   — shared C-string helpers
//!   * `pairing`    — RPPairing host à la StikPair          (STEP 2)
//!   * `connection` — loopback lockdown session + device info (STEP 2)
//!   * `install`    — AFC + installation_proxy               (STEP 4)
//!   * `account`    — isideload: login / cert / profile / sign (STEP 3)
//!
//! FFI contract: no panics cross the boundary, every fallible call returns an
//! error code + (optionally) a heap-allocated message the caller frees with
//! `si_string_free`.

// Force-link idevice's own C-FFI crate so its `#[no_mangle]` connection/install
// symbols (tunnel_create_rppairing, installation_proxy_*, afc_*, rsd_*,
// rp_pairing_file_*, lockdown_*, adapter_*) are re-exported from our staticlib
// and callable from Swift. Aliased to `_` — we never reference it from Rust,
// we only want its exported C symbols.
extern crate idevice_ffi as _;

mod account;
mod certs;
mod ffi_util;
mod logging;
mod pairing;

use std::ffi::{c_char, c_void};

use ffi_util::cstr;

// Re-export FFI types so the generated header / Swift see them.
pub use account::{SignSession, TwoFactorCb};
pub use certs::CertSession;
pub use pairing::{PairResult, PinCb, ReadyCb};

/// Initialise the logging spine. `cb` receives every formatted log line
/// (idevice's tracing output included). `ctx` is passed back untouched.
///
/// Returns 0 on success, 1 if logging was already initialised.
#[no_mangle]
pub extern "C" fn si_log_init(cb: logging::LogCallback, ctx: *mut c_void) -> i32 {
    logging::init(cb, ctx)
}

/// Liveness probe: logs through `tracing` (so it should appear in the console
/// via the callback) and returns a heap string the caller must free.
#[no_mangle]
pub extern "C" fn si_ping() -> *mut c_char {
    tracing::info!("si_ping: Rust core alive (idevice {} linked)", idevice_version());
    cstr(format!(
        "pong from sideinstaller_ffi — idevice {} linked, tokio runtime available",
        idevice_version()
    ))
}

/// Best-effort idevice version string for diagnostics.
fn idevice_version() -> &'static str {
    // idevice doesn't export its own version at runtime; pin is documented in
    // Cargo.toml. Keep a human-readable marker here.
    "@7bd551c"
}

/// Free a `*mut c_char` previously returned by this library.
///
/// # Safety
/// `p` must be null or a pointer returned by one of this library's functions.
#[no_mangle]
pub unsafe extern "C" fn si_string_free(p: *mut c_char) {
    ffi_util::string_free(p);
}

// ---------------------------------------------------------------------------
// STEP 2: pairing — RPPairing host (StikPair flow)
// ---------------------------------------------------------------------------

/// Run the RPPairing host. Blocks until a device pairs or an error occurs, so
/// the caller MUST run it off the main thread. `ready_cb` fires with the
/// Bonjour advertising details; `pin_cb` fires with the PIN to confirm on the
/// device. On success `out` is populated with the paired device's info and the
/// path to the written pairing file.
///
/// # Safety
/// See `pairing::run_host`. `out` must point to a writable `PairResult`.
#[no_mangle]
pub unsafe extern "C" fn si_pairing_run_host(
    bind_addr: *const c_char,
    port: u16,
    name: *const c_char,
    model: *const c_char,
    out_path: *const c_char,
    ready_cb: ReadyCb,
    pin_cb: PinCb,
    ctx: *mut c_void,
    out: *mut PairResult,
) -> i32 {
    pairing::run_host(
        bind_addr, port, name, model, out_path, ready_cb, pin_cb, ctx, out,
    )
}

/// Free the heap strings inside a `PairResult`.
///
/// # Safety
/// `r` must be null or a `PairResult` populated by `si_pairing_run_host`.
#[no_mangle]
pub unsafe extern "C" fn si_pairing_result_free(r: *mut PairResult) {
    pairing::result_free(r)
}


// ---------------------------------------------------------------------------
// STEP 3: account — Apple ID sign-in + on-device signing (isideload)
// ---------------------------------------------------------------------------

/// Log in to Apple ID, open a developer session, and build a signer. Blocks —
/// run off the main thread. `twofa_cb` is invoked when a 2FA code is needed.
///
/// # Safety
/// See `account::apple_signin`.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn si_apple_signin(
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
    account::apple_signin(
        apple_id, password, anisette_url, machine_name, storage_dir, twofa_cb, ctx,
        out_session, out_summary, out_error,
    )
}

/// Sign the IPA at `ipa_path` using a session from `si_apple_signin`. Blocks.
/// On success `*out_signed_path` is the signed `.app` bundle path.
///
/// `device_udid` (and cosmetic `device_name`) identify the device the build will
/// be installed onto; the device is registered with the developer portal before
/// signing so the provisioning profile covers it. Pass null/empty to skip.
///
/// # Safety
/// See `account::sign_ipa`.
#[no_mangle]
pub unsafe extern "C" fn si_sign_ipa(
    session: *mut SignSession,
    ipa_path: *const c_char,
    device_name: *const c_char,
    device_udid: *const c_char,
    out_signed_path: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    account::sign_ipa(
        session,
        ipa_path,
        device_name,
        device_udid,
        out_signed_path,
        out_error,
    )
}

/// Free a sign session.
///
/// # Safety
/// `session` must be null or a pointer from `si_apple_signin`.
#[no_mangle]
pub unsafe extern "C" fn si_sign_session_free(session: *mut SignSession) {
    account::sign_session_free(session)
}

// ---------------------------------------------------------------------------
// Certificate management — list + revoke iOS development certificates
// ---------------------------------------------------------------------------

/// Log in + open a developer session + select the first team for certificate
/// management. Blocks — run off the main thread. `twofa_cb` is invoked when a
/// 2FA code is needed. Independent of the install pipeline (no device needed).
///
/// # Safety
/// See `certs::cert_signin`.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn si_cert_signin(
    apple_id: *const c_char,
    password: *const c_char,
    anisette_url: *const c_char,
    machine_name: *const c_char,
    storage_dir: *const c_char,
    twofa_cb: TwoFactorCb,
    ctx: *mut c_void,
    out_session: *mut *mut CertSession,
    out_summary: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    certs::cert_signin(
        apple_id, password, anisette_url, machine_name, storage_dir, twofa_cb, ctx,
        out_session, out_summary, out_error,
    )
}

/// List the team's iOS development certificates as a JSON array. Blocks.
/// On success `*out_json` is a heap JSON string (free with `si_string_free`).
///
/// # Safety
/// See `certs::cert_list`.
#[no_mangle]
pub unsafe extern "C" fn si_cert_list(
    session: *mut CertSession,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    certs::cert_list(session, out_json, out_error)
}

/// Revoke the development certificate with `serial_number`. Blocks.
///
/// # Safety
/// See `certs::cert_revoke`.
#[no_mangle]
pub unsafe extern "C" fn si_cert_revoke(
    session: *mut CertSession,
    serial_number: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    certs::cert_revoke(session, serial_number, out_error)
}

/// Free a certificate session.
///
/// # Safety
/// `session` must be null or a pointer from `si_cert_signin`.
#[no_mangle]
pub unsafe extern "C" fn si_cert_session_free(session: *mut CertSession) {
    certs::cert_session_free(session)
}
