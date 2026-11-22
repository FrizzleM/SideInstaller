//! Local signing with a user-supplied enterprise certificate.
//!
//! The .p12 is parsed on the Swift side (Security framework), so
//! the certificate and RSA private key arrive here as DER files,
//! alongside the .mobileprovision. No Apple ID and no network:
//! the identity and profile are built directly and handed to
//! isideload's signer — the same code path the Apple-ID flow
//! ends in. The bundle ID is left untouched (an enterprise
//! profile authorizes the app as it is, unlike a development
//! profile tied to registered App IDs).

use std::ffi::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::PathBuf;

use isideload::dev::app_ids::Profile;
use isideload::dev::teams::DeveloperTeam;
use isideload::sideload::application::Application;
use isideload::sideload::cert_identity::CertificateIdentity;
use isideload::sideload::sign;
use rsa::{pkcs8::DecodePrivateKey, RsaPrivateKey};
use x509_cert_old::{der::Decode, Certificate};

use crate::error_text::report_text;
use crate::ffi_util::{cstr, opt_str};

/// DER length octets for a content of `len` bytes.
fn der_len(len: usize) -> Vec<u8> {
    if len < 0x80 {
        vec![len as u8]
    } else if len < 0x100 {
        vec![0x81, len as u8]
    } else {
        vec![0x82, (len >> 8) as u8, len as u8]
    }
}

/// Wrap a PKCS#1 RSA private key in a PKCS#8 PrivateKeyInfo, so
/// the rsa crate's PKCS#8 decoder accepts it (Swift's
/// SecKeyCopyExternalRepresentation hands out PKCS#1 for RSA).
fn wrap_pkcs1_in_pkcs8(pkcs1: &[u8]) -> Vec<u8> {
    // AlgorithmIdentifier: rsaEncryption (1.2.840.113549.1.1.1) + NULL
    const ALG_ID: [u8; 15] = [
        0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00,
    ];
    let mut body = Vec::with_capacity(pkcs1.len() + 32);
    body.extend_from_slice(&[0x02, 0x01, 0x00]); // version 0
    body.extend_from_slice(&ALG_ID);
    body.push(0x04); // OCTET STRING
    body.extend_from_slice(&der_len(pkcs1.len()));
    body.extend_from_slice(pkcs1);
    let mut out = vec![0x30]; // SEQUENCE
    out.extend_from_slice(&der_len(body.len()));
    out.extend_from_slice(&body);
    out
}

fn find_subslice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack.windows(needle.len()).position(|w| w == needle)
}

/// Extract the XML plist embedded verbatim in a .mobileprovision
/// (a CMS blob) and parse it into a dictionary.
fn provision_dict(bytes: &[u8]) -> Result<plist::Dictionary, String> {
    let start = find_subslice(bytes, b"<?xml").ok_or("描述文件里找不到 plist")?;
    let tail = find_subslice(bytes, b"</plist>").ok_or("描述文件里找不到 plist 结尾")?;
    let end = tail + "</plist>".len();
    let value = plist::Value::from_reader(std::io::Cursor::new(&bytes[start..end]))
        .map_err(|e| format!("描述文件解析失败：{e}"))?;
    value
        .as_dictionary()
        .cloned()
        .ok_or_else(|| "描述文件格式不对".to_string())
}

fn dict_string(dict: &plist::Dictionary, key: &str) -> String {
    dict.get(key)
        .and_then(|v| v.as_string())
        .unwrap_or("")
        .to_string()
}

/// Optional pre-signing modifications plus a signed-.ipa output,
/// passed from Swift as one JSON object; every field is optional
/// and an absent/empty field leaves the app as it is:
/// `{name, bundleId, version, minOS, iconPng, outIpa, plugins}`.
/// `plugins` is an array of .dylib/.deb/.zip file paths to inject
/// into the app before signing.
#[derive(Default)]
struct SignMods {
    name: Option<String>,
    bundle_id: Option<String>,
    version: Option<String>,
    min_os: Option<String>,
    icon_png: Option<String>,
    out_ipa: Option<String>,
    plugins: Vec<String>,
}

fn parse_mods(json: &str) -> SignMods {
    let mut mods = SignMods::default();
    if json.trim().is_empty() {
        return mods;
    }
    let Ok(value) = serde_json::from_str::<serde_json::Value>(json) else {
        return mods;
    };
    let get = |key: &str| {
        value
            .get(key)
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .map(|s| s.to_string())
    };
    mods.name = get("name");
    mods.bundle_id = get("bundleId");
    mods.version = get("version");
    mods.min_os = get("minOS");
    mods.icon_png = get("iconPng");
    mods.out_ipa = get("outIpa");
    if let Some(list) = value.get("plugins").and_then(|v| v.as_array()) {
        mods.plugins = list
            .iter()
            .filter_map(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .map(|s| s.to_string())
            .collect();
    }
    mods
}

/// Overwrite the app's icon files with one PNG. The icon file names
/// come from the Info.plist (CFBundleIcons → CFBundlePrimaryIcon →
/// CFBundleIconFiles); each existing scale variant gets the PNG.
/// Apps whose icons live only in Assets.car have no loose files to
/// replace — that case silently keeps the original icon.
fn apply_icon(app: &Application, icon_path: &str) -> Result<(), String> {
    let png = std::fs::read(icon_path).map_err(|e| format!("读图标失败：{e}"))?;
    let mut bases: Vec<String> = Vec::new();
    for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
        if let Some(files) = app
            .bundle
            .app_info
            .get(key)
            .and_then(|v| v.as_dictionary())
            .and_then(|d| d.get("CFBundlePrimaryIcon"))
            .and_then(|v| v.as_dictionary())
            .and_then(|d| d.get("CFBundleIconFiles"))
            .and_then(|v| v.as_array())
        {
            for file in files {
                if let Some(name) = file.as_string() {
                    bases.push(name.to_string());
                }
            }
        }
    }
    if bases.is_empty() {
        bases.push("AppIcon60x60".to_string());
    }
    let dir = &app.bundle.bundle_dir;
    for base in &bases {
        let stem = base.strip_suffix(".png").unwrap_or(base);
        for suffix in ["", "@2x", "@3x", "~ipad", "@2x~ipad", "@3x~ipad"] {
            let candidate = dir.join(format!("{stem}{suffix}.png"));
            if candidate.exists() {
                std::fs::write(&candidate, &png).map_err(|e| format!("写图标失败：{e}"))?;
            }
        }
    }
    Ok(())
}

/// Apply the requested modifications, then persist every bundle's
/// Info.plist the same way the account flow does before signing.
fn apply_mods(app: &mut Application, mods: &SignMods) -> Result<(), String> {
    if let Some(new_id) = &mods.bundle_id {
        let old_id = app.main_bundle_id().map_err(|e| report_text(&e))?;
        if old_id != *new_id {
            app.update_bundle_id(&old_id, new_id)
                .map_err(|e| report_text(&e))?;
        }
    }
    if let Some(name) = &mods.name {
        app.bundle.app_info.insert(
            "CFBundleDisplayName".to_string(),
            plist::Value::String(name.clone()),
        );
    }
    if let Some(version) = &mods.version {
        app.bundle.app_info.insert(
            "CFBundleShortVersionString".to_string(),
            plist::Value::String(version.clone()),
        );
    }
    if let Some(min_os) = &mods.min_os {
        app.bundle.app_info.insert(
            "MinimumOSVersion".to_string(),
            plist::Value::String(min_os.clone()),
        );
    }
    if let Some(icon_path) = &mods.icon_png {
        apply_icon(app, icon_path)?;
    }
    app.bundle.write_info().map_err(|e| report_text(&e))?;
    for ext in app.bundle.app_extensions_mut() {
        ext.write_info().map_err(|e| report_text(&e))?;
    }
    for fw in app.bundle.frameworks_mut() {
        fw.write_info().map_err(|e| report_text(&e))?;
    }
    Ok(())
}

/// Zip a signed .app bundle back into an .ipa at `out_ipa`,
/// keeping each file's unix mode (the executable bit matters when
/// the archive is extracted again).
fn zip_bundle(bundle_dir: &std::path::Path, out_ipa: &str) -> Result<(), String> {
    let app_name = bundle_dir
        .file_name()
        .ok_or("签名包目录不对")?
        .to_string_lossy()
        .to_string();
    let mut entries: Vec<PathBuf> = Vec::new();
    let mut stack = vec![bundle_dir.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let read = std::fs::read_dir(&dir).map_err(|e| format!("读签名包失败：{e}"))?;
        for entry in read {
            let entry = entry.map_err(|e| format!("读签名包失败：{e}"))?;
            let path = entry.path();
            if path.is_dir() {
                stack.push(path.clone());
            }
            entries.push(path);
        }
    }
    entries.sort();
    let file = std::fs::File::create(out_ipa).map_err(|e| format!("建已签 IPA 失败：{e}"))?;
    let mut zip = zip::ZipWriter::new(file);
    let make_options = || {
        zip::write::SimpleFileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated)
    };
    for path in &entries {
        let rel = path.strip_prefix(bundle_dir).unwrap_or(path);
        let name = format!("Payload/{}/{}", app_name, rel.to_string_lossy());
        if path.is_dir() {
            zip.add_directory(format!("{name}/"), make_options())
                .map_err(|e| format!("打包失败：{e}"))?;
        } else {
            #[cfg(unix)]
            let mode = {
                use std::os::unix::fs::PermissionsExt;
                path.metadata().map(|m| m.permissions().mode()).unwrap_or(0o644)
            };
            #[cfg(not(unix))]
            let mode = 0o644;
            zip.start_file(name, make_options().unix_permissions(mode))
                .map_err(|e| format!("打包失败：{e}"))?;
            let mut source = std::fs::File::open(path).map_err(|e| format!("打包失败：{e}"))?;
            std::io::copy(&mut source, &mut zip).map_err(|e| format!("打包失败：{e}"))?;
        }
    }
    zip.finish().map_err(|e| format!("打包失败：{e}"))?;
    Ok(())
}

fn sign_with_cert(
    ipa_path: &str,
    cert_der_path: &str,
    key_der_path: &str,
    provision_path: &str,
) -> Result<String, String> {
    sign_with_cert_mods(
        ipa_path,
        cert_der_path,
        key_der_path,
        provision_path,
        &SignMods::default(),
    )
}

fn sign_with_cert_mods(
    ipa_path: &str,
    cert_der_path: &str,
    key_der_path: &str,
    provision_path: &str,
    mods: &SignMods,
) -> Result<String, String> {
    let cert_der = std::fs::read(cert_der_path).map_err(|e| format!("读证书失败：{e}"))?;
    let key_der = std::fs::read(key_der_path).map_err(|e| format!("读私钥失败：{e}"))?;
    let provision_bytes =
        std::fs::read(provision_path).map_err(|e| format!("读描述文件失败：{e}"))?;

    let certificate =
        Certificate::from_der(&cert_der).map_err(|e| format!("证书解析失败：{e}"))?;
    let private_key = RsaPrivateKey::from_pkcs8_der(&key_der)
        .or_else(|_| RsaPrivateKey::from_pkcs8_der(&wrap_pkcs1_in_pkcs8(&key_der)))
        .map_err(|e| format!("私钥解析失败：{e}"))?;

    let dict = provision_dict(&provision_bytes)?;
    let team_id = dict
        .get("TeamIdentifier")
        .and_then(|v| v.as_array())
        .and_then(|a| a.first())
        .and_then(|v| v.as_string())
        .unwrap_or("")
        .to_string();
    if team_id.is_empty() {
        return Err("描述文件里没有 TeamIdentifier".into());
    }
    let date_expire = match dict.get("ExpirationDate") {
        Some(plist::Value::Date(d)) => *d,
        _ => return Err("描述文件里没有 ExpirationDate".into()),
    };

    let profile = Profile {
        encoded_profile: plist::Data::new(provision_bytes),
        filename: "enterprise.mobileprovision".to_string(),
        provisioning_profile_id: String::new(),
        name: dict_string(&dict, "Name"),
        status: "Active".to_string(),
        r#type: "Distribution".to_string(),
        distribution_method: String::new(),
        pro_pro_platorm: None,
        uuid: dict_string(&dict, "UUID"),
        date_expire,
        managing_app: None,
        app_id_id: String::new(),
        is_template_profile: false,
        is_team_profile: None,
        is_free_provisioning_profile: Some(false),
    };
    let team = DeveloperTeam {
        name: Some(dict_string(&dict, "TeamName")),
        team_id,
        r#type: Some("Distribution".to_string()),
        status: None,
    };
    let identity = CertificateIdentity {
        machine_id: "enterprise".to_string(),
        machine_name: "enterprise".to_string(),
        private_key,
        certificate,
    };

    let mut app = Application::new(PathBuf::from(ipa_path)).map_err(|e| report_text(&e))?;
    apply_mods(&mut app, mods)?;
    if !mods.plugins.is_empty() {
        inject_plugins(&app, &mods.plugins)?;
    }
    sign::sign(&mut app, &identity, &profile, &None, &team).map_err(|e| report_text(&e))?;
    if let Some(out_ipa) = &mods.out_ipa {
        if let Some(parent) = PathBuf::from(out_ipa).parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        zip_bundle(&app.bundle.bundle_dir, out_ipa)?;
    }
    Ok(app.bundle.bundle_dir.to_string_lossy().to_string())
}

/// Extract an .ipa and return its .app bundle directory (in the
/// shared extraction folder `Application::new` uses). Used to
/// install an already-signed IPA without signing it again.
///
/// # Safety
/// Same contract as `sign_ipa_with_cert`.
pub unsafe fn extract_ipa(
    ipa_path: *const c_char,
    out_bundle_path: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let ipa = opt_str(ipa_path, "");
    let result = catch_unwind(AssertUnwindSafe(|| {
        Application::new(PathBuf::from(&ipa))
            .map(|app| app.bundle.bundle_dir.to_string_lossy().to_string())
            .map_err(|e| report_text(&e))
    }));
    match result {
        Ok(Ok(path)) => {
            *out_bundle_path = cstr(path);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during IPA extraction");
            2
        }
    }
}

/// Like `sign_ipa_with_cert`, plus a JSON options object with the
/// optional modifications and signed-.ipa output (see `SignMods`).
///
/// # Safety
/// Same contract as `sign_ipa_with_cert`; `options_json` may be
/// null for no modifications.
pub unsafe fn sign_ipa_with_cert_ex(
    ipa_path: *const c_char,
    cert_der_path: *const c_char,
    key_der_path: *const c_char,
    provision_path: *const c_char,
    options_json: *const c_char,
    out_signed_path: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let ipa = opt_str(ipa_path, "");
    let cert = opt_str(cert_der_path, "");
    let key = opt_str(key_der_path, "");
    let provision = opt_str(provision_path, "");
    let json = opt_str(options_json, "");
    let result = catch_unwind(AssertUnwindSafe(|| {
        let mods = parse_mods(&json);
        sign_with_cert_mods(&ipa, &cert, &key, &provision, &mods)
    }));
    match result {
        Ok(Ok(path)) => {
            *out_signed_path = cstr(path);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during enterprise signing");
            2
        }
    }
}

/// Sign an IPA with an enterprise certificate, locally. Returns 0
/// on success and sets `*out_signed_path` to the signed bundle's
/// directory; on failure returns nonzero and sets `*out_error`.
///
/// # Safety
/// All `*const c_char` args must be null or valid C strings; the
/// out pointers must be valid and writable.
pub unsafe fn sign_ipa_with_cert(
    ipa_path: *const c_char,
    cert_der_path: *const c_char,
    key_der_path: *const c_char,
    provision_path: *const c_char,
    out_signed_path: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let ipa = opt_str(ipa_path, "");
    let cert = opt_str(cert_der_path, "");
    let key = opt_str(key_der_path, "");
    let provision = opt_str(provision_path, "");
    let result = catch_unwind(AssertUnwindSafe(|| sign_with_cert(&ipa, &cert, &key, &provision)));
    match result {
        Ok(Ok(path)) => {
            *out_signed_path = cstr(path);
            0
        }
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during enterprise signing");
            2
        }
    }
}

// MARK: - Plugin injection (dylib / deb / zip into Frameworks + LC_LOAD_DYLIB)

use std::collections::HashSet;
use std::io::Read as _;
use std::path::Path;

fn u32le(b: &[u8], off: usize) -> u32 {
    u32::from_le_bytes(b[off..off + 4].try_into().unwrap())
}
fn u64le(b: &[u8], off: usize) -> u64 {
    u64::from_le_bytes(b[off..off + 8].try_into().unwrap())
}
fn u32be(b: &[u8], off: usize) -> u32 {
    u32::from_be_bytes(b[off..off + 4].try_into().unwrap())
}
fn u64be(b: &[u8], off: usize) -> u64 {
    u64::from_be_bytes(b[off..off + 8].try_into().unwrap())
}

/// Add one LC_LOAD_DYLIB for `load_path` to the Mach-O slice at
/// `base` in `data`, writing the new command into the zero padding
/// between the load commands and the first section/segment data
/// (the same trick insert_dylib uses; the file size never changes).
/// Already-present loads are left alone.
fn macho_add_load(data: &mut [u8], base: usize, load_path: &str) -> Result<(), String> {
    if data.len() < base + 32 {
        return Err("主程序文件太小".into());
    }
    let magic = u32le(data, base);
    let is64 = match magic {
        0xFEEDFACF => true,
        0xFEEDFACE => false,
        _ => return Err("主程序不是 Mach-O 二进制".into()),
    };
    let header = if is64 { 32 } else { 28 };
    let ncmds = u32le(data, base + 16) as usize;
    let sizeofcmds = u32le(data, base + 20) as usize;
    let cmds_start = base + header;
    let cmds_end = cmds_start + sizeofcmds;
    if cmds_end > data.len() {
        return Err("主程序加载命令区不对".into());
    }
    let mut off = cmds_start;
    let mut first_data = usize::MAX;
    for _ in 0..ncmds {
        if off + 8 > cmds_end {
            break;
        }
        let cmd = u32le(data, off);
        let cmdsize = u32le(data, off + 4) as usize;
        if cmdsize < 8 || off + cmdsize > data.len() {
            break;
        }
        // Dylib load-family commands carry the install name at +8.
        if matches!(cmd, 0xC | 0x18 | 0x1F | 0x23 | 0x8000_0018) && cmdsize >= 24 {
            let name_off = u32le(data, off + 8) as usize;
            if name_off < cmdsize {
                let bytes = &data[off + name_off..off + cmdsize];
                let end = bytes.iter().position(|&c| c == 0).unwrap_or(bytes.len());
                if &bytes[..end] == load_path.as_bytes() {
                    return Ok(()); // already injected
                }
            }
        }
        if cmd == 0x19 && cmdsize >= 72 {
            // LC_SEGMENT_64
            let fileoff = u64le(data, off + 40) as usize;
            if fileoff > 0 {
                first_data = first_data.min(fileoff);
            }
            let nsects = u32le(data, off + 64) as usize;
            for s in 0..nsects {
                let soff = off + 72 + s * 80;
                if soff + 80 > off + cmdsize {
                    break;
                }
                let offset = u32le(data, soff + 48) as usize;
                if offset > 0 {
                    first_data = first_data.min(offset);
                }
            }
        } else if cmd == 0x1 && cmdsize >= 56 {
            // LC_SEGMENT (32-bit)
            let fileoff = u32le(data, off + 32) as usize;
            if fileoff > 0 {
                first_data = first_data.min(fileoff);
            }
            let nsects = u32le(data, off + 48) as usize;
            for s in 0..nsects {
                let soff = off + 56 + s * 68;
                if soff + 68 > off + cmdsize {
                    break;
                }
                let offset = u32le(data, soff + 32) as usize;
                if offset > 0 {
                    first_data = first_data.min(offset);
                }
            }
        }
        off += cmdsize;
    }
    if first_data == usize::MAX {
        first_data = data.len();
    }
    let cmdsize = (24 + load_path.len() + 1 + 7) & !7;
    if cmds_end + cmdsize > first_data {
        return Err("主程序头部没有空余空间插入插件，这个 App 注不了".into());
    }
    let mut cmd = Vec::with_capacity(cmdsize);
    cmd.extend_from_slice(&0xCu32.to_le_bytes()); // LC_LOAD_DYLIB
    cmd.extend_from_slice(&(cmdsize as u32).to_le_bytes());
    cmd.extend_from_slice(&24u32.to_le_bytes()); // name offset
    cmd.extend_from_slice(&2u32.to_le_bytes()); // timestamp
    cmd.extend_from_slice(&0u32.to_le_bytes()); // current version
    cmd.extend_from_slice(&0u32.to_le_bytes()); // compatibility version
    cmd.extend_from_slice(load_path.as_bytes());
    cmd.push(0);
    cmd.resize(cmdsize, 0);
    data[cmds_end..cmds_end + cmdsize].copy_from_slice(&cmd);
    data[base + 16..base + 20].copy_from_slice(&((ncmds + 1) as u32).to_le_bytes());
    data[base + 20..base + 24]
        .copy_from_slice(&((sizeofcmds + cmdsize) as u32).to_le_bytes());
    Ok(())
}

/// Add the load command to every architecture slice of `exe`.
fn add_load_dylib(exe: &Path, load_path: &str) -> Result<(), String> {
    let mut data = std::fs::read(exe).map_err(|e| format!("读主程序失败：{e}"))?;
    if data.len() >= 8 && u32be(&data, 0) == 0xCAFE_BABE {
        let n = u32be(&data, 4) as usize;
        for i in 0..n {
            let entry = 8 + i * 20;
            if entry + 20 > data.len() {
                break;
            }
            let off = u32be(&data, entry + 8) as usize;
            macho_add_load(&mut data, off, load_path)?;
        }
    } else if data.len() >= 8 && u32be(&data, 0) == 0xCAFE_BABF {
        let n = u32be(&data, 4) as usize;
        for i in 0..n {
            let entry = 8 + i * 32;
            if entry + 32 > data.len() {
                break;
            }
            let off = u64be(&data, entry + 8) as usize;
            macho_add_load(&mut data, off, load_path)?;
        }
    } else {
        macho_add_load(&mut data, 0, load_path)?;
    }
    std::fs::write(exe, &data).map_err(|e| format!("写主程序失败：{e}"))?;
    Ok(())
}

fn parse_octal(b: &[u8]) -> usize {
    let s = String::from_utf8_lossy(b);
    let t = s.trim_matches(|c| c == '\0' || c == ' ');
    usize::from_str_radix(t, 8).unwrap_or(0)
}

/// Pull every .dylib out of a .deb (ar archive → data.tar[.gz]).
/// xz/bz2/zst-compressed data members are reported, not decoded.
fn deb_dylibs(bytes: &[u8]) -> Result<Vec<(String, Vec<u8>)>, String> {
    if !bytes.starts_with(b"!<arch>\n") {
        return Err("deb 格式不对".into());
    }
    let mut pos = 8usize;
    let mut string_table: Vec<u8> = Vec::new();
    let mut data_member: Option<(String, Vec<u8>)> = None;
    while pos + 60 <= bytes.len() {
        let header = &bytes[pos..pos + 60];
        if header[58] != b'`' || header[59] != b'\n' {
            break;
        }
        let raw_name = String::from_utf8_lossy(&header[0..16]).trim().to_string();
        let size: usize = String::from_utf8_lossy(&header[48..58])
            .trim()
            .parse()
            .unwrap_or(0);
        let body_start = pos + 60;
        if body_start + size > bytes.len() {
            break;
        }
        let body = &bytes[body_start..body_start + size];
        let mut name = raw_name.clone();
        if raw_name == "//" {
            string_table = body.to_vec();
        } else if let Some(idx) = raw_name
            .strip_prefix('/')
            .and_then(|s| s.parse::<usize>().ok())
        {
            if idx < string_table.len() {
                let end = string_table[idx..]
                    .iter()
                    .position(|&c| c == b'\n')
                    .map(|p| idx + p)
                    .unwrap_or(string_table.len());
                name = String::from_utf8_lossy(&string_table[idx..end])
                    .trim_end_matches('/')
                    .to_string();
            }
        }
        if name.starts_with("data.tar") {
            data_member = Some((name.clone(), body.to_vec()));
        }
        pos = body_start + size + (size % 2);
    }
    let (name, body) = data_member.ok_or("deb 里没有 data.tar")?;
    let tar_bytes: Vec<u8> = if name.ends_with(".gz") {
        let mut out = Vec::new();
        flate2::read::GzDecoder::new(&body[..])
            .read_to_end(&mut out)
            .map_err(|e| format!("deb 解压失败：{e}"))?;
        out
    } else if name == "data.tar" {
        body
    } else {
        return Err(
            "这个 deb 是 xz/bz2 压缩的，暂时注不了；先解出里面的 .dylib 再注".into(),
        );
    };
    let mut out: Vec<(String, Vec<u8>)> = Vec::new();
    let mut p = 0usize;
    while p + 512 <= tar_bytes.len() {
        let h = &tar_bytes[p..p + 512];
        if h.iter().all(|&c| c == 0) {
            break;
        }
        let entry_name = String::from_utf8_lossy(&h[0..100])
            .trim_matches('\0')
            .to_string();
        let size = parse_octal(&h[124..136]);
        let typeflag = h[156];
        let prefix = String::from_utf8_lossy(&h[345..500])
            .trim_matches('\0')
            .to_string();
        let full = if prefix.is_empty() {
            entry_name
        } else {
            format!("{prefix}/{entry_name}")
        };
        let data_start = p + 512;
        if (typeflag == b'0' || typeflag == 0)
            && full.ends_with(".dylib")
            && data_start + size <= tar_bytes.len()
        {
            let base = full.rsplit('/').next().unwrap_or(&full).to_string();
            out.push((base, tar_bytes[data_start..data_start + size].to_vec()));
        }
        p = data_start + size.div_ceil(512) * 512;
    }
    if out.is_empty() {
        return Err("deb 里没找到 .dylib".into());
    }
    Ok(out)
}

/// Stage one plugin file (.dylib / .deb / .zip) into Frameworks,
/// collecting the install names the main executable must load.
fn stage_plugin(
    path: &Path,
    frameworks: &Path,
    loads: &mut Vec<String>,
    done: &mut HashSet<String>,
) -> Result<(), String> {
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();
    let write_dylib = |name: &str, bytes: &[u8], loads: &mut Vec<String>, done: &mut HashSet<String>| -> Result<(), String> {
        if !done.insert(name.to_string()) {
            return Ok(());
        }
        std::fs::write(frameworks.join(name), bytes)
            .map_err(|e| format!("写插件失败：{e}"))?;
        loads.push(format!("@executable_path/Frameworks/{name}"));
        Ok(())
    };
    match ext.as_str() {
        "dylib" => {
            let bytes = std::fs::read(path).map_err(|e| format!("读插件失败：{e}"))?;
            let name = path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("plugin.dylib")
                .to_string();
            write_dylib(&name, &bytes, loads, done)?;
        }
        "deb" => {
            let bytes = std::fs::read(path).map_err(|e| format!("读插件失败：{e}"))?;
            for (name, data) in deb_dylibs(&bytes)? {
                write_dylib(&name, &data, loads, done)?;
            }
        }
        "zip" => {
            let bytes = std::fs::read(path).map_err(|e| format!("读插件失败：{e}"))?;
            let mut archive = zip::ZipArchive::new(std::io::Cursor::new(bytes))
                .map_err(|e| format!("插件 zip 打不开：{e}"))?;
            let mut framework_names: HashSet<String> = HashSet::new();
            for i in 0..archive.len() {
                let mut entry = archive
                    .by_index(i)
                    .map_err(|e| format!("插件 zip 读取失败：{e}"))?;
                if entry.is_dir() {
                    continue;
                }
                let entry_name = entry.name().replace('\\', "/");
                if entry_name.starts_with("__MACOSX") {
                    continue;
                }
                let mut data = Vec::new();
                entry
                    .read_to_end(&mut data)
                    .map_err(|e| format!("插件 zip 读取失败：{e}"))?;
                if let Some(fw_idx) = entry_name.find(".framework/") {
                    // Framework bundle: keep its layout under Frameworks.
                    let start = entry_name[..fw_idx]
                        .rfind('/')
                        .map(|p| p + 1)
                        .unwrap_or(0);
                    let rel = &entry_name[start..];
                    let fw_dir_name = &rel[..rel.find(".framework").unwrap() + 10];
                    let dest = frameworks.join(rel);
                    if let Some(parent) = dest.parent() {
                        std::fs::create_dir_all(parent)
                            .map_err(|e| format!("写插件失败：{e}"))?;
                    }
                    std::fs::write(&dest, &data)
                        .map_err(|e| format!("写插件失败：{e}"))?;
                    framework_names.insert(fw_dir_name.to_string());
                } else if entry_name.ends_with(".dylib") {
                    let base = entry_name
                        .rsplit('/')
                        .next()
                        .unwrap_or(&entry_name)
                        .to_string();
                    write_dylib(&base, &data, loads, done)?;
                }
            }
            for fw in framework_names {
                let stem = fw.trim_end_matches(".framework");
                let binary = frameworks.join(&fw).join(stem);
                if binary.exists() {
                    let load = format!("@executable_path/Frameworks/{fw}/{stem}");
                    if !loads.contains(&load) {
                        loads.push(load);
                    }
                }
            }
        }
        _ => return Err("插件只支持 .dylib / .deb / .zip".into()),
    }
    Ok(())
}

/// Inject the given plugins into the extracted app: dylibs land in
/// Frameworks (signed with the bundle) and the main executable
/// gains one LC_LOAD_DYLIB per plugin.
fn inject_plugins(app: &Application, plugins: &[String]) -> Result<(), String> {
    let bundle_dir = &app.bundle.bundle_dir;
    let frameworks = bundle_dir.join("Frameworks");
    std::fs::create_dir_all(&frameworks).map_err(|e| format!("建 Frameworks 失败：{e}"))?;
    let mut loads: Vec<String> = Vec::new();
    let mut done: HashSet<String> = HashSet::new();
    for plugin in plugins {
        stage_plugin(Path::new(plugin), &frameworks, &mut loads, &mut done)?;
    }
    if loads.is_empty() {
        return Err("插件里没找到能注入的 .dylib".into());
    }
    let exe_name = app
        .bundle
        .app_info
        .get("CFBundleExecutable")
        .and_then(|v| v.as_string())
        .ok_or("读不到主程序名")?
        .to_string();
    let exe_path = bundle_dir.join(&exe_name);
    for load in &loads {
        add_load_dylib(&exe_path, load)?;
    }
    Ok(())
}

// MARK: - Zip tools for the file manager

/// Zip the given absolute paths into `out_zip` (directories are
/// recursed, stored under their folder name; files by basename).
fn zip_create(paths_json: &str, out_zip: &str) -> Result<(), String> {
    let value: serde_json::Value =
        serde_json::from_str(paths_json).map_err(|e| format!("参数不对：{e}"))?;
    let list = value.as_array().ok_or("参数不对")?;
    let file = std::fs::File::create(out_zip).map_err(|e| format!("建压缩包失败：{e}"))?;
    let mut zip = zip::ZipWriter::new(file);
    let options = || {
        zip::write::SimpleFileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated)
    };
    let add_file = |zip: &mut zip::ZipWriter<std::fs::File>, path: &Path, name: &str| -> Result<(), String> {
        #[cfg(unix)]
        let mode = {
            use std::os::unix::fs::PermissionsExt;
            path.metadata().map(|m| m.permissions().mode()).unwrap_or(0o644)
        };
        #[cfg(not(unix))]
        let mode = 0o644;
        zip.start_file(name.to_string(), options().unix_permissions(mode))
            .map_err(|e| format!("压缩失败：{e}"))?;
        let mut source = std::fs::File::open(path).map_err(|e| format!("压缩失败：{e}"))?;
        std::io::copy(&mut source, &mut *zip).map_err(|e| format!("压缩失败：{e}"))?;
        Ok(())
    };
    for item in list {
        let Some(p) = item.as_str() else { continue };
        let path = PathBuf::from(p);
        if path.is_dir() {
            let root = path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("folder")
                .to_string();
            let mut stack = vec![path.clone()];
            let mut all: Vec<PathBuf> = Vec::new();
            while let Some(dir) = stack.pop() {
                let read = std::fs::read_dir(&dir).map_err(|e| format!("读文件夹失败：{e}"))?;
                for entry in read {
                    let entry = entry.map_err(|e| format!("读文件夹失败：{e}"))?;
                    let ep = entry.path();
                    if ep.is_dir() {
                        stack.push(ep.clone());
                    }
                    all.push(ep);
                }
            }
            all.sort();
            for ep in &all {
                let rel = ep.strip_prefix(&path).unwrap_or(ep);
                let name = format!("{}/{}", root, rel.to_string_lossy());
                if ep.is_dir() {
                    zip.add_directory(format!("{name}/"), options())
                        .map_err(|e| format!("压缩失败：{e}"))?;
                } else {
                    add_file(&mut zip, ep, &name)?;
                }
            }
        } else if path.exists() {
            let name = path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("file")
                .to_string();
            add_file(&mut zip, &path, &name)?;
        }
    }
    zip.finish().map_err(|e| format!("压缩失败：{e}"))?;
    Ok(())
}

/// Extract a zip into `dest_dir`, refusing entries that escape it
/// and restoring unix permissions (executable bits matter for
/// IPAs and dylibs).
fn unzip_archive(archive_path: &str, dest_dir: &str) -> Result<(), String> {
    // C-3：失败清掉本次新建的 dest（已存在的目录不动——调用方传的
    // uniqueSibling 恒为新名，实操中总是不存在，但守卫要写）。
    let dest = PathBuf::from(dest_dir);
    let dest_existed = dest.exists();
    let result = unzip_archive_inner(archive_path, &dest);
    if result.is_err() && !dest_existed {
        let _ = std::fs::remove_dir_all(&dest);
    }
    result
}

fn unzip_archive_inner(archive_path: &str, dest: &std::path::Path) -> Result<(), String> {
    // C-3：流式开包，整包不再读进内存（File 满足 Read + Seek，
    // 与 vendored isideload 的 Application::new 同款写法）。
    let file = std::fs::File::open(archive_path).map_err(|e| format!("读压缩包失败：{e}"))?;
    let mut archive = zip::ZipArchive::new(file)
        .map_err(|e| format!("压缩包打不开：{e}"))?;
    std::fs::create_dir_all(dest).map_err(|e| format!("建解压目录失败：{e}"))?;
    // 总量上限 8GB：zip bomb / 损坏包的刹车。Cargo.toml 里没有可用
    // 空间依赖，不为这一个上限引新 crate。
    const TOTAL_LIMIT: u64 = 8 * 1024 * 1024 * 1024;
    let mut total: u64 = 0;
    for i in 0..archive.len() {
        let mut entry = archive
            .by_index(i)
            .map_err(|e| format!("解压失败：{e}"))?;
        let Some(rel) = entry.enclosed_name() else {
            continue; // path escapes the destination — skip it
        };
        let out = dest.join(rel.as_os_str());
        if entry.is_dir() {
            std::fs::create_dir_all(&out).map_err(|e| format!("解压失败：{e}"))?;
            continue;
        }
        if let Some(parent) = out.parent() {
            std::fs::create_dir_all(parent).map_err(|e| format!("解压失败：{e}"))?;
        }
        let mut target = std::fs::File::create(&out).map_err(|e| format!("解压失败：{e}"))?;
        let written = std::io::copy(&mut entry, &mut target).map_err(|e| format!("解压失败：{e}"))?;
        total = total.saturating_add(written);
        if total > TOTAL_LIMIT {
            return Err("解压失败：展开总量超过 8GB 上限".to_string());
        }
        #[cfg(unix)]
        if let Some(mode) = entry.unix_mode() {
            use std::os::unix::fs::PermissionsExt;
            let _ = std::fs::set_permissions(&out, std::fs::Permissions::from_mode(mode));
        }
    }
    Ok(())
}

/// Zip files/folders for the file manager. `paths_json` is a JSON
/// array of absolute paths; success returns 0.
///
/// # Safety
/// All `*const c_char` args must be null or valid C strings; the
/// out pointers must be valid and writable.
pub unsafe fn zip_create_ffi(
    paths_json: *const c_char,
    out_zip: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let json = opt_str(paths_json, "");
    let out = opt_str(out_zip, "");
    let result = catch_unwind(AssertUnwindSafe(|| zip_create(&json, &out)));
    match result {
        Ok(Ok(())) => 0,
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during zip create");
            2
        }
    }
}

/// Extract a zip archive into a directory for the file manager.
///
/// # Safety
/// Same contract as `zip_create_ffi`.
pub unsafe fn unzip_archive_ffi(
    archive_path: *const c_char,
    dest_dir: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let archive = opt_str(archive_path, "");
    let dest = opt_str(dest_dir, "");
    let result = catch_unwind(AssertUnwindSafe(|| unzip_archive(&archive, &dest)));
    match result {
        Ok(Ok(())) => 0,
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during unzip");
            2
        }
    }
}

// MARK: - Mach-O dependency viewer / editor

/// Architecture slices of a Mach-O: the whole file when thin,
/// otherwise each fat slice's offset.
fn macho_slice_bases(data: &[u8]) -> Result<Vec<usize>, String> {
    if data.len() < 4 {
        return Err("不是 Mach-O 文件".into());
    }
    if u32be(data, 0) == 0xCAFE_BABE {
        let n = u32be(data, 4) as usize;
        let mut bases = Vec::new();
        for i in 0..n {
            let entry = 8 + i * 20;
            if entry + 20 > data.len() {
                break;
            }
            bases.push(u32be(data, entry + 8) as usize);
        }
        return Ok(bases);
    }
    if u32be(data, 0) == 0xCAFE_BABF {
        let n = u32be(data, 4) as usize;
        let mut bases = Vec::new();
        for i in 0..n {
            let entry = 8 + i * 32;
            if entry + 32 > data.len() {
                break;
            }
            bases.push(u64be(data, entry + 8) as usize);
        }
        return Ok(bases);
    }
    Ok(vec![0])
}

/// (is64, ncmds, sizeofcmds, cmds_start) for the slice at `base`.
fn slice_header(data: &[u8], base: usize) -> Result<(bool, usize, usize, usize), String> {
    if data.len() < base + 28 {
        return Err("不是 Mach-O 文件".into());
    }
    let magic = u32le(data, base);
    let is64 = match magic {
        0xFEEDFACF => true,
        0xFEEDFACE => false,
        _ => return Err("不是 Mach-O 文件".into()),
    };
    let header = if is64 { 32 } else { 28 };
    Ok((
        is64,
        u32le(data, base + 16) as usize,
        u32le(data, base + 20) as usize,
        base + header,
    ))
}

fn arch_name(data: &[u8], base: usize) -> String {
    if data.len() < base + 8 {
        return "unknown".into();
    }
    match u32le(data, base + 4) {
        0x0100_000C => "arm64".into(),
        0x0100_0007 => "x86_64".into(),
        0x0C => "armv7".into(),
        0x07 => "i386".into(),
        other => format!("cpu 0x{other:x}"),
    }
}

/// The name string of a dylib/rpath load command (both keep the
/// string offset at +8 and the string inside the command).
fn cmd_string(data: &[u8], off: usize, cmdsize: usize) -> Option<String> {
    if cmdsize < 12 {
        return None;
    }
    let name_off = u32le(data, off + 8) as usize;
    if name_off >= cmdsize {
        return None;
    }
    let bytes = &data[off + name_off..off + cmdsize];
    let end = bytes.iter().position(|&c| c == 0).unwrap_or(bytes.len());
    Some(String::from_utf8_lossy(&bytes[..end]).to_string())
}

fn dep_kind(cmd: u32) -> Option<&'static str> {
    match cmd {
        0xC => Some("load"),
        0x18 | 0x8000_0018 => Some("weak"),
        0x1F => Some("reexport"),
        0x23 => Some("upward"),
        0xD => Some("id"),
        _ => None,
    }
}

/// JSON description of every slice's dylib dependencies + rpaths.
fn macho_info(path: &str) -> Result<String, String> {
    let data = std::fs::read(path).map_err(|e| format!("读文件失败：{e}"))?;
    let bases = macho_slice_bases(&data)?;
    let mut slices = Vec::new();
    for base in &bases {
        let (_, ncmds, sizeofcmds, cmds_start) = slice_header(&data, *base)?;
        let cmds_end = cmds_start + sizeofcmds;
        let mut deps = Vec::new();
        let mut rpaths = Vec::new();
        let mut off = cmds_start;
        for _ in 0..ncmds {
            if off + 8 > cmds_end || off + 8 > data.len() {
                break;
            }
            let cmd = u32le(&data, off);
            let cmdsize = u32le(&data, off + 4) as usize;
            if cmdsize < 8 || off + cmdsize > data.len() {
                break;
            }
            if let Some(kind) = dep_kind(cmd) {
                if let Some(name) = cmd_string(&data, off, cmdsize) {
                    deps.push(serde_json::json!({"kind": kind, "name": name}));
                }
            } else if cmd == 0x8000_001C {
                if let Some(p) = cmd_string(&data, off, cmdsize) {
                    rpaths.push(p);
                }
            }
            off += cmdsize;
        }
        slices.push(serde_json::json!({
            "arch": arch_name(&data, *base),
            "deps": deps,
            "rpaths": rpaths,
        }));
    }
    let out = serde_json::json!({"fat": bases.len() > 1, "slices": slices});
    Ok(out.to_string())
}

/// Apply one edit ({action:"remove", name} or
/// {action:"rename", name, newName}) to every slice of the file.
/// Removing shifts the remaining load commands down; renaming
/// must fit the space the existing command already occupies.
fn macho_edit(path: &str, op_json: &str) -> Result<(), String> {
    let op: serde_json::Value =
        serde_json::from_str(op_json).map_err(|e| format!("参数不对：{e}"))?;
    let action = op.get("action").and_then(|v| v.as_str()).unwrap_or("");
    let name = op.get("name").and_then(|v| v.as_str()).unwrap_or("");
    let new_name = op.get("newName").and_then(|v| v.as_str()).unwrap_or("");
    if name.is_empty() || (action != "remove" && action != "rename") {
        return Err("参数不对".into());
    }
    if action == "rename" && new_name.is_empty() {
        return Err("新名字不能为空".into());
    }
    let mut data = std::fs::read(path).map_err(|e| format!("读文件失败：{e}"))?;
    let bases = macho_slice_bases(&data)?;
    let mut hits = 0usize;
    for base in &bases {
        let base = *base;
        let (_, ncmds, sizeofcmds, cmds_start) = slice_header(&data, base)?;
        if action == "rename" {
            let mut off = cmds_start;
            let mut remaining = ncmds;
            let mut left = sizeofcmds;
            while remaining > 0 && left >= 8 {
                if off + 8 > data.len() {
                    break;
                }
                let cmd = u32le(&data, off);
                let cmdsize = u32le(&data, off + 4) as usize;
                if cmdsize < 8 || off + cmdsize > data.len() {
                    break;
                }
                if dep_kind(cmd).is_some()
                    && cmd_string(&data, off, cmdsize).as_deref() == Some(name)
                {
                    let name_off = u32le(&data, off + 8) as usize;
                    let needed = name_off + new_name.len() + 1;
                    if needed > cmdsize {
                        return Err(format!(
                            "新名字太长：这个命令只有 {cmdsize} 字节，装不下"
                        ));
                    }
                    let start = off + name_off;
                    data[start..start + new_name.len()].copy_from_slice(new_name.as_bytes());
                    for b in &mut data[start + new_name.len()..off + cmdsize] {
                        *b = 0;
                    }
                    hits += 1;
                }
                off += cmdsize;
                left -= cmdsize;
                remaining -= 1;
            }
        } else {
            // remove: collect the matching commands, then cut them
            // out from last to first so earlier offsets stay valid.
            let mut cuts: Vec<(usize, usize)> = Vec::new();
            let mut off = cmds_start;
            for _ in 0..ncmds {
                if off + 8 > data.len() {
                    break;
                }
                let cmd = u32le(&data, off);
                let cmdsize = u32le(&data, off + 4) as usize;
                if cmdsize < 8 || off + cmdsize > data.len() {
                    break;
                }
                if dep_kind(cmd).is_some() && cmd != 0xD
                    && cmd_string(&data, off, cmdsize).as_deref() == Some(name)
                {
                    cuts.push((off, cmdsize));
                }
                off += cmdsize;
            }
            let cmds_end = cmds_start + sizeofcmds;
            let mut removed_bytes = 0usize;
            for (off, cmdsize) in cuts.iter().rev() {
                let (off, cmdsize) = (*off, *cmdsize);
                data.copy_within(off + cmdsize..cmds_end, off);
                for b in &mut data[cmds_end - cmdsize..cmds_end] {
                    *b = 0;
                }
                removed_bytes += cmdsize;
                hits += 1;
            }
            if !cuts.is_empty() {
                let new_ncmds = ncmds - cuts.len();
                let new_sizeofcmds = sizeofcmds - removed_bytes;
                data[base + 16..base + 20]
                    .copy_from_slice(&(new_ncmds as u32).to_le_bytes());
                data[base + 20..base + 24]
                    .copy_from_slice(&(new_sizeofcmds as u32).to_le_bytes());
            }
        }
    }
    if hits == 0 {
        return Err("没找到这个依赖".into());
    }
    std::fs::write(path, &data).map_err(|e| format!("写文件失败：{e}"))?;
    Ok(())
}

/// Mach-O dependency info as JSON in `*out_json`.
///
/// # Safety
/// All `*const c_char` args must be null or valid C strings; the
/// out pointers must be valid and writable.
pub unsafe fn macho_info_ffi(
    path: *const c_char,
    out_json: *mut *mut c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let p = opt_str(path, "");
    let result = catch_unwind(AssertUnwindSafe(|| macho_info(&p)));
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
            *out_error = cstr("panic during macho info");
            2
        }
    }
}

/// One Mach-O dependency edit (see `macho_edit` for the JSON op).
///
/// # Safety
/// Same contract as `macho_info_ffi`.
pub unsafe fn macho_edit_ffi(
    path: *const c_char,
    op_json: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    let p = opt_str(path, "");
    let j = opt_str(op_json, "");
    let result = catch_unwind(AssertUnwindSafe(|| macho_edit(&p, &j)));
    match result {
        Ok(Ok(())) => 0,
        Ok(Err(e)) => {
            *out_error = cstr(e);
            1
        }
        Err(_) => {
            *out_error = cstr("panic during macho edit");
            2
        }
    }
}
