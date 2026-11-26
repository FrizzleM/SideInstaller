//! Errors specific to `cryptexd`.

use thiserror::Error;

/// Failures talking to the device's `cryptexd`.
#[derive(Error, Debug)]
#[non_exhaustive]
pub enum CryptexdError {
    /// The daemon rejected a routine, either with a `cferr` or a non-zero
    /// device-side errno.
    #[error("cryptexd routine `{routine}` failed: {detail}")]
    RoutineFailed { routine: String, detail: String },

    /// A field the reply was required to contain was absent.
    #[error("cryptexd reply missing required field `{0}`")]
    MissingField(&'static str),

    /// A nonce structure was too short to hold the nonce it declared.
    #[error("cryptexd returned a malformed {0}-byte nonce structure")]
    MalformedNonce(usize),

    /// The DDI bundle on disk didn't hold what a cryptex install needs.
    #[error("developer disk image bundle is unusable: {0}")]
    BadDdiBundle(String),
}

impl CryptexdError {
    pub fn sub_code(&self) -> i32 {
        match self {
            Self::RoutineFailed { .. } => 1,
            Self::MissingField(_) => 2,
            Self::MalformedNonce(_) => 3,
            Self::BadDdiBundle(_) => 4,
        }
    }
}
