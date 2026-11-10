//! Terminal output: staged status lines, a verbose channel, and prompts.
//!
//! Kept from ../ish-bootstrap: every stage prints its line *before* the work
//! starts, so a stall is attributable to a named step, and errors name the
//! thing the user can change while the raw cause goes to the verbose channel.

use std::io::{self, BufRead, IsTerminal, Write};
use std::sync::atomic::{AtomicBool, Ordering};

use crate::Advertiser;

static VERBOSE: AtomicBool = AtomicBool::new(false);

pub fn set_verbose(on: bool) {
    VERBOSE.store(on, Ordering::Relaxed);
}

pub fn verbose_enabled() -> bool {
    VERBOSE.load(Ordering::Relaxed)
}

/// Minis's terminal takes ANSI; a redirect to a file shouldn't collect it.
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

fn flush() {
    let _ = io::stdout().flush();
}

/// A stage banner, printed before the work starts and flushed at once.
pub fn stage(n: usize, total: usize, what: &str) {
    println!();
    println!("{} {}", paint("1;36", &format!("[{n}/{total}]")), what);
    flush();
}

pub fn info(msg: &str) {
    println!("      {msg}");
    flush();
}

pub fn ok(msg: &str) {
    println!("      {} {msg}", paint("1;32", "OK"));
    flush();
}

pub fn warn(msg: &str) {
    println!("      {} {msg}", paint("1;33", "!!"));
    flush();
}

/// Useful only when diagnosing. Shown with `--verbose`.
pub fn detail(msg: &str) {
    if verbose_enabled() {
        println!("      {} {msg}", paint("2", "··"));
        flush();
    }
}

/// Numbered steps for the user to do on the iPhone.
pub fn steps(lines: &[String]) {
    for (i, line) in lines.iter().enumerate() {
        println!("      {} {line}", paint("1", &format!("{}.", i + 1)));
    }
    flush();
}

/// The pairing code, big enough to read at a glance: "123 456".
pub fn pin(code: &str) {
    let spaced = if code.len() == 6 {
        format!("{} {}", &code[..3], &code[3..])
    } else {
        code.into()
    };
    println!();
    println!("      {}", paint("1", "Type this code into Settings:"));
    println!();
    println!("            {}", paint("1;7", &format!("  {spaced}  ")));
    println!();
    flush();
}

/// A progress line that rewrites itself on a terminal.
pub fn progress(label: &str, percent: u64) {
    if styled() {
        print!("\r      {label} {percent:>3}%");
        if percent >= 100 {
            println!();
        }
    } else if percent.is_multiple_of(25) {
        println!("      {label} {percent}%");
    }
    flush();
}

/// Report a failure: the advice always, the raw cause with `--verbose`.
pub fn failure(advice: &str, raw: &str) {
    eprintln!();
    eprintln!("{} {advice}", paint("1;31", "Stopped:"));
    if verbose_enabled() {
        eprintln!("      {} {raw}", paint("2", "cause:"));
    } else if !raw.is_empty() {
        eprintln!(
            "      {}",
            paint("2", "run again with --verbose to see the underlying error")
        );
    }
    let _ = io::stderr().flush();
}

/// Ask for a line on the terminal. None at end of input.
pub fn ask(prompt: &str) -> Option<String> {
    print!("      {prompt}");
    flush();
    let mut line = String::new();
    match io::stdin().lock().read_line(&mut line) {
        Ok(0) | Err(_) => None,
        Ok(_) => Some(line.trim().to_string()),
    }
}

pub fn banner(version: &str, advertiser: Advertiser) {
    println!();
    println!("{} {}", paint("1;35", "siboot"), paint("2", version));
    println!(
        "{}",
        paint(
            "2",
            "installs SideInstaller onto this iPhone, with your own Apple Account"
        )
    );
    if advertiser == Advertiser::Minis {
        println!();
        println!(
            "{}",
            paint(
                "1;33",
                "Keep Minis open: you can switch to Settings when asked, but don't"
            )
        );
        println!(
            "{}",
            paint("1;33", "swipe Minis away until siboot says it's done.")
        );
    }
    flush();
}
