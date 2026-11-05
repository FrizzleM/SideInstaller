//! Forwards `tracing` output, idevice's included, to a C callback supplied by
//! Swift, so its protocol-level logs reach the app's console verbatim.
//! Timestamps are left off, since the Swift console adds its own.
//!
//! idevice logs every plist, XPC message and pairing step it exchanges at
//! DEBUG, so it's held to INFO unless Settings › Verbose logging is on
//! (`set_verbose`). Everything else logs at DEBUG either way.

use std::ffi::{c_char, c_void, CString};
use std::io::Write;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::OnceLock;

use tracing::level_filters::LevelFilter;
use tracing_subscriber::filter::Targets;
use tracing_subscriber::fmt::MakeWriter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::{reload, Registry};

/// `void (*)(void *ctx, const char *msg)` — may be null.
pub type LogCallback = Option<extern "C" fn(ctx: *mut c_void, msg: *const c_char)>;

struct Sink {
    cb: LogCallback,
    ctx: *mut c_void,
}

// Both are read-only, the ctx outlives the process, and the callback itself
// dispatches to the main queue, so it's thread-safe.
unsafe impl Send for Sink {}
unsafe impl Sync for Sink {}

static SINK: OnceLock<Sink> = OnceLock::new();

/// Whether idevice's DEBUG lines get through. Read by `init`, so it can be
/// set before or after.
static VERBOSE: AtomicBool = AtomicBool::new(false);

/// Swaps the filter once the subscriber is installed.
static FILTER: OnceLock<reload::Handle<Targets, Registry>> = OnceLock::new();

/// What reaches the log. `Targets` matches by prefix, so "idevice" covers
/// idevice-ffi too.
fn targets(verbose: bool) -> Targets {
    let idevice = if verbose { LevelFilter::DEBUG } else { LevelFilter::INFO };
    Targets::new()
        .with_default(LevelFilter::DEBUG)
        .with_target("idevice", idevice)
}

/// Install the global subscriber, returning 1 if one already exists.
pub fn init(cb: LogCallback, ctx: *mut c_void) -> i32 {
    if SINK.set(Sink { cb, ctx }).is_err() {
        return 1;
    }

    let (filter, handle) = reload::Layer::new(targets(VERBOSE.load(Ordering::SeqCst)));
    let format = tracing_subscriber::fmt::layer()
        .with_writer(CbMakeWriter)
        .with_ansi(false)
        .without_time()
        .with_target(true)
        .with_level(true);
    let subscriber = Registry::default().with(filter).with(format);

    if tracing::subscriber::set_global_default(subscriber).is_err() {
        return 1;
    }
    let _ = FILTER.set(handle);
    // A switch flipped between the load above and `FILTER.set` would be lost.
    apply_verbose();
    true_emit("logging initialised (idevice tracing -> FFI callback)");
    0
}

/// Let idevice's DEBUG lines through, or hold them back again.
pub fn set_verbose(verbose: bool) {
    VERBOSE.store(verbose, Ordering::SeqCst);
    apply_verbose();
}

fn apply_verbose() {
    if let Some(handle) = FILTER.get() {
        // Fails only once the subscriber is gone, and a global one never goes.
        let _ = handle.reload(targets(VERBOSE.load(Ordering::SeqCst)));
    }
}

fn true_emit(msg: &str) {
    emit_line(msg.as_bytes());
}

/// Push one formatted line to Swift, replacing NULs so `CString` can't fail.
fn emit_line(buf: &[u8]) {
    let Some(sink) = SINK.get() else { return };
    let Some(cb) = sink.cb else { return };

    let trimmed = match buf.last() {
        Some(b'\n') => &buf[..buf.len() - 1],
        _ => buf,
    };
    let mut bytes: Vec<u8> = trimmed.to_vec();
    for b in bytes.iter_mut() {
        if *b == 0 {
            *b = b' ';
        }
    }
    if let Ok(c) = CString::new(bytes) {
        cb(sink.ctx, c.as_ptr());
    }
}

/// `MakeWriter` that hands the fmt layer a fresh `CbWriter` per event.
struct CbMakeWriter;

impl<'a> MakeWriter<'a> for CbMakeWriter {
    type Writer = CbWriter;
    fn make_writer(&'a self) -> Self::Writer {
        CbWriter
    }
}

struct CbWriter;

impl Write for CbWriter {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        // The fmt layer writes one complete event per call.
        emit_line(buf);
        Ok(buf.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tracing::Level;

    #[test]
    fn idevice_debug_needs_verbose() {
        let afc = "idevice::services::afc::packet";
        let quiet = targets(false);
        assert!(!quiet.would_enable(afc, &Level::DEBUG));
        assert!(quiet.would_enable(afc, &Level::INFO));
        assert!(!quiet.would_enable("idevice_ffi::pairing_file", &Level::DEBUG));
        // The rest of the core keeps its DEBUG lines.
        assert!(quiet.would_enable("sideinstaller_ffi::account", &Level::DEBUG));
        assert!(quiet.would_enable("isideload::auth::apple_account", &Level::DEBUG));
        assert!(!quiet.would_enable("isideload::auth::apple_account", &Level::TRACE));

        let verbose = targets(true);
        assert!(verbose.would_enable(afc, &Level::DEBUG));
        assert!(!verbose.would_enable(afc, &Level::TRACE));
    }
}
