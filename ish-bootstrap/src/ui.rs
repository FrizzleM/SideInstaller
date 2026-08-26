//! Terminal output: staged status lines, a verbose channel, and prompts.
//!
//! Two rules from the spec shape this module. Every stage prints a one-line
//! status *before* it starts, so a stall under emulation is attributable to a
//! named step rather than to "it hung". And errors name the thing the user can
//! change — the raw protocol/FFI text goes to the verbose channel instead, the
//! way `DeviceConnection.tunnelAdvice` separates advice from cause.

use std::io::{self, IsTerminal, Write};
use std::sync::atomic::{AtomicBool, Ordering};

static VERBOSE: AtomicBool = AtomicBool::new(false);

pub fn set_verbose(on: bool) {
    VERBOSE.store(on, Ordering::Relaxed);
}

pub fn verbose_enabled() -> bool {
    VERBOSE.load(Ordering::Relaxed)
}

/// True when stdout is a terminal that can take ANSI. iSH's terminal can; a
/// redirect to a file should not collect escape codes.
fn styled() -> bool {
    io::stdout().is_terminal()
}

fn paint(code: &str, text: &str) -> String {
    if styled() {
        format!("\x1b[{code}m{text}\x1b[0m")
    } else {
        text.to_string()
    }
}

/// A stage banner, printed before the work starts and flushed immediately.
///
/// The flush matters: iSH gets roughly 1–2 seconds of execution per return to
/// the foreground, and a line still sitting in a buffer when it is suspended
/// makes the *previous* stage look like the one that hung.
pub fn stage(n: usize, total: usize, what: &str) {
    print!("{} {}\n", paint("1;36", &format!("[{n}/{total}]")), what);
    let _ = io::stdout().flush();
}

pub fn info(msg: &str) {
    println!("      {msg}");
    let _ = io::stdout().flush();
}

pub fn ok(msg: &str) {
    println!("      {} {msg}", paint("1;32", "OK"));
    let _ = io::stdout().flush();
}

pub fn warn(msg: &str) {
    println!("      {} {msg}", paint("1;33", "!!"));
    let _ = io::stdout().flush();
}

/// Detail that is useful only when diagnosing. Suppressed unless `--verbose`.
pub fn detail(msg: &str) {
    if verbose_enabled() {
        println!("      {} {msg}", paint("2", "··"));
        let _ = io::stdout().flush();
    }
}

/// Report a failure the way the spec asks: the actionable sentence always, the
/// raw cause only on the verbose channel.
pub fn failure(advice: &str, raw: &str) {
    eprintln!();
    eprintln!("{} {advice}", paint("1;31", "Stopped:"));
    if verbose_enabled() {
        eprintln!("      {} {raw}", paint("2", "cause:"));
    } else {
        eprintln!("      {}", paint("2", "re-run with --verbose to see the underlying error"));
    }
    let _ = io::stderr().flush();
}

pub fn banner(version: &str) {
    println!();
    println!("{} {}", paint("1;35", "siboot"), paint("2", version));
    println!("{}", paint("2", "installs SideInstaller onto this iPhone, using your own Apple account"));
    println!();
    println!(
        "{}",
        paint("1;33", "Keep iSH in the foreground. iOS suspends it within a second or two of")
    );
    println!("{}", paint("1;33", "leaving, and every step here stalls while it is suspended."));
    println!();
    let _ = io::stdout().flush();
}
