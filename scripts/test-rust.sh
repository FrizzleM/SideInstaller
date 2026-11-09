#!/bin/bash
# Runs the Rust tests on this Mac: rust-core's own (2FA bridge, saved sessions,
# .p12, pairing host, …), then those of the crates vendored under
# rust-core/vendor/, whose local changes have tests of their own (idevice's
# OPACK back-references and AFC logging, isideload's 2FA, anisette and
# extension handling, apple-codesign-quick's signing).
#
#   scripts/test-rust.sh
#
# A vendored crate isn't part of rust-core's build as far as `cargo test` is
# concerned, so each is tested from its own folder the way the app builds it:
#   - with the features the app's build gives it (read from `cargo metadata`),
#   - with rust-core's [patch.crates-io] entries, so isideload signs with the
#     vendored apple-codesign-quick as the app does,
#   - against rust-core/Cargo.lock, copied in for the run and put back after,
#     so the dependency versions are the ones the app ships with. Only what a
#     crate's tests need on top (its dev-dependencies) is resolved anew.
#
# LOCKED=1 (CI) stops when rust-core/Cargo.lock doesn't match Cargo.toml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT/rust-core"
VENDORED=(idevice isideload apple-codesign-quick)
# Tests that can't run here: idevice's round trip reads a pairing file from
# /var/lib/lockdown on the machine running it.
SKIP=(pairing_file::test_pairing_file_roundtrip)

if ! command -v cargo >/dev/null && [ -f "$HOME/.cargo/env" ]; then
  set +u
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env"
  set -u
fi
# One build folder for all of them, so a dependency built for one with the same
# features isn't built again for the next.
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$CORE/target}"
locked=()
[ "${LOCKED:-0}" = 1 ] && locked=(--locked)

skips=()
for t in "${SKIP[@]}"; do skips+=(--skip "$t"); done

echo "==> sideinstaller_ffi (rust-core)"
(cd "$CORE" && cargo test ${locked[@]+"${locked[@]}"} --lib)

# name<TAB>features for each vendored crate, as the app's build resolves them.
features="$(cd "$CORE" && cargo metadata ${locked[@]+"${locked[@]}"} --format-version 1 | python3 -c '
import json, sys
meta = json.load(sys.stdin)
local = {p["id"]: p["name"] for p in meta["packages"] if p["source"] is None}
for node in meta["resolve"]["nodes"]:
    if node["id"] in local:
        print(local[node["id"]], ",".join(node["features"]), sep="\t")
')"

# rust-core's [patch.crates-io] entries, as --config arguments.
patches=()
while IFS= read -r spec; do
  [ -n "$spec" ] && patches+=(--config "$spec")
done < <(awk -v core="$CORE" '
  /^\[/ { section = $0; next }
  section == "[patch.crates-io]" && match($0, /^[A-Za-z0-9_-]+ *= *\{ *path *= *"[^"]+"/) {
    name = $0; sub(/ *=.*/, "", name)
    path = $0; sub(/.*path *= *"/, "", path); sub(/".*/, "", path)
    printf "patch.crates-io.%s.path=\"%s/%s\"\n", name, core, path
  }' "$CORE/Cargo.toml")

stash="$(mktemp -d)"
restore() {
  for crate in "${VENDORED[@]}"; do
    lock="$CORE/vendor/$crate/Cargo.lock"
    if [ -f "$stash/$crate.lock" ]; then mv -f "$stash/$crate.lock" "$lock"
    elif [ -f "$stash/$crate.none" ]; then rm -f "$lock"
    fi
  done
  rm -rf "$stash"
}
trap restore EXIT

for crate in "${VENDORED[@]}"; do
  dir="$CORE/vendor/$crate"
  line="$(printf '%s\n' "$features" | awk -F '\t' -v n="$crate" '$1 == n')"
  [ -n "$line" ] || { echo "error: $crate isn't in rust-core's build any more; update VENDORED in $0" >&2; exit 1; }
  list="$(printf '%s' "$line" | cut -f2)"
  echo "==> vendor/$crate${list:+ (features: $list)}"
  if [ -f "$dir/Cargo.lock" ]; then cp "$dir/Cargo.lock" "$stash/$crate.lock"; else touch "$stash/$crate.none"; fi
  cp "$CORE/Cargo.lock" "$dir/Cargo.lock"
  (cd "$dir" && cargo test --lib --no-default-features ${list:+--features "$list"} \
    ${patches[@]+"${patches[@]}"} -- ${skips[@]+"${skips[@]}"})
done
echo "==> All Rust tests passed"
