# apple-codesign-quick (vendored)

Copy of [apple-codesign-quick](https://crates.io/crates/apple-codesign-quick)
0.1.0 from crates.io, published from
[Dadoum/apple-crates](https://github.com/Dadoum/apple-crates) @
`91fad87099663252dec23e4b5332a8ca979986f4` (now developed at
[tangled.org/dadoum.zone/apple-crates](https://tangled.org/dadoum.zone/apple-crates)).
`Cargo.toml` is the manifest crates.io normalized when the crate was
published. Licensed LGPL-2.1-or-later, like the original.

Vendored so `[patch.crates-io]` in `rust-core/Cargo.toml` can redirect the
dependency that `vendor/isideload` has on it, which is its signer.

## Local changes

**One change: `src/bundle.rs` signs the `.appex` bundles in `Extensions/`.**

0.1.0 only signs the nested bundles in `Frameworks/` and `PlugIns/`. iOS apps
keep their ExtensionKit app extensions (those with `EXAppExtensionAttributes` in
their Info.plist) in `Extensions/`, so the signer sealed such an extension's
files as plain files of the app and never signed its executable: even with its
bundle ID fixed, the extension reached iOS without a signature of its own.
`Bundle::sub_bundles` now also takes each `.appex` folder in `Extensions/` that
has an Info.plist, and signs it as it signs one in `PlugIns/`: with the profile
and entitlements listed for its bundle ID, before the app seals it. Anything
else in `Extensions/` is sealed as plain files, as before, so a resource bundle
there doesn't stop signing for lack of an executable. isideload finds the
extensions by the same rule (its README, change 14). SideInstaller issue #110,
an app with a Now Playing remote-media extension, and iLoader issue #394,
Instagram's `lockscreencamera` extension.

To test it, `macho.rs` lets the crate's tests use its minimal Mach-O, and
`bundle.rs` has `signs_app_extensions_in_extensions`:
`cargo test -p apple-codesign-quick --lib` (from `rust-core/`).

## Re-vendoring

The code at tangled.org (not released as of 2026-11-01) rewrites the walk and
signs every `.app`, `.appex` and `.framework` it finds, wherever it is
(`Frameworks/`, `PlugIns/`, `Extensions/`, `Watch/`, `AppClips/`...). Once a
release has that, this copy can go and the patch in `rust-core/Cargo.toml`
with it. Check first that the release signs an `.appex` in `Extensions/` on its
own, as `signs_app_extensions_in_extensions` checks here.
