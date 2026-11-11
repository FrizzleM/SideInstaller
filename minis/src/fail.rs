//! One failure type: what the user can change, and the raw cause for
//! `--verbose`.

use std::fmt;

#[derive(Debug)]
pub struct Fail {
    /// What the user can do about it. Always shown.
    pub advice: String,
    /// The underlying protocol or library error. Shown with `--verbose`.
    pub raw: String,
}

impl Fail {
    pub fn new(advice: impl Into<String>, raw: impl Into<String>) -> Self {
        Self {
            advice: advice.into(),
            raw: raw.into(),
        }
    }
}

impl fmt::Display for Fail {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.advice)
    }
}

pub type Result<T> = std::result::Result<T, Fail>;

/// An error with everything it wraps. idevice's `IdeviceError::Socket` shows
/// only "device socket io failed" and keeps the `io::Error` that says *reset*
/// or *timeout* in `source()`.
pub fn chain(e: &dyn std::error::Error) -> String {
    let mut out = e.to_string();
    let mut source = e.source();
    while let Some(s) = source {
        out.push_str(&format!(": {s}"));
        source = s.source();
    }
    out
}
