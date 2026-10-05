pub mod app_groups;
pub mod app_ids;
pub mod certificates;
pub mod developer_session;
pub mod device_type;
pub mod devices;
pub mod teams;

/// The name to register an App ID or app group under.
///
/// Apple refuses names with anything but ASCII letters and digits in them
/// ("Developer error 35: An invalid value was provided for the parameter
/// 'appIdName'"), and the name is the bundle's `CFBundleName`, so an imported
/// IPA called "YouTube Music+" or "微信" couldn't be signed. Upstream 3383885,
/// a53be5c and 37a1c64 (iLoader 2.3.4) do the same.
pub fn normalize_app_names(name: &str) -> String {
    let normalized: String = name.chars().filter(|c| c.is_ascii_alphanumeric()).collect();
    if normalized.is_empty() {
        "App".to_string()
    } else {
        normalized
    }
}

#[cfg(test)]
mod tests {
    use super::normalize_app_names;

    #[test]
    fn keeps_plain_names() {
        assert_eq!(normalize_app_names("SideStore"), "SideStore");
        assert_eq!(normalize_app_names("LiveContainer"), "LiveContainer");
    }

    #[test]
    fn drops_what_apple_refuses() {
        assert_eq!(normalize_app_names("YouTube Music+"), "YouTubeMusic");
        assert_eq!(normalize_app_names("Café-Bar_2"), "CafBar2");
    }

    #[test]
    fn never_returns_an_empty_name() {
        assert_eq!(normalize_app_names("微信"), "App");
        assert_eq!(normalize_app_names(""), "App");
    }
}
