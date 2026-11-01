use crate::error::{CodeSignError, Result};
use crate::signature::{CmsSigner, CmsSigningRequest, HashAlgorithm};
use cms::builder::{SignedDataBuilder, SignerInfoBuilder};
use cms::cert::{CertificateChoices, IssuerAndSerialNumber};
use cms::signed_data::{EncapsulatedContentInfo, SignerIdentifier};
use const_oid::ObjectIdentifier;
use der::asn1::{Any, ObjectIdentifier as DerObjectIdentifier, OctetStringRef, SetOfVec};
use der::{DateTime, Decode, Encode, Sequence};
use plist::{Dictionary, Value};
use rsa::RsaPrivateKey;
use rsa::pkcs1::DecodeRsaPrivateKey;
use rsa::pkcs1v15::SigningKey;
use rsa::pkcs8::DecodePrivateKey;
use spki::AlgorithmIdentifierOwned;
use std::fmt::Display;
use std::time::SystemTime;
use x509_cert::Certificate;
use x509_cert::attr::{Attribute, AttributeValue};

const APPLE_CODE_DIRECTORY_HASHES_OID: ObjectIdentifier =
    ObjectIdentifier::new_unwrap("1.2.840.113635.100.9.1");
const APPLE_CODE_DIRECTORY_DIGEST_OID: ObjectIdentifier =
    ObjectIdentifier::new_unwrap("1.2.840.113635.100.9.2");
const APPLE_WWDR_G3_CERTIFICATE_DER: &[u8] = include_bytes!("../assets/AppleWWDRCAG3.cer");
const APPLE_ROOT_CERTIFICATE_DER: &[u8] = include_bytes!("../assets/AppleIncRootCertificate.cer");

type RsaSha256SigningKey = SigningKey<sha2_010::Sha256>;

/// CMS signer for Apple Code Signing using RustCrypto's CMS/DER/X.509 crates.
///
/// The generated CMS is detached SignedData over the primary CodeDirectory and
/// includes the Apple-specific CodeDirectory digest attributes that AMFI expects.
pub struct RustCryptoCmsSigner {
    signing_key: RsaSha256SigningKey,
    signer_certificate: Certificate,
    certificate_chain: Vec<Certificate>,
    signing_time: Option<SystemTime>,
}

impl RustCryptoCmsSigner {
    pub fn new(
        private_key: RsaPrivateKey,
        signer_certificate: Certificate,
        certificate_chain: Vec<Certificate>,
    ) -> Self {
        Self {
            signing_key: RsaSha256SigningKey::new(private_key),
            signer_certificate,
            certificate_chain,
            signing_time: Some(SystemTime::now()),
        }
    }

    pub fn from_der<I, C>(
        private_key_der: &[u8],
        signer_certificate_der: &[u8],
        certificate_chain_der: I,
    ) -> Result<Self>
    where
        I: IntoIterator<Item = C>,
        C: AsRef<[u8]>,
    {
        let private_key = decode_rsa_private_key(private_key_der)?;
        let signer_certificate = Certificate::from_der(signer_certificate_der)
            .map_err(|err| cms_error(format!("failed to decode signer certificate: {err}")))?;
        let mut certificate_candidates = Vec::new();

        for certificate_der in certificate_chain_der {
            let certificate = Certificate::from_der(certificate_der.as_ref())
                .map_err(|err| cms_error(format!("failed to decode chain certificate: {err}")))?;
            push_unique_certificate(&mut certificate_candidates, certificate);
        }

        for (name, certificate_der) in [
            ("Apple WWDR G3", APPLE_WWDR_G3_CERTIFICATE_DER),
            ("Apple Root CA", APPLE_ROOT_CERTIFICATE_DER),
        ] {
            let certificate = Certificate::from_der(certificate_der).map_err(|err| {
                cms_error(format!(
                    "failed to decode bundled {name} certificate: {err}"
                ))
            })?;
            push_unique_certificate(&mut certificate_candidates, certificate);
        }

        let certificate_chain =
            certificate_chain_for_signer(&signer_certificate, &certificate_candidates)?;

        Ok(Self::new(
            private_key,
            signer_certificate,
            certificate_chain,
        ))
    }

    pub fn with_signing_time(mut self, signing_time: SystemTime) -> Self {
        self.signing_time = Some(signing_time);
        self
    }

    pub fn without_signing_time(mut self) -> Self {
        self.signing_time = None;
        self
    }

    pub fn signer_certificate(&self) -> &Certificate {
        &self.signer_certificate
    }

    pub fn certificate_chain(&self) -> &[Certificate] {
        &self.certificate_chain
    }
}

impl CmsSigner for RustCryptoCmsSigner {
    fn sign(&self, request: CmsSigningRequest<'_>) -> Result<Vec<u8>> {
        let primary_code_directory = request
            .code_directories
            .first()
            .ok_or_else(|| cms_error("cannot build CMS without a primary CodeDirectory"))?;
        let message_digest = HashAlgorithm::Sha256.digest(primary_code_directory.bytes);

        let encapsulated_content_info = EncapsulatedContentInfo {
            econtent_type: const_oid::db::rfc5911::ID_DATA,
            econtent: None,
        };
        let digest_algorithm = sha256_algorithm_identifier();
        let signer_identifier = signer_identifier(&self.signer_certificate);
        let mut signer_info = SignerInfoBuilder::new(
            &self.signing_key,
            signer_identifier,
            digest_algorithm.clone(),
            &encapsulated_content_info,
            Some(&message_digest),
        )
        .map_err(cms_builder_error)?;

        if let Some(signing_time) = self.signing_time {
            signer_info
                .add_signed_attribute(signing_time_attribute(signing_time)?)
                .map_err(cms_builder_error)?;
        }

        signer_info
            .add_signed_attribute(apple_code_directory_digest_attribute(&request)?)
            .map_err(cms_builder_error)?;
        signer_info
            .add_signed_attribute(apple_code_directory_hashes_attribute(&request)?)
            .map_err(cms_builder_error)?;

        let mut builder = SignedDataBuilder::new(&encapsulated_content_info);
        builder
            .add_digest_algorithm(digest_algorithm)
            .map_err(cms_builder_error)?;
        add_certificates(
            &mut builder,
            &self.signer_certificate,
            &self.certificate_chain,
        )?;
        builder
            .add_signer_info::<RsaSha256SigningKey, rsa::pkcs1v15::Signature>(signer_info)
            .map_err(cms_builder_error)?;

        let content_info = builder.build().map_err(cms_builder_error)?;
        content_info.to_der().map_err(cms_der_error)
    }
}

#[derive(Sequence)]
struct AppleCodeDirectoryDigest<'a> {
    algorithm: DerObjectIdentifier,
    digest: OctetStringRef<'a>,
}

fn decode_rsa_private_key(der: &[u8]) -> Result<RsaPrivateKey> {
    match RsaPrivateKey::from_pkcs8_der(der) {
        Ok(private_key) => Ok(private_key),
        Err(pkcs8_error) => RsaPrivateKey::from_pkcs1_der(der).map_err(|pkcs1_error| {
            cms_error(format!(
                "failed to decode RSA private key as PKCS#8 ({pkcs8_error}) or PKCS#1 ({pkcs1_error})"
            ))
        }),
    }
}

fn push_unique_certificate(certificates: &mut Vec<Certificate>, certificate: Certificate) {
    if !certificates.contains(&certificate) {
        certificates.push(certificate);
    }
}

fn certificate_chain_for_signer(
    signer_certificate: &Certificate,
    certificate_candidates: &[Certificate],
) -> Result<Vec<Certificate>> {
    if signer_certificate.tbs_certificate.subject == signer_certificate.tbs_certificate.issuer {
        return Ok(Vec::new());
    }

    let mut issuer = signer_certificate.tbs_certificate.issuer.clone();
    let mut certificate_chain = Vec::new();

    loop {
        let certificate = certificate_candidates
            .iter()
            .find(|candidate| candidate.tbs_certificate.subject == issuer)
            .ok_or_else(|| {
                cms_error(format!(
                    "missing issuer certificate {issuer} for the code-signing certificate chain"
                ))
            })?
            .clone();

        if certificate_chain.contains(&certificate) {
            return Err(cms_error("certificate chain contains a cycle"));
        }

        let is_root = certificate.tbs_certificate.subject == certificate.tbs_certificate.issuer;
        issuer = certificate.tbs_certificate.issuer.clone();
        certificate_chain.push(certificate);

        if is_root {
            return Ok(certificate_chain);
        }
    }
}

fn add_certificates(
    builder: &mut SignedDataBuilder<'_>,
    signer_certificate: &Certificate,
    certificate_chain: &[Certificate],
) -> Result<()> {
    let mut added = Vec::with_capacity(certificate_chain.len() + 1);

    for certificate in certificate_chain
        .iter()
        .chain(std::iter::once(signer_certificate))
    {
        if added.contains(&certificate) {
            continue;
        }

        builder
            .add_certificate(CertificateChoices::Certificate(certificate.clone()))
            .map_err(cms_builder_error)?;
        added.push(certificate);
    }

    Ok(())
}

fn signing_time_attribute(signing_time: SystemTime) -> Result<Attribute> {
    let date_time = DateTime::from_system_time(signing_time).map_err(cms_der_error)?;
    let time_der = if date_time.year() < 1950 || date_time.year() > 2049 {
        der::asn1::GeneralizedTime::from_date_time(date_time)
            .to_der()
            .map_err(cms_der_error)?
    } else {
        der::asn1::UtcTime::from_date_time(date_time)
            .map_err(cms_der_error)?
            .to_der()
            .map_err(cms_der_error)?
    };
    let value = AttributeValue::from_der(&time_der).map_err(cms_der_error)?;

    single_value_attribute(const_oid::db::rfc5911::ID_SIGNING_TIME, value)
}

fn signer_identifier(certificate: &Certificate) -> SignerIdentifier {
    SignerIdentifier::IssuerAndSerialNumber(IssuerAndSerialNumber {
        issuer: certificate.tbs_certificate.issuer.clone(),
        serial_number: certificate.tbs_certificate.serial_number.clone(),
    })
}

fn apple_code_directory_digest_attribute(request: &CmsSigningRequest<'_>) -> Result<Attribute> {
    if !request
        .code_directories
        .iter()
        .any(|code_directory| code_directory.algorithm == HashAlgorithm::Sha256)
    {
        return Err(cms_error(
            "cannot build CMS without a SHA-256 CodeDirectory",
        ));
    }

    let mut values = Vec::with_capacity(request.code_directories.len());
    for code_directory in request.code_directories {
        let digest = code_directory.algorithm.digest(code_directory.bytes);
        let digest = OctetStringRef::new(&digest).map_err(cms_der_error)?;
        values.push(
            Any::encode_from(&AppleCodeDirectoryDigest {
                algorithm: match code_directory.algorithm {
                    HashAlgorithm::Sha1 => const_oid::db::rfc5912::ID_SHA_1,
                    HashAlgorithm::Sha256 => const_oid::db::rfc5912::ID_SHA_256,
                },
                digest,
            })
            .map_err(cms_der_error)?,
        );
    }

    Ok(Attribute {
        oid: APPLE_CODE_DIRECTORY_DIGEST_OID,
        values: SetOfVec::try_from(values).map_err(cms_der_error)?,
    })
}

fn apple_code_directory_hashes_attribute(request: &CmsSigningRequest<'_>) -> Result<Attribute> {
    let mut cdhashes = Vec::with_capacity(request.code_directories.len());

    for code_directory in request.code_directories {
        let digest = code_directory.algorithm.digest(code_directory.bytes);
        let cdhash = digest
            .get(..20)
            .ok_or_else(|| cms_error("CodeDirectory digest is shorter than a cdhash"))?;
        cdhashes.push(Value::Data(cdhash.to_vec()));
    }

    let mut plist = Dictionary::new();
    plist.insert("cdhashes".to_string(), Value::Array(cdhashes));

    let mut xml = Vec::new();
    plist::to_writer_xml(&mut xml, &Value::Dictionary(plist))?;
    if xml.last() != Some(&b'\n') {
        xml.push(b'\n');
    }

    let value = Any::from(OctetStringRef::new(&xml).map_err(cms_der_error)?);
    single_value_attribute(APPLE_CODE_DIRECTORY_HASHES_OID, value)
}

fn single_value_attribute(oid: DerObjectIdentifier, value: AttributeValue) -> Result<Attribute> {
    Ok(Attribute {
        oid,
        values: SetOfVec::try_from(vec![value]).map_err(cms_der_error)?,
    })
}

fn sha256_algorithm_identifier() -> AlgorithmIdentifierOwned {
    AlgorithmIdentifierOwned {
        oid: const_oid::db::rfc5912::ID_SHA_256,
        parameters: Some(Any::null()),
    }
}

fn cms_builder_error(error: cms::builder::Error) -> CodeSignError {
    cms_error(error)
}

fn cms_der_error(error: der::Error) -> CodeSignError {
    cms_error(error)
}

fn cms_error(message: impl Display) -> CodeSignError {
    CodeSignError::cms(message.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::signature::EncodedCodeDirectory;
    use der::Decode;

    #[test]
    fn apple_code_directory_digest_requires_sha256_code_directory() {
        let code_directory = EncodedCodeDirectory {
            algorithm: HashAlgorithm::Sha1,
            bytes: b"primary",
        };
        let request = CmsSigningRequest {
            code_directories: &[code_directory],
        };

        assert!(apple_code_directory_digest_attribute(&request).is_err());
    }

    #[test]
    fn apple_code_directory_digest_contains_a_bare_hash_oid() {
        let code_directory = EncodedCodeDirectory {
            algorithm: HashAlgorithm::Sha256,
            bytes: b"alternate",
        };
        let request = CmsSigningRequest {
            code_directories: &[code_directory],
        };

        let attribute = apple_code_directory_digest_attribute(&request).unwrap();
        let value_der = attribute.values.get(0).unwrap().to_der().unwrap();

        assert_eq!(
            &value_der[..15],
            &[
                0x30, 0x2d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x04,
                0x20,
            ]
        );
        assert_eq!(value_der.len(), 47);
    }

    #[test]
    fn apple_code_directory_hashes_are_xml_plist_octet_string() {
        let code_directories = [
            EncodedCodeDirectory {
                algorithm: HashAlgorithm::Sha1,
                bytes: b"primary",
            },
            EncodedCodeDirectory {
                algorithm: HashAlgorithm::Sha256,
                bytes: b"alternate",
            },
        ];
        let request = CmsSigningRequest {
            code_directories: &code_directories,
        };

        let attribute = apple_code_directory_hashes_attribute(&request).unwrap();
        assert_eq!(attribute.oid, APPLE_CODE_DIRECTORY_HASHES_OID);

        let value = attribute.values.get(0).unwrap();
        let plist_xml = OctetStringRef::from_der(value.to_der().unwrap().as_slice())
            .unwrap()
            .as_bytes()
            .to_vec();
        assert!(plist_xml.starts_with(br#"<?xml version="1.0""#));
        assert!(plist_xml.ends_with(b"\n"));
    }

    #[test]
    fn apple_code_directory_digest_includes_every_code_directory() {
        let code_directories = [
            EncodedCodeDirectory {
                algorithm: HashAlgorithm::Sha1,
                bytes: b"primary",
            },
            EncodedCodeDirectory {
                algorithm: HashAlgorithm::Sha256,
                bytes: b"alternate",
            },
        ];
        let request = CmsSigningRequest {
            code_directories: &code_directories,
        };

        let attribute = apple_code_directory_digest_attribute(&request).unwrap();
        let sha1_value_der = attribute.values.get(0).unwrap().to_der().unwrap();

        assert_eq!(attribute.values.len(), 2);
        assert_eq!(
            &sha1_value_der[..11],
            &[
                0x30, 0x1d, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x04, 0x14
            ]
        );
    }

    #[test]
    fn bundled_apple_chain_links_wwdr_g3_to_root() {
        let wwdr = Certificate::from_der(APPLE_WWDR_G3_CERTIFICATE_DER).unwrap();
        let root = Certificate::from_der(APPLE_ROOT_CERTIFICATE_DER).unwrap();
        let candidates = [wwdr.clone(), root.clone()];

        let chain = certificate_chain_for_signer(&wwdr, &candidates).unwrap();

        assert_eq!(chain, vec![root]);
    }
}
