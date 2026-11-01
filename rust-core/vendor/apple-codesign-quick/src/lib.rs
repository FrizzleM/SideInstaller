pub mod bundle;
pub mod error;
mod file_bytes;
pub mod macho;
pub mod provisioning;
pub mod rustcrypto_cms;
pub mod signature;

pub use bundle::{Bundle, BundleSigningSettings, CodeResourcesMaps, sign_bundle};
pub use error::{CodeSignError, Result};
pub use macho::{
    DEFAULT_CMS_BLOB_RESERVATION, MachOSigningConfig, sign_macho_data, sign_macho_file,
};
pub use provisioning::ProvisioningProfile;
pub use rustcrypto_cms::RustCryptoCmsSigner;
pub use signature::{CmsSigner, CmsSigningRequest, EncodedCodeDirectory, HashAlgorithm};
