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
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::timeout;

use crate::fail::{Fail, Result, chain};
use crate::ui;

/// LocalDevVPN's default peer address. Measured on device: `lockdownd` and RSD
/// both answer here, while plain loopback returns EPERM — the sandbox denies a
/// non-native process loopback access to system services.
pub const DEFAULT_DEVICE_IP: &str = "10.7.0.1";
pub const LOCKDOWN_PORT: u16 = 62078;
/// RemoteServiceDiscovery. Probed only as a comparison in the failure path.
pub const RSD_PORT: u16 = 49152;

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
        .map_err(|e| chain(&e));

    let lockdown_type = match lockdown_type {
        Ok(t) => t,
        Err(raw) => {
            // The exchange failed after the connection came up, which is the
            // one case worth spending a round trip on: it is also exactly what
            // a proxy that accepts eagerly and dials late looks like. Diagnose
            // now rather than asking for another run — the user is on a phone.
            ui::detail(&format!("QueryType failed: {raw}"));
            return Err(diagnose(host, raw).await);
        }
    };

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


/// Work out *why* a connection that opened could not complete one exchange.
///
/// The question this answers is whether anything was ever really behind the
/// port. A userspace VPN can complete the TCP handshake locally and only then
/// try to reach the service, so "connect succeeded" is not evidence that
/// lockdownd exists — and every measurement taken so far, including
/// checkpoint 1's, only ever connected.
///
/// The control is a port nothing serves. If that connects too, "open" means
/// nothing on this setup and the finding has to be re-read.
async fn diagnose(host: &str, raw: String) -> Fail {
    println!();
    ui::info("working out what is behind that port …");

    // Two arbitrary ports no iOS service listens on.
    let mut phantom = Vec::new();
    for control in [12345u16, 51763] {
        if connects(host, control).await {
            phantom.push(control);
        }
    }
    let accepts_anything = !phantom.is_empty();

    if accepts_anything {
        ui::warn(&format!(
            "{host}:{} connected too, and nothing serves that port",
            phantom.iter().map(|p| p.to_string()).collect::<Vec<_>>().join(" and ")
        ));
    } else {
        ui::detail("control ports were refused, so an open port does mean a live service");
    }

    for (label, port) in [("lockdownd", LOCKDOWN_PORT), ("RSD", RSD_PORT)] {
        match exchange(host, port).await {
            Ok(outcome) => ui::info(&format!("{host}:{port} ({label}) — {outcome}")),
            Err(e) => ui::info(&format!("{host}:{port} ({label}) — {e}")),
        }
    }

    let advice = if accepts_anything {
        [
            format!("LocalDevVPN accepted a connection to {host}:{LOCKDOWN_PORT}, but it also"),
            "accepts connections to ports nothing serves — so the port being open".to_string(),
            "never meant lockdownd was listening. Writing to it is what fails.".to_string(),
            String::new(),
            "The likely reading is that lockdownd is not accepting network connections".to_string(),
            "on this iOS version: it answers over USB until wireless debugging is".to_string(),
            "enabled, and enabling that needs a session, which needs a pair record.".to_string(),
            String::new(),
            "That is the case siboot cannot pair its way out of. If it holds, a pairing".to_string(),
            "file has to be made on a computer once and imported — which is the thing".to_string(),
            "this tool exists to avoid, so it is worth confirming before accepting it.".to_string(),
        ]
        .join("\n")
    } else {
        [
            format!("Something is listening at {host}:{LOCKDOWN_PORT}, but it closed the"),
            "connection instead of answering a lockdown QueryType.".to_string(),
            String::new(),
            "If LocalDevVPN is connected and its tunnel address is still".to_string(),
            format!("{DEFAULT_DEVICE_IP}, this is lockdownd refusing a network client rather"),
            "than a configuration problem.".to_string(),
        ]
        .join("\n")
    };

    Fail::new(advice, raw)
}

async fn connects(host: &str, port: u16) -> bool {
    matches!(
        timeout(Duration::from_secs(5), TcpStream::connect((host, port))).await,
        Ok(Ok(_))
    )
}

/// Send one lockdown `QueryType` by hand and describe exactly what came back.
///
/// Hand-rolled rather than reusing `Idevice`, because the interesting part is
/// the part `idevice` abstracts away: whether the write lands, whether the
/// length prefix arrives, and whether the peer resets or simply closes.
async fn exchange(host: &str, port: u16) -> std::result::Result<String, String> {
    let mut stream = timeout(Duration::from_secs(5), TcpStream::connect((host, port)))
        .await
        .map_err(|_| "connect timed out".to_string())?
        .map_err(|e| format!("connect failed: {e}"))?;
    let _ = stream.set_nodelay(true);

    let body = query_type_plist();
    let mut frame = (body.len() as u32).to_be_bytes().to_vec();
    frame.extend_from_slice(&body);

    if let Err(e) = stream.write_all(&frame).await {
        return Ok(format!("write of {} bytes failed: {e}", frame.len()));
    }
    if let Err(e) = stream.flush().await {
        return Ok(format!("flush failed: {e}"));
    }

    let mut prefix = [0u8; 4];
    match timeout(Duration::from_secs(10), stream.read_exact(&mut prefix)).await {
        Err(_) => Ok(format!("wrote {} bytes, then no reply within 10s", frame.len())),
        Ok(Err(e)) if e.kind() == std::io::ErrorKind::UnexpectedEof => {
            Ok(format!("wrote {} bytes, then the peer closed without replying", frame.len()))
        }
        Ok(Err(e)) => Ok(format!("wrote {} bytes, then the read failed: {e}", frame.len())),
        Ok(Ok(_)) => {
            let len = u32::from_be_bytes(prefix);
            let mut buf = vec![0u8; len.min(512) as usize];
            match timeout(Duration::from_secs(10), stream.read_exact(&mut buf)).await {
                Ok(Ok(_)) => Ok(format!(
                    "replied with a {len}-byte message starting {:?}",
                    String::from_utf8_lossy(&buf[..buf.len().min(60)])
                )),
                _ => Ok(format!("announced {len} bytes but did not send them")),
            }
        }
    }
}

fn query_type_plist() -> Vec<u8> {
    let mut dict = plist::Dictionary::new();
    dict.insert("Label".into(), plist::Value::String(crate::LABEL.into()));
    dict.insert("Request".into(), plist::Value::String("QueryType".into()));
    let mut out = Vec::new();
    // Matches what `Idevice::send_plist` writes: XML, length-prefixed.
    plist::Value::Dictionary(dict)
        .to_writer_xml(&mut out)
        .expect("serialising a two-key plist cannot fail");
    out
}
