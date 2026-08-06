//! SideInstaller's Rust core: a C FFI shim over `idevice` and `isideload`.
//!
//! No panic crosses the boundary, and every fallible call returns an error code
//! plus a message the caller frees with `si_string_free`.

// Force-link idevice's C-FFI crate so Swift can call its `#[no_mangle]`
// symbols. Aliased to `_`: only the exports are wanted, never the crate itself.
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

/// Liveness probe: logs through `tracing` and returns a string to free.
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
    // idevice exports no runtime version; the pin lives in Cargo.toml.
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
// Pairing — the RPPairing host
// ---------------------------------------------------------------------------

/// Run the RPPairing host, blocking until a device pairs, so run it off the
/// main thread. `ready_cb` carries the Bonjour details and `pin_cb` the PIN;
/// `out` receives the device info and the pairing file's path.
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
// Account — Apple ID sign-in and signing
// ---------------------------------------------------------------------------

/// Log in, open a developer session, and build a signer. Blocks; `twofa_cb`
/// is invoked when a 2FA code is needed.
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

/// Sign the IPA at `ipa_path`, returning the `.app` bundle's path. Blocks.
/// `udid` is registered with the team first; pass NULL to skip that.
///
/// # Safety
/// See `account::sign_ipa`.
#[no_mangle]
pub unsafe extern "C" fn si_sign_ipa(
    session: *mut SignSession,
    ipa_path: *const c_char,
    udid: *const c_char,
    device_name: *const c_char,
    out_signed_path: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    account::sign_ipa(session, ipa_path, udid, device_name, out_signed_path, out_error)
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
// Certificates — list and revoke
// ---------------------------------------------------------------------------

/// Open a developer session on the first team for certificate management.
/// Blocks, and needs no device.
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

/// List the team's certificates as JSON in `*out_json`. Blocks.
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
