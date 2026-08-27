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

    let stream = timeout(Duration::from_secs(15), TcpStream::connect((host, RSD_PORT)))
        .await
        .map_err(|_| Fail::new(vpn_advice(host), "connect timed out after 15s"))?
        .map_err(|e| Fail::new(vpn_advice(host), format!("connect: {e}")))?;
    let _ = stream.set_nodelay(true);
    ui::detail("TCP connected; starting the RemoteXPC handshake");

    let handshake = timeout(Duration::from_secs(30), RsdHandshake::new(stream))
        .await
        .map_err(|_| {
            Fail::new(
                [
                    format!("{host}:{RSD_PORT} accepted the connection but never completed"),
                    "the RemoteServiceDiscovery handshake.".to_string(),
                    String::new(),
                    "Try again with iSH in the foreground the whole time — iOS suspends it".to_string(),
                    "within a second or two of leaving, and the handshake stalls rather than".to_string(),
                    "failing.".to_string(),
                ]
                .join("\n"),
                "RSD handshake timed out after 30s",
            )
        })?
        .map_err(|e| {
            Fail::new(
                [
                    format!("{host}:{RSD_PORT} refused the RemoteServiceDiscovery handshake."),
                    String::new(),
                    "If this iPhone is older than iOS 17, there is no RSD to talk to and".to_string(),
                    "siboot cannot work here at all.".to_string(),
                    String::new(),
                    "Otherwise the likeliest cause is another client already holding the".to_string(),
                    "RSD connection — StikDebug, or a previous siboot run that did not exit".to_string(),
                    "cleanly. Force-quit those and try again.".to_string(),
                ]
                .join("\n"),
                format!("RsdHandshake: {}", chain(&e)),
            )
        })?;

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
                "tunnel service, which is the one siboot pairs over.".to_string(),
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
