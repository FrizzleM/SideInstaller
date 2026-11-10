//! `siboot-pair`: siboot's pairing step, for rootshell's WASM runtime.
//!
//! Pairs this iPhone with itself from an App Store app. iOS 27 lists a host
//! in Settings › Privacy & Security › Developer Mode › "Pair with …" when it
//! advertises `_remotepairing-pairable-host._tcp`; the iPhone then dials it
//! and runs pair-setup, typing in a code the host shows. An app may only
//! advertise the Bonjour types its Info.plist declares, unless it has Apple's
//! multicast entitlement, which rootshell ("rootshell - Local Terminal &
//! SSH", App Store) has. rootshell runs WASI programs and lends them sockets,
//! so this one sends the advertisement as raw mDNS (`mdns.rs`) and answers
//! with idevice's own `PairableHost`, the responder SideInstaller uses.
//!
//! It writes `rp_pairing_file.plist` into rootshell's folder, the same file
//! `siboot pair` makes. siboot in Open Minis's App Store build (which can't
//! advertise) takes it from Minis's shared folder for the other six steps.

mod mdns;
mod rs;

use std::cell::Cell;
use std::net::Ipv4Addr;
use std::process::ExitCode;
use std::time::Duration;

use idevice::remote_pairing::{PairableHost, PairableHostInfo, PeerDevice, RpPairingFile, RpPairingSocket};

const VERSION: &str = env!("CARGO_PKG_VERSION");
/// iOS treats a pairable host as a computer, as rust-core and StikPair do.
const HOST_MODEL: &str = "Mac17,7";
/// Connections tried before giving up: a stray one, a mistyped code, the one that pairs.
const MAX_ATTEMPTS: u32 = 3;
const ALT_IRK_FILE: &str = "host_alt_irk";
/// Where `ifconfig en0 > ifconfig.txt` leaves the address for us.
const IFCONFIG_FILE: &str = "ifconfig.txt";
const INSTALL: &str =
    "wget -qO- https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/minis/install.sh | sh";

struct Args {
    ip: [u8; 4],
    name: String,
    port: Option<u16>,
    out: String,
    service: String,
}

fn usage() {
    println!(
        "siboot-pair {VERSION} — pairs this iPhone with itself, from rootshell.

USAGE
    ifconfig en0 > ifconfig.txt     (then)     ./siboot-pair.wasm [options]
    ifconfig en0 | ./siboot-pair.wasm [options]
    ./siboot-pair.wasm <this iPhone's Wi-Fi IP address> [options]

    It needs this iPhone's Wi-Fi address: from ifconfig.txt, piped, or as given
    (Settings › Wi-Fi › ⓘ next to your network › IP Address).
    Before running it, turn on rootshell's Settings › Location Diary Mode ›
    Session Only, which keeps rootshell running while you're in Settings.
    After pairing it hands the pairing file to siboot in Open Minis.

OPTIONS
    --name NAME   What Settings shows: \"Pair with NAME\" (default siboot).
    --port N      The port to listen on (default: a random one).
    --out FILE    Where to write the pairing file (default rp_pairing_file.plist).
    -h, --help    Show this message."
    );
}

fn parse_args() -> Result<Option<Args>, String> {
    let mut ip = None;
    let mut args = Args {
        ip: [0; 4],
        name: "siboot".into(),
        port: None,
        out: "rp_pairing_file.plist".into(),
        service: mdns::PAIRABLE_HOST_TYPE.into(),
    };
    let mut argv = std::env::args().skip(1);
    while let Some(arg) = argv.next() {
        let mut value = |flag: &str| argv.next().ok_or(format!("{flag} needs a value"));
        match arg.as_str() {
            "-h" | "--help" => return Ok(None),
            "-V" | "--version" => {
                println!("siboot-pair {VERSION}");
                std::process::exit(0);
            }
            "--name" => args.name = value("--name")?,
            "--out" => args.out = value("--out")?,
            "--port" => {
                args.port = Some(value("--port")?.parse().map_err(|_| "--port needs a number".to_string())?)
            }
            // Tests: announce another type, so a test run on a real network
            // doesn't offer itself to iPhones there.
            "--service" => args.service = value("--service")?,
            other if ip.is_none() && !other.starts_with('-') => {
                let parsed: Ipv4Addr = other
                    .parse()
                    .map_err(|_| format!("`{other}` isn't an IPv4 address like 192.168.1.20"))?;
                ip = Some(parsed.octets());
            }
            other => return Err(format!("unrecognised argument `{other}`")),
        }
    }
    args.ip = match ip {
        Some(ip) => ip,
        // `ifconfig en0 | ./siboot-pair.wasm`: rootshell has ifconfig, and a
        // WASM program can't find the address itself.
        None if !rs::is_tty(0) => {
            let mut piped = String::new();
            std::io::Read::read_to_string(&mut std::io::stdin(), &mut piped)
                .map_err(|e| format!("couldn't read what was piped in: {e}"))?;
            wifi_address(&piped).ok_or(
                "no IPv4 address in what was piped in. Is Wi-Fi on? Or give the address: \
                 Settings › Wi-Fi › ⓘ › IP Address",
            )?
        }
        // `ifconfig en0 > ifconfig.txt`, for shells that won't pipe into WASM.
        None if std::path::Path::new(IFCONFIG_FILE).exists() => {
            let saved = std::fs::read_to_string(IFCONFIG_FILE)
                .map_err(|e| format!("couldn't read {IFCONFIG_FILE}: {e}"))?;
            wifi_address(&saved).ok_or(format!(
                "no IPv4 address in {IFCONFIG_FILE}. Is Wi-Fi on? Run `ifconfig en0 > {IFCONFIG_FILE}` \
                 again, or give the address: Settings › Wi-Fi › ⓘ › IP Address"
            ))?
        }
        None => {
            return Err(format!(
                "give this iPhone's Wi-Fi address: run `ifconfig en0 > {IFCONFIG_FILE}` and then \
                 `./siboot-pair.wasm`, or `./siboot-pair.wasm <address>` with the one in \
                 Settings › Wi-Fi › ⓘ"
            ))
        }
    };
    Ok(Some(args))
}

/// The first non-loopback IPv4 address in `ifconfig` output (`inet A.B.C.D`),
/// or a bare address.
fn wifi_address(text: &str) -> Option<[u8; 4]> {
    let mut words = text.split_whitespace().peekable();
    while let Some(word) = words.next() {
        let candidate = if word == "inet" { words.peek().copied() } else { Some(word) };
        if let Some(ip) = candidate
            .and_then(|w| w.trim_start_matches("addr:").parse::<Ipv4Addr>().ok())
            .filter(|ip| !ip.is_loopback() && !ip.is_unspecified() && !ip.is_broadcast())
        {
            if word == "inet" || text.trim() == word {
                return Some(ip.octets());
            }
        }
    }
    None
}

fn main() -> ExitCode {
    let args = match parse_args() {
        Ok(Some(a)) => a,
        Ok(None) => {
            usage();
            return ExitCode::SUCCESS;
        }
        Err(problem) => {
            eprintln!("siboot-pair: {problem}");
            eprintln!("try `./siboot-pair.wasm --help`");
            return ExitCode::from(2);
        }
    };
    match run(&args) {
        Ok(()) => ExitCode::SUCCESS,
        Err(problem) => {
            println!();
            println!("Stopped: {problem}");
            ExitCode::FAILURE
        }
    }
}

fn run(args: &Args) -> Result<(), String> {
    println!("siboot-pair {VERSION} — pairs this iPhone with itself");
    println!();
    println!("Keep Location Diary on (rootshell › Settings › Location Diary Mode ›");
    println!("Session Only): it keeps rootshell running while you're in Settings.");
    println!();

    let (mut file, alt_irk) = identity(args)?;
    let mut info = PairableHostInfo::generate(args.name.clone(), HOST_MODEL);
    if let Some(alt_irk) = alt_irk {
        info.alt_irk = alt_irk;
    }
    let id = file.identifier.clone();
    let txt = info.mdns_txt_records(&id);

    let port = args.port.unwrap_or_else(random_port);
    let listener = rs::Socket::listen(port).map_err(|e| format!("couldn't listen on port {port}: {e}"))?;
    let host = format!("siboot-{}.local", id.split('-').next().unwrap_or("host").to_ascii_lowercase());
    let ad = mdns::Advert { service: &args.service, instance: &id, host: &host, ip: args.ip, port, txt: &txt };

    // A burst before waiting: nothing can be sent while blocked in accept.
    let announcement = mdns::announcement(&ad, mdns::TTL);
    let mut sent = 0;
    for i in 0..3 {
        match rs::Socket::send_datagram(&announcement, mdns::GROUP, mdns::PORT) {
            Ok(()) => sent += 1,
            Err(e) => println!("  announcement {} failed: {e}", i + 1),
        }
        std::thread::sleep(Duration::from_secs(1));
    }
    if sent == 0 {
        return Err("rootshell couldn't send the Bonjour announcement. Allow it Local Network \
                    access (Settings › Privacy & Security › Local Network › rootshell) and run \
                    this again."
            .into());
    }
    println!("OK announced \"Pair with {}\" on port {port}", args.name);
    println!();
    println!("Now, on this iPhone:");
    println!("  1. Open Settings › Privacy & Security › Developer Mode, and scroll to the bottom.");
    println!("  2. Tap \"Pair with {}\". It can take a few seconds to appear.", args.name);
    println!("  3. Enter your passcode, then the 6-digit code, which arrives as a rootshell");
    println!("     notification (it's also printed here).");
    println!("Waiting …");

    let peer = pair(&listener, &info, &mut file)?;
    drop(listener);

    std::fs::write(&args.out, file.to_bytes()).map_err(|e| format!("paired, but couldn't write {}: {e}", args.out))?;
    let _ = std::fs::write(ALT_IRK_FILE, hex::encode(info.alt_irk));
    // Withdraw the entry: nothing listens behind it now.
    let _ = rs::Socket::send_datagram(&mdns::announcement(&ad, 0), mdns::GROUP, mdns::PORT);

    println!();
    println!("OK paired with {} ({})", peer.name, peer.model);
    println!("OK pairing file saved: Files › rootshell › {}", args.out);
    hand_off(&file.to_bytes());
    Ok(())
}

/// Where siboot in Minis asks for the pairing file, on this iPhone's loopback.
/// Also in minis/src/preflight.rs.
const HANDOFF_PORT: u16 = 61207;
const HANDOFF_TRIES: u32 = 5;

/// Offer the pairing file to siboot in Open Minis, over this iPhone's own
/// loopback, until it has it. The transfer code keeps any other app on the
/// iPhone from taking it in the meantime: five wrong ones and the offer ends.
/// The file stays in Files › rootshell either way.
fn hand_off(pairing: &[u8]) {
    let listener = match rs::Socket::listen(HANDOFF_PORT) {
        Ok(l) => l,
        Err(e) => {
            println!("(couldn't offer the file to Minis directly: {e})");
            files_route();
            return;
        }
    };
    let code = transfer_code();
    println!();
    println!("Next, install SideInstaller with Open Minis (App Store). In Minis's terminal");
    println!("(Minis › Settings › Terminal), run:");
    println!();
    println!("    {INSTALL}");
    println!();
    println!("siboot takes the pairing file from here. When it asks, type the transfer code:");
    println!();
    println!("    {} {}", &code[..3], &code[3..]);
    println!();
    println!("Leave rootshell running until siboot has the file (Ctrl-C stops the offer).");
    let mut wrong = 0;
    while wrong < HANDOFF_TRIES {
        let Ok(conn) = listener.accept() else { break };
        let asked = conn.read_line(64).unwrap_or_default();
        let given: String = asked.trim_start_matches("SIBOOT1").chars().filter(char::is_ascii_digit).collect();
        if asked.starts_with("SIBOOT1") && given == code {
            let sent = conn
                .write_all(format!("OK {}\n", pairing.len()).as_bytes())
                .and_then(|()| conn.write_all(pairing));
            match sent {
                Ok(()) => {
                    println!("OK siboot has the pairing file. You can close rootshell's tab.");
                    return;
                }
                Err(e) => println!("  sending the file broke off ({e}); waiting for siboot to ask again"),
            }
        } else {
            wrong += 1;
            let _ = conn.write_all(b"NO\n");
            println!("  a wrong transfer code ({wrong} of {HANDOFF_TRIES})");
        }
    }
    println!("Stopped offering the file.");
    files_route();
}

fn files_route() {
    println!("Copy rp_pairing_file.plist from Files › rootshell into Files › Minis › shared, then");
    println!("run in Minis's terminal: {INSTALL}");
}

/// Six digits, not starting with 0 so it reads as a number.
fn transfer_code() -> String {
    let b = uuid::Uuid::new_v4();
    let n = u32::from_be_bytes(b.as_bytes()[..4].try_into().unwrap());
    format!("{}", 100_000 + n % 900_000)
}

/// Pair over up to `MAX_ATTEMPTS` connections: a stray one, a mistyped code
/// or a cancel in Settings leaves the entry up for another tap.
fn pair(listener: &rs::Socket, info: &PairableHostInfo, file: &mut RpPairingFile) -> Result<PeerDevice, String> {
    for attempt in 1..=MAX_ATTEMPTS {
        let stream = listener.accept().map_err(|e| format!("couldn't accept the connection: {e}"))?;
        println!("Settings connected — waiting for it to ask for a code …");
        let mut host = PairableHost::new(RpPairingSocket::new_device(stream), info.clone());
        let code_shown = Cell::new(false);
        let outcome = futures::executor::block_on(host.accept(file, |pin: String| {
            code_shown.set(true);
            show_code(&pin);
            async {}
        }));
        let error = match outcome {
            Ok(peer) => return Ok(peer),
            Err(e) => e.to_string(),
        };
        let wrong_code = error.to_ascii_lowercase().contains("srp");
        if attempt == MAX_ATTEMPTS {
            return Err(if wrong_code {
                "the code didn't match. Run this again and type the new code exactly.".into()
            } else {
                format!("pairing didn't finish ({error}). Run this again.")
            });
        }
        println!(
            "{}",
            match (code_shown.get(), wrong_code) {
                (false, _) => "That connection closed before asking for a code.",
                (true, true) => "That code didn't match. Tap the entry in Settings again for a new one.",
                (true, false) => "Pairing stopped before it finished. Tap the entry in Settings again.",
            }
        );
        println!("Still waiting …");
    }
    unreachable!("the loop returns on its last attempt")
}

/// The code, printed and posted as a notification: Ghostty, rootshell's
/// terminal, turns OSC 777 into one, also with rootshell in the background.
fn show_code(pin: &str) {
    let (a, b) = pin.split_at(pin.len().min(3));
    println!();
    println!("    Type this code into Settings:   {a} {b}");
    println!();
    print!("\x1b]777;notify;siboot pairing code;{a} {b} — type it into Settings\x07");
    use std::io::Write as _;
    let _ = std::io::stdout().flush();
}

/// The host identity from an earlier run, so a new pairing doesn't invalidate
/// copies of the file handed out before; else a new one.
fn identity(args: &Args) -> Result<(RpPairingFile, Option<[u8; 16]>), String> {
    let file = match std::fs::read(&args.out).ok().and_then(|b| RpPairingFile::from_bytes(&b).ok()) {
        Some(mut existing) => {
            existing.alt_irk = None;
            existing
        }
        None => {
            let mut fresh = RpPairingFile::generate(&args.name);
            fresh.identifier = uuid::Uuid::new_v4().to_string().to_uppercase();
            fresh
        }
    };
    let alt_irk = std::fs::read_to_string(ALT_IRK_FILE)
        .ok()
        .and_then(|h| hex::decode(h.trim()).ok())
        .and_then(|b| b.try_into().ok());
    Ok((file, alt_irk))
}

fn random_port() -> u16 {
    let b = uuid::Uuid::new_v4();
    let n = u16::from_be_bytes([b.as_bytes()[0], b.as_bytes()[1]]);
    50000 + n % 10000
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_wifi_address_comes_out_of_ifconfig() {
        let ifconfig = "en0: flags=8863<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500\n\
             \tinet6 fe80::1c2b:3a4d:5e6f:7081%en0 prefixlen 64 secured scopeid 0x9\n\
             \tinet 192.168.178.42 netmask 0xffffff00 broadcast 192.168.178.255\n";
        assert_eq!(wifi_address(ifconfig), Some([192, 168, 178, 42]));
        assert_eq!(wifi_address("lo0: inet 127.0.0.1 netmask 0xff000000"), None);
        assert_eq!(wifi_address("  10.0.0.7\n"), Some([10, 0, 0, 7]));
        assert_eq!(wifi_address("en0: flags=8822<BROADCAST,SMART,SIMPLEX,MULTICAST> mtu 1500"), None);
    }

    #[test]
    fn transfer_codes_have_six_digits() {
        for _ in 0..100 {
            let code = transfer_code();
            assert_eq!(code.len(), 6);
            assert!(code.chars().all(|c| c.is_ascii_digit()) && !code.starts_with('0'));
        }
    }
}
