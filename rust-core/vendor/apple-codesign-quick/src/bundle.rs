use crate::error::{CodeSignError, Result};
use crate::file_bytes::read_file_bytes;
use crate::macho::{DEFAULT_CMS_BLOB_RESERVATION, MachOSigningConfig, sign_macho_file};
use crate::signature::CmsSigner;
use plist::{Dictionary, Value};
use rayon::prelude::*;
use sha1::Digest as _;
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

const FAIRPLAY_DIR: &str = "SC_Info";
const CODE_SIGNATURE_DIR: &str = "_CodeSignature";
const CODE_RESOURCES_FILE: &str = "CodeResources";

pub struct BundleSigningSettings<'a> {
    pub team_id: String,
    pub main_entitlements: Dictionary,
    pub entitlements_by_bundle_id: BTreeMap<String, Dictionary>,
    pub cms_signer: Option<&'a dyn CmsSigner>,
    pub embedded_mobileprovision: Option<&'a [u8]>,
    pub embedded_mobileprovisions_by_bundle_id: BTreeMap<String, &'a [u8]>,
    pub cms_blob_reservation: usize,
}

impl<'a> BundleSigningSettings<'a> {
    pub fn new(
        team_id: impl Into<String>,
        main_entitlements: Dictionary,
        cms_signer: Option<&'a dyn CmsSigner>,
    ) -> Self {
        Self {
            team_id: team_id.into(),
            main_entitlements,
            entitlements_by_bundle_id: BTreeMap::new(),
            cms_signer,
            embedded_mobileprovision: None,
            embedded_mobileprovisions_by_bundle_id: BTreeMap::new(),
            cms_blob_reservation: DEFAULT_CMS_BLOB_RESERVATION,
        }
    }
}

#[derive(Debug)]
pub struct Bundle {
    path: PathBuf,
    app_info: Dictionary,
}

impl Bundle {
    pub fn open(path: impl Into<PathBuf>) -> Result<Self> {
        let path = path.into();
        let info_path = path.join("Info.plist");
        if !info_path.exists() {
            return Err(CodeSignError::MissingInfoPlist(info_path));
        }

        let file =
            fs::File::open(&info_path).map_err(|source| CodeSignError::io(&info_path, source))?;
        let app_info = match Value::from_reader(file)? {
            Value::Dictionary(dict) => dict,
            _ => {
                return Err(CodeSignError::macho(
                    &info_path,
                    "Info.plist is not a dictionary",
                ));
            }
        };

        Ok(Self { path, app_info })
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn bundle_identifier(&self) -> Result<&str> {
        self.info_string("CFBundleIdentifier")
    }

    pub fn executable_name(&self) -> Result<&str> {
        self.info_string("CFBundleExecutable")
    }

    pub fn sign(&mut self, settings: &BundleSigningSettings<'_>) -> Result<CodeResourcesMaps> {
        self.sign_inner(settings, true)
    }

    fn sign_inner(
        &mut self,
        settings: &BundleSigningSettings<'_>,
        is_root: bool,
    ) -> Result<CodeResourcesMaps> {
        remove_fairplay_dir(&self.path)?;

        let bundle_id = self.bundle_identifier()?.to_string();
        let executable = self.executable_name()?.to_string();
        let sub_bundles = self.sub_bundles()?;
        let sub_bundles_for_hashing = sub_bundles.clone();

        let code_signature_dir = self.path.join(CODE_SIGNATURE_DIR);
        fs::create_dir_all(&code_signature_dir)
            .map_err(|source| CodeSignError::io(&code_signature_dir, source))?;

        let code_resources_path = code_signature_dir.join(CODE_RESOURCES_FILE);
        if code_resources_path.exists() {
            fs::remove_file(&code_resources_path)
                .map_err(|source| CodeSignError::io(&code_resources_path, source))?;
        }

        let info_data = encode_binary_plist(&self.app_info)?;
        let info_path = self.path.join("Info.plist");
        fs::write(&info_path, &info_data)
            .map_err(|source| CodeSignError::io(&info_path, source))?;
        let mobileprovision = settings
            .embedded_mobileprovisions_by_bundle_id
            .get(&bundle_id)
            .copied()
            .or_else(|| {
                if is_root {
                    settings.embedded_mobileprovision
                } else {
                    None
                }
            });
        if let Some(mobileprovision) = mobileprovision {
            let profile_path = self.path.join("embedded.mobileprovision");
            fs::write(&profile_path, mobileprovision)
                .map_err(|source| CodeSignError::io(&profile_path, source))?;
        }

        let (sub_results, bundle_files) = rayon::join(
            || sign_sub_bundles(&self.path, sub_bundles, settings),
            || collect_own_bundle_files(&self.path, &executable, &sub_bundles_for_hashing),
        );
        let sub_results = sub_results?;
        let bundle_files = bundle_files?;
        sign_libraries(&bundle_files.libraries, settings)?;
        let resource_hashes = hash_resource_files(&self.path, &bundle_files.resource_files)?;

        let mut maps = CodeResourcesMaps::default();

        for sub in &sub_results {
            merge_sub_bundle_resources(&mut maps, &self.path, sub)?;
        }

        for hash in resource_hashes {
            maps.insert_hash(hash);
        }

        let code_resources = encode_code_resources(&maps)?;
        fs::write(&code_resources_path, &code_resources)
            .map_err(|source| CodeSignError::io(&code_resources_path, source))?;

        let empty_entitlements = Dictionary::new();
        let bundle_entitlements = settings
            .entitlements_by_bundle_id
            .get(&bundle_id)
            .or_else(|| is_root.then_some(&settings.main_entitlements))
            .unwrap_or(&empty_entitlements);

        let mut config = MachOSigningConfig::new(
            &bundle_id,
            &settings.team_id,
            bundle_entitlements,
            settings.cms_signer,
        );
        config.cms_blob_reservation = settings.cms_blob_reservation;
        config.info_plist = Some(&info_data);
        config.code_resources = Some(&code_resources);
        sign_macho_file(&self.path.join(&executable), &config)?;

        Ok(maps)
    }

    fn info_string(&self, key: &'static str) -> Result<&str> {
        self.app_info
            .get(key)
            .and_then(Value::as_string)
            .ok_or(CodeSignError::MissingInfoString(key))
    }

    fn sub_bundles(&self) -> Result<Vec<PathBuf>> {
        let mut bundles = Vec::new();
        // SideInstaller, 2026-11-01: Extensions too, where ExtensionKit app
        // extensions live, but only its .appex folders. Anything else in it
        // stays sealed as plain files, as it was before.
        let folders = [
            ("Frameworks", None),
            ("PlugIns", None),
            ("Extensions", Some("appex")),
        ];
        for (folder, extension) in folders {
            let dir = self.path.join(folder);
            if !dir.exists() {
                continue;
            }

            for entry in fs::read_dir(&dir).map_err(|source| CodeSignError::io(&dir, source))? {
                let entry = entry.map_err(|source| CodeSignError::io(&dir, source))?;
                let path = entry.path();
                if entry
                    .file_type()
                    .map_err(|source| CodeSignError::io(&path, source))?
                    .is_dir()
                    && path.join("Info.plist").exists()
                    && extension
                        .is_none_or(|wanted| path.extension().is_some_and(|ext| ext == wanted))
                {
                    bundles.push(path);
                }
            }
        }
        bundles.sort();
        Ok(bundles)
    }
}

#[derive(Debug)]
struct SubBundleResult {
    path: PathBuf,
    relative_root: String,
    executable: String,
    resources: CodeResourcesMaps,
}

#[derive(Clone, Debug)]
struct FileHash {
    relative_path: String,
    sha1: [u8; 20],
    sha256: [u8; 32],
    optional: bool,
}

#[derive(Debug)]
struct BundleFiles {
    resource_files: Vec<PathBuf>,
    libraries: Vec<PathBuf>,
}

fn merge_sub_bundle_resources(
    maps: &mut CodeResourcesMaps,
    parent_path: &Path,
    sub: &SubBundleResult,
) -> Result<()> {
    maps.merge_rerooted(&sub.relative_root, &sub.resources);
    maps.insert_hash(hash_bundle_file(
        parent_path,
        &sub.path.join(&sub.executable),
    )?);
    maps.insert_hash(hash_bundle_file(
        parent_path,
        &sub.path.join(CODE_SIGNATURE_DIR).join(CODE_RESOURCES_FILE),
    )?);
    Ok(())
}

#[derive(Clone, Debug, Default)]
pub struct CodeResourcesMaps {
    pub files: Dictionary,
    pub files2: Dictionary,
    hashes: Vec<FileHash>,
}

impl CodeResourcesMaps {
    fn insert_hash(&mut self, hash: FileHash) {
        self.hashes.push(hash.clone());
        let sha1 = hash.sha1.to_vec();
        if !omit_from_files(&hash.relative_path) {
            if hash.optional {
                let mut file = Dictionary::new();
                file.insert("hash".to_string(), Value::Data(sha1.clone()));
                file.insert("optional".to_string(), Value::Boolean(true));
                self.files
                    .insert(hash.relative_path.clone(), Value::Dictionary(file));
            } else {
                self.files
                    .insert(hash.relative_path.clone(), Value::Data(sha1.clone()));
            }
        }

        if !omit_from_files2(&hash.relative_path) {
            let mut file2 = Dictionary::new();
            file2.insert("hash".to_string(), Value::Data(sha1));
            file2.insert("hash2".to_string(), Value::Data(hash.sha256.to_vec()));
            if hash.optional {
                file2.insert("optional".to_string(), Value::Boolean(true));
            }
            self.files2
                .insert(hash.relative_path, Value::Dictionary(file2));
        }
    }

    fn merge_rerooted(&mut self, root: &str, other: &Self) {
        for hash in &other.hashes {
            let mut hash = hash.clone();
            hash.relative_path = join_relative(root, &hash.relative_path);
            self.insert_hash(hash);
        }
    }
}

fn omit_from_files(relative_path: &str) -> bool {
    relative_path.ends_with(".lproj/locversion.plist")
}

fn omit_from_files2(relative_path: &str) -> bool {
    omit_from_files(relative_path)
        || relative_path == "Info.plist"
        || relative_path == "PkgInfo"
        || relative_path == ".DS_Store"
        || relative_path.ends_with("/.DS_Store")
}

pub fn sign_bundle(path: impl Into<PathBuf>, settings: &BundleSigningSettings<'_>) -> Result<()> {
    let mut bundle = Bundle::open(path)?;
    bundle.sign(settings)?;
    Ok(())
}

fn sign_sub_bundles(
    root_path: &Path,
    sub_bundles: Vec<PathBuf>,
    settings: &BundleSigningSettings<'_>,
) -> Result<Vec<SubBundleResult>> {
    sub_bundles
        .into_par_iter()
        .map(|path| {
            let mut bundle = Bundle::open(&path)?;
            let result = bundle.sign_inner(settings, false)?;
            let relative_root = relative_path_string(root_path, &path)?;
            let executable = bundle.executable_name()?.to_string();
            Ok(SubBundleResult {
                path,
                relative_root,
                executable,
                resources: result,
            })
        })
        .collect()
}

fn collect_own_bundle_files(
    bundle_path: &Path,
    executable: &str,
    sub_bundles: &[PathBuf],
) -> Result<BundleFiles> {
    let mut resource_files = Vec::new();
    let mut libraries = Vec::new();

    walk_files_pruned(
        bundle_path,
        &mut |dir| !sub_bundles.iter().any(|sub_bundle| sub_bundle == dir),
        &mut |path| {
            let relative = relative_path_string(bundle_path, path)?;
            if path.extension().and_then(|value| value.to_str()) == Some("dylib") {
                libraries.push(path.to_path_buf());
            }
            if should_hash_resource(&relative, executable) {
                resource_files.push(path.to_path_buf());
            }
            Ok(())
        },
    )?;

    resource_files.sort();
    libraries.sort();

    Ok(BundleFiles {
        resource_files,
        libraries,
    })
}

fn sign_libraries(libraries: &[PathBuf], settings: &BundleSigningSettings<'_>) -> Result<()> {
    libraries
        .par_iter()
        .map(|path| {
            let identifier = path
                .file_name()
                .and_then(|value| value.to_str())
                .ok_or_else(|| CodeSignError::InvalidBundlePath(path.clone()))?;
            let entitlements = Dictionary::new();
            let mut config = MachOSigningConfig::new(
                identifier,
                &settings.team_id,
                &entitlements,
                settings.cms_signer,
            );
            config.cms_blob_reservation = settings.cms_blob_reservation;
            sign_macho_file(path, &config)
        })
        .collect::<Result<Vec<_>>>()?;
    Ok(())
}

fn hash_resource_files(bundle_path: &Path, resource_files: &[PathBuf]) -> Result<Vec<FileHash>> {
    resource_files
        .par_iter()
        .map(|path| hash_bundle_file(bundle_path, path))
        .collect()
}

fn remove_fairplay_dir(bundle_path: &Path) -> Result<()> {
    let fairplay_path = bundle_path.join(FAIRPLAY_DIR);
    if fairplay_path.exists() {
        fs::remove_dir_all(&fairplay_path)
            .map_err(|source| CodeSignError::io(&fairplay_path, source))?;
    }
    Ok(())
}

fn walk_files_pruned(
    root: &Path,
    should_descend: &mut impl FnMut(&Path) -> bool,
    visitor: &mut impl FnMut(&Path) -> Result<()>,
) -> Result<()> {
    let mut stack = vec![root.to_path_buf()];
    while let Some(dir) = stack.pop() {
        for entry in fs::read_dir(&dir).map_err(|source| CodeSignError::io(&dir, source))? {
            let entry = entry.map_err(|source| CodeSignError::io(&dir, source))?;
            let path = entry.path();
            let file_type = entry
                .file_type()
                .map_err(|source| CodeSignError::io(&path, source))?;
            if file_type.is_dir() && should_descend(&path) {
                stack.push(path);
            } else if file_type.is_file() {
                visitor(&path)?;
            }
        }
    }
    Ok(())
}

fn should_hash_resource(relative: &str, executable: &str) -> bool {
    if relative == executable || relative.starts_with(FAIRPLAY_DIR) {
        return false;
    }

    for nested_root in ["Frameworks/", "PlugIns/"] {
        if let Some(rest) = relative.strip_prefix(nested_root)
            && rest.contains('/')
        {
            return false;
        }
    }

    true
}

fn hash_bundle_file(bundle_path: &Path, path: &Path) -> Result<FileHash> {
    let relative_path = relative_path_string(bundle_path, path)?;
    let data = read_file_bytes(path)?;
    let (sha1, sha256) = hash_file_data(data.as_slice());
    Ok(FileHash {
        optional: relative_path.contains(".lproj"),
        relative_path,
        sha1,
        sha256,
    })
}

fn hash_file_data(data: &[u8]) -> ([u8; 20], [u8; 32]) {
    if data.len() >= 1024 * 1024 {
        rayon::join(
            || sha1::Sha1::digest(data).into(),
            || sha2::Sha256::digest(data).into(),
        )
    } else {
        (
            sha1::Sha1::digest(data).into(),
            sha2::Sha256::digest(data).into(),
        )
    }
}

fn encode_code_resources(maps: &CodeResourcesMaps) -> Result<Vec<u8>> {
    let mut code_resources = Dictionary::new();
    code_resources.insert("files".to_string(), Value::Dictionary(maps.files.clone()));
    code_resources.insert("files2".to_string(), Value::Dictionary(maps.files2.clone()));
    code_resources.insert("rules".to_string(), rules());
    code_resources.insert("rules2".to_string(), rules2());

    let mut data = Vec::new();
    plist::to_writer_xml(&mut data, &Value::Dictionary(code_resources))?;
    Ok(data)
}

fn rules() -> Value {
    let mut rules = Dictionary::new();
    rules.insert("^.*".to_string(), Value::Boolean(true));
    rules.insert(
        "^.*\\.lproj/".to_string(),
        weighted_rule([("optional", Value::Boolean(true))], 1000.0),
    );
    rules.insert(
        "^.*\\.lproj/locversion.plist$".to_string(),
        weighted_rule([("omit", Value::Boolean(true))], 1100.0),
    );
    rules.insert("^Base\\.lproj/".to_string(), weight_only_rule(1010.0));
    rules.insert("^version.plist$".to_string(), Value::Boolean(true));
    Value::Dictionary(rules)
}

fn rules2() -> Value {
    let mut rules = Dictionary::new();
    rules.insert(".*\\.dSYM($|/)".to_string(), weight_only_rule(11.0));
    rules.insert(
        "^(.*/)?\\.DS_Store$".to_string(),
        weighted_rule([("omit", Value::Boolean(true))], 2000.0),
    );
    rules.insert("^.*".to_string(), Value::Boolean(true));
    rules.insert(
        "^.*\\.lproj/".to_string(),
        weighted_rule([("optional", Value::Boolean(true))], 1000.0),
    );
    rules.insert(
        "^.*\\.lproj/locversion.plist$".to_string(),
        weighted_rule([("omit", Value::Boolean(true))], 1100.0),
    );
    rules.insert("^Base\\.lproj/".to_string(), weight_only_rule(1010.0));
    rules.insert(
        "^Info\\.plist$".to_string(),
        weighted_rule([("omit", Value::Boolean(true))], 20.0),
    );
    rules.insert(
        "^PkgInfo$".to_string(),
        weighted_rule([("omit", Value::Boolean(true))], 20.0),
    );
    rules.insert(
        "^embedded\\.provisionprofile$".to_string(),
        weight_only_rule(20.0),
    );
    rules.insert("^version\\.plist$".to_string(), weight_only_rule(20.0));
    Value::Dictionary(rules)
}

fn weighted_rule<const N: usize>(entries: [(&str, Value); N], weight: f64) -> Value {
    let mut dict = Dictionary::new();
    for (key, value) in entries {
        dict.insert(key.to_string(), value);
    }
    dict.insert("weight".to_string(), Value::Real(weight));
    Value::Dictionary(dict)
}

fn weight_only_rule(weight: f64) -> Value {
    weighted_rule::<0>([], weight)
}

fn encode_binary_plist(dict: &Dictionary) -> Result<Vec<u8>> {
    let mut data = Vec::new();
    plist::to_writer_binary(&mut data, &Value::Dictionary(dict.clone()))?;
    Ok(data)
}

fn relative_path_string(root: &Path, path: &Path) -> Result<String> {
    let relative = path
        .strip_prefix(root)
        .map_err(|_| CodeSignError::InvalidBundlePath(path.to_path_buf()))?;
    path_to_forward_slashes(relative)
}

fn path_to_forward_slashes(path: &Path) -> Result<String> {
    let mut parts = Vec::new();
    for component in path.components() {
        parts.push(
            component
                .as_os_str()
                .to_str()
                .ok_or_else(|| CodeSignError::InvalidBundlePath(path.to_path_buf()))?,
        );
    }
    Ok(parts.join("/"))
}

fn join_relative(root: &str, child: &str) -> String {
    if root.is_empty() {
        child.to_string()
    } else if child.is_empty() {
        root.to_string()
    } else {
        format!("{root}/{child}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_hash(relative_path: &str) -> FileHash {
        FileHash {
            relative_path: relative_path.to_string(),
            sha1: [1; 20],
            sha256: [2; 32],
            optional: false,
        }
    }

    #[test]
    fn files2_omits_only_the_current_bundles_info_and_pkginfo() {
        let mut child = CodeResourcesMaps::default();
        child.insert_hash(test_hash("Info.plist"));
        child.insert_hash(test_hash("PkgInfo"));

        assert!(child.files.contains_key("Info.plist"));
        assert!(!child.files2.contains_key("Info.plist"));
        assert!(!child.files2.contains_key("PkgInfo"));

        let mut parent = CodeResourcesMaps::default();
        parent.merge_rerooted("PlugIns/Widget.appex", &child);

        assert!(
            parent
                .files2
                .contains_key("PlugIns/Widget.appex/Info.plist")
        );
        assert!(parent.files2.contains_key("PlugIns/Widget.appex/PkgInfo"));
    }

    /// SideInstaller: an ExtensionKit extension in Extensions gets a signature
    /// of its own, with the profile and entitlements listed for its bundle ID,
    /// and the app seals it as it seals one in PlugIns. Before, its files were
    /// sealed as the app's own and its executable was never signed. A bundle
    /// in Extensions that isn't an .appex is still sealed as plain files.
    #[test]
    fn signs_app_extensions_in_extensions() {
        let root = std::env::temp_dir().join(format!(
            "apple-codesign-extensionkit-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let write_bundle = |relative: &str, bundle_id: &str, executable: Option<&str>| {
            let path = root.join(relative);
            fs::create_dir_all(&path).unwrap();
            let mut info = Dictionary::new();
            info.insert("CFBundleIdentifier".to_string(), bundle_id.into());
            if let Some(executable) = executable {
                info.insert("CFBundleExecutable".to_string(), executable.into());
                let macho = crate::macho::tests::minimal_macho_with_empty_signature();
                fs::write(path.join(executable), macho).unwrap();
            }
            plist::to_file_xml(path.join("Info.plist"), &info).unwrap();
        };
        write_bundle("", "com.example.app", Some("App"));
        write_bundle("PlugIns/Widget.appex", "com.example.app.Widget", Some("Widget"));
        write_bundle("Extensions/Kit.appex", "com.example.app.Kit", Some("Kit"));
        write_bundle("Extensions/Strings.bundle", "org.example.Strings", None);

        let entitlements = |bundle_id: &str| {
            let mut entitlements = Dictionary::new();
            let app_id = format!("TEAMID.{bundle_id}");
            entitlements.insert("application-identifier".to_string(), app_id.into());
            entitlements
        };
        let profile = b"extension profile".as_slice();
        let mut settings =
            BundleSigningSettings::new("TEAMID", entitlements("com.example.app"), None);
        for bundle_id in ["com.example.app.Widget", "com.example.app.Kit"] {
            settings
                .entitlements_by_bundle_id
                .insert(bundle_id.to_string(), entitlements(bundle_id));
            settings
                .embedded_mobileprovisions_by_bundle_id
                .insert(bundle_id.to_string(), profile);
        }
        sign_bundle(&root, &settings).unwrap();

        let kit = root.join("Extensions/Kit.appex");
        let kit_executable = fs::read(kit.join("Kit")).unwrap();
        let contains = |needle: &[u8]| {
            kit_executable
                .windows(needle.len())
                .any(|window| window == needle)
        };
        assert!(contains(b"com.example.app.Kit\0"), "Kit isn't signed as itself");
        assert!(contains(b"<string>TEAMID.com.example.app.Kit</string>"));
        assert_eq!(fs::read(kit.join("embedded.mobileprovision")).unwrap(), profile);
        assert!(kit.join("_CodeSignature/CodeResources").is_file());

        let sealed: Dictionary =
            plist::from_file(root.join("_CodeSignature/CodeResources")).unwrap();
        let files2 = sealed["files2"].as_dictionary().unwrap();
        let sealed_sha256 = |relative: &str| {
            files2
                .get(relative)
                .and_then(Value::as_dictionary)
                .and_then(|entry| entry.get("hash2"))
                .and_then(Value::as_data)
                .map(<[u8]>::to_vec)
        };
        let signed_sha256: [u8; 32] = sha2::Sha256::digest(&kit_executable).into();
        assert_eq!(
            sealed_sha256("Extensions/Kit.appex/Kit"),
            Some(signed_sha256.to_vec())
        );
        for relative in [
            "Extensions/Kit.appex/Info.plist",
            "Extensions/Kit.appex/embedded.mobileprovision",
            "Extensions/Kit.appex/_CodeSignature/CodeResources",
            "Extensions/Strings.bundle/Info.plist",
            "PlugIns/Widget.appex/Widget",
        ] {
            assert!(files2.contains_key(relative), "{relative} isn't sealed");
        }
        assert!(!root.join("Extensions/Strings.bundle/_CodeSignature").exists());

        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn direct_dylibs_are_hashed_from_their_final_signed_contents() {
        let test_root = std::env::temp_dir().join(format!(
            "apple-codesign-dylib-resources-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let dylib = test_root.join("Frameworks/Patch.dylib");
        fs::create_dir_all(dylib.parent().unwrap()).unwrap();
        fs::write(&dylib, b"unsigned").unwrap();

        let bundle_files = collect_own_bundle_files(&test_root, "Main", &[]).unwrap();
        assert_eq!(bundle_files.libraries, vec![dylib.clone()]);
        assert_eq!(bundle_files.resource_files, vec![dylib.clone()]);

        fs::write(&dylib, b"signed").unwrap();
        let hashes = hash_resource_files(&test_root, &bundle_files.resource_files).unwrap();
        let expected_sha256: [u8; 32] = sha2::Sha256::digest(b"signed").into();
        assert_eq!(hashes[0].sha256, expected_sha256);

        fs::remove_dir_all(test_root).unwrap();
    }

    #[test]
    fn parent_seals_nested_bundle_code_resources() {
        let test_root = std::env::temp_dir().join(format!(
            "apple-codesign-nested-resources-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let child_path = test_root.join("Frameworks/Example.framework");
        let signature_path = child_path.join(CODE_SIGNATURE_DIR);
        fs::create_dir_all(&signature_path).unwrap();
        fs::write(child_path.join("Example"), b"executable").unwrap();
        fs::write(signature_path.join(CODE_RESOURCES_FILE), b"resources").unwrap();

        let mut child_resources = CodeResourcesMaps::default();
        child_resources.insert_hash(test_hash("Resource.txt"));
        let child = SubBundleResult {
            path: child_path,
            relative_root: "Frameworks/Example.framework".to_string(),
            executable: "Example".to_string(),
            resources: child_resources,
        };
        let mut parent = CodeResourcesMaps::default();

        merge_sub_bundle_resources(&mut parent, &test_root, &child).unwrap();

        assert!(
            parent
                .files2
                .contains_key("Frameworks/Example.framework/Resource.txt")
        );
        assert!(
            parent
                .files2
                .contains_key("Frameworks/Example.framework/Example")
        );
        assert!(
            parent
                .files2
                .contains_key("Frameworks/Example.framework/_CodeSignature/CodeResources")
        );

        fs::remove_dir_all(test_root).unwrap();
    }
}
