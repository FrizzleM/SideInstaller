//! Pipeline step 1 — find this iPhone's RemoteServiceDiscovery and the one
//! service pairing runs over.
//!
//! This is the first half of what `tunnel_create_rppairing_multihost` does, and
//! therefore what SideInstaller itself does on iOS 26: a plain TCP connection to
//! RSD on 49152, a RemoteXPC handshake, and a service list. No pairing record is
//! involved yet — the list is public.
//!
//! It is deliberately the **first** thing that touches the device. An earlier
//! version probed lockdownd on 62078 first and only then tried RSD, which got a
//! reset; lockdownd on 62078 turned out to be the wrong door entirely (it hangs
//! up on network clients within ~250µs, measured 2026-08-27), and there is no
//! reason to knock on it before the door that opens. `--diagnose` still runs
//! those probes for the record.

use std::time::Duration;

use idevice::rsd::RsdHandshake;
use idevice::xpc::RemoteXpcClient;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::timeout;

use crate::fail::{Fail, Result, chain};
use crate::ui;

/// LocalDevVPN's default peer address.
pub const DEFAULT_DEVICE_IP: &str = "10.7.0.1";
/// RemoteServiceDiscovery. Fixed, and forwarded by the VPN.
pub const RSD_PORT: u16 = 49152;
/// Classic lockdownd. Kept only for `--diagnose`; nothing in the pipeline uses it.
pub const LOCKDOWN_PORT: u16 = 62078;

/// The service `RemotePairingClient` talks to. "untrusted" is the point: it is
/// reachable with no pairing record, which is what breaks the deadlock.
pub const TUNNEL_SERVICE: &str = "com.apple.internal.dt.coredevice.untrusted.tunnelservice";

pub struct Discovery {
    /// Port `TUNNEL_SERVICE` is listening on. RSD hands out a fresh one per boot.
    pub tunnel_service_port: u16,
    pub service_count: usize,
}

fn vpn_advice(host: &str) -> String {
    [
        format!("Could not reach this iPhone's RemoteServiceDiscovery at {host}:{RSD_PORT}."),
        String::new(),
        "Open LocalDevVPN and connect it, then run siboot again. iSH cannot reach".to_string(),
        "the device's services any other way — 127.0.0.1 is blocked by the sandbox,".to_string(),
        "so the VPN's peer address is the only route.".to_string(),
        String::new(),
        "If LocalDevVPN is already connected, check its tunnel address: it is".to_string(),
        format!("user-editable, and siboot assumes {DEFAULT_DEVICE_IP}. Pass --device-ip"),
        "if you have changed it.".to_string(),
    ]
    .join("\n")
}

pub async fn run(host: &str) -> Result<Discovery> {
    ui::info(&format!("connecting to {host}:{RSD_PORT} …"));

    let stream = connect(host, RSD_PORT).await.map_err(|e| Fail::new(vpn_advice(host), e))?;
    ui::detail("TCP connected; starting the RemoteXPC handshake");

    let handshake = match timeout(Duration::from_secs(30), RsdHandshake::new(stream)).await {
        Ok(Ok(h)) => h,
        Ok(Err(e)) => return Err(diagnose_rsd(host, chain(&e)).await),
        Err(_) => return Err(diagnose_rsd(host, "RSD handshake timed out after 30s".into()).await),
    };

    let service_count = handshake.services.len();
    ui::ok(&format!("RSD answered — {service_count} services advertised"));

    if ui::verbose_enabled() {
        let mut names: Vec<&str> = handshake.services.keys().map(|s| s.as_str()).collect();
        names.sort_unstable();
        for name in &names {
            ui::detail(name);
        }
    }

    let service = handshake.services.get(TUNNEL_SERVICE).ok_or_else(|| {
        Fail::new(
            [
                "This iPhone's RemoteServiceDiscovery does not advertise the untrusted".to_string(),
                "tunnel service, which is the one pairing runs over.".to_string(),
                String::new(),
                "Run with --verbose to see what it does advertise.".to_string(),
            ]
            .join("\n"),
            format!("{TUNNEL_SERVICE} missing from {service_count} advertised services"),
        )
    })?;

    ui::ok(&format!("untrusted tunnel service is on port {}", service.port));
    Ok(Discovery { tunnel_service_port: service.port, service_count })
}

async fn connect(host: &str, port: u16) -> std::result::Result<TcpStream, String> {
    let stream = timeout(Duration::from_secs(15), TcpStream::connect((host, port)))
        .await
        .map_err(|_| format!("connecting to {host}:{port} timed out after 15s"))?
        .map_err(|e| format!("connect to {host}:{port}: {e}"))?;
    let _ = stream.set_nodelay(true);
    Ok(stream)
}

/// Find which step of the RemoteXPC handshake the device rejects.
///
/// `RsdHandshake::new` is four operations in a trench coat — `RemoteXpcClient::new`,
/// `do_handshake`, `send_device_handshake`, `recv_root` — and it reports one
/// error for all four, so on its own it cannot say whether the device dislikes
/// the HTTP/2 preface, the XPC handshake, or the request that follows.
///
/// The second experiment matters as much as the first: connecting to a service
/// port the way `tunnel_create_rppairing` does — `do_handshake` then straight to
/// `recv_root`, with **no** `send_device_handshake` — tells us whether it is
/// RemoteXPC as such that this device refuses from here, or only the RSD
/// request on top of it.
async fn diagnose_rsd(host: &str, raw: String) -> Fail {
    println!();
    ui::info("finding which step it rejects …");

    let mut reached = "nothing";

    match connect(host, RSD_PORT).await {
        Err(e) => ui::info(&format!("reconnect — {e}")),
        Ok(stream) => match timeout(Duration::from_secs(20), RemoteXpcClient::new(stream)).await {
            Err(_) => ui::info("RemoteXpcClient::new — timed out"),
            Ok(Err(e)) => ui::info(&format!("RemoteXpcClient::new — {}", chain(&e))),
            Ok(Ok(mut client)) => {
                reached = "RemoteXpcClient::new";
                ui::info("RemoteXpcClient::new     — ok");
                match timeout(Duration::from_secs(20), client.do_handshake()).await {
                    Err(_) => ui::info("do_handshake            — timed out"),
                    Ok(Err(e)) => ui::info(&format!("do_handshake            — {}", chain(&e))),
                    Ok(Ok(())) => {
                        reached = "do_handshake";
                        ui::info("do_handshake            — ok");
                        match timeout(Duration::from_secs(20), client.send_device_handshake()).await
                        {
                            Err(_) => ui::info("send_device_handshake   — timed out"),
                            Ok(Err(e)) => {
                                ui::info(&format!("send_device_handshake   — {}", chain(&e)))
                            }
                            Ok(Ok(())) => {
                                reached = "send_device_handshake";
                                ui::info("send_device_handshake   — ok");
                                match timeout(Duration::from_secs(20), client.recv_root()).await {
                                    Err(_) => ui::info("recv_root               — timed out"),
                                    Ok(Err(e)) => {
                                        ui::info(&format!("recv_root               — {}", chain(&e)))
                                    }
                                    Ok(Ok(_)) => {
                                        reached = "recv_root";
                                        ui::info("recv_root               — ok (!)");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
    }

    // Does this device send us *anything*? Every step above only writes —
    // `Http2Client::new`, `do_handshake` and `send_device_handshake` are all
    // write-only, so the first read in the whole sequence is `recv_root`, and
    // an "ok" from them means nothing more than "the local socket accepted it".
    //
    // In HTTP/2 the server sends its SETTINGS frame straight after the client
    // preface, unprompted. So writing the 24-byte magic and then reading
    // separates the two possibilities cleanly: bytes back means the device is
    // willing to talk to this process and the fault is in what we send later;
    // a reset means it is refusing us from the start, whatever we send.
    println!();
    ui::info(&format!("49152, HTTP/2 preface then read — {}", preface_only(host, RSD_PORT).await));

    // The other flow in tunnel_provider.rs. `tunnel_create_rppairing` talks to
    // the *tunnel service* with new -> do_handshake -> recv_root and no
    // `send_device_handshake`; only `RsdHandshake::new` sends that. If 49152 is
    // the tunnel service rather than RSD, our extra message is the thing being
    // reset, and this flow will get a reply where the other one did not.
    println!();
    ui::info("trying the tunnel-service flow instead (no device handshake) …");
    let as_tunnel_service = tunnel_service_flow(host, RSD_PORT).await;
    ui::info(&format!("49152, tunnel-service flow — {as_tunnel_service}"));

    let advice = [
        format!("This iPhone reset the RemoteXPC connection to {host}:{RSD_PORT}."),
        format!("The last step that completed was: {reached}."),
        String::new(),
        "SideInstaller reaches the same port from the same iPhone, so this is not".to_string(),
        "the device refusing the protocol — it is refusing this process. The".to_string(),
        "difference to look at is that SideInstaller is a native app holding iOS".to_string(),
        "Local Network permission, and iSH is not.".to_string(),
        String::new(),
        "Send these lines — which step it reached is the thing that decides what".to_string(),
        "to try next.".to_string(),
    ]
    .join("\n");

    Fail::new(advice, raw)
}

/// Write only the HTTP/2 connection preface, then read.
///
/// A conforming HTTP/2 server answers with SETTINGS before it is asked for
/// anything, so this needs no protocol support from us beyond 24 bytes.
async fn preface_only(host: &str, port: u16) -> String {
    const HTTP2_MAGIC: &[u8] = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n";

    let mut stream = match connect(host, port).await {
        Ok(s) => s,
        Err(e) => return e,
    };
    if let Err(e) = stream.write_all(HTTP2_MAGIC).await {
        return format!("writing the preface failed: {e}");
    }
    if let Err(e) = stream.flush().await {
        return format!("flushing the preface failed: {e}");
    }

    let mut buf = [0u8; 64];
    match timeout(Duration::from_secs(10), stream.read(&mut buf)).await {
        Err(_) => "silence for 10s — no SETTINGS frame".into(),
        Ok(Err(e)) => format!("reset before sending anything: {e}"),
        Ok(Ok(0)) => "closed without sending anything".into(),
        Ok(Ok(n)) => {
            // Frame header: 3-byte length, 1-byte type (0x04 = SETTINGS).
            let kind = if n >= 4 && buf[3] == 0x04 { "SETTINGS" } else { "something else" };
            format!("RECEIVED {n} bytes ({kind}) — the device does talk to this process")
        }
    }
}

/// `new` → `do_handshake` → `recv_root`, with no device handshake.
///
/// This is verbatim what `tunnel_create_rppairing` does once it has resolved a
/// service port, so a reply here means the port is a RemoteXPC *service* rather
/// than RSD — and that pairing can start from it directly.
async fn tunnel_service_flow(host: &str, port: u16) -> String {
    let stream = match connect(host, port).await {
        Ok(s) => s,
        Err(e) => return e,
    };
    let mut client = match timeout(Duration::from_secs(20), RemoteXpcClient::new(stream)).await {
        Err(_) => return "RemoteXpcClient::new timed out".into(),
        Ok(Err(e)) => return format!("RemoteXpcClient::new: {}", chain(&e)),
        Ok(Ok(c)) => c,
    };
    match timeout(Duration::from_secs(20), client.do_handshake()).await {
        Err(_) => return "do_handshake timed out".into(),
        Ok(Err(e)) => return format!("do_handshake: {}", chain(&e)),
        Ok(Ok(())) => {}
    }
    match timeout(Duration::from_secs(20), client.recv_root()).await {
        Err(_) => "no root message within 20s".into(),
        Ok(Err(e)) => format!("recv_root: {}", chain(&e)),
        Ok(Ok(value)) => {
            let shape = match value.as_dictionary() {
                Some(d) => {
                    let mut keys: Vec<&str> = d.keys().map(|k| k.as_str()).collect();
                    keys.sort_unstable();
                    format!("a dictionary with keys: {}", keys.join(", "))
                }
                None => format!("{value:?}"),
            };
            format!("ANSWERED — {shape}")
        }
    }
}
