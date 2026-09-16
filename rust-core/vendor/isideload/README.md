# isideload (vendored)

Copy of the `isideload/` crate from
[nab138/isideload](https://github.com/nab138/isideload) @
`e319d931aa3f9d97fbd132149a3916dcd5c71f09` — the same revision `Cargo.lock`
pinned for the git dependency in `rust-core/Cargo.toml`, so nothing about the
auth / App ID / certificate behaviour described there changes.

Vendored so `[patch."https://github.com/nab138/isideload.git"]` can redirect the
dependency here.

## Local changes

**1. `src/sideload/sideloader.rs` — write `embedded.mobileprovision` into
each app extension.**

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

The write has to happen *before* `sign::sign`: `embedded.mobileprovision` is
sealed into `_CodeSignature/CodeResources` (`files` and `files2`), so adding it
to an already-signed bundle breaks the resource envelope.

**2. `src/anisette/` and `src/auth/grandslam.rs` — report the client as akd,
and don't reuse GrandSlam connections.**

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

**4. `src/sideload/sideloader.rs`, `application.rs` — send `sign_app`'s
requests to Apple concurrently.**

`sign_app` ran every developer-portal request one after another on a single
`DeveloperSession`: the certificate lookup, `listAppIds` twice, the app group,
one feature check and one group assignment per App ID, then the profile. On an
iPhone 16 that was about 5.5 s of a SideStore install spent waiting on Apple.

It now takes a device `(name, UDID)` to register and sends what doesn't depend
on anything else at once, each on a clone of the session (anisette headers are
fetched first, so the clones share them rather than each asking the server):

1. device registration, the certificate lookup, and — once the archive is
   extracted on a blocking thread — the App IDs and the app group together, then
   every App ID's feature check and group assignment side by side;
2. the provisioning profile, which needs all of that, while the certificate is
   written into the bundle.

`register_app_ids` also skips its second `listAppIds` when nothing new was
registered, since the first listing is already current. `install_app` passes
its device through instead of registering it separately first.

Two additions serve `rust-core`'s sign-in, which cost another 1.5 s:
`Sideloader::set_team` takes a team the caller has already listed (so
`get_team` doesn't list them a second time), and `GrandSlam::without_url_bag`
builds a client that skips the URL-bag fetch, for reusing a saved developer
session — portal requests use fixed URLs and never read the bag.

## Re-vendoring

Upstream had not fixed change 1 as of the pinned revision. Re-copying the crate
from a newer revision drops the patch unless upstream has landed an equivalent —
check `sign_app` in `src/sideload/sideloader.rs` for a profile write that loops
over `app.bundle.app_extensions()` first.

Change 2 is upstream on the `apple-codesign-quick` branch at `f6a4d5d` (what
iLoader 2.3.3 pins) but was not on `main` (`b6d1113`) as of 2026-09-13. A
re-vendor from `main` would bring the 503 back.

Upstream's `README.md` is a symlink to the workspace root, which doesn't exist
here; this file replaces it, and `readme` in `Cargo.toml` points at it.
