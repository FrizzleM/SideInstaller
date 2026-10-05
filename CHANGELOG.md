# Changelog

All notable changes to SideInstaller are documented here.

## Unreleased

### Changed
- **Installing SideStore or LiveContainer + SideStore is faster.** The download now starts as soon
  as the network is up and runs while your iPhone pairs, connects and signs in to your Apple ID,
  instead of waiting for all of that to finish first.
- Signing in to your Apple ID now happens while SideInstaller opens its link to your iPhone, rather
  than after it.
- An IPA downloaded on an earlier run is reused when GitHub still serves that exact file, so trying
  again after a failed install, or installing the same build later, skips the download.
- SideStore's certificate hand-off is prepared while the app installs, and finding the installed app
  afterwards only asks your iPhone about the apps you installed, not every system app.
- **Signing asks Apple for everything it needs at once.** Registering your iPhone, finding the
  certificate, and setting up the App IDs and app group now go out together instead of one after
  another, so signing SideStore takes under 3 seconds instead of over 6.
- Signing in with a saved Apple ID session makes two fewer requests to Apple.
- The signed app reaches your iPhone over several connections at once, which shaves a little more
  off the install. Together, a SideStore install on an iPhone 16 went from about 18.5 seconds to
  about 11.
- **The log is safe to share.** It leaves out your Apple ID, your iPhone's name, serial numbers,
  IMEI, SIM and subscriber numbers, network hardware addresses, Find My data and pairing keys, and
  shortens the UDID to its first and last characters. Model, iOS version, errors and connection
  details stay, and errors now say why a request couldn't be sent (DNS, connection or TLS).
- Closing a popup that a running install is waiting on, such as the pairing code or the steps to
  connect LocalDevVPN, now asks first, since it ends the install.
- The app behind a popup is now dimmed further as well as blurred, in light mode too, until the
  popup closes.
- On iOS 27, handing the pairing file to another app no longer tries to add a classic lockdown
  pairing first. iOS 27 refuses that every time, so the attempt only cost time and left a warning
  in the log. The file carries the pairing that StikDebug and SideStore nightlies from 20 September
  2026 on read. Older SideStore builds, LiveContainer's built-in SideStore and Feather need a
  classic pairing, which iOS 27 doesn't allow these apps to use on the iPhone itself.
- When Apple briefly turns a sign-in away as too many requests (HTTP 429), SideInstaller now tries
  again twice, a few seconds apart, before saying Apple is limiting sign-ins. iLoader found these
  often clear up straight away.

### Fixed
- **An imported IPA whose name has symbols, spaces or non-Latin letters signs again.** Apple refuses
  to register an App ID under such a name (error 35), so signing stopped before it started.
  SideInstaller now registers it under the name's letters and digits only, as iLoader does.
- **SideStore Nightly no longer asks you to import the pairing file.** Nightlies from 20 September
  2026 on stopped reading the pairing file where SideInstaller put it: they look for one file per
  connection type under new names, turn down a file that holds both, and only load one after their
  own import has saved two settings. SideInstaller now writes the pairing that way too, and sets
  those settings the way SideStore's import does, so SideStore connects on first launch. Older
  SideStore builds and LiveContainer + SideStore keep getting the file they read.
- **Sign-in says when SideInstaller can't reach Apple.** It used to try every anisette server and
  blame them, although none was at fault. It now stops and says why: Cellular Data turned off for
  SideInstaller, Wi-Fi not allowed for it, no internet connection, a disconnected VPN holding traffic
  back, or something on the network blocking Apple.
- **Side by Side works with iPhones on iOS 27.** Their iPhone dropped the connection the moment
  SideInstaller asked it to pair (error 54), before any Trust prompt could appear, so every run
  stopped at the first step. iOS 27 only pairs over Wi-Fi from its own Settings, so Side by Side now
  switches to that: it shows what to do on their iPhone — Settings › Privacy & Security › Developer
  Mode, then “Pair with SideInstaller (Side by Side)” — and the code to type there, and carries on
  once they have. The pairing is remembered for that address, so installing again doesn't ask for it.
- Pairing someone else's iPhone this way leaves this iPhone's own pairing file alone, and uses a name
  of its own, so it can't break the pairing their own SideInstaller sets up for itself.
- When two people each pair the same iPhone with Side by Side, the second no longer undoes the
  first. Every SideInstaller used to pair under one shared identifier, and an iPhone keeps a single
  pairing per identifier; each install now pairs under its own. Pairings already remembered keep
  working.
- Cancel stops Side by Side straight away while it waits for their iPhone to pair.
- Tapping Stop while the IPA downloads now stops the install, instead of carrying on with an older
  copy of the IPA left in Documents.

### Added
- Three more problems now get their own explanation and steps instead of a raw error: an Apple
  Account Apple won't let sign apps because of its owner's age (error 1102), an Apple ID out of App
  IDs for the week (error 9120), and an iPhone that already has the three apps a free Apple ID may
  install. The age refusal also stops sign-in at once rather than trying every anisette server.
- PanicAnalyzer joins the apps the Pairing tab can hand the pairing file to.

## 0.9.0

### Fixed
- **No more "Import Account" box on first launch.** Recent SideStore builds — including the one
  inside LiveContainer + SideStore nightly — stopped importing the certificate hand-off on their
  own and started asking for a *file password* instead. They only accept a file encrypted by
  SideStore's own Export Account, never delete the one they find, and only remember it once a
  password has worked, so the box came back every single launch and could never be dismissed for
  good. SideInstaller now checks the SideStore build it just signed and skips the hand-off entirely
  when that build would ask, exactly as iLoader does. Builds that still import it quietly — SideStore
  stable, and LiveContainer + SideStore stable — are unaffected and keep the certificate as before.
  On the builds that ask, SideStore offers to resign itself on first sign-in instead, which is the
  normal flow and takes one tap.
- **LiveContainer + SideStore installs again on the Nightly setting.** LiveContainer's nightly
  release stopped carrying the combined `LiveContainer+SideStore.ipa` — it now publishes the plain
  LiveContainer build alone, which has no SideStore inside it — so picking Nightly for that app
  simply failed to download. SideInstaller now looks through LiveContainer's other releases, takes
  the newest one that still has the combined build, and says in the log which release it used.
  Asking for Stable is never answered with a nightly. This also covers SideStore if its releases
  ever move the same way.
- SideStore, LiveContainer + SideStore and Feather now accept the pairing file SideInstaller puts in
  them, instead of asking you for one as though nothing had been placed.
- SideInstaller now switches on the setting those apps need to reach your iPhone over your local
  tunnel, which nothing was doing before.
- The install may ask you to unlock your iPhone and tap Trust once; it remembers the result and
  won't ask again for that device.
- If that extra step doesn't work, your install still finishes exactly as it did before, and the log
  says what went out.

### Added
- One button in the Pairing tab now writes the pairing file into every supported app it found, and
  one app refusing it no longer stops the rest.
- Export now shares the pairing file that every app can read, so importing it by hand works as well
  as letting SideInstaller place it.

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
