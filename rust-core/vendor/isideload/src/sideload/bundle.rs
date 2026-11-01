// This file was made using https://github.com/Dadoum/Sideloader as a reference.
// I'm planning on redoing this later to better handle entitlements, extensions, etc, but it will do for now

use plist::{Dictionary, Value};
use rootcause::prelude::*;
use std::{
    fs,
    path::{Path, PathBuf},
};

use crate::SideloadError;

#[derive(Debug, Clone)]
pub struct Bundle {
    pub app_info: Dictionary,
    pub bundle_dir: PathBuf,

    app_extensions: Vec<Bundle>,
    frameworks: Vec<Bundle>,
    _libraries: Vec<String>,
}

impl Bundle {
    pub fn new(bundle_dir: PathBuf) -> Result<Self, Report> {
        let mut bundle_path = bundle_dir;
        // Remove trailing slash/backslash
        if let Some(path_str) = bundle_path.to_str()
            && (path_str.ends_with('/') || path_str.ends_with('\\'))
        {
            bundle_path = PathBuf::from(&path_str[..path_str.len() - 1]);
        }

        let info_plist_path = bundle_path.join("Info.plist");
        assert_bundle(
            info_plist_path.exists(),
            &format!("No Info.plist here: {}", info_plist_path.display()),
        )?;

        let plist_data = fs::read(&info_plist_path).context(SideloadError::InvalidBundle(
            "Failed to read Info.plist".to_string(),
        ))?;

        let app_info = plist::from_bytes(&plist_data).context(SideloadError::InvalidBundle(
            "Failed to parse Info.plist".to_string(),
        ))?;

        // App extensions: the NSExtension kind (widgets, share extensions...)
        // in PlugIns, and the ExtensionKit kind (`EXAppExtensionAttributes`,
        // such as a Now Playing remote-media extension) in Extensions. iOS
        // wants both kinds' bundle IDs under the app's, so both are rebased,
        // provisioned and signed alike. In Extensions only `.appex` folders
        // count, as for apple-codesign-quick, which signs them on their own.
        let mut app_extensions = child_bundles(&bundle_path, "PlugIns", None)?;
        app_extensions.extend(child_bundles(&bundle_path, "Extensions", Some("appex"))?);

        let frameworks = child_bundles(&bundle_path, "Frameworks", None)?;

        // Find all .dylib files in the bundle directory (recursive)
        let libraries = find_dylibs(&bundle_path, &bundle_path)?;

        Ok(Bundle {
            app_info,
            bundle_dir: bundle_path,
            app_extensions,
            frameworks,
            _libraries: libraries,
        })
    }

    /// Sets `CFBundleIdentifier`, and permits every background task identifier
    /// declared under the old bundle identifier under the new one as well.
    ///
    /// iOS only accepts a `BGContinuedProcessingTask` whose identifier starts
    /// with the app's bundle identifier, so an app that builds it from
    /// `Bundle.main.bundleIdentifier` submits `<new id>.…`, which then has to
    /// be in `BGTaskSchedulerPermittedIdentifiers` (iLoader issue #649). The
    /// old entries stay, for apps that register a hard-coded identifier, after
    /// the new ones: an app that takes the first entry of a kind (Madeira, the
    /// first ending in `.download.*`) then finds the one iOS accepts.
    pub fn set_bundle_identifier(&mut self, id: &str) {
        if let Some(old_id) = self.bundle_identifier().map(str::to_string)
            && let Some(Value::Array(task_ids)) =
                self.app_info.get_mut("BGTaskSchedulerPermittedIdentifiers")
        {
            let renamed: Vec<Value> = task_ids
                .iter()
                .filter_map(|task_id| rebase_identifier(task_id.as_string()?, &old_id, id))
                .filter(|new_id| !task_ids.iter().any(|t| t.as_string() == Some(new_id)))
                .map(Value::String)
                .collect();
            task_ids.splice(0..0, renamed);
        }

        self.app_info.insert(
            "CFBundleIdentifier".to_string(),
            Value::String(id.to_string()),
        );
    }

    pub fn bundle_identifier(&self) -> Option<&str> {
        self.app_info
            .get("CFBundleIdentifier")
            .and_then(|v| v.as_string())
    }

    pub fn bundle_name(&self) -> Option<&str> {
        self.app_info
            .get("CFBundleName")
            .and_then(|v| v.as_string())
    }

    pub fn app_extensions(&self) -> &[Bundle] {
        &self.app_extensions
    }

    pub fn app_extensions_mut(&mut self) -> &mut [Bundle] {
        &mut self.app_extensions
    }

    pub fn frameworks(&self) -> &[Bundle] {
        &self.frameworks
    }

    pub fn frameworks_mut(&mut self) -> &mut [Bundle] {
        &mut self.frameworks
    }

    pub fn write_info(&self) -> Result<(), Report> {
        let info_plist_path = self.bundle_dir.join("Info.plist");
        plist::to_file_binary(&info_plist_path, &self.app_info).context(
            SideloadError::InvalidBundle("Failed to write Info.plist".to_string()),
        )?;
        Ok(())
    }

    fn from_dylib_path(dylib_path: PathBuf) -> Self {
        Self {
            app_info: Dictionary::new(),
            bundle_dir: dylib_path,
            app_extensions: Vec::new(),
            frameworks: Vec::new(),
            _libraries: Vec::new(),
        }
    }

    fn collect_dylib_bundles(&self) -> Vec<Bundle> {
        self._libraries
            .iter()
            .map(|relative| Self::from_dylib_path(self.bundle_dir.join(relative)))
            .collect()
    }

    fn collect_nested_bundles_into(&self, bundles: &mut Vec<Bundle>) {
        for bundle in &self.app_extensions {
            bundles.push(bundle.clone());
            bundle.collect_nested_bundles_into(bundles);
        }

        for bundle in &self.frameworks {
            bundles.push(bundle.clone());
            bundle.collect_nested_bundles_into(bundles);
        }
    }

    pub fn collect_nested_bundles(&self) -> Vec<Bundle> {
        let mut bundles = Vec::new();
        self.collect_nested_bundles_into(&mut bundles);
        bundles.extend(self.collect_dylib_bundles());
        bundles
    }

    pub fn collect_bundles_sorted(&self) -> Vec<Bundle> {
        let mut bundles = self.collect_nested_bundles();
        bundles.push(self.clone());
        bundles.sort_by_key(|b| b.bundle_dir.components().count());
        bundles.reverse();
        bundles
    }
}

/// `identifier` moved from under `old_prefix` to under `new_prefix`, or `None`
/// when it isn't under `old_prefix` or is under `new_prefix` already (the new
/// bundle identifier extends the old one).
fn rebase_identifier(identifier: &str, old_prefix: &str, new_prefix: &str) -> Option<String> {
    if suffix_under(identifier, new_prefix).is_some() {
        return None;
    }
    suffix_under(identifier, old_prefix).map(|rest| format!("{new_prefix}{rest}"))
}

/// What follows `prefix` in `identifier` when it is `prefix` itself or starts
/// with `prefix` and a dot, so `com.example.apple` isn't taken for a child of
/// `com.example.app`.
fn suffix_under<'a>(identifier: &'a str, prefix: &str) -> Option<&'a str> {
    let rest = identifier.strip_prefix(prefix)?;
    (rest.is_empty() || rest.starts_with('.')).then_some(rest)
}

/// The bundles in `bundle_path`'s `folder`, if it has one: each folder in it
/// with an Info.plist, and with `extension` as well when one is given. A bundle
/// that fails to load is left out.
fn child_bundles(
    bundle_path: &Path,
    folder: &str,
    extension: Option<&str>,
) -> Result<Vec<Bundle>, Report> {
    let dir = bundle_path.join(folder);
    if !dir.exists() {
        return Ok(Vec::new());
    }

    Ok(fs::read_dir(&dir)
        .context(SideloadError::InvalidBundle(format!(
            "Failed to read {folder} directory"
        )))?
        .filter_map(|entry| entry.ok())
        .filter(|entry| {
            let path = entry.path();
            entry.file_type().map(|ft| ft.is_dir()).unwrap_or(false)
                && path.join("Info.plist").exists()
                && extension.is_none_or(|wanted| path.extension().is_some_and(|ext| ext == wanted))
        })
        .filter_map(|entry| Bundle::new(entry.path()).ok())
        .collect())
}

fn assert_bundle(condition: bool, msg: &str) -> Result<(), Report> {
    if !condition {
        bail!(SideloadError::InvalidBundle(msg.to_string()))
    } else {
        Ok(())
    }
}

fn find_dylibs(dir: &Path, bundle_root: &Path) -> Result<Vec<String>, Report> {
    let mut libraries = Vec::new();

    fn collect_dylibs(
        dir: &Path,
        bundle_root: &Path,
        libraries: &mut Vec<String>,
    ) -> Result<(), Report> {
        let entries = fs::read_dir(dir).context(SideloadError::InvalidBundle(format!(
            "Failed to read directory {}",
            dir.display()
        )))?;

        for entry in entries {
            let entry = entry.context(SideloadError::InvalidBundle(
                "Failed to read directory entry".to_string(),
            ))?;

            let path = entry.path();
            let file_type = entry.file_type().context(SideloadError::InvalidBundle(
                "Failed to get file type".to_string(),
            ))?;

            if file_type.is_file() {
                if let Some(name) = path.file_name().and_then(|n| n.to_str())
                    && name.ends_with(".dylib")
                {
                    // Get relative path from bundle root
                    if let Ok(relative_path) = path.strip_prefix(bundle_root)
                        && let Some(relative_str) = relative_path.to_str()
                    {
                        libraries.push(relative_str.to_string());
                    }
                }
            } else if file_type.is_dir() {
                collect_dylibs(&path, bundle_root, libraries)?;
            }
        }
        Ok(())
    }

    collect_dylibs(dir, bundle_root, &mut libraries)?;
    Ok(libraries)
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;

    const TASKS_KEY: &str = "BGTaskSchedulerPermittedIdentifiers";

    /// A folder in the temp directory, removed when dropped.
    pub(crate) struct TempDir(pub(crate) PathBuf);

    impl TempDir {
        pub(crate) fn new() -> Self {
            let dir = std::env::temp_dir().join(format!("isideload-test-{}", uuid::Uuid::new_v4()));
            fs::create_dir_all(&dir).unwrap();
            TempDir(dir)
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    /// Makes `dir` a bundle whose Info.plist names `bundle_id`.
    fn write_bundle(dir: &Path, bundle_id: &str) {
        fs::create_dir_all(dir).unwrap();
        let mut info = Dictionary::new();
        info.insert("CFBundleIdentifier".to_string(), bundle_id.into());
        plist::to_file_xml(dir.join("Info.plist"), &info).unwrap();
    }

    /// The layout from SideInstaller issue #110, in `root`: a widget in PlugIns
    /// and an ExtensionKit extension in Extensions, plus a framework and a
    /// resource bundle in Extensions that isn't an extension. Returns the app.
    pub(crate) fn write_app_with_both_extension_kinds(root: &Path) -> PathBuf {
        let app = root.join("Runner.app");
        write_bundle(&app, "com.zarz.mornye");
        write_bundle(&app.join("PlugIns/PlayerWidget.appex"), "com.zarz.mornye.PlayerWidget");
        write_bundle(
            &app.join("Extensions/LinkNowPlaying.appex"),
            "com.zarz.mornye.LinkNowPlaying",
        );
        write_bundle(&app.join("Extensions/Strings.bundle"), "org.example.Strings");
        write_bundle(&app.join("Frameworks/Flutter.framework"), "io.flutter.flutter");
        app
    }

    #[test]
    fn finds_app_extensions_in_plugins_and_extensions() {
        let dir = TempDir::new();
        let app = write_app_with_both_extension_kinds(&dir.0);

        let bundle = Bundle::new(app.clone()).unwrap();
        let mut extensions: Vec<_> = bundle
            .app_extensions()
            .iter()
            .map(|ext| {
                let location = ext.bundle_dir.strip_prefix(&app).unwrap().to_path_buf();
                (ext.bundle_identifier().unwrap(), location)
            })
            .collect();
        extensions.sort();
        assert_eq!(
            extensions,
            [
                (
                    "com.zarz.mornye.LinkNowPlaying",
                    PathBuf::from("Extensions/LinkNowPlaying.appex")
                ),
                (
                    "com.zarz.mornye.PlayerWidget",
                    PathBuf::from("PlugIns/PlayerWidget.appex")
                ),
            ]
        );

        let frameworks: Vec<_> = bundle
            .frameworks()
            .iter()
            .map(|framework| framework.bundle_identifier().unwrap())
            .collect();
        assert_eq!(frameworks, ["io.flutter.flutter"]);
    }

    fn bundle(bundle_id: &str, task_ids: Option<&[&str]>) -> Bundle {
        let mut app_info = Dictionary::new();
        app_info.insert("CFBundleIdentifier".to_string(), bundle_id.into());
        if let Some(task_ids) = task_ids {
            let task_ids = task_ids.iter().map(|&id| id.into()).collect();
            app_info.insert(TASKS_KEY.to_string(), Value::Array(task_ids));
        }
        Bundle {
            app_info,
            bundle_dir: PathBuf::new(),
            app_extensions: Vec::new(),
            frameworks: Vec::new(),
            _libraries: Vec::new(),
        }
    }

    fn task_ids(bundle: &Bundle) -> Vec<&str> {
        bundle.app_info[TASKS_KEY]
            .as_array()
            .unwrap()
            .iter()
            .map(|id| id.as_string().unwrap())
            .collect()
    }

    #[test]
    fn permits_background_tasks_under_the_new_bundle_id_too() {
        let mut bundle = bundle(
            "com.example.app",
            Some(&[
                "com.example.app.continued.*",
                "com.example.app.refresh",
                "com.example.app",
                "com.example.apple.sync",
                "com.other.task",
            ]),
        );
        bundle.set_bundle_identifier("com.example.app.TEAMID");

        assert_eq!(bundle.bundle_identifier(), Some("com.example.app.TEAMID"));
        assert_eq!(
            task_ids(&bundle),
            [
                "com.example.app.TEAMID.continued.*",
                "com.example.app.TEAMID.refresh",
                "com.example.app.TEAMID",
                "com.example.app.continued.*",
                "com.example.app.refresh",
                "com.example.app",
                "com.example.apple.sync",
                "com.other.task",
            ]
        );
    }

    #[test]
    fn adds_no_background_task_twice() {
        let mut bundle = bundle(
            "com.example.app",
            Some(&["com.example.app.refresh", "com.example.app.TEAMID.refresh"]),
        );
        bundle.set_bundle_identifier("com.example.app.TEAMID");
        bundle.set_bundle_identifier("com.example.app.TEAMID");

        assert_eq!(
            task_ids(&bundle),
            ["com.example.app.refresh", "com.example.app.TEAMID.refresh"]
        );
    }

    #[test]
    fn leaves_apps_without_background_tasks_alone() {
        let mut bundle = bundle("com.example.app", None);
        bundle.set_bundle_identifier("com.example.app.TEAMID");

        assert!(!bundle.app_info.contains_key(TASKS_KEY));
    }
}
