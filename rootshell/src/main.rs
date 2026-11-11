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
//! It writes `rp_pairing_file.plist` into rootshell's folder, then offers it
//! on this iPhone's loopback, behind a transfer code, to siboot in Open Minis
//! (../minis), which runs the other six steps.

mod mdns;
mod rs;

#[cfg(test)]
mod fake_iphone;

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
/// Settings shows "Pair with siboot".
const HOST_NAME: &str = "siboot";
const PAIRING_FILE: &str = "rp_pairing_file.plist";
const ALT_IRK_FILE: &str = "host_alt_irk";
/// Where `ifconfig en0 > ifconfig.txt` leaves the address for us.
const IFCONFIG_FILE: &str = "ifconfig.txt";
const INSTALL: &str =
    "wget -qO- https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/minis/install.sh | sh";

struct Args {
    ip: [u8; 4],
    port: Option<u16>,
    service: String,
}

fn usage() {
    println!(
        "siboot-pair {VERSION} — pairs this iPhone with itself, from rootshell.

USAGE
    ifconfig en0 > ifconfig.txt
    ./siboot-pair.wasm

    One line at a time. It reads this iPhone's Wi-Fi address from ifconfig.txt
    (a WASM program can't find it itself). Before running it, turn on
    rootshell's Settings › Location Diary Mode › Session Only, which keeps
    rootshell running while you're in Settings. After pairing it hands the
    pairing file to siboot in Open Minis.

OPTIONS
    --port N      The port to listen on (default: a random one).
    -h, --help    Show this message."
    );
}

fn parse_args() -> Result<Option<Args>, String> {
    let mut args = Args { ip: [0; 4], port: None, service: mdns::PAIRABLE_HOST_TYPE.into() };
    let mut argv = std::env::args().skip(1);
    while let Some(arg) = argv.next() {
        let mut value = |flag: &str| argv.next().ok_or(format!("{flag} needs a value"));
        match arg.as_str() {
            "-h" | "--help" => return Ok(None),
            "-V" | "--version" => {
                println!("siboot-pair {VERSION}");
                std::process::exit(0);
            }
            "--port" => {
                args.port = Some(value("--port")?.parse().map_err(|_| "--port needs a number".to_string())?)
            }
            // Tests: announce another type, so a test run on a real network
            // doesn't offer itself to iPhones there.
            "--service" => args.service = value("--service")?,
            other => return Err(format!("unrecognised argument `{other}`")),
        }
    }
    let saved = std::fs::read_to_string(IFCONFIG_FILE).map_err(|_| {
        format!("no {IFCONFIG_FILE} here. Run `ifconfig en0 > {IFCONFIG_FILE}` first, then `./siboot-pair.wasm`.")
    })?;
    args.ip = wifi_address(&saved).ok_or(format!(
        "no IPv4 address in {IFCONFIG_FILE}. Turn on Wi-Fi, run `ifconfig en0 > {IFCONFIG_FILE}` again, \
         then `./siboot-pair.wasm`."
    ))?;
    Ok(Some(args))
}

/// The first non-loopback IPv4 address in `ifconfig` output (`inet A.B.C.D`).
fn wifi_address(text: &str) -> Option<[u8; 4]> {
    let mut words = text.split_whitespace().peekable();
    while let Some(word) = words.next() {
        if word != "inet" {
            continue;
        }
        if let Some(ip) = words
            .peek()
            .and_then(|w| w.trim_start_matches("addr:").parse::<Ipv4Addr>().ok())
            .filter(|ip| !ip.is_loopback() && !ip.is_unspecified() && !ip.is_broadcast())
        {
            return Some(ip.octets());
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

    let (mut file, alt_irk) = identity();
    let mut info = PairableHostInfo::generate(HOST_NAME, HOST_MODEL);
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
    println!("OK announced \"Pair with {HOST_NAME}\" on port {port}");
    println!();
    println!("Now, on this iPhone:");
    println!("  1. Open Settings › Privacy & Security › Developer Mode, and scroll to the bottom.");
    println!("  2. Tap \"Pair with {HOST_NAME}\". It can take a few seconds to appear.");
    println!("  3. Enter your passcode, then the 6-digit code, which arrives as a rootshell");
    println!("     notification (it's also printed here).");
    println!("Waiting …");

    let peer = pair(&listener, &info, &mut file, show_code)?;
    drop(listener);

    std::fs::write(PAIRING_FILE, file.to_bytes()).map_err(|e| format!("paired, but couldn't write {PAIRING_FILE}: {e}"))?;
    let _ = std::fs::write(ALT_IRK_FILE, hex::encode(info.alt_irk));
    // Withdraw the entry: nothing listens behind it now.
    let _ = rs::Socket::send_datagram(&mdns::announcement(&ad, 0), mdns::GROUP, mdns::PORT);

    println!();
    println!("OK paired with {} ({})", peer.name, peer.model);
    println!("OK pairing file saved: Files › rootshell › {PAIRING_FILE}");
    hand_off(&file.to_bytes())
}

/// Where siboot in Minis asks for the pairing file, on this iPhone's loopback.
/// Also in minis/src/pairing.rs.
const HANDOFF_PORT: u16 = 61207;
const HANDOFF_TRIES: u32 = 5;

/// Offer the pairing file to siboot in Open Minis, over this iPhone's own
/// loopback, until it has it.
fn hand_off(pairing: &[u8]) -> Result<(), String> {
    let listener = rs::Socket::listen(HANDOFF_PORT).map_err(|e| {
        format!(
            "paired, but couldn't offer the file to Minis ({e}). Close any other rootshell tab \
             running siboot-pair, then run `./siboot-pair.wasm` again."
        )
    })?;
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
    println!("siboot only asks when it has no pairing file that works yet. If it goes");
    println!("ahead without asking, close this tab once Minis is done.");
    if offer(&listener, &code, pairing) {
        println!("OK siboot has the pairing file. You can close rootshell's tab.");
        Ok(())
    } else {
        Err("stopped offering the file. Run `./siboot-pair.wasm` again for a new transfer code.".into())
    }
}

/// Answer siboot's requests on `listener` until one brings `code`, then send
/// the file. The code keeps any other app on the iPhone from taking it:
/// `HANDOFF_TRIES` wrong ones end the offer. True once siboot has the file.
fn offer(listener: &rs::Socket, code: &str, pairing: &[u8]) -> bool {
    let mut wrong = 0;
    while wrong < HANDOFF_TRIES {
        let Ok(conn) = listener.accept() else { return false };
        let asked = conn.read_line(64).unwrap_or_default();
        let given: String = asked.trim_start_matches("SIBOOT1").chars().filter(char::is_ascii_digit).collect();
        if asked.starts_with("SIBOOT1") && given == code {
            let sent = conn
                .write_all(format!("OK {}\n", pairing.len()).as_bytes())
                .and_then(|()| conn.write_all(pairing));
            match sent {
                Ok(()) => return true,
                Err(e) => println!("  sending the file broke off ({e}); waiting for siboot to ask again"),
            }
        } else {
            wrong += 1;
            let _ = conn.write_all(b"NO\n");
            println!("  a wrong transfer code ({wrong} of {HANDOFF_TRIES})");
        }
    }
    false
}

/// Six digits, not starting with 0 so it reads as a number.
fn transfer_code() -> String {
    let b = uuid::Uuid::new_v4();
    let n = u32::from_be_bytes(b.as_bytes()[..4].try_into().unwrap());
    format!("{}", 100_000 + n % 900_000)
}

/// Pair over up to `MAX_ATTEMPTS` connections: a stray one, a mistyped code
/// or a cancel in Settings leaves the entry up for another tap. Each code
/// goes to `show`.
fn pair(
    listener: &rs::Socket,
    info: &PairableHostInfo,
    file: &mut RpPairingFile,
    show: impl Fn(&str),
) -> Result<PeerDevice, String> {
    for attempt in 1..=MAX_ATTEMPTS {
        let stream = listener.accept().map_err(|e| format!("couldn't accept the connection: {e}"))?;
        println!("Settings connected — waiting for it to ask for a code …");
        let mut host = PairableHost::new(RpPairingSocket::new_device(stream), info.clone());
        let code_shown = Cell::new(false);
        let outcome = futures::executor::block_on(host.accept(file, |pin: String| {
            code_shown.set(true);
            show(&pin);
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
fn identity() -> (RpPairingFile, Option<[u8; 16]>) {
    let file = match std::fs::read(PAIRING_FILE).ok().and_then(|b| RpPairingFile::from_bytes(&b).ok()) {
        Some(mut existing) => {
            existing.alt_irk = None;
            existing
        }
        None => fresh_identity(),
    };
    let alt_irk = std::fs::read_to_string(ALT_IRK_FILE)
        .ok()
        .and_then(|h| hex::decode(h.trim()).ok())
        .and_then(|b| b.try_into().ok());
    (file, alt_irk)
}

/// `generate` derives the identifier from the name, the same for every
/// siboot; a random one keeps this host's records apart.
fn fresh_identity() -> RpPairingFile {
    let mut fresh = RpPairingFile::generate(HOST_NAME);
    fresh.identifier = uuid::Uuid::new_v4().to_string().to_uppercase();
    fresh
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
        assert_eq!(wifi_address("  10.0.0.7\n"), None, "only ifconfig output, not a bare address");
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

    /// A host waiting on a loopback port, as Settings finds it, pairing in a
    /// thread of its own (the real one blocks in accept). The codes it shows
    /// come out of the receiver.
    fn host() -> (
        u16,
        std::sync::mpsc::Receiver<String>,
        std::thread::JoinHandle<(Result<PeerDevice, String>, RpPairingFile)>,
    ) {
        let listener = rs::Socket::listen(0).unwrap();
        let port = listener.local_port();
        let (codes, shown) = std::sync::mpsc::channel();
        let thread = std::thread::spawn(move || {
            let info = PairableHostInfo::generate(HOST_NAME, HOST_MODEL);
            let mut file = fresh_identity();
            let paired = pair(&listener, &info, &mut file, |pin| codes.send(pin.to_string()).unwrap());
            (paired, file)
        });
        (port, shown, thread)
    }

    fn addr(port: u16) -> std::net::SocketAddr {
        std::net::SocketAddr::from(([127, 0, 0, 1], port))
    }

    /// The fake iPhone's typing: the next code the host shows.
    async fn next_code(shown: std::sync::Arc<std::sync::Mutex<std::sync::mpsc::Receiver<String>>>) -> String {
        tokio::task::spawn_blocking(move || shown.lock().unwrap().recv().unwrap()).await.unwrap()
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn a_device_pairs_and_the_file_holds_the_host_it_saw() {
        let (port, shown, host) = host();
        let shown = std::sync::Arc::new(std::sync::Mutex::new(shown));
        let phone = fake_iphone::pair(addr(port), next_code(shown)).await.expect("phone paired");
        let (paired, file) = host.join().unwrap();
        let peer = paired.expect("host paired");
        assert_eq!(peer.name, fake_iphone::NAME);
        assert_eq!(peer.model, fake_iphone::MODEL);
        // The identity the device was given in M6 is the one written out…
        assert_eq!(file.identifier, phone.host_identifier);
        assert_eq!(file.public_key_bytes(), phone.host_public_key);
        // …with the device's altIRK from M5, and it reads back.
        assert_eq!(file.alt_irk.as_deref(), Some(&fake_iphone::ALT_IRK[..]));
        let reread = RpPairingFile::from_bytes(&file.to_bytes()).unwrap();
        assert_eq!(reread.identifier, file.identifier);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn a_wrong_code_gets_another_try() {
        let (port, shown, host) = host();
        let shown = std::sync::Arc::new(std::sync::Mutex::new(shown));
        // A typo, then the entry tapped again and the new code typed.
        let first = fake_iphone::pair(addr(port), async { "000000".to_string() }).await;
        assert!(first.is_err(), "a wrong code paired");
        let _typo = next_code(shown.clone()).await;
        fake_iphone::pair(addr(port), next_code(shown)).await.expect("the second try paired");
        let (paired, _) = host.join().unwrap();
        assert_eq!(paired.expect("host paired on the second try").name, fake_iphone::NAME);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn three_wrong_codes_end_the_run_and_say_why() {
        let (port, _shown, host) = host();
        for _ in 0..MAX_ATTEMPTS {
            let paired = fake_iphone::pair(addr(port), async { "000000".to_string() }).await;
            assert!(paired.is_err(), "a wrong code paired");
        }
        let (paired, _) = host.join().unwrap();
        let problem = paired.err().expect("the host should give up");
        assert!(problem.contains("code didn't match"), "{problem}");
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn a_connection_that_drops_before_the_code_doesnt_end_pairing() {
        let (port, shown, host) = host();
        drop(std::net::TcpStream::connect(addr(port)).unwrap());
        let shown = std::sync::Arc::new(std::sync::Mutex::new(shown));
        fake_iphone::pair(addr(port), next_code(shown)).await.expect("phone paired");
        let (paired, _) = host.join().unwrap();
        assert_eq!(paired.expect("host paired after the stray connection").name, fake_iphone::NAME);
    }

    /// siboot's side of the hand-off (minis/src/pairing.rs): one request per
    /// connection, the answer's first line, then the file.
    fn ask_for_file(port: u16, code: &str) -> (String, Vec<u8>) {
        use std::io::{BufRead, Read, Write};
        let mut conn = std::net::TcpStream::connect(addr(port)).unwrap();
        conn.write_all(format!("SIBOOT1 {code}\n").as_bytes()).unwrap();
        let mut reader = std::io::BufReader::new(conn);
        let mut answer = String::new();
        reader.read_line(&mut answer).unwrap();
        let mut rest = Vec::new();
        reader.read_to_end(&mut rest).unwrap();
        (answer.trim().to_string(), rest)
    }

    #[test]
    fn the_file_goes_to_whoever_has_the_code() {
        let listener = rs::Socket::listen(0).unwrap();
        let port = listener.local_port();
        let offered = std::thread::spawn(move || offer(&listener, "481516", b"pairing file"));
        assert_eq!(ask_for_file(port, "000000").0, "NO");
        let (answer, file) = ask_for_file(port, "481516");
        assert_eq!(answer, "OK 12");
        assert_eq!(file, b"pairing file");
        assert!(offered.join().unwrap(), "the offer ends once siboot has the file");
    }

    #[test]
    fn five_wrong_codes_end_the_offer() {
        let listener = rs::Socket::listen(0).unwrap();
        let port = listener.local_port();
        let offered = std::thread::spawn(move || offer(&listener, "481516", b"pairing file"));
        for _ in 0..HANDOFF_TRIES {
            assert_eq!(ask_for_file(port, "123456").0, "NO");
        }
        assert!(!offered.join().unwrap());
    }
}
