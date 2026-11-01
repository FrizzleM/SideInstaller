use std::path::PathBuf;

#[derive(Debug, thiserror::Error)]
pub enum CodeSignError {
    #[error("I/O error for {path}: {source}")]
    Io {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("plist error: {0}")]
    Plist(#[from] plist::Error),

    #[error("bundle is missing Info.plist: {0}")]
    MissingInfoPlist(PathBuf),

    #[error("Info.plist is missing string key {0}")]
    MissingInfoString(&'static str),

    #[error("invalid UTF-8 path inside bundle: {0}")]
    InvalidBundlePath(PathBuf),

    #[error("argument error: {0}")]
    Argument(String),

    #[error("Mach-O error in {path}: {message}")]
    MachO { path: PathBuf, message: String },

    #[error(
        "Mach-O in {path} has no safe header padding for a new LC_CODE_SIGNATURE load command; requested signature reservation is {signature_len} bytes"
    )]
    NeedsCodeSignatureAllocation { path: PathBuf, signature_len: usize },

    #[error("unsupported entitlement value for key {0}")]
    UnsupportedEntitlement(String),

    #[error("CMS signing error: {0}")]
    Cms(String),

    #[error("provisioning profile error: {0}")]
    ProvisioningProfile(String),

    #[error("CMS signature blob is {actual} bytes, exceeding the {reserved} byte reservation")]
    SignatureTooLarge { actual: usize, reserved: usize },
}

impl CodeSignError {
    pub(crate) fn io(path: impl Into<PathBuf>, source: std::io::Error) -> Self {
        Self::Io {
            path: path.into(),
            source,
        }
    }

    pub(crate) fn macho(path: impl Into<PathBuf>, message: impl Into<String>) -> Self {
        Self::MachO {
            path: path.into(),
            message: message.into(),
        }
    }

    pub(crate) fn cms(message: impl Into<String>) -> Self {
        Self::Cms(message.into())
    }

    pub(crate) fn provisioning_profile(message: impl Into<String>) -> Self {
        Self::ProvisioningProfile(message.into())
    }
}

pub type Result<T> = std::result::Result<T, CodeSignError>;
