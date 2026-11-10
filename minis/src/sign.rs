//! Step 5: fetch SideInstaller and sign it for this iPhone, as Side by Side
//! does for another one: register the device, then isideload's `sign_app`
//! with the app group and no Increased Memory Limit (`SideBySideView.signApp`).

use std::io::Write as _;
use std::path::{Path, PathBuf};

use isideload::sideload::sideloader::MemoryLimit;

use crate::account::Session;
use crate::fail::{Fail, Result};
use crate::tunnel::DeviceInfo;
use crate::{ui, Args, VERSION};

/// The release Side by Side installs (`SideBySideView.releaseIPA`).
pub const RELEASE_IPA: &str =
    "https://github.com/FrizzleM/SideInstaller/releases/latest/download/SideInstaller.ipa";

pub struct Signed {
    /// The signed `.app` folder, ready to upload.
    pub app_dir: PathBuf,
    pub bundle_id: String,
    pub name: String,
}

/// `--ipa` as a path, or the URL it names, or SideInstaller's latest release.
pub async fn fetch_ipa(args: &Args) -> Result<PathBuf> {
    match args.ipa.as_deref() {
        Some(source) if !source.starts_with("https://") && !source.starts_with("http://") => {
            let path = PathBuf::from(source);
            check_ipa(&path)?;
            ui::ok(&format!("using {}", path.display()));
            Ok(path)
        }
        source => {
            let url = source.unwrap_or(RELEASE_IPA);
            let dir = args.home.join("downloads");
            std::fs::create_dir_all(&dir).map_err(|e| {
                Fail::new(format!("Couldn't create {}.", dir.display()), e.to_string())
            })?;
            download(url, &dir.join("SideInstaller.ipa")).await
        }
    }
}

async fn download(url: &str, dest: &Path) -> Result<PathBuf> {
    ui::info(&format!("downloading {url}"));
    let client = reqwest::Client::builder()
        .user_agent(format!("siboot/{VERSION}"))
        .build()
        .map_err(|e| Fail::new("Couldn't start a download.", e.to_string()))?;
    let mut response = client.get(url).send().await.map_err(|e| {
        Fail::new(
            "Couldn't download SideInstaller. Check the internet connection (LocalDevVPN only \
             routes 10.7.0.1, so it isn't the cause).",
            crate::error_text::error_text(&e),
        )
    })?;
    if !response.status().is_success() {
        return Err(Fail::new(
            format!(
                "GitHub answered {} for the SideInstaller download. Try again in a minute.",
                response.status()
            ),
            url.to_string(),
        ));
    }
    let total = response.content_length();
    let partial = dest.with_extension("ipa.part");
    let mut file = std::fs::File::create(&partial).map_err(|e| {
        Fail::new(
            format!("Couldn't write {}.", partial.display()),
            e.to_string(),
        )
    })?;
    let mut received: u64 = 0;
    let mut shown = u64::MAX;
    loop {
        let chunk = response.chunk().await.map_err(|e| {
            Fail::new(
                "The SideInstaller download broke off. Run siboot again.",
                e.to_string(),
            )
        })?;
        let Some(chunk) = chunk else { break };
        file.write_all(&chunk).map_err(|e| {
            Fail::new(
                format!("Couldn't write {}.", partial.display()),
                e.to_string(),
            )
        })?;
        received += chunk.len() as u64;
        if let Some(total) = total.filter(|t| *t > 0) {
            let percent = received * 100 / total;
            if percent != shown && (percent.is_multiple_of(5) || percent == 100) {
                ui::progress("downloaded", percent);
                shown = percent;
            }
        }
    }
    drop(file);
    std::fs::rename(&partial, dest)
        .map_err(|e| Fail::new(format!("Couldn't write {}.", dest.display()), e.to_string()))?;
    check_ipa(dest)?;
    ui::ok(&format!(
        "downloaded SideInstaller ({:.1} MB)",
        received as f64 / 1_048_576.0
    ));
    Ok(dest.to_path_buf())
}

/// An IPA is a zip: an error page or a truncated download isn't, and would
/// only fail later, inside the signer.
fn check_ipa(path: &Path) -> Result<()> {
    let mut magic = [0u8; 4];
    let read =
        std::fs::File::open(path).and_then(|mut f| std::io::Read::read_exact(&mut f, &mut magic));
    match read {
        Ok(()) if &magic == b"PK\x03\x04" => Ok(()),
        Ok(()) => Err(Fail::new(
            format!(
                "{} isn't an IPA. GitHub may have returned an error page: try again in a minute.",
                path.display()
            ),
            format!("first bytes {magic:02x?}"),
        )),
        Err(e) => Err(Fail::new(
            format!("Couldn't read {}.", path.display()),
            e.to_string(),
        )),
    }
}

pub async fn sign(session: &mut Session, ipa: &Path, device: &DeviceInfo) -> Result<Signed> {
    ui::info("registering this iPhone with your team and signing (this takes a while here) …");
    let (app_dir, _special) = session
        .sideloader
        .sign_app(
            ipa.to_path_buf(),
            None,
            MemoryLimit::Off,
            true,
            Some((device.name.as_str(), device.udid.as_str())),
            None,
        )
        .await
        .map_err(|e| {
            let text = crate::error_text::report_text(&e);
            Fail::new(sign_advice(&text), text)
        })?;
    let (bundle_id, name) = bundle_info(&app_dir)?;
    ui::ok(&format!("signed {name} as {bundle_id}"));
    Ok(Signed {
        app_dir,
        bundle_id,
        name,
    })
}

/// Advice for the refusals SideInstaller's own signing explains.
fn sign_advice(text: &str) -> String {
    if text.starts_with("device registration failed") {
        "Apple wouldn't register this iPhone with your developer team, so it won't issue a \
         provisioning profile."
            .into()
    } else if text.contains("7460") {
        "Apple won't issue a signing certificate: it says one already exists (error 7460).".into()
    } else if text.contains("9401")
        || text
            .to_ascii_lowercase()
            .contains("maximum number of app ids")
    {
        "This Apple Account has reached its limit of App IDs for the week. Wait for one to expire, \
         or use another account."
            .into()
    } else {
        "Signing failed.".into()
    }
}

/// Bundle id and Home Screen name of the signed app.
fn bundle_info(app_dir: &Path) -> Result<(String, String)> {
    let info: plist::Dictionary = plist::from_file(app_dir.join("Info.plist"))
        .map_err(|e| Fail::new("The signed app has no readable Info.plist.", e.to_string()))?;
    let text = |key: &str| {
        info.get(key)
            .and_then(|v| v.as_string())
            .map(str::to_string)
    };
    let bundle_id = text("CFBundleIdentifier").ok_or_else(|| {
        Fail::new(
            "The signed app has no bundle identifier.",
            "CFBundleIdentifier missing",
        )
    })?;
    let name = text("CFBundleDisplayName")
        .filter(|n| !n.is_empty())
        .or_else(|| text("CFBundleName"))
        .unwrap_or_else(|| "SideInstaller".into());
    Ok((bundle_id, name))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_a_zip_passes_as_an_ipa() {
        let dir = std::env::temp_dir().join(format!("siboot-ipa-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let good = dir.join("good.ipa");
        std::fs::write(&good, b"PK\x03\x04rest").unwrap();
        assert!(check_ipa(&good).is_ok());
        let page = dir.join("page.ipa");
        std::fs::write(&page, b"<!DOCTYPE html>").unwrap();
        assert!(check_ipa(&page)
            .unwrap_err()
            .advice
            .contains("isn't an IPA"));
        assert!(check_ipa(&dir.join("missing.ipa")).is_err());
    }

    #[test]
    fn the_bundle_id_and_name_come_from_info_plist() {
        let dir = std::env::temp_dir().join(format!(
            "siboot-app-{}/SideInstaller.app",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let mut info = plist::Dictionary::new();
        info.insert(
            "CFBundleIdentifier".into(),
            "com.frizzlem.sideinstaller.ABCDE12345".into(),
        );
        info.insert("CFBundleName".into(), "SideInstaller".into());
        plist::to_file_xml(dir.join("Info.plist"), &info).unwrap();
        let (id, name) = bundle_info(&dir).unwrap();
        assert_eq!(id, "com.frizzlem.sideinstaller.ABCDE12345");
        assert_eq!(name, "SideInstaller");
    }
}
