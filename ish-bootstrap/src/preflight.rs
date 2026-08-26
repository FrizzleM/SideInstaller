//! Pipeline step 1 — confirm this iPhone's own `lockdownd` is reachable and
//! talking, before anything slower or more interactive is attempted.
//!
//! Reachability alone is not enough to go on: an open port says the loopback
//! VPN is routing, not that the thing behind it is lockdownd. `QueryType` is
//! the cheapest exchange that proves the whole path — a 4-byte big-endian
//! length prefix, an XML plist in, an XML plist out — and it needs no pairing
//! record, so it can run before the device has ever trusted us.
//!
//! It also proves, on hardware, that `idevice`'s protocol code runs under
//! emulation at all. That is why this step exists as its own checkpoint.

use std::time::Duration;

use idevice::{Idevice, services::lockdown::LockdownClient};
use tokio::net::TcpStream;
use tokio::time::timeout;

use crate::fail::{Fail, Result};
use crate::ui;

/// LocalDevVPN's default peer address. Measured on device: `lockdownd` and RSD
/// both answer here, while plain loopback returns EPERM — the sandbox denies a
/// non-native process loopback access to system services.
pub const DEFAULT_DEVICE_IP: &str = "10.7.0.1";
pub const LOCKDOWN_PORT: u16 = 62078;

/// What lockdownd will say before it has any reason to trust us.
const LOCKDOWN_TYPE: &str = "com.apple.mobile.lockdown";

/// Values worth asking for without a session. Which of these a device answers
/// unauthenticated varies by iOS version, and the answer decides how much
/// step 2 has to do — a `UniqueDeviceID` readable here is the UDID signing
/// needs, obtained without spending a pairing slot.
const PROBE_KEYS: &[&str] = &[
    "UniqueDeviceID",
    "ProductType",
    "ProductVersion",
    "BuildVersion",
    "DeviceClass",
    "DeviceName",
];

pub struct Greeting {
    /// The `Type` lockdownd reported. Recorded rather than used: step 3 checks
    /// it again through the tunnel, where a mismatch means something different.
    #[allow(dead_code)]
    pub lockdown_type: String,
    /// Whatever it was willing to hand over without a session.
    pub readable: Vec<(String, String)>,
}

impl Greeting {
    pub fn value(&self, key: &str) -> Option<&str> {
        self.readable.iter().find(|(k, _)| k == key).map(|(_, v)| v.as_str())
    }
}

/// Advice for every failure in this step. The spec requires LocalDevVPN by
/// name, because it is the one thing the user can act on and nothing else in
/// the pipeline can start without it.
fn vpn_advice(host: &str) -> String {
    [
        format!("Could not reach this iPhone's own lockdownd at {host}:{LOCKDOWN_PORT}."),
        String::new(),
        "Open LocalDevVPN and connect it, then run siboot again. iSH cannot reach".into(),
        "the device's services any other way — 127.0.0.1 is blocked by the sandbox,".into(),
        "so the VPN's peer address is the only route.".into(),
        String::new(),
        "If LocalDevVPN is already connected, check its tunnel address: it is".into(),
        format!("user-editable, and siboot assumes {DEFAULT_DEVICE_IP}. Pass --device-ip"),
        "if you have changed it.".into(),
    ]
    .join("\n")
}

pub async fn run(host: &str) -> Result<Greeting> {
    ui::info(&format!("connecting to {host}:{LOCKDOWN_PORT} …"));

    let stream = timeout(Duration::from_secs(15), TcpStream::connect((host, LOCKDOWN_PORT)))
        .await
        .map_err(|_| {
            Fail::new(
                vpn_advice(host),
                format!("connecting to {host}:{LOCKDOWN_PORT} timed out after 15s"),
            )
        })?
        .map_err(|e| Fail::new(vpn_advice(host), format!("connect: {e}")))?;

    // Lockdown is request/response with small messages; Nagle only adds latency.
    let _ = stream.set_nodelay(true);
    ui::detail("TCP connected");

    let mut device = Idevice::new(Box::new(stream), crate::LABEL);

    let lockdown_type = timeout(Duration::from_secs(20), device.get_type())
        .await
        .map_err(|_| {
            Fail::new(
                format!(
                    "{host}:{LOCKDOWN_PORT} accepted the connection but never answered.\n\n\
                     That usually means something other than lockdownd is on that port.\n\
                     Check LocalDevVPN's tunnel address, and pass --device-ip if it is\n\
                     not {DEFAULT_DEVICE_IP}."
                ),
                "QueryType timed out after 20s",
            )
        })?
        .map_err(|e| {
            Fail::new(
                format!(
                    "{host}:{LOCKDOWN_PORT} answered, but not the way lockdownd does.\n\n\
                     Check LocalDevVPN's tunnel address, and pass --device-ip if it is\n\
                     not {DEFAULT_DEVICE_IP}."
                ),
                format!("QueryType failed: {e}"),
            )
        })?;

    if lockdown_type != LOCKDOWN_TYPE {
        return Err(Fail::new(
            format!(
                "The service at {host}:{LOCKDOWN_PORT} is not lockdownd — it calls\n\
                 itself \"{lockdown_type}\".\n\n\
                 Check LocalDevVPN's tunnel address and pass --device-ip if it is\n\
                 not {DEFAULT_DEVICE_IP}."
            ),
            format!("QueryType returned {lockdown_type}, expected {LOCKDOWN_TYPE}"),
        ));
    }

    ui::ok(&format!("lockdownd answered — Type = {lockdown_type}"));

    let readable = probe_values(device).await;
    Ok(Greeting { lockdown_type, readable })
}

/// Ask for each key without starting a session, and keep whatever comes back.
///
/// Every one of these is expected to fail on a device that has never trusted
/// this host, so a refusal is recorded rather than raised — the point is to
/// learn what this iOS version gives away, not to get a particular answer.
async fn probe_values(device: Idevice) -> Vec<(String, String)> {
    let mut client = LockdownClient::new(device);
    let mut readable = Vec::new();

    for key in PROBE_KEYS {
        match timeout(Duration::from_secs(10), client.get_value(Some(key), None)).await {
            Ok(Ok(value)) => {
                let rendered = render(&value);
                ui::detail(&format!("{key} = {rendered}"));
                readable.push((key.to_string(), rendered));
            }
            Ok(Err(e)) => ui::detail(&format!("{key}: refused without a session ({e})")),
            Err(_) => ui::detail(&format!("{key}: timed out")),
        }
    }

    if readable.is_empty() {
        ui::info("lockdownd gave away nothing without a pairing session, as expected");
    } else {
        ui::ok(&format!(
            "readable without pairing: {}",
            readable.iter().map(|(k, _)| k.as_str()).collect::<Vec<_>>().join(", ")
        ));
    }
    readable
}

/// plist values render as debug otherwise, which is unreadable in a terminal.
fn render(value: &plist::Value) -> String {
    match value {
        plist::Value::String(s) => s.clone(),
        plist::Value::Integer(i) => i.to_string(),
        plist::Value::Boolean(b) => b.to_string(),
        plist::Value::Data(d) => format!("<{} bytes>", d.len()),
        other => format!("{other:?}"),
    }
}
