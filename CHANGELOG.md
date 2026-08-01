# Changelog

All notable changes to SideInstaller are documented here.

## Unreleased

### Added
- **Custom .ipa.** A third option in the Install picker, alongside SideStore and LiveContainer +
  SideStore. Choosing it swaps the Stable/Nightly control for an **Import .ipa** button that opens the
  Files picker — pick any IPA, from iCloud Drive, a USB drive, anywhere — and SideInstaller signs and
  installs that instead of downloading. The button then shows the filename, so the card always says
  which IPA will be installed. The pairing-file step still runs and seeds AltStore-family apps, but no
  longer fails the install for an IPA that doesn't want one.
- **Install from an IPA you supply yourself.** SideInstaller's Documents folder is now visible in
  **Files › On My iPhone › SideInstaller**. Drop a `SideStore.ipa` (or `LiveContainer+SideStore.ipa`,
  optionally `-nightly`) in there and the install uses that file instead of downloading anything — the
  way through for anyone who can't reach GitHub. Imported files are listed under Settings › Downloaded
  IPAs marked *imported*; deleting one goes back to downloading. A download that fails now also falls
  back to a copy left by an earlier run rather than stopping the install.

### Changed
- **Any loopback VPN works, not just LocalDevVPN.** The tunnel check always tested the device subnet
  rather than which app provided it, but the copy said otherwise. It now names LocalDevVPN and ClashMi
  as examples and points out why the choice matters: iOS runs one VPN at a time, so a local-only tunnel
  leaves nothing to download SideStore through where GitHub is blocked.

## 0.6.5

### Fixed
- **One-click install no longer fails at the final step after a slow sign-in or download.** The device tunnel opened during Connect was held and reused for the install, but it sat idle through Apple ID sign-in (2FA), the SideStore download, and signing — often 1–2 minutes. iOS tears down an idle tunnel, so the install would stop with `⛔️ … "adapter closed" (NetworkUnreachable)` when it tried to reach the AFC service. The installer now refreshes the device link (a quick re-pair-verify, no PIN) right before uploading, so install and the pairing-file write always run over a live tunnel. Runs with a fast sign-in/download were unaffected, which is why this only showed up intermittently.
