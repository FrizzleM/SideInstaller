//! Pipeline step 2 — pair with this iPhone, from this iPhone, with no computer
//! and no Bonjour.
//!
//! This is the second half of `tunnel_create_rppairing_multihost`
//! (`rust-core/vendor/idevice-ffi/src/tunnel_provider.rs`), which is the call
//! `DeviceConnection.connectRemotePairing` makes and therefore the path
//! SideInstaller actually takes on iOS 26:
//!
//! ```text
//! RSD :49152 → untrusted.tunnelservice → RemoteXPC → RemotePairingClient
//! ```
//!
//! `RemotePairingClient::connect` pair-*verifies* when the record it is given is
//! still good, and falls through to a full pair-*setup* when it is not. Setup
//! puts a PIN on this iPhone's screen, which the user types back in here.
//!
//! **Why this works where the brief said it could not.** The brief ruled
//! RPPairing out because iSH has no `NSNetService`, so it cannot advertise
//! `_remotepairing._tcp` — and concluded pairing had to go through lockdownd on
//! 62078. That reasoning holds only for the *host* role, where the device
//! discovers us. `RemotePairingClient` is the *client* role: it dials the
//! device's own tunnel service outbound, so nothing is ever advertised and no
//! multicast entitlement is needed. lockdownd on 62078, meanwhile, hangs up on
//! network clients before reading a byte (measured on device, 2026-08-27), so it
//! was never going to be the way in.

use std::path::{Path, PathBuf};
use std::time::Duration;

use idevice::remote_pairing::{RemotePairingClient, RpPairingFile};
use idevice::xpc::RemoteXpcClient;
use tokio::net::TcpStream;
use tokio::time::timeout;

use crate::fail::{Fail, Result, chain};
use crate::ui;

/// Pairing puts a prompt on the device and waits for a human, so it gets a much
/// longer budget than anything else in the pipeline.
const PAIR_TIMEOUT: Duration = Duration::from_secs(300);

pub struct Paired {
    pub path: PathBuf,
    /// False when an existing record pair-verified and no prompt was needed.
    pub freshly_paired: bool,
}

pub async fn run(host: &str, tunnel_service_port: u16, path: &Path) -> Result<Paired> {
    // Re-use an existing record rather than minting one. Pairing is interactive
    // and spends a slot on the device, and `RpPairingFile::generate` would mint
    // a fresh Ed25519 key pair every run — which silently invalidates the copy
    // any other app is holding. rust-core hit exactly this and now carries the
    // key pair across pairings; the same reasoning applies here.
    let existing = if path.exists() {
        match RpPairingFile::read_from_file(path).await {
            Ok(f) => {
                ui::info(&format!("re-using the pairing record at {}", path.display()));
                Some(f)
            }
            Err(e) => {
                ui::warn(&format!(
                    "the pairing record at {} could not be read, making a new one",
                    path.display()
                ));
                ui::detail(&chain(&e));
                None
            }
        }
    } else {
        None
    };
    let had_record = existing.is_some();
    let mut pairing_file = existing.unwrap_or_else(|| RpPairingFile::generate(crate::LABEL));

    ui::info(&format!("connecting to the tunnel service on port {tunnel_service_port} …"));
    let stream = timeout(
        Duration::from_secs(15),
        TcpStream::connect((host, tunnel_service_port)),
    )
    .await
    .map_err(|_| Fail::new(retry_advice(), "tunnel service connect timed out"))?
    .map_err(|e| Fail::new(retry_advice(), format!("tunnel service connect: {e}")))?;
    let _ = stream.set_nodelay(true);

    let mut conn = timeout(Duration::from_secs(30), RemoteXpcClient::new(stream))
        .await
        .map_err(|_| Fail::new(retry_advice(), "RemoteXPC setup timed out"))?
        .map_err(|e| Fail::new(retry_advice(), format!("RemoteXPC: {}", chain(&e))))?;

    timeout(Duration::from_secs(30), conn.do_handshake())
        .await
        .map_err(|_| Fail::new(retry_advice(), "RemoteXPC handshake timed out"))?
        .map_err(|e| Fail::new(retry_advice(), format!("RemoteXPC handshake: {}", chain(&e))))?;

    // The tunnel service sends an unsolicited root message before it will take
    // anything; the FFI reads and discards it, so we do too.
    timeout(Duration::from_secs(30), conn.recv_root())
        .await
        .map_err(|_| Fail::new(retry_advice(), "waiting for the tunnel service's greeting timed out"))?
        .map_err(|e| Fail::new(retry_advice(), format!("tunnel service greeting: {}", chain(&e))))?;
    ui::ok("tunnel service is talking");

    let mut client = RemotePairingClient::new(conn, crate::LABEL);

    if had_record {
        ui::info("checking whether the stored pairing record still works …");
    } else {
        println!();
        ui::info("This iPhone is about to show a pairing PIN.");
        ui::info("Unlock it, note the PIN, and type it in here.");
        println!();
    }

    timeout(PAIR_TIMEOUT, client.connect(&mut pairing_file, || read_pin()))
        .await
        .map_err(|_| {
            Fail::new(
                [
                    "Pairing timed out after five minutes.".to_string(),
                    String::new(),
                    "If no PIN appeared on screen, unlock this iPhone and try again with".to_string(),
                    "iSH in the foreground the whole time.".to_string(),
                ]
                .join("\n"),
                "RemotePairingClient::connect timed out",
            )
        })?
        .map_err(|e| {
            Fail::new(
                [
                    "This iPhone refused to pair.".to_string(),
                    String::new(),
                    "If a PIN appeared and was typed correctly, the likeliest cause is a".to_string(),
                    "stale record: delete the file below and run siboot again to pair from".to_string(),
                    "scratch.".to_string(),
                    String::new(),
                    format!("  {}", path.display()),
                ]
                .join("\n"),
                format!("RemotePairingClient::connect: {}", chain(&e)),
            )
        })?;

    if let Some(parent) = path.parent() {
        let _ = tokio::fs::create_dir_all(parent).await;
    }
    pairing_file
        .write_to_file(path)
        .await
        .map_err(|e| {
            Fail::new(
                format!("Paired, but the record could not be saved to {}.", path.display()),
                chain(&e),
            )
        })?;

    // A zero-byte file would pair-verify forever without saying why; rust-core
    // added the same guard after chasing an ENOENT that was really an empty file.
    let size = tokio::fs::metadata(path).await.map(|m| m.len()).unwrap_or(0);
    if size == 0 {
        return Err(Fail::new(
            format!("The pairing record written to {} is empty.", path.display()),
            "write_to_file produced a zero-byte file",
        ));
    }

    ui::ok(&format!("pairing record saved — {} ({size} bytes)", path.display()));
    Ok(Paired { path: path.to_path_buf(), freshly_paired: !had_record })
}

fn retry_advice() -> String {
    [
        "Lost the connection to this iPhone's tunnel service part-way through.".to_string(),
        String::new(),
        "The usual cause is iSH being suspended: iOS gives it a second or two after".to_string(),
        "it leaves the foreground. Keep it on screen and run siboot again.".to_string(),
    ]
    .join("\n")
}

/// Read the PIN the device is showing.
///
/// Echoed, unlike the Apple ID password in step 4: it is displayed on the
/// screen next to the user, is useless once pairing completes, and typing a
/// 6-digit code blind invites a retry that costs another prompt.
async fn read_pin() -> String {
    tokio::task::spawn_blocking(|| {
        use std::io::{BufRead, Write};
        print!("      PIN shown on this iPhone: ");
        let _ = std::io::stdout().flush();
        let mut line = String::new();
        let _ = std::io::stdin().lock().read_line(&mut line);
        line.trim().to_string()
    })
    .await
    .unwrap_or_default()
}
