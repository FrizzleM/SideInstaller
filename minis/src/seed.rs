//! Step 7: hand the newly installed SideInstaller this pairing, as Side by Side
//! hands one to SideInstaller on another iPhone
//! (`SideBySideView.handOffToSideInstaller`): the file goes where SideInstaller
//! keeps its own (`PrivateStore.pairingFile`), a merged file from an older
//! pairing is deleted, and the file is marked as imported, so SideInstaller
//! connects with it from its first launch instead of pairing itself.
//!
//! house_arrest vends the whole container because the app is signed for
//! development; Application Support is outside Documents, and SideInstaller
//! only moves a pairing file out of Documents when it has none of its own.

use std::path::Path;

use idevice::afc::opcode::AfcFopenMode;
use idevice::afc::AfcClient;
use idevice::house_arrest::HouseArrestClient;
use idevice::RsdService;

use crate::fail::{chain, Fail, Result};
use crate::tunnel::Connection;
use crate::ui;

pub const PAIRING_PATH: &str = "/Library/Application Support/rp_pairing_file.plist";
const MERGED_PATH: &str = "/Library/Application Support/combined_pairing_file.plist";
/// `Engine.importedPairingNameKey`.
const IMPORTED_NAME_KEY: &str = "importedPairingFileName";
/// The name SideInstaller shows the file under, as it shows "SideBySide.plist"
/// for one Side by Side hands over.
const HANDED_OVER_NAME: &str = "siboot.plist";

pub async fn hand_over(
    connection: &mut Connection,
    bundle_id: &str,
    pairing_path: &Path,
) -> Result<()> {
    let pairing = std::fs::read(pairing_path).map_err(|e| {
        Fail::new(
            format!("Couldn't read {}.", pairing_path.display()),
            e.to_string(),
        )
    })?;

    let house_arrest =
        HouseArrestClient::connect_rsd(&mut connection.adapter, &mut connection.handshake)
            .await
            .map_err(|e| Fail::new("Couldn't reach house_arrest on this iPhone.", chain(&e)))?;
    let mut afc = house_arrest.vend_container(bundle_id).await.map_err(|e| {
        Fail::new(
            format!("Couldn't open {bundle_id}'s container. Import the pairing file in SideInstaller instead: it's at ~/.siboot/rp_pairing_file.plist in Minis."),
            chain(&e),
        )
    })?;

    for dir in ["/Library", "/Library/Application Support"] {
        let _ = afc.mk_dir(dir).await;
    }
    let written = write_verified(&mut afc, PAIRING_PATH, &pairing).await?;
    ui::ok(&format!(
        "pairing file written into SideInstaller ({written} bytes, read back and checked)"
    ));

    // There's none on a fresh install; one from an older pairing would hand
    // other apps that pairing.
    let _ = afc.remove(MERGED_PATH).await;

    let prefs_path = format!("/Library/Preferences/{bundle_id}.plist");
    match mark_imported(&mut afc, &prefs_path).await {
        Ok(()) => ui::detail(&format!(
            "marked it as the imported file \"{HANDED_OVER_NAME}\" ({prefs_path})"
        )),
        Err(e) => {
            ui::warn(
                "Couldn't mark the pairing file as imported. SideInstaller still connects with it,",
            );
            ui::warn("but may offer to pair again.");
            ui::detail(&e.raw);
        }
    }
    Ok(())
}

/// Set `importedPairingFileName` in SideInstaller's preferences, keeping what's
/// there. Written beside the file and renamed over it, so a broken upload can't
/// leave a half-written preferences file.
async fn mark_imported(afc: &mut AfcClient, prefs_path: &str) -> Result<()> {
    let mut prefs = match read_if_present(afc, prefs_path).await? {
        Some(bytes) if !bytes.is_empty() => plist::from_bytes::<plist::Dictionary>(&bytes)
            .map_err(|e| Fail::new("SideInstaller's preferences aren't a plist.", e.to_string()))?,
        _ => plist::Dictionary::new(),
    };
    prefs.insert(IMPORTED_NAME_KEY.into(), HANDED_OVER_NAME.into());
    let mut bytes = Vec::new();
    plist::to_writer_binary(&mut bytes, &prefs).map_err(|e| {
        Fail::new(
            "Couldn't encode SideInstaller's preferences.",
            e.to_string(),
        )
    })?;
    let _ = afc.mk_dir("/Library/Preferences").await;
    let staging = format!("{prefs_path}.siboot");
    write_verified(afc, &staging, &bytes).await?;
    afc.rename(staging, prefs_path)
        .await
        .map_err(|e| Fail::new("Couldn't save SideInstaller's preferences.", chain(&e)))?;
    Ok(())
}

async fn read_if_present(afc: &mut AfcClient, path: &str) -> Result<Option<Vec<u8>>> {
    if afc.get_file_info(path).await.is_err() {
        return Ok(None);
    }
    let mut file = afc
        .open(path, AfcFopenMode::RdOnly)
        .await
        .map_err(|e| Fail::new(format!("Couldn't open {path}."), chain(&e)))?;
    let bytes = file
        .read_entire()
        .await
        .map_err(|e| Fail::new(format!("Couldn't read {path}."), chain(&e)))?;
    let _ = file.close().await;
    Ok(Some(bytes))
}

/// Write `data` to `path`, then read it back and compare. Returns its length.
async fn write_verified(afc: &mut AfcClient, path: &str, data: &[u8]) -> Result<usize> {
    let mut file = afc
        .open(path, AfcFopenMode::WrOnly)
        .await
        .map_err(|e| Fail::new(format!("Couldn't create {path}."), chain(&e)))?;
    file.write_entire(data)
        .await
        .map_err(|e| Fail::new(format!("Couldn't write {path}."), chain(&e)))?;
    file.close()
        .await
        .map_err(|e| Fail::new(format!("Couldn't write {path}."), chain(&e)))?;
    match read_if_present(afc, path).await? {
        Some(back) if back == data => Ok(data.len()),
        Some(back) => Err(Fail::new(
            format!("{path} reads back different from what was written."),
            format!("wrote {} bytes, read {}", data.len(), back.len()),
        )),
        None => Err(Fail::new(format!("{path} vanished after writing."), "")),
    }
}
