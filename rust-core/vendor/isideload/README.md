# isideload (vendored)

Copy of the `isideload/` crate from
[nab138/isideload](https://github.com/nab138/isideload) @
`e319d931aa3f9d97fbd132149a3916dcd5c71f09` — the same revision `Cargo.lock`
pinned for the git dependency in `rust-core/Cargo.toml`, so nothing about the
auth / App ID / certificate behaviour described there changes. Change 7 swaps
the signing backend for the one upstream moved to after that revision.

Vendored so `[patch."https://github.com/nab138/isideload.git"]` can redirect the
dependency here.

## Local changes

**1. `src/sideload/sign.rs` — give each app extension `embedded.mobileprovision`.**

`sign_app` downloaded a single provisioning profile (for `main_app_id`) and wrote
it only to the main `.app`. App extensions got nothing, even though
`register_app_ids` already registers an App ID for each of them and `sign::sign`
signs every nested bundle with the *main* app's entitlements
(`SettingsScope::Main`) — AltStore's "use main profile" arrangement. So the
signature was fine and only the file was missing.

That is enough to brick SideStore. `DatabaseManager.prepareDatabase()` walks
`appExtensions` on every launch and `InstalledExtension.init` throws when a
`.appex` has no profile:

```
Error Domain=AltSign.Error Code=1 "The app extension is missing a valid
provisioning profile."
```

SideStore has shipped `PlugIns/AltWidgetExtension.appex` for a long time; the
throwing guard landed upstream in `b34d9970` (2026-06-29) and started firing for
on-device installers with the 2026-07-25 nightlies. Users don't see that error,
though — `AppDelegate` only logs it, `LaunchViewController` then calls
`DatabaseManager.start` a second time, and because `start` re-runs
`loadPersistentStores` on a container whose store already loaded, the alert that
actually appears is `NSCocoaErrorDomain 134081 "Can't add the same store twice"`,
on a Retry loop that never recovers. See SideStore issues #1394 and #1400 —
closed upstream as an installer bug, and iLoader (same crate) has it too.

The profile has to be in place before the bundle is sealed:
`embedded.mobileprovision` is sealed into `_CodeSignature/CodeResources` (`files`
and `files2`), so adding it to an already-signed bundle breaks the resource
envelope. Since change 7, `sign` hands it to apple-codesign-quick for every
`.appex` (nested ones too) through `embedded_mobileprovisions_by_bundle_id`,
with the main entitlements through `entitlements_by_bundle_id`; before, it was
written by hand in `sign_app`. Upstream `baca89d` fixes the same bug differently:
it downloads each extension's own profile and signs the extension with that
profile's entitlements, at one more request per extension.

**2. `src/anisette/`, `src/auth/grandslam.rs`, `apple_account.rs` — report the
client as akd on an Android phone, now iTunes on a Windows PC or what the
server's library calls for, keep one anisette identity per ADI library, take
the 2FA code Apple sends unasked, resync anisette when Apple asks, and don't
reuse GrandSlam connections.**

Since early September 2026 Apple's GSA edge answers HTTP 503 to any request
whose `X-Mme-Client-Info` names `com.apple.dt.Xcode`, before it looks at
credentials or anisette data. The pinned revision took that header from the
anisette server's `/v3/client_info`, and the public servers all return an Xcode
string, so sign-in failed identically on every server:

```
HTTP status server error (503 Service Temporarily Unavailable) for url
(https://gsa.apple.com/grandslam/GsService2)
```

The URL-bag `lookup` GET still answers 200 with the Xcode header, which is why
the failure only shows up at the first POST.

`RemoteV3AnisetteProvider::get_client_info` now returns a fixed akd identity and
never requests `/v3/client_info` — upstream `232c7f3` (hardcode) plus `a19f5f0`
(akd), the same value AltStore #1790 and SideSign ship. The trait method takes
`&self`, as upstream's does. The GrandSlam client also sets
`pool_max_idle_per_host(0)` (upstream `f6a4d5d`; SideSign `35993d7` sends
`Connection: close` after finding reused GSA connections draw 5xx).

Measured 2026-09-13 with curl against `GsService2`: both Xcode strings got 503
on every try, the akd string got past the edge. `X-Xcode-Version` `14.2 (14C18)`
and upstream's `27.0 (27A5218g)` behaved the same, so it is left unchanged.

From 2026-10-12 that identity's Mac device and OS stopped working too. The
first sign-in request (SRP `init`) came back HTTP 200 with

```
Auth error -80045: This action cannot be completed at this time.
```

for every account, real or made up, on every server, in every tool that uses
them. The public servers run Dadoum's anisette-v3-server, which makes anisette
data with the ADI library from Apple Music for Android, and GrandSlam now
refuses a client whose OS isn't the one the machine ID was made on (Dadoum,
anisette-v3-server #61). So `get_client_info` reports an Android phone, and
keeps akd and the user agent:

```
<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>
```

Measured 2026-10-13 against `GsService2` with a made-up account, through
ani.npeg.us, ani.stikstore.app, ani.sidestore.io and ani.jaydenha.uk:

| `X-Mme-Client-Info` device and OS | `init` answer |
|---|---|
| `<Mac15,7> <macOS;27.0;26A5378j>` | -80045 |
| `<PC> <Windows;6.2(0,0);9200>` (iCloud for Windows) | -80045 |
| `<iPhone15,2> <iPhone OS;17.4;21E219>` | -80045 |
| `<PC> <Linux;6.1;0>` | HTTP 404 |
| `<Pixel 7> <Android;14;UQ1A.240205.002>` | -20101, "Your account information was entered incorrectly" |

-20101 is the answer for an account that doesn't exist (#61 reports the same
from a Mac's own anisette), so the request reaches the account check. With the
Android device and OS, naming akd or Apple Music for Android as the app, with
either's user agent, got -20101 alike. Anisette state provisioned under the Mac
identity keeps working, so nobody has to provision again. A server that moves
to the Windows or macOS library will need that OS here instead, and will answer
-80045 until then.

Reporting an Android phone changes three more of Apple's answers, all found on
2026-10-13 with a real account.

- The URL-bag lookup answers an Android client with ten URLs on gsd.apple.com,
  not the 175 on gsa.apple.com. `GrandSlam::new` asks for the bag as a Mac
  (`MAC_CLIENT_INFO`), which keeps sign-in on gsa.apple.com, where the URLs
  hardcoded in `apple_account.rs` live. The lookup carries no anisette data, so
  the Mac identity is not refused there. gsd.apple.com answered `init`,
  `complete` and a too-early `apptokens` exactly as gsa.apple.com did; nothing
  past that was tried on it.
- An accepted password proof comes back with hsc 409 and no `au`. Apple has
  already pushed a code to the trusted devices (the decrypted `spd` has
  `status-code` 409 and `sm`, "A message with a verification code has been sent
  to your other devices… Enter the code to continue."), and `validateCode`
  takes that code with no `trustedDeviceSecondaryAuth` request first. The
  pinned code read a missing `au` as signed in, and the `xcode.auth` request
  after it failed with -22411 (hsc 401, "This action cannot be completed at
  this time"). `state_after_proof` maps the answer to
  `NeedsDevice2FAVerification`, and that state now loads the trusted numbers
  itself. Tests: `cargo test -p isideload --lib state_after_proof`.
- The second-factor pages under gsa.apple.com/auth answer an Android client
  with a bare 403: `GET /auth` (the trusted numbers), `PUT /auth/verify/phone`
  (send a text or a call), `POST /auth/verify/phone/securitycode` (check its
  code) and `GET /auth/verify/trusteddevice` (send the code to the trusted
  devices again). With no numbers the app had no text or call to offer, and
  asking for another code ended the sign-in. Sent with a made-up identity
  token, each answers 403 as the Android phone and 401 as a Mac, a Windows PC
  or an iPhone, on gsd.apple.com too, so the refusal comes before Apple reads
  who is asking; `GsService2/validate` answers 401 to all of them. These four
  are now sent as the Mac as well (`get_sms`, `put_sms`, `post_sms` and the new
  `get_auth`). Test: `cargo test -p isideload --lib client_info_tests`.

With both in place one account went all the way on 2026-10-13: proof, the
pushed code, the second sign-in (hsc 200), an `xcode.auth` token good for a
year, and `listTeams`. That run was `ish/sideinstaller.py`, which sends the
same requests. From this crate, the lookup as a Mac and `listTeams` with that
session's token and anisette state were run. The token request and `listTeams`
also worked with the Mac identity. `listTeams` with the token and a newly
provisioned anisette identity answered 1100, "Your session has expired", so a
token goes with the machine ID that signed in.

The app's own sign-in then ran on an iPhone the same day, with the code from a
trusted device and, once the pages under `/auth` were asked as a Mac, with the
trusted numbers listed and a code by phone.

**Not verified:** an account whose only second factor is a phone number. Apple
no longer says in `au` that such a code goes by text, so the prompt still names
the trusted devices; what Apple sends unasked, and whether `validateCode` takes
it, isn't known.

By 2026-10-15 Apple had closed the Android route: `init` as the Android phone
gets a bare HTTP 503 on every server. A SideStore developer reported that the
Windows client the new Windows-ADI servers hand out goes through on the old
Android-ADI ones too, and it does, so `get_client_info` reports (where the
server's own client info can't be used, below)

```
<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKit/1 (com.apple.iTunes/12.12.4.1)>
```

with akd's user agent, as ani.jkcoxson.com and win.ani.sidestore.io advertise
it. Measured 2026-10-15 with made-up accounts, `init` answers:

| `X-Mme-Client-Info` | Android-ADI servers (ani.npeg.us, ani.stikstore.app, ani.sidestore.io, ani.jaydenha.uk) | Windows-ADI servers (win.ani.sidestore.io, ani.jkcoxson.com) |
|---|---|---|
| `<Pixel 7> <Android;14;…>` (akd) | HTTP 503 | HTTP 503 |
| `<Mac15,7> <macOS;27.0;…>` (akd) | -80045 | -22410 or HTTP 429 |
| `<PC> <Windows;6.2(0,0);9200>` (iTunes or akd) | -20970, "Your account information was entered incorrectly" | hsc 434, -22421, then -20970 after a resync |

-20970 carries the wording -20101 had, so the account check is reached; the
app counts it as a credential error. Anisette state provisioned under the
Android or Mac identity keeps working with the Windows one. Windows-ADI servers
must be provisioned as Windows (as the Android phone, `finishMachineProvisioning`
answered 401), which they now are, since provisioning sends the same client
info.

A Windows-ADI server's machine gets hsc 434 at its first `init`, with resync
data in `Status`'s `X-Apple-I-MD-DATA`. `login_inner` passes it to the server
(`/v3/get_headers` with `sim`, `device_id` and `md_lu`, upstream 0.4.5's
request, through `AnisetteProvider::resync`) and sends `init` again with the
new headers; later sign-ins with that machine need no resync. Tests:
`cargo test -p isideload --lib state_after_proof_tests` (`resync_sim`). A
throwaway `#[ignore]` test ran `AppleAccount::login` with fresh anisette state
through ani.npeg.us, ani.stikstore.app, win.ani.sidestore.io and
ani.jkcoxson.com: -20970 on all four.

Later on 2026-10-15 the rest followed what the SideStore and iLoader
developers had worked out by then: Apple only lets the Windows PC through the
Android-ADI servers by leniency it can withdraw, Windows ADI is the route they
moved to (iLoader 2.3.8 dropped the Android servers; isideload 0.4.6 takes the
client info from the server, 8ca39b62 provisions again on -45061), and a
macOS-ADI server is planned behind it, which clients that take the server's
client info and handle -45061 should follow with no update. Anisette v4 is to
have the server choose the client info outright.

- **Client info from the server, where it is the server's own.**
  `get_client_info` asks `/v3/client_info` once per provider and passes it
  through `client_info_to_use`: a stock identity (anisette-v3-server's
  `<MacBookPro13,2> <macOS;13.1;22C65>`, AltServer/omnisette's
  `<MacBookPro15,1> <Mac OS X;10.15.2;19C57>`, which every Android-ADI server
  hands out, Xcode or akd) or an Android one becomes `WINDOWS_CLIENT_INFO`;
  anything else is kept, as the Windows-ADI servers' own string is. A server
  that can't be asked fails the attempt, so the app moves to the next one.
  That request now comes before the URL bag, so on a network that resolves no
  names for the app (a public Wi-Fi's DNS did that to the Rust side on
  2026-10-15 while URLSession still worked) every server failed alike and the
  app tried all of them. `AppleAccount::new` now fetches the bag as well when
  the server can't be reached at all (`is_unreachable`: connect, DNS or
  timeout), and returns its "Failed to fetch URL Bag … error sending request"
  if Apple can't be reached either, which the app stops on as before.
- **One anisette identity per ADI library.** Measured 2026-10-15: an identity
  provisioned through an Android-ADI server gets `GetHeadersError` "ADI Login
  error: -45061" from all three Windows-ADI servers (ani.jkcoxson.com,
  win.ani.sidestore.io, ani2.stikstore.app), and one provisioned through a
  Windows-ADI server gets "provision.adi.ADIException: not provisioned
  (-45061)" from the Android ones; within a library it works everywhere
  (identical headers from all three Windows servers). The pinned code kept one
  `anisette_state`, so a sign-in loop that crossed libraries failed every
  server of the other one, and upstream's reset on -45061 would give a user who
  alternates a new machine, and Apple's second-factor prompt, each time.
  `RemoteV3AnisetteProvider::provision` now keeps `Slots`
  (`anisette_slots.json`: which identity each server took, and when each
  worked): the identity a server took before; else the first stored one it
  doesn't answer with -45061 (most recently used first, then the old
  `anisette_state`, which stays the first identity's key, so existing state,
  tokens and hand-offs carry on); else a new one, provisioned through it and
  kept only once the server makes headers from it. -45061 from
  `/v3/get_headers` is `SideloadError::AnisetteNotProvisioned`, and
  `AnisetteDataGenerator::get_anisette_data` picks once more on it, which is
  how a server that moves to another library is followed. `state_key_for`
  names a server's identity, for what is handed on with a token.
- **The bag and the pages under `/auth` as the same client.** As the Windows PC
  the lookup returns 122 URLs on gsa.apple.com with every URL this crate uses,
  and `/auth` reaches the token check (401 to a made-up token, as for the Mac),
  and the Mac on those requests alone was a mix the SideStore developers
  expected Apple to close. `GrandSlam::new` asks for the bag as the anisette
  client and only asks again as the Mac if it lacks a URL in `BAG_KEYS` or has
  GsService2 off gsa.apple.com. The `/auth` pages go through
  `AppleAccount::send_auth` (`GrandSlam::auth`), which asks once more as the
  Mac, and keeps to it for the session, if a page answers a bare 403 (no
  `serviceErrors`), the Android phone's refusal.

Also seen 2026-10-15: after a resync through one Windows-ADI server, the same
identity needed none through the other two (Apple keeps it per machine); a
first `init` right after a resync on another server once answered -90010,
"This action cannot be completed at this time", and once HTTP 503, and both
passed on the next try; and a made-up address `init` is sent for too often
starts getting -20209 ("locked") instead of -20970.

Tests: `cargo test -p isideload --lib remote_v3` (`client_info_to_use`, the
slots, and a local stand-in server that answers -45061 to the other library's
identities, including one that changes library under the same address) and
`client_info_tests`. A throwaway binary signed a made-up account in through
ani.sidestore.io, ani.jkcoxson.com, ani.npeg.us, win.ani.sidestore.io,
ani2.stikstore.app and ani.sidestore.io again, on one storage directory: two
identities, provisioned once each (the Windows one resynced once), every later
server matched without provisioning, -20970 throughout. On 2026-10-15 the
app's Certificates sign-in also went through with a real account on an
iPhone, a fresh install (so a new identity, through ani.jkcoxson.com unless
it was down), over mobile data; which second-factor route Apple took, and
whether `/auth` needed the Mac fallback, wasn't logged.

The macOS-ADI servers arrived on 2026-10-16 (iLoader 2.3.9 defaults to
mac-ani.jkcoxson.com; the community list has it as "jkcoxson" and
new.ani.sidestore.io as "SideStore (New)") and needed no change here: both
hand out `<MacBookPro13,3> <Mac OS X;10.12.6;16G29> <com.apple.AuthKit/1
(com.apple.akd/1.0)>`, which `client_info_to_use` keeps. Measured with made-up
accounts through this crate and `ish/sideinstaller.py`: provisioning goes
through, no hsc 434, -20970 at `init`; the two take each other's identity, and
the Windows-ADI servers answer it with -45061 (a third slot). On that identity
Apple also gave -20970 to the Windows PC and to a current Mac
(`<Mac15,7> <macOS;27.0;26A5378j>`). The bag asked as the server's Mac had 122
URLs, every one this crate uses.

A real account did not get through them (2026-10-16, the app on an iPhone,
fresh identity): on both Mac servers Apple took the password, then answered
`complete` with `au` = `secondaryAuth` (a code by text) rather than a push to
the trusted devices the account has, and both `GET /auth` (trusted numbers)
and `PUT /auth/verify/phone` answered a bare 403. `send_auth` doesn't retry
those as `MAC_CLIENT_INFO`, since the client is a Mac already; with a made-up
identity token both Mac strings get 401 there (the Windows PC gets 403 now),
so the 403 came from the session, not the client string alone. The app went on
to win.ani.sidestore.io (Windows identity, one resync), where Apple pushed the
code to the devices (409) and sign-in finished. iLoader 2.3.9's users reported
the same "SMS 2FA … 403" that day. So the app keeps ani.jkcoxson.com as the
first server and tries the macOS ones last.

**3. `src/auth/apple_account.rs`, `builder.rs`, `grandslam.rs` — let the user
choose how the 2FA code arrives.**

The pinned revision pushed a code to trusted devices and could only ask for
that code back; its SMS path hardcoded phone number id 1 and aborted on Apple's
412. This ports upstream's reworked flow (branch `apple-codesign-quick`, through
`c7e1bc4`). The login callback is upstream's async
`Fn(TwoFactorCallbackParams) -> Fut`. It receives the trusted numbers (from
`GET https://gsa.apple.com/auth`), the last error and what is pending, and
answers with `SubmitCode`, `SendSms(id)`, `SendToDevices`, `ResendCode` or
`Abort`. A 412 carrying the requested active challenge proceeds to verification,
-22979/-22981 keep the last code valid, and -21669 (wrong code) prompts again.
The GrandSlam client gained upstream's JSON `put_sms`/`post_sms`.

On top of the port, all local:

- `CallNumber(id)` / `PhoneCodeMode::Voice`: the same `/auth/verify/phone`
  requests with `"mode": "voice"`. SideStore offers calls, and a number whose
  `pushMode` is `voice` (a landline) can't take a text. **Never exercised against
  Apple** — only the text path has upstream users behind it.
- A refused phone request other than the throttling codes moves to
  `NeedsUnknown2FA` (pick another method) instead of failing the sign-in, so a
  refused call can fall back to a text.
- `secondaryAuth` still starts from id 1, but switches to the first real trusted
  number when 1 isn't one; a failed trusted-number lookup is logged, not fatal.
- The login loop allows 30 steps instead of 15, since every resend and change
  of method is one.
- Upstream's contract tests from `f560857` (removed there in `c7e1bc4`) are kept,
  with call and number-fallback cases. Run them from `rust-core/` with
  `cargo test -p isideload --lib auth::apple_account`.

`rust-core/src/account.rs` bridges this callback to Swift as JSON; the shapes
are documented on `SITwoFactorCb` in `rust-core/include/sideinstaller.h`.

**4. `src/sideload/application.rs` — tolerate a negative App ID quota.**

`register_app_ids` converted Apple's `availableQuantity` (an `i64`) with
`try_into()?` before comparing it. Apple can return a negative number, and then
signing died with `out of range integral type conversion attempted` at
`application.rs:192` — even when every App ID already existed and nothing needed
registering. Seen 2026-09-17 on a free account signing LiveContainer+SideStore.
A negative quota now logs a warning and skips the pre-check; if the IDs really
are exhausted, `add_app_id` fails with Apple's own error. Upstream `769e386`
(on `main`) does the same.

**5. `src/dev/` — register App IDs and app groups under a name Apple accepts.**

`add_app_id` and `add_app_group` sent the bundle's `CFBundleName` as is, and
Apple refuses anything but ASCII letters and digits with `Developer error 35: An
invalid value was provided for the parameter 'appIdName'`, so an imported IPA
named e.g. "YouTube Music+" couldn't be signed. `normalize_app_names` in
`dev/mod.rs` strips the rest, and falls back to "App" for a name with nothing
left. Same as upstream `3383885`, `a53be5c` and `37a1c64` (iLoader 2.3.4).
Tests: `cargo test -p isideload --lib dev::tests`.

**6. `src/auth/grandslam.rs` — retry a sign-in request GrandSlam answers 429.**

`plist_request` takes a `retry_429` flag, set for the three sign-in requests in
`apple_account.rs` and not for anisette provisioning. With it, a 429 is retried
after 2 s and again after 5 s; a 429 after that fails with reqwest's status
error as before, which the app matches ("apple.com" and "429 Too Many Requests")
to stop sign-in and explain. Upstream `a00c3a7` (iLoader 2.3.4) has the same
signature shape but retries 10 times without waiting, and replaces the final
error with one that names neither, so a re-vendor needs the app's match updated
too. `tokio`'s `time` feature is enabled for the wait. Tests (shorter waits under
`cfg(test)`, against a local server): `cargo test -p isideload --lib
auth::grandslam`.

**7. `src/sideload/sign.rs`, `cert_identity.rs`, `Cargo.toml` — sign with
apple-codesign-quick.**

Dadoum's [apple-codesign-quick](https://crates.io/crates/apple-codesign-quick)
0.1.0 replaces `isideload-apple-codesign` 0.29, as upstream did in `cc9fa9c`,
`5dd88f1` and `5992f00` (iLoader 2.3.0–2.3.4). It hashes files and signs nested
bundles in parallel, and its dependency tree is far smaller: with it the iOS
static library went from 79.1 MB to 69.0 MB and the app binary from 30.0 MB to
25.0 MB. On an M-series Mac, signing SideStore nightly took 0.024 s instead of
0.151 s, LiveContainer+SideStore 0.045 s instead of 0.39 s, and still 4–6× less
with only two threads.

Ported from upstream: `CertificateIdentity` keeps an `x509_cert::Certificate`
and no `InMemoryPrivateKey`, and `profile_to_certificate_chain` builds the CMS
chain from the profile's certificates plus the bundled WWDR G3 and Apple root
(`src/assets/AppleWWDRCAG3.cer`; the root is `src/auth/apple_root.der`).
`rsa` goes back to 0.9 and `rand` to 0.8, which apple-codesign-quick's
`RustCryptoCmsSigner` needs; stored keys are PKCS#8 either way. Not taken:
upstream's async/progress `sign`, its per-extension profiles (see change 1), and
the wasm and callback changes around them.

Local, on top: `sign` deletes every bundle's `_CodeSignature` folder first.
apple-codesign-quick replaces `CodeResources` but seals anything else in there,
so an IPA carrying a stray `_CodeSignature/ResourceRules` (seen in a re-signed
game) failed `codesign --verify` with "a sealed resource is missing or invalid";
`_CodeSignature` is never a sealed resource, and the old signer skipped it.

Checked on the Mac (2026-10-05) by signing SideStore nightly,
LiveContainer+SideStore and three other IPAs with a test CA and a CMS-wrapped
profile, old signer against new: `codesign --verify --deep --strict` passes for
every new output; identifiers, sealed file counts and profile placement match;
entitlements are now readable where macOS called the old blob invalid; both XML
and DER entitlements are present; code directories carry SHA-1 and SHA-256
where the old ones had SHA-256 only. Not covered: symlinks in a bundle, which
apple-codesign-quick's file walk skips and so leaves unsealed (none of the test
IPAs has one).

**8. `src/dev/certificates.rs`, `developer_session.rs` — revoke "Apple
Development" certificates.**

`ios/listAllDevelopmentCerts` returns the team's cross-platform "Apple
Development" certificates (the kind Xcode makes) next to the "iOS Development"
ones, and `list_ios_certs` keeps them, but `ios/revokeDevelopmentCert` refuses
them by serial:

```
Developer error 7252: There is no 'ios' certificate with serial number
'364D766243450DE16ED0CBBBF07FD9F2' on this team.
```

So the Certificates screen couldn't revoke one, and neither could
`MaxCertsBehavior::Revoke`/`Prompt` if it picked one. iLoader 2.3.5 has the same
bug (it calls the same endpoint). On 7252, `revoke_development_cert` now looks
the serial up in `listAllDevelopmentCerts` and deletes that certificate by
`certificateId` with `DELETE services/v1/certificates/<id>`, the request AltSign
uses for every revoke (`sendServicesRequest`: a POST with
`X-HTTP-Method-Override`, `application/vnd.api+json`, and
`{"urlEncodedQueryParams": "teamId=…"}` as the body). A serial that isn't listed
keeps Apple's 7252. The request's shape and its JSON:API error parsing are
tested against a local server: `cargo test -p isideload --lib
services_request_tests`.

**9. `src/sideload/application.rs`, `bundle.rs`, `sideloader.rs` — what
isideload 0.4.1–0.4.3 adds to the bundle (iLoader 2.3.6).**

- `ALTAppGroups` now goes into every app extension's Info.plist too, not just
  the app's (upstream `c23db68`). Extensions read it from their own bundle, and
  the widget in AltStore and in SideStore releases up to 0.7.0-alpha opens the
  shared database through it (`PersistentContainer.defaultDirectoryURL`). Without
  it the widget opened an empty database in its own container. SideStore
  nightlies read the group from the entitlements instead.
- AltStore gets `ALTDeviceID`: the UDID `sign_app` registers. AltStore registers
  that UDID with the team when it signs in and signs apps for it, and the IPA
  carries whichever UDID it was built with. Upstream `dd44258` writes
  `ALTDeviceId`, which AltStore doesn't read (`Bundle.Info.deviceID` is
  `"ALTDeviceID"`).
- `set_bundle_identifier` also lists each `BGTaskSchedulerPermittedIdentifiers`
  entry under the new bundle identifier (upstream `340cfea`, iLoader issue
  #649). iOS accepts a `BGContinuedProcessingTask` only if its identifier starts
  with the app's bundle identifier, so apps build it from
  `Bundle.main.bundleIdentifier`, and that identifier then wasn't permitted.
  Upstream replaces the old bundle identifier wherever it occurs in an entry and
  drops the original. Here, only an entry equal to the old bundle identifier or
  starting with it and a dot is rebased, and the original stays, so an app that
  registers a hard-coded identifier keeps its background tasks. The rebased
  entries go in front of the originals: Madeira takes the first entry ending in
  `.download.*` (and `.pairing.*`) and builds its task identifier from that, so
  with the originals first it asked iOS for one under its old bundle identifier
  and lost its background downloads. Tests:
  `cargo test -p isideload --lib sideload::`.
- AltStore gets the device's pairing file as `ALTPairingFile.dat` (upstream
  `4f7fb39`), so setting up a Remote AltServer in AltStore Classic 2.3 skips the
  "Pair with a PC" step. The format is AltServer's
  (`ALTDeviceManager.encryptedPairingData` on AltStore's `classic` branch):
  AES-256-GCM under SHA-256 of the certificate's machine identifier, written as
  CryptoKit's `SealedBox.combined` (12-byte nonce, ciphertext, 16-byte tag).
  AltStore opens it in `AppManager.bundledPairingFile()` once signed in, with
  the machine identifier Apple lists for the certificate in `ALTCertificateID`
  (`cert.machine_id` here, the same password the bundled p12 uses), and copies
  it to its Keychain when Remote AltServer is set up. If it can't open the file
  (say, AltStore kept a different certificate from an earlier install), it
  pairs on its own as before.

  Unlike upstream, which bundles iLoader's merged lockdown and RPPairing file as
  is, only an RPPairing record goes in, re-serialized by idevice's
  `RpPairingFile` as AltServer's `rp_pairing_file_to_bytes` writes it
  (`altstore_pairing_file` in `rust-core/src/account.rs`). AltStore's
  `OnDeviceClient` only connects with an RPPairing record (it refuses a file
  without `private_key`), and AltStore keeps a bundled file without checking it,
  so a lockdown-only file would make Remote AltServer look set up while every
  install fails. With no RPPairing record, nothing is bundled. The file never
  leaves the iPhone: AltStore only uses it for its own tunnel over LocalDevVPN.

  Tests: `cargo test -p isideload --lib sideload::` opens a file CryptoKit
  sealed and checks the layout; `cargo test --lib altstore_pairing_file` (from
  `rust-core/`) covers what gets bundled. Checked once on the Mac the other way
  round, too: AltStore's `bundledPairingFile()` code, run as a Swift script,
  opened a file sealed here and got the record back unchanged.

Not needed: upstream `0bee45d` (isideload 0.4.4, after iLoader 2.3.6). It
gives LiveContainer's `LiveProcess.appex` the keychain groups, which every
`.appex` here already gets with the main entitlements (change 1).

**10. `src/sideload/sideloader.rs`, `src/dev/developer_session.rs` — for an app
that renews its own profile (Madeira).**

`sign_app` takes `app_group`: false skips `ensure_app_group`, the group feature
and the assignment. Madeira registers its App ID again when the weekly one runs
out, and a new App ID has no group, so a profile for it would grant less than a
signature made with one. `DeveloperSession::token()` and `adsid()` expose what
the session is signed in with, for `si_signing_account` to hand to Madeira.
Local; upstream has neither. Not testable without an Apple ID.

## Re-vendoring

Upstream fixed change 1 its own way in `baca89d` (per-extension profiles). A
re-vendor either keeps the main-profile arrangement in `sign.rs` or takes
upstream's, which adds a profile download per extension to `sign_app`.

Change 7 is upstream on `main` from `5992f00` (isideload 0.4.0), without the
`_CodeSignature` cleanup.

Change 2 is upstream on the `apple-codesign-quick` branch at `f6a4d5d` (what
iLoader 2.3.3 pins) but was not on `main` (`b6d1113`) as of 2026-09-13. A
re-vendor from `main` would bring the 503 back.

Upstream's `README.md` is a symlink to the workspace root, which doesn't exist
here; this file replaces it, and `readme` in `Cargo.toml` points at it.
