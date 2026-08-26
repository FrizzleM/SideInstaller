//! One failure type, shaped by the rule that an error names the thing the user
//! can change while the raw cause goes to the verbose channel.
//!
//! `DeviceConnection.tunnelAdvice` in the iOS app makes the same split. The
//! difference here is that there is no UI to put the advice in, so the two
//! halves travel together and `ui::failure` decides which to print.

use std::fmt;

#[derive(Debug)]
pub struct Fail {
    /// What the user can do about it. Always shown.
    pub advice: String,
    /// The underlying protocol or library error. Shown only with `--verbose`.
    pub raw: String,
}

impl Fail {
    pub fn new(advice: impl Into<String>, raw: impl Into<String>) -> Self {
        Self { advice: advice.into(), raw: raw.into() }
    }
}

impl fmt::Display for Fail {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.advice)
    }
}

pub type Result<T> = std::result::Result<T, Fail>;

/// Attach advice to any error, keeping its own text as the raw cause.
#[allow(dead_code)] // used from step 2 onwards
pub trait Advise<T> {
    fn advise(self, advice: impl Into<String>) -> Result<T>;
}

impl<T, E: std::error::Error> Advise<T> for std::result::Result<T, E> {
    fn advise(self, advice: impl Into<String>) -> Result<T> {
        self.map_err(|e| Fail::new(advice, chain(&e)))
    }
}

/// Render an error together with everything it wraps.
///
/// `idevice`'s errors need this: `IdeviceError::Socket` displays as the fixed
/// string "device socket io failed" and keeps the `io::Error` — the part that
/// says *reset* rather than *timeout* — only in `source()`. Without walking the
/// chain the verbose channel prints a sentence that names no cause at all.
pub fn chain(e: &dyn std::error::Error) -> String {
    let mut out = e.to_string();
    let mut source = e.source();
    while let Some(s) = source {
        out.push_str(&format!(": {s}"));
        source = s.source();
    }
    out
}

impl<T> Advise<T> for Option<T> {
    fn advise(self, advice: impl Into<String>) -> Result<T> {
        self.ok_or_else(|| Fail::new(advice, "value was absent"))
    }
}
