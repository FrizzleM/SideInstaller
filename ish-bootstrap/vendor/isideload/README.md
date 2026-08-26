# isideload (vendored, siboot fork)

Forked from `rust-core/vendor/isideload` — itself a copy of the `isideload/`
crate from [nab138/isideload](https://github.com/nab138/isideload) @
`e319d931aa3f9d97fbd132149a3916dcd5c71f09`. It carries that copy's
`embedded.mobileprovision` change unaltered (documented last, below) plus three
changes that exist only because `siboot` targets `i686-unknown-linux-musl`.

A separate fork rather than an edit in place: `rust-core/` builds for Apple
targets where aws-lc is fine and where the duplicate `idevice` costs nothing, so
none of the changes below belong to it.

## Local changes

**1. `Cargo.toml` — off aws-lc, onto ring.**

`aws-lc-sys` has no `i686-unknown-linux-musl` build, and nothing in the crate
needs it. Three declarations reached it:

| declaration | why it pulled aws-lc | change |
|---|---|---|
| `rcgen` | its `aws_lc_rs` feature | `default-features = false, features = ["ring", "pem"]` |
| `reqwest` | `default` → `default-tls` → `rustls` → `__rustls-aws-lc-rs` | `default-features = false`, `rustls-no-provider` + the `default` members actually used |
| `tokio-tungstenite` | none of its own — it asks only for `rustls`, and got aws-lc by feature unification with reqwest | none needed |

`rustls-no-provider` leaves the `CryptoProvider` unset, so **the binary must
install one before its first TLS handshake**. `siboot` does that on the first
line of `main`. Without it, every HTTPS call panics at runtime rather than
failing to build — which is why the self-test exercises a real handshake.

**2. `lib.rs`, `util/mod.rs`, `sideload/sideloader.rs` — finish the `install`
feature gate.**

Upstream's `install` feature is incomplete: with it off, four `use idevice::…`
sites still referenced the crate, so `idevice` had to be linked anyway.
`rust-core/Cargo.toml` records this as "isideload references `idevice`
unconditionally … so `install` must be enabled", and pays for it with a second,
duplicate `idevice` (0.1.61 from crates.io alongside 0.1.63 from git).

`siboot` cannot afford that duplicate — the binary is downloaded over a phone
connection and run under emulation — and does not want it either, since the
install runs over its own RSD tunnel. The four sites are all install-only:

- `lib.rs` — `use idevice::IdeviceError` and the `SideloadError::IdeviceError`
  variant, whose only constructor is in the already-gated `sideload/install.rs`.
- `util/mod.rs` — `pub mod device`, referenced by nothing outside `install_app`.
- `sideload/sideloader.rs` — `use idevice::provider::IdeviceProvider` and
  `util::device::IdeviceInfo`, both used only inside `install_app`, which is
  itself already `#[cfg(feature = "install")]`.

Each is now behind the same gate. With `install` off the tree resolves to a
single `idevice`, and `cargo check` is clean.

## Inherited change

**One file: `src/sideload/sideloader.rs` — write `embedded.mobileprovision` into
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

## Re-vendoring

Upstream had not fixed this as of the pinned revision. Re-copying the crate from
a newer revision drops the patch unless upstream has landed an equivalent —
check `sign_app` in `src/sideload/sideloader.rs` for a profile write that loops
over `app.bundle.app_extensions()` first.

Upstream's `README.md` is a symlink to the workspace root, which doesn't exist
here; this file replaces it, and `readme` in `Cargo.toml` points at it.
