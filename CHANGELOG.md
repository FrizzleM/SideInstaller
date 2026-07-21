# Changelog

All notable changes to SideInstaller are documented here.

## 0.6.5

### Fixed
- **One-click install no longer fails at the final step after a slow sign-in or download.** The device tunnel opened during Connect was held and reused for the install, but it sat idle through Apple ID sign-in (2FA), the SideStore download, and signing — often 1–2 minutes. iOS tears down an idle tunnel, so the install would stop with `⛔️ … "adapter closed" (NetworkUnreachable)` when it tried to reach the AFC service. The installer now refreshes the device link (a quick re-pair-verify, no PIN) right before uploading, so install and the pairing-file write always run over a live tunnel. Runs with a fast sign-in/download were unaffected, which is why this only showed up intermittently.
