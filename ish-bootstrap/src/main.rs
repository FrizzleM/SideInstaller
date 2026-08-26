//! `siboot` — a PC-free, certificate-free bootstrap for SideInstaller.
//!
//! Runs inside [iSH](https://ish.app) on the iPhone it installs to. The pipeline
//! is: reach this device's own lockdownd over the loopback VPN, mint a pair
//! record, open a CoreDeviceProxy tunnel, sign the IPA with the user's own free
//! Apple account, then install it over AFC + installation_proxy.
//!
//! **Checkpoint 1 of 5.** Only the self-test is wired up. It exists to prove the
//! toolchain on real hardware — the i686 codegen, ring's assembly, TLS, and the
//! loopback-VPN reachability — before any pipeline code is written against it.
//! See `README.md` for the phase plan.
//!
//! Credentials are never written to disk or to any log. There are none to
//! handle yet at this checkpoint; the promise is recorded here because it is the
//! project's central one.

mod selftest;
mod ui;

use std::process::ExitCode;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const USER_AGENT: &str = concat!("siboot/", env!("CARGO_PKG_VERSION"));

struct Args {
    verbose: bool,
    offline: bool,
    help: bool,
}

fn parse_args() -> Result<Args, String> {
    let mut args = Args { verbose: false, offline: false, help: false };
    for arg in std::env::args().skip(1) {
        match arg.as_str() {
            "-v" | "--verbose" => args.verbose = true,
            "--offline" => args.offline = true,
            "-h" | "--help" => args.help = true,
            // Accepted now so the checkpoint-1 binary does not reject the
            // invocation the finished tool documents.
            "--self-test" => {}
            other => return Err(other.to_string()),
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
    -v, --verbose    Show the underlying protocol and library errors.
        --offline    Skip the checks that need internet access.
        --self-test  Run the toolchain checks only. (Checkpoint 1: this is
                     everything siboot currently does.)
    -h, --help       Show this message.

REQUIREMENTS
    LocalDevVPN (App Store) installed and connected. siboot reaches this
    iPhone's own services through that VPN's peer address; without it they
    cannot be reached from inside iSH at all.

    Keep iSH in the foreground while it runs."
    );
}

fn main() -> ExitCode {
    // Before anything else can open a TLS connection. isideload's reqwest is
    // built with `rustls-no-provider` to keep aws-lc out of the i686-musl build
    // (see vendor/isideload/README.md), which leaves the process-wide provider
    // unset — the first handshake would panic rather than fail. Installing it
    // here is the counterpart to that decision.
    if rustls::crypto::ring::default_provider().install_default().is_err() {
        eprintln!("siboot: could not install the ring crypto provider");
        return ExitCode::FAILURE;
    }

    let args = match parse_args() {
        Ok(a) => a,
        Err(unknown) => {
            eprintln!("siboot: unrecognised option `{unknown}`");
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

    match selftest::run(args.offline) {
        Ok(device_reachable) => {
            println!();
            ui::ok("toolchain checks passed");
            if device_reachable {
                ui::ok("this iPhone's own services are reachable — the approach holds here");
            } else {
                ui::warn(
                    "the device checks did not run: LocalDevVPN was not connected. The \
                     toolchain result above still stands.",
                );
            }
            println!();
            ui::info("This build stops here by design — it is checkpoint 1 of 5, and its");
            ui::info("only job is to prove the toolchain runs on real hardware.");
            println!();
            ExitCode::SUCCESS
        }
        Err((advice, raw)) => {
            ui::failure(&advice, &raw);
            ExitCode::FAILURE
        }
    }
}
