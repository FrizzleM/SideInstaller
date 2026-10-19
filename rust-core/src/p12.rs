//! Reads the signing key out of the PKCS#12 archive SideStore exports with
//! `sidestore://certificate`, in either shape it can come in.
//!
//! SideStore sends the archive it keeps in its Keychain. One written by SideSign
//! (SideStore 0.6.4 and the nightlies) is CodeSignKit's `PKCS12Builder` output:
//! no encryption, no MAC, the key in a plain keyBag and no bag attributes. The
//! password SideStore sends with it isn't used. One kept from an AltSign build
//! is OpenSSL's: encrypted bags, a MAC, and a `localKeyId` tying the key to its
//! certificate. isideload's p12 reader opens the second but skips any key bag
//! without a `localKeyId`, so the first is walked here.

use der::{
    asn1::{AnyRef, OctetString},
    oid::ObjectIdentifier,
    Decode, Encode,
};
use p12_keystore::{KeyStore, KeyStoreEntry, Pkcs12ImportPolicy};
use pkcs12::{
    cms::content_info::ContentInfo, AuthenticatedSafe, CertBag, Pfx, PKCS_12_CERT_BAG_OID,
    PKCS_12_KEY_BAG_OID, PKCS_12_X509_CERT_OID,
};
use rsa::{pkcs8::DecodePrivateKey, RsaPrivateKey};

/// PKCS#7 `data`, the content type of an unencrypted safe.
const DATA_OID: ObjectIdentifier = ObjectIdentifier::new_unwrap("1.2.840.113549.1.7.1");

/// A private key found in the archive.
pub(crate) struct ArchiveKey {
    pub key: RsaPrivateKey,
    /// The serial number of the certificate stored with it, as the developer
    /// portal writes serials (hex, uppercase, no leading zeros); None when the
    /// archive pairs it with none.
    pub serial: Option<String>,
}

/// The RSA private keys in `data`, opened with `password` if the archive is
/// encrypted.
pub(crate) fn signing_keys(data: &[u8], password: &str) -> Result<Vec<ArchiveKey>, String> {
    let pfx = Pfx::from_der(data).map_err(|e| format!("not a PKCS#12 archive: {e}"))?;
    let mut keys = plain_keys(&pfx)?;
    if keys.is_empty() {
        keys = linked_keys(data, password)?;
    }
    if keys.is_empty() {
        return Err("the archive holds no RSA private key".into());
    }
    Ok(keys)
}

/// Keys in unencrypted key bags, as SideSign writes them. An encrypted safe or
/// a shrouded key bag is left for `linked_keys`.
fn plain_keys(pfx: &Pfx) -> Result<Vec<ArchiveKey>, String> {
    let bad = |e: der::Error| format!("unreadable PKCS#12 archive: {e}");
    if pfx.auth_safe.content_type != DATA_OID {
        return Ok(Vec::new());
    }
    let safes = AuthenticatedSafe::from_der(octets(&pfx.auth_safe).map_err(bad)?.as_bytes())
        .map_err(bad)?;

    let mut keys = Vec::new();
    let mut serials = Vec::new();
    for safe in safes.iter().filter(|s| s.content_type == DATA_OID) {
        let bags = pkcs12::safe_bag::SafeContents::from_der(octets(safe).map_err(bad)?.as_bytes())
            .map_err(bad)?;
        for bag in bags {
            // `bag_value` is the whole `[0] EXPLICIT` field; its content is the
            // bag's own encoding.
            let inner = AnyRef::from_der(&bag.bag_value).map_err(bad)?.value();
            if bag.bag_id == PKCS_12_KEY_BAG_OID {
                // A key that isn't RSA can't be isideload's, so it's skipped.
                if let Ok(key) = RsaPrivateKey::from_pkcs8_der(inner) {
                    keys.push(key);
                }
            } else if bag.bag_id == PKCS_12_CERT_BAG_OID {
                let cert = CertBag::from_der(inner).map_err(bad)?;
                if cert.cert_id == PKCS_12_X509_CERT_OID {
                    serials.extend(serial_text(cert.cert_value.as_bytes()));
                }
            }
        }
    }
    // With no `localKeyId` to go by, the one certificate SideSign stores is
    // the key's.
    let serial = if keys.len() == 1 && serials.len() == 1 { serials.pop() } else { None };
    Ok(keys.into_iter().map(|key| ArchiveKey { key, serial: serial.clone() }).collect())
}

/// Keys tied to their certificate by `localKeyId`, as OpenSSL writes them.
fn linked_keys(data: &[u8], password: &str) -> Result<Vec<ArchiveKey>, String> {
    let store = KeyStore::from_pkcs12(data, password, Pkcs12ImportPolicy::Relaxed).map_err(|e| {
        format!("couldn't open the PKCS#12 archive (a wrong password reads the same): {e}")
    })?;
    Ok(store
        .entries()
        .filter_map(|(_, entry)| match entry {
            KeyStoreEntry::PrivateKeyChain(chain) => Some(chain),
            _ => None,
        })
        .filter_map(|chain| {
            let key = RsaPrivateKey::from_pkcs8_der(chain.key().as_der()).ok()?;
            let serial = chain.certs().first().and_then(|c| serial_text(c.as_der()));
            Some(ArchiveKey { key, serial })
        })
        .collect())
}

/// The bytes of a `data` content info's OCTET STRING.
fn octets(info: &ContentInfo) -> der::Result<OctetString> {
    OctetString::from_der(&info.content.to_der()?)
}

/// A certificate's serial number the way the developer portal lists it, as
/// isideload's `CertificateIdentity::get_serial_number` writes it.
fn serial_text(cert_der: &[u8]) -> Option<String> {
    let cert = x509_cert::Certificate::from_der(cert_der).ok()?;
    let serial = hex::encode_upper(cert.tbs_certificate().serial_number().as_bytes());
    Some(serial.trim_start_matches('0').to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use rsa::pkcs1::EncodeRsaPublicKey;

    // One RSA-2048 key and a self-signed certificate (serial 5A3C9F01D2E4B6A8)
    // made for these tests with LibreSSL 3.3.6.
    const KEY_PKCS8: &[u8] = include_bytes!("../testdata/p12/key.pk8");
    const SERIAL: &str = "5A3C9F01D2E4B6A8";
    /// What SideStore sends: CodeSignKit's `PKCS12Builder.build` (at
    /// d0c67710, SideSign's pin) run on the Mac, given the password SERIAL.
    const SIDESIGN: &[u8] = include_bytes!("../testdata/p12/sidesign.p12");
    /// What an AltSign build kept: `openssl pkcs12 -export` with LibreSSL's
    /// defaults (RC2-40 certificate bag, 3DES key bag, SHA-1 MAC), password
    /// SERIAL.
    const OPENSSL: &[u8] = include_bytes!("../testdata/p12/openssl.p12");

    fn expected_key() -> RsaPrivateKey {
        RsaPrivateKey::from_pkcs8_der(KEY_PKCS8).unwrap()
    }

    fn assert_the_key(keys: &[ArchiveKey]) {
        assert_eq!(keys.len(), 1);
        assert_eq!(keys[0].key.to_public_key(), expected_key().to_public_key());
        assert_eq!(keys[0].serial.as_deref(), Some(SERIAL));
    }

    #[test]
    fn reads_sidesigns_unencrypted_archive_whatever_the_password() {
        for password in [SERIAL, "", "not it"] {
            assert_the_key(&signing_keys(SIDESIGN, password).unwrap());
        }
    }

    #[test]
    fn reads_an_openssl_archive_with_its_password() {
        assert_the_key(&signing_keys(OPENSSL, SERIAL).unwrap());
        assert!(signing_keys(OPENSSL, "wrong").is_err());
    }

    /// The archive SideInstaller itself hands SideStore in `Account.sideconf`
    /// (isideload's `as_p12`: PBES2/AES-256, SHA-256 MAC), in case SideStore
    /// still holds that one as it was imported.
    #[test]
    fn reads_the_archive_sideinstaller_hands_over() {
        let cert = p12_keystore::Certificate::from_der(&include_bytes!("../testdata/p12/cert.der")[..])
            .unwrap();
        let chain = p12_keystore::PrivateKeyChain::new(
            vec![1u8; 8],
            p12_keystore::PrivateKey::from_der(KEY_PKCS8).unwrap(),
            vec![cert],
        );
        let mut store = KeyStore::new();
        store.add_entry("isideload", KeyStoreEntry::PrivateKeyChain(chain));
        let p12 = store.writer("machine-id").write().unwrap();

        assert_the_key(&signing_keys(&p12, "machine-id").unwrap());
    }

    #[test]
    fn refuses_what_isnt_an_archive() {
        assert!(signing_keys(b"not a p12", "").is_err());
        // A PKCS#1 public key: valid DER, wrong shape.
        let der = expected_key().to_public_key().to_pkcs1_der().unwrap();
        assert!(signing_keys(der.as_bytes(), "").is_err());
    }
}
