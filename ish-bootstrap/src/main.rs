//! `siboot` — a PC-free, certificate-free bootstrap for SideInstaller.
//!
//! Runs inside [iSH](https://ish.app) on the iPhone it installs to. The pipeline
//! is: reach this device's own lockdownd over the loopback VPN, mint a pair
//! record, open a CoreDeviceProxy tunnel, sign the IPA with the user's own free
//! Apple account, then install it over AFC + installation_proxy.
//!
//! **Checkpoint 2 of 5.** Steps 1 of 7 is wired up; the rest stop with a note.
//! Checkpoint 1 — the toolchain proof — passed on device and now lives behind
//! `--self-test`.
//!
//! Credentials are used and discarded. They are never written to disk, never
//! logged, and never sent anywhere but Apple. There are none to handle before
//! step 4; the promise is recorded here because it is the project's central one.

mod fail;
mod preflight;
mod selftest;
mod ui;

use std::process::ExitCode;

use fail::Result;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const USER_AGENT: &str = concat!("siboot/", env!("CARGO_PKG_VERSION"));
/// The name this host gives lockdownd, and the name that appears on the device
/// if it ever shows a trust prompt.
pub const LABEL: &str = "siboot";

/// Steps in the finished pipeline: preflight, pair, tunnel, Apple ID, sign,
/// install, seed. Numbering stays fixed while the later ones are built so the
/// output means the same thing at every checkpoint.
const STAGES: usize = 7;

struct Args {
    verbose: bool,
    offline: bool,
    self_test: bool,
    help: bool,
    device_ip: String,
}

fn parse_args() -> std::result::Result<Args, String> {
    let mut args = Args {
        verbose: false,
        offline: false,
        self_test: false,
        help: false,
        device_ip: preflight::DEFAULT_DEVICE_IP.to_string(),
    };
    let mut argv = std::env::args().skip(1);
    while let Some(arg) = argv.next() {
        match arg.as_str() {
            "-v" | "--verbose" => args.verbose = true,
            "--offline" => args.offline = true,
            "--self-test" => args.self_test = true,
            "-h" | "--help" => args.help = true,
            "--device-ip" => {
                args.device_ip = argv.next().ok_or("--device-ip needs an address")?;
            }
            other => return Err(format!("unrecognised option `{other}`")),
        }
    }
    Ok(args)
}

fn usage() {
    println!(
        "\
siboot {VERSION} — installs SideInstaller onto this iPhone, from iSH.

USAGE
    siboot [options]

OPTIONS
    -v, --verbose       Show the underlying protocol and library errors.
        --device-ip IP  The loopback VPN's peer address (default {default}).
        --self-test     Run the toolchain checks instead of the pipeline.
        --offline       With --self-test, skip the checks needing internet.
    -h, --help          Show this message.

REQUIREMENTS
    LocalDevVPN (App Store) installed and connected. siboot reaches this
    iPhone's own services through that VPN's peer address; without it they
    cannot be reached from inside iSH at all.

    Keep iSH in the foreground while it runs.",
        default = preflight::DEFAULT_DEVICE_IP
    );
}

fn main() -> ExitCode {
    // Before anything can open a TLS connection. isideload's reqwest is built
    // with `rustls-no-provider` to keep aws-lc out of the i686-musl build (see
    // vendor/isideload/README.md), which leaves the process-wide provider
    // unset — the first handshake would panic rather than fail.
    if rustls::crypto::ring::default_provider().install_default().is_err() {
        eprintln!("siboot: could not install the ring crypto provider");
        return ExitCode::FAILURE;
    }

    let args = match parse_args() {
        Ok(a) => a,
        Err(problem) => {
            eprintln!("siboot: {problem}");
            eprintln!("try `siboot --help`");
            return ExitCode::FAILURE;
        }
    };

    if args.help {
        usage();
        return ExitCode::SUCCESS;
    }

    ui::set_verbose(args.verbose);
    ui::banner(VERSION);

    if args.self_test {
        return match selftest::run(args.offline) {
            Ok(_) => ExitCode::SUCCESS,
            Err(f) => {
                ui::failure(&f.advice, &f.raw);
                ExitCode::FAILURE
            }
        };
    }

    // Two workers rather than one: the RSD tunnel in step 3 runs a software TCP
    // stack that has to keep making progress while the foreground task waits on
    // it, and threads are cheap next to what emulation costs.
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

    match runtime.block_on(pipeline(&args)) {
        Ok(()) => ExitCode::SUCCESS,
        Err(f) => {
            ui::failure(&f.advice, &f.raw);
            ExitCode::FAILURE
        }
    }
}

async fn pipeline(args: &Args) -> Result<()> {
    ui::stage(1, STAGES, "Preflight — is this iPhone's lockdownd reachable?");
    let greeting = preflight::run(&args.device_ip).await?;

    println!();
    ui::ok("preflight passed");
    if let Some(udid) = greeting.value("UniqueDeviceID") {
        ui::info(&format!("this device's UDID is readable without pairing: {udid}"));
    }
    println!();
    ui::info("This build stops here by design — it is checkpoint 2 of 5. Pairing,");
    ui::info("the tunnel, signing and the install are not written yet.");
    println!();
    Ok(())
}
