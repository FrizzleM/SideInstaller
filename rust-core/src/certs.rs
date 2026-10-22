//! Lists and revokes iOS development certificates via `isideload`'s
//! `DeveloperSession` (developer portal only, no device). `si_cert_signin` opens
//! a session on the first team, `si_cert_list` returns its certificates as JSON,
//! `si_cert_revoke` revokes one by serial number, `si_cert_import` signs with
//! SideStore's certificate from then on, and `si_cert_export` writes the one
//! SideInstaller signs with to a password-protected PKCS#12 archive.

use std::ffi::{c_char, c_void};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use isideload::{
    dev::{
        certificates::{CertificatesApi, DevelopmentCertificate},
        developer_session::DeveloperSession,
        device_type::DeveloperDeviceType,
        teams::DeveloperTeam,
    },
    sideload::cert_identity::CertificateIdentity,
};
use der::Decode;
use rsa::{
    pkcs1::EncodeRsaPublicKey,
    pkcs8::{DecodePrivateKey, EncodePrivateKey},
    RsaPrivateKey,
};
use serde::Serialize;

use crate::account::{make_2fa, TwoFactorCb, TwoFaCtx};
use crate::apple_session;
use crate::error_text::report_text;
use crate::ffi_util::{cstr, opt_str, req_str};

/// Opaque handle owning the runtime, developer session and selected team.
pub struct CertSession {
    // `pub(crate)` so `entitlements` can reuse this session and team instead of
    // signing in (and prompting for 2FA) again.
    pub(crate) rt: tokio::runtime::Runtime,
    pub(crate) dev: DeveloperSession,
    pub(crate) team: DeveloperTeam,
    /// Where `cert_import` writes the signing key isideload reads.
    apple_id: String,
    storage_dir: PathBuf,
}

// Used only through its own runtime, serialized by Swift on one queue.
unsafe impl Send for CertSession {}

/// A certificate flattened to plain strings, so Swift decodes no optionals.
#[derive(Serialize)]
struct CertInfo {
    name: String,
    serial_number: String,
    machine_name: String,
    machine_id: String,
    certificate_id: String,
    platform: String,
    status: String,
    /// RFC3339 expiry (e.g. `2027-01-01T00:00:00Z`), or "" if Apple omitted it.
    expiration: String,
    /// True for the certificate SideInstaller signs with: the only one whose
    /// private key is on this iPhone, so the only one it can export.
    signing: bool,
}

impl From<&DevelopmentCertificate> for CertInfo {
    fn from(c: &DevelopmentCertificate) -> Self {
        let s = |o: &Option<String>| o.clone().unwrap_or_default();
        CertInfo {
            name: s(&c.name),
            serial_number: s(&c.serial_number),
            machine_name: s(&c.machine_name),
            machine_id: s(&c.machine_id),
            certificate_id: s(&c.certificate_id),
            platform: s(&c.certificate_platform),
            status: s(&c.status),
            // plist::Date's XML form is RFC3339 (e.g. 2027-01-01T00:00:00Z).
            expiration: c
                .expiration_date
                .as_ref()
                .map(|d| d.to_xml_format())
                .unwrap_or_default(),
            signing: false,
        }
    }
}

impl CertInfo {
    fn signing(mut self, signing: bool) -> Self {
        self.signing = signing;
        self
    }
}

/// Log in, open a developer session, and select the first team. Returns 0 on
/// success; free the session with `si_cert_session_free`.
///
/// # Safety
/// All `*const c_char` args must be null or valid C strings; the out pointers
/// must be valid and writable.
#[allow(clippy::too_many_arguments)]
pub unsafe fn cert_signin(
    apple_id: *const c_char,
    password: *const c_char,
    anisette_url: *const c_char,
    // Unused; matches `si_apple_signin`'s signature.
    _machine_name: *const c_char,
    storage_dir: *const c_char,
    twofa_cb: TwoFactorCb,
    ctx: *mut c_void,
    out_session: *mut *mut CertSession,
    out_summary: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let apple_id = opt_str(apple_id, "");
    let password = opt_str(password, "");
    let anisette_url = opt_str(anisette_url, "https://ani.sidestore.io");
    let storage_dir = opt_str(storage_dir, ".");
    let twofa = make_2fa(twofa_cb, TwoFaCtx(ctx));

    let result = catch_unwind(AssertUnwindSafe(|| {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|e| format!("failed to start runtime: {e}"))?;

        let (dev, team, summary) = rt.block_on(async {
            // Always the active account, so the session is saved and reused.
            let (dev, teams) = apple_session::open(
                &apple_id,
                &password,
                &anisette_url,
                Path::new(&storage_dir),
                true,
                twofa,
                "Certs",
            )
            .await?;
            let team = teams
                .into_iter()
                .next()
                .ok_or_else(|| "no development teams on this Apple ID".to_string())?;
            tracing::info!("Certs: using team {}", team.team_id);

            let summary = format!(
                "team: {} ({})",
                team.name.as_deref().unwrap_or("<unnamed>"),
                team.team_id
            );
            Ok::<_, String>((dev, team, summary))
        })?;

        Ok::<_, String>((rt, dev, team, summary))
    }));

    match result {
        Ok(Ok((rt, dev, team, summary))) => {
            let session = Box::new(CertSession {
                rt,
                dev,
                team,
                apple_id,
                storage_dir: PathBuf::from(storage_dir),
            });
            *out_session = Box::into_raw(session);
            *out_summary = cstr(summary);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during certificate sign-in");
            2
        }
    }
}

/// List the team's certificates as a JSON array of `CertInfo`.
///
/// # Safety
/// `session` must be a valid pointer from `cert_signin`; out pointers valid.
pub unsafe fn cert_list(
    session: *mut CertSession,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() {
        *out_error = cstr("null session");
        return 2;
    }
    let session = &mut *session;

    let result = catch_unwind(AssertUnwindSafe(|| {
        let key = signing_key(session).ok().flatten();
        session.rt.block_on(async {
            let certs = session
                .dev
                .list_ios_certs(&session.team)
                .await
                .map_err(|e| format!("list certs failed: {}", report_text(&e)))?;
            tracing::info!("Certs: {} iOS development certificate(s)", certs.len());
            let infos: Vec<CertInfo> = certs
                .iter()
                .map(|c| {
                    let signing = key.as_ref().is_some_and(|k| holds_key(c, k));
                    CertInfo::from(c).signing(signing)
                })
                .collect();
            serde_json::to_string(&infos).map_err(|e| format!("serialize certs: {e}"))
        })
    }));

    match result {
        Ok(Ok(json)) => {
            *out_json = cstr(json);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic while listing certificates");
            2
        }
    }
}

/// Revoke the certificate with `serial_number`.
///
/// # Safety
/// `session` must be a valid pointer from `cert_signin`; `serial_number` a
/// valid C string; `out_error` valid and writable.
pub unsafe fn cert_revoke(
    session: *mut CertSession,
    serial_number: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() {
        *out_error = cstr("null session");
        return 2;
    }
    let session = &mut *session;
    let serial = opt_str(serial_number, "");
    if serial.is_empty() {
        *out_error = cstr("empty serial number");
        return 2;
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        session.rt.block_on(async {
            tracing::info!("Certs: revoking certificate {serial}");
            session
                .dev
                .revoke_development_cert(&session.team, &serial, DeveloperDeviceType::Ios)
                .await
                .map_err(|e| format!("revoke failed: {}", report_text(&e)))?;
            Ok::<_, String>(())
        })
    }));

    match result {
        Ok(Ok(())) => {
            tracing::info!("Certs: revoked {serial}");
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic while revoking certificate");
            2
        }
    }
}

/// What `cert_import` did, as Swift decodes it.
#[derive(Serialize)]
struct CertImport {
    /// The team's certificate the key belongs to.
    certificate: CertInfo,
    /// False when SideInstaller signed with this key already, so nothing was
    /// written.
    replaced_key: bool,
}

/// Sign with the certificate in a PKCS#12 archive from now on: SideStore's,
/// sent back for `sidestore://certificate`.
///
/// isideload keeps one RSA key per Apple ID, `<sha256(email)>/key`, and signs
/// with the team's certificate that carries its public key, asking Apple for a
/// new one only when none does. A free account gets one certificate (a second
/// is refused with error 7460), so SideInstaller and SideStore had to revoke
/// each other's. With SideStore's key in that file, both sign with SideStore's
/// certificate.
///
/// The key is written only once the portal lists a certificate for it on this
/// session's team, the check signing makes. An archive from another Apple ID,
/// or one whose certificate was revoked, leaves the current key alone and
/// returns 3. The key it replaces is kept next to it as `key.replaced-<unix
/// time>`.
///
/// # Safety
/// `session` must be a valid pointer from `cert_signin`; `p12` must point to
/// `p12_len` readable bytes; `password` null or a valid C string; out pointers
/// valid.
pub unsafe fn cert_import(
    session: *mut CertSession,
    p12: *const u8,
    p12_len: usize,
    password: *const c_char,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() || p12.is_null() {
        *out_error = cstr("null session or certificate");
        return 2;
    }
    let session = &mut *session;
    let data = std::slice::from_raw_parts(p12, p12_len).to_vec();
    let password = opt_str(password, "");

    let result = catch_unwind(AssertUnwindSafe(|| {
        let keys = crate::p12::signing_keys(&data, &password).map_err(|e| (1, e))?;
        session.rt.block_on(async {
            for archived in &keys {
                let found =
                    CertificateIdentity::find_matching(&archived.key, &mut session.dev, &session.team)
                        .await
                        .map_err(|e| (1, format!("list certs failed: {}", report_text(&e))))?;
                let Some((cert, _)) = found else { continue };
                let replaced = store_signing_key(&session.storage_dir, &session.apple_id, &archived.key)
                    .map_err(|e| (1, e))?;
                tracing::info!(
                    "Certs: signing with certificate {} ({}) from now on{}",
                    cert.serial_number.as_deref().unwrap_or("?"),
                    cert.machine_name.as_deref().unwrap_or("no machine name"),
                    if replaced { "" } else { "; it was the one in use already" }
                );
                let import = CertImport {
                    certificate: CertInfo::from(&cert).signing(true),
                    replaced_key: replaced,
                };
                return serde_json::to_string(&import)
                    .map_err(|e| (1, format!("serialize import: {e}")));
            }
            let serials: Vec<&str> = keys.iter().filter_map(|k| k.serial.as_deref()).collect();
            Err((
                3,
                format!(
                    "no certificate on team {} has the key in that archive{} — it was revoked, \
                     or it belongs to another Apple ID",
                    session.team.team_id,
                    if serials.is_empty() {
                        String::new()
                    } else {
                        format!(" (certificate {})", serials.join(", "))
                    }
                ),
            ))
        })
    }));

    match result {
        Ok(Ok(json)) => {
            *out_json = cstr(json);
            0
        }
        Ok(Err((rc, e))) => {
            *out_error = cstr(e);
            rc
        }
        Err(_) => {
            *out_error = cstr("panic while importing the certificate");
            2
        }
    }
}

/// Write the certificate with `serial_number` and SideInstaller's private key
/// for it to `out_path` as a PKCS#12 archive encrypted with `password`, for
/// another app or computer to sign with (see `p12::archive`).
///
/// Only the certificate SideInstaller signs with can go: the private key of any
/// other stays on the device that asked Apple for it. Returns 3, writing
/// nothing, when the certificate isn't that one (or SideInstaller has no key
/// for this Apple ID yet), 1 when the portal no longer lists it.
///
/// # Safety
/// `session` must be a valid pointer from `cert_signin`; `serial_number`,
/// `password` and `out_path` valid C strings; `out_error` valid and writable.
pub unsafe fn cert_export(
    session: *mut CertSession,
    serial_number: *const c_char,
    password: *const c_char,
    out_path: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    if session.is_null() {
        *out_error = cstr("null session");
        return 2;
    }
    let session = &mut *session;
    let serial = opt_str(serial_number, "");
    let (Some(password), Some(out_path)) = (req_str(password), req_str(out_path)) else {
        *out_error = cstr("missing password or destination");
        return 2;
    };
    if serial.is_empty() {
        *out_error = cstr("empty serial number");
        return 2;
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let not_ours = |why: &str| {
            (3, format!("certificate {serial} can't be exported: {why}"))
        };
        let key = signing_key(session)
            .map_err(|e| (1, e))?
            .ok_or_else(|| not_ours("SideInstaller has no signing key for this Apple ID yet"))?;
        let certs = session
            .rt
            .block_on(session.dev.list_ios_certs(&session.team))
            .map_err(|e| (1, format!("list certs failed: {}", report_text(&e))))?;
        let cert = certs
            .iter()
            .find(|c| c.serial_number.as_deref() == Some(serial.as_str()))
            .ok_or_else(|| (1, format!("certificate {serial} isn't on team {} anymore", session.team.team_id)))?;
        if !holds_key(cert, &key) {
            return Err(not_ours("its private key isn't the one SideInstaller signs with"));
        }
        let cert_der = cert
            .cert_content
            .as_ref()
            .ok_or_else(|| (1, "Apple sent the certificate without its content".to_string()))?;
        let name = cert.name.as_deref().filter(|n| !n.is_empty()).unwrap_or("SideInstaller");
        let p12 = crate::p12::archive(cert_der.as_ref(), &key, name, &password).map_err(|e| (1, e))?;
        std::fs::write(&out_path, &p12).map_err(|e| (1, format!("couldn't write the archive: {e}")))?;
        tracing::info!("Certs: exported certificate {serial} ({} byte p12)", p12.len());
        Ok(())
    }));

    match result {
        Ok(Ok(())) => 0,
        Ok(Err((rc, e))) => {
            *out_error = cstr(e);
            rc
        }
        Err(_) => {
            *out_error = cstr("panic while exporting the certificate");
            2
        }
    }
}

/// The key isideload signs with for this session's Apple ID, or None when it
/// has made none yet. Read as is: `CertificateIdentity::retrieve_private_key`
/// would make one.
fn signing_key(session: &CertSession) -> Result<Option<RsaPrivateKey>, String> {
    let path = apple_session::account_dir(&session.storage_dir, &session.apple_id).join("key");
    match std::fs::read(&path) {
        Ok(der) => RsaPrivateKey::from_pkcs8_der(&der)
            .map(Some)
            .map_err(|e| format!("couldn't read the signing key: {e}")),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(format!("couldn't read the signing key: {e}")),
    }
}

/// Whether `cert` is the certificate for `key`, compared the way isideload's
/// `find_matching` does.
fn holds_key(cert: &DevelopmentCertificate, key: &RsaPrivateKey) -> bool {
    cert.cert_content
        .as_ref()
        .is_some_and(|der| cert_holds_key(der.as_ref(), key))
}

fn cert_holds_key(cert_der: &[u8], key: &RsaPrivateKey) -> bool {
    let Ok(cert) = x509_cert::Certificate::from_der(cert_der) else { return false };
    let Ok(public) = key.to_public_key().to_pkcs1_der() else { return false };
    cert.tbs_certificate().subject_public_key_info().subject_public_key.as_bytes()
        == Some(public.as_bytes())
}

/// Makes `key` the signing key isideload reads for `apple_id`. Returns false
/// when it is that already. A different key there is kept beside it first.
fn store_signing_key(storage_dir: &Path, apple_id: &str, key: &RsaPrivateKey) -> Result<bool, String> {
    let dir = apple_session::account_dir(storage_dir, apple_id);
    let path = dir.join("key");
    match std::fs::read(&path) {
        Ok(current) => {
            let same = RsaPrivateKey::from_pkcs8_der(&current)
                .is_ok_and(|k| k.to_public_key() == key.to_public_key());
            if same {
                return Ok(false);
            }
            let stamp = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
            let kept = dir.join(format!("key.replaced-{stamp}"));
            std::fs::write(&kept, &current).map_err(|e| format!("couldn't keep the current key: {e}"))?;
            tracing::info!("Certs: kept the signing key it replaces as {}", file_name(&kept));
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            std::fs::create_dir_all(&dir).map_err(|e| format!("couldn't create {}: {e}", dir.display()))?;
        }
        Err(e) => return Err(format!("couldn't read the current key: {e}")),
    }
    let der = key.to_pkcs8_der().map_err(|e| format!("couldn't encode the key: {e}"))?;
    // Renamed into place, so signing never reads half a key.
    let tmp = dir.join("key.tmp");
    std::fs::write(&tmp, der.as_bytes()).map_err(|e| format!("couldn't write the key: {e}"))?;
    std::fs::rename(&tmp, &path).map_err(|e| format!("couldn't write the key: {e}"))?;
    Ok(true)
}

fn file_name(path: &Path) -> String {
    path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default()
}

/// Free a `CertSession`.
///
/// # Safety
/// `session` must be null or a pointer from `cert_signin`.
pub unsafe fn cert_session_free(session: *mut CertSession) {
    if !session.is_null() {
        drop(Box::from_raw(session));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key(der: &[u8]) -> RsaPrivateKey {
        RsaPrivateKey::from_pkcs8_der(der).unwrap()
    }

    #[test]
    fn stores_the_key_where_isideload_reads_it_and_keeps_the_old_one() {
        let storage = std::env::temp_dir().join(format!("si-cert-import-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&storage);
        let sidestore = key(include_bytes!("../testdata/p12/key.pk8"));
        let own = key(include_bytes!("../testdata/p12/other-key.pk8"));
        let apple_id = "someone@example.com";
        // isideload's folder: the hex SHA-256 of the email (`shasum -a 256`).
        let dir = storage.join("72497f475e4f76d0b28f57c73a084ece576d170874eba3ee2609d9afe4b71aab");
        assert_eq!(apple_session::account_dir(&storage, apple_id), dir);

        // No key yet: written as is.
        assert!(store_signing_key(&storage, apple_id, &own).unwrap());
        assert_eq!(key(&std::fs::read(dir.join("key")).unwrap()), own);

        // A different key: replaced, and the old one kept beside it.
        assert!(store_signing_key(&storage, apple_id, &sidestore).unwrap());
        assert_eq!(key(&std::fs::read(dir.join("key")).unwrap()), sidestore);
        let kept: Vec<_> = std::fs::read_dir(&dir)
            .unwrap()
            .map(|e| e.unwrap().file_name().to_string_lossy().into_owned())
            .filter(|n| n.starts_with("key.replaced-"))
            .collect();
        assert_eq!(kept.len(), 1);
        assert_eq!(key(&std::fs::read(dir.join(&kept[0])).unwrap()), own);

        // The same key again: nothing written.
        assert!(!store_signing_key(&storage, apple_id, &sidestore).unwrap());
        assert!(!dir.join("key.tmp").exists());

        std::fs::remove_dir_all(&storage).unwrap();
    }

    #[test]
    fn tells_the_certificate_for_a_key_from_the_others() {
        let cert = include_bytes!("../testdata/p12/cert.der");
        assert!(cert_holds_key(cert, &key(include_bytes!("../testdata/p12/key.pk8"))));
        assert!(!cert_holds_key(cert, &key(include_bytes!("../testdata/p12/other-key.pk8"))));
        assert!(!cert_holds_key(b"not a certificate", &key(include_bytes!("../testdata/p12/key.pk8"))));
    }
}
