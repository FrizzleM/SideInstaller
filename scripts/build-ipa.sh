#!/bin/bash
# Build the unsigned SideInstaller IPA from this checkout, as the
# release-sideinstaller workflow does on GitHub: the Rust library, an Xcode
# project generated from project.yml, a Release build with signing off, and the
# app zipped into Payload/.
#
#   scripts/build-ipa.sh
#
# Needs Xcode with the iOS 27 SDK, Rust with the aarch64-apple-ios target
# (added here when rustup is around) and xcodegen.
#
# For a clean clone, like the one CI checks out. The Xcode project is generated
# into the checkout, so one that already has its own SideInstaller.xcodeproj is
# refused rather than overwritten; scripts/export-ipa.sh builds from there.
# Nothing is signed and nothing is sent to Apple.
#
# Config, all overridable by env:
#   VERSION        CFBundleShortVersionString, e.g. 1.6.0 (default: project.yml's)
#   BUILD_NUMBER   CFBundleVersion (default: project.yml's)
#   BUNDLE_ID      bundle id of the app; the extension keeps its suffix, e.g.
#                  .LiveActivity (default: com.frizzlem.sideinstaller, the
#                  published one)
#   OUTPUT         path of the IPA (default: build/SideInstaller.ipa)
#   DERIVED_DATA   Xcode build folder (default: build/DerivedData)
#   REBUILD_RUST   1 = rebuild SideInstallerFFI.xcframework even when one is
#                  there (default: build it only when it's missing)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="${BUNDLE_ID:-com.frizzlem.sideinstaller}"
OUTPUT="${OUTPUT:-$ROOT/build/SideInstaller.ipa}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData}"
REBUILD_RUST="${REBUILD_RUST:-0}"
VERSION="${VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"

die() { echo "error: $*" >&2; exit 1; }
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null; }

case "$OUTPUT" in /*) ;; *) OUTPUT="$PWD/$OUTPUT" ;; esac
case "$DERIVED_DATA" in /*) ;; *) DERIVED_DATA="$PWD/$DERIVED_DATA" ;; esac
cd "$ROOT"

[ -e SideInstaller.xcodeproj ] &&
  die "this checkout already has a SideInstaller.xcodeproj, which generating one would overwrite. Run this in a clean clone, or use scripts/export-ipa.sh here."
if [ -n "$VERSION" ]; then
  # What iOS accepts as CFBundleShortVersionString.
  [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || die "VERSION must be up to three numbers, like 1.6.0 (got: $VERSION)"
fi
if [ -n "$BUILD_NUMBER" ]; then
  [[ "$BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || die "BUILD_NUMBER must be up to three numbers (got: $BUILD_NUMBER)"
fi

# build-rust.sh defaults to Xcode-beta; use the selected Xcode instead.
if [ -z "${DEVELOPER_DIR:-}" ]; then
  DEVELOPER_DIR="$(xcode-select -p)"
fi
export DEVELOPER_DIR
# shellcheck disable=SC1091
source "$HOME/.cargo/env" 2>/dev/null || true
command -v xcodegen >/dev/null || die "xcodegen isn't installed (brew install xcodegen)"
command -v cargo >/dev/null || die "Rust isn't installed (https://rustup.rs)"
echo "==> $(xcodebuild -version | tr '\n' ' ')"

# --- Rust library -------------------------------------------------------------
if [ "$REBUILD_RUST" = 1 ] || [ ! -d SideInstallerFFI.xcframework ]; then
  if command -v rustup >/dev/null && ! rustup target list --installed | grep -qx aarch64-apple-ios; then
    rustup target add aarch64-apple-ios
  fi
  echo "==> Building the Rust library"
  SIMULATOR=0 bash ./build-rust.sh
else
  echo "==> Rust library: using the SideInstallerFFI.xcframework already here"
fi
[ -d SideInstallerFFI.xcframework ] || die "no SideInstallerFFI.xcframework after the Rust build"

# --- Xcode project ------------------------------------------------------------
echo "==> Generating SideInstaller.xcodeproj from project.yml"
xcodegen generate --spec project.yml --quiet
pbx=SideInstaller.xcodeproj/project.pbxproj
[ -f "$pbx" ] || die "xcodegen made no $pbx"
# Give the app the bundle id to build with, and the extension the same id plus
# its suffix. The app's id is the shortest one; the extension's starts with it.
app_id="$(grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;' "$pbx" | sed -E 's/.* = "?([^";]+)"?;/\1/' |
  awk '{ print length, $0 }' | sort -n | head -1 | cut -d' ' -f2-)"
[ -n "$app_id" ] || die "no PRODUCT_BUNDLE_IDENTIFIER in $pbx"
sed -i '' -E "s/(PRODUCT_BUNDLE_IDENTIFIER = \"?)$(printf '%s' "$app_id" | sed 's/\./\\./g')([.\";])/\1$BUNDLE_ID\2/" "$pbx"

# --- App ----------------------------------------------------------------------
overrides=()
[ -n "$VERSION" ] && overrides+=("MARKETING_VERSION=$VERSION")
[ -n "$BUILD_NUMBER" ] && overrides+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")
echo "==> Building SideInstaller (Release, unsigned)"
# A precompiled module of an older Rust header fails the build.
find "$DERIVED_DATA" -name 'SideInstallerFFI-*.pcm' -delete 2>/dev/null || true
xcodebuild build \
  -project SideInstaller.xcodeproj -scheme SideInstaller -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  ${overrides[@]+"${overrides[@]}"}

app="$DERIVED_DATA/Build/Products/Release-iphoneos/SideInstaller.app"
[ -d "$app" ] || die "no SideInstaller.app in $DERIVED_DATA/Build/Products/Release-iphoneos"
got="$(plist CFBundleIdentifier "$app/Info.plist")"
[ "$got" = "$BUNDLE_ID" ] || die "the built app's bundle id is $got, not $BUNDLE_ID"
version="$(plist CFBundleShortVersionString "$app/Info.plist")"
if [ -n "$VERSION" ] && [ "$version" != "$VERSION" ]; then
  die "the built app's version is $version, not $VERSION"
fi
exts=0
for ext in "$app"/PlugIns/*.appex "$app"/Extensions/*.appex; do
  [ -d "$ext" ] || continue
  exts=$((exts + 1))
  eid="$(plist CFBundleIdentifier "$ext/Info.plist")"
  case "$eid" in "$BUNDLE_ID".*) ;; *) die "$(basename "$ext") has bundle id $eid, outside $BUNDLE_ID" ;; esac
  ever="$(plist CFBundleShortVersionString "$ext/Info.plist")"
  [ "$ever" = "$version" ] || die "$(basename "$ext") has version $ever, the app $version"
done
[ "$exts" -gt 0 ] || die "no app extension in the built app (the Live Activity is missing)"

# --- IPA ----------------------------------------------------------------------
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload" "$(dirname "$OUTPUT")"
ditto "$app" "$stage/Payload/SideInstaller.app"
find "$stage" -name .DS_Store -delete
rm -f "$OUTPUT" # zip would add to an existing archive instead of replacing it
(cd "$stage" && zip -qryX "$OUTPUT" Payload)

echo "==> Done: $OUTPUT ($(du -h "$OUTPUT" | cut -f1 | tr -d ' '))"
echo "    $BUNDLE_ID, version $version ($(plist CFBundleVersion "$app/Info.plist")), unsigned"
echo "    sha256 $(shasum -a 256 "$OUTPUT" | cut -d' ' -f1)"
