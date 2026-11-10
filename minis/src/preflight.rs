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
    /// Minis can advertise a pairing host, so siboot can pair here. Without it
    /// (Minis's App Store build so far) the pairing comes from rootshell.
    pub can_pair: bool,
    /// Notifications from Minis are allowed, so the pairing code can be shown
    /// over Settings.
    pub notifications: bool,
    /// This iPhone answered RPPairing at the VPN address.
    pub device_reachable: bool,
}

/// Where a pairing file made elsewhere (by `siboot-pair` in rootshell) turns
/// up once copied into Files › Minis › shared: `/home` in Minis's builds so
/// far, `/var/minis/shared` per its source.
const SHARED_PAIRING: &[&str] = &[
    "/home/rp_pairing_file.plist",
    "/var/minis/shared/rp_pairing_file.plist",
];

/// The rootshell route, for when Minis can't pair.
pub const ROOTSHELL_ROUTE: &str = "Pair with rootshell (App Store) first: turn on its Settings › \
     Location Diary Mode › Session Only, then run in its local shell \
     `curl -fsSLO https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/rootshell/bin/siboot-pair.wasm && ifconfig en0 | ./siboot-pair.wasm`. \
     Once it has paired, leave it running and run siboot here again: it asks for the \
     transfer code rootshell shows. (Or copy rp_pairing_file.plist from Files › rootshell \
     into Files › Minis › shared, and run siboot again.)";

pub async fn run(bridge: &Bridge, args: &Args) -> Result<Ready> {
    let mut ready = Ready {
        can_pair: args.advertiser != Advertiser::Minis,
        notifications: false,
        device_reachable: false,
    };

    import_shared_pairing(args);
    if args.advertiser == Advertiser::Minis {
        ready.can_pair = check_bonjour(bridge).await?;
        if ready.can_pair {
            ready.notifications = check_notifications(bridge).await;
        } else if args.pairing_path().exists() {
            ui::ok("siboot will use the pairing file made elsewhere, as this Minis can't pair");
        } else if fetch_from_rootshell(&args.pairing_path()).await? {
            ui::ok("siboot will use the pairing file from rootshell");
        } else {
            return Err(Fail::new(
                format!("This Minis build can't pair the iPhone with itself (it has no minis-bonjour). {ROOTSHELL_ROUTE}"),
                "no minis-bonjour, no pairing file",
            ));
        }
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

/// Where rootshell's siboot-pair offers the pairing file once it has paired,
/// on this iPhone's own loopback (rootshell/src/main.rs, `HANDOFF_PORT`).
const HANDOFF_PORT: u16 = 61207;

/// Take the pairing file siboot-pair is offering, if it is: the transfer code
/// it shows proves the request comes from the person at the iPhone, not
/// another app. False when nothing is offering one.
async fn fetch_from_rootshell(path: &std::path::Path) -> Result<bool> {
    use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};

    let addr = SocketAddr::from(([127, 0, 0, 1], HANDOFF_PORT));
    let connect = || timeout(Duration::from_secs(2), TcpStream::connect(addr));
    let Ok(Ok(mut stream)) = connect().await else {
        return Ok(false);
    };
    ui::ok("rootshell is offering the pairing file it made");
    for attempt in 1..=3 {
        let Some(typed) = ui::ask("Transfer code shown in rootshell: ") else {
            return Ok(false);
        };
        let code: String = typed.chars().filter(char::is_ascii_digit).collect();
        if attempt > 1 {
            stream = match connect().await {
                Ok(Ok(s)) => s,
                _ => {
                    return Err(Fail::new(
                        "rootshell stopped offering the pairing file.",
                        "",
                    ))
                }
            };
        }
        let raw =
            |e: std::io::Error| Fail::new("The hand-over from rootshell broke off.", e.to_string());
        stream
            .write_all(format!("SIBOOT1 {code}\n").as_bytes())
            .await
            .map_err(raw)?;
        let mut reader = BufReader::new(&mut stream);
        let mut answer = String::new();
        reader.read_line(&mut answer).await.map_err(raw)?;
        if let Some(len) = answer
            .trim()
            .strip_prefix("OK ")
            .and_then(|n| n.parse::<usize>().ok())
        {
            if len == 0 || len > 64 * 1024 {
                return Err(Fail::new(
                    "rootshell sent something that isn't a pairing file.",
                    answer,
                ));
            }
            let mut file = vec![0u8; len];
            reader.read_exact(&mut file).await.map_err(raw)?;
            if let Some(dir) = path.parent() {
                std::fs::create_dir_all(dir)
                    .map_err(|e| Fail::new("Couldn't save the pairing file.", e.to_string()))?;
            }
            std::fs::write(path, &file)
                .map_err(|e| Fail::new("Couldn't save the pairing file.", e.to_string()))?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600));
            }
            ui::ok(&format!(
                "took the pairing file from rootshell ({len} bytes)"
            ));
            return Ok(true);
        }
        ui::warn("That isn't the code rootshell shows.");
    }
    Err(Fail::new(
        "The transfer code didn't match. Run siboot again and type the code rootshell shows.",
        "",
    ))
}

/// Copy a pairing file from Minis's shared folder into `~/.siboot`, when one
/// is there and newer than the one siboot has (or siboot has none). Not when
/// `--pairing-file` names one.
fn import_shared_pairing(args: &Args) {
    if args.pairing_file.is_some() {
        return;
    }
    let target = args.pairing_path();
    let modified = |p: &std::path::Path| std::fs::metadata(p).and_then(|m| m.modified()).ok();
    let Some(source) = SHARED_PAIRING
        .iter()
        .map(std::path::Path::new)
        .filter(|p| p.is_file())
        .max_by_key(|p| modified(p))
    else {
        return;
    };
    if let (Some(have), Some(offered)) = (modified(&target), modified(source)) {
        if have >= offered {
            return;
        }
    }
    let copied = std::fs::read(source).and_then(|bytes| {
        if let Some(dir) = target.parent() {
            std::fs::create_dir_all(dir)?;
        }
        std::fs::write(&target, bytes)
    });
    match copied {
        Ok(()) => {
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = std::fs::set_permissions(&target, std::fs::Permissions::from_mode(0o600));
            }
            ui::ok(&format!(
                "took the pairing file from Minis › shared ({})",
                source.display()
            ));
        }
        Err(e) => ui::warn(&format!(
            "couldn't take the pairing file from {}: {e}",
            source.display()
        )),
    }
}

/// Whether `minis-bonjour` is here and may advertise a pairable host. False
/// when the command is missing or can't use the type; siboot then needs a
/// pairing file made elsewhere.
async fn check_bonjour(bridge: &Bridge) -> Result<bool> {
    let types = match bridge.bonjour_types().await {
        Ok(types) => types,
        Err(BridgeError::Missing(_)) => {
            ui::info(
                "this Minis build has no minis-bonjour, so it can't pair the iPhone with itself",
            );
            return Ok(false);
        }
        Err(other) => {
            return Err(Fail::new(
                "Minis's Bonjour bridge didn't answer.",
                other.to_string(),
            ))
        }
    };
    if !types.declares(PAIRABLE_HOST_TYPE) {
        ui::info(
            "this Minis build doesn't declare _remotepairing-pairable-host._tcp, so it can't pair",
        );
        ui::detail(&format!("declared: {}", types.types.join(", ")));
        return Ok(false);
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
    Ok(true)
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
        Ok(Err(e)) => {
            return Err(Fail::new(
                format!(
                "Something at {addr} took the connection but didn't answer as an iPhone. Turn on \
                     Developer Mode (Settings › Privacy & Security › Developer Mode) and check \
                     LocalDevVPN is the VPN that's on."
            ),
                chain(&e),
            ))
        }
        Err(_) => {
            return Err(Fail::new(
                format!(
                "The iPhone took the connection at {addr} but never answered. Restart LocalDevVPN."
            ),
                "handshake timed out after 10 s",
            ))
        }
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
