# Changelog

All notable changes to SideInstaller are documented here.

## Unreleased

### Fixed
- **SideStore, LiveContainer + SideStore and Feather can now read the pairing file SideInstaller
  gives them.** SideInstaller pairs with your iPhone the only way an app on the phone can — the
  code you type into Settings — and that produces one kind of pairing record. SideStore reads a
  different, older kind, and so does Feather. What they were handed was a file they had no way to
  parse, so they carried on asking for a pairing file as if none had been placed. SideInstaller now
  produces the second kind as well, over the connection it already has open, and writes both of them
  into a single file the way iLoader does — every app takes the half it understands and ignores the
  rest. The step may ask you to tap Trust and unlock your iPhone once; after that the record is kept
  and reused. It also turns on the wireless-lockdown setting these apps need to reach your iPhone
  over the local tunnel, which nothing was doing before. If any of it fails, the install still
  finishes and writes the record it always wrote — the log says which one went out.

### Added
- **Install the pairing file into every app at once.** The Pairing tab lists each supported app it
  finds; with more than one, a single button now writes to all of them, as iLoader's *Place In All
  Apps* does. One app refusing the write no longer stops the others — the summary names whichever
  failed.
- **Export hands over the file that works.** The Export button shared the raw pairing record, which
  only StikDebug's sideloaded build could read. It now shares the combined file once one has been
  built, so a manual import into SideStore or Feather works the same as an automatic one.

## 0.7.0

### Added
- **SideStore is handed the certificate it was installed with.** SideStore only signs with a
  certificate it holds the private key for, and the one SideInstaller installs it with lives here,
  not there. On a free Apple ID — one certificate, no room for a second — SideStore's first sign-in
  therefore revoked ours, issued its own, and put up *Resign SideStore*, asking to reinstall itself
  before it would refresh. The install now seeds `Account.sideconf` into SideStore's container in
  the same step that writes the pairing file, over the same tunnel: SideStore imports the
  certificate on first launch, deletes the file, and carries on with the certificate it already has.
  No revoke, no reinstall, nothing for you to do. Your Apple ID password is deliberately not
  included — it isn't needed to keep the certificate, and the file is plain JSON until SideStore
  reads it. Reinstalling over a SideStore you had already set up replaces its stored account, so
  you'll enter your Apple ID password there once more. Building the file only ever reads the
  certificate: it can't create one, so it can't revoke one either, and a failure is logged and
  skipped rather than failing an install that is otherwise complete.
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
- **Recent SideStore nightlies launch again.** They refuse to start unless every app extension inside
  the bundle carries its own provisioning profile, and SideStore ships a widget. Signing wrote the
  profile into the app but never into the widget, so the app died on the splash screen behind a
  misleading Core Data error — *“Can't add the same store twice”* — that came back on every Retry. The
  widget now gets the profile it is signed against, and the same fix covers any other IPA with
  extensions. The signature was always correct; only the file was missing.
- **The Pairing tab no longer fails with “adapter closed” after sitting idle.** It reused the device
  link on the strength of a check that only proves our handles aren't null — but iOS tears the tunnel
  down underneath them, so scanning or writing minutes later hit a dead link. It now re-establishes
  first, the same way the install step has since 0.6.5.
- **A reconfigured tunnel is detected properly.** LocalDevVPN lets you change its tunnel IP, device IP
  and subnet mask; SideInstaller assumed a /24 and would report “no loopback VPN” for a working tunnel
  on any other mask. It now reads the interface's real netmask and asks the question that actually
  matters — would traffic to this address go into that tunnel?
- **A tunnel is no longer confused with a home network on the same range.** The check matched any
  interface in the target's subnet, so a Wi-Fi LAN on `10.7.0.x` read as a connected tunnel. It now
  has to be a tunnel interface *and* carry the address.
- **Putting the wrong address in Device IP is caught immediately.** LocalDevVPN's main screen shows
  `10.7.0.0` — its own end of the tunnel — while the address to connect to is the `10.7.0.1` under its
  Settings › Device IP. Entering the first left a tunnel that read as up and a run that failed at
  Connect after a sign-in and a download. SideInstaller now recognises an address this iPhone already
  holds and says so before starting.
- **Wi-Fi is only required for the step that needs it.** The tunnel is a loopback — it routes its own
  subnet and excludes the default route — so it works fine on cellular, and so does everything else in
  the run. Only pairing needs the local network, to be findable by Settings. With a pairing file
  already saved, installing no longer demands Wi-Fi; nor do the Pairing tab's scan and write.
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
- **A busy GitHub no longer stops the install, or sends you off to sideload by hand.** The SideStore
  download went through api.github.com, whose 60-requests-an-hour limit is counted per public IP — so
  behind carrier-grade NAT the quota can be spent by strangers before SideInstaller asks for anything.
  GitHub said so plainly, but the reply's status was never looked at: its body went to the release
  decoder and came out as “Key 'tag_name' not found”, under a hint about GitHub being unreachable that
  cost people ten minutes of manual work to get around a wait that clears itself. The IPA now comes off
  GitHub's ordinary download link, which isn't rate-limited at all; the API is asked only if an asset
  has been renamed. When something does go wrong the reasons stay apart — out of reach, refused (with
  how long the wait is, when it's a limit), or an answer that wasn't a release — and the *fetch it
  elsewhere and copy it in* hint appears only where that's genuinely the way past it.
- **A download that isn't an IPA is caught when it arrives.** The status of the download itself was
  logged but never checked, so a block page or a transfer that stopped partway was filed in Documents
  under the name that had been asked for, and only found out much later as an unexplained signing
  failure. A download now gets the same check an imported file has had since earlier in this release.

## 0.6.5

### Fixed
- **One-click install no longer fails at the final step after a slow sign-in or download.** The device tunnel opened during Connect was held and reused for the install, but it sat idle through Apple ID sign-in (2FA), the SideStore download, and signing — often 1–2 minutes. iOS tears down an idle tunnel, so the install would stop with `⛔️ … "adapter closed" (NetworkUnreachable)` when it tried to reach the AFC service. The installer now refreshes the device link (a quick re-pair-verify, no PIN) right before uploading, so install and the pairing-file write always run over a live tunnel. Runs with a fast sign-in/download were unaffected, which is why this only showed up intermittently.
