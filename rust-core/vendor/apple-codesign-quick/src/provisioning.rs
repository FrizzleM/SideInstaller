use crate::error::{CodeSignError, Result};
use cms::cert::CertificateChoices;
use cms::content_info::ContentInfo;
use cms::signed_data::SignedData;
use der::{Decode, Encode};
use plist::{Dictionary, Value};

#[derive(Clone, Debug)]
pub struct ProvisioningProfile {
    plist: Dictionary,
    team_id: String,
    entitlements: Dictionary,
    certificate_chain: Vec<Vec<u8>>,
}

impl ProvisioningProfile {
    pub fn parse(data: &[u8]) -> Result<Self> {
        let signed_data = decode_signed_data(data)?;
        let profile_data = signed_data
            .encap_content_info
            .econtent
            .as_ref()
            .ok_or_else(|| {
                CodeSignError::provisioning_profile("CMS SignedData has no embedded plist")
            })?;
        let plist = match Value::from_reader_xml(profile_data.value())? {
            Value::Dictionary(plist) => plist,
            _ => {
                return Err(CodeSignError::provisioning_profile(
                    "embedded plist is not a dictionary",
                ));
            }
        };

        let team_id = team_identifier(&plist)?;
        let entitlements = match plist.get("Entitlements") {
            Some(Value::Dictionary(entitlements)) => entitlements.clone(),
            _ => {
                return Err(CodeSignError::provisioning_profile(
                    "profile is missing Entitlements dictionary",
                ));
            }
        };
        let certificate_chain = certificate_chain_der(&signed_data)?;

        Ok(Self {
            plist,
            team_id,
            entitlements,
            certificate_chain,
        })
    }

    pub fn plist(&self) -> &Dictionary {
        &self.plist
    }

    pub fn team_id(&self) -> &str {
        &self.team_id
    }

    pub fn entitlements(&self) -> &Dictionary {
        &self.entitlements
    }

    pub fn certificate_chain_der(&self) -> &[Vec<u8>] {
        &self.certificate_chain
    }
}

fn decode_signed_data(data: &[u8]) -> Result<SignedData> {
    let content_info = ContentInfo::from_der(data).map_err(|err| {
        CodeSignError::provisioning_profile(format!("failed to decode CMS ContentInfo: {err}"))
    })?;
    if content_info.content_type != const_oid::db::rfc5911::ID_SIGNED_DATA {
        return Err(CodeSignError::provisioning_profile(
            "CMS ContentInfo is not SignedData",
        ));
    }

    let signed_data = content_info.content.to_der().map_err(|err| {
        CodeSignError::provisioning_profile(format!("failed to re-encode SignedData: {err}"))
    })?;
    SignedData::from_der(&signed_data).map_err(|err| {
        CodeSignError::provisioning_profile(format!("failed to decode CMS SignedData: {err}"))
    })
}

fn team_identifier(plist: &Dictionary) -> Result<String> {
    plist
        .get("TeamIdentifier")
        .and_then(Value::as_array)
        .and_then(|values| values.first())
        .and_then(Value::as_string)
        .map(ToString::to_string)
        .or_else(|| {
            plist
                .get("ApplicationIdentifierPrefix")
                .and_then(Value::as_array)
                .and_then(|values| values.first())
                .and_then(Value::as_string)
                .map(ToString::to_string)
        })
        .ok_or_else(|| {
            CodeSignError::provisioning_profile(
                "profile is missing TeamIdentifier/ApplicationIdentifierPrefix",
            )
        })
}

fn certificate_chain_der(signed_data: &SignedData) -> Result<Vec<Vec<u8>>> {
    let Some(certificates) = &signed_data.certificates else {
        return Ok(Vec::new());
    };
    let mut out = Vec::with_capacity(certificates.0.len());

    for certificate in certificates.0.iter() {
        if let CertificateChoices::Certificate(certificate) = certificate {
            out.push(certificate.to_der().map_err(|err| {
                CodeSignError::provisioning_profile(format!(
                    "failed to encode CMS certificate: {err}"
                ))
            })?);
        }
    }

    Ok(out)
}
