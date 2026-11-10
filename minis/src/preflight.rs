//! Step 1: is everything the later steps need actually here?
//!
//! Each check names what to change when it fails. Pairing needs Minis's
//! Bonjour bridge, not the loopback VPN; everything after pairing needs the VPN,
//! so for `siboot pair` an unreachable iPhone is only a warning.

use std::net::SocketAddr;
use std::time::Duration;

use idevice::remote_pairing::{RemotePairingClient, RpPairingSocket};
use tokio::net::TcpStream;
use tokio::time::timeout;

use crate::bridge::{Bridge, BridgeError, PAIRABLE_HOST_TYPE};
use crate::fail::{chain, Fail, Result};
use crate::{ui, Advertiser, Args, Command};

/// What the checks found, for the steps after them.
pub struct Ready {
    /// Notifications from Minis are allowed, so the pairing code can be shown
    /// over Settings.
    pub notifications: bool,
    /// This iPhone answered RPPairing at the VPN address.
    pub device_reachable: bool,
}

pub async fn run(bridge: &Bridge, args: &Args) -> Result<Ready> {
    let mut ready = Ready {
        notifications: false,
        device_reachable: false,
    };

    if args.advertiser == Advertiser::Minis {
        check_bonjour(bridge).await?;
        ready.notifications = check_notifications(bridge).await;
    }

    // Pairing and the tunnel stay on this iPhone; sign-in and the download don't.
    if matches!(args.command, Command::All | Command::Check) {
        check_online(args).await?;
    }

    match probe(args.device).await {
        Ok(found) => {
            ready.device_reachable = true;
            ui::ok(&format!(
                "this iPhone answers on {} (RPPairing, wire protocol {})",
                args.device, found.wire_version
            ));
            if let Some(name) = found.name {
                ui::detail(&format!("it calls itself \"{name}\""));
            }
        }
        Err(problem) if args.command == Command::Pair => {
            ui::warn(&format!(
                "{} Pairing works without it, but nothing after pairing does.",
                problem.advice
            ));
            ui::detail(&problem.raw);
        }
        Err(problem) => return Err(problem),
    }
    Ok(ready)
}

/// `minis-bonjour` is here and may advertise a pairable host.
async fn check_bonjour(bridge: &Bridge) -> Result<()> {
    let types = bridge.bonjour_types().await.map_err(|e| match e {
        BridgeError::Missing(_) => Fail::new(
            "This isn't Open Minis, or its build has no minis-bonjour command. Run siboot in \
             Open Minis's terminal (Minis › Settings › Terminal), on its TestFlight build from late \
             October 2026 or later.",
            e.to_string(),
        ),
        other => Fail::new("Minis's Bonjour bridge didn't answer.", other.to_string()),
    })?;
    if !types.declares(PAIRABLE_HOST_TYPE) {
        return Err(Fail::new(
            "This Minis build doesn't declare _remotepairing-pairable-host._tcp, so iOS won't let it \
             advertise a pairing host. Update Open Minis.",
            format!("declared: {}", types.types.join(", ")),
        ));
    }
    ui::ok("Minis may advertise a pairing host (_remotepairing-pairable-host._tcp is declared)");
    ui::detail(&format!(
        "{} declared types, {}",
        types.types.len(),
        if types.restricted {
            "restricted to that list"
        } else {
            "any type allowed"
        }
    ));

    match bridge.bonjour_list().await {
        Ok(listing) => {
            if listing.app_in_background {
                ui::warn("Minis reports being in the background. Keep it on screen until pairing starts.");
            }
            // Another pairable host, left by an earlier run or pair_host, would
            // put a second "Pair with …" entry in Settings that leads nowhere.
            for advert in listing
                .advertisements
                .iter()
                .filter(|a| a.is_pairable_host())
            {
                ui::info(&format!(
                    "withdrawing a pairing advertisement left from before ({})",
                    advert.name
                ));
                if let Err(e) = bridge.stop_advert(&advert.id).await {
                    ui::detail(&format!("couldn't withdraw {}: {e}", advert.id));
                }
            }
        }
        Err(e) => ui::detail(&format!("minis-bonjour list failed: {e}")),
    }
    Ok(())
}

/// Whether the pairing code can reach the user over Settings as a notification.
async fn check_notifications(bridge: &Bridge) -> bool {
    match bridge.notification_status().await {
        Ok(status) => match status.as_str() {
            "authorized" | "provisional" | "ephemeral" => {
                ui::ok("Minis may show notifications, so the pairing code will show over Settings");
                true
            }
            "not_determined" => {
                ui::info("Minis will ask to send notifications when the code is ready. Allow it:");
                ui::info("the code then shows over Settings.");
                // Scheduling asks for permission, so a notification may still work.
                true
            }
            _ => {
                ui::warn(
                    "Notifications from Minis are off, so you'll have to switch back to Minis",
                );
                ui::warn(
                    "to read the pairing code (or turn them on: Settings › Notifications › Minis).",
                );
                false
            }
        },
        Err(e) => {
            ui::detail(&format!("apple-notification settings failed: {e}"));
            false
        }
    }
}

/// GitHub (the IPA) and Apple's sign-in server answer over TLS. Apple's
/// `gsa.apple.com` chains to Apple Root CA, which Alpine's bundle lacks, so it's
/// trusted here as isideload's GrandSlam client trusts it.
async fn check_online(args: &Args) -> Result<()> {
    let apple_root = reqwest::Certificate::from_der(isideload::sideload::cert_identity::APPLE_ROOT)
        .map_err(|e| Fail::new("Couldn't load Apple's root certificate.", e.to_string()))?;
    let client = reqwest::Client::builder()
        .user_agent(format!("siboot/{}", crate::VERSION))
        .timeout(Duration::from_secs(20))
        .add_root_certificate(apple_root)
        .build()
        .map_err(|e| Fail::new("Couldn't start an HTTPS client.", e.to_string()))?;

    let downloads = args
        .ipa
        .as_deref()
        .is_none_or(|ipa| ipa.starts_with("http"));
    if downloads {
        let url = args.ipa.as_deref().unwrap_or(crate::sign::RELEASE_IPA);
        match client.head(url).send().await {
            Ok(r) if r.status().is_success() => {
                ui::ok("GitHub answers, and the SideInstaller release is there")
            }
            Ok(r) => ui::warn(&format!(
                "GitHub answered {} for the SideInstaller release.",
                r.status()
            )),
            Err(e) => {
                return Err(Fail::new(
                    "Couldn't reach GitHub, where SideInstaller is downloaded from. Check the \
                     internet connection.",
                    crate::error_text::error_text(&e),
                ))
            }
        }
    }
    // Any HTTP answer proves DNS, the route and the certificate chain.
    match client
        .get("https://gsa.apple.com/grandslam/GsService2/lookup")
        .send()
        .await
    {
        Ok(_) => ui::ok("Apple's sign-in server answers"),
        Err(e) => {
            return Err(Fail::new(
                "Couldn't reach Apple's sign-in server (gsa.apple.com). Check the internet \
                 connection.",
                crate::error_text::error_text(&e),
            ))
        }
    }
    Ok(())
}

pub struct Found {
    pub wire_version: i64,
    pub name: Option<String>,
}

/// Ask the iPhone's RPPairing listener for its handshake, as the first message
/// of a connection does. A reply proves the VPN route, Developer Mode and the
/// service all at once.
pub async fn probe(addr: SocketAddr) -> Result<Found> {
    let stream = match timeout(Duration::from_secs(8), TcpStream::connect(addr)).await {
        Ok(Ok(s)) => s,
        Ok(Err(e)) => return Err(unreachable(addr, &e)),
        Err(_) => {
            return Err(Fail::new(
                format!(
                    "Nothing answered at {addr}. Connect LocalDevVPN (it shows Connected), and \
                     check Wi-Fi is on."
                ),
                "connect timed out after 8 s",
            ))
        }
    };
    let mut client = RemotePairingClient::new(RpPairingSocket::new(stream), "siboot");
    let reply = match timeout(Duration::from_secs(10), client.attempt_pair_verify()).await {
        Ok(Ok(reply)) => reply,
        Ok(Err(e)) => return Err(Fail::new(
            format!(
                "Something at {addr} took the connection but didn't answer as an iPhone. Turn on \
                     Developer Mode (Settings › Privacy & Security › Developer Mode) and check \
                     LocalDevVPN is the VPN that's on."
            ),
            chain(&e),
        )),
        Err(_) => return Err(Fail::new(
            format!(
                "The iPhone took the connection at {addr} but never answered. Restart LocalDevVPN."
            ),
            "handshake timed out after 10 s",
        )),
    };
    let wire_version = reply
        .as_dictionary()
        .and_then(|d| d.get("wireProtocolVersion"))
        .and_then(|v| v.as_signed_integer())
        .unwrap_or(0);
    let name = reply
        .as_dictionary()
        .and_then(|d| d.get("peerDeviceInfo"))
        .and_then(|v| v.as_dictionary())
        .and_then(|d| d.get("name"))
        .and_then(|v| v.as_string())
        .map(str::to_string);
    Ok(Found { wire_version, name })
}

fn unreachable(addr: SocketAddr, e: &std::io::Error) -> Fail {
    let advice = match e.raw_os_error() {
        // EPERM: iOS refused the route itself, which is what happens with no VPN
        // carrying it (or with the iPhone's own Wi-Fi address as the target).
        Some(1) => format!(
            "iOS won't let Minis reach {addr}. Connect LocalDevVPN (it shows Connected) and use \
             its address, 10.7.0.1."
        ),
        _ => match e.kind() {
            std::io::ErrorKind::ConnectionRefused => format!(
                "The iPhone refused the connection at {addr}. Turn on Developer Mode (Settings › \
                 Privacy & Security › Developer Mode), and check Wi-Fi is on."
            ),
            _ => format!("Couldn't reach {addr}. Connect LocalDevVPN, and check Wi-Fi is on."),
        },
    };
    Fail::new(advice, format!("{e} ({:?})", e.kind()))
}
