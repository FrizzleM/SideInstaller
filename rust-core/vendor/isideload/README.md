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
