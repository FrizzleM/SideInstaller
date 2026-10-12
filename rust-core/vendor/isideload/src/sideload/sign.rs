use apple_codesign_quick::{
    BundleSigningSettings, ProvisioningProfile, RustCryptoCmsSigner, sign_bundle,
};
use plist::Dictionary;
use rootcause::prelude::*;
use tracing::info;

use crate::{
    dev::{app_ids::Profile, teams::DeveloperTeam},
    sideload::{
        application::{Application, SpecialApp},
        cert_identity::CertificateIdentity,
    },
};

/// Signs the app and every bundle in it with apple-codesign-quick, which
/// hashes and signs nested bundles in parallel (upstream cc9fa9c, iLoader
/// 2.3.0), and embeds the provisioning profile while doing so.
///
/// Every app extension, nested ones too, gets the main app's entitlements and
/// a copy of its profile, as before the switch: the main profile is the one
/// that authorizes them (README change 1). apple-codesign-quick gives a nested
/// bundle only what is listed for its bundle ID, which by default is no profile
/// and no entitlements, so each extension is listed. Frameworks and dylibs get
/// neither, as Xcode signs them.
pub fn sign(
    app: &mut Application,
    cert_identity: &CertificateIdentity,
    provisioning_profile: &Profile,
    special: &Option<SpecialApp>,
    team: &DeveloperTeam,
) -> Result<(), Report> {
    let profile_der: &[u8] = provisioning_profile.encoded_profile.as_ref();
    let profile =
        ProvisioningProfile::parse(profile_der).context("Failed to parse provisioning profile")?;
    let certificate_chain = cert_identity
        .profile_to_certificate_chain(&profile)
        .context("Failed to build the signing certificate chain")?;
    let signer = RustCryptoCmsSigner::new(
        cert_identity.private_key.clone(),
        cert_identity.certificate.clone(),
        certificate_chain,
    );

    let entitlements = entitlements(&profile, special, team);

    clear_old_signatures(app)?;

    let mut settings = BundleSigningSettings::new(&team.team_id, entitlements.clone(), Some(&signer));
    settings.embedded_mobileprovision = Some(profile_der);
    for bundle in app.bundle.collect_nested_bundles() {
        if bundle.bundle_dir.extension().and_then(|e| e.to_str()) != Some("appex") {
            continue;
        }
        let Some(bundle_id) = bundle.bundle_identifier() else {
            continue;
        };
        settings
            .embedded_mobileprovisions_by_bundle_id
            .insert(bundle_id.to_string(), profile_der);
        settings
            .entitlements_by_bundle_id
            .insert(bundle_id.to_string(), entitlements.clone());
    }

    info!(
        "Signing {} and {} app extension(s)",
        app.bundle
            .bundle_dir
            .file_name()
            .unwrap_or(app.bundle.bundle_dir.as_os_str())
            .to_string_lossy(),
        settings.entitlements_by_bundle_id.len()
    );
    sign_bundle(&app.bundle.bundle_dir, &settings).context(format!(
        "Failed to sign bundle: {}",
        app.bundle.bundle_dir.display()
    ))?;

    Ok(())
}

/// Deletes each bundle's `_CodeSignature` folder before it is signed again.
///
/// apple-codesign-quick replaces `CodeResources` but seals anything else it
/// finds in there, such as the `ResourceRules` some re-signed IPAs carry.
/// Nothing in `_CodeSignature` is ever a sealed resource, so verification then
/// fails with "a sealed resource is missing or invalid". The old signer
/// skipped the folder.
fn clear_old_signatures(app: &Application) -> Result<(), Report> {
    let nested = app.bundle.collect_nested_bundles();
    let bundle_dirs = std::iter::once(&app.bundle.bundle_dir).chain(nested.iter().map(|b| &b.bundle_dir));
    for bundle_dir in bundle_dirs {
        let signature_dir = bundle_dir.join("_CodeSignature");
        if signature_dir.is_dir() {
            std::fs::remove_dir_all(&signature_dir).context(format!(
                "Failed to remove the old signature in {}",
                bundle_dir.display()
            ))?;
        }
    }
    Ok(())
}

/// The profile's entitlements, plus the keychain groups LiveContainer needs.
fn entitlements(
    profile: &ProvisioningProfile,
    special: &Option<SpecialApp>,
    team: &DeveloperTeam,
) -> Dictionary {
    let mut entitlements = profile.entitlements().clone();

    if matches!(
        special,
        Some(SpecialApp::SideStoreLc) | Some(SpecialApp::LiveContainer)
    ) {
        let mut keychain_access = vec![plist::Value::String(format!(
            "{}.com.kdt.livecontainer.shared",
            team.team_id
        ))];

        for number in 1..128 {
            keychain_access.push(plist::Value::String(format!(
                "{}.com.kdt.livecontainer.shared.{}",
                team.team_id, number
            )));
        }

        entitlements.insert(
            "keychain-access-groups".to_string(),
            plist::Value::Array(keychain_access),
        );
    }

    entitlements
}
