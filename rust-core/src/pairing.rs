//! RPPairing host: generates a pairing file in-process, as StikPair does.
//!
//! mDNS advertising lives on the Swift side to avoid the iOS multicast
//! entitlement, so just before `accept()` the service identifier, port and TXT
//! records go out through a `ready` callback for Swift to publish over Bonjour.
//! Only Local Network and Developer Mode are needed here, not the tunnel.

use std::ffi::{c_char, c_void, CString};
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::ptr;

use idevice::remote_pairing::{
    PairableHost, PairableHostInfo, RpPairingFile, RpPairingSocket,
};
use tokio::net::TcpListener;

use crate::ffi_util::{cstr, opt_str};

pub type ReadyCb = Option<
    extern "C" fn(
        ctx: *mut c_void,
        service_id: *const c_char,
        port: u16,
        txt_keys: *const *const c_char,
        txt_vals: *const *const c_char,
        txt_count: usize,
    ),
>;

pub type PinCb = Option<extern "C" fn(pin: *const c_char, ctx: *mut c_void)>;

#[repr(C)]
pub struct PairResult {
    pub error: *mut c_char,
    pub device_name: *mut c_char,
    pub device_model: *mut c_char,
    pub device_udid: *mut c_char,
    pub pairing_file_path: *mut c_char,
    pub host_alt_irk_hex: *mut c_char,
}

impl PairResult {
    fn empty() -> Self {
        Self {
            error: ptr::null_mut(),
            device_name: ptr::null_mut(),
            device_model: ptr::null_mut(),
            device_udid: ptr::null_mut(),
            pairing_file_path: ptr::null_mut(),
            host_alt_irk_hex: ptr::null_mut(),
        }
    }
}

struct Callbacks {
    ready: ReadyCb,
    pin: PinCb,
    ctx: *mut c_void,
}
unsafe impl Send for Callbacks {}

/// Bind a listener, hand the advertising details to Swift, wait for the device,
/// drive pairing through `pin_cb`, and write the pairing file to `out_path`.
///
/// # Safety
/// All `*const c_char` args must be null or valid C strings; `out` must be a
/// valid, writable `PairResult`.
pub unsafe fn run_host(
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
    if out.is_null() {
        return 2;
    }
    *out = PairResult::empty();

    let bind_addr = opt_str(bind_addr, "0.0.0.0");
    let name = opt_str(name, "SideInstaller");
    let model = opt_str(model, "Mac17,7");
    let out_path = opt_str(out_path, "rp_pairing_file.plist");
    let cbs = Callbacks { ready: ready_cb, pin: pin_cb, ctx };

    let rt = match tokio::runtime::Builder::new_multi_thread().enable_all().build() {
        Ok(rt) => rt,
        Err(e) => {
            (*out).error = cstr(format!("failed to start runtime: {e}"));
            return 1;
        }
    };

    match rt.block_on(run(bind_addr, port, name, model, out_path, cbs)) {
        Ok(res) => {
            (*out).device_name = cstr(res.name);
            (*out).device_model = cstr(res.model);
            (*out).device_udid = cstr(res.udid);
            (*out).pairing_file_path = cstr(res.path);
            (*out).host_alt_irk_hex = cstr(res.host_alt_irk_hex);
            0
        }
        Err(e) => {
            (*out).error = cstr(e);
            1
        }
    }
}

struct Paired {
    name: String,
    model: String,
    udid: String,
    path: String,
    host_alt_irk_hex: String,
}

async fn run(
    bind_addr: String,
    port: u16,
    name: String,
    model: String,
    out_path: String,
    cbs: Callbacks,
) -> Result<Paired, String> {
    tracing::info!("RPPairing: binding listener on {bind_addr}:{port}");
    let ip: IpAddr = bind_addr.parse().unwrap_or(IpAddr::V4(Ipv4Addr::UNSPECIFIED));
    let listener = TcpListener::bind(SocketAddr::new(ip, port))
        .await
        .map_err(|e| format!("failed to bind {bind_addr}:{port}: {e}"))?;
    let port = listener
        .local_addr()
        .map_err(|e| format!("no local addr: {e}"))?
        .port();
    tracing::info!("RPPairing: listening on port {port}");

    // Host identity; persisting alt_irk would keep paired devices working.
    let mut pairing_file = RpPairingFile::generate(&name);
    let host_info = PairableHostInfo::generate(&name, &model);
    let host_alt_irk = host_info.alt_irk;
    let service_identifier = pairing_file.identifier.clone();

    tracing::info!("RPPairing: advertising service {service_identifier}");
    emit_ready(&cbs, &service_identifier, port, &host_info);

    tracing::info!("RPPairing: MILESTONE waiting for a device to connect on advertised port {port}…");
    let (stream, peer_addr) = listener
        .accept()
        .await
        .map_err(|e| format!("accept failed: {e}"))?;
    tracing::info!("RPPairing: MILESTONE device connected on advertised port (from {peer_addr})");

    let socket = RpPairingSocket::new_device(stream);
    let mut host = PairableHost::new(socket, host_info);

    let peer = host
        .accept(&mut pairing_file, move |pin| async move {
            tracing::info!("RPPairing: MILESTONE PIN issued — enter {pin} on the device to confirm");
            if let Some(cb) = cbs.pin {
                if let Ok(c) = CString::new(pin) {
                    cb(c.as_ptr(), cbs.ctx);
                }
            }
        })
        .await
        .map_err(|e| format!("pairing failed: {e}"))?;
    tracing::info!(
        "RPPairing: MILESTONE handshake complete (PIN accepted): {} ({})",
        peer.name,
        peer.model
    );

    pairing_file
        .write_to_file(&out_path)
        .await
        .map_err(|e| format!("failed to write pairing file: {e}"))?;

    // Connect needs this file, so fail loudly if it's missing or empty.
    let size = tokio::fs::metadata(&out_path)
        .await
        .map(|m| m.len())
        .unwrap_or(0);
    if size == 0 {
        return Err(format!(
            "RPPairing handshake completed but pairing file at {out_path} is missing or zero bytes"
        ));
    }
    tracing::info!("RPPairing: MILESTONE pairing file written: {out_path} ({size} bytes)");

    Ok(Paired {
        name: peer.name,
        model: peer.model,
        udid: peer.remotepairing_udid,
        path: out_path,
        host_alt_irk_hex: hex(&host_alt_irk),
    })
}

fn hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

fn emit_ready(cbs: &Callbacks, service_id: &str, port: u16, host_info: &PairableHostInfo) {
    let Some(cb) = cbs.ready else { return };

    let records = host_info.mdns_txt_records(service_id);
    let mut keys: Vec<CString> = Vec::with_capacity(records.len());
    let mut vals: Vec<CString> = Vec::with_capacity(records.len());
    for (k, v) in &records {
        keys.push(CString::new(k.as_str()).unwrap_or_default());
        vals.push(CString::new(v.as_str()).unwrap_or_default());
    }
    let key_ptrs: Vec<*const c_char> = keys.iter().map(|s| s.as_ptr()).collect();
    let val_ptrs: Vec<*const c_char> = vals.iter().map(|s| s.as_ptr()).collect();

    let Ok(id_c) = CString::new(service_id) else { return };
    cb(
        cbs.ctx,
        id_c.as_ptr(),
        port,
        key_ptrs.as_ptr(),
        val_ptrs.as_ptr(),
        records.len(),
    );
}

/// Free the heap strings inside a `PairResult`.
///
/// # Safety
/// `r` must be null or a `PairResult` previously populated by `run_host`.
pub unsafe fn result_free(r: *mut PairResult) {
    if r.is_null() {
        return;
    }
    for p in [
        (*r).error,
        (*r).device_name,
        (*r).device_model,
        (*r).device_udid,
        (*r).pairing_file_path,
        (*r).host_alt_irk_hex,
    ] {
        if !p.is_null() {
            drop(CString::from_raw(p));
        }
    }
    *r = PairResult::empty();
}
