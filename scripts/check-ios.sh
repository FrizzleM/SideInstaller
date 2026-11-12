#!/bin/bash
# Builds SideInstaller for the iOS simulator and runs its unit tests
# (SideInstallerTests, ios-tests/), as the pull-request workflow does: the Rust
# library's simulator slice, an Xcode project generated from project.yml, then
# `xcodebuild test` on a simulator.
#
#   scripts/check-ios.sh
#
# Needs Xcode with the iOS 27 SDK, Rust with the aarch64-apple-ios-sim target
# (added here when rustup is around) and xcodegen.
#
# For a clean clone or worktree, like scripts/build-ipa.sh: the Xcode project is
# generated into the checkout, so one that already has its own
# SideInstaller.xcodeproj is refused rather than overwritten (one this script
# generated is generated again). Nothing is signed.
#
# Config, all overridable by env:
#   SIMULATOR_ID   UDID of the simulator to run on (default: the first iPhone on
#                  the newest iOS runtime)
#   DERIVED_DATA   Xcode build folder (default: build/DerivedData-sim)
#   RESULT_BUNDLE  test results, for Xcode's Test navigator (default:
#                  build/SideInstallerTests.xcresult)
#   REBUILD_RUST   1 = rebuild SideInstallerFFI.xcframework even when one with
#                  a simulator slice is there
set -euo pipefail
trap 'rc=$?; [ "$rc" = 0 ] || echo "error: check-ios.sh stopped (exit $rc) at: $BASH_COMMAND" >&2' EXIT
if [ "${RUNNER_DEBUG:-}" = 1 ]; then set -x; fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData-sim}"
RESULT_BUNDLE="${RESULT_BUNDLE:-$ROOT/build/SideInstallerTests.xcresult}"
REBUILD_RUST="${REBUILD_RUST:-0}"
SIMULATOR_ID="${SIMULATOR_ID:-}"

die() { echo "error: $*" >&2; exit 1; }
case "$DERIVED_DATA" in /*) ;; *) DERIVED_DATA="$PWD/$DERIVED_DATA" ;; esac
case "$RESULT_BUNDLE" in /*) ;; *) RESULT_BUNDLE="$PWD/$RESULT_BUNDLE" ;; esac
cd "$ROOT"

# Left in a project this script generated, so the next run may replace it.
MARKER=SideInstaller.xcodeproj/.generated-by-check-ios
if [ -e SideInstaller.xcodeproj ] && [ ! -e "$MARKER" ]; then
  die "this checkout already has a SideInstaller.xcodeproj, which generating one would overwrite. Run this in a clean clone or worktree."
fi

# shellcheck disable=SC1091
if ! command -v cargo >/dev/null && [ -f "$HOME/.cargo/env" ]; then
  set +u
  source "$HOME/.cargo/env" || true
  set -u
fi
command -v xcodegen >/dev/null || die "xcodegen isn't installed (brew install xcodegen)"
command -v cargo >/dev/null || die "Rust isn't installed (https://rustup.rs)"
# build-rust.sh falls back to Xcode-beta; build with the selected Xcode.
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
echo "==> $(xcodebuild -version | tr '\n' ' ')"

# --- Rust library -------------------------------------------------------------
if [ "$REBUILD_RUST" = 1 ] || [ ! -d SideInstallerFFI.xcframework/ios-arm64-simulator ]; then
  if command -v rustup >/dev/null && ! rustup target list --installed | grep -qx aarch64-apple-ios-sim; then
    rustup target add aarch64-apple-ios-sim
  fi
  echo "==> Building the Rust library (simulator)"
  DEVICE=0 bash ./build-rust.sh
else
  echo "==> Rust library: using the SideInstallerFFI.xcframework already here"
fi
[ -d SideInstallerFFI.xcframework/ios-arm64-simulator ] || die "no simulator slice in SideInstallerFFI.xcframework"

# --- Xcode project ------------------------------------------------------------
echo "==> Generating SideInstaller.xcodeproj from project.yml"
xcodegen generate --spec project.yml --quiet
touch "$MARKER"

# --- Simulator ----------------------------------------------------------------
if [ -z "$SIMULATOR_ID" ]; then
  SIMULATOR_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
best = None
for runtime, entries in devices.items():
    # Plain iOS runtimes only, not a device-specific one such as iOS-27-2-iPhone19-4.
    m = re.search(r"\.iOS-(\d+)-(\d+)(?:-(\d+))?$", runtime)
    if not m:
        continue
    version = tuple(int(p or 0) for p in m.groups())
    for d in entries:
        if d["name"].startswith("iPhone") and (best is None or version > best[0]):
            best = (version, d["udid"], d["name"])
if best:
    print(best[1])
    print("==> Simulator: %s, iOS %s" % (best[2], ".".join(map(str, best[0]))), file=sys.stderr)
')"
fi
[ -n "$SIMULATOR_ID" ] || die "no iPhone simulator available (xcrun simctl list devices available)"

# --- Build and test -----------------------------------------------------------
echo "==> Building SideInstaller for the simulator and running SideInstallerTests"
# A precompiled module of an older Rust header fails the build.
find "$DERIVED_DATA" -name 'SideInstallerFFI-*.pcm' -delete 2>/dev/null || true
rm -rf "$RESULT_BUNDLE"
mkdir -p "$(dirname "$RESULT_BUNDLE")"
rc=0
xcodebuild test \
  -project SideInstaller.xcodeproj -scheme SideInstaller -configuration Debug \
  -destination "id=$SIMULATOR_ID" -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$RESULT_BUNDLE" -quiet \
  CODE_SIGNING_ALLOWED=NO || rc=$?

# -quiet names a failing test but not what failed; the result bundle has it.
if [ -d "$RESULT_BUNDLE" ]; then
  xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" --compact 2>/dev/null | python3 -c '
import json, os, sys
try:
    summary = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
print("==> %s tests passed, %s failed" % (summary.get("passedTests", 0), summary.get("failedTests", 0)))
github = os.environ.get("GITHUB_ACTIONS") == "true"
for f in summary.get("testFailures", []):
    name, text = f.get("testIdentifierString", "?"), f.get("failureText", "")
    print("\n--- %s\n%s" % (name, text))
    if github:
        print("::error title=%s::%s" % (name, text.replace("%", "%25").replace("\n", "%0A")))
' || true
fi
[ "$rc" = 0 ] || die "the simulator build or SideInstallerTests failed (xcodebuild exit $rc; results in $RESULT_BUNDLE)"

echo "==> Done: the simulator build and SideInstallerTests passed ($RESULT_BUNDLE)"
