//! The payloads a Cryptex1 DeveloperDiskImage install needs, read out of an
//! unpacked DDI `Restore` directory.

use std::path::{Path, PathBuf};

use crate::{
    IdeviceError,
    xpc::{Dictionary, XPCObject},
};

use super::CryptexdError;

/// The four payloads and the parameters needed to install a Cryptex1 image.
#[derive(Debug, Clone)]
pub struct Cryptex1Assets {
    pub image: Vec<u8>,
    pub trustcache: Vec<u8>,
    pub info: Vec<u8>,
    pub volumehash: Vec<u8>,
    /// The build identity the payloads came from, i.e. the argument for
    /// [`TSSRequest::add_cryptex1_tags`](crate::tss::TSSRequest::add_cryptex1_tags).
    pub build_identity: plist::Dictionary,
}

const PAYLOAD_KEYS: [&str; 4] = [
    "Cryptex1,GenericDmg",
    "Cryptex1,GenericTrustCache",
    "Cryptex1,CryptexInfoPlist",
    "Cryptex1,GenericVolume",
];

impl Cryptex1Assets {
    /// Loads the payloads from an unpacked DDI `Restore` directory.
    #[cfg(not(target_arch = "wasm32"))]
    pub async fn load(restore_dir: impl AsRef<Path>) -> Result<Self, IdeviceError> {
        let restore_dir = restore_dir.as_ref();
        let manifest_path = restore_dir.join("BuildManifest.plist");
        let manifest = tokio::fs::read(&manifest_path).await.map_err(|e| {
            CryptexdError::BadDdiBundle(format!("cannot read {}: {e}", manifest_path.display()))
        })?;
        let manifest: plist::Dictionary = plist::from_bytes(&manifest)?;
        let build_identity = crate::tss::select_cryptex_build_identity(&manifest)?.clone();

        let mut payloads = Vec::with_capacity(PAYLOAD_KEYS.len());
        for key in PAYLOAD_KEYS {
            let path = restore_dir.join(payload_path(&build_identity, key)?);
            payloads.push(tokio::fs::read(&path).await.map_err(|e| {
                CryptexdError::BadDdiBundle(format!("cannot read {}: {e}", path.display()))
            })?);
        }
        let mut payloads = payloads.into_iter();

        Ok(Self {
            image: payloads.next().expect("four payloads read above"),
            trustcache: payloads.next().expect("four payloads read above"),
            info: payloads.next().expect("four payloads read above"),
            volumehash: payloads.next().expect("four payloads read above"),
            build_identity,
        })
    }

    /// Builds the assets from payloads the caller already has in memory, e.g.
    /// from an archive or a download.
    pub fn from_parts(
        image: Vec<u8>,
        trustcache: Vec<u8>,
        info: Vec<u8>,
        volumehash: Vec<u8>,
        build_identity: plist::Dictionary,
    ) -> Self {
        Self {
            image,
            trustcache,
            info,
            volumehash,
            build_identity,
        }
    }

    /// Handle (not index) of the nonce domain this cryptex is personalized
    /// against, i.e. the identity's `Cryptex1,NonceDomain`.
    pub fn nonce_domain(&self) -> Result<u64, IdeviceError> {
        self.build_identity
            .get("Cryptex1,NonceDomain")
            .and_then(|v| v.as_unsigned_integer())
            .ok_or_else(|| {
                CryptexdError::BadDdiBundle("build identity has no Cryptex1,NonceDomain".into())
                    .into()
            })
    }

    pub fn cryptex1_properties(&self) -> Result<Dictionary, IdeviceError> {
        fn uint(
            identity: &plist::Dictionary,
            key: &'static str,
        ) -> Result<XPCObject, IdeviceError> {
            identity
                .get(key)
                .and_then(|v| v.as_unsigned_integer())
                .map(XPCObject::UInt64)
                .ok_or_else(|| {
                    CryptexdError::BadDdiBundle(format!("build identity has no unsigned {key}"))
                        .into()
                })
        }

        fn passthrough(
            identity: &plist::Dictionary,
            key: &'static str,
        ) -> Result<XPCObject, IdeviceError> {
            identity
                .get(key)
                .map(|v| XPCObject::from(v.clone()))
                .ok_or_else(|| {
                    CryptexdError::BadDdiBundle(format!("build identity has no {key}")).into()
                })
        }

        let identity = &self.build_identity;
        let mut properties = Dictionary::new();
        properties.insert(
            "Cryptex1,UseProductClass".into(),
            passthrough(identity, "Cryptex1,UseProductClass")?,
        );
        properties.insert("MountedCryptex".into(), XPCObject::Bool(false));
        properties.insert(
            "Cryptex1,SubType".into(),
            uint(identity, "Cryptex1,SubType")?,
        );
        properties.insert(
            "Cryptex1,NonceDomain".into(),
            uint(identity, "Cryptex1,NonceDomain")?,
        );
        properties.insert(
            "Cryptex1,Version".into(),
            passthrough(identity, "Cryptex1,Version")?,
        );
        // The daemon calls it PreauthVersion; the manifest spells it out.
        properties.insert(
            "Cryptex1,PreauthVersion".into(),
            passthrough(identity, "Cryptex1,PreauthorizationVersion")?,
        );
        Ok(properties)
    }
}

fn payload_path(
    build_identity: &plist::Dictionary,
    key: &'static str,
) -> Result<PathBuf, IdeviceError> {
    build_identity
        .get("Manifest")
        .and_then(|m| m.as_dictionary())
        .and_then(|m| m.get(key))
        .and_then(|e| e.as_dictionary())
        .and_then(|e| e.get("Info"))
        .and_then(|i| i.as_dictionary())
        .and_then(|i| i.get("Path"))
        .and_then(|p| p.as_string())
        .map(PathBuf::from)
        .ok_or_else(|| {
            CryptexdError::BadDdiBundle(format!("build manifest has no path for {key}")).into()
        })
}
