//! Step 2: pair this iPhone with itself, as a pairable host.
//!
//! From iOS 27 a device can start pairing itself. A host advertises
//! `_remotepairing-pairable-host._tcp`; Settings › Privacy & Security › Developer
//! Mode lists it as "Pair with …"; tapping that has the device dial the
//! advertised port and drive pair-setup, with the roles flipped: the device is
//! the rppairing "host", and we answer as the accessory and show the PIN.
//!
//! Dialling the device instead (`RemotePairingClient`, which ../ish-bootstrap
//! and ../ashell tried) can only pair-*verify*: the device answers
//! `allowsPairSetup: false` and hangs up on `setupManualPairing`. Taking the
//! host role needs a Bonjour advertisement, which Minis's `minis-bonjour`
//! makes from the app. SideInstaller does the same in `PairingController` and
//! rust-core's `pairing.rs`, which this follows: the same idevice responder,
//! the same reuse of the host identity, the same stage time limits.

use std::future::Future;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::time::Duration;

use idevice::remote_pairing::{
    PairableHost, PairableHostInfo, PeerDevice, RpPairingFile, RpPairingSocket,
};
use tokio::net::TcpListener;
use tokio::sync::{mpsc, oneshot};

use crate::bridge::{Advertisement, Bridge, BridgeError, PAIRABLE_HOST_TYPE};
use crate::fail::{chain, Fail, Result};
use crate::keepalive::{self, KeepAlive};
use crate::preflight::Ready;
use crate::{tunnel, ui, Advertiser, Args};

/// What the device reads off the host. iOS treats a pairable host as a
/// computer, so the model stays a Mac's, as rust-core and StikPair send.
const HOST_MODEL: &str = "Mac17,7";

/// How long each stage may take.
#[derive(Clone, Copy, Debug)]
pub struct Limits {
    /// For the user to find the entry in Settings and tap it.
    pub device: Duration,
    /// From the device connecting until it asks for a code. In SideInstaller's
    /// logs both arrive within 40 ms of each other.
    pub code_request: Duration,
    /// From the code being shown until pairing has finished.
    pub code_entry: Duration,
}

pub const LIMITS: Limits = Limits {
    device: Duration::from_secs(10 * 60),
    code_request: Duration::from_secs(30),
    code_entry: Duration::from_secs(5 * 60),
};

/// Connections tried before giving up: a stray or aborted one, a mistyped
/// code, and the one that pairs.
const MAX_ATTEMPTS: u32 = 3;

/// Pair unless the saved pairing file still works, then check the result over
/// LocalDevVPN when it's there.
pub async fn ensure(bridge: &Bridge, args: &Args, ready: &Ready, path: &Path) -> Result<()> {
    if path.exists() && !args.repair {
        if ready.device_reachable {
            match tunnel::verify(args.device, path).await {
                Ok(()) => {
                    ui::ok(&format!(
                        "this iPhone still trusts the pairing file at {}",
                        path.display()
                    ));
                    return Ok(());
                }
                Err(f) => {
                    ui::info(
                        "this iPhone doesn't accept the saved pairing file any more; pairing again",
                    );
                    ui::detail(&f.raw);
                }
            }
        } else {
            ui::info("the saved pairing file can't be checked without LocalDevVPN; pairing again");
        }
    }

    let identity = Identity::load(path, &args.home, &args.host_name).await;
    let setup = HostSetup {
        bridge: bridge.clone(),
        advertiser: args.advertiser,
        name: args.host_name.clone(),
        keepalive_dir: (args.keepalive && args.advertiser == Advertiser::Minis)
            .then(|| args.home.clone()),
        notify: ready.notifications,
        limits: LIMITS,
        pin_hook: None,
    };
    let listener = TcpListener::bind(SocketAddr::new(bind_address(args.advertiser), 0))
        .await
        .map_err(|e| Fail::new("Couldn't open a port to listen on.", e.to_string()))?;
    let paired = run_host(listener, setup, identity, path, &args.home).await?;
    ui::ok(&format!("paired with {} ({})", paired.name, paired.model));

    if ready.device_reachable {
        tunnel::verify(args.device, path).await.map_err(|f| {
            Fail::new(
                format!(
                    "Paired, but the new pairing doesn't work through {}: {}",
                    args.device, f.advice
                ),
                f.raw,
            )
        })?;
        ui::ok("this iPhone accepts the new pairing through LocalDevVPN");
    }
    Ok(())
}

/// Minis forwards to the shell over loopback, so nothing else needs to reach
/// the port. A Mac advertising with dns-sd is dialled over Wi-Fi, by IPv4 or
/// IPv6, and `::` takes both there.
fn bind_address(advertiser: Advertiser) -> IpAddr {
    match advertiser {
        Advertiser::DnsSd => IpAddr::V6(Ipv6Addr::UNSPECIFIED),
        Advertiser::Minis | Advertiser::None => IpAddr::V4(Ipv4Addr::LOCALHOST),
    }
}

/// The host identity, kept between runs.
///
/// A new key pair each run would invalidate every copy of the pairing file
/// already handed to other apps (SideInstaller included), and a new altIRK
/// would change the advertised `authTag`, so a device that paired before
/// wouldn't recognise the host. rust-core keeps both for the same reasons.
pub struct Identity {
    pub file: RpPairingFile,
    pub alt_irk: Option<[u8; 16]>,
}

impl Identity {
    pub async fn load(path: &Path, home: &Path, name: &str) -> Self {
        let file = match RpPairingFile::read_from_file(path).await {
            Ok(mut existing) => {
                // That was the device's altIRK; the next device brings its own.
                existing.alt_irk = None;
                ui::detail("reusing the host key pair from the saved pairing file");
                existing
            }
            Err(_) => {
                let mut file = RpPairingFile::generate(name);
                // `generate` derives the identifier from the name, the same for
                // every siboot; a random one keeps this host's records apart.
                file.identifier = uuid::Uuid::new_v4().to_string().to_uppercase();
                file
            }
        };
        let alt_irk = std::fs::read_to_string(alt_irk_path(home))
            .ok()
            .and_then(|hex| parse_alt_irk(hex.trim()));
        Self { file, alt_irk }
    }
}

fn alt_irk_path(home: &Path) -> PathBuf {
    home.join("host_alt_irk")
}

/// How to run one host.
pub struct HostSetup {
    pub bridge: Bridge,
    pub advertiser: Advertiser,
    /// "Pair with <name>".
    pub name: String,
    /// Play silence from here while waiting (Minis only).
    pub keepalive_dir: Option<PathBuf>,
    /// Post the code as a Minis notification.
    pub notify: bool,
    pub limits: Limits,
    /// Tests: receives the code as it's shown.
    pub pin_hook: Option<mpsc::UnboundedSender<String>>,
}

pub struct Paired {
    pub name: String,
    pub model: String,
    #[allow(dead_code)]
    pub udid: String,
}

/// Advertise `listener`, wait for the device, pair, and write the pairing file
/// to `out_path`. The advertisement and the keep-alive end with this call,
/// however it ends.
pub async fn run_host(
    listener: TcpListener,
    setup: HostSetup,
    identity: Identity,
    out_path: &Path,
    home: &Path,
) -> Result<Paired> {
    let Identity {
        file: mut pairing_file,
        alt_irk,
    } = identity;
    let port = listener
        .local_addr()
        .map_err(|e| Fail::new("Couldn't open a port to listen on.", e.to_string()))?
        .port();

    let mut host_info = PairableHostInfo::generate(setup.name.clone(), HOST_MODEL);
    if let Some(alt_irk) = alt_irk {
        host_info.alt_irk = alt_irk;
    }
    let service_id = pairing_file.identifier.clone();
    let txt = host_info.mdns_txt_records(&service_id);

    let published = publish(&setup, &service_id, port, &txt).await?;

    // Shown before the player opens: its sheet covers the terminal.
    instructions(&setup, &published);
    let keepalive = match &setup.keepalive_dir {
        Some(dir) => match KeepAlive::start(&setup.bridge, dir, keepalive::PAIRING_SECONDS).await {
            Ok(k) => {
                ui::detail("playing silence through apple-player, so iOS keeps Minis running");
                Some(k)
            }
            Err(e) => {
                ui::warn("Couldn't start the silent audio that keeps Minis running in the");
                ui::warn("background, so iOS may suspend it while you're in Settings.");
                ui::detail(&e);
                None
            }
        },
        None => None,
    };

    let deadline = tokio::time::Instant::now() + setup.limits.device;
    let mut attempt = 0;
    let peer: PeerDevice = loop {
        attempt += 1;
        let stream = match tokio::time::timeout_at(deadline, listener.accept()).await {
            Ok(Ok((stream, peer))) => {
                ui::info("Settings connected — waiting for it to ask for a code …");
                ui::detail(&format!("from {peer}"));
                stream
            }
            Ok(Err(e)) => {
                return Err(Fail::new(
                    "Couldn't accept the iPhone's connection.",
                    e.to_string(),
                ))
            }
            Err(_) => {
                return Err(Fail::new(
                    format!(
                        "Nobody tapped \"Pair with {}\" within {}. If it never showed in Settings, \
                         keep Wi-Fi on, check Minis has Local Network access (Settings › Privacy & \
                         Security › Local Network), and run siboot again.",
                        setup.name,
                        spoken(setup.limits.device)
                    ),
                    "no connection to the pairing port",
                ))
            }
        };

        let socket = RpPairingSocket::new_device(stream);
        let mut host = PairableHost::new(socket, host_info.clone());
        let (code_shown_tx, code_shown) = oneshot::channel();
        let (code_seen_tx, mut code_seen) = oneshot::channel::<()>();
        let bridge = setup.bridge.clone();
        let notify = setup.notify;
        let hook = setup.pin_hook.clone();
        let ended = {
            let conversation = host.accept(&mut pairing_file, move |pin: String| async move {
                ui::pin(&pin);
                if notify {
                    let (a, b) = pin.split_at(pin.len().min(3));
                    let body = format!("{a} {b} — type it into Settings");
                    tokio::spawn(async move {
                        if let Err(e) = bridge.notify("siboot pairing code", &body).await {
                            tracing::warn!("couldn't post the pairing code as a notification: {e}");
                        }
                    });
                }
                if let Some(hook) = hook {
                    let _ = hook.send(pin);
                }
                let _ = code_seen_tx.send(());
                let _ = code_shown_tx.send(());
            });
            within_limits(conversation, code_shown, setup.limits).await
        };
        // A stray or aborted connection, a mistyped code, a cancel in
        // Settings: the user can tap the entry again, and the advertisement is
        // still up, so the run waits for that rather than ending.
        let code_was_seen = code_seen.try_recv().is_ok();
        let (failure, note) = match ended {
            Ok(Ok(peer)) => break peer,
            // The code wasn't typed in time: waiting longer won't help.
            Err(timeout) if code_was_seen => return Err(timeout),
            Err(quiet) => (
                quiet,
                "That connection went quiet before asking for a code.",
            ),
            Ok(Err(e)) if !code_was_seen => (
                pairing_failed(&e),
                "That connection closed before asking for a code.",
            ),
            Ok(Err(e)) if is_wrong_code(&e) => (
                pairing_failed(&e),
                "That code didn't match. Tap the entry in Settings again for a new one.",
            ),
            Ok(Err(e)) => (
                pairing_failed(&e),
                "Pairing stopped before it finished. Tap the entry in Settings again.",
            ),
        };
        if attempt >= MAX_ATTEMPTS {
            return Err(failure);
        }
        ui::info(note);
        ui::detail(&failure.raw);
        ui::info("Still waiting …");
    };
    drop(listener);

    save(&pairing_file, out_path).await?;
    if let Err(e) = std::fs::write(alt_irk_path(home), hex::encode(host_info.alt_irk)) {
        ui::detail(&format!("couldn't keep the host altIRK: {e}"));
    }

    // Withdrawn now rather than at the end of the run: the entry must not
    // outlive the listener behind it.
    published.stop().await;
    if let Some(k) = keepalive {
        k.stop().await;
    }

    Ok(Paired {
        name: peer.name,
        model: peer.model,
        udid: peer.remotepairing_udid,
    })
}

fn pairing_failed(e: &idevice::IdeviceError) -> Fail {
    let advice = if is_wrong_code(e) {
        "The code didn't match. Run siboot again and type the new code exactly."
    } else {
        "Pairing didn't finish. Run siboot again, and tap the entry again in Settings."
    };
    Fail::new(advice, chain(e))
}

/// idevice's `SrpAuthFailed`: the client's proof didn't match the code.
fn is_wrong_code(e: &idevice::IdeviceError) -> bool {
    chain(e).to_ascii_lowercase().contains("srp")
}

/// What Settings should show, however it was advertised.
enum Published {
    Minis(Advertisement),
    DnsSd(tokio::process::Child),
    Nothing,
}

impl Published {
    async fn stop(self) {
        match self {
            Published::Minis(advert) => advert.stop().await,
            Published::DnsSd(mut child) => {
                let _ = child.kill().await;
            }
            Published::Nothing => {}
        }
    }
}

async fn publish(
    setup: &HostSetup,
    service_id: &str,
    port: u16,
    txt: &[(String, String)],
) -> Result<Published> {
    match setup.advertiser {
        Advertiser::Minis => {
            let advert = setup
                .bridge
                .advertise(PAIRABLE_HOST_TYPE, service_id, port, txt)
                .await
                .map_err(advertise_failed)?;
            let a = advert.advert().clone();
            // The device checks the instance name against the identifier.
            if a.name != service_id {
                advert.stop().await;
                return Err(Fail::new(
                    "Minis registered the pairing host under another name, which Settings won't \
                     pair with. Run siboot again.",
                    format!("asked for {service_id}, got {}", a.name),
                ));
            }
            ui::ok("advertising this iPhone's pairing host through Minis");
            ui::detail(&format!(
                "{} {} on Minis's port {} → port {port} here",
                PAIRABLE_HOST_TYPE,
                a.name,
                a.listener_port
                    .map(|p| p.to_string())
                    .unwrap_or_else(|| "?".into())
            ));
            if let Some(w) = a.warning {
                ui::detail(&format!("minis-bonjour: {w}"));
            }
            Ok(Published::Minis(advert))
        }
        Advertiser::DnsSd => {
            let mut cmd = tokio::process::Command::new("dns-sd");
            cmd.args([
                "-R",
                service_id,
                PAIRABLE_HOST_TYPE,
                "local",
                &port.to_string(),
            ]);
            cmd.args(txt.iter().map(|(k, v)| format!("{k}={v}")));
            let mut child = cmd
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .kill_on_drop(true)
                .spawn()
                .map_err(|e| Fail::new("Couldn't run dns-sd (it's on macOS).", e.to_string()))?;
            tokio::time::sleep(Duration::from_millis(500)).await;
            if let Ok(Some(status)) = child.try_wait() {
                return Err(Fail::new(
                    "dns-sd stopped straight away.",
                    status.to_string(),
                ));
            }
            ui::ok(&format!(
                "advertising {service_id} with dns-sd on port {port}"
            ));
            Ok(Published::DnsSd(child))
        }
        Advertiser::None => {
            ui::info(&format!(
                "not advertising; the record is {PAIRABLE_HOST_TYPE} {service_id} port {port}"
            ));
            for (k, v) in txt {
                ui::info(&format!("  {k}={v}"));
            }
            Ok(Published::Nothing)
        }
    }
}

fn advertise_failed(e: BridgeError) -> Fail {
    let advice = match e.code() {
        Some("authorization_denied") => {
            "Minis needs Local Network access to advertise: allow it in Settings › Privacy & \
             Security › Local Network › Minis, then run siboot again."
        }
        Some("disabled") => {
            "Turn on Local Discovery in Minis (its Settings › Network), then run siboot again."
        }
        Some("not_declared") => {
            "This Minis build can't advertise a pairing host. Update Open Minis."
        }
        _ => "Minis couldn't advertise the pairing host.",
    };
    Fail::new(advice, e.to_string())
}

fn instructions(setup: &HostSetup, published: &Published) {
    if let Published::Nothing = published {
        return;
    }
    println!();
    ui::info("Now, on this iPhone:");
    let mut steps = vec![
        "Open Settings › Privacy & Security › Developer Mode, and scroll to the bottom."
            .to_string(),
        format!(
            "Tap \"Pair with {}\". It can take a few seconds to appear.",
            setup.name
        ),
        "Enter your iPhone passcode, then the 6-digit code siboot shows.".to_string(),
    ];
    if matches!(published, Published::Minis(_)) {
        steps[2] = if setup.notify {
            "Enter your iPhone passcode, then the 6-digit code, which arrives as a Minis notification.".into()
        } else {
            "Enter your iPhone passcode, then the 6-digit code. With Minis's notifications off it's \
             only here, under the player."
                .into()
        };
    }
    ui::steps(&steps);
    if setup.keepalive_dir.is_some() {
        println!();
        ui::info("A player opens over this terminal next. It plays silence, which keeps Minis");
        ui::info("running while you're in Settings: leave it open, and go to Settings. siboot");
        ui::info("closes it when pairing is done.");
    }
    ui::info(&format!("Waiting up to {} …", spoken(setup.limits.device)));
}

/// idevice's conversation waits on the device without a limit:
/// `code_request` until the code is shown, then `code_entry` until it ends.
async fn within_limits<T>(
    conversation: impl Future<Output = T>,
    code_shown: oneshot::Receiver<()>,
    limits: Limits,
) -> Result<T> {
    tokio::pin!(conversation);
    tokio::select! {
        biased;
        done = &mut conversation => return Ok(done),
        // An error means the PIN callback was dropped uncalled, which only
        // happens as the conversation ends, so it disables this branch.
        Ok(()) = code_shown => {}
        () = tokio::time::sleep(limits.code_request) => {
            return Err(Fail::new(
                "The iPhone connected but stopped before asking for a code. Tap the entry in \
                 Settings again, or run siboot again.",
                format!("no code request within {}", spoken(limits.code_request)),
            ));
        }
    }
    tokio::time::timeout(limits.code_entry, conversation)
        .await
        .map_err(|_| {
            Fail::new(
                format!(
                    "The code wasn't entered within {}. Run siboot again for a new one.",
                    spoken(limits.code_entry)
                ),
                "code entry timed out",
            )
        })
}

/// Write the pairing file, readable by this user only: it holds the private key.
async fn save(file: &RpPairingFile, path: &Path) -> Result<()> {
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)
            .map_err(|e| Fail::new(format!("Couldn't create {}.", dir.display()), e.to_string()))?;
    }
    file.write_to_file(path).await.map_err(|e| {
        Fail::new(
            format!("Paired, but couldn't write {}.", path.display()),
            chain(&e),
        )
    })?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600));
    }
    let size = std::fs::metadata(path).map(|m| m.len()).unwrap_or(0);
    if size == 0 {
        return Err(Fail::new(
            format!("Paired, but {} came out empty.", path.display()),
            "zero-byte pairing file",
        ));
    }
    ui::detail(&format!(
        "pairing file written: {} ({size} bytes)",
        path.display()
    ));
    Ok(())
}

/// "30 seconds", "10 minutes".
fn spoken(d: Duration) -> String {
    let secs = d.as_secs();
    let (n, unit) = if secs >= 60 && secs.is_multiple_of(60) {
        (secs / 60, "minute")
    } else {
        (secs, "second")
    };
    format!("{n} {unit}{}", if n == 1 { "" } else { "s" })
}

fn parse_alt_irk(text: &str) -> Option<[u8; 16]> {
    let bytes = hex::decode(text).ok()?;
    bytes.try_into().ok()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fake_iphone;

    const QUICK: Limits = Limits {
        device: Duration::from_secs(20),
        code_request: Duration::from_secs(20),
        code_entry: Duration::from_secs(20),
    };

    fn temp_home(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("siboot-test-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    /// A whole pairing, the fake iPhone dialling the listener straight away,
    /// as Settings dials the advertised port.
    async fn pair_once(
        home: &Path,
        advertiser: Advertiser,
        bridge: Bridge,
    ) -> (Paired, fake_iphone::Outcome) {
        let out = home.join("rp_pairing_file.plist");
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let (pin_tx, mut pin_rx) = mpsc::unbounded_channel();
        let setup = test_setup(bridge, advertiser, Some(pin_tx));
        let identity = Identity::load(&out, home, "siboot test").await;
        let host = run_host(listener, setup, identity, &out, home);
        let phone = fake_iphone::pair(addr, async move { pin_rx.recv().await.unwrap() });
        let (host, phone) = tokio::join!(host, phone);
        (host.expect("host paired"), phone.expect("phone paired"))
    }

    fn test_setup(
        bridge: Bridge,
        advertiser: Advertiser,
        pin_hook: Option<mpsc::UnboundedSender<String>>,
    ) -> HostSetup {
        HostSetup {
            bridge,
            advertiser,
            name: "siboot test".into(),
            keepalive_dir: None,
            notify: false,
            limits: QUICK,
            pin_hook,
        }
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn a_device_pairs_and_the_file_holds_the_host_it_saw() {
        let home = temp_home("pair");
        let (paired, phone) = pair_once(&home, Advertiser::None, Bridge::default()).await;
        assert_eq!(paired.name, fake_iphone::NAME);
        assert_eq!(paired.model, fake_iphone::MODEL);

        let saved = RpPairingFile::read_from_file(home.join("rp_pairing_file.plist"))
            .await
            .unwrap();
        // The identity the device was given in M6 is the one on disk…
        assert_eq!(saved.identifier, phone.host_identifier);
        assert_eq!(saved.public_key_bytes(), phone.host_public_key);
        // …the device's altIRK came back in M5 and was kept…
        assert_eq!(saved.alt_irk.as_deref(), Some(&fake_iphone::ALT_IRK[..]));
        // …and the host's own altIRK was kept for the next run.
        assert_eq!(
            std::fs::read_to_string(home.join("host_alt_irk"))
                .unwrap()
                .len(),
            32
        );
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = std::fs::metadata(home.join("rp_pairing_file.plist"))
                .unwrap()
                .permissions()
                .mode();
            assert_eq!(mode & 0o777, 0o600);
        }
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn pairing_again_keeps_the_host_identity() {
        let home = temp_home("again");
        let (_, first) = pair_once(&home, Advertiser::None, Bridge::default()).await;
        let alt_irk = std::fs::read_to_string(home.join("host_alt_irk")).unwrap();
        let (_, second) = pair_once(&home, Advertiser::None, Bridge::default()).await;
        assert_eq!(first.host_identifier, second.host_identifier);
        assert_eq!(first.host_public_key, second.host_public_key);
        assert_eq!(
            std::fs::read_to_string(home.join("host_alt_irk")).unwrap(),
            alt_irk
        );
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn through_the_minis_bridge_the_advert_matches_and_is_withdrawn() {
        let home = temp_home("bridge");
        let stub = fake_iphone::minis_stub(&home);
        let (_, phone) = pair_once(&home, Advertiser::Minis, Bridge::in_dir(&stub)).await;

        let calls = std::fs::read_to_string(home.join("minis-calls.log")).unwrap();
        let lines: Vec<&str> = calls.lines().collect();
        let advertise = lines
            .iter()
            .find(|l| l.starts_with("minis-bonjour advertise"))
            .expect("advertised");
        let words: Vec<&str> = advertise.split(' ').collect();
        // advertise <type> <name> <port> key=value…
        assert_eq!(words[2], PAIRABLE_HOST_TYPE);
        assert_eq!(
            words[3], phone.host_identifier,
            "instance name is the identifier"
        );
        for key in [
            "name",
            "identifier",
            "authTag",
            "model",
            "flags",
            "ver",
            "minVer",
        ] {
            assert!(
                words.iter().any(|w| w.starts_with(&format!("{key}="))),
                "TXT {key} missing: {advertise}"
            );
        }
        assert!(words.contains(&format!("identifier={}", phone.host_identifier).as_str()));
        assert!(
            lines
                .iter()
                .any(|l| l.starts_with("minis-bonjour stop adv-1")),
            "the advertisement wasn't withdrawn: {calls}"
        );
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn a_wrong_code_gets_another_try() {
        let home = temp_home("wrong");
        let out = home.join("rp_pairing_file.plist");
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let (pin_tx, mut pin_rx) = mpsc::unbounded_channel();
        let setup = test_setup(Bridge::default(), Advertiser::None, Some(pin_tx));
        let identity = Identity::load(&out, &home, "siboot test").await;
        let host = run_host(listener, setup, identity, &out, &home);
        // A typo, then the entry tapped again and the new code typed.
        let phones = async move {
            let first = fake_iphone::pair(addr, async { "000000".to_string() }).await;
            let _ignored = pin_rx.recv().await.unwrap();
            let second = fake_iphone::pair(addr, async move { pin_rx.recv().await.unwrap() }).await;
            (first, second)
        };
        let (host, (first, second)) = tokio::join!(host, phones);
        assert!(first.is_err(), "the first phone typed a wrong code");
        second.expect("the second try paired");
        assert_eq!(
            host.expect("host paired on the second try").name,
            fake_iphone::NAME
        );
        assert!(out.exists());
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn three_wrong_codes_end_the_run_and_say_why() {
        let home = temp_home("wrong3");
        let out = home.join("rp_pairing_file.plist");
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let setup = test_setup(Bridge::default(), Advertiser::None, None);
        let identity = Identity::load(&out, &home, "siboot test").await;
        let host = run_host(listener, setup, identity, &out, &home);
        let phones = async move {
            for _ in 0..MAX_ATTEMPTS {
                let paired = fake_iphone::pair(addr, async { "000000".to_string() }).await;
                assert!(paired.is_err(), "a wrong code paired");
            }
        };
        let (host, ()) = tokio::join!(host, phones);
        let failure = host.err().expect("host should give up");
        assert!(
            failure.advice.contains("code didn't match"),
            "{}",
            failure.advice
        );
        assert!(!out.exists(), "no pairing file for a failed pairing");
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn a_connection_that_drops_before_the_code_doesnt_end_pairing() {
        let home = temp_home("stray");
        let out = home.join("rp_pairing_file.plist");
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        // Queued ahead of the phone, and gone before saying anything.
        drop(std::net::TcpStream::connect(addr).unwrap());
        let (pin_tx, mut pin_rx) = mpsc::unbounded_channel();
        let setup = test_setup(Bridge::default(), Advertiser::None, Some(pin_tx));
        let identity = Identity::load(&out, &home, "siboot test").await;
        let host = run_host(listener, setup, identity, &out, &home);
        let phone = fake_iphone::pair(addr, async move { pin_rx.recv().await.unwrap() });
        let (host, phone) = tokio::join!(host, phone);
        assert_eq!(
            host.expect("host paired after the stray connection").name,
            fake_iphone::NAME
        );
        phone.expect("phone paired");
        assert!(out.exists());
    }

    #[tokio::test]
    async fn nobody_connecting_ends_with_advice() {
        let home = temp_home("idle");
        let out = home.join("rp_pairing_file.plist");
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let setup = HostSetup {
            bridge: Bridge::default(),
            advertiser: Advertiser::None,
            name: "siboot test".into(),
            keepalive_dir: None,
            notify: false,
            limits: Limits {
                device: Duration::from_millis(200),
                ..QUICK
            },
            pin_hook: None,
        };
        let identity = Identity::load(&out, &home, "siboot test").await;
        let failure = run_host(listener, setup, identity, &out, &home)
            .await
            .err()
            .unwrap();
        assert!(
            failure.advice.contains("Nobody tapped"),
            "{}",
            failure.advice
        );
    }

    #[test]
    fn words_and_irks() {
        assert_eq!(spoken(LIMITS.device), "10 minutes");
        assert_eq!(spoken(LIMITS.code_request), "30 seconds");
        assert_eq!(spoken(Duration::from_secs(60)), "1 minute");
        assert_eq!(
            parse_alt_irk("00112233445566778899aabbccddeeff").unwrap()[15],
            0xff
        );
        assert!(parse_alt_irk("0011").is_none());
        assert!(parse_alt_irk("zz112233445566778899aabbccddeeff").is_none());
    }
}
