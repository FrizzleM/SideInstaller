//! Step 1: is everything the later steps need actually here?
//!
//! Each check names what to change when it fails: the internet, for sign-in
//! and the download, and LocalDevVPN, which carries everything to this iPhone.

use std::net::SocketAddr;
use std::time::Duration;

use idevice::remote_pairing::{RemotePairingClient, RpPairingSocket};
use tokio::net::TcpStream;
use tokio::time::timeout;

use crate::fail::{chain, Fail, Result};
use crate::{ui, Args, Command};

pub async fn run(args: &Args) -> Result<()> {
    // The tunnel stays on this iPhone; sign-in and the download don't.
    if args.command == Command::All || args.command == Command::Check {
        check_online(args).await?;
    }
    let found = probe(args.device).await?;
    ui::ok(&format!(
        "this iPhone answers on {} (RPPairing, wire protocol {})",
        args.device, found.wire_version
    ));
    if let Some(name) = found.name {
        ui::detail(&format!("it calls itself \"{name}\""));
    }
    Ok(())
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
