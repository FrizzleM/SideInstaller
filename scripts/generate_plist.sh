#!/bin/bash
# Generate one OTA install manifest (.plist) per signed IPA in OUTPUT_DIR.
# The itms-services:// links on the install page point at these manifests.
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-sideinstaller}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"

# Where the signed IPAs are served from. Defaults to the repo's raw URLs.
if [[ -n "${GITHUB_REPOSITORY:-}" && "$GITHUB_REPOSITORY" == */* ]]; then
  GITHUB_USER="${GITHUB_USER:-${GITHUB_REPOSITORY%/*}}"
  GITHUB_REPO="${GITHUB_REPO:-${GITHUB_REPOSITORY#*/}}"
else
  # Outside CI, derive owner/repo from the git "origin" remote so locally
  # generated URLs match wherever this repo actually lives. Keeps the script
  # owner-neutral while stopping a stale placeholder slug (which 404s) from
  # being baked into committed artifacts. Falls back to the placeholder only
  # when there is no usable GitHub remote (e.g. a git-archive export).
  origin_slug="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null \
    | sed -E 's#(\.git)?/?$##; s#^.*github\.com[:/]+##' || true)"
  if [[ "$origin_slug" =~ ^[^/]+/[^/]+$ ]]; then
    GITHUB_USER="${GITHUB_USER:-${origin_slug%/*}}"
    GITHUB_REPO="${GITHUB_REPO:-${origin_slug#*/}}"
  else
    GITHUB_USER="${GITHUB_USER:-SideInstaller}"
    GITHUB_REPO="${GITHUB_REPO:-SideInstaller}"
  fi
fi
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
OUTPUT_BASE_URL="${OUTPUT_BASE_URL:-https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/output}"

generate_one() {
  local IPA_PATH="$1" PLIST_OUT="$2"
  local IPA_FILENAME; IPA_FILENAME="$(basename "$IPA_PATH")"
  local IPA_URL="$OUTPUT_BASE_URL/$IPA_FILENAME"

  local TMPDIR; TMPDIR="$(mktemp -d)"
  if ! unzip -q "$IPA_PATH" -d "$TMPDIR"; then
    rm -rf "$TMPDIR"; echo "[!] Failed to unzip IPA: $IPA_FILENAME"; return 1
  fi

  local APP_PATH; APP_PATH="$(find "$TMPDIR/Payload" -maxdepth 1 -name "*.app" | LC_ALL=C sort)"
  APP_PATH="${APP_PATH%%$'\n'*}"
  if [[ -z "${APP_PATH:-}" ]]; then
    rm -rf "$TMPDIR"; echo "[!] No .app found inside: $IPA_FILENAME"; return 1
  fi

  local INFO_PLIST="$APP_PATH/Info.plist" BUNDLE_ID BUNDLE_VERSION TITLE
  BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || echo "")
  BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0")
  TITLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$INFO_PLIST" 2>/dev/null \
       || /usr/libexec/PlistBuddy -c "Print :CFBundleName" "$INFO_PLIST" 2>/dev/null || echo "$IPA_FILENAME")

  if [[ -z "$BUNDLE_ID" ]]; then
    rm -rf "$TMPDIR"; echo "[!] Missing CFBundleIdentifier in: $IPA_FILENAME"; return 1
  fi

  cat > "$PLIST_OUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>$IPA_URL</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>$BUNDLE_ID</string>
        <key>bundle-version</key>
        <string>$BUNDLE_VERSION</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>$TITLE</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
EOF

  rm -rf "$TMPDIR"
  echo "[✓] Generated plist: $(basename "$PLIST_OUT")"
}

mkdir -p "$OUTPUT_DIR"

if [[ $# -ge 2 ]]; then
  generate_one "$1" "$2"; exit $?
fi

shopt -s nullglob
OLD_PLISTS=("$OUTPUT_DIR"/*.plist)
shopt -u nullglob
[[ ${#OLD_PLISTS[@]} -gt 0 ]] && rm -f "${OLD_PLISTS[@]}"

shopt -s nullglob
IPA_FILES=("$OUTPUT_DIR"/"$OUTPUT_PREFIX"-*.ipa)
shopt -u nullglob
if [[ ${#IPA_FILES[@]} -eq 0 ]]; then
  echo "[!] No .ipa files found in $OUTPUT_DIR"; exit 0
fi

SUCCESS=0; FAILED=0
for ipa in "${IPA_FILES[@]}"; do
  plist_out="${ipa%.ipa}.plist"
  if generate_one "$ipa" "$plist_out"; then SUCCESS=$((SUCCESS+1)); else FAILED=$((FAILED+1)); fi
done

echo "[✓] Plist generation done"
echo "[✓] Successful: $SUCCESS"
echo "[!] Failed: $FAILED"
