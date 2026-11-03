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

**1. `src/bundle.rs` signs the `.appex` bundles in `Extensions/`.**

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

**2. `src/macho.rs` signs a binary whose old signature has data after it.**

When the old signature's space was too small, 0.1.0 grew it only if it ended
the Mach-O slice, and otherwise failed with "cannot grow a code signature that
is not at the end of the Mach-O slice". Some signers leave data there: ChOma's
CoreTrust bypass, which TrollStore signs apps with, shrinks LC_CODE_SIGNATURE to
its new signature but keeps the old one's spare space after it, as zeroes inside
__LINKEDIT. `move_code_signature_to_end` now leaves the old signature and what
follows it where they are, puts the new signature after them (16-byte aligned)
and grows __LINKEDIT over all of it, so the code directories hash them as code.
Nothing is truncated, so data something points to survives. It stops with an
error instead if another segment's content lies after __LINKEDIT, which
couldn't grow over it. An old signature that is big enough is still reused in
place. SideInstaller issue #109 (a tweak dylib), and iLoader issues #809/#831
(a TikTok IPA marked trollstore-fixed) and #1067 (Flutter.framework).

The size reserved for a signature is now planned for where it will start
(`reserve_code_signature` takes the size as a function of the start), since the
code directories hash every page before it. Before, a signature that moved, or
an empty LC_CODE_SIGNATURE with a stale offset, was sized for the old offset
and could fail with "encoded signature exceeded reserved LC_CODE_SIGNATURE
size".

Tested by the `moves_a_signature_*`, `reuses_a_big_enough_signature_*`,
`will_not_move_a_signature_over_another_segment` and
`plans_an_empty_signature_for_where_it_lands` tests in `macho.rs`. Checked on a
Mac too (2026-11-01): a dylib given ChOma's layout and signed here without a
certificate, its code directories then marked ad hoc, passes `codesign --verify
--strict` and loads with `dlopen`.

## Re-vendoring

The code at tangled.org (not released as of 2026-11-01) rewrites the walk and
signs every `.app`, `.appex` and `.framework` it finds, wherever it is
(`Frameworks/`, `PlugIns/`, `Extensions/`, `Watch/`, `AppClips/`...). Once a
release has that, this copy can go and the patch in `rust-core/Cargo.toml`
with it. Check first that the release signs an `.appex` in `Extensions/` on its
own, as `signs_app_extensions_in_extensions` checks here. Change 2 is not
upstream: tangled.org's rewrite (`src/macho/thin.rs`) still refuses a signature
with data after it, so a release has to pass this copy's change 2 tests before
it replaces this copy.
