#!/bin/bash
# Build an unsigned SideInstaller IPA from any branch, with the bundle id the
# public IPA uses, for signers that take any bundle id (Feather and the like).
#
#   scripts/export-ipa.sh            pick a branch from a list
#   scripts/export-ipa.sh <branch>   export that branch (or any tag / commit)
#
# It then asks where the IPA goes: the Desktop, as SideInstaller.ipa (replacing
# the one there), or the folder it was run from, named with version, branch and
# commit. When done, the IPA is selected in Finder.
#
# The branch's last commit is built in a separate worktree under CACHE_DIR, so
# this checkout, its uncommitted changes and Xcode's own build folder are left
# alone. The Xcode project is gitignored, so the local one is copied in with
# its bundle ids swapped (extensions keep their suffix, e.g. .LiveActivity).
# That's this checkout's project, which carries the current version; when it
# lacks Swift files the branch has (or lists ones it lacks), the project of the
# branch's own worktree is used instead, if that one fits.
# Nothing is signed and nothing is sent to Apple.
#
# Config, all overridable by env:
#   BUNDLE_ID   bundle id of the exported app (default: com.frizzlem.sideinstaller)
#   OUTPUT_DIR  skip the question and save there, named as in the run folder
#   REVEAL      1 = select the .ipa in Finder when done, 0 = don't (default: 1)
#   XCODEPROJ   Xcode project to copy in, instead of picking one as above
#   CACHE_DIR   worktree, build folders and built Rust libraries, reused between
#               runs (default: ~/Library/Caches/SideInstallerExport)
set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-com.frizzlem.sideinstaller}"
OUTPUT_DIR="${OUTPUT_DIR:-}"
REVEAL="${REVEAL:-1}"
CACHE_DIR="${CACHE_DIR:-$HOME/Library/Caches/SideInstallerExport}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$CACHE_DIR/src"
DERIVED="$CACHE_DIR/DerivedData"
FFI_CACHE="$CACHE_DIR/ffi"
LOG="$CACHE_DIR/last-build.log"

# build-rust.sh defaults to Xcode-beta; use the selected Xcode when it's missing.
if [ -z "${DEVELOPER_DIR:-}" ] && [ ! -d /Applications/Xcode-beta.app ]; then
  DEVELOPER_DIR="$(xcode-select -p)"
  export DEVELOPER_DIR
fi

die() { echo "error: $*" >&2; exit 1; }
build_failed() {
  echo "error: $1. Last errors:" >&2
  grep -E "error(\[E[0-9]+\])?:|\*\* BUILD FAILED" "$LOG" | tail -20 >&2 || tail -20 "$LOG" >&2
  echo "Full log: $LOG" >&2
  exit 1
}
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null; }

HERE="$PWD"
cd "$ROOT"

# --- Pick the branch ----------------------------------------------------------
ref="${1:-}"
if [ -z "$ref" ]; then
  branches=()
  while IFS= read -r b; do branches+=("$b"); done < <(
    git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads
    # Remote branches without a local one (origin/HEAD shows as plain "origin").
    git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes |
      grep / | grep -v '/HEAD$' | while IFS= read -r r; do
        git show-ref --verify --quiet "refs/heads/${r#*/}" || echo "$r"
      done
  )
  [ "${#branches[@]}" -gt 0 ] || die "no branches found"
  echo "Branches, newest first:"
  i=1
  for b in "${branches[@]}"; do
    printf '%3d) %-34s %s  %s\n' "$i" "$b" \
      "$(git log -1 --format=%cd --date=short "$b")" "$(git log -1 --format=%s "$b" | cut -c1-60)"
    i=$((i + 1))
  done
  printf 'Export which? [1] '
  read -r pick
  pick="${pick:-1}"
  case "$pick" in *[!0-9]*) die "not a number: $pick" ;; esac
  { [ "$pick" -ge 1 ] && [ "$pick" -le "${#branches[@]}" ]; } || die "no branch $pick"
  ref="${branches[$((pick - 1))]}"
fi
commit="$(git rev-parse --verify --quiet "$ref^{commit}")" || die "unknown branch or commit: $ref"
short="$(git rev-parse --short "$commit")"

# --- Pick where the IPA goes --------------------------------------------------
# An empty name means the long one, made once the version is known.
if [ -n "$OUTPUT_DIR" ]; then
  case "$OUTPUT_DIR" in /*) out_dir="$OUTPUT_DIR" ;; *) out_dir="$HERE/$OUTPUT_DIR" ;; esac
  out_name=""
else
  echo "Save the IPA to:"
  echo "  1) Desktop, as SideInstaller.ipa (replaces the one there)"
  echo "  2) this folder: $HERE"
  printf 'Where? [1] '
  read -r where
  case "${where:-1}" in
    1) out_dir="$HOME/Desktop" out_name="SideInstaller.ipa" ;;
    2) out_dir="$HERE" out_name="" ;;
    *) die "not 1 or 2: $where" ;;
  esac
fi
echo "==> Exporting $ref at $short: $(git log -1 --format=%s "$commit")"

# Where the branch is checked out, if anywhere (this checkout or a worktree).
checkout=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*) wt="${line#worktree }" ;;
    "branch refs/heads/$ref") checkout="$wt" ;;
  esac
done < <(git worktree list --porcelain)
if [ -n "$checkout" ] && [ -n "$(git -C "$checkout" status --porcelain --untracked-files=no)" ]; then
  echo "    note: $checkout has uncommitted changes; only committed work is exported"
fi

# --- Check out the commit -----------------------------------------------------
mkdir -p "$CACHE_DIR" "$FFI_CACHE"
: >"$LOG"
git worktree prune
if [ -e "$SRC/.git" ]; then
  git -C "$SRC" checkout --detach --force --quiet "$commit"
  git -C "$SRC" clean -fdq # keeps ignored files: Rust target, xcframework
else
  echo "==> Creating the export worktree (first run only)"
  rm -rf "$SRC"
  git worktree add --detach --quiet "$SRC" "$commit"
  # Start from this checkout's Rust build (APFS clones, no extra space), so
  # only the crates that differ get compiled.
  if [ -d "$ROOT/rust-core/target" ]; then
    mkdir -p "$SRC/rust-core/target"
    for d in release aarch64-apple-ios aarch64-apple-ios-sim; do
      if [ -d "$ROOT/rust-core/target/$d" ]; then
        cp -cR "$ROOT/rust-core/target/$d" "$SRC/rust-core/target/"
      fi
    done
  fi
fi

# --- Xcode project with the export bundle id ----------------------------------
# New Swift files are registered in the project by hand, so a project file can
# miss files this commit has, or list ones it doesn't. One line per mismatch.
project_mismatches() {
  local f n
  for f in "$SRC"/ios-app/*.swift "$SRC"/ios-live-activity/*.swift; do
    [ -e "$f" ] || continue
    grep -qF "path = $(basename "$f");" "$1" 2>/dev/null ||
      echo "$(basename "$f") is in the branch but not in the Xcode project"
  done
  for n in $(grep -oE 'path = [^;"]+\.swift;' "$1" 2>/dev/null | sed -E 's/path = (.*);/\1/' | sort -u); do
    [ -e "$SRC/ios-app/$n" ] || [ -e "$SRC/ios-live-activity/$n" ] ||
      echo "$n is in the Xcode project but not in the branch"
  done
  return 0
}

if [ -n "${XCODEPROJ:-}" ]; then
  project="$XCODEPROJ"
else
  project="$ROOT/SideInstaller.xcodeproj"
  if [ -n "$(project_mismatches "$project/project.pbxproj")" ] && [ -n "$checkout" ] &&
    [ -f "$checkout/SideInstaller.xcodeproj/project.pbxproj" ] &&
    [ -z "$(project_mismatches "$checkout/SideInstaller.xcodeproj/project.pbxproj")" ]; then
    project="$checkout/SideInstaller.xcodeproj"
  fi
fi
[ -f "$project/project.pbxproj" ] || die "no Xcode project at $project"
echo "    Xcode project: $project"
rm -rf "$SRC/SideInstaller.xcodeproj"
cp -R "$project" "$SRC/SideInstaller.xcodeproj"
pbx="$SRC/SideInstaller.xcodeproj/project.pbxproj"
# The app's id is the shortest one; extension ids start with it.
app_id="$(grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;' "$pbx" | sed -E 's/.* = "?([^";]+)"?;/\1/' |
  awk '{ print length, $0 }' | sort -n | head -1 | cut -d' ' -f2-)"
[ -n "$app_id" ] || die "no PRODUCT_BUNDLE_IDENTIFIER in $pbx"
sed -i '' -E "s/(PRODUCT_BUNDLE_IDENTIFIER = \"?)$(printf '%s' "$app_id" | sed 's/\./\\./g')([.\";])/\1$BUNDLE_ID\2/" "$pbx"

# Left over mismatches fail the build with a cryptic error; say which files.
project_mismatches "$pbx" | sed 's/^/    warning: /'

# --- Rust library, built once per rust-core version ---------------------------
ffi_key="$(git rev-parse "$commit:rust-core")-$(git rev-parse "$commit:build-rust.sh")"
rm -rf "$SRC/SideInstallerFFI.xcframework"
if [ -d "$FFI_CACHE/$ffi_key/SideInstallerFFI.xcframework" ]; then
  echo "==> Rust library: reusing the build of this rust-core"
else
  echo "==> Building the Rust library (new rust-core, can take a few minutes)"
  (cd "$SRC" && ./build-rust.sh) >>"$LOG" 2>&1 || build_failed "Rust build failed"
  rm -rf "$FFI_CACHE/$ffi_key"
  mkdir -p "$FFI_CACHE/$ffi_key"
  mv "$SRC/SideInstallerFFI.xcframework" "$FFI_CACHE/$ffi_key/"
  # Keep the five most recent.
  ls -1t "$FFI_CACHE" | tail -n +6 | while IFS= read -r old; do rm -rf "${FFI_CACHE:?}/$old"; done
fi
touch "$FFI_CACHE/$ffi_key"
cp -R "$FFI_CACHE/$ffi_key/SideInstallerFFI.xcframework" "$SRC/"

# --- App ----------------------------------------------------------------------
echo "==> Building SideInstaller (Release, unsigned)"
# A precompiled module of the previous export's Rust header fails the build.
find "$DERIVED" -name 'SideInstallerFFI-*.pcm' -delete 2>/dev/null || true
xcodebuild build \
  -project "$SRC/SideInstaller.xcodeproj" -scheme SideInstaller -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  >>"$LOG" 2>&1 || build_failed "Xcode build failed"

app="$DERIVED/Build/Products/Release-iphoneos/SideInstaller.app"
[ -d "$app" ] || die "no SideInstaller.app in $DERIVED/Build/Products/Release-iphoneos"
got="$(plist CFBundleIdentifier "$app/Info.plist")"
[ "$got" = "$BUNDLE_ID" ] || die "the built app's bundle id is $got, not $BUNDLE_ID"
for ext in "$app"/PlugIns/*.appex "$app"/Extensions/*.appex; do
  [ -d "$ext" ] || continue
  eid="$(plist CFBundleIdentifier "$ext/Info.plist")"
  case "$eid" in "$BUNDLE_ID".*) ;; *) die "$(basename "$ext") has bundle id $eid, outside $BUNDLE_ID" ;; esac
done
version="$(plist CFBundleShortVersionString "$app/Info.plist")"

# --- IPA ----------------------------------------------------------------------
stage="$CACHE_DIR/stage"
rm -rf "$stage"
mkdir -p "$stage/Payload" "$out_dir"
ditto "$app" "$stage/Payload/SideInstaller.app"
find "$stage" -name .DS_Store -delete
out="$out_dir/${out_name:-SideInstaller-$version-$(printf '%s' "$ref" | tr '/' '-')-$short.ipa}"
rm -f "$out" # zip would add to an existing archive instead of replacing it
(cd "$stage" && zip -qryX "$out" Payload)
rm -rf "$stage"

echo "==> Done: $out ($(du -h "$out" | cut -f1 | tr -d ' '))"
echo "    $BUNDLE_ID, version $version, unsigned"
if [ "$REVEAL" = 1 ]; then open -R "$out"; fi
