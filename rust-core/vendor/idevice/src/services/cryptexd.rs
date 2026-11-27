//! `cryptexd` over RemoteXPC (`com.apple.security.cryptexd.remote`).

use std::borrow::Cow;

use tracing::debug;

use crate::{
    IdeviceError, ReadWrite, RemoteXpcClient,
    darwin_errno::describe_errno,
    obf,
    xpc::{Dictionary, XPCObject},
};

pub mod assets;
pub mod errors;
pub use assets::Cryptex1Assets;
pub use errors::CryptexdError;

/// Capability tags cryptexd advertises in the RSD handshake's `Features`.
pub const FEATURE_CRYPTEX_INSTALL: &str = "CryptexInstall";
pub const FEATURE_READ_IDENTIFIERS: &str = "ReadIdentifiers";

pub const NONCE_DOMAIN_CRYPTEX: u64 = 2;

pub const CLIENT_VERSION: u64 = 3;
pub const DDI_IMAGE_TYPE_INDEX: i64 = 10;
pub const DDI_PERSISTENCE: u64 = 2;
pub const DDI_NONCE_PERSISTENCE: u64 = 1;

/// Which nonce domain a `get-nonce` / `roll-nonce` request refers to.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NonceDomain {
    Index(u64),
    Handle(u64),
}

impl NonceDomain {
    fn to_argv(self) -> Dictionary {
        let mut argv = Dictionary::new();
        match self {
            NonceDomain::Index(index) => {
                argv.insert("nonce-domain".into(), XPCObject::UInt64(index));
            }
            NonceDomain::Handle(handle) => {
                argv.insert("nonce-domain-handle".into(), XPCObject::UInt64(handle));
            }
        }
        argv
    }
}

impl Default for NonceDomain {
    fn default() -> Self {
        NonceDomain::Index(NONCE_DOMAIN_CRYPTEX)
    }
}

/// A cryptex currently installed on the device, e.g. the mounted
/// DeveloperDiskImage.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstalledCryptex {
    pub identifier: String,
    pub version: String,
}

/// The payloads and parameters one `install` needs.
#[derive(Debug, Clone)]
pub struct CryptexInstallRequest {
    /// The cryptex disk image, i.e. the manifest's `Cryptex1,GenericDmg`.
    pub image: Vec<u8>,
    /// `Cryptex1,GenericTrustCache`.
    pub trustcache: Vec<u8>,
    /// The Cryptex1 personalization ticket.
    pub im4m: Vec<u8>,
    /// `Cryptex1,CryptexInfoPlist`, which names and versions the cryptex.
    pub info: Vec<u8>,
    /// `Cryptex1,GenericVolume` root hash.
    pub volumehash: Vec<u8>,
    /// The `Cryptex1,*` parameters from the build identity. Their integers must
    /// be uint64: int64 is rejected with `Cryptex1,NonceDomain [79:
    /// Inappropriate file type or format]`.
    pub cryptex1_properties: Dictionary,
    pub image_type_index: i64,
    pub persistence: u64,
    pub nonce_persistence: u64,
    pub auth: u64,
}

impl CryptexInstallRequest {
    /// A request with the four `DDI` defaults Xcode uses
    /// ([`DDI_IMAGE_TYPE_INDEX`], [`DDI_PERSISTENCE`],
    /// [`DDI_NONCE_PERSISTENCE`], `auth = 0`).
    pub fn new(
        image: Vec<u8>,
        trustcache: Vec<u8>,
        im4m: Vec<u8>,
        info: Vec<u8>,
        volumehash: Vec<u8>,
        cryptex1_properties: Dictionary,
    ) -> Self {
        Self {
            image,
            trustcache,
            im4m,
            info,
            volumehash,
            cryptex1_properties,
            image_type_index: DDI_IMAGE_TYPE_INDEX,
            persistence: DDI_PERSISTENCE,
            nonce_persistence: DDI_NONCE_PERSISTENCE,
            auth: 0,
        }
    }
}

#[derive(Debug)]
pub struct CryptexdClient<R: ReadWrite> {
    inner: RemoteXpcClient<R>,
}

#[cfg(feature = "rsd")]
impl crate::RsdService for CryptexdClient<Box<dyn ReadWrite>> {
    fn rsd_service_name() -> Cow<'static, str> {
        obf!("com.apple.security.cryptexd.remote")
    }

    async fn from_stream(stream: Box<dyn ReadWrite>) -> Result<Self, IdeviceError> {
        Self::new(stream).await
    }
}

impl<R: ReadWrite> CryptexdClient<R> {
    pub async fn new(stream: R) -> Result<Self, IdeviceError> {
        let mut inner = RemoteXpcClient::new(stream).await?;
        inner.do_handshake().await?;
        Ok(Self { inner })
    }

    /// Sends one `routine` request and returns its `argv` payload.
    ///
    /// Consumes the client: the daemon closes the connection after a routine.
    pub async fn invoke(
        mut self,
        routine: &str,
        argv: Dictionary,
    ) -> Result<Option<plist::Value>, IdeviceError> {
        let mut req = Dictionary::new();
        req.insert("routine".into(), XPCObject::String(routine.to_string()));
        req.insert("argv".into(), XPCObject::Dictionary(argv));

        self.inner.send_object(req, true).await?;
        let res = self.inner.recv().await?;
        unwrap_reply(routine, res)
    }

    /// Reads the device's AppleImage4 chip instance, which identifies it in a
    /// Cryptex1 personalization request.
    ///
    /// The keys are the daemon's `img4_chip_*` names, e.g. `img4_chip_chip`
    /// (ChipID), `img4_chip_bord` (BoardID) and `img4_chip_ecid` (ECID).
    pub async fn read_personalization_identifiers(self) -> Result<plist::Dictionary, IdeviceError> {
        let res = self
            .invoke("read-personalization-id", Dictionary::new())
            .await?;
        res.and_then(plist::Value::into_dictionary)
            .ok_or_else(|| CryptexdError::MissingField("argv").into())
    }

    /// Lists the cryptexes installed on the device.
    pub async fn copy_installed(self) -> Result<Vec<InstalledCryptex>, IdeviceError> {
        let res = self.invoke("copy-installed", Dictionary::new()).await?;
        let Some(res) = res.and_then(plist::Value::into_dictionary) else {
            return Ok(Vec::new());
        };
        let Some(array) = res.get("remote-cryptex-array").and_then(|v| v.as_array()) else {
            return Ok(Vec::new());
        };

        Ok(array
            .iter()
            .filter_map(|entry| {
                let entry = entry.as_dictionary()?;
                Some(InstalledCryptex {
                    identifier: entry
                        .get("remote-cryptex-identifier")?
                        .as_string()?
                        .to_string(),
                    version: entry
                        .get("remote-cryptex-version")?
                        .as_string()?
                        .to_string(),
                })
            })
            .collect())
    }

    /// Reads a nonce domain's nonce structure.
    /// [`cryptex_nonce`](Self::cryptex_nonce) for the nonce TSS wants.
    pub async fn get_nonce(self, domain: NonceDomain) -> Result<Vec<u8>, IdeviceError> {
        let res = self.invoke("get-nonce", domain.to_argv()).await?;
        res.as_ref()
            .and_then(plist::Value::as_dictionary)
            .and_then(|d| d.get("nonce"))
            .and_then(|v| v.as_data())
            .map(<[u8]>::to_vec)
            .ok_or_else(|| CryptexdError::MissingField("nonce").into())
    }

    pub async fn cryptex_nonce(self, nonce_domain_handle: u64) -> Result<Vec<u8>, IdeviceError> {
        let blob = self
            .get_nonce(NonceDomain::Handle(nonce_domain_handle))
            .await?;
        unwrap_nonce(&blob)
    }

    /// Rolls (regenerates) a nonce domain's nonce, invalidating anything
    /// personalized against the previous one.
    pub async fn roll_nonce(mut self, domain: NonceDomain) -> Result<(), IdeviceError> {
        let mut req = Dictionary::new();
        req.insert("routine".into(), XPCObject::String("roll-nonce".into()));
        req.insert("argv".into(), XPCObject::Dictionary(domain.to_argv()));
        for (key, value) in domain.to_argv() {
            req.insert(key, value);
        }

        self.inner.send_object(req, true).await?;
        let res = self.inner.recv().await?;
        unwrap_reply("roll-nonce", res)?;
        Ok(())
    }

    /// Uninstalls a cryptex by the identifier [`copy_installed`](Self::copy_installed)
    /// reports, optionally scoped to one version.
    pub async fn uninstall(
        self,
        identifier: &str,
        version: Option<&str>,
    ) -> Result<(), IdeviceError> {
        let mut argv = Dictionary::new();
        argv.insert(
            "remote-cryptex-identifier".into(),
            XPCObject::String(identifier.to_string()),
        );
        if let Some(version) = version {
            argv.insert(
                "remote-cryptex-version".into(),
                XPCObject::String(version.to_string()),
            );
        }
        self.invoke("uninstall", argv).await?;
        Ok(())
    }

    /// Installs a cryptex.
    ///
    /// The five payloads are announced in the request as XPC file transfers and
    /// then pushed on their own streams; the daemon only replies once it has
    /// consumed all of them.
    pub async fn install(mut self, request: CryptexInstallRequest) -> Result<(), IdeviceError> {
        let transfers: [(&str, &[u8]); 5] = [
            ("image", &request.image),
            ("trustcache", &request.trustcache),
            ("im4m", &request.im4m),
            ("info", &request.info),
            ("volumehash", &request.volumehash),
        ];

        let mut argv = crate::xpc!({
            "auth": XPCObject::UInt64(request.auth),
            "client-version": XPCObject::UInt64(CLIENT_VERSION),
            "cryptex1-properties": XPCObject::Dictionary(request.cryptex1_properties.clone()),
            "image-type-index": XPCObject::Int64(request.image_type_index),
            "nonce-persistence": XPCObject::UInt64(request.nonce_persistence),
            "persistence": XPCObject::UInt64(request.persistence)
        })
        .to_dictionary()
        .unwrap();

        for (transfer_id, (key, payload)) in transfers.iter().enumerate() {
            let mut size = Dictionary::new();
            size.insert("s".into(), XPCObject::UInt64(payload.len() as u64));
            argv.insert(
                (*key).to_string(),
                XPCObject::FileTransfer {
                    msg_id: transfer_id as u64 + 1,
                    data: Box::new(XPCObject::Dictionary(size)),
                },
            );
        }

        let req = crate::xpc!({
            "routine": "install",
            "argv": XPCObject::Dictionary(argv)
        });
        self.inner.send_object(req, true).await?;

        for (transfer_id, (key, payload)) in transfers.iter().enumerate() {
            debug!("pushing cryptex {key} payload ({} bytes)", payload.len());
            self.inner
                .send_file_transfer(transfer_id as u64 + 1, payload)
                .await?;
        }

        let res = self.inner.recv().await?;
        unwrap_reply("install", res)?;
        Ok(())
    }
}

/// Turns a cryptexd reply into its `argv` payload, or an error.
fn unwrap_reply(
    routine: &str,
    response: plist::Value,
) -> Result<Option<plist::Value>, IdeviceError> {
    let mut response = response
        .into_dictionary()
        .ok_or(CryptexdError::MissingField("(root)"))?;

    if let Some(cferr) = response.get("cferr").and_then(|v| v.as_dictionary()) {
        let description = cferr
            .get("cferr_userinfo")
            .and_then(|v| v.as_dictionary())
            .and_then(|d| d.get("NSLocalizedDescription"))
            .and_then(|v| v.as_string())
            .map(str::to_string)
            .unwrap_or_else(|| format!("{cferr:?}"));
        let domain = cferr
            .get("cferr_domain")
            .and_then(|v| v.as_string())
            .unwrap_or("?");
        let code = cferr
            .get("cferr_code")
            .and_then(|v| v.as_signed_integer())
            .unwrap_or_default();
        return Err(CryptexdError::RoutineFailed {
            routine: routine.to_string(),
            detail: format!("{description} ({domain}: {code})"),
        }
        .into());
    }

    // Successful replies carry error=0; read-personalization-id omits the key.
    let error = response
        .get("error")
        .and_then(|v| v.as_signed_integer())
        .unwrap_or(0);
    if error != 0 {
        return Err(CryptexdError::RoutineFailed {
            routine: routine.to_string(),
            detail: describe_errno(error),
        }
        .into());
    }

    Ok(response.remove("argv"))
}

/// Extracts the nonce from cryptexd's nonce structure: a 2-byte lead, the nonce
/// itself, then its length as a little-endian `u32`.
pub fn unwrap_nonce(blob: &[u8]) -> Result<Vec<u8>, IdeviceError> {
    if blob.len() < 6 {
        return Err(CryptexdError::MalformedNonce(blob.len()).into());
    }
    let len_bytes = &blob[blob.len() - 4..];
    let len = u32::from_le_bytes([len_bytes[0], len_bytes[1], len_bytes[2], len_bytes[3]]) as usize;
    if 2 + len > blob.len() {
        return Err(CryptexdError::MalformedNonce(blob.len()).into());
    }
    Ok(blob[2..2 + len].to_vec())
}

/// Personalizes and installs the DeveloperDiskImage cryptex end to end. The
/// cryptex equivalent of the image mounter's auto-mount.
///
/// Reads the device's personalization identifiers and cryptex nonce, has Apple
/// sign a Cryptex1 ticket for them, and installs the assets, all over
/// `cryptexd` and without the image mounter. Each step opens its own connection,
/// since the daemon serves one routine per connection.
#[cfg(all(feature = "rsd", feature = "tss"))]
pub async fn install_ddi(
    provider: &mut impl crate::provider::RsdProvider,
    handshake: &mut crate::rsd::RsdHandshake,
    assets: &Cryptex1Assets,
) -> Result<InstalledCryptex, IdeviceError> {
    use crate::RsdService as _;

    async fn client<P: crate::provider::RsdProvider>(
        provider: &mut P,
        handshake: &mut crate::rsd::RsdHandshake,
    ) -> Result<CryptexdClient<Box<dyn ReadWrite>>, IdeviceError> {
        CryptexdClient::connect_rsd(provider, handshake).await
    }

    let chip_instance = client(provider, handshake)
        .await?
        .read_personalization_identifiers()
        .await?;
    let nonce = client(provider, handshake)
        .await?
        .cryptex_nonce(assets.nonce_domain()?)
        .await?;

    let mut request = crate::tss::TSSRequest::new();
    request.add_cryptex1_tags(&assets.build_identity, &chip_instance, &nonce)?;
    let response = request
        .send()
        .await?
        .into_dictionary()
        .ok_or(CryptexdError::MissingField("(TSS response)"))?;
    // Cryptex1 responses carry the ticket under its own key on current releases
    // and under the AP key on older ones.
    let im4m = response
        .get("Cryptex1,Ticket")
        .or_else(|| response.get("ApImg4Ticket"))
        .and_then(|v| v.as_data())
        .ok_or(CryptexdError::MissingField("Cryptex1,Ticket"))?
        .to_vec();

    client(provider, handshake)
        .await?
        .install(CryptexInstallRequest::new(
            assets.image.clone(),
            assets.trustcache.clone(),
            im4m,
            assets.info.clone(),
            assets.volumehash.clone(),
            assets.cryptex1_properties()?,
        ))
        .await?;

    installed_ddi(provider, handshake)
        .await?
        .ok_or(IdeviceError::ImageNotMounted)
}

/// The installed DeveloperDiskImage cryptex, if there is one.
#[cfg(feature = "rsd")]
pub async fn installed_ddi(
    provider: &mut impl crate::provider::RsdProvider,
    handshake: &mut crate::rsd::RsdHandshake,
) -> Result<Option<InstalledCryptex>, IdeviceError> {
    use crate::{RsdService as _, obf};

    let client: CryptexdClient<Box<dyn ReadWrite>> =
        CryptexdClient::connect_rsd(provider, handshake).await?;
    Ok(client
        .copy_installed()
        .await?
        .into_iter()
        .find(|c| c.identifier == obf!("com.apple.MobileAsset.DDI")))
}
