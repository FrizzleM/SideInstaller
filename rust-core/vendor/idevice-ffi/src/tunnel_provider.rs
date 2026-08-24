//! FFI functions for creating tunnels to iOS/tvOS/visionOS devices.
//!
//! These produce an `AdapterHandle` + `RsdHandshakeHandle` — the same types
//! used by every `_connect_rsd` function (e.g. `debug_proxy_connect_rsd`).
//!
//! Three paths:
//! - **USB via CoreDeviceProxy**: `tunnel_create_usb` / `tunnel_pair_usb`
//! - **Network via RemoteXPC** (NCM/USB Ethernet): `tunnel_create_remotexpc`
//! - **Network via raw RPPairing** (Wi-Fi/LAN): `tunnel_create_rppairing`

use std::ffi::{CStr, c_char, c_void};
use std::io::ErrorKind;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::ptr::null_mut;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use idevice::RemoteXpcClient;
use idevice::remote_pairing::{
    CdTunnel, RemotePairingClient, RpPairingSocket, RpPairingSocketProvider,
};
use idevice::{
    IdeviceError, IdeviceService, ReadWrite, core_device_proxy::CoreDeviceProxy,
    provider::IdeviceProvider, rsd::RsdHandshake, tcp::handle::AdapterHandle as TcpAdapterHandle,
};
use tokio::net::TcpStream;
use tracing::{info, warn};

use crate::core_device_proxy::AdapterHandle;
use crate::rp_pairing_file::RpPairingFileHandle;
use crate::rsd::RsdHandshakeHandle;
use crate::util::{SockAddr, idevice_sockaddr, idevice_socklen_t};
use crate::{IdeviceFfiError, ffi_err, provider::IdeviceProviderHandle, run_sync_local};

struct PinCtx(*mut c_void);
unsafe impl Send for PinCtx {}
unsafe impl Sync for PinCtx {}

// ---------------------------------------------------------------------------
// Tunnel dial — candidate hosts, instrumentation, failure classification
// ---------------------------------------------------------------------------

/// Why a tunnel attempt ultimately failed, so the caller can say something more
/// useful than whichever OS error happened to come last. Written through the
/// `out_failure_kind` argument of [`tunnel_create_rppairing_multihost`].
///
/// The raw error still comes back in the `IdeviceFfiError` message, and every
/// step is logged as it happens; this only says *which* wall was hit.
#[repr(C)]
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TunnelFailureKind {
    /// No failure — the tunnel came up.
    TunnelFailureNone = 0,
    /// The device's RSD port never answered, so nothing below it was attempted.
    TunnelFailureRsdUnreachable = 1,
    /// RSD answered but pair-verify was refused: this pairing file no longer
    /// matches the device.
    TunnelFailurePairVerify = 2,
    /// The port `createListener` opened was unreachable — refused outright, or
    /// dropped with no answer — on the very host RSD had just answered on,
    /// while RSD itself kept working. The device is there; the route in front
    /// of it forwards some ports and not others. Also covers the case where
    /// every candidate refused.
    TunnelFailureHostsRefused = 3,
    /// Candidates swallowed the connection: no refusal, no answer.
    TunnelFailureTimeout = 4,
    /// A candidate accepted the TCP connection but the TLS-PSK or CDTunnel
    /// handshake on top of it failed.
    TunnelFailureTlsHandshake = 5,
    /// Anything else — the RSD handshake inside the tunnel, a parse failure, …
    TunnelFailureOther = 6,
}

/// Where a candidate host came from, named in the dial log so a failing run
/// says which addresses were tried and why each one was on the list.
#[derive(Clone, Copy)]
enum HostSource {
    SessionCache,
    RsdPeer,
    LoopbackDefault,
    PairingInterface,
}

impl HostSource {
    fn label(self) -> &'static str {
        match self {
            HostSource::SessionCache => "cached from this session's first tunnel",
            HostSource::RsdPeer => "RSD peer address",
            HostSource::LoopbackDefault => "hardcoded default",
            HostSource::PairingInterface => "pairing session's local interface",
        }
    }
}

/// Total wall clock the whole candidate sweep may spend, across every round.
const DIAL_BUDGET: Duration = Duration::from_secs(18);

/// Cap on a single `connect()`.
///
/// Every candidate is a local address — loopback, the VPN's peer, this device's
/// own LAN address — so a listener that is up answers in single-digit
/// milliseconds. This is not a latency allowance, it is only there so a host
/// that black-holes the SYN can't stall the candidates behind it.
const DIAL_ATTEMPT_TIMEOUT: Duration = Duration::from_millis(800);

/// Pause between rounds. The device's listener is occasionally not accepting
/// yet when `createListener` returns, which is the only thing dialling the same
/// host again can fix.
const DIAL_ROUND_DELAY: Duration = Duration::from_millis(700);

/// Rounds over the whole candidate list, so each candidate gets this many
/// attempts in total.
const DIAL_MAX_ROUNDS: u32 = 6;

/// Cap on TLS-PSK/CDTunnel handshakes attempted in one sweep. Each one burns
/// the listener `createListener` opened and needs a replacement, so this bounds
/// how many replacements a device that keeps rejecting us is asked for.
const DIAL_MAX_HANDSHAKES: u32 = 3;

/// The host that worked, remembered so later tunnels in the same session dial
/// it first instead of re-walking the list. Process-wide: the process is the
/// session, and a wrong guess here only costs one refused connect.
static CACHED_TUNNEL_HOST: Mutex<Option<IpAddr>> = Mutex::new(None);

/// A failed tunnel attempt: the raw error for the log, and what kind of failure
/// it was for what the user is told.
struct TunnelFailure {
    kind: TunnelFailureKind,
    error: IdeviceError,
}

impl TunnelFailure {
    fn new(kind: TunnelFailureKind, error: IdeviceError) -> Self {
        Self { kind, error }
    }

    fn other(error: IdeviceError) -> Self {
        Self::new(TunnelFailureKind::TunnelFailureOther, error)
    }
}

/// `createListener` hands back a port and no host, so the host has to be
/// guessed. These are the guesses, best first, without duplicates.
fn tunnel_host_candidates(rsd_host: IpAddr, extra: &[IpAddr]) -> Vec<(IpAddr, HostSource)> {
    let mut out: Vec<(IpAddr, HostSource)> = Vec::new();
    fn push(out: &mut Vec<(IpAddr, HostSource)>, ip: IpAddr, source: HostSource) {
        if !out.iter().any(|(seen, _)| *seen == ip) {
            out.push((ip, source));
        }
    }

    // A host that already worked goes first, but the rest stay behind it: a VPN
    // reconnect can renumber the tunnel under a cached address.
    if let Ok(cached) = CACHED_TUNNEL_HOST.lock()
        && let Some(ip) = *cached
    {
        push(&mut out, ip, HostSource::SessionCache);
    }
    push(&mut out, rsd_host, HostSource::RsdPeer);
    push(
        &mut out,
        IpAddr::V4(Ipv4Addr::LOCALHOST),
        HostSource::LoopbackDefault,
    );
    for ip in extra {
        push(&mut out, *ip, HostSource::PairingInterface);
    }
    out
}

/// How one dial of one candidate ended.
enum DialOutcome {
    Connected(TcpStream),
    /// Actively refused — nothing is bound to that address:port right now.
    Refused(std::io::Error),
    /// No answer and no refusal before the attempt's cap ran out.
    TimedOut,
    /// Some other socket error (no route, permission denied, …).
    Failed(std::io::Error),
}

/// The last thing a candidate did, kept per candidate so the failure summary
/// reports where the sweep ended up rather than one line per round.
#[derive(Clone)]
enum CandidateState {
    Refused,
    TimedOut,
    Failed(String),
    /// Reached the listener, but the TLS-PSK/CDTunnel handshake on top of it
    /// was rejected.
    HandshakeFailed,
}

impl CandidateState {
    fn describe(&self) -> &str {
        match self {
            CandidateState::Refused => "refused",
            CandidateState::TimedOut => "timed out",
            CandidateState::Failed(text) => text,
            CandidateState::HandshakeFailed => "accepted but failed the TLS handshake",
        }
    }
}

/// Dial one candidate once, logging the attempt before it is made and its
/// failure at the point it happens.
async fn dial_once(
    addr: SocketAddr,
    source: HostSource,
    index: usize,
    total: usize,
    round: u32,
    left: Duration,
) -> DialOutcome {
    info!(
        "tunnel dial: connecting to {addr} — host from {}, candidate {}/{total}, \
         round {round}/{DIAL_MAX_ROUNDS} ({:.1}s left in the dial budget)",
        source.label(),
        index + 1,
        left.as_secs_f64()
    );

    let cap = left.min(DIAL_ATTEMPT_TIMEOUT);
    match tokio::time::timeout(cap, TcpStream::connect(addr)).await {
        Ok(Ok(stream)) => {
            info!("tunnel dial: {addr} accepted the connection in round {round}");
            DialOutcome::Connected(stream)
        }
        Ok(Err(e)) => {
            // Logged here, not once the sweep drains, so the console shows
            // which address produced which errno as it happens.
            warn!(
                "tunnel dial: {addr} failed in round {round}: {e} (kind {:?}, os error {:?})",
                e.kind(),
                e.raw_os_error()
            );
            if e.kind() == ErrorKind::ConnectionRefused {
                DialOutcome::Refused(e)
            } else {
                DialOutcome::Failed(e)
            }
        }
        Err(_) => {
            warn!(
                "tunnel dial: {addr} did not answer within {:.1}s in round {round} — \
                 no refusal either, so the connection is being dropped rather than rejected",
                cap.as_secs_f64()
            );
            DialOutcome::TimedOut
        }
    }
}

/// Turn a live CDTunnel into the adapter + RSD handshake every `_connect_rsd`
/// function expects.
async fn adapter_over_tunnel<S: ReadWrite + 'static>(
    tunnel: CdTunnel<S>,
) -> Result<(TcpAdapterHandle, RsdHandshake), TunnelFailure> {
    let client_ip: IpAddr = tunnel
        .info
        .client_address
        .parse()
        .map_err(|e| TunnelFailure::other(IdeviceError::InternalError(format!("{e}"))))?;
    let server_ip: IpAddr = tunnel
        .info
        .server_address
        .parse()
        .map_err(|e| TunnelFailure::other(IdeviceError::InternalError(format!("{e}"))))?;
    let mtu = tunnel.info.mtu as usize;
    let rsd_port = tunnel.info.server_rsd_port;

    let raw = tunnel.into_inner();
    let mut adapter = idevice::tcp::adapter::Adapter::new(Box::new(raw), client_ip, server_ip);
    adapter.set_mss(mtu.saturating_sub(60));
    let mut adapter = adapter.to_async_handle();

    info!("tunnel dial: tunnel up (client {client_ip}, server {server_ip}, mtu {mtu}); connecting to RSD on port {rsd_port} inside it");
    let rsd_stream = adapter
        .connect(rsd_port)
        .await
        .map_err(|e| TunnelFailure::other(IdeviceError::InternalError(format!("{e}"))))?;
    let handshake = RsdHandshake::new(rsd_stream)
        .await
        .map_err(TunnelFailure::other)?;

    Ok((adapter, handshake))
}

/// Shared logic: given a connected & paired `RemotePairingClient`, create the
/// TLS-PSK tunnel and return adapter + handshake.
///
/// `createListener` returns the port the device opened but not the host to
/// reach it on, so the host is guessed — the address RSD was reached at first,
/// then loopback, then whatever local interface the caller supplied. A
/// loopback VPN that forwards the RSD port but not the ephemeral one the device
/// just picked refuses all of them, which is what the failure kind is for.
///
/// The list is swept **breadth-first**: one attempt at every candidate, then
/// round again, rather than spending one candidate's whole retry allowance
/// before looking at the next. Depth-first put ten seconds of dead candidates —
/// a black-holed SYN waited out twice, then a refusal re-tried five more times —
/// in front of the address that does answer, and the listener the device opens
/// does not survive that: it accepted the connection and then rejected the
/// tunnel handshake on top of it. Breadth-first reaches a live listener inside
/// the first round, while still giving a listener that isn't accepting yet the
/// same number of attempts it had before.
async fn finish_tunnel(
    rpc: &mut RemotePairingClient<impl RpPairingSocketProvider>,
    connect_addr: SocketAddr,
    extra_hosts: &[IpAddr],
) -> Result<(TcpAdapterHandle, RsdHandshake), TunnelFailure> {
    use idevice::remote_pairing::connect_tls_psk_tunnel_native;

    let mut tunnel_port = rpc
        .create_tcp_listener()
        .await
        .map_err(TunnelFailure::other)?;
    let candidates = tunnel_host_candidates(connect_addr.ip(), extra_hosts);
    info!(
        "tunnel dial: createListener opened port {tunnel_port} and named no host; \
         trying {} candidate(s) over up to {DIAL_MAX_ROUNDS} round(s) within {:.0}s: {}",
        candidates.len(),
        DIAL_BUDGET.as_secs_f64(),
        candidates
            .iter()
            .map(|(ip, source)| format!("{ip} ({})", source.label()))
            .collect::<Vec<_>>()
            .join(", ")
    );

    let started = Instant::now();
    let deadline = started + DIAL_BUDGET;
    let mut handshakes = 0u32;
    let mut states: Vec<Option<CandidateState>> = vec![None; candidates.len()];
    let mut last: Option<IdeviceError> = None;
    // Whether the host RSD answered on was dialled at all, and whether the
    // tunnel port was ever reached on it.
    let mut rsd_peer_tried = false;
    let mut rsd_peer_connected = false;

    'sweep: for round in 1..=DIAL_MAX_ROUNDS {
        // Index-based, because a rejected handshake steps back onto the same
        // candidate rather than advancing.
        let mut index = 0usize;
        while index < candidates.len() {
            let (host, source) = &candidates[index];
            let left = deadline.saturating_duration_since(Instant::now());
            if left.is_zero() {
                warn!(
                    "tunnel dial: {:.0}s budget spent in round {round}; stopping",
                    DIAL_BUDGET.as_secs_f64()
                );
                break 'sweep;
            }
            let addr = SocketAddr::new(*host, tunnel_port);
            if matches!(source, HostSource::RsdPeer) {
                rsd_peer_tried = true;
            }

            let stream = match dial_once(addr, *source, index, candidates.len(), round, left).await
            {
                DialOutcome::Connected(stream) => stream,
                DialOutcome::Refused(e) => {
                    states[index] = Some(CandidateState::Refused);
                    last = Some(IdeviceError::InternalError(format!("TLS tunnel: {addr}: {e}")));
                    index += 1;
                    continue;
                }
                DialOutcome::TimedOut => {
                    states[index] = Some(CandidateState::TimedOut);
                    last = Some(IdeviceError::InternalError(format!(
                        "TLS tunnel: {addr}: no answer and no refusal"
                    )));
                    index += 1;
                    continue;
                }
                DialOutcome::Failed(e) => {
                    states[index] =
                        Some(CandidateState::Failed(format!("failed ({})", e.kind_str())));
                    last = Some(IdeviceError::InternalError(format!("TLS tunnel: {addr}: {e}")));
                    index += 1;
                    continue;
                }
            };

            // RSD answered here and so did the tunnel port, so whatever goes
            // wrong next is not the route in front of the device.
            if matches!(source, HostSource::RsdPeer) {
                rsd_peer_connected = true;
            }
            // Worth remembering even if the handshake then fails: it is the
            // only host the next run has any evidence for, and the cache only
            // decides what order the candidates are tried in.
            if let Ok(mut cached) = CACHED_TUNNEL_HOST.lock() {
                *cached = Some(*host);
            }

            handshakes += 1;
            match connect_tls_psk_tunnel_native(stream, rpc.encryption_key()).await {
                Ok(tunnel) => {
                    info!(
                        "tunnel dial: TLS-PSK + CDTunnel handshake succeeded over {addr} — \
                         host {host} ({}) is the one that works",
                        source.label()
                    );
                    return adapter_over_tunnel(tunnel).await;
                }
                Err(e) => {
                    states[index] = Some(CandidateState::HandshakeFailed);
                    warn!(
                        "tunnel dial: {addr} accepted the connection but the TLS-PSK/CDTunnel \
                         handshake failed: {e:?}"
                    );
                    last = Some(e);
                    if handshakes >= DIAL_MAX_HANDSHAKES {
                        warn!(
                            "tunnel dial: {handshakes} handshake(s) rejected — not asking the \
                             device for another listener"
                        );
                        break 'sweep;
                    }
                    // That connection consumed the listener, so anything
                    // further needs the device to open a fresh one — and a
                    // fresh one is also the remedy if the last one had gone
                    // stale. So this host is dialled again immediately, on the
                    // new port, instead of being written off: it is the only
                    // candidate known to reach a listener at all, and the
                    // replacement is at its youngest right now.
                    match rpc.create_tcp_listener().await {
                        Ok(port) => {
                            tunnel_port = port;
                            info!(
                                "tunnel dial: asked the device for a replacement listener — \
                                 now on port {port}; dialling {host} again straight away"
                            );
                        }
                        Err(e) => return Err(TunnelFailure::other(e)),
                    }
                    // Deliberately not advancing: same host, new listener.
                    continue;
                }
            }
        }

        let left = deadline.saturating_duration_since(Instant::now());
        if left.is_zero() || round == DIAL_MAX_ROUNDS {
            break;
        }
        tokio::time::sleep(DIAL_ROUND_DELAY.min(left)).await;
    }

    let tried = states.iter().filter(|s| s.is_some()).count();
    let refused = states
        .iter()
        .filter(|s| matches!(s, Some(CandidateState::Refused)))
        .count();
    let timed_out = states
        .iter()
        .filter(|s| matches!(s, Some(CandidateState::TimedOut)))
        .count();
    let tls_failures = states
        .iter()
        .filter(|s| matches!(s, Some(CandidateState::HandshakeFailed)))
        .count();
    let summary = candidates
        .iter()
        .zip(states.iter())
        .filter_map(|((host, _), state)| state.as_ref().map(|s| format!("{host} {}", s.describe())))
        .collect::<Vec<_>>()
        .join(", ");

    // Order matters, and not the obvious way. Reaching a listener looks like
    // the most specific signal, but a *fallback* host reaching one did so over
    // a different interface than the user's route, so it says nothing about why
    // that route failed. When the tunnel port was unreachable on the same host
    // RSD answered on, that is the diagnosis, and it outranks anything a
    // fallback went on to do — otherwise the user is told to re-pair when their
    // VPN is filtering, and the PIN dance cannot possibly help.
    let kind = if rsd_peer_tried && !rsd_peer_connected {
        TunnelFailureKind::TunnelFailureHostsRefused
    } else if tls_failures > 0 {
        TunnelFailureKind::TunnelFailureTlsHandshake
    } else if tried > 0 && refused == tried {
        TunnelFailureKind::TunnelFailureHostsRefused
    } else if timed_out > 0 {
        TunnelFailureKind::TunnelFailureTimeout
    } else {
        TunnelFailureKind::TunnelFailureOther
    };
    warn!(
        "tunnel dial: no candidate host completed a tunnel on port {tunnel_port} after {:.1}s — \
         {tried} tried, {refused} refused, {timed_out} timed out, \
         {tls_failures} failed the TLS handshake [{summary}]",
        started.elapsed().as_secs_f64()
    );

    let last = last.unwrap_or_else(|| {
        IdeviceError::InternalError(format!(
            "TLS tunnel: no candidate host was reached on port {tunnel_port}"
        ))
    });
    Err(TunnelFailure::new(
        kind,
        IdeviceError::InternalError(format!(
            "TLS tunnel: none of {tried} candidate host(s) answered on port {tunnel_port} \
             [{summary}]; last error: {last:?}"
        )),
    ))
}

/// `io::ErrorKind` as a short word for the outcome summary.
trait ErrorKindStr {
    fn kind_str(&self) -> String;
}

impl ErrorKindStr for std::io::Error {
    fn kind_str(&self) -> String {
        match self.raw_os_error() {
            Some(errno) => format!("{:?}, os error {errno}", self.kind()),
            None => format!("{:?}", self.kind()),
        }
    }
}

/// Read a `char **` list of dotted-quad / IPv6 literals into addresses,
/// skipping (and naming) anything unparseable rather than failing the dial.
///
/// # Safety
/// `hosts` must be null or point to `count` valid C strings.
unsafe fn read_extra_hosts(hosts: *const *const c_char, count: usize) -> Vec<IpAddr> {
    if hosts.is_null() || count == 0 {
        return Vec::new();
    }
    let mut out = Vec::with_capacity(count);
    for i in 0..count {
        let entry = unsafe { *hosts.add(i) };
        if entry.is_null() {
            continue;
        }
        let Ok(text) = (unsafe { CStr::from_ptr(entry) }).to_str() else {
            continue;
        };
        match text.parse::<IpAddr>() {
            Ok(ip) => out.push(ip),
            Err(_) => warn!("tunnel dial: ignoring unparseable candidate host {text:?}"),
        }
    }
    out
}

fn write_result(
    adapter: idevice::tcp::handle::AdapterHandle,
    handshake: RsdHandshake,
    out_adapter: *mut *mut AdapterHandle,
    out_handshake: *mut *mut RsdHandshakeHandle,
) {
    unsafe {
        *out_adapter = Box::into_raw(Box::new(AdapterHandle(adapter)));
        *out_handshake = Box::into_raw(Box::new(RsdHandshakeHandle(handshake)));
    }
}

/// Creates a tunnel over USB via CoreDeviceProxy.
/// No need to stop remoted.
///
/// # Safety
/// All pointer arguments must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_create_usb(
    lockdown_provider: *mut IdeviceProviderHandle,
    out_adapter: *mut *mut AdapterHandle,
    out_handshake: *mut *mut RsdHandshakeHandle,
) -> *mut IdeviceFfiError {
    if lockdown_provider.is_null() || out_adapter.is_null() || out_handshake.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let res = run_sync_local(async {
        let provider_ref: &dyn IdeviceProvider = unsafe { &*(*lockdown_provider).0 };
        let proxy = CoreDeviceProxy::connect(provider_ref).await?;
        let rsd_port = proxy.tunnel_info().server_rsd_port;
        let adapter = proxy
            .create_software_tunnel()
            .map_err(|e| IdeviceError::InternalError(format!("{e}")))?;
        let mut adapter = adapter.to_async_handle();
        let rsd_stream = adapter
            .connect(rsd_port)
            .await
            .map_err(|e| IdeviceError::InternalError(format!("{e}")))?;
        let handshake = RsdHandshake::new(rsd_stream).await?;
        Ok::<_, IdeviceError>((adapter, handshake))
    });

    match res {
        Ok((adapter, handshake)) => {
            write_result(adapter, handshake, out_adapter, out_handshake);
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Pairs via USB CoreDeviceProxy tunnel (no SIGSTOP needed).
///
/// For iOS, `pin_callback` can be NULL (defaults to "000000").
/// For Apple TV / Vision Pro, provide a callback returning the on-screen PIN.
///
/// # Safety
/// All pointer arguments must be valid and non-null (except `pin_callback`/`pin_context`).
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_pair_usb(
    lockdown_provider: *mut IdeviceProviderHandle,
    hostname: *const c_char,
    pin_callback: Option<extern "C" fn(context: *mut c_void) -> *const c_char>,
    pin_context: *mut c_void,
    out_pairing_file: *mut *mut RpPairingFileHandle,
) -> *mut IdeviceFfiError {
    if lockdown_provider.is_null() || hostname.is_null() || out_pairing_file.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let host = match unsafe { CStr::from_ptr(hostname) }.to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return ffi_err!(IdeviceError::FfiInvalidString),
    };
    let ctx = PinCtx(pin_context);

    let res = run_sync_local(async {
        use idevice::RemoteXpcClient;
        use idevice::remote_pairing::{RemotePairingClient, RpPairingFile};

        let provider_ref: &dyn IdeviceProvider = unsafe { &*(*lockdown_provider).0 };

        let proxy = CoreDeviceProxy::connect(provider_ref).await?;
        let rsd_port = proxy.tunnel_info().server_rsd_port;
        let adapter = proxy
            .create_software_tunnel()
            .map_err(|e| IdeviceError::InternalError(format!("{e}")))?;
        let mut adapter = adapter.to_async_handle();

        let rsd_stream = adapter
            .connect(rsd_port)
            .await
            .map_err(|e| IdeviceError::InternalError(format!("{e}")))?;
        let handshake = RsdHandshake::new(rsd_stream).await?;

        let ts = handshake
            .services
            .get("com.apple.internal.dt.coredevice.untrusted.tunnelservice")
            .ok_or(IdeviceError::ServiceNotFound)?;

        let ts_stream = adapter
            .connect(ts.port)
            .await
            .map_err(|e| IdeviceError::InternalError(format!("{e}")))?;
        let mut conn = RemoteXpcClient::new(ts_stream).await?;
        conn.do_handshake().await?;
        let _ = conn.recv_root().await?;

        let mut rpf = RpPairingFile::generate(&host);
        let mut rpc = RemotePairingClient::new(conn, &host);
        rpc.connect(&mut rpf, async || get_pin(pin_callback, &ctx))
            .await?;

        Ok::<_, IdeviceError>(rpf)
    });

    match res {
        Ok(rpf) => {
            unsafe { *out_pairing_file = Box::into_raw(Box::new(RpPairingFileHandle(rpf))) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Creates a tunnel over the network via RemoteXPC.
///
/// Use this when connecting to a device discovered via `_remoted._tcp` (RSD port).
/// The connection goes: RSD → find tunnel service → RemoteXPC → RPPairing → tunnel.
///
/// # Safety
/// All pointer arguments must be valid and non-null (except `pin_callback`/`pin_context`).
/// `pairing_file` is borrowed, not consumed.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_create_remotexpc(
    addr: *const idevice_sockaddr,
    addr_len: idevice_socklen_t,
    hostname: *const c_char,
    pairing_file: *mut RpPairingFileHandle,
    pin_callback: Option<extern "C" fn(context: *mut c_void) -> *const c_char>,
    pin_context: *mut c_void,
    out_adapter: *mut *mut AdapterHandle,
    out_handshake: *mut *mut RsdHandshakeHandle,
) -> *mut IdeviceFfiError {
    if addr.is_null()
        || hostname.is_null()
        || pairing_file.is_null()
        || out_adapter.is_null()
        || out_handshake.is_null()
    {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let socket_addr = match crate::util::c_socket_to_rust(addr as *const SockAddr, addr_len) {
        Ok(a) => a,
        Err(e) => return ffi_err!(e),
    };
    let host = match unsafe { CStr::from_ptr(hostname) }.to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return ffi_err!(IdeviceError::FfiInvalidString),
    };
    let rpf = unsafe { &mut (*pairing_file).0 };
    let ctx = PinCtx(pin_context);

    let res = run_sync_local(async {
        // RSD handshake to discover tunnel service
        let rsd_stream = tokio::net::TcpStream::connect(socket_addr)
            .await
            .map_err(|e| IdeviceError::InternalError(format!("RSD connect: {e}")))?;
        let rsd_handshake = RsdHandshake::new(rsd_stream).await?;

        let ts = rsd_handshake
            .services
            .get("com.apple.internal.dt.coredevice.untrusted.tunnelservice")
            .ok_or(IdeviceError::ServiceNotFound)?;

        // Connect to tunnel service via RemoteXPC
        let ts_addr = std::net::SocketAddr::new(socket_addr.ip(), ts.port);
        let ts_stream = tokio::net::TcpStream::connect(ts_addr)
            .await
            .map_err(|e| IdeviceError::InternalError(format!("tunnel service: {e}")))?;
        let mut conn = RemoteXpcClient::new(ts_stream).await?;
        conn.do_handshake().await?;
        let _ = conn.recv_root().await?;

        // RPPairing over RemoteXPC
        let mut rpc = RemotePairingClient::new(conn, &host);
        rpc.connect(rpf, async || get_pin(pin_callback, &ctx))
            .await?;

        finish_tunnel(&mut rpc, socket_addr, &[])
            .await
            .map_err(|f| f.error)
    });

    match res {
        Ok((adapter, handshake)) => {
            write_result(adapter, handshake, out_adapter, out_handshake);
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Creates a tunnel over the network via raw RPPairing protocol.
///
/// Use this when connecting to a device discovered via `_remotepairing._tcp`.
/// The connection goes: direct TCP → RPPairing (JSON) → tunnel.
///
/// This path only supports pair-verify (existing pairing file required).
/// For initial pairing, use `tunnel_pair_usb`.
///
/// Equivalent to [`tunnel_create_rppairing_multihost`] with no extra candidate
/// hosts and no interest in the failure kind.
///
/// # Safety
/// All pointer arguments must be valid and non-null (except `pin_callback`/`pin_context`).
/// `pairing_file` is borrowed, not consumed.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tunnel_create_rppairing(
    addr: *const idevice_sockaddr,
    addr_len: idevice_socklen_t,
    hostname: *const c_char,
    pairing_file: *mut RpPairingFileHandle,
    pin_callback: Option<extern "C" fn(context: *mut c_void) -> *const c_char>,
    pin_context: *mut c_void,
    out_adapter: *mut *mut AdapterHandle,
    out_handshake: *mut *mut RsdHandshakeHandle,
) -> *mut IdeviceFfiError {
    unsafe {
        tunnel_create_rppairing_multihost(
            addr,
            addr_len,
            hostname,
            pairing_file,
            pin_callback,
            pin_context,
            null_mut(),
            0,
            null_mut(),
            out_adapter,
            out_handshake,
        )
    }
}

/// [`tunnel_create_rppairing`], plus caller-supplied fallback hosts and a
/// classified failure kind.
///
/// `createListener` tells us which port the device opened but not which address
/// reaches it, so the host is guessed: whatever `addr` reached RSD on, then
/// `127.0.0.1`, then each entry of `extra_hosts` (dotted-quad or IPv6 literals —
/// in practice the local address of the interface the pairing session ran over,
/// which the caller knows and this library does not). Duplicates are dropped and
/// the whole sweep is bounded by one wall-clock budget, so extra candidates
/// never lengthen a run that was going to fail anyway. The host that works is
/// remembered and dialled first for the rest of the process.
///
/// `out_failure_kind`, when non-null, is set on every return: `TunnelFailureNone`
/// on success, otherwise which wall was hit. The raw error is still in the
/// returned `IdeviceFfiError`'s message, and every attempt is logged as it is
/// made.
///
/// # Safety
/// All pointer arguments must be valid and non-null except `pin_callback`,
/// `pin_context`, `extra_hosts` and `out_failure_kind`. `extra_hosts` must point
/// to `extra_host_count` valid C strings when non-null. `pairing_file` is
/// borrowed, not consumed.
#[unsafe(no_mangle)]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn tunnel_create_rppairing_multihost(
    addr: *const idevice_sockaddr,
    addr_len: idevice_socklen_t,
    hostname: *const c_char,
    pairing_file: *mut RpPairingFileHandle,
    pin_callback: Option<extern "C" fn(context: *mut c_void) -> *const c_char>,
    pin_context: *mut c_void,
    extra_hosts: *const *const c_char,
    extra_host_count: usize,
    out_failure_kind: *mut TunnelFailureKind,
    out_adapter: *mut *mut AdapterHandle,
    out_handshake: *mut *mut RsdHandshakeHandle,
) -> *mut IdeviceFfiError {
    let set_kind = |kind: TunnelFailureKind| {
        if !out_failure_kind.is_null() {
            unsafe { *out_failure_kind = kind };
        }
    };
    set_kind(TunnelFailureKind::TunnelFailureNone);

    if addr.is_null()
        || hostname.is_null()
        || pairing_file.is_null()
        || out_adapter.is_null()
        || out_handshake.is_null()
    {
        set_kind(TunnelFailureKind::TunnelFailureOther);
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let socket_addr = match crate::util::c_socket_to_rust(addr as *const SockAddr, addr_len) {
        Ok(a) => a,
        Err(e) => {
            set_kind(TunnelFailureKind::TunnelFailureOther);
            return ffi_err!(e);
        }
    };
    let host = match unsafe { CStr::from_ptr(hostname) }.to_str() {
        Ok(s) => s.to_string(),
        Err(_) => {
            set_kind(TunnelFailureKind::TunnelFailureOther);
            return ffi_err!(IdeviceError::FfiInvalidString);
        }
    };
    let rpf = unsafe { &mut (*pairing_file).0 };
    let ctx = PinCtx(pin_context);
    let extras = unsafe { read_extra_hosts(extra_hosts, extra_host_count) };

    let res = run_sync_local(async {
        // Connect directly and use raw RPPairing protocol
        info!("tunnel dial: opening the RPPairing connection to {socket_addr}");
        let stream = TcpStream::connect(socket_addr).await.map_err(|e| {
            warn!(
                "tunnel dial: RPPairing connect to {socket_addr} failed: {e} (kind {:?}, os error {:?})",
                e.kind(),
                e.raw_os_error()
            );
            TunnelFailure::new(
                TunnelFailureKind::TunnelFailureRsdUnreachable,
                IdeviceError::InternalError(format!("connect: {e}")),
            )
        })?;
        let conn = RpPairingSocket::new(stream);

        let mut rpc = RemotePairingClient::new(conn, &host);
        rpc.connect(rpf, async || get_pin(pin_callback, &ctx))
            .await
            .map_err(|e| {
                warn!("tunnel dial: pair-verify against {socket_addr} failed: {e:?}");
                TunnelFailure::new(TunnelFailureKind::TunnelFailurePairVerify, e)
            })?;

        finish_tunnel(&mut rpc, socket_addr, &extras).await
    });

    match res {
        Ok((adapter, handshake)) => {
            write_result(adapter, handshake, out_adapter, out_handshake);
            null_mut()
        }
        Err(failure) => {
            set_kind(failure.kind);
            ffi_err!(failure.error)
        }
    }
}

fn get_pin(cb: Option<extern "C" fn(*mut c_void) -> *const c_char>, ctx: &PinCtx) -> String {
    if let Some(cb) = cb {
        let ptr = cb(ctx.0);
        if !ptr.is_null()
            && let Ok(s) = unsafe { CStr::from_ptr(ptr) }.to_str()
        {
            return s.to_string();
        }
    }
    "000000".to_string()
}
