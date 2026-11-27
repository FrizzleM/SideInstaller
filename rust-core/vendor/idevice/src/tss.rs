//! Ticket Signature Server (TSS) Client
//!
//! Provides functionality for interacting with Apple's TSS service to:
//! - Request personalized firmware components
//! - Apply restore request rules for device-specific parameters
//! - Handle cryptographic signing operations

use plist::Value;
use plist_macro::plist_to_xml_bytes;
use tracing::{debug, warn};

use crate::IdeviceError;

/// TSS client version string sent in requests
const TSS_CLIENT_VERSION_STRING: &str = "libauthinstall-1033.0.2";
/// Apple's TSS endpoint URL
const TSS_CONTROLLER_ACTION_URL: &str = "http://gs.apple.com/TSS/controller?action=2";

/// Represents a TSS request to Apple's signing server
#[derive(Debug)]
pub struct TSSRequest {
    /// The underlying plist dictionary containing request parameters
    inner: plist::Dictionary,
}

impl TSSRequest {
    /// Creates a new TSS request with default headers
    ///
    /// Initializes with:
    /// - Host platform info
    /// - Client version string
    /// - Random UUID for request identification
    pub fn new() -> Self {
        let inner = plist_macro::plist!(dict {
            "@HostPlatformInfo": "mac",
            "@VersionInfo": TSS_CLIENT_VERSION_STRING,
            "@UUID": uuid::Uuid::new_v4().to_string().to_uppercase()
        });
        Self { inner }
    }

    /// Inserts a key-value pair into the TSS request
    ///
    /// # Arguments
    /// * `key` - The parameter name
    /// * `val` - The parameter value (will be converted to plist::Value)
    pub fn insert(&mut self, key: impl Into<String>, val: impl Into<Value>) {
        let key = key.into();
        let val = val.into();
        self.inner.insert(key, val);
    }

    /// Sends the TSS request to Apple's servers
    ///
    /// # Returns
    /// The parsed plist response from Apple
    ///
    /// # Errors
    /// Returns `IdeviceError` if:
    /// - The request fails
    /// - The response is malformed
    /// - Apple returns a non-success status
    ///
    /// # Example
    /// ```rust
    /// let mut request = TSSRequest::new();
    /// request.insert("ApBoardID", board_id);
    /// request.insert("ApChipID", chip_id);
    /// let response = request.send().await?;
    /// ```
    pub async fn send(&self) -> Result<plist::Value, IdeviceError> {
        debug!(
            "Sending TSS request: {}",
            crate::pretty_print_dictionary(&self.inner)
        );
        let client = reqwest::Client::new();

        let res = client
            .post(TSS_CONTROLLER_ACTION_URL)
            .header("Cache-Control", "no-cache")
            .header("Content-type", "text/xml; charset=\"utf-8\"")
            .header("User-Agent", "InetURL/1.0")
            .body(plist_to_xml_bytes(&self.inner))
            .send()
            .await?
            .text()
            .await?;

        debug!("Apple responded with {res}");
        let trimmed = res.trim_start_matches("STATUS=0&");
        let trimmed = trimmed.trim_start_matches("MESSAGE=");
        if !trimmed.starts_with("SUCCESS") {
            // On failure Apple returns `STATUS=<n>&MESSAGE=<text>` (no
            // REQUEST_STRING); surface it so the caller sees why it was rejected.
            let detail = res
                .split("&REQUEST_STRING=")
                .next()
                .unwrap_or(res.as_str())
                .trim();
            warn!("TSS responded with non-success value: {detail}");
            return Err(IdeviceError::UnexpectedResponse(format!(
                "TSS server responded with non-success status ({detail})"
            )));
        }
        let res = res.split("REQUEST_STRING=").collect::<Vec<&str>>();
        if res.len() < 2 {
            warn!("Response didn't contain a request string");
            return Err(IdeviceError::UnexpectedResponse(
                "TSS response missing REQUEST_STRING".into(),
            ));
        }
        Ok(plist::from_bytes(res[1].as_bytes())?)
    }

    /// Builds a Cryptex1 personalization request (`@Cryptex1,Ticket`).
    ///
    /// Cryptex1 tickets have a different shape from the AP tickets
    /// [`add_ap_tags`](Self::add_ap_tags) produces, which is why that method
    /// skips every `Cryptex1,*` key. The device is identified by `Cryptex1,UDID`
    /// alone - none of the `Ap*` tags an AP request carries appear here - and
    /// each personalized component contributes nothing but its `Digest`. The
    /// generic DMG is declared `Personalize: false` in the build manifest and is
    /// left out entirely.
    ///
    /// # Arguments
    /// * `build_identity` - the build identity whose `Info.Variant` names a
    ///   cryptex, i.e. the one carrying the `Cryptex1,*` manifest entries.
    /// * `chip_instance` - the device's AppleImage4 chip instance, as returned by
    ///   cryptexd's `read-personalization-id` routine.
    /// * `nonce` - the cryptex nonce for the identity's `Cryptex1,NonceDomain`.
    pub fn add_cryptex1_tags(
        &mut self,
        build_identity: &plist::Dictionary,
        chip_instance: &plist::Dictionary,
        nonce: &[u8],
    ) -> Result<(), IdeviceError> {
        fn required<'a>(
            dict: &'a plist::Dictionary,
            key: &'static str,
        ) -> Result<&'a Value, IdeviceError> {
            dict.get(key).ok_or_else(|| {
                IdeviceError::UnexpectedResponse(format!("cryptex identity is missing {key}"))
            })
        }

        /// Manifest values come as either an integer or a `0x`-prefixed string.
        fn as_number(value: &Value, key: &'static str) -> Result<u64, IdeviceError> {
            match value {
                Value::Integer(i) => i.as_unsigned().ok_or_else(|| {
                    IdeviceError::UnexpectedResponse(format!("{key} is not an unsigned integer"))
                }),
                Value::String(s) => {
                    let trimmed = s.trim_start_matches("0x");
                    let radix = if trimmed.len() == s.len() { 10 } else { 16 };
                    u64::from_str_radix(trimmed, radix).map_err(|_| {
                        IdeviceError::UnexpectedResponse(format!("{key} is not a number: {s}"))
                    })
                }
                _ => Err(IdeviceError::UnexpectedResponse(format!(
                    "{key} is neither an integer nor a string"
                ))),
            }
        }

        self.insert("@Cryptex1,Ticket", true);
        self.insert(
            "Cryptex1,ChipID",
            as_number(
                required(build_identity, "Cryptex1,ChipID")?,
                "Cryptex1,ChipID",
            )?,
        );
        self.insert(
            "Cryptex1,ProductClass",
            as_number(
                required(build_identity, "Cryptex1,ProductClass")?,
                "Cryptex1,ProductClass",
            )?,
        );
        for key in [
            "Cryptex1,Type",
            "Cryptex1,SubType",
            "Cryptex1,UseProductClass",
            "Cryptex1,NonceDomain",
            "Cryptex1,Version",
            "Cryptex1,PreauthorizationVersion",
        ] {
            self.insert(key, required(build_identity, key)?.clone());
        }
        self.insert("Cryptex1,Nonce", Value::Data(nonce.to_vec()));
        self.insert(
            "Cryptex1,ProductionMode",
            required(chip_instance, "img4_chip_cpro")?
                .as_boolean()
                .or_else(|| {
                    // The daemon reports the flag as an integer on some releases.
                    chip_instance
                        .get("img4_chip_cpro")
                        .and_then(|v| v.as_unsigned_integer())
                        .map(|v| v != 0)
                })
                .ok_or_else(|| {
                    IdeviceError::UnexpectedResponse("img4_chip_cpro is not a boolean".into())
                })?,
        );
        self.insert("Cryptex1,UDID", Value::Data(cryptex1_udid(chip_instance)?));
        self.insert("Cryptex1,UniqueTagList", Value::Data(Vec::new()));

        let manifest = build_identity
            .get("Manifest")
            .and_then(|m| m.as_dictionary())
            .ok_or_else(|| {
                IdeviceError::UnexpectedResponse("cryptex identity is missing Manifest".into())
            })?;
        for (key, entry) in manifest {
            if !key.starts_with("Cryptex1,") {
                continue;
            }
            let entry = match entry.as_dictionary() {
                Some(e) => e,
                None => continue,
            };
            let personalize = entry
                .get("Info")
                .and_then(|i| i.as_dictionary())
                .and_then(|i| i.get("Personalize"))
                .and_then(|p| p.as_boolean())
                .unwrap_or(false);
            if !personalize {
                debug!("skipping {key} as it is not personalized");
                continue;
            }
            let digest = entry
                .get("Digest")
                .ok_or_else(|| IdeviceError::UnexpectedResponse(format!("{key} has no Digest")))?;
            self.insert(key.clone(), crate::plist!({ "Digest": digest.clone() }));
        }

        Ok(())
    }
}

impl Default for TSSRequest {
    /// Creates a default TSS request (same as `new()`)
    fn default() -> Self {
        Self::new()
    }
}

/// Applies restore request rules to modify input parameters
///
/// # Arguments
/// * `input` - The dictionary to modify based on rules
/// * `parameters` - Device parameters to check conditions against
/// * `rules` - List of rules to apply
///
/// # Process
/// For each rule:
/// 1. Checks all conditions against the parameters
/// 2. If all conditions are met, applies the rule's actions
/// 3. Actions can add, modify or remove parameters
pub fn apply_restore_request_rules(
    input: &mut plist::Dictionary,
    parameters: &plist::Dictionary,
    rules: &Vec<plist::Value>,
) {
    for rule in rules {
        if let plist::Value::Dictionary(rule) = rule {
            let conditions = match rule.get("Conditions") {
                Some(plist::Value::Dictionary(c)) => c,
                _ => {
                    warn!("Conditions doesn't exist or wasn't a dictionary!");
                    continue;
                }
            };

            let mut conditions_fulfilled = true;
            for (key, value) in conditions {
                let value2 = match key.as_str() {
                    "ApRawProductionMode" => parameters.get("ApProductionMode"),
                    "ApCurrentProductionMode" => parameters.get("ApProductionMode"),
                    "ApRawSecurityMode" => parameters.get("ApSecurityMode"),
                    "ApRequiresImage4" => parameters.get("ApSupportsImg4"),
                    "ApDemotionPolicyOverride" => parameters.get("DemotionPolicy"),
                    "ApInRomDFU" => parameters.get("ApInRomDFU"),
                    _ => {
                        warn!("Unhandled key {key}");
                        None
                    }
                };

                if value2.is_none() || value2 != Some(value) {
                    conditions_fulfilled = false;
                    break; // Stop checking other conditions immediately
                }
            }

            if !conditions_fulfilled {
                continue;
            }

            let actions = match rule.get("Actions") {
                Some(plist::Value::Dictionary(a)) => a,
                _ => {
                    warn!("Actions doesn't exist or wasn't a dictionary!");
                    continue;
                }
            };

            for (key, value) in actions {
                // Skip special values (255 typically means "ignore")
                if let Some(i) = value.as_unsigned_integer()
                    && i == 255
                {
                    continue;
                }
                if let Some(i) = value.as_signed_integer()
                    && i == 255
                {
                    continue;
                }

                input.remove(key); // Explicitly remove before inserting
                input.insert(key.to_owned(), value.to_owned());
            }
        } else {
            warn!("Rule wasn't a dictionary");
        }
    }
}

/// Builds the `Cryptex1,UDID` identifying a device in a Cryptex1 TSS request.
///
/// It is the 16-byte concatenation of the chip ID and the ECID, both big-endian,
/// and lands in the signed ticket verbatim as the `UDID` property.
pub fn cryptex1_udid(chip_instance: &plist::Dictionary) -> Result<Vec<u8>, IdeviceError> {
    fn field(chip_instance: &plist::Dictionary, key: &'static str) -> Result<u64, IdeviceError> {
        chip_instance
            .get(key)
            .and_then(|v| v.as_unsigned_integer())
            .ok_or_else(|| {
                IdeviceError::UnexpectedResponse(format!(
                    "chip instance is missing an unsigned {key}"
                ))
            })
    }

    let mut udid = field(chip_instance, "img4_chip_chip")?
        .to_be_bytes()
        .to_vec();
    udid.extend_from_slice(&field(chip_instance, "img4_chip_ecid")?.to_be_bytes());
    Ok(udid)
}

/// Selects the one build identity in a DDI build manifest that describes a
/// cryptex, i.e. the one whose `Info.Variant` ends in
/// `Developer Disk Image Cryptex`.
pub fn select_cryptex_build_identity(
    build_manifest: &plist::Dictionary,
) -> Result<&plist::Dictionary, IdeviceError> {
    const CRYPTEX_VARIANT_SUFFIX: &str = "Developer Disk Image Cryptex";

    build_manifest
        .get("BuildIdentities")
        .and_then(|i| i.as_array())
        .and_then(|identities| {
            identities.iter().find_map(|identity| {
                let identity = identity.as_dictionary()?;
                let variant = identity
                    .get("Info")
                    .and_then(|i| i.as_dictionary())
                    .and_then(|i| i.get("Variant"))
                    .and_then(|v| v.as_string())?;
                variant
                    .ends_with(CRYPTEX_VARIANT_SUFFIX)
                    .then_some(identity)
            })
        })
        .ok_or(IdeviceError::BadBuildManifest)
}
