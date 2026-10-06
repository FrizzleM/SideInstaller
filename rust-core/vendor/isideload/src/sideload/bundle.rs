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

        // Load app extensions from PlugIns directory
        let plug_ins_dir = bundle_path.join("PlugIns");
        let app_extensions = if plug_ins_dir.exists() {
            fs::read_dir(&plug_ins_dir)
                .context(SideloadError::InvalidBundle(
                    "Failed to read PlugIns directory".to_string(),
                ))?
                .filter_map(|entry| entry.ok())
                .filter(|entry| {
                    entry.file_type().map(|ft| ft.is_dir()).unwrap_or(false)
                        && entry.path().join("Info.plist").exists()
                })
                .filter_map(|entry| Bundle::new(entry.path()).ok())
                .collect()
        } else {
            Vec::new()
        };

        // Load frameworks from Frameworks directory
        let frameworks_dir = bundle_path.join("Frameworks");
        let frameworks = if frameworks_dir.exists() {
            fs::read_dir(&frameworks_dir)
                .context(SideloadError::InvalidBundle(
                    "Failed to read Frameworks directory".to_string(),
                ))?
                .filter_map(|entry| entry.ok())
                .filter(|entry| {
                    entry.file_type().map(|ft| ft.is_dir()).unwrap_or(false)
                        && entry.path().join("Info.plist").exists()
                })
                .filter_map(|entry| Bundle::new(entry.path()).ok())
                .collect()
        } else {
            Vec::new()
        };

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
    /// old entries stay, for apps that register a hard-coded identifier.
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
            task_ids.extend(renamed);
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
mod tests {
    use super::*;

    const TASKS_KEY: &str = "BGTaskSchedulerPermittedIdentifiers";

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
                "com.example.app.continued.*",
                "com.example.app.refresh",
                "com.example.app",
                "com.example.apple.sync",
                "com.other.task",
                "com.example.app.TEAMID.continued.*",
                "com.example.app.TEAMID.refresh",
                "com.example.app.TEAMID",
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
