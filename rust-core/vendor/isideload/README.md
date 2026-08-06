# isideload (vendored)

Copy of the `isideload/` crate from
[nab138/isideload](https://github.com/nab138/isideload) @
`e319d931aa3f9d97fbd132149a3916dcd5c71f09` — the same revision `Cargo.lock`
pinned for the git dependency in `rust-core/Cargo.toml`, so nothing about the
auth / App ID / certificate behaviour described there changes.

Vendored so `[patch."https://github.com/nab138/isideload.git"]` can redirect the
dependency here.

## Local changes

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
