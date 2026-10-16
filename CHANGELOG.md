# Changelog

All notable changes to SideInstaller are documented here.

## 1.5.3

### Fixed
- **Moving between the two kinds of anisette server no longer breaks sign-in.** Servers on Apple's
  Android library and on its Windows library can't use each other's anisette identity, and
  SideInstaller kept only one, so when a server went down and sign-in moved on, every server of the
  other kind failed. SideInstaller now keeps one identity for each kind and remembers which one each
  server takes, so it can move back and forth without making a new identity, which Apple would ask
  for your verification code again. A server that changes kind is followed the same way.

### Changed
- **New sign-ins start on a Windows anisette server.** A first sign-in now goes through
  “jkcoxson (Windows ADI)”, where SideInstaller's Windows PC matches the machine the anisette data
  comes from. Through the Android servers it only passes as long as Apple lets it. If you have
  signed in before, SideInstaller stays on the server you used, keeping your saved sign-in. When
  that server fails, the Windows servers are tried next, and “StikStore (Windows ADI)” is added to
  the list for that.
- **The Mac anisette servers are tried last.** “jkcoxson” and “SideStore (New)” make their data
  with Apple's macOS library, and SideInstaller signs in through them as the Mac they name and
  keeps a separate anisette identity for them. Through them Apple has asked an account with trusted
  devices for a code by text and then refused to send one, so they come after every other server
  rather than first, where iLoader 2.3.9 puts them.
- **Apple turning away one kind of device no longer ends sign-in.** Through the Mac servers
  SideInstaller signs in as a Mac, and through the others as a Windows PC. When Apple refuses one
  of them twice (HTTP 503), the servers left that sign in as it are skipped and the others are
  tried, instead of sign-in stopping after the second refusal.
- **The anisette server decides what device SideInstaller signs in as**, when it names a device of
  its own, as the Windows servers do. Servers that still name the old Mac, which Apple refuses,
  get the Windows PC. A server that moves to another of Apple's libraries then works without an
  update.
- **Sign-in reports the same device from start to finish.** The verification-code requests, which
  SideInstaller sent as a Mac since 1.5.1, now go as the Windows PC like the rest, since Apple
  accepts them from it. If Apple turns them away, they go as a Mac again.
- **LocalDevVPN starts when it's needed, not when SideInstaller opens.** The setting is now
  “Start LocalDevVPN when needed”, and your choice carries over. With it on, opening SideInstaller
  no longer sends you to LocalDevVPN. Installing, scanning or writing on the Pairing page, loading
  or refreshing on the Apps page, and setting a location start it when the tunnel is off, then carry
  on once you're back. Opening the Apps or Location page uses the tunnel only if it's already up.

## 1.5.2

### Fixed
- **Signing in works again.** Apple now turns away the Android device SideInstaller has signed in
  as since 1.5.0, and sign-in stopped with “Apple's sign-in server refused the request (HTTP 503)”.
  SideInstaller now signs in as a Windows PC, which Apple accepts through the same anisette servers.
  The anisette identity SideInstaller already saved keeps working.
- **The Windows anisette servers work.** “SideStore (Windows ADI)” and “jkcoxson (Windows ADI)” in
  the server list make their data with Apple's Windows library. Sign-in through them failed while
  the anisette identity was being set up, since SideInstaller didn't say it was a Windows PC, and
  Apple asks each new identity on them to resync once before it signs in. SideInstaller now does
  both.
- **A mistyped Apple ID is reported at the first server.** Apple now answers an Apple ID it doesn't
  know with a new error code, which SideInstaller tried on every anisette server in turn before
  giving up. It now says the Apple ID or password is incorrect straight away, as it did before.

## 1.5.1

### Fixed
- **A verification code by text or phone call works again.** Since 1.5.0 signs in as an Android
  device, Apple turned away the requests that list your trusted phone numbers and send a code to
  one, so the code prompt had no number to offer and the code could only come from a trusted device.
  Asking for a new code on your devices failed the same way and ended the sign-in. Those requests
  are made the way Apple accepts them again: your numbers are back in the prompt, with a text or a
  call to each, and a new code can be sent to your devices.
- **An Apple Account with an unverified email address is told so.** Apple won't let such an account
  use developer services (error 2160), and SideInstaller took that for a stale sign-in: it signed in
  again with the password on each anisette server in turn, about every 8 seconds, before giving up
  with a raw error. It now stops at the first refusal, keeps the saved sign-in, and shows how to
  verify the address at account.apple.com. Certificates, Entitlements and Side by Side stop the same
  way.

## 1.5.0

### Changed
- **The Install button grows into the progress card.** Starting an install reshapes the button into
  the card that shows its steps, instead of turning it into a Cancel button under a separate card.
  After an install that finished or failed the card stays and the button comes back under it, as
  before.
- **Stopping an install asks first.** The progress card has an X in its corner, and tapping it asks
  “Cancel the install?” before anything stops. While the step in flight winds down the card reads
  “Cancelling”, then it shrinks back into the Install button.
- Advanced steps aside while an install runs, since a run can't take a change to the version or the
  pairing file. It comes back under the Install button once the install finishes, fails or is
  cancelled, as open or closed as you left it.
- **Cards are clear glass.** Every card is now a clear pane the animated backdrop shows through,
  drawn by a rim lit along its top edge, in place of the gray cards. It looks the same on every iOS
  version.
- The new text is translated into Chinese, French, Italian, Japanese, Portuguese, Spanish and
  Vietnamese.

### Fixed
- **Signing in to your Apple ID works again.** Since 12 October 2026 Apple has turned away sign-ins
  made through the public anisette servers (error -80045, “This action cannot be completed at this
  time”). Apple now refuses a sign-in that doesn't come from the kind of device the anisette data
  was made on: those servers make it with Apple's Android library, and SideInstaller said it was a
  Mac. It now signs in as the Android device the data belongs to. After your password, Apple sends a
  verification code to your trusted devices straight away, and SideInstaller asks for it.

## 1.4.0

### Added
- **Madeira joins the Install picker.** [Madeira](https://github.com/willfaust/Madeira) runs Windows
  PC games on an iPhone. SideInstaller signs it with the Increased Memory Limit entitlement it needs
  (Madeira shows it as Memory+), and puts your iPhone's pairing inside it, so Madeira's built-in JIT
  is set up without pairing again or importing a file: in its setup, “In-app with pairing file”
  already shows as done. Madeira needs iOS 26 or later; on an older iOS the install stops before it
  uses up an App ID. It reads only the pairing iOS 27 makes on the iPhone itself, or an imported
  file with the same kind of record. A file with only a classic lockdown record isn't passed on.
  Until upstream Madeira renews its own signing, Latest installs a fixed build that does; a version
  picked under Advanced comes from Madeira's GitHub releases. Madeira has no nightly, so the
  Stable/Nightly picker is hidden for it.
- **Madeira renews its own signing.** SideInstaller hands Madeira the sign-in it needs for that: the
  developer-service token this sign-in got and the anisette identity that goes with it, the same
  things SideStore keeps to refresh. Your Apple ID password isn't included, and no 2FA code is
  needed. Madeira moves it into its Keychain on first launch and from then on asks Apple for a new
  profile and installs it itself, whenever it's open with LocalDevVPN connected, so it keeps working
  with SideInstaller uninstalled. It needs SideInstaller again only when Apple stops accepting the
  token (it has an expiry, and a password change ends it): installing Madeira again hands over a
  new one. Only Madeira builds that say they take the sign-in get one; older ones are refreshed
  under Tools › Sideloaded apps. Madeira is signed without an app group, since the App ID it
  registers again each week comes without one.
- Madeira joins the apps the Pairing tab can hand the pairing file to.
- **The pairing code follows you into Settings.** While your iPhone pairs, SideInstaller now runs a
  Live Activity. When Settings asks for the code, it appears in the Dynamic Island, or drops down as
  a banner on an iPhone without one, and stays on the Lock Screen, so you no longer have to switch
  back to SideInstaller to read it. Once the pairing goes through it says so, and a tap takes you
  back to the app. A build signed with a certificate that can't sign app extensions sends the code
  as a notification instead, and asks to allow notifications the first time you pair; builds with
  the Live Activity never ask. Installed through SideStore, AltStore or Xcode with a free Apple ID,
  SideInstaller now takes two App IDs instead of one, since the extension that draws the Live
  Activity needs its own.
- **Crypto donations.** About › Crypto shows a wallet for Bitcoin, Ethereum and Solana, one at a
  time, each with its network, a QR code and a Copy button. Donations are optional and don't unlock
  anything.

### Changed
- **Most of the app is already on your iPhone by the time signing finishes.** Signing only changes a
  few of an app's files, so the rest is copied over from the download while signing runs, and only
  the changed files are sent afterwards. Every file copied early is checked against the signed app
  before installing.
- If the install needs you to tap Trust for the pairing file, it now asks right after connecting, so
  you can answer while everything else runs, instead of at the very end.
- When SideStore or LiveContainer is already installed, the pairing file goes in while the app is
  being signed rather than after the install. Together, reinstalling SideStore on an iPhone 16 now
  takes about 8.5 seconds, down from about 11 in 1.3.1.
- If Apple asks for a 2FA code while your iPhone is asking you to tap Trust, SideInstaller's code
  prompt now waits until you've answered.
- **LiveContainer + SideStore comes from LiveContainer's own repository again.** Since 1.3.0 it came
  from a copy on LiveContainerMirror/LiveContainer, whatever file was there. GitHub has hidden
  LiveContainer's organization since 4 October 2026, so while the repository is gone SideInstaller
  still takes LiveContainer's last nightly (18 September 2026) from that copy, but only that exact
  file: it's checked against the SHA-256 of the official build, and anything else under that link is
  refused. Stable and Nightly both install that build for now. Once the repository is back,
  SideInstaller goes back to it by itself, Stable included.
- **SideInstaller installs on iOS 17.4 and later**, down from iOS 18. As on iOS 18 to 26, an iPhone
  below iOS 27 needs a pairing file made on a computer.
- Everything new is translated into Chinese, French, Italian, Japanese, Portuguese, Spanish and
  Vietnamese.

### Fixed
- **A download whose connection drops is tried again.** The download runs while the VPN comes up,
  which can cut a transfer already going, and the install then stopped with “couldn't reach GitHub:
  The network connection was lost.” SideInstaller now tries twice more, a second and three seconds
  later, before it gives up.
- **A build whose GitHub repository is gone says so.** When there's no copy to fall back on, the
  install no longer stops with a bare 404, which reads like a fault on your side. SideInstaller says
  the repository is unavailable and that your iPhone and network are fine, and shows how to install
  from an IPA you got elsewhere: name it as shown and copy it into Files › On My iPhone ›
  SideInstaller.
- An app that looks its background task up in its own Info.plist, taking the first entry of a kind,
  now finds the one under the bundle ID it was signed with. SideInstaller listed those after the
  originals, so such an app asked iOS for a task it wasn't allowed and lost its background work.
  Madeira's Steam downloads rely on this to carry on in the background.
- Stopping an install while it signs in to your Apple ID no longer leaves a 2FA prompt to pop up
  later. The sign-in carried on behind the stopped install; a code request from it is now turned
  down.
- Files left in the iPhone's staging folder by an interrupted install are cleared before the next
  upload, so they can no longer end up inside the app being installed.

## 1.3.1

### Added
- **AltStore Classic installed as a custom IPA comes with your pairing.** AltStore 2.3 can install
  and refresh apps without a computer through a Remote AltServer, but setting that up asks you to
  pair with a PC first. SideInstaller now puts your iPhone's pairing inside AltStore when it signs
  it, encrypted the way AltServer does it, so after you sign in to AltStore the setup skips that
  step. This works with the pairing SideInstaller creates on the iPhone itself on iOS 27, and with
  an imported pairing file that includes the same kind of record. A file with only a classic
  lockdown record isn't passed on, since AltStore can't connect with it. The pairing stays on your
  iPhone.

### Fixed
- **SideStore's home screen widget shows your apps.** The widget looks for SideStore's app group in
  its own settings, and SideInstaller only wrote the group into the app's, so the widget opened an
  empty list. It now gets the group too, as AltServer does and as iLoader 2.3.6 does. This affects
  SideStore 0.7.0-alpha and older; nightlies find the group another way.
- **AltStore Classic installed as a custom IPA knows which iPhone it's on.** AltStore reads the
  iPhone's UDID from its own settings, where AltServer writes it during installation. SideInstaller
  left in whatever UDID the IPA came with, so AltStore registered that device with your Apple ID and
  signed apps for it instead. It now gets the UDID of the iPhone it's installed on.
- An imported app that schedules background work under its own bundle ID, such as a long export
  with iOS's continued processing tasks, can run it again after signing. Signing adds your team ID
  to the bundle ID, and iOS only runs those tasks under the bundle ID the app now has. Each such
  task is now allowed under the new bundle ID too, and still under the old one for apps that name it
  directly. Reported to iLoader in issue #649.

## 1.3.0

### Changed
- **Signing uses apple-codesign-quick**, the signer iLoader moved to in 2.3.0. It hashes an app's
  files and signs its extensions and frameworks in parallel. In tests on a Mac it signed SideStore
  about 6 times faster and LiveContainer + SideStore about 9 times faster, and SideInstaller itself
  is about 5 MB smaller. An imported IPA that still carries leftovers of an old signature inside its
  `_CodeSignature` folder is signed cleanly as well.
- **Popups that appear together are merged into one card.** The pairing code and its Settings steps
  are one popup, an error and the steps to fix it are one, and the “Installed” message, the trust
  step and LiveContainer's certificate import are one “Success: last steps” popup.
- When Apple briefly turns a sign-in away as too many requests (HTTP 429), SideInstaller now tries
  again twice, a few seconds apart, before saying Apple is limiting sign-ins. iLoader found these
  often clear up straight away.

### Fixed
- LiveContainer + SideStore downloads again while LiveContainer's GitHub repository is down: it
  comes from a temporary mirror, which only has the nightly build, so Stable installs that too.
- **An imported IPA whose name has symbols, spaces or non-Latin letters signs again.** Apple refuses
  to register an App ID under such a name (error 35), so signing stopped before it started.
  SideInstaller now registers it under the name's letters and digits only, as iLoader does.
- When two people each pair the same iPhone with Side by Side, the second no longer undoes the
  first. Every SideInstaller used to pair under one shared identifier, and an iPhone keeps a single
  pairing per identifier; each install now pairs under its own. Pairings already remembered keep
  working.
- The Certificates tool can revoke “Apple Development” certificates, the ones Xcode makes, instead
  of failing with error 7252.
- AutoFill fills in the Apple ID and password together on the sign-in page, instead of one at a
  time.

### Added
- Three more problems now get their own explanation and steps instead of a raw error: an Apple
  Account Apple won't let sign apps because of its owner's age (error 1102), an Apple ID out of App
  IDs for the week (error 9120), and an iPhone that already has the three apps a free Apple ID may
  install. The age refusal also stops sign-in at once rather than trying every anisette server.
- PanicAnalyzer joins the apps the Pairing tab can hand the pairing file to.

## 1.2.2

### Changed
- The app behind a popup is now dimmed further as well as blurred, in light mode too, until the
  popup closes.
- On iOS 27, handing the pairing file to another app no longer tries to add a classic lockdown
  pairing first. iOS 27 refuses that every time, so the attempt only cost time and left a warning
  in the log. The file carries the pairing that StikDebug and SideStore nightlies from 20 September
  2026 on read. Older SideStore builds, LiveContainer's built-in SideStore and Feather need a
  classic pairing, which iOS 27 doesn't allow these apps to use on the iPhone itself.

### Fixed
- **SideStore Nightly no longer asks you to import the pairing file.** Nightlies from 20 September
  2026 on stopped reading the pairing file where SideInstaller put it: they look for one file per
  connection type under new names, turn down a file that holds both, and only load one after their
  own import has saved two settings. SideInstaller now writes the pairing that way too, and sets
  those settings the way SideStore's import does, so SideStore connects on first launch. Older
  SideStore builds and LiveContainer + SideStore keep getting the file they read.

## 1.2.1

### Changed
- **The log is safe to share.** It leaves out your Apple ID, your iPhone's name, serial numbers,
  IMEI, SIM and subscriber numbers, network hardware addresses, Find My data and pairing keys, and
  shortens the UDID to its first and last characters. Model, iOS version, errors and connection
  details stay, and errors now say why a request couldn't be sent (DNS, connection or TLS).
- Closing a popup that a running install is waiting on, such as the pairing code or the steps to
  connect LocalDevVPN, now asks first, since it ends the install.

### Fixed
- **Sign-in says when SideInstaller can't reach Apple.** It used to try every anisette server and
  blame them, although none was at fault. It now stops and says why: Cellular Data turned off for
  SideInstaller, Wi-Fi not allowed for it, no internet connection, a disconnected VPN holding traffic
  back, or something on the network blocking Apple.

## 1.2.0

### Added
- **Advanced options on the Install tab.** Pick which version of SideStore or LiveContainer +
  SideStore to install, and import a pairing file by hand on iOS 27 as well (#60).

### Changed
- Messages are shown as popups, so they're harder to miss.
- Switching between pages is smoother.

## 1.1.0

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

### Fixed
- **Side by Side works with iPhones on iOS 27.** Their iPhone dropped the connection the moment
  SideInstaller asked it to pair (error 54), before any Trust prompt could appear, so every run
  stopped at the first step. iOS 27 only pairs over Wi-Fi from its own Settings, so Side by Side now
  switches to that: it shows what to do on their iPhone — Settings › Privacy & Security › Developer
  Mode, then “Pair with SideInstaller (Side by Side)” — and the code to type there, and carries on
  once they have. The pairing is remembered for that address, so installing again doesn't ask for it.
- Pairing someone else's iPhone this way leaves this iPhone's own pairing file alone, and uses a name
  of its own, so it can't break the pairing their own SideInstaller sets up for itself.
- Cancel stops Side by Side straight away while it waits for their iPhone to pair.
- Tapping Stop while the IPA downloads now stops the install, instead of carrying on with an older
  copy of the IPA left in Documents.

## 1.0.0

### Added
- **A Tools tab.** It holds Side by Side, which installs SideInstaller on another iPhone or iPad
  wirelessly; the Certificates and Pairing tools; a location spoofer; and an entitlement manager,
  mainly for adding the Increased Memory Limit.
- **iPhones on iOS 18 to 26 can use SideInstaller**, if they already have a pairing file, which
  takes a computer to make. The Pairing tool needs iOS 27.
- 2FA codes can come by SMS or phone call.
- Import .ipa takes a URL as well as a file.
- A dark and a glass app icon.
- Portuguese, and Japanese (thanks to @so-5699).
- SideInstaller starts LocalDevVPN at launch.

### Changed
- Apple ID sessions are saved and reused, so Apple rate-limits sign-ins less often.
- The progress bar looks better.
- SideInstaller needs approving in Privacy & Security less often.

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
- Sign-in no longer fails with HTTP 503.
- SideInstaller works with LocalDevVPN's latest update again.
- Import .ipa lets you pick a file again.
- An anisette server picked in Settings stays picked.

## 0.9.0

### Fixed
- SideStore, LiveContainer + SideStore and Feather now accept the pairing file SideInstaller puts in
  them, instead of asking you for one as though nothing had been placed.
- SideInstaller now switches on the setting those apps need to reach your iPhone over your local
  tunnel, which nothing was doing before.
- The install may ask you to unlock your iPhone and tap Trust once; it remembers the result and
  won't ask again for that device.
- If that extra step doesn't work, your install still finishes exactly as it did before, and the log
  says what went out.

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
- One button in the Pairing tab now writes the pairing file into every supported app it found, and
  one app refusing it no longer stops the rest.
- Export now shares the pairing file that every app can read, so importing it by hand works as well
  as letting SideInstaller place it.

## 0.8.0

### Fixed
- **Recent SideStore nightlies launch again.** They refuse to start unless every app extension inside
  the bundle carries its own provisioning profile, and SideStore ships a widget. Signing wrote the
  profile into the app but never into the widget, so the app died on the splash screen behind a
  misleading Core Data error — *“Can't add the same store twice”* — that came back on every Retry. The
  widget now gets the profile it is signed against, and the same fix covers any other IPA with
  extensions. The signature was always correct; only the file was missing.
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
  failure. A download now gets the same check an imported file has had since 0.7.0.

### Changed
- Dependencies updated; see `v0.8-dependency-updates.txt`.

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

## 0.6.5

### Fixed
- **One-click install no longer fails at the final step after a slow sign-in or download.** The device tunnel opened during Connect was held and reused for the install, but it sat idle through Apple ID sign-in (2FA), the SideStore download, and signing — often 1–2 minutes. iOS tears down an idle tunnel, so the install would stop with `⛔️ … "adapter closed" (NetworkUnreachable)` when it tried to reach the AFC service. The installer now refreshes the device link (a quick re-pair-verify, no PIN) right before uploading, so install and the pairing-file write always run over a live tunnel. Runs with a fast sign-in/download were unaffected, which is why this only showed up intermittently.
