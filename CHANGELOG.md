# Changelog

All notable changes to SideInstaller are documented here.

## 0.7.0

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
- **Importing no longer freezes the app.** The copy runs in the background and the button says
  *Importing…* while it does. It used to happen inline, which is fine off local storage and not at all
  fine off the two sources the instructions recommend — iCloud Drive and a USB drive — where a
  hundred-megabyte read takes long enough for iOS to kill the app for being unresponsive.
- **A file picked from iCloud Drive imports.** The copy is now file-coordinated and asks for the
  download first, so an item that hasn't been pulled down yet is waited for rather than failing.
- **A failed import leaves the previous one alone.** The picked file is copied and checked in a staging
  folder, and only replaces what's loaded once it's known good. Before, the old import was deleted
  first, so a full disk — or simply picking the wrong file — destroyed it and left the button still
  showing its name.
- **A half-copied IPA is caught at import instead of at signing.** The check read the first two bytes,
  which a truncated archive still passes; it now also looks for the zip's end-of-central-directory
  record, which only a complete file has.

### Fixed
- **The pairing file and your signing certificate are no longer sitting in a folder anyone can browse.**
  Making the Documents folder visible in Files — the point of the import feature — exposed everything
  in it, including the device pairing record and isideload's storage, which holds the developer
  certificate. Both moved to Application Support, which file sharing doesn't reach; existing copies are
  migrated on first launch, so nobody has to pair again. Documents is now only the IPA drop-zone.
- **A custom IPA named `SideStore.ipa` no longer breaks SideStore updates.** Downloads were tracked by
  filename alone, so an import sharing a name with a download shared its entry — and deleting the
  import erased the download's claim. The app then read its own downloaded copy as user-supplied and
  stopped ever refreshing it from GitHub. Tracking is now per-path.
- **The tunnel/Wi-Fi poll no longer redraws the whole UI twice a second.** It republished its state
  every 2 seconds whether or not anything had changed, which invalidated every view watching it for as
  long as the app was open.
- **Installing a large build no longer risks being killed for memory.** Each file of the signed bundle
  was read into memory whole before being uploaded a megabyte at a time; it's now mapped.
- The activity log is capped at 2000 lines instead of growing for the whole session, and repeated
  install-progress percentages are no longer logged.

## 0.6.5

### Fixed
- **One-click install no longer fails at the final step after a slow sign-in or download.** The device tunnel opened during Connect was held and reused for the install, but it sat idle through Apple ID sign-in (2FA), the SideStore download, and signing — often 1–2 minutes. iOS tears down an idle tunnel, so the install would stop with `⛔️ … "adapter closed" (NetworkUnreachable)` when it tried to reach the AFC service. The installer now refreshes the device link (a quick re-pair-verify, no PIN) right before uploading, so install and the pairing-file write always run over a live tunnel. Runs with a fast sign-in/download were unaffected, which is why this only showed up intermittently.
