use apple_codesign_quick::{
    BundleSigningSettings, CodeSignError, ProvisioningProfile, Result, RustCryptoCmsSigner,
    sign_bundle,
};
use std::collections::BTreeMap;
use std::ffi::OsString;
use std::fs;
use std::path::{Path, PathBuf};

fn main() -> Result<()> {
    let Some(args) = CliArgs::parse()? else {
        print_usage();
        return Ok(());
    };

    let mobileprovision = read_file(&args.mobileprovision)?;
    let profile = ProvisioningProfile::parse(&mobileprovision)?;
    let private_key = read_der_or_pem(&args.private_key, &["PRIVATE KEY", "RSA PRIVATE KEY"])?;
    let certificate = read_der_or_pem(&args.certificate, &["CERTIFICATE"])?;
    let mut certificate_chain =
        Vec::with_capacity(args.certificate_chain.len() + profile.certificate_chain_der().len());

    for certificate in &args.certificate_chain {
        certificate_chain.push(read_der_or_pem(certificate, &["CERTIFICATE"])?);
    }
    certificate_chain.extend(profile.certificate_chain_der().iter().cloned());

    let signer = RustCryptoCmsSigner::from_der(
        &private_key,
        &certificate,
        certificate_chain.iter().map(Vec::as_slice),
    )?;

    let team_id = args
        .team_id
        .as_deref()
        .unwrap_or_else(|| profile.team_id())
        .to_string();
    let mut settings =
        BundleSigningSettings::new(team_id, profile.entitlements().clone(), Some(&signer));
    settings.embedded_mobileprovision = Some(&mobileprovision);
    let nested_profiles = args
        .profiles_by_bundle_id
        .iter()
        .map(|(bundle_id, path)| {
            let data = read_file(path)?;
            let profile = ProvisioningProfile::parse(&data)?;
            let entitlements = profile.entitlements().clone();
            Ok((bundle_id.clone(), data, entitlements))
        })
        .collect::<Result<Vec<_>>>()?;
    settings.embedded_mobileprovisions_by_bundle_id = nested_profiles
        .iter()
        .map(|(bundle_id, data, _)| (bundle_id.clone(), data.as_slice()))
        .collect::<BTreeMap<_, _>>();
    settings.entitlements_by_bundle_id = nested_profiles
        .iter()
        .map(|(bundle_id, _, entitlements)| (bundle_id.clone(), entitlements.clone()))
        .collect();
    if let Some(reservation) = args.cms_blob_reservation {
        settings.cms_blob_reservation = reservation;
    }

    sign_bundle(args.bundle, &settings)
}

#[derive(Debug)]
struct CliArgs {
    bundle: PathBuf,
    certificate: PathBuf,
    private_key: PathBuf,
    mobileprovision: PathBuf,
    certificate_chain: Vec<PathBuf>,
    profiles_by_bundle_id: Vec<(String, PathBuf)>,
    team_id: Option<String>,
    cms_blob_reservation: Option<usize>,
}

impl CliArgs {
    fn parse() -> Result<Option<Self>> {
        let raw_args: Vec<OsString> = std::env::args_os().skip(1).collect();
        if raw_args.is_empty() || raw_args.iter().any(|arg| arg == "-h" || arg == "--help") {
            return Ok(None);
        }

        let mut bundle = None;
        let mut certificate = None;
        let mut private_key = None;
        let mut mobileprovision = None;
        let mut certificate_chain = Vec::new();
        let mut profiles_by_bundle_id = Vec::new();
        let mut team_id = None;
        let mut cms_blob_reservation = None;

        let mut args = raw_args.into_iter();
        while let Some(arg) = args.next() {
            match arg.to_string_lossy().as_ref() {
                "--bundle" | "-b" => set_path_arg(&mut bundle, "--bundle", args.next())?,
                "--certificate" | "--cert" | "-c" => {
                    set_path_arg(&mut certificate, "--certificate", args.next())?
                }
                "--private-key" | "--key" | "-k" => {
                    set_path_arg(&mut private_key, "--private-key", args.next())?
                }
                "--mobileprovision" | "--profile" | "-m" => {
                    set_path_arg(&mut mobileprovision, "--mobileprovision", args.next())?
                }
                "--chain" => certificate_chain.push(next_path_arg("--chain", args.next())?),
                "--profile-for" => profiles_by_bundle_id.push(next_profile_arg(args.next())?),
                "--team-id" => {
                    team_id = Some(next_string_arg("--team-id", args.next())?);
                }
                "--cms-reservation" => {
                    let value = next_string_arg("--cms-reservation", args.next())?;
                    cms_blob_reservation = Some(value.parse().map_err(|_| {
                        CodeSignError::Argument(format!(
                            "--cms-reservation must be a byte count, got {value}"
                        ))
                    })?);
                }
                value if value.starts_with('-') => {
                    return Err(CodeSignError::Argument(format!("unknown argument {value}")));
                }
                _ if bundle.is_none() => {
                    bundle = Some(PathBuf::from(arg));
                }
                value => {
                    return Err(CodeSignError::Argument(format!(
                        "unexpected positional argument {value}"
                    )));
                }
            }
        }

        Ok(Some(Self {
            bundle: required_path(bundle, "--bundle")?,
            certificate: required_path(certificate, "--certificate")?,
            private_key: required_path(private_key, "--private-key")?,
            mobileprovision: required_path(mobileprovision, "--mobileprovision")?,
            certificate_chain,
            profiles_by_bundle_id,
            team_id,
            cms_blob_reservation,
        }))
    }
}

fn next_profile_arg(value: Option<OsString>) -> Result<(String, PathBuf)> {
    let value = next_string_arg("--profile-for", value)?;
    let (bundle_id, path) = value.split_once('=').ok_or_else(|| {
        CodeSignError::Argument("--profile-for requires BUNDLE_IDENTIFIER=PROFILE_PATH".to_string())
    })?;
    if bundle_id.trim().is_empty() || path.trim().is_empty() {
        return Err(CodeSignError::Argument(
            "--profile-for requires non-empty bundle identifier and path".to_string(),
        ));
    }
    Ok((bundle_id.to_string(), PathBuf::from(path)))
}

fn set_path_arg(slot: &mut Option<PathBuf>, name: &str, value: Option<OsString>) -> Result<()> {
    if slot.is_some() {
        return Err(CodeSignError::Argument(format!(
            "{name} was provided twice"
        )));
    }
    *slot = Some(next_path_arg(name, value)?);
    Ok(())
}

fn next_path_arg(name: &str, value: Option<OsString>) -> Result<PathBuf> {
    value
        .map(PathBuf::from)
        .ok_or_else(|| CodeSignError::Argument(format!("{name} requires a value")))
}

fn next_string_arg(name: &str, value: Option<OsString>) -> Result<String> {
    let value = value.ok_or_else(|| CodeSignError::Argument(format!("{name} requires a value")))?;
    value
        .into_string()
        .map_err(|_| CodeSignError::Argument(format!("{name} must be valid UTF-8")))
}

fn required_path(value: Option<PathBuf>, name: &str) -> Result<PathBuf> {
    value.ok_or_else(|| CodeSignError::Argument(format!("missing required {name}")))
}

fn read_file(path: &Path) -> Result<Vec<u8>> {
    fs::read(path).map_err(|source| CodeSignError::Io {
        path: path.to_path_buf(),
        source,
    })
}

fn read_der_or_pem(path: &Path, allowed_labels: &[&str]) -> Result<Vec<u8>> {
    let data = read_file(path)?;
    if !data.starts_with(b"-----BEGIN ") {
        return Ok(data);
    }

    let (label, der) = pem_rfc7468::decode_vec(&data)
        .map_err(|err| CodeSignError::Argument(format!("failed to decode PEM {path:?}: {err}")))?;
    if allowed_labels.contains(&label) {
        Ok(der)
    } else {
        Err(CodeSignError::Argument(format!(
            "unsupported PEM label {label:?} in {path:?}; expected one of {allowed_labels:?}"
        )))
    }
}

fn print_usage() {
    eprintln!(
        "usage: apple-codesign --bundle Bundle.app --certificate signer.cer --private-key signer.key --mobileprovision profile.mobileprovision [--profile-for BUNDLE_IDENTIFIER=PROFILE_PATH ...] [--chain wwdr.cer ...] [--team-id TEAMID] [--cms-reservation BYTES]"
    );
}
