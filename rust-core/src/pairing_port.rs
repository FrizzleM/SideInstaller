//! This iPhone's RPPairing listener, looked for when it isn't on port 49152.
//!
//! The listener, remotepairingd's, takes whatever TCP port iOS hands it when it
//! starts, and iOS hands TCP ports out in order from 49152, not at random
//! (`net.inet.tcp.randomize_ports` is 0, as on a Mac). Started first after a
//! restart, it gets 49152, which is why `DeviceConnection` and StikDebug dial
//! that one blind. Started after something else, it gets a later one: on
//! 2026-11-18 one iPhone on a Wi-Fi advertised it (`_remotepairing._tcp`) on
//! 55021, while siboot users with Developer Mode on were refused at
//! 10.7.0.1:49152.
//!
//! When 49152 refuses and this iPhone's Bonjour advert
//! (`NetworkStatus.ownRemotePairingAdvert`) doesn't lead to the listener
//! either, [`find`] knocks on the iPhone's other dynamic ports through
//! LocalDevVPN, 32 at a time, and takes the first that answers the RPPairing
//! handshake. iOS refuses a closed port at once and doesn't rate-limit the
//! refusals, so that takes seconds: all 16,382 in 24 s, from a Mac over Wi-Fi.
//!
//! Before `DeviceConnection` dials a port for the tunnel, [`probe`] asks it for
//! that handshake, with 8 s to connect and 10 s to answer, as siboot's first
//! dial does. The tunnel's dial has no time limit, so a port something else
//! holds would hold the dial: for ever when it takes the connection and never
//! answers, as the iPhone's other listeners do, and until it fails as a
//! pairing file the iPhone rejected when it answers something else. Such a
//! port is passed over instead, like a refused one.
//!
//! The search and the probe are siboot 0.19.1's (`minis/src/preflight.rs` in
//! FrizzleM/siboot), with its widths, timeouts and limits.

use std::collections::{HashSet, VecDeque};
use std::ffi::c_char;
use std::fmt::Write;
use std::future::Future;
use std::io::ErrorKind;
use std::net::{IpAddr, SocketAddr};
use std::ops::RangeInclusive;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::time::{Duration, Instant};

use idevice::remote_pairing::{RemotePairingClient, RpPairingSocket};
use idevice::IdeviceError;
use tokio::net::TcpStream;
use tokio::task::JoinSet;
use tokio::time::timeout;

use crate::ffi_util::{cstr, req_str};

/// `si_find_pairing_port`'s results: a port answered as the pairing service,
/// none did, knocking had to stop, or an argument was wrong.
pub const FOUND: i32 = 0;
pub const NOT_FOUND: i32 = 1;
pub const STOPPED: i32 = 2;
pub const INVALID: i32 = -1;

/// `si_probe_pairing_port`'s results: the port answered as the pairing
/// service, refused the connection, took it without answering as the service
/// (nothing in time, or something else), neither took nor refused it in time,
/// or the connection failed some other way. A tunnel dial gets a refusal or a
/// failure at once too, and says why.
pub const PROBE_ANSWERED: i32 = 0;
pub const PROBE_REFUSED: i32 = 1;
pub const PROBE_TOOK: i32 = 2;
pub const PROBE_SILENT: i32 = 3;
pub const PROBE_FAILED: i32 = 4;

/// The ports iOS hands a listener that asks for any free one
/// (`net.inet.ip.portrange.first` to `.last`).
const DYNAMIC_PORTS: RangeInclusive<u16> = 49152..=65535;
/// lockdownd's: the one fixed port in that range, and not the pairing service.
const LOCKDOWN_PORT: u16 = 62078;

/// How to knock: kept apart so tests can wait less.
struct Knocks {
    /// Connections open at once.
    width: usize,
    /// Through LocalDevVPN a closed port refuses and an open one accepts at
    /// once; this also covers one lost SYN, which iOS sends again after 1 s.
    connect: Duration,
    /// The pairing service answers its handshake within milliseconds.
    answer: Duration,
}

const KNOCKS: Knocks = Knocks {
    width: 32,
    connect: Duration::from_secs(2),
    answer: Duration::from_secs(3),
};

/// How long a probe waits: siboot's, longer than a knock. A port that misses
/// the probe isn't dialled, and the search passes over it, so one that's only
/// slow to answer mustn't miss. (One port, so the width isn't used.)
const PROBE: Knocks = Knocks {
    width: 1,
    connect: Duration::from_secs(8),
    answer: Duration::from_secs(10),
};

/// This many connections in a row that neither refuse nor connect: the route
/// has gone (LocalDevVPN disconnected), and knocking on would take minutes.
const SILENT_IN_A_ROW: usize = 64;
/// More ports than an iPhone has open in its dynamic range took the
/// connection, so something else answers for this address, like another VPN
/// or a proxy. The iPhone siboot checked had two there besides the pairing
/// service and lockdownd.
const MOST_OPEN: usize = 48;
/// Times the app ran out of descriptors or buffers before the search gives up.
const MOST_BUSY: usize = 256;

/// What a search or a probe came to, for `DeviceConnection`: one of the
/// results above, the port found (0 when none was) or probed, and a line for
/// the log.
#[derive(Debug)]
pub struct Report {
    pub code: i32,
    pub port: u16,
    pub summary: String,
}

/// `si_find_pairing_port`: knock on `device_ip`'s dynamic ports, except
/// lockdownd's and the `tried_count` ports in `tried`, for the pairing
/// service. Blocks. Never panics across the boundary.
///
/// # Safety
/// `device_ip` must be null or a valid C string, `tried` null or
/// `tried_count` readable `u16`s, and `out_port` and `out_summary` null or
/// writable. `*out_summary` is freed with `si_string_free`.
pub unsafe fn find_ffi(
    device_ip: *const c_char,
    tried: *const u16,
    tried_count: usize,
    out_port: *mut u16,
    out_summary: *mut *mut c_char,
) -> i32 {
    let ip = req_str(device_ip).and_then(|s| s.trim().parse::<IpAddr>().ok());
    let report = match ip {
        None => Report {
            code: INVALID,
            port: 0,
            summary: "no IP address to knock on".into(),
        },
        Some(ip) => {
            let tried = if tried.is_null() {
                &[][..]
            } else {
                std::slice::from_raw_parts(tried, tried_count)
            };
            catch_unwind(AssertUnwindSafe(|| find(ip, tried))).unwrap_or_else(|_| Report {
                code: STOPPED,
                port: 0,
                summary: "the search stopped on an internal error".into(),
            })
        }
    };
    if !out_port.is_null() {
        *out_port = report.port;
    }
    if !out_summary.is_null() {
        *out_summary = cstr(report.summary);
    }
    report.code
}

/// Knock on `ip`'s dynamic ports, except lockdownd's and those already
/// `tried`, in order, until one answers as the pairing service. Blocks.
pub fn find(ip: IpAddr, tried: &[u16]) -> Report {
    let runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(e) => {
            return Report {
                code: STOPPED,
                port: 0,
                summary: format!("couldn't start the runtime to knock with: {e}"),
            }
        }
    };
    let ports = others(tried, DYNAMIC_PORTS);
    let count = ports.len();
    let started = Instant::now();
    let search = runtime.block_on(knock_on(ip, ports, &KNOCKS));
    report(&search, ip, count, started.elapsed(), &KNOCKS)
}

/// `ports` without lockdownd's and the ones already tried, in order.
fn others(tried: &[u16], ports: impl IntoIterator<Item = u16>) -> Vec<u16> {
    let tried: HashSet<u16> = tried.iter().copied().collect();
    ports
        .into_iter()
        .filter(|p| *p != LOCKDOWN_PORT && !tried.contains(p))
        .collect()
}

fn listed(ports: &[u16]) -> String {
    if ports.is_empty() {
        return "none".into();
    }
    let mut sorted = ports.to_vec();
    sorted.sort_unstable();
    sorted
        .iter()
        .map(u16::to_string)
        .collect::<Vec<_>>()
        .join(", ")
}

/// What `search` came to, said for the log. `count` ports were to be knocked
/// on, and it took `took`.
fn report(search: &Search, ip: IpAddr, count: usize, took: Duration, knocks: &Knocks) -> Report {
    let took = took.as_secs_f32();
    match search {
        Search::Found {
            port,
            found,
            knocked,
        } => Report {
            code: FOUND,
            port: *port,
            summary: format!(
                "found on port {port} (RPPairing, wire protocol {}) after {knocked} of {count} \
                 ports, in {took:.1} s",
                found.wire_version
            ),
        },
        Search::NotFound { open } => Report {
            code: NOT_FOUND,
            port: 0,
            summary: format!(
                "no other port answered the RPPairing handshake ({count} knocked on in \
                 {took:.1} s; took the connection: {})",
                listed(open)
            ),
        },
        Search::Stopped { why, knocked } => {
            let why = match why {
                Stop::Silent { last } => format!(
                    "{SILENT_IN_A_ROW} connections in a row neither refused nor connected \
                     within {} s, the last to port {last}, so LocalDevVPN stopped carrying them",
                    knocks.connect.as_secs_f32()
                ),
                Stop::Open { open } => format!(
                    "{} ports took the connection and none answered RPPairing, more than this \
                     iPhone has open, so something other than LocalDevVPN answers at {ip}, like \
                     another VPN or a proxy: {}",
                    open.len(),
                    listed(open)
                ),
                Stop::Busy { error, times } => format!(
                    "out of descriptors or buffers {times} times, the last: {error} ({:?})",
                    error.kind()
                ),
                Stop::Failed { port, error } => format!(
                    "the route to {} failed: {error} ({:?})",
                    SocketAddr::new(ip, *port),
                    error.kind()
                ),
            };
            Report {
                code: STOPPED,
                port: 0,
                summary: format!("stopped after {knocked} of {count} ports, in {took:.1} s: {why}"),
            }
        }
    }
}

/// `si_probe_pairing_port`: ask `device_ip:port` for the RPPairing handshake,
/// as a tunnel dial does first, within `PROBE`'s limits. Blocks for up to
/// 18 s. Never panics across the boundary.
///
/// # Safety
/// `device_ip` must be null or a valid C string, and `out_summary` null or
/// writable. `*out_summary` is freed with `si_string_free`.
pub unsafe fn probe_ffi(device_ip: *const c_char, port: u16, out_summary: *mut *mut c_char) -> i32 {
    let ip = req_str(device_ip).and_then(|s| s.trim().parse::<IpAddr>().ok());
    let report = match ip {
        None => Report {
            code: INVALID,
            port,
            summary: "wasn't probed: there's no IP address to probe".into(),
        },
        Some(ip) => catch_unwind(AssertUnwindSafe(|| probe(SocketAddr::new(ip, port))))
            .unwrap_or_else(|_| Report {
                code: PROBE_FAILED,
                port,
                summary: "wasn't probed: the probe stopped on an internal error".into(),
            }),
    };
    if !out_summary.is_null() {
        *out_summary = cstr(report.summary);
    }
    report.code
}

/// Ask `addr` for the RPPairing handshake, as a tunnel dial does first, within
/// `PROBE`'s limits, and say what it did. Blocks.
pub fn probe(addr: SocketAddr) -> Report {
    let runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(e) => {
            return Report {
                code: PROBE_FAILED,
                port: addr.port(),
                summary: format!("wasn't probed: couldn't start the runtime to probe with: {e}"),
            }
        }
    };
    let knocked = runtime.block_on(knock(addr, PROBE.connect, PROBE.answer));
    probed(knocked, addr.port(), &PROBE)
}

/// What a probe's knock on `port` found, said for the log after "Port N".
fn probed(knock: Knock, port: u16, limits: &Knocks) -> Report {
    let (code, summary) = match knock {
        Knock::Answered(found) => (
            PROBE_ANSWERED,
            format!(
                "answered the RPPairing handshake (wire protocol {})",
                found.wire_version
            ),
        ),
        Knock::Closed => (PROBE_REFUSED, "refused the connection".to_string()),
        Knock::Open(None) => (
            PROBE_TOOK,
            format!(
                "took the connection but didn't answer the RPPairing handshake within {} s",
                limits.answer.as_secs_f32()
            ),
        ),
        Knock::Open(Some(said)) => (
            PROBE_TOOK,
            format!("took the connection but didn't answer as RPPairing ({said})"),
        ),
        Knock::Silent => (
            PROBE_SILENT,
            format!(
                "neither took nor refused the connection within {} s",
                limits.connect.as_secs_f32()
            ),
        ),
        Knock::Busy(e) | Knock::Failed(e) => (
            PROBE_FAILED,
            format!("couldn't be connected to: {e} ({:?})", e.kind()),
        ),
    };
    Report {
        code,
        port,
        summary,
    }
}

/// What the pairing service said to the handshake.
#[derive(Debug, PartialEq, Eq)]
struct Found {
    wire_version: i64,
}

impl Found {
    fn from_handshake(reply: &plist::Value) -> Self {
        let wire_version = reply
            .as_dictionary()
            .and_then(|d| d.get("wireProtocolVersion"))
            .and_then(|v| v.as_signed_integer())
            .unwrap_or(0);
        Self { wire_version }
    }
}

#[derive(Debug)]
enum Search {
    /// Where it is, what it said, and how many ports were knocked on.
    Found {
        port: u16,
        found: Found,
        knocked: usize,
    },
    /// No port answered as the pairing service. `open` took the connection.
    NotFound { open: Vec<u16> },
    /// Knocking had to stop after `knocked` ports, for `why`.
    Stopped { why: Stop, knocked: usize },
}

#[derive(Debug)]
enum Stop {
    /// `SILENT_IN_A_ROW` connections in a row, the last to `last`, neither
    /// refused nor connected: the route has gone.
    Silent { last: u16 },
    /// More than `MOST_OPEN` ports took the connection without answering.
    Open { open: Vec<u16> },
    /// Out of descriptors or buffers more than `MOST_BUSY` times.
    Busy { error: std::io::Error, times: usize },
    /// The route itself failed, on the way to `port`.
    Failed { port: u16, error: std::io::Error },
}

/// Knock on each of `ports` at `ip`, as `knocks` says.
async fn knock_on(ip: IpAddr, ports: Vec<u16>, knocks: &Knocks) -> Search {
    let (connect, answer) = (knocks.connect, knocks.answer);
    search(ports, knocks.width, move |port| {
        knock(SocketAddr::new(ip, port), connect, answer)
    })
    .await
}

/// Knock on each of `ports`, `width` at a time, in order, until one answers as
/// the pairing service. `knock` is what knocking on one port does.
async fn search<K, F>(ports: Vec<u16>, width: usize, knock: K) -> Search
where
    K: Fn(u16) -> F,
    F: Future<Output = Knock> + Send + 'static,
{
    let count = ports.len();
    let most = width.max(1);
    let mut width = most;
    let mut queue = VecDeque::from(ports);
    let mut running = JoinSet::new();
    let started = Instant::now();
    let (mut settled, mut quarters) = (0usize, 0usize);
    let mut open = Vec::new();
    let (mut silent, mut busy) = (0usize, 0usize);
    loop {
        while running.len() < width {
            let Some(port) = queue.pop_front() else { break };
            let knocking = knock(port);
            running.spawn(async move { (port, knocking.await) });
        }
        // Leaving early drops the set, which aborts the knocks still out.
        let Some(joined) = running.join_next().await else {
            return Search::NotFound { open };
        };
        let Ok((port, outcome)) = joined else {
            continue;
        };
        match outcome {
            Knock::Answered(found) => {
                return Search::Found {
                    port,
                    found,
                    knocked: settled + 1,
                }
            }
            Knock::Closed => silent = 0,
            Knock::Open(_) => {
                silent = 0;
                open.push(port);
                if open.len() > MOST_OPEN {
                    return Search::Stopped {
                        why: Stop::Open { open },
                        knocked: settled + 1,
                    };
                }
            }
            Knock::Silent => {
                silent += 1;
                if silent >= SILENT_IN_A_ROW {
                    return Search::Stopped {
                        why: Stop::Silent { last: port },
                        knocked: settled + 1,
                    };
                }
            }
            Knock::Busy(error) => {
                busy += 1;
                if busy > MOST_BUSY {
                    return Search::Stopped {
                        why: Stop::Busy { error, times: busy },
                        knocked: settled,
                    };
                }
                // Fewer at once, and this port again later.
                width = fewer(width, most);
                queue.push_back(port);
                continue;
            }
            Knock::Failed(error) => {
                return Search::Stopped {
                    why: Stop::Failed { port, error },
                    knocked: settled + 1,
                }
            }
        }
        settled += 1;
        // The tunnel dial's log goes quiet meanwhile, so say how far it got.
        let quarter = settled * 4 / count.max(1);
        if quarter > quarters && quarter < 4 {
            quarters = quarter;
            tracing::info!(
                "pairing port search: {settled} of {count} ports knocked on, {:.1} s",
                started.elapsed().as_secs_f32()
            );
        }
    }
}

/// How many to knock on at once after running out of descriptors with
/// `width` out: half, but no fewer than 4 unless `most` is fewer.
fn fewer(width: usize, most: usize) -> usize {
    (width / 2).max(4).min(most)
}

#[derive(Debug)]
enum Knock {
    /// The pairing service.
    Answered(Found),
    /// Nothing listens there.
    Closed,
    /// Something took the connection, but didn't answer as the service: what
    /// went wrong when it answered something else or hung up, `None` when it
    /// said nothing in time.
    Open(Option<String>),
    /// Neither refused nor connected in time.
    Silent,
    /// Out of descriptors, buffers or local ports for now.
    Busy(std::io::Error),
    /// The route itself failed.
    Failed(std::io::Error),
}

/// Connect to `addr`, and ask whatever takes the connection for the RPPairing
/// handshake.
async fn knock(addr: SocketAddr, connect: Duration, answer: Duration) -> Knock {
    match timeout(connect, TcpStream::connect(addr)).await {
        Err(_) => Knock::Silent,
        Ok(Err(e)) => match e.kind() {
            ErrorKind::TimedOut => Knock::Silent,
            ErrorKind::PermissionDenied
            | ErrorKind::NetworkUnreachable
            | ErrorKind::HostUnreachable
            | ErrorKind::NetworkDown => Knock::Failed(e),
            _ if is_busy(&e) => Knock::Busy(e),
            // Refused, reset, or anything else about this one port.
            _ => Knock::Closed,
        },
        Ok(Ok(stream)) => match timeout(answer, handshake(stream)).await {
            Ok(Ok(found)) => Knock::Answered(found),
            Ok(Err(e)) => Knock::Open(Some(chain(&e))),
            Err(_) => Knock::Open(None),
        },
    }
}

/// `e` and what caused it: idevice's socket error alone reads "device socket
/// io failed".
fn chain(e: &dyn std::error::Error) -> String {
    let mut out = e.to_string();
    let mut source = e.source();
    while let Some(s) = source {
        let _ = write!(out, ": {s}");
        source = s.source();
    }
    out
}

/// The handshake the pairing service answers first, as
/// `tunnel_create_rppairing` sends it.
async fn handshake(stream: TcpStream) -> Result<Found, IdeviceError> {
    let mut client = RemotePairingClient::new(RpPairingSocket::new(stream), "SideInstaller");
    let reply = client.attempt_pair_verify().await?;
    Ok(Found::from_handshake(&reply))
}

/// Worth trying again with fewer connections open.
fn is_busy(e: &std::io::Error) -> bool {
    matches!(
        e.raw_os_error(),
        Some(libc::EMFILE | libc::ENFILE | libc::ENOBUFS | libc::EADDRNOTAVAIL | libc::EAGAIN)
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use std::net::Ipv4Addr;
    use std::sync::{Arc, Mutex};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

    const QUICK: Knocks = Knocks {
        width: 32,
        connect: Duration::from_secs(2),
        answer: Duration::from_millis(300),
    };

    const LOOPBACK: IpAddr = IpAddr::V4(Ipv4Addr::LOCALHOST);

    async fn listener() -> (TcpListener, u16) {
        let listener = TcpListener::bind((LOOPBACK, 0)).await.unwrap();
        let port = listener.local_addr().unwrap().port();
        (listener, port)
    }

    /// This iPhone's pairing service: each connection's handshake answered as
    /// the iPhone answers it.
    async fn pairing_service() -> u16 {
        let (listener, port) = listener().await;
        tokio::spawn(async move {
            while let Ok((mut s, _)) = listener.accept().await {
                tokio::spawn(async move {
                    let mut head = [0u8; 11];
                    if s.read_exact(&mut head).await.is_err() || &head[..9] != b"RPPairing" {
                        return;
                    }
                    let mut body = vec![0; u16::from_be_bytes([head[9], head[10]]) as usize];
                    if s.read_exact(&mut body).await.is_err() {
                        return;
                    }
                    let reply = serde_json::json!({
                        "message": {"plain": {"_0": {"response": {"_1": {"handshake": {"_0": {
                            "deviceOptions": {"allowsPairSetup": true},
                            "peerDeviceInfo": {"name": "Test iPhone"},
                            "wireProtocolVersion": 26
                        }}}}}}},
                        "originatedBy": "device",
                        "sequenceNumber": 0
                    })
                    .to_string();
                    let mut frame = b"RPPairing".to_vec();
                    frame.extend_from_slice(&(reply.len() as u16).to_be_bytes());
                    frame.extend_from_slice(reply.as_bytes());
                    let _ = s.write_all(&frame).await;
                    let _ = s.read(&mut [0u8; 64]).await;
                });
            }
        });
        port
    }

    /// Takes the connection and says nothing, as the iPhone's other
    /// listeners do.
    async fn silent_service() -> u16 {
        let (listener, port) = listener().await;
        tokio::spawn(async move {
            let mut held = Vec::new();
            while let Ok((s, _)) = listener.accept().await {
                held.push(s);
            }
        });
        port
    }

    /// Answers, but not as the pairing service.
    async fn other_service() -> u16 {
        let (listener, port) = listener().await;
        tokio::spawn(async move {
            while let Ok((mut s, _)) = listener.accept().await {
                let _ = s.write_all(b"HTTP/1.1 400 Bad Request\r\n\r\n").await;
            }
        });
        port
    }

    /// A port nothing listens on any more.
    async fn closed_port() -> u16 {
        listener().await.1
    }

    async fn knock_quick(port: u16) -> Knock {
        knock(SocketAddr::new(LOOPBACK, port), QUICK.connect, QUICK.answer).await
    }

    fn reported(search: &Search, count: usize) -> Report {
        report(search, LOOPBACK, count, Duration::from_millis(1234), &QUICK)
    }

    #[tokio::test]
    async fn only_the_pairing_service_answers_the_handshake() {
        let (service, silent) = (pairing_service().await, silent_service().await);
        let (other, closed) = (other_service().await, closed_port().await);
        let answered = knock_quick(service).await;
        assert!(
            matches!(answered, Knock::Answered(Found { wire_version: 26 })),
            "{answered:?}"
        );
        assert!(matches!(knock_quick(silent).await, Knock::Open(None)));
        let answered = knock_quick(other).await;
        assert!(matches!(&answered, Knock::Open(Some(_))), "{answered:?}");
        assert!(matches!(knock_quick(closed).await, Knock::Closed));
    }

    #[tokio::test]
    async fn a_probe_says_what_the_port_did() {
        let (service, silent) = (pairing_service().await, silent_service().await);
        let (other, closed) = (other_service().await, closed_port().await);
        let probe = |port| async move { probed(knock_quick(port).await, port, &QUICK) };

        let answered = probe(service).await;
        assert_eq!((answered.code, answered.port), (PROBE_ANSWERED, service));
        assert_eq!(
            answered.summary,
            "answered the RPPairing handshake (wire protocol 26)"
        );
        let refused = probe(closed).await;
        assert_eq!(
            (refused.code, refused.summary.as_str()),
            (PROBE_REFUSED, "refused the connection")
        );
        // Taken and never answered: the tunnel's dial would wait for ever.
        let quiet = probe(silent).await;
        assert_eq!(
            (quiet.code, quiet.summary.as_str()),
            (
                PROBE_TOOK,
                "took the connection but didn't answer the RPPairing handshake within 0.3 s"
            )
        );
        // Taken and answered otherwise: the dial would fail it as a pairing
        // file the iPhone rejected.
        let wrong = probe(other).await;
        assert_eq!(wrong.code, PROBE_TOOK);
        assert!(
            wrong.summary.starts_with(
                "took the connection but didn't answer as RPPairing (device socket io failed: "
            ),
            "{}",
            wrong.summary
        );
    }

    #[test]
    fn a_probe_that_gets_nowhere_says_so() {
        let silent = probed(Knock::Silent, 49152, &PROBE);
        assert_eq!(
            (silent.code, silent.summary.as_str()),
            (
                PROBE_SILENT,
                "neither took nor refused the connection within 8 s"
            )
        );
        let quiet = probed(Knock::Open(None), 49152, &PROBE);
        assert_eq!(
            quiet.summary,
            "took the connection but didn't answer the RPPairing handshake within 10 s"
        );
        let unreachable = std::io::Error::from_raw_os_error(libc::ENETUNREACH);
        let failed = probed(Knock::Failed(unreachable), 49152, &PROBE);
        assert_eq!(failed.code, PROBE_FAILED);
        assert!(
            failed.summary.starts_with("couldn't be connected to: ")
                && failed.summary.ends_with(" (NetworkUnreachable)"),
            "{}",
            failed.summary
        );
        let busy = std::io::Error::from_raw_os_error(libc::EMFILE);
        assert_eq!(probed(Knock::Busy(busy), 49152, &PROBE).code, PROBE_FAILED);
    }

    #[test]
    fn the_probe_answers_through_the_c_call() {
        // The stand-ins run on a runtime of their own, as the iPhone's
        // listeners do, and the probe starts its own, as when Swift calls it.
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let (service, closed) =
            runtime.block_on(async { (pairing_service().await, closed_port().await) });
        let ask = |ip: &std::ffi::CStr, port: u16| {
            let mut text = std::ptr::null_mut();
            let code = unsafe { probe_ffi(ip.as_ptr(), port, &mut text) };
            let said = unsafe { std::ffi::CStr::from_ptr(text) }
                .to_str()
                .unwrap()
                .to_string();
            unsafe { crate::ffi_util::string_free(text) };
            (code, said)
        };
        assert_eq!(
            ask(c"127.0.0.1", service),
            (
                PROBE_ANSWERED,
                "answered the RPPairing handshake (wire protocol 26)".to_string()
            )
        );
        assert_eq!(
            ask(c"127.0.0.1", closed),
            (PROBE_REFUSED, "refused the connection".to_string())
        );
        assert_eq!(
            ask(c"not an address", 49152),
            (
                INVALID,
                "wasn't probed: there's no IP address to probe".to_string()
            )
        );
        let code = unsafe { probe_ffi(std::ptr::null(), 49152, std::ptr::null_mut()) };
        assert_eq!(code, INVALID);
    }

    #[tokio::test]
    async fn the_service_is_found_past_closed_silent_and_other_ports() {
        let closed = closed_port().await;
        let (silent, other, service) = (
            silent_service().await,
            other_service().await,
            pairing_service().await,
        );
        let mut ports = vec![closed; 200];
        ports.extend([silent, other, closed, service]);

        let search = knock_on(LOOPBACK, ports, &QUICK).await;
        let Search::Found {
            port,
            found,
            knocked,
        } = &search
        else {
            panic!("{search:?}");
        };
        assert_eq!((*port, found.wire_version), (service, 26));
        assert!(*knocked <= 204, "{knocked}");
        let report = reported(&search, 204);
        assert_eq!((report.code, report.port), (FOUND, service));
        assert_eq!(
            report.summary,
            format!(
                "found on port {service} (RPPairing, wire protocol 26) after {knocked} of 204 \
                 ports, in 1.2 s"
            )
        );
    }

    #[tokio::test]
    async fn none_found_is_said_with_what_took_the_connection() {
        let (closed, other, silent) = (
            closed_port().await,
            other_service().await,
            silent_service().await,
        );
        let search = knock_on(LOOPBACK, vec![closed, other, silent], &QUICK).await;
        let Search::NotFound { open } = &search else {
            panic!("{search:?}");
        };
        assert_eq!(open.len(), 2);
        let report = reported(&search, 3);
        assert_eq!((report.code, report.port), (NOT_FOUND, 0));
        let (low, high) = (other.min(silent), other.max(silent));
        assert_eq!(
            report.summary,
            format!(
                "no other port answered the RPPairing handshake (3 knocked on in 1.2 s; took \
                 the connection: {low}, {high})"
            )
        );
    }

    #[tokio::test]
    async fn ports_that_all_take_the_connection_are_not_this_iphones() {
        let other = other_service().await;
        let search = knock_on(LOOPBACK, vec![other; MOST_OPEN + 5], &QUICK).await;
        let Search::Stopped {
            why: Stop::Open { open },
            ..
        } = &search
        else {
            panic!("{search:?}");
        };
        assert_eq!(open.len(), MOST_OPEN + 1);
        let report = reported(&search, MOST_OPEN + 5);
        assert_eq!(report.code, STOPPED);
        assert!(
            report.summary.contains(&format!(
                "{} ports took the connection and none answered RPPairing",
                MOST_OPEN + 1
            )),
            "{}",
            report.summary
        );
        assert!(
            report.summary.contains("another VPN or a proxy"),
            "{}",
            report.summary
        );
    }

    #[test]
    fn lockdownd_and_the_ports_tried_are_not_knocked_on() {
        let ports = others(&[49152], DYNAMIC_PORTS);
        assert_eq!(ports.len(), 65535 - 49152 + 1 - 2);
        assert_eq!((ports[0], *ports.last().unwrap()), (49153, 65535));
        assert!(!ports.contains(&LOCKDOWN_PORT) && !ports.contains(&49152));
        // A port dialled before the knock, like the advertised one, isn't
        // knocked on again either.
        let ports = others(&[49152, 55021], DYNAMIC_PORTS);
        assert_eq!(ports.len(), 65535 - 49152 + 1 - 3);
        assert!(!ports.contains(&55021));
        assert_eq!(others(&[], DYNAMIC_PORTS)[0], 49152);
        assert_eq!(listed(&[54666, 49999]), "49999, 54666");
        assert_eq!(listed(&[]), "none");
    }

    // The stops, with each port's knock scripted instead of dialled.

    #[tokio::test]
    async fn silence_in_a_row_stops_the_search() {
        let search = search((1..=500).collect(), 32, |_| async { Knock::Silent }).await;
        let Search::Stopped {
            why: Stop::Silent { last },
            knocked,
        } = &search
        else {
            panic!("{search:?}");
        };
        assert_eq!(*knocked, SILENT_IN_A_ROW);
        let report = reported(&search, 500);
        assert_eq!(report.code, STOPPED);
        assert_eq!(
            report.summary,
            format!(
                "stopped after 64 of 500 ports, in 1.2 s: 64 connections in a row neither \
                 refused nor connected within 2 s, the last to port {last}, so LocalDevVPN \
                 stopped carrying them"
            )
        );
    }

    #[tokio::test]
    async fn a_refusal_now_and_then_keeps_it_knocking() {
        // Silent ports, but every 50th refuses: never 64 silent in a row.
        let search = search((1..=500).collect(), 32, |port| async move {
            if port % 50 == 0 {
                Knock::Closed
            } else {
                Knock::Silent
            }
        })
        .await;
        assert!(
            matches!(&search, Search::NotFound { open } if open.is_empty()),
            "{search:?}"
        );
    }

    #[tokio::test]
    async fn running_out_of_descriptors_knocks_fewer_at_once_and_again() {
        // Ports 1–8 run out of descriptors the first time; 5 is the service.
        let first_time: Arc<Mutex<HashSet<u16>>> = Arc::new(Mutex::new((1..=8).collect()));
        let knocks: Arc<Mutex<HashMap<u16, usize>>> = Arc::default();
        let search = search((1..=40).collect(), 32, {
            let knocks = knocks.clone();
            move |port| {
                *knocks.lock().unwrap().entry(port).or_default() += 1;
                let busy = first_time.lock().unwrap().remove(&port);
                async move {
                    if busy {
                        Knock::Busy(std::io::Error::from_raw_os_error(libc::EMFILE))
                    } else if port == 5 {
                        Knock::Answered(Found { wire_version: 26 })
                    } else {
                        Knock::Closed
                    }
                }
            }
        })
        .await;
        assert!(
            matches!(search, Search::Found { port: 5, .. }),
            "{search:?}"
        );
        assert_eq!(knocks.lock().unwrap()[&5], 2);

        assert_eq!(fewer(32, 32), 16);
        assert_eq!(fewer(16, 32), 8);
        assert_eq!(fewer(8, 32), 4);
        assert_eq!(fewer(4, 32), 4);
        // Never more than were asked for.
        assert_eq!(fewer(2, 2), 2);
        assert_eq!(fewer(1, 1), 1);
    }

    #[tokio::test]
    async fn running_out_too_often_stops_the_search() {
        let search = search((1..=10).collect(), 32, |_| async {
            Knock::Busy(std::io::Error::from_raw_os_error(libc::ENOBUFS))
        })
        .await;
        let Search::Stopped {
            why: Stop::Busy { times, .. },
            knocked,
        } = &search
        else {
            panic!("{search:?}");
        };
        assert_eq!((*times, *knocked), (MOST_BUSY + 1, 0));
        let report = reported(&search, 10);
        assert!(
            report.summary.starts_with(
                "stopped after 0 of 10 ports, in 1.2 s: out of descriptors or buffers 257 times"
            ),
            "{}",
            report.summary
        );
        assert!(is_busy(&std::io::Error::from_raw_os_error(libc::EMFILE)));
        assert!(is_busy(&std::io::Error::from_raw_os_error(libc::ENFILE)));
        assert!(!is_busy(&std::io::Error::from_raw_os_error(
            libc::ECONNREFUSED
        )));
    }

    #[tokio::test]
    async fn a_route_that_fails_stops_the_search() {
        let search = search((1..=10).collect(), 1, |port| async move {
            if port == 3 {
                Knock::Failed(std::io::Error::from_raw_os_error(libc::EHOSTUNREACH))
            } else {
                Knock::Closed
            }
        })
        .await;
        assert!(
            matches!(
                &search,
                Search::Stopped {
                    why: Stop::Failed { port: 3, .. },
                    knocked: 3
                }
            ),
            "{search:?}"
        );
        let report = reported(&search, 10);
        assert!(
            report.summary.starts_with(
                "stopped after 3 of 10 ports, in 1.2 s: the route to 127.0.0.1:3 failed:"
            ),
            "{}",
            report.summary
        );
    }

    #[test]
    fn a_bad_address_is_said_and_null_outputs_are_left_alone() {
        let (mut port, mut text) = (7u16, std::ptr::null_mut());
        let ip = c"not an address";
        let code = unsafe { find_ffi(ip.as_ptr(), std::ptr::null(), 3, &mut port, &mut text) };
        assert_eq!((code, port), (INVALID, 0));
        let said = unsafe { std::ffi::CStr::from_ptr(text) }
            .to_str()
            .unwrap()
            .to_string();
        unsafe { crate::ffi_util::string_free(text) };
        assert_eq!(said, "no IP address to knock on");
        let code = unsafe {
            find_ffi(
                std::ptr::null(),
                std::ptr::null(),
                0,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
            )
        };
        assert_eq!(code, INVALID);
    }
}
