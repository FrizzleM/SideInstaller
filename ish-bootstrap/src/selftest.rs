//! Checkpoint 1: prove the toolchain, on the device, before any pipeline code.
//!
//! Everything here is chosen because it is a plausible way for an
//! `i686-unknown-linux-musl` binary to fail *only* under iSH's emulator and
//! sandbox, where none of it can be reproduced on a build machine:
//!
//! * **codegen** — Rust's i686 targets assume a Pentium 4 baseline (SSE2). If
//!   iSH does not emulate an instruction the compiler chose, the process dies
//!   with SIGILL and prints nothing at all.
//! * **ring's x86 assembly** — hand-written, and a separate SIGILL surface from
//!   anything rustc emits. Tested against a known digest so a wrong answer is
//!   caught as loudly as a crash.
//! * **TLS** — `rustls-no-provider` means the `CryptoProvider` is installed at
//!   runtime, and the system trust store has to exist inside Alpine. A build
//!   cannot tell us either way.
//! * **the sandbox's view of the network** — the loopback-VPN peer answers
//!   where plain loopback does not, and that asymmetry is the discovery the
//!   whole approach rests on.
//!
//! Each stage prints before it runs, so whichever line is last on screen names
//! the thing that failed.

use std::net::{SocketAddr, TcpStream, UdpSocket};
use std::time::{Duration, Instant};

use crate::fail::{Fail, Result};
use crate::ui;

/// The loopback VPN's peer address. Measured on device: lockdownd and RSD both
/// answer here, and neither answers on 127.0.0.1 (that returns EPERM — the
/// sandbox denies loopback to system services).
pub const VPN_PEER: &str = "10.7.0.1";
pub const LOCKDOWN_PORT: u16 = 62078;
pub const RSD_PORT: u16 = 49152;

const TOTAL: usize = 5;

/// Returns whether the device's own services were reachable.
pub fn run(offline: bool) -> Result<bool> {
    platform();
    runtime()?;
    crypto()?;
    if offline {
        ui::stage(4, TOTAL, "TLS to api.github.com — skipped (--offline)");
    } else {
        tls()?;
    }
    let reachable = network();

    println!();
    ui::ok("toolchain checks passed");
    if reachable {
        ui::ok("this iPhone's own services are reachable — the approach holds here");
    } else {
        ui::warn(
            "the device checks did not run: LocalDevVPN was not connected. The toolchain \
             result above still stands.",
        );
    }
    println!();
    Ok(reachable)
}

fn platform() {
    ui::stage(1, TOTAL, "Platform");
    ui::info(&format!(
        "{} / {} — {}-bit pointers",
        std::env::consts::ARCH,
        std::env::consts::OS,
        std::mem::size_of::<usize>() * 8
    ));
    if cfg!(all(target_arch = "x86", target_os = "linux")) {
        ui::detail("built for i686-unknown-linux-musl (the iSH build)");
    } else {
        ui::detail("not an i686 Linux build — running off-device, so the emulator is untested");
    }
    // Reaching this line at all means every instruction rustc chose so far is
    // one this CPU implements: an unsupported opcode kills the process outright,
    // printing nothing. That is the single most likely way a Rust binary fails
    // under iSH, which is why it is checked before anything else.
    ui::ok("this binary's instruction set runs here");
}

/// Spinning up the multi-threaded runtime exercises thread creation and the
/// futex/mmap paths musl uses — the parts of libc iSH emulates least completely.
fn runtime() -> Result<()> {
    ui::stage(2, TOTAL, "Async runtime (threads, timers)");
    let rt = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
        .map_err(|e| {
            Fail::new(
                "This build could not start its thread pool inside iSH. Nothing here can \
                 work around that — please report it with the line below.",
                format!("tokio runtime build failed: {e}"),
            )
        })?;

    let started = Instant::now();
    rt.block_on(async {
        tokio::time::sleep(Duration::from_millis(50)).await;
    });
    let slept = started.elapsed();
    ui::detail(&format!("50ms sleep took {slept:?}"));
    ui::ok("runtime started, timers fire");
    Ok(())
}

/// A SHA-256 known-answer test. `ring` ships hand-written x86 assembly, so this
/// is both a "does it run" and a "does it compute the right thing" check.
fn crypto() -> Result<()> {
    ui::stage(3, TOTAL, "Crypto backend (ring, x86 assembly)");
    let digest = ring::digest::digest(&ring::digest::SHA256, b"abc");
    let got = hex(digest.as_ref());
    // FIPS 180-4 SHA-256("abc").
    const WANT: &str = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
    if got != WANT {
        return Err(Fail::new(
            "This device's CPU emulation computed a wrong SHA-256. Signing would produce \
             a corrupt bundle, so siboot stops here.",
            format!("ring SHA-256(\"abc\") = {got}, expected {WANT}"),
        ));
    }
    ui::detail(&format!("SHA-256(\"abc\") = {got}"));

    // Announced, because under emulation this single loop can take tens of
    // seconds and would otherwise look like the stage had hung.
    ui::info("measuring hash speed (4 MiB) — this is the slow part, please wait …");
    let started = Instant::now();
    let mut ctx = ring::digest::Context::new(&ring::digest::SHA256);
    let block = [0u8; 64 * 1024];
    for _ in 0..64 {
        ctx.update(&block);
    }
    let _ = ctx.finish();
    let elapsed = started.elapsed();
    // 4 MiB. The unsigned IPA is 7.6 MB and signing hashes every Mach-O page,
    // so this is the closest thing to a signing-time estimate available before
    // there is an Apple account to sign with.
    ui::info(&format!(
        "SHA-256 throughput: 4 MiB in {:.1}s ({:.2} MiB/s)",
        elapsed.as_secs_f64(),
        4.0 / elapsed.as_secs_f64().max(0.001)
    ));
    ui::ok("ring runs and agrees with the FIPS 180-4 vector");
    Ok(())
}

/// One real HTTPS request. Proves the runtime-installed `CryptoProvider`, the
/// rustls handshake and Alpine's trust store all work from inside the sandbox.
fn tls() -> Result<()> {
    ui::stage(4, TOTAL, "TLS to api.github.com");
    let rt = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|e| Fail::new("Could not start a runtime for the network check.", e.to_string()))?;

    rt.block_on(async {
        let client = reqwest::Client::builder()
            .user_agent(crate::USER_AGENT)
            .timeout(Duration::from_secs(60))
            .build()
            .map_err(|e| Fail::new("Could not build an HTTPS client.", e.to_string()))?;

        let resp = client
            .get("https://api.github.com/repos/FrizzleM/SideInstaller/releases/latest")
            .send()
            .await
            .map_err(|e| {
                Fail::new(
                    "Could not reach api.github.com over HTTPS. Check that iSH has network \
                     access — if `curl https://api.github.com` also fails, the problem is \
                     iSH's connection, not siboot.",
                    format!("{e:?}"),
                )
            })?;

        let status = resp.status();
        let body: serde_json::Value = resp
            .json()
            .await
            .map_err(|e| Fail::new("GitHub replied with something that was not JSON.", e.to_string()))?;
        let tag = body.get("tag_name").and_then(|v| v.as_str()).unwrap_or("<none>");
        ui::detail(&format!("HTTP {status}"));
        ui::ok(&format!("TLS works; latest SideInstaller release is {tag}"));
        Ok::<_, Fail>(())
    })
}

/// The reachability asymmetry the whole approach depends on. Not a protocol
/// exchange — that is checkpoint 2's job — just a connect, so the result is
/// unambiguous.
fn network() -> bool {
    ui::stage(5, TOTAL, "Device services over the loopback VPN");

    match local_address() {
        Some(addr) => ui::detail(&format!("local address (via connected UDP socket): {addr}")),
        None => ui::detail("local address: unavailable"),
    }

    let mut vpn_up = false;
    for (label, host, port) in [
        ("lockdownd", VPN_PEER, LOCKDOWN_PORT),
        ("RemoteServiceDiscovery", VPN_PEER, RSD_PORT),
    ] {
        match probe(host, port) {
            Ok(took) => {
                vpn_up = true;
                ui::ok(&format!("{host}:{port} ({label}) is open — {took:?}"));
            }
            Err(e) => ui::warn(&format!("{host}:{port} ({label}) did not answer — {e}")),
        }
    }

    // Recorded for contrast: on device this is EPERM, not a refusal. Only ever
    // a diagnostic, never a fallback.
    match probe("127.0.0.1", LOCKDOWN_PORT) {
        Ok(_) => ui::detail("127.0.0.1:62078 answered — unexpected; please report this"),
        Err(e) => ui::detail(&format!("127.0.0.1:{LOCKDOWN_PORT} refused as expected — {e}")),
    }

    if vpn_up {
        ui::ok("this iPhone's own lockdownd is reachable from inside iSH");
    } else {
        ui::warn("no device service answered. Start LocalDevVPN and connect it, then re-run.");
    }
    vpn_up
}

fn probe(host: &str, port: u16) -> std::result::Result<Duration, String> {
    let addr: SocketAddr = format!("{host}:{port}").parse().map_err(|e| format!("{e}"))?;
    let started = Instant::now();
    TcpStream::connect_timeout(&addr, Duration::from_secs(5))
        .map(|_| started.elapsed())
        .map_err(|e| format!("{e}"))
}

/// iSH has no `/proc/net/dev`, so `ifconfig` and `ip addr` both fail. A UDP
/// socket connected to the peer picks the route without sending a packet, and
/// its local address is the answer.
fn local_address() -> Option<String> {
    let sock = UdpSocket::bind("0.0.0.0:0").ok()?;
    sock.connect((VPN_PEER, 9)).ok()?;
    sock.local_addr().ok().map(|a| a.ip().to_string())
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
