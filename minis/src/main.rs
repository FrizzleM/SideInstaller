//! `siboot` for Open Minis: installs SideInstaller onto the iPhone it runs on,
//! with no computer and no paid certificate.
//!
//! Open Minis (App Store) runs Alpine Linux on an ARM64 build of iSH, so this is
//! an ordinary static aarch64 Linux binary built on the same vendored idevice
//! and isideload as SideInstaller. What no Linux program can do on iOS is
//! advertise over Bonjour. Minis's `minis-bonjour` does that for it, from the
//! app, and Minis declares `_remotepairing-pairable-host._tcp`: the type iOS 27's
//! Settings › Developer Mode lists hosts by. That lets this iPhone pair with
//! itself here, which a-Shell, Terminus and iSH can't (see README.md).
//!
//! The steps keep the numbering of ../ashell and ../ish-bootstrap:
//! 1 check · 2 pair · 3 connect · 4 Apple ID · 5 sign · 6 install · 7 hand over.
//!
//! The Apple ID password goes only to Apple (as an SRP proof, via isideload) and
//! is never written to disk or logged. Like SideInstaller, the developer token
//! and signing key are kept, in ~/.siboot/isideload, so a second run needn't
//! sign in again.

mod account;
mod bridge;
mod fail;
mod install;
mod keepalive;
mod pairing;
mod preflight;
mod seed;
mod sign;
mod tunnel;
mod ui;

// rust-core's saved-session sign-in, compiled here unchanged so siboot signs in
// exactly as SideInstaller does (anisette identity rules, -80046 skip, token
// reuse). `crate::error_text` is the path it expects.
#[allow(dead_code)]
#[path = "../../rust-core/src/apple_session.rs"]
mod apple_session;
#[allow(dead_code)]
#[path = "../../rust-core/src/error_text.rs"]
mod error_text;

#[cfg(test)]
mod fake_iphone;

use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use std::process::ExitCode;

use fail::{Fail, Result};

pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Steps in the full run. Numbering stays fixed whatever the command, so the
/// output means the same thing in every mode.
const STAGES: usize = 7;

/// LocalDevVPN's address for this iPhone: traffic to it comes back to the
/// device's own services.
const DEFAULT_DEVICE_IP: Ipv4Addr = Ipv4Addr::new(10, 7, 0, 1);
/// The device's RPPairing listener (remoted), as SideInstaller dials it.
const DEFAULT_RP_PORT: u16 = 49152;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Command {
    /// Every step.
    All,
    /// Step 1 only.
    Check,
    /// Steps 1-2: leave a pairing file and stop.
    Pair,
    /// Steps 1-3 with the saved pairing file: prove the tunnel works.
    Connect,
}

/// How the pairing host is advertised.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Advertiser {
    /// `minis-bonjour advertise`, from inside Open Minis.
    Minis,
    /// `dns-sd -R`, for running on a Mac on the iPhone's Wi-Fi (testing).
    DnsSd,
    /// Print the record and advertise nothing (tests, or advertising by hand).
    None,
}

pub struct Args {
    pub command: Command,
    pub verbose: bool,
    pub device: SocketAddr,
    /// ~/.siboot: the pairing file, isideload's store, downloads.
    pub home: PathBuf,
    pub pairing_file: Option<PathBuf>,
    pub apple_id: Option<String>,
    pub ipa: Option<String>,
    pub anisette: Option<String>,
    pub advertiser: Advertiser,
    pub keepalive: bool,
    /// The name Settings shows: "Pair with <name>".
    pub host_name: String,
    /// Pair again even when the saved pairing file still works.
    pub repair: bool,
}

impl Args {
    pub fn pairing_path(&self) -> PathBuf {
        self.pairing_file
            .clone()
            .unwrap_or_else(|| self.home.join("rp_pairing_file.plist"))
    }
}

fn default_home() -> PathBuf {
    let home = std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| ".".into());
    home.join(".siboot")
}

enum Parsed {
    Run(Args),
    Help,
    Version,
}

fn parse_args(argv: impl IntoIterator<Item = String>) -> std::result::Result<Parsed, String> {
    let mut args = Args {
        command: Command::All,
        verbose: false,
        device: SocketAddr::new(IpAddr::V4(DEFAULT_DEVICE_IP), DEFAULT_RP_PORT),
        home: default_home(),
        pairing_file: None,
        apple_id: None,
        ipa: None,
        anisette: None,
        advertiser: Advertiser::Minis,
        keepalive: true,
        host_name: "siboot".into(),
        repair: false,
    };
    let mut argv = argv.into_iter();
    let mut command_seen = false;
    while let Some(arg) = argv.next() {
        let mut value = |flag: &str| argv.next().ok_or(format!("{flag} needs a value"));
        match arg.as_str() {
            "-h" | "--help" | "help" => return Ok(Parsed::Help),
            "-V" | "--version" => return Ok(Parsed::Version),
            "-v" | "--verbose" => args.verbose = true,
            "--device-ip" => {
                let ip: IpAddr = value("--device-ip")?
                    .parse()
                    .map_err(|_| "--device-ip needs an IP address".to_string())?;
                args.device.set_ip(ip);
            }
            "--port" => {
                let port = value("--port")?
                    .parse()
                    .map_err(|_| "--port needs a port number".to_string())?;
                args.device.set_port(port);
            }
            "--home" => args.home = PathBuf::from(value("--home")?),
            "--pairing-file" => args.pairing_file = Some(PathBuf::from(value("--pairing-file")?)),
            "--apple-id" => args.apple_id = Some(value("--apple-id")?),
            "--ipa" => args.ipa = Some(value("--ipa")?),
            "--anisette" => args.anisette = Some(value("--anisette")?),
            "--name" => args.host_name = value("--name")?,
            "--advertiser" => {
                args.advertiser = match value("--advertiser")?.as_str() {
                    "minis" => Advertiser::Minis,
                    "dns-sd" => Advertiser::DnsSd,
                    "none" => Advertiser::None,
                    other => return Err(format!("unknown advertiser `{other}` (minis, dns-sd, none)")),
                }
            }
            "--no-keepalive" => args.keepalive = false,
            "--repair" => args.repair = true,
            "check" | "pair" | "connect" if !command_seen => {
                command_seen = true;
                args.command = match arg.as_str() {
                    "check" => Command::Check,
                    "pair" => Command::Pair,
                    _ => Command::Connect,
                };
            }
            other => return Err(format!("unrecognised argument `{other}`")),
        }
    }
    if args.host_name.trim().is_empty() {
        return Err("--name can't be empty".into());
    }
    Ok(Parsed::Run(args))
}

fn usage() {
    println!(
        "\
siboot {VERSION} — installs SideInstaller onto this iPhone, from Open Minis.

USAGE
    siboot [check | pair | connect] [options]

    With no command, every step runs: check, pair this iPhone with itself,
    connect, sign in to your Apple Account, sign SideInstaller, install it,
    and hand it the pairing.

COMMANDS
    check       Only check that Minis, LocalDevVPN and this iPhone are ready.
    pair        Check, then pair this iPhone with itself and save the file.
    connect     Check, then open the tunnel with the saved pairing file.

OPTIONS
    --apple-id EMAIL    Apple Account to sign with (else SIBOOT_APPLE_ID, else
                        a prompt). The password comes from SIBOOT_PASSWORD or a
                        prompt that doesn't echo.
    --ipa PATH|URL      Install this IPA instead of SideInstaller's latest release.
    --anisette URL      Sign in through this anisette server only.
    --device-ip IP      LocalDevVPN's address for this iPhone (default {ip}).
    --port N            The iPhone's RPPairing port (default {port}).
    --pairing-file PATH Default ~/.siboot/rp_pairing_file.plist.
    --home DIR          Where siboot keeps its files (default ~/.siboot).
    --name NAME         The host name Settings shows (default siboot).
    --repair            Pair again even if the saved pairing file works.
    --advertiser KIND   minis (default), dns-sd (a Mac on the iPhone's Wi-Fi,
                        for testing) or none.
    --no-keepalive      Don't play silence while pairing. Without it iOS may
                        suspend Minis while you're in Settings.
    -v, --verbose       Show the underlying protocol and library errors.
    -h, --help          Show this message.

NEEDS
    Open Minis with the minis-bonjour command (its TestFlight build from late
    October 2026 on), Wi-Fi, Developer Mode on, iOS 27 or later, and
    LocalDevVPN (App Store) connected.",
        ip = DEFAULT_DEVICE_IP,
        port = DEFAULT_RP_PORT,
    );
}

fn main() -> ExitCode {
    let parsed = match parse_args(std::env::args().skip(1)) {
        Ok(p) => p,
        Err(problem) => {
            eprintln!("siboot: {problem}");
            eprintln!("try `siboot --help`");
            return ExitCode::from(2);
        }
    };
    let args = match parsed {
        Parsed::Help => {
            usage();
            return ExitCode::SUCCESS;
        }
        Parsed::Version => {
            println!("siboot {VERSION}");
            return ExitCode::SUCCESS;
        }
        Parsed::Run(args) => args,
    };

    ui::set_verbose(args.verbose);
    init_logging(args.verbose);
    ui::banner(VERSION, args.advertiser);

    // Two workers: the software TCP stack inside the tunnel keeps moving while
    // a foreground task waits on it, and threads are cheap next to emulation.
    let runtime = match tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(e) => {
            eprintln!("siboot: could not start the async runtime: {e}");
            return ExitCode::FAILURE;
        }
    };

    let outcome = runtime.block_on(async {
        tokio::select! {
            outcome = pipeline(&args) => outcome,
            _ = tokio::signal::ctrl_c() => Err(Fail::new("Stopped with Ctrl-C.", "SIGINT")),
        }
    });
    // Whatever was advertised or playing is stopped by its guard as the
    // pipeline's future is dropped, before this point.
    match outcome {
        Ok(()) => ExitCode::SUCCESS,
        Err(f) => {
            ui::failure(&f.advice, &f.raw);
            ExitCode::FAILURE
        }
    }
}

/// idevice's and isideload's own logs go to stderr: warnings by default, and
/// everything they say with `--verbose`.
///
/// hyper-util warns on every connection that the socket refused
/// `TCP_USER_TIMEOUT`, which iSH doesn't implement; the connection is fine, so
/// that warning only shows with `--verbose`.
fn init_logging(verbose: bool) {
    use tracing_subscriber::filter::{LevelFilter, Targets};
    use tracing_subscriber::prelude::*;

    let level = if verbose { LevelFilter::DEBUG } else { LevelFilter::WARN };
    let quiet = if verbose { LevelFilter::DEBUG } else { LevelFilter::ERROR };
    let filter = Targets::new().with_default(level).with_target("hyper_util", quiet);
    let fmt = tracing_subscriber::fmt::layer()
        .with_writer(std::io::stderr)
        .with_target(verbose)
        .without_time();
    let _ = tracing_subscriber::registry().with(fmt).with(filter).try_init();
}

async fn pipeline(args: &Args) -> Result<()> {
    std::fs::create_dir_all(&args.home)
        .map_err(|e| Fail::new(format!("Couldn't create {}.", args.home.display()), e.to_string()))?;
    let bridge = bridge::Bridge::from_env();

    ui::stage(1, STAGES, "Checking Minis, LocalDevVPN and this iPhone");
    let ready = preflight::run(&bridge, args).await?;
    if args.command == Command::Check {
        println!();
        ui::ok("ready — run `siboot` to install SideInstaller");
        return Ok(());
    }

    ui::stage(2, STAGES, "Pairing this iPhone with itself");
    let pairing_path = args.pairing_path();
    pairing::ensure(&bridge, args, &ready, &pairing_path).await?;
    if args.command == Command::Pair {
        println!();
        ui::ok(&format!("pairing file saved at {}", pairing_path.display()));
        return Ok(());
    }

    ui::stage(3, STAGES, "Connecting to this iPhone through LocalDevVPN");
    let device = {
        let mut connection = tunnel::open(args.device, &pairing_path).await?;
        connection.describe().await?
    };
    ui::ok(&format!(
        "{} — {} on iOS {}",
        device.name, device.product_type, device.ios_version
    ));
    ui::detail(&format!("UDID {}", device.udid));
    if args.command == Command::Connect {
        println!();
        ui::ok("the tunnel works with this pairing file");
        return Ok(());
    }
    // The connection is closed here: iOS drops an idle tunnel during sign-in and
    // signing anyway, so a fresh one is opened to install (as Side by Side does).

    ui::stage(4, STAGES, "Signing in to your Apple Account");
    let mut session = account::sign_in(args).await?;

    ui::stage(5, STAGES, "Signing SideInstaller for this iPhone");
    let ipa = sign::fetch_ipa(args).await?;
    let signed = sign::sign(&mut session, &ipa, &device).await?;

    ui::stage(6, STAGES, "Installing it");
    let mut connection = tunnel::open(args.device, &pairing_path).await?;
    install::install(&mut connection, &signed.app_dir).await?;
    ui::ok(&format!("{} installed ({})", signed.name, signed.bundle_id));

    ui::stage(7, STAGES, "Handing SideInstaller the pairing");
    seed::hand_over(&mut connection, &signed.bundle_id, &pairing_path).await?;

    println!();
    ui::ok("Done. Open SideInstaller from your Home Screen.");
    ui::info("The first time, iOS asks you to trust your Apple Account: Settings ›");
    ui::info("General › VPN & Device Management. Free accounts' apps last 7 days;");
    ui::info("SideInstaller can renew itself from then on.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(line: &str) -> Args {
        match parse_args(line.split_whitespace().map(String::from)).unwrap() {
            Parsed::Run(args) => args,
            _ => panic!("not a run"),
        }
    }

    #[test]
    fn defaults_run_everything_through_localdevvpn() {
        let args = parse("");
        assert_eq!(args.command, Command::All);
        assert_eq!(args.device.to_string(), "10.7.0.1:49152");
        assert_eq!(args.advertiser, Advertiser::Minis);
        assert!(args.keepalive);
        assert!(args.pairing_path().ends_with(".siboot/rp_pairing_file.plist"));
    }

    #[test]
    fn commands_and_options_parse() {
        let args = parse("pair --advertiser dns-sd --device-ip 192.168.1.20 --port 50000 --no-keepalive -v");
        assert_eq!(args.command, Command::Pair);
        assert_eq!(args.advertiser, Advertiser::DnsSd);
        assert_eq!(args.device.to_string(), "192.168.1.20:50000");
        assert!(!args.keepalive && args.verbose);
    }

    #[test]
    fn bad_input_is_refused() {
        for line in ["--device-ip", "--device-ip nope", "--advertiser avahi", "pair connect", "--name"] {
            assert!(parse_args(line.split_whitespace().map(String::from)).is_err(), "{line}");
        }
    }
}
