//! Step 6: upload the signed app to /PublicStaging over AFC and install it with
//! installation_proxy, as `DeviceConnection.installSignedApp` does.
//!
//! The upload is checked file by file before installing: installd accepts a
//! bundle with a sealed file missing and installs it without a word, and the
//! app then fails to open.

use std::path::{Path, PathBuf};

use idevice::afc::opcode::AfcFopenMode;
use idevice::afc::AfcClient;
use idevice::installation_proxy::InstallationProxyClient;
use idevice::RsdService;

use crate::fail::{chain, Fail, Result};
use crate::tunnel::Connection;
use crate::ui;

const STAGING: &str = "/PublicStaging";

/// One file or folder of the bundle, relative to its root.
#[derive(Debug, PartialEq)]
pub struct Entry {
    pub relative: String,
    pub is_dir: bool,
    pub size: u64,
}

pub async fn install(connection: &mut Connection, app_dir: &Path) -> Result<()> {
    let bundle_name = app_dir
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| {
            Fail::new(
                "The signed app has no folder name.",
                app_dir.display().to_string(),
            )
        })?;
    let remote_root = format!("{STAGING}/{bundle_name}");
    let entries = bundle_entries(app_dir).map_err(|e| {
        Fail::new(
            format!("Couldn't read {}.", app_dir.display()),
            e.to_string(),
        )
    })?;
    let total: u64 = entries.iter().map(|e| e.size).sum();
    ui::info(&format!(
        "uploading {} files ({:.1} MB) …",
        entries.iter().filter(|e| !e.is_dir).count(),
        total as f64 / 1_048_576.0
    ));

    let mut afc = AfcClient::connect_rsd(&mut connection.adapter, &mut connection.handshake)
        .await
        .map_err(|e| Fail::new("Couldn't open AFC on this iPhone.", chain(&e)))?;
    // Left from an earlier run, it would mix old files into this upload.
    let _ = afc.remove_all(remote_root.clone()).await;
    let _ = afc.mk_dir(STAGING).await;
    afc.mk_dir(remote_root.clone()).await.map_err(|e| {
        Fail::new(
            format!("Couldn't create {remote_root} on this iPhone."),
            chain(&e),
        )
    })?;

    let started = std::time::Instant::now();
    let mut sent: u64 = 0;
    let mut shown = u64::MAX;
    for entry in &entries {
        let remote = format!("{remote_root}/{}", entry.relative);
        if entry.is_dir {
            afc.mk_dir(remote.clone())
                .await
                .map_err(|e| Fail::new(format!("Couldn't create {remote}."), chain(&e)))?;
            continue;
        }
        let bytes = std::fs::read(app_dir.join(&entry.relative))
            .map_err(|e| Fail::new(format!("Couldn't read {}.", entry.relative), e.to_string()))?;
        let mut file = afc
            .open(remote.clone(), AfcFopenMode::WrOnly)
            .await
            .map_err(|e| {
                Fail::new(
                    format!("Couldn't create {remote} on this iPhone."),
                    chain(&e),
                )
            })?;
        file.write_entire(&bytes).await.map_err(|e| {
            Fail::new(
                format!("The upload of {} broke off.", entry.relative),
                chain(&e),
            )
        })?;
        file.close().await.map_err(|e| {
            Fail::new(
                format!("The upload of {} broke off.", entry.relative),
                chain(&e),
            )
        })?;
        sent += entry.size;
        let percent = (sent * 100).checked_div(total).unwrap_or(100);
        if percent != shown && percent.is_multiple_of(5) {
            ui::progress("uploaded", percent);
            shown = percent;
        }
    }
    if shown != 100 {
        ui::progress("uploaded", 100);
    }
    ui::detail(&format!(
        "upload took {:.1} s",
        started.elapsed().as_secs_f64()
    ));

    // Every file, at its size: an incomplete bundle installs "fine".
    let mut missing = Vec::new();
    for entry in entries.iter().filter(|e| !e.is_dir) {
        let remote = format!("{remote_root}/{}", entry.relative);
        match afc.get_file_info(remote).await {
            Ok(info) if info.size as u64 == entry.size => {}
            Ok(info) => missing.push(format!(
                "{} ({} of {} bytes)",
                entry.relative, info.size, entry.size
            )),
            Err(_) => missing.push(entry.relative.clone()),
        }
    }
    if !missing.is_empty() {
        return Err(Fail::new(
            format!(
                "{} files didn't arrive whole on the iPhone. Run siboot again.",
                missing.len()
            ),
            missing.join(", "),
        ));
    }
    ui::ok("upload checked: every file arrived whole");

    let mut proxy =
        InstallationProxyClient::connect_rsd(&mut connection.adapter, &mut connection.handshake)
            .await
            .map_err(|e| {
                Fail::new(
                    "Couldn't reach installation_proxy on this iPhone.",
                    chain(&e),
                )
            })?;
    // Without PackageType Developer, installd never reads the embedded profile
    // and rejects the bundle with 0xe8008015.
    let mut options = plist::Dictionary::new();
    options.insert("PackageType".into(), "Developer".into());
    ui::info("installing …");
    let installed = proxy
        .install_with_callback(
            remote_root.clone(),
            Some(plist::Value::Dictionary(options)),
            |(percent, _): (u64, ())| async move {
                ui::progress("installed", percent);
            },
            (),
        )
        .await;
    if let Err(e) = installed {
        let raw = chain(&e);
        return Err(Fail::new(install_advice(&raw), raw));
    }
    let _ = afc.remove_all(remote_root).await;
    Ok(())
}

fn install_advice(raw: &str) -> String {
    let lower = raw.to_ascii_lowercase();
    // `Engine.isAppLimitError`'s two phrasings.
    if lower.contains("maximum number of installed apps")
        || lower.contains("maximum number of apps for free development profiles")
    {
        "This iPhone already has 3 apps signed with a free Apple Account. Delete one, then run siboot again.".into()
    } else if lower.contains("0xe8008015") || lower.contains("provisioning") {
        "installd refused the provisioning profile. Run siboot again; if it keeps failing, the \
         profile may not include this iPhone."
            .into()
    } else {
        "installd refused SideInstaller.".into()
    }
}

/// Every folder and file under `root`, each folder before what's in it, in a
/// stable order.
pub fn bundle_entries(root: &Path) -> std::io::Result<Vec<Entry>> {
    let mut out = Vec::new();
    walk(root, root, &mut out)?;
    Ok(out)
}

fn walk(root: &Path, dir: &Path, out: &mut Vec<Entry>) -> std::io::Result<()> {
    let mut children: Vec<PathBuf> = std::fs::read_dir(dir)?
        .map(|entry| entry.map(|e| e.path()))
        .collect::<std::io::Result<_>>()?;
    children.sort();
    for path in children {
        let relative = path
            .strip_prefix(root)
            .map_err(|e| std::io::Error::other(e.to_string()))?
            .to_string_lossy()
            .replace('\\', "/");
        // Follows symlinks: AFC uploads their contents as plain files.
        let meta = std::fs::metadata(&path)?;
        if meta.is_dir() {
            out.push(Entry {
                relative,
                is_dir: true,
                size: 0,
            });
            walk(root, &path, out)?;
        } else {
            out.push(Entry {
                relative,
                is_dir: false,
                size: meta.len(),
            });
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn folders_come_before_their_files_and_sizes_add_up() {
        let root =
            std::env::temp_dir().join(format!("siboot-bundle-{}/Demo.app", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(root.join("Frameworks/Core.framework")).unwrap();
        std::fs::write(root.join("Info.plist"), b"1234").unwrap();
        std::fs::write(root.join("Demo"), vec![0u8; 100]).unwrap();
        std::fs::write(root.join("Frameworks/Core.framework/Core"), vec![0u8; 10]).unwrap();
        let entries = bundle_entries(&root).unwrap();
        let names: Vec<&str> = entries.iter().map(|e| e.relative.as_str()).collect();
        assert_eq!(
            names,
            [
                "Demo",
                "Frameworks",
                "Frameworks/Core.framework",
                "Frameworks/Core.framework/Core",
                "Info.plist"
            ]
        );
        assert_eq!(entries.iter().map(|e| e.size).sum::<u64>(), 114);
        let framework = names
            .iter()
            .position(|n| *n == "Frameworks/Core.framework")
            .unwrap();
        let inside = names
            .iter()
            .position(|n| *n == "Frameworks/Core.framework/Core")
            .unwrap();
        assert!(framework < inside);
    }

    #[test]
    fn install_refusals_get_advice() {
        assert!(
            install_advice("ApplicationVerificationFailed: 0xe8008015 profile")
                .contains("provisioning profile")
        );
        assert!(
            install_advice("This device has reached the maximum number of installed apps")
                .contains("3 apps")
        );
        assert!(install_advice("something else").contains("refused"));
    }
}
