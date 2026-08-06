//! Forwards `tracing` output, idevice's included, to a C callback supplied by
//! Swift, so its protocol-level logs reach the app's console verbatim.
//! Timestamps are left off, since the Swift console adds its own.

use std::ffi::{c_char, c_void, CString};
use std::io::Write;
use std::sync::OnceLock;

use tracing_subscriber::fmt::MakeWriter;

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

/// Install the global subscriber, returning 1 if one already exists.
pub fn init(cb: LogCallback, ctx: *mut c_void) -> i32 {
    if SINK.set(Sink { cb, ctx }).is_err() {
        return 1;
    }

    let subscriber = tracing_subscriber::fmt()
        .with_writer(CbMakeWriter)
        .with_ansi(false)
        .without_time()
        .with_target(true)
        .with_level(true)
        // DEBUG, so idevice's protocol-level logs are visible.
        .with_max_level(tracing::Level::DEBUG)
        .finish();

    if tracing::subscriber::set_global_default(subscriber).is_err() {
        return 1;
    }
    true_emit("logging initialised (idevice tracing -> FFI callback)");
    0
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
