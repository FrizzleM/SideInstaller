//! RPPairing host: generates a pairing file in-process, as StikPair does.
//!
//! mDNS advertising is done in Swift, which avoids needing the iOS multicast
//! entitlement: before `accept()`, the service ID, port and TXT records are
//! passed to Swift through the `ready` callback. Needs Local Network permission
//! and Developer Mode, not the tunnel.
//!
//! idevice's pairing conversation waits on the device with no time limit, so
//! each stage after the device connects gets one (`Limits`), and a
//! `PairCancel` ends the run at any stage.

use std::any::Any;
use std::ffi::{c_char, c_void, CString};
use std::future::Future;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::time::Duration;

use idevice::remote_pairing::{
    PairableHost, PairableHostInfo, PeerDevice, RpPairingFile, RpPairingSocket,
};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{oneshot, watch};

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
    /// The address the device connected from: its IP on this network.
    pub device_address: *mut c_char,
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
            device_address: ptr::null_mut(),
        }
    }
}

/// Ends a `run_host` call from another thread, whatever stage it's at.
///
/// A `watch` channel, so a cancel sent before the run starts waiting still
/// counts, and sending one needs no runtime.
pub struct PairCancel(watch::Sender<bool>);

impl Default for PairCancel {
    fn default() -> Self {
        Self(watch::channel(false).0)
    }
}

impl PairCancel {
    pub fn cancel(&self) {
        self.0.send_replace(true);
    }

    /// Resolves once `cancel` is called, at once if it already was. It holds
    /// its own receiver, so the run needs the handle only to start.
    fn cancelled(&self) -> impl Future<Output = ()> + Send + 'static {
        let mut rx = self.0.subscribe();
        async move {
            // An error means the handle was freed without cancelling.
            let fired = rx.wait_for(|cancelled| *cancelled).await.map(|_| ());
            if fired.is_err() {
                std::future::pending::<()>().await;
            }
        }
    }
}

/// How long each stage may take once a device has connected. Waiting for one
/// to connect has no limit: the user may take a while to find the page in
/// Settings, and `PairCancel` ends that wait.
#[derive(Clone, Copy, Debug)]
struct Limits {
    /// From the device connecting until it asks for a code. Its handshake and
    /// first pair-setup message come at once: within 40 ms in #28's log.
    code_request: Duration,
    /// From the code being shown until pairing has finished. The user types it
    /// into Settings (10 s in #28's log); the rest takes milliseconds.
    code_entry: Duration,
}

const LIMITS: Limits = Limits {
    code_request: Duration::from_secs(30),
    code_entry: Duration::from_secs(5 * 60),
};

struct Callbacks {
    ready: ReadyCb,
    pin: PinCb,
    ctx: *mut c_void,
}
unsafe impl Send for Callbacks {}

/// What `run_host` was asked for, its C strings read.
struct HostOptions {
    bind_addr: String,
    port: u16,
    name: String,
    model: String,
    out_path: String,
    saved_alt_irk: Option<[u8; 16]>,
    identifier: String,
}

/// Why a run ended without a pairing file.
#[derive(Debug)]
enum Failure {
    Failed(String),
    /// `PairCancel::cancel` was called.
    Cancelled,
    /// The host panicked, with the panic's message.
    Panicked(String),
}

impl From<String> for Failure {
    fn from(message: String) -> Self {
        Failure::Failed(message)
    }
}

/// Bind a listener, hand the advertising details to Swift, wait for the device,
/// drive pairing through `pin_cb`, and write the pairing file to `out_path`.
///
/// Returns 0 once paired; 1 when pairing failed, a stage's time limit running
/// out included; 2 when `out` is null or the host panicked; 3 when `cancel` was
/// fired. For 1–3, `out.error` says why.
///
/// # Safety
/// All `*const c_char` args must be null or valid C strings; `cancel` must be
/// null or a live `PairCancel`; `out` must be a valid, writable `PairResult`.
#[allow(clippy::too_many_arguments)]
pub unsafe fn run_host(
    bind_addr: *const c_char,
    port: u16,
    name: *const c_char,
    model: *const c_char,
    out_path: *const c_char,
    host_alt_irk_hex: *const c_char,
    host_identifier: *const c_char,
    ready_cb: ReadyCb,
    pin_cb: PinCb,
    ctx: *mut c_void,
    cancel: *const PairCancel,
    out: *mut PairResult,
) -> i32 {
    if out.is_null() {
        return 2;
    }
    *out = PairResult::empty();

    let opts = HostOptions {
        bind_addr: opt_str(bind_addr, "0.0.0.0"),
        port,
        name: opt_str(name, "SideInstaller"),
        model: opt_str(model, "Mac17,7"),
        out_path: opt_str(out_path, "rp_pairing_file.plist"),
        saved_alt_irk: parse_alt_irk(&opt_str(host_alt_irk_hex, "")),
        identifier: opt_str(host_identifier, ""),
    };
    let cbs = Callbacks { ready: ready_cb, pin: pin_cb, ctx };
    let cancelled = cancel.as_ref().map(PairCancel::cancelled);

    match host_main(opts, cbs, cancelled, LIMITS) {
        Ok(res) => {
            (*out).device_name = cstr(res.name);
            (*out).device_model = cstr(res.model);
            (*out).device_udid = cstr(res.udid);
            (*out).pairing_file_path = cstr(res.path);
            (*out).host_alt_irk_hex = cstr(res.host_alt_irk_hex);
            (*out).device_address = cstr(res.address);
            0
        }
        Err(Failure::Failed(e)) => {
            (*out).error = cstr(e);
            1
        }
        Err(Failure::Panicked(e)) => {
            (*out).error = cstr(format!("pairing stopped on an internal error: {e}"));
            2
        }
        Err(Failure::Cancelled) => {
            (*out).error = cstr("pairing cancelled");
            3
        }
    }
}

struct Paired {
    name: String,
    model: String,
    udid: String,
    path: String,
    host_alt_irk_hex: String,
    address: String,
}

/// The run on its own runtime, blocking. A panic in it, idevice's code
/// included, comes back as `Failure::Panicked`: unwinding into Swift would
/// abort the app.
fn host_main(
    opts: HostOptions,
    cbs: Callbacks,
    cancelled: Option<impl Future<Output = ()>>,
    limits: Limits,
) -> Result<Paired, Failure> {
    catch_panics(|| {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|e| format!("failed to start runtime: {e}"))?;
        rt.block_on(run(opts, cbs, cancelled, limits))
    })
}

fn catch_panics<T>(f: impl FnOnce() -> Result<T, Failure>) -> Result<T, Failure> {
    catch_unwind(AssertUnwindSafe(f))
        .unwrap_or_else(|panic| Err(Failure::Panicked(panic_message(&*panic))))
}

/// The message a panic was raised with.
fn panic_message(panic: &(dyn Any + Send)) -> String {
    if let Some(s) = panic.downcast_ref::<&str>() {
        s.to_string()
    } else if let Some(s) = panic.downcast_ref::<String>() {
        s.clone()
    } else {
        "unknown panic".to_string()
    }
}

/// Pair, unless `cancelled` fires first, then write the pairing file. Dropping
/// `pair` closes the listener and the device's connection. A cancel that comes
/// while the file is being written is too late: the device has paired by then.
async fn run(
    opts: HostOptions,
    cbs: Callbacks,
    cancelled: Option<impl Future<Output = ()>>,
    limits: Limits,
) -> Result<Paired, Failure> {
    let cancelled = async {
        match cancelled {
            Some(cancelled) => cancelled.await,
            None => std::future::pending().await,
        }
    };
    let paired = tokio::select! {
        // A run cancelled before it started doesn't listen or advertise.
        biased;
        () = cancelled => return Err(Failure::Cancelled),
        paired = pair(&opts, cbs, limits) => paired?,
    };
    save(paired, &opts.out_path).await.map_err(Failure::Failed)
}

/// What a device that has just paired left to save.
struct Negotiated {
    peer: PeerDevice,
    peer_addr: SocketAddr,
    pairing_file: RpPairingFile,
    host_alt_irk: [u8; 16],
    /// The device's connection, closed once the file is written.
    _connection: PairableHost<RpPairingSocket<TcpStream>>,
}

/// Listen, advertise, wait for a device and pair with it within `limits`.
async fn pair(opts: &HostOptions, cbs: Callbacks, limits: Limits) -> Result<Negotiated, String> {
    let HostOptions { bind_addr, port, name, model, out_path, saved_alt_irk, identifier } = opts;

    tracing::info!("RPPairing: binding listener on {bind_addr}:{port}");
    let ip: IpAddr = bind_addr.parse().unwrap_or(IpAddr::V4(Ipv4Addr::UNSPECIFIED));
    let listener = TcpListener::bind(SocketAddr::new(ip, *port))
        .await
        .map_err(|e| format!("failed to bind {bind_addr}:{port}: {e}"))?;
    let port = listener
        .local_addr()
        .map_err(|e| format!("no local addr: {e}"))?
        .port();
    tracing::info!("RPPairing: listening on port {port}");

    // Reuse the host identity (key pair and altIRK) across pairings:
    //
    // - The Bonjour `authTag` is derived from `alt_irk`; a new one each run
    //   means an already-paired device won't recognize this host.
    // - Pairing files already written into other apps (SideStore, Feather,
    //   StikDebug) use this Ed25519 key pair. A new key would invalidate them.
    //
    // Re-pairing with the same key works like a Mac re-pairing: the device
    // replaces its record for this identifier, and existing files stay valid.
    let mut pairing_file = match RpPairingFile::read_from_file(out_path).await {
        Ok(mut existing) => {
            // Clear the previous device's altIRK so pairing with a different
            // iPhone doesn't inherit it.
            existing.alt_irk = None;
            tracing::info!(
                "RPPairing: reusing the host key pair from {out_path} — files already placed in other apps stay valid"
            );
            existing
        }
        Err(_) => {
            tracing::info!("RPPairing: no reusable host key pair at {out_path}; generating one");
            let mut file = RpPairingFile::generate(name);
            // `generate` derives the identifier from the name alone, the same on
            // every SideInstaller; a caller's own keeps their records apart.
            if !identifier.is_empty() {
                file.identifier = identifier.clone();
            }
            file
        }
    };
    let mut host_info = PairableHostInfo::generate(name, model);
    if let Some(alt_irk) = *saved_alt_irk {
        host_info.alt_irk = alt_irk;
        tracing::info!("RPPairing: reusing this host's stored altIRK, so the device knows us");
    }
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

    let (code_shown_tx, code_shown) = oneshot::channel();
    let conversation = host.accept(&mut pairing_file, move |pin| async move {
        tracing::info!("RPPairing: MILESTONE PIN issued — enter {pin} on the device to confirm");
        if let Some(cb) = cbs.pin {
            if let Ok(c) = CString::new(pin) {
                cb(c.as_ptr(), cbs.ctx);
            }
        }
        let _ = code_shown_tx.send(());
    });
    let peer = within_limits(conversation, code_shown, limits)
        .await?
        .map_err(|e| format!("pairing failed: {e}"))?;
    tracing::info!("RPPairing: MILESTONE handshake complete (PIN accepted): {}", peer.model);

    Ok(Negotiated { peer, peer_addr, pairing_file, host_alt_irk, _connection: host })
}

/// Drive idevice's pairing conversation, which waits on the device without a
/// limit: `code_request` until `code_shown` fires, then `code_entry` until it
/// ends.
async fn within_limits<T>(
    conversation: impl Future<Output = T>,
    code_shown: oneshot::Receiver<()>,
    limits: Limits,
) -> Result<T, String> {
    tokio::pin!(conversation);
    tokio::select! {
        biased;
        done = &mut conversation => return Ok(done),
        // An error would mean the PIN callback was dropped uncalled, which only
        // happens as the conversation ends, so it disables this branch instead.
        Ok(()) = code_shown => {}
        () = tokio::time::sleep(limits.code_request) => {
            return Err(format!(
                "pairing timed out: the iPhone connected but stopped responding before asking for a code ({})",
                spoken(limits.code_request)
            ));
        }
    }
    tokio::time::timeout(limits.code_entry, conversation)
        .await
        .map_err(|_| {
            format!(
                "pairing timed out: the code wasn't entered within {}, or the iPhone stopped responding",
                spoken(limits.code_entry)
            )
        })
}

/// "30 seconds", "5 minutes".
fn spoken(d: Duration) -> String {
    let secs = d.as_secs();
    let (n, unit) = if secs >= 60 && secs % 60 == 0 {
        (secs / 60, "minute")
    } else {
        (secs, "second")
    };
    format!("{n} {unit}{}", if n == 1 { "" } else { "s" })
}

/// Write the pairing file of a device that has just paired.
async fn save(n: Negotiated, out_path: &str) -> Result<Paired, String> {
    n.pairing_file
        .write_to_file(out_path)
        .await
        .map_err(|e| format!("failed to write pairing file: {e}"))?;

    // Connect needs this file, so fail loudly if it's missing or empty.
    let size = tokio::fs::metadata(out_path)
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
        name: n.peer.name,
        model: n.peer.model,
        udid: n.peer.remotepairing_udid,
        path: out_path.to_string(),
        host_alt_irk_hex: hex(&n.host_alt_irk),
        // The device dialled us over the network, so this is where to reach it.
        address: n.peer_addr.ip().to_canonical().to_string(),
    })
}

/// Parse the 32-character hex altIRK returned by a previous `run_host`. Invalid
/// input returns None, and a new altIRK is generated (the device just won't
/// recognize this host).
fn parse_alt_irk(hex: &str) -> Option<[u8; 16]> {
    if hex.len() != 32 {
        return None;
    }
    let mut out = [0u8; 16];
    for (i, byte) in out.iter_mut().enumerate() {
        *byte = u8::from_str_radix(hex.get(i * 2..i * 2 + 2)?, 16).ok()?;
    }
    Some(out)
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
        (*r).device_address,
    ] {
        if !p.is_null() {
            drop(CString::from_raw(p));
        }
    }
    *r = PairResult::empty();
}

#[cfg(test)]
mod tests {
    //! A host on loopback, as `run_host` runs it, against a fake iPhone.

    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpStream;
    use std::sync::atomic::{AtomicBool, AtomicU16, Ordering};
    use std::sync::Arc;
    use std::thread::{self, JoinHandle};
    use std::time::Instant;

    /// What the callbacks saw; their `ctx`.
    #[derive(Default)]
    struct Probe {
        port: AtomicU16,
        code_shown: AtomicBool,
    }

    extern "C" fn on_ready(
        ctx: *mut c_void,
        _service_id: *const c_char,
        port: u16,
        _txt_keys: *const *const c_char,
        _txt_vals: *const *const c_char,
        _txt_count: usize,
    ) {
        unsafe { &*(ctx as *const Probe) }.port.store(port, Ordering::SeqCst);
    }

    extern "C" fn on_pin(_pin: *const c_char, ctx: *mut c_void) {
        unsafe { &*(ctx as *const Probe) }.code_shown.store(true, Ordering::SeqCst);
    }

    struct Run {
        probe: Arc<Probe>,
        cancel: Arc<PairCancel>,
        thread: JoinHandle<Result<Paired, Failure>>,
    }

    /// Start a host on its own thread, as Swift does; `cancel` is fired first
    /// when `cancelled_early`.
    fn start(limits: Limits, cancelled_early: bool) -> Run {
        let probe = Arc::new(Probe::default());
        let cancel = Arc::new(PairCancel::default());
        if cancelled_early {
            cancel.cancel();
        }
        let opts = HostOptions {
            bind_addr: "127.0.0.1".into(),
            port: 0,
            name: "SideInstaller test".into(),
            model: "Mac17,7".into(),
            // Never written: no test gets as far as pairing.
            out_path: std::env::temp_dir()
                .join(format!("si-pairing-test-{}.plist", std::process::id()))
                .to_string_lossy()
                .into_owned(),
            saved_alt_irk: None,
            identifier: String::new(),
        };
        let cbs = Callbacks {
            ready: Some(on_ready),
            pin: Some(on_pin),
            ctx: Arc::as_ptr(&probe) as *mut c_void,
        };
        let (probe_kept, cancel_kept) = (probe.clone(), cancel.clone());
        let thread = thread::spawn(move || {
            let _probe = probe_kept; // outlives the run, which points at it
            host_main(opts, cbs, Some(cancel_kept.cancelled()), limits)
        });
        Run { probe, cancel, thread }
    }

    fn wait_until(what: &str, done: impl Fn() -> bool) {
        let deadline = Instant::now() + Duration::from_secs(30);
        while !done() {
            assert!(Instant::now() < deadline, "timed out waiting for {what}");
            thread::sleep(Duration::from_millis(10));
        }
    }

    fn connect(run: &Run) -> TcpStream {
        wait_until("the host to listen", || run.probe.port.load(Ordering::SeqCst) != 0);
        TcpStream::connect(("127.0.0.1", run.probe.port.load(Ordering::SeqCst))).unwrap()
    }

    /// The device's side of the rppairing framing ("host" in its terms).
    fn send(device: &mut TcpStream, seq: u64, plain: &str) {
        let json = format!(
            r#"{{"message":{{"plain":{{"_0":{plain}}}}},"originatedBy":"host","sequenceNumber":{seq}}}"#
        );
        let mut frame = b"RPPairing".to_vec();
        frame.extend_from_slice(&(json.len() as u16).to_be_bytes());
        frame.extend_from_slice(json.as_bytes());
        device.write_all(&frame).unwrap();
    }

    const HANDSHAKE: &str = r#"{"request":{"_0":{"handshake":{"_0":{"hostOptions":{"attemptPairVerify":false},"wireProtocolVersion":19}}}}}"#;
    /// Pair-setup M1: TLV8 State = 1, base64.
    const M1: &str = r#"{"event":{"_0":{"pairingData":{"_0":{"data":"BgEB","kind":"setupManualPairing","startNewSession":false}}}}}"#;

    /// Connect, ask for a code, and wait until the host shows it.
    fn reach_code(run: &Run) -> TcpStream {
        let mut device = connect(run);
        send(&mut device, 0, HANDSHAKE);
        send(&mut device, 1, M1);
        wait_until("the code", || run.probe.code_shown.load(Ordering::SeqCst));
        device
    }

    fn finish(run: Run, within: Duration) -> Failure {
        let started = Instant::now();
        let ended = run.thread.join().unwrap();
        assert!(started.elapsed() < within, "the run took {:?}", started.elapsed());
        match ended {
            Ok(_) => panic!("the run paired"),
            Err(failure) => failure,
        }
    }

    /// Reads what the host sent until it hangs up, failing if it doesn't.
    fn assert_hung_up(mut device: TcpStream) {
        device.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
        let mut sink = Vec::new();
        device.read_to_end(&mut sink).expect("reading until the host hangs up");
    }

    const LONG: Limits = Limits {
        code_request: Duration::from_secs(60),
        code_entry: Duration::from_secs(60),
    };

    #[test]
    fn cancel_ends_the_wait_for_a_device() {
        let run = start(LONG, false);
        wait_until("the host to listen", || run.probe.port.load(Ordering::SeqCst) != 0);
        run.cancel.cancel();
        assert!(matches!(finish(run, Duration::from_secs(2)), Failure::Cancelled));
    }

    #[test]
    fn cancel_before_the_run_starts_means_no_listening() {
        let run = start(LONG, true);
        let probe = run.probe.clone();
        assert!(matches!(finish(run, Duration::from_secs(2)), Failure::Cancelled));
        assert_eq!(probe.port.load(Ordering::SeqCst), 0, "the host advertised");
    }

    #[test]
    fn cancel_ends_a_connected_device_that_stopped_responding() {
        let run = start(LONG, false);
        let device = connect(&run);
        thread::sleep(Duration::from_millis(100));
        run.cancel.cancel();
        assert!(matches!(finish(run, Duration::from_secs(2)), Failure::Cancelled));
        assert_hung_up(device);
    }

    #[test]
    fn cancel_ends_the_wait_for_the_code() {
        let run = start(LONG, false);
        let device = reach_code(&run);
        run.cancel.cancel();
        assert!(matches!(finish(run, Duration::from_secs(2)), Failure::Cancelled));
        assert_hung_up(device);
    }

    #[test]
    fn a_device_that_never_asks_for_a_code_times_out() {
        let limits = Limits { code_request: Duration::from_millis(300), ..LONG };
        let run = start(limits, false);
        let device = connect(&run);
        match finish(run, Duration::from_secs(10)) {
            Failure::Failed(e) => assert!(e.contains("before asking for a code"), "{e}"),
            other => panic!("{other:?}"),
        }
        assert_hung_up(device);
    }

    #[test]
    fn a_code_never_entered_times_out() {
        // The code request covers the SRP setup, slow in a debug build.
        let limits = Limits { code_entry: Duration::from_millis(300), ..LONG };
        let run = start(limits, false);
        let device = reach_code(&run);
        match finish(run, Duration::from_secs(10)) {
            Failure::Failed(e) => assert!(e.contains("the code wasn't entered"), "{e}"),
            other => panic!("{other:?}"),
        }
        assert_hung_up(device);
    }

    #[test]
    fn a_handle_freed_uncancelled_never_cancels() {
        let cancel = PairCancel::default();
        let cancelled = cancel.cancelled();
        drop(cancel);
        let rt = tokio::runtime::Builder::new_current_thread().enable_all().build().unwrap();
        let waited =
            rt.block_on(async { tokio::time::timeout(Duration::from_millis(50), cancelled).await });
        assert!(waited.is_err());
    }

    #[test]
    fn a_panic_becomes_an_error() {
        let caught = catch_panics::<()>(|| panic!("boom {}", 7));
        assert!(matches!(caught, Err(Failure::Panicked(m)) if m == "boom 7"));
        let caught = catch_panics::<()>(|| panic!("static"));
        assert!(matches!(caught, Err(Failure::Panicked(m)) if m == "static"));
    }

    #[test]
    fn limits_read_as_words() {
        assert_eq!(spoken(LIMITS.code_request), "30 seconds");
        assert_eq!(spoken(LIMITS.code_entry), "5 minutes");
        assert_eq!(spoken(Duration::from_secs(60)), "1 minute");
    }
}
