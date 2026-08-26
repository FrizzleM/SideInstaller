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
/// The decisive question is whether lockdownd closes because of what we sent,
/// or would have closed regardless. If it hangs up before reading a byte, it is
/// refusing network clients outright and no message we could craft would help —
/// that is the deadlock `NOTES.md` predicted, where enabling wireless lockdown
/// needs a session, a session needs a pair record, and the pair record needs
/// the connection that was just refused.
///
/// If instead it waits for input and only then closes, the message is the
/// problem, and a message is something we can change.
///
/// Each experiment is one connection, so nothing here depends on the state left
/// by the one before it.
async fn diagnose(host: &str, raw: String) -> Fail {
    println!();
    ui::info("working out what is behind that port …");

    // Control: two ports no iOS service listens on. If these connect, an open
    // port would prove nothing and every earlier measurement would need
    // re-reading. (On 2026-08-27 they were refused, so it does prove something.)
    let mut phantom = Vec::new();
    for control in [12345u16, 51763] {
        if connects(host, control).await {
            phantom.push(control.to_string());
        }
    }
    if phantom.is_empty() {
        ui::detail("control ports refused — an open port here does mean a live service");
    } else {
        ui::warn(&format!(
            "ports {} connected too, and nothing serves those",
            phantom.join(" and ")
        ));
    }

    // The experiment that decides the outcome.
    let silent = listen_only(host, LOCKDOWN_PORT).await;
    ui::info(&format!("62078, saying nothing  — {silent}"));

    let closes_unprompted = matches!(silent, Silence::ClosedBy(_));

    for (what, outcome) in [
        ("XML QueryType, one write ", write_then_read(host, LOCKDOWN_PORT, Framing::XmlOneWrite).await),
        ("XML QueryType, two writes", write_then_read(host, LOCKDOWN_PORT, Framing::XmlTwoWrites).await),
        ("binary plist QueryType   ", write_then_read(host, LOCKDOWN_PORT, Framing::Binary).await),
    ] {
        ui::info(&format!("62078, {what} — {outcome}"));
    }

    ui::info(&format!("49152, saying nothing  — {}", listen_only(host, RSD_PORT).await));

    let advice = if closes_unprompted {
        [
            format!("lockdownd is listening at {host}:{LOCKDOWN_PORT}, but it hangs up before"),
            "reading anything at all — so it is refusing network clients outright,".to_string(),
            "not rejecting the message siboot sent.".to_string(),
            String::new(),
            "That is the deadlock this approach had to clear: lockdownd answers over".to_string(),
            "USB until wireless debugging is switched on, switching it on needs a".to_string(),
            "session, and a session needs a pair record — which is what could not be".to_string(),
            "minted here.".to_string(),
            String::new(),
            "If this holds, a pairing file has to be made once on a computer and".to_string(),
            "imported. Worth confirming before accepting it, because it is the one".to_string(),
            "thing this tool exists to avoid.".to_string(),
        ]
        .join("\n")
    } else {
        [
            format!("lockdownd at {host}:{LOCKDOWN_PORT} waits for input and then closes without"),
            "answering — so it is reading what siboot sent and rejecting it, rather".to_string(),
            "than refusing network clients on principle.".to_string(),
            String::new(),
            "That is the more tractable of the two outcomes: the message is something".to_string(),
            "that can be changed. Send the lines above.".to_string(),
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

enum Silence {
    /// The peer hung up on its own, this long after the connection opened.
    ClosedBy(Duration),
    StayedOpen,
    Failed(String),
}

impl std::fmt::Display for Silence {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Silence::ClosedBy(d) => write!(f, "it closed after {d:?} without us writing a byte"),
            Silence::StayedOpen => write!(f, "it stayed open, waiting for input"),
            Silence::Failed(e) => write!(f, "{e}"),
        }
    }
}

/// Connect and read without ever writing.
async fn listen_only(host: &str, port: u16) -> Silence {
    let mut stream = match timeout(Duration::from_secs(5), TcpStream::connect((host, port))).await {
        Ok(Ok(s)) => s,
        Ok(Err(e)) => return Silence::Failed(format!("connect failed: {e}")),
        Err(_) => return Silence::Failed("connect timed out".into()),
    };
    let started = std::time::Instant::now();
    let mut buf = [0u8; 64];
    match timeout(Duration::from_secs(5), stream.read(&mut buf)).await {
        // A clean EOF, or a reset, both mean the peer ended it unprompted.
        Ok(Ok(0)) => Silence::ClosedBy(started.elapsed()),
        Ok(Ok(n)) => Silence::Failed(format!("it spoke first, sending {n} bytes")),
        // A reset is the peer ending it too, just less politely.
        Ok(Err(e)) if e.kind() == std::io::ErrorKind::ConnectionReset => {
            Silence::ClosedBy(started.elapsed())
        }
        Ok(Err(e)) => Silence::Failed(format!("read failed: {e}")),
        Err(_) => Silence::StayedOpen,
    }
}

enum Framing {
    /// Length prefix and body in a single write.
    XmlOneWrite,
    /// Prefix, then body — what `Idevice::send_plist` does.
    XmlTwoWrites,
    /// Same request, serialised as a binary plist. lockdownd accepts both, so a
    /// difference here would point at the XML rather than the protocol.
    Binary,
}

async fn write_then_read(host: &str, port: u16, framing: Framing) -> String {
    let mut stream = match timeout(Duration::from_secs(5), TcpStream::connect((host, port))).await {
        Ok(Ok(s)) => s,
        Ok(Err(e)) => return format!("connect failed: {e}"),
        Err(_) => return "connect timed out".into(),
    };
    let _ = stream.set_nodelay(true);

    let body = match framing {
        Framing::Binary => query_type_plist(true),
        _ => query_type_plist(false),
    };
    let prefix = (body.len() as u32).to_be_bytes();

    let write = async {
        match framing {
            Framing::XmlTwoWrites => {
                stream.write_all(&prefix).await?;
                stream.write_all(&body).await?;
            }
            _ => {
                let mut frame = prefix.to_vec();
                frame.extend_from_slice(&body);
                stream.write_all(&frame).await?;
            }
        }
        stream.flush().await
    };
    if let Err(e) = write.await {
        return format!("write of {} bytes failed: {e}", 4 + body.len());
    }

    let mut got = [0u8; 4];
    match timeout(Duration::from_secs(10), stream.read_exact(&mut got)).await {
        Err(_) => format!("wrote {} bytes, then silence for 10s", 4 + body.len()),
        Ok(Err(e)) if e.kind() == std::io::ErrorKind::UnexpectedEof => {
            format!("wrote {} bytes, then it closed cleanly", 4 + body.len())
        }
        Ok(Err(e)) => format!("wrote {} bytes, then the read failed: {e}", 4 + body.len()),
        Ok(Ok(_)) => {
            let len = u32::from_be_bytes(got);
            let mut buf = vec![0u8; (len as usize).min(400)];
            match timeout(Duration::from_secs(10), stream.read_exact(&mut buf)).await {
                Ok(Ok(_)) => format!(
                    "REPLIED with {len} bytes: {}",
                    String::from_utf8_lossy(&buf[..buf.len().min(200)])
                ),
                _ => format!("announced {len} bytes but sent none"),
            }
        }
    }
}

fn query_type_plist(binary: bool) -> Vec<u8> {
    let mut dict = plist::Dictionary::new();
    dict.insert("Label".into(), plist::Value::String(crate::LABEL.into()));
    dict.insert("Request".into(), plist::Value::String("QueryType".into()));
    let value = plist::Value::Dictionary(dict);
    let mut out = Vec::new();
    if binary {
        value.to_writer_binary(&mut out).expect("serialising two keys cannot fail");
    } else {
        value.to_writer_xml(&mut out).expect("serialising two keys cannot fail");
    }
    out
}
