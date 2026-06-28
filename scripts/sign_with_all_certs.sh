#!/bin/bash
# Sign one unsigned IPA with EVERY certificate in a cert pool zip.
#
# Config (all overridable by env; sensible defaults baked in):
#   UNSIGNED_IPA_URL  direct URL of the unsigned IPA. If unset, the first
#                     non-comment line of ipa-url.txt is used.
#   CERT_ZIP_URL      direct URL of the certificate pool zip. If unset, the
#                     first non-comment line of cert-url.txt is used.
#   OUTPUT_DIR        where signed IPAs + metadata land (default: ./output)
#   OUTPUT_PREFIX     filename prefix for signed IPAs (default: sideinstaller)
#   P12_PASSWORD      fallback p12 password when no sidecar file exists
#   FORCED_BUNDLE_ID  override bundle id for wildcard profiles
#
# Cert pool layout (one folder per cert):
#   <Name>/<Name>.p12  +  <Name>/<Name>.mobileprovision  [+ <Name>/password.txt]
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-sideinstaller}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
CERT_URL_FILE="${CERT_URL_FILE:-$ROOT_DIR/cert-url.txt}"
IPA_URL_FILE="${IPA_URL_FILE:-$ROOT_DIR/ipa-url.txt}"
CERT_METADATA_FILE="${CERT_METADATA_FILE:-$OUTPUT_DIR/certificate-validity.tsv}"
APP_INFO_FILE="${APP_INFO_FILE:-$OUTPUT_DIR/app-info.tsv}"
CERT_NAME_LIST_FILE="${CERT_NAME_LIST_FILE:-}"

DEFAULT_CERT_ZIP_URL="https://github.com/WSF-Team/WSF/raw/refs/heads/main/portal/resources/certificates.zip"

DEFAULT_P12_PASSWORD="${P12_PASSWORD:-WSF}"
KC_PASSWORD="${KC_PASSWORD:-temp123}"
FORCED_BUNDLE_ID="${FORCED_BUNDLE_ID:-}"

TMP_DIR="$(mktemp -d)"
CERT_ARCHIVE="$TMP_DIR/certificates.zip"
UNSIGNED_IPA="$TMP_DIR/unsigned.ipa"
APPLE_CERTS_DIR="$TMP_DIR/apple-certs"
INTERMEDIATES_KC="$TMP_DIR/intermediates.keychain-db"
OCSP_CA_BUNDLE="$APPLE_CERTS_DIR/ocsp-ca-bundle.pem"

ORIGINAL_KEYCHAINS=()
OPENSSL_LEGACY_FLAG=""

log()  { echo "[LOG] $1"; }
warn() { echo "[WARN] $1"; }
fail() { echo "[FAIL] $1"; }

cleanup() {
  security delete-keychain "$INTERMEDIATES_KC" >/dev/null 2>&1 || true
  restore_keychains
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

restore_keychains() {
  if [[ ${#ORIGINAL_KEYCHAINS[@]} -gt 0 ]]; then
    security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1 || true
  fi
}

# First non-blank, non-comment line of a file, CR-stripped and trimmed.
first_config_line() {
  awk '
    {
      sub(/\r$/, "")
      sub(/^[[:space:]]+/, "")
      if ($0 ~ /^#/ || $0 !~ /[^[:space:]]/) next
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$1"
}

password_from_file() {
  awk '
    {
      sub(/\r$/, "")
      if ($0 ~ /password[[:space:]]*[:：]/) {
        sub(/^.*password[[:space:]]*[:：][[:space:]]*/, ""); found = 1; print; exit
      }
      if ($0 ~ /密码[[:space:]]*[:：]/) {
        sub(/^.*密码[[:space:]]*[:：][[:space:]]*/, ""); found = 1; print; exit
      }
      if ($0 ~ /[^[:space:]]/ && first == "") first = $0
    }
    END { if (!found && first != "") print first }
  ' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

safe_name() {
  echo "$1" | tr ' ' '-' | sed 's/[^A-Za-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

clean_generated_artifacts() {
  local pattern="$1"
  local matches=()
  shopt -s nullglob
  matches=("$OUTPUT_DIR"/$pattern)
  shopt -u nullglob
  if [[ ${#matches[@]} -gt 0 ]]; then
    rm -f "${matches[@]}"
  fi
}

resolve_cert_zip_url() {
  if [[ -n "${CERT_ZIP_URL:-}" ]]; then
    echo "$CERT_ZIP_URL"; return 0
  fi
  if [[ -f "$CERT_URL_FILE" ]]; then
    local u; u="$(first_config_line "$CERT_URL_FILE")"
    [[ -n "$u" ]] && { echo "$u"; return 0; }
  fi
  echo "$DEFAULT_CERT_ZIP_URL"
}

resolve_unsigned_ipa_url() {
  if [[ -n "${UNSIGNED_IPA_URL:-}" ]]; then
    echo "$UNSIGNED_IPA_URL"; return 0
  fi
  if [[ -f "$IPA_URL_FILE" ]]; then
    local u; u="$(first_config_line "$IPA_URL_FILE")"
    [[ -n "$u" ]] && { echo "$u"; return 0; }
  fi
  return 1
}

resolve_p12_password() {
  local cert_dir="$1" base_name="$2" candidate=""
  for candidate in \
    "$cert_dir/$base_name.password" "$cert_dir/$base_name.pass" "$cert_dir/$base_name.txt" \
    "$cert_dir/password.txt" "$cert_dir/password" \
    "$cert_dir/readme.txt" "$cert_dir/README.txt" "$cert_dir/readme"; do
    if [[ -f "$candidate" ]]; then
      local p; p="$(password_from_file "$candidate")"
      [[ -n "$p" ]] && { echo "$p"; return 0; }
    fi
  done
  echo "$DEFAULT_P12_PASSWORD"
}

set_plist_string() {
  /usr/libexec/PlistBuddy -c "Set $2 $3" "$1" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Add $2 string $3" "$1" >/dev/null 2>&1
}

derive_bundle_id() {
  local team_id="$1" profile_app_id="$2" original_bundle_id="$3"
  if [[ -z "$team_id" || -z "$profile_app_id" ]]; then echo "$original_bundle_id"; return 0; fi
  case "$profile_app_id" in
    "$team_id.*")
      if [[ -n "$FORCED_BUNDLE_ID" ]]; then echo "$FORCED_BUNDLE_ID"; else echo "$original_bundle_id"; fi ;;
    "$team_id."*) echo "${profile_app_id#"$team_id."}" ;;
    *) echo "$original_bundle_id" ;;
  esac
}

normalize_keychain_groups() {
  local entitlements_path="$1" team_id="$2" target_bundle_id="$3" idx=0 group_value=""
  while group_value=$(/usr/libexec/PlistBuddy -c "Print :keychain-access-groups:$idx" "$entitlements_path" 2>/dev/null); do
    if [[ "$group_value" == "$team_id.*" ]]; then
      /usr/libexec/PlistBuddy -c "Set :keychain-access-groups:$idx $team_id.$target_bundle_id" "$entitlements_path" >/dev/null 2>&1
    fi
    idx=$((idx + 1))
  done
  if ! /usr/libexec/PlistBuddy -c "Print :keychain-access-groups:0" "$entitlements_path" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Add :keychain-access-groups array" "$entitlements_path" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :keychain-access-groups:0 string $team_id.$target_bundle_id" "$entitlements_path" >/dev/null 2>&1
  fi
}

prepare_entitlements() {
  local profile_plist="$1" entitlements_path="$2" team_id="$3" target_bundle_id="$4"
  /usr/libexec/PlistBuddy -x -c "Print :Entitlements" "$profile_plist" > "$entitlements_path" 2>/dev/null || return 1
  set_plist_string "$entitlements_path" ":application-identifier" "$team_id.$target_bundle_id"
  set_plist_string "$entitlements_path" ":com.apple.developer.team-identifier" "$team_id"
  normalize_keychain_groups "$entitlements_path" "$team_id" "$target_bundle_id"
  return 0
}

repack_pkcs12() {
  local input_p12="$1" output_p12="$2" password="$3"
  local repack_dir="$TMP_DIR/repack-$(basename "$input_p12" .p12)"
  local bundle_pem="$repack_dir/bundle.pem"
  mkdir -p "$repack_dir"
  openssl pkcs12 $OPENSSL_LEGACY_FLAG -in "$input_p12" -passin "pass:$password" -nodes -out "$bundle_pem" >/dev/null 2>&1 || return 1
  openssl pkcs12 -export $OPENSSL_LEGACY_FLAG -in "$bundle_pem" -inkey "$bundle_pem" -out "$output_p12" -passout "pass:$password" >/dev/null 2>&1
}

import_certificate() {
  local p12_file="$1" keychain="$2" password="$3"
  local repacked_p12="$TMP_DIR/repacked-$(basename "$p12_file")"
  if security import "$p12_file" -f pkcs12 -k "$keychain" -P "$password" -A -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1; then
    return 0
  fi
  warn "Direct PKCS#12 import failed for $(basename "$p12_file"); retrying with an OpenSSL-normalized copy"
  command -v openssl >/dev/null 2>&1 || return 1
  repack_pkcs12 "$p12_file" "$repacked_p12" "$password" || return 1
  security import "$repacked_p12" -f pkcs12 -k "$keychain" -P "$password" -A -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1
}

certificate_expiry_info() {
  local p12_file="$1" password="$2"
  local cert_pem="$TMP_DIR/cert-$(basename "$p12_file" .p12).pem" not_after=""
  openssl pkcs12 $OPENSSL_LEGACY_FLAG -in "$p12_file" -passin "pass:$password" -nokeys -clcerts -out "$cert_pem" >/dev/null 2>&1 || return 1
  not_after="$(openssl x509 -in "$cert_pem" -noout -enddate 2>/dev/null | sed 's/^notAfter=//')"
  [[ -z "$not_after" ]] && return 1
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$not_after" <<'PY'
import math, sys
from datetime import datetime, timezone
raw = sys.argv[1].strip()
formats = ("%b %d %H:%M:%S %Y %Z", "%Y-%m-%d %H:%M:%S %Z", "%Y-%m-%dT%H:%M:%SZ")
expiry = None
for fmt in formats:
    try:
        expiry = datetime.strptime(raw, fmt); break
    except ValueError:
        pass
if expiry is None:
    raise SystemExit(1)
expiry = expiry.replace(tzinfo=timezone.utc) if expiry.tzinfo is None else expiry.astimezone(timezone.utc)
seconds_left = (expiry - datetime.now(timezone.utc)).total_seconds()
days_left = math.ceil(seconds_left / 86400) if seconds_left >= 0 else math.floor(seconds_left / 86400)
print(f"{expiry.date().isoformat()}\t{days_left}")
PY
}

# Read display name + version from the unsigned IPA once, for the install page hero.
record_app_info() {
  local ipa="$1" work; work="$TMP_DIR/appinfo"
  rm -rf "$work"; mkdir -p "$work"
  unzip -q "$ipa" -d "$work" || return 1
  local app; app="$(find "$work/Payload" -maxdepth 1 -name '*.app' | LC_ALL=C sort | head -n1)"
  [[ -z "$app" ]] && return 1
  local info="$app/Info.plist" title version
  title=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$info" 2>/dev/null \
       || /usr/libexec/PlistBuddy -c "Print :CFBundleName" "$info" 2>/dev/null || echo "SideInstaller")
  version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info" 2>/dev/null || echo "")
  printf 'title\t%s\nversion\t%s\n' "$title" "$version" > "$APP_INFO_FILE"
  log "App: $title ${version:+($version)}"
}

sign_embedded_code() {
  local app_path="$1" identity="$2"
  if [[ -d "$app_path/Frameworks" ]]; then
    while IFS= read -r component; do
      [[ -n "$component" ]] || continue
      codesign -f -s "$identity" --generate-entitlement-der --timestamp=none "$component"
    done < <(find "$app_path/Frameworks" -depth \( -name "*.framework" -o -name "*.dylib" \) | LC_ALL=C sort)
  fi
}

# Apple's WWDR intermediates + root. Without these in the signing keychain,
# codesign can't build the chain and fails with errSecInternalComponent /
# "0 valid identities found". Best-effort: CI runners often already have them.
download_apple_intermediates() {
  mkdir -p "$APPLE_CERTS_DIR"
  local ca="https://www.apple.com/certificateauthority"
  local u
  for u in \
    "$ca/AppleWWDRCAG2.cer" "$ca/AppleWWDRCAG3.cer" "$ca/AppleWWDRCAG4.cer" \
    "$ca/AppleWWDRCAG5.cer" "$ca/AppleWWDRCAG6.cer" \
    "https://developer.apple.com/certificationauthority/AppleWWDRCA.cer" \
    "$ca/AppleRootCA-G3.cer" \
    "https://www.apple.com/appleca/AppleIncRootCertificate.cer"; do
    curl -fsSL "$u" -o "$APPLE_CERTS_DIR/$(basename "$u")" 2>/dev/null || true
  done
  return 0
}

# Convert the downloaded Apple CA .cer files (DER) to PEM and assemble a single
# CA bundle. Used by the OCSP revocation check to (a) match each leaf's issuer
# and (b) verify the OCSP responder's signature ("Response verify OK").
prepare_ocsp_truststore() {
  local c pem
  : > "$OCSP_CA_BUNDLE"
  shopt -s nullglob
  for c in "$APPLE_CERTS_DIR"/*.cer; do
    pem="${c%.cer}.pem"
    if openssl x509 -inform DER -in "$c" -out "$pem" 2>/dev/null \
       || openssl x509 -inform PEM -in "$c" -out "$pem" 2>/dev/null; then
      cat "$pem" >> "$OCSP_CA_BUNDLE"
    fi
  done
  shopt -u nullglob
}

# OCSP revocation status of a signing certificate -> prints "revoked", "valid",
# or "unknown". Asks the cert's own OCSP responder (from its AIA extension),
# using the matching Apple WWDR intermediate as issuer. Any failure — no
# network, missing issuer, unreadable cert — degrades to "unknown" so it can
# never block signing. Works on both OpenSSL 3.x and the macOS LibreSSL.
certificate_revocation_status() {
  local p12_file="$1" password="$2"
  command -v openssl >/dev/null 2>&1 || { echo "unknown"; return 0; }
  local leaf="$TMP_DIR/ocsp-leaf-$(basename "$p12_file" .p12).pem"
  openssl pkcs12 $OPENSSL_LEGACY_FLAG -in "$p12_file" -passin "pass:$password" \
    -nokeys -clcerts -out "$leaf" >/dev/null 2>&1 || { echo "unknown"; return 0; }
  [[ -s "$leaf" ]] || { echo "unknown"; return 0; }

  local uri issuer_dn
  uri="$(openssl x509 -in "$leaf" -noout -ocsp_uri 2>/dev/null)"
  # Fallback for openssl builds without -ocsp_uri: read the AIA extension text.
  [[ -n "$uri" ]] || uri="$(openssl x509 -in "$leaf" -noout -text 2>/dev/null \
    | sed -n 's/.*OCSP - URI:\(.*\)/\1/p' | head -n1)"
  [[ -n "$uri" ]] || { echo "unknown"; return 0; }

  issuer_dn="$(openssl x509 -in "$leaf" -noout -issuer -nameopt RFC2253 2>/dev/null | sed 's/^issuer=//')"
  local cand subj issuer_pem=""
  shopt -s nullglob
  for cand in "$APPLE_CERTS_DIR"/*.pem; do
    subj="$(openssl x509 -in "$cand" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject=//')"
    [[ "$subj" == "$issuer_dn" ]] && { issuer_pem="$cand"; break; }
  done
  shopt -u nullglob
  [[ -n "$issuer_pem" ]] || { echo "unknown"; return 0; }

  # Always pass a non-empty verify option (avoids set -u empty-array issues on
  # bash 3.2): a CA bundle when we have one, else skip responder verification.
  local -a verify_opt
  if [[ -s "$OCSP_CA_BUNDLE" ]]; then verify_opt=(-CAfile "$OCSP_CA_BUNDLE"); else verify_opt=(-no_cert_verify); fi

  local out status_line attempt
  for attempt in 1 2 3; do
    out="$(openssl ocsp -issuer "$issuer_pem" -cert "$leaf" -url "$uri" \
      "${verify_opt[@]}" -no_nonce -timeout 25 2>/dev/null)"
    status_line="$(printf '%s\n' "$out" | sed -n "s#^$leaf: ##p" | head -n1)"
    case "$status_line" in
      good)    echo "valid";   return 0 ;;
      revoked) echo "revoked"; return 0 ;;
      unknown) echo "unknown"; return 0 ;;
    esac
    sleep 2
  done
  echo "unknown"
}

# Import Apple intermediates ONCE into a dedicated keychain that stays in the
# search list for the whole run. Importing them into each per-cert keychain
# fails after the first cert — macOS dedups identical certs and silently no-ops,
# so only the first leaf can build its chain.
setup_intermediates_keychain() {
  security create-keychain -p "$KC_PASSWORD" "$INTERMEDIATES_KC" >/dev/null 2>&1 || return 0
  security set-keychain-settings -lut 7200 "$INTERMEDIATES_KC" >/dev/null 2>&1 || true
  security unlock-keychain -p "$KC_PASSWORD" "$INTERMEDIATES_KC" >/dev/null 2>&1 || true
  local c
  shopt -s nullglob
  for c in "$APPLE_CERTS_DIR"/*.cer; do
    security import "$c" -k "$INTERMEDIATES_KC" -A >/dev/null 2>&1 || true
  done
  shopt -u nullglob
  return 0
}

# ----- preflight ------------------------------------------------------------
while IFS= read -r existing_keychain; do
  # `security list-keychains` prints each path indented and quoted:  "/path/x.keychain-db"
  existing_keychain="$(printf '%s' "$existing_keychain" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
  [[ -n "$existing_keychain" ]] || continue
  ORIGINAL_KEYCHAINS+=("$existing_keychain")
done < <(security list-keychains -d user 2>/dev/null || true)

OPENSSL_PKCS12_HELP="$(openssl pkcs12 -help 2>&1 || true)"
if [[ "$OPENSSL_PKCS12_HELP" == *"-legacy"* ]]; then OPENSSL_LEGACY_FLAG="-legacy"; fi

mkdir -p "$OUTPUT_DIR"
clean_generated_artifacts "$OUTPUT_PREFIX-*.ipa"
printf 'name\tcertificate_expires_at\tdays_left\trevoked\n' > "$CERT_METADATA_FILE"
if [[ -n "$CERT_NAME_LIST_FILE" ]]; then : > "$CERT_NAME_LIST_FILE"; fi

CERT_ZIP_URL="$(resolve_cert_zip_url)"
if ! UNSIGNED_IPA_RESOLVED_URL="$(resolve_unsigned_ipa_url)"; then
  fail "No unsigned IPA URL. Set the first line of $IPA_URL_FILE, or pass UNSIGNED_IPA_URL."
  exit 1
fi

echo "[*] Root dir: $ROOT_DIR"
echo "[*] Output dir: $OUTPUT_DIR"
echo "[*] Unsigned IPA URL: $UNSIGNED_IPA_RESOLVED_URL"
echo "[*] Certificate zip: $CERT_ZIP_URL"
echo "[*] Expected cert layout: <Name>/<Name>.p12 + <Name>/<Name>.mobileprovision"

curl -fsSL "$CERT_ZIP_URL" -o "$CERT_ARCHIVE"
if ! curl -fSL "$UNSIGNED_IPA_RESOLVED_URL" -o "$UNSIGNED_IPA"; then
  fail "Could not download the unsigned IPA from: $UNSIGNED_IPA_RESOLVED_URL"
  exit 1
fi
# Guard against the URL serving an HTML error page instead of a real IPA.
if ! unzip -tq "$UNSIGNED_IPA" >/dev/null 2>&1; then
  fail "Downloaded file is not a valid IPA (zip). Check the URL in $IPA_URL_FILE."
  exit 1
fi

record_app_info "$UNSIGNED_IPA" || warn "Could not read app info from the unsigned IPA"
echo "[*] Fetching Apple WWDR intermediates"
download_apple_intermediates
setup_intermediates_keychain
prepare_ocsp_truststore
unzip -q "$CERT_ARCHIVE" -d "$TMP_DIR"

SUCCESS=0
FAILED=0
FOUND_P12=0

while IFS= read -r P12_FILE; do
  [[ -n "$P12_FILE" ]] || continue
  FOUND_P12=1

  CERT_PATH="$(dirname "$P12_FILE")"
  RAW_NAME="$(basename "$P12_FILE" .p12)"
  CERT_GROUP_NAME="$(basename "$CERT_PATH")"
  OUTPUT_NAME="$(safe_name "$CERT_GROUP_NAME")"
  PROFILE="$CERT_PATH/$RAW_NAME.mobileprovision"

  if [[ "$RAW_NAME" != "$CERT_GROUP_NAME" ]]; then
    warn "Certificate filename $RAW_NAME.p12 does not match directory $CERT_GROUP_NAME; using directory name for output"
  fi

  if [[ ! -f "$PROFILE" && -f "$CERT_PATH/$CERT_GROUP_NAME.mobileprovision" ]]; then
    PROFILE="$CERT_PATH/$CERT_GROUP_NAME.mobileprovision"
  fi
  if [[ ! -f "$PROFILE" ]]; then
    PROFILE="$(find "$CERT_PATH" -maxdepth 1 -type f -name '*.mobileprovision' | LC_ALL=C sort)"
    PROFILE="${PROFILE%%$'\n'*}"
  fi
  if [[ -z "${PROFILE:-}" || ! -f "$PROFILE" ]]; then
    warn "Skipping $RAW_NAME because no matching provisioning profile was found"
    FAILED=$((FAILED + 1)); continue
  fi

  P12_PASSWORD_FOR_CERT="$(resolve_p12_password "$CERT_PATH" "$RAW_NAME")"
  CERT_EXPIRES_AT="unknown"; CERT_DAYS_LEFT="unknown"
  if CERT_EXPIRY_INFO="$(certificate_expiry_info "$P12_FILE" "$P12_PASSWORD_FOR_CERT")"; then
    IFS=$'\t' read -r CERT_EXPIRES_AT CERT_DAYS_LEFT <<< "$CERT_EXPIRY_INFO"
  else
    warn "Unable to read certificate expiry for $CERT_GROUP_NAME"
  fi
  CERT_REVOCATION="$(certificate_revocation_status "$P12_FILE" "$P12_PASSWORD_FOR_CERT")"

  echo
  echo "=============================================="
  echo "[*] CERTIFICATE: $CERT_GROUP_NAME"
  echo "=============================================="

  PROFILE_PLIST="$TMP_DIR/$OUTPUT_NAME-profile.plist"
  if ! security cms -D -i "$PROFILE" > "$PROFILE_PLIST"; then
    fail "Unable to decode provisioning profile"; FAILED=$((FAILED + 1)); continue
  fi

  TEAM_ID=$(/usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" "$PROFILE_PLIST" 2>/dev/null || echo "")
  PROFILE_APP_ID=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$PROFILE_PLIST" 2>/dev/null || echo "")
  EXPIRY=$(/usr/libexec/PlistBuddy -c "Print :ExpirationDate" "$PROFILE_PLIST" 2>/dev/null || echo "unknown")
  PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" "$PROFILE_PLIST" 2>/dev/null || echo "$RAW_NAME")

  log "Profile name: $PROFILE_NAME"
  log "Team ID: ${TEAM_ID:-unknown}"
  log "Profile App ID: ${PROFILE_APP_ID:-unknown}"
  log "Profile Expiry: $EXPIRY"
  log "Certificate Expiry: $CERT_EXPIRES_AT ($CERT_DAYS_LEFT days left)"
  log "Certificate Revocation: $CERT_REVOCATION"

  if [[ -z "$TEAM_ID" || -z "$PROFILE_APP_ID" ]]; then
    fail "Provisioning profile is missing TeamIdentifier or application-identifier"
    FAILED=$((FAILED + 1)); continue
  fi

  KEYCHAIN="$TMP_DIR/$OUTPUT_NAME.keychain-db"
  IPA_WORK="$TMP_DIR/ipa-$OUTPUT_NAME"
  ENTITLEMENTS="$TMP_DIR/$OUTPUT_NAME-entitlements.plist"
  rm -rf "$IPA_WORK"; mkdir -p "$IPA_WORK"

  if ! security create-keychain -p "$KC_PASSWORD" "$KEYCHAIN" >/dev/null 2>&1; then
    fail "Keychain creation failed"; FAILED=$((FAILED + 1)); continue
  fi
  security set-keychain-settings -lut 7200 "$KEYCHAIN" >/dev/null 2>&1 || true
  security unlock-keychain -p "$KC_PASSWORD" "$KEYCHAIN" >/dev/null 2>&1
  if [[ ${#ORIGINAL_KEYCHAINS[@]} -gt 0 ]]; then
    security list-keychains -d user -s "$KEYCHAIN" "$INTERMEDIATES_KC" "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1
  else
    security list-keychains -d user -s "$KEYCHAIN" "$INTERMEDIATES_KC" >/dev/null 2>&1
  fi

  log "Importing certificate"
  if ! import_certificate "$P12_FILE" "$KEYCHAIN" "$P12_PASSWORD_FOR_CERT"; then
    fail "Certificate import failed"
    restore_keychains; security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    FAILED=$((FAILED + 1)); continue
  fi

  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASSWORD" "$KEYCHAIN" >/dev/null 2>&1 || true

  IDENTITY="$(security find-identity -p codesigning -v "$KEYCHAIN" | sed -n 's/.*"\([^"]*\)".*/\1/p')"
  IDENTITY="${IDENTITY%%$'\n'*}"
  if [[ -z "$IDENTITY" ]]; then
    # Fall back to all identities (chain may not validate locally, but the
    # private key is present and that is all codesign needs).
    IDENTITY="$(security find-identity -p codesigning "$KEYCHAIN" | sed -n 's/.*"\([^"]*\)".*/\1/p')"
    IDENTITY="${IDENTITY%%$'\n'*}"
  fi
  if [[ -z "$IDENTITY" ]]; then
    fail "No signing identity found"
    restore_keychains; security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    FAILED=$((FAILED + 1)); continue
  fi
  log "Using identity: $IDENTITY"

  if ! unzip -q "$UNSIGNED_IPA" -d "$IPA_WORK"; then
    fail "IPA unzip failed"
    restore_keychains; security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    FAILED=$((FAILED + 1)); continue
  fi

  APP_PATH="$(find "$IPA_WORK/Payload" -maxdepth 1 -name '*.app' | LC_ALL=C sort)"
  APP_PATH="${APP_PATH%%$'\n'*}"
  if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
    fail "No .app bundle found in IPA"
    restore_keychains; security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    FAILED=$((FAILED + 1)); continue
  fi

  INFO_PLIST="$APP_PATH/Info.plist"
  ORIGINAL_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || echo "")
  if [[ -z "$ORIGINAL_BUNDLE_ID" ]]; then
    fail "Missing CFBundleIdentifier in app Info.plist"
    restore_keychains; security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    FAILED=$((FAILED + 1)); continue
  fi

  TARGET_BUNDLE_ID="$(derive_bundle_id "$TEAM_ID" "$PROFILE_APP_ID" "$ORIGINAL_BUNDLE_ID")"
  if [[ -n "$FORCED_BUNDLE_ID" && "$PROFILE_APP_ID" != "$TEAM_ID.*" && "$FORCED_BUNDLE_ID" != "$TARGET_BUNDLE_ID" ]]; then
    warn "Ignoring FORCED_BUNDLE_ID for $RAW_NAME because the provisioning profile is explicit"
  fi
  log "Bundle ID before: $ORIGINAL_BUNDLE_ID"
  log "Bundle ID after: $TARGET_BUNDLE_ID"

  set_plist_string "$INFO_PLIST" ":CFBundleIdentifier" "$TARGET_BUNDLE_ID"
  cp "$PROFILE" "$APP_PATH/embedded.mobileprovision"
  rm -rf "$APP_PATH/_CodeSignature"

  if ! prepare_entitlements "$PROFILE_PLIST" "$ENTITLEMENTS" "$TEAM_ID" "$TARGET_BUNDLE_ID"; then
    fail "Unable to prepare entitlements"
    restore_keychains; security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    FAILED=$((FAILED + 1)); continue
  fi

  sign_embedded_code "$APP_PATH" "$IDENTITY"

  if ! codesign -f -s "$IDENTITY" --generate-entitlement-der --timestamp=none --entitlements "$ENTITLEMENTS" "$APP_PATH"; then
    fail "codesign failed"
    restore_keychains; security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    FAILED=$((FAILED + 1)); continue
  fi
  if ! codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
    fail "codesign verification failed"
    restore_keychains; security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    FAILED=$((FAILED + 1)); continue
  fi

  pushd "$IPA_WORK" >/dev/null
  zip -qry "$OUTPUT_DIR/$OUTPUT_PREFIX-$OUTPUT_NAME.ipa" Payload
  popd >/dev/null

  log "Signed IPA created: $OUTPUT_PREFIX-$OUTPUT_NAME.ipa"
  printf '%s\t%s\t%s\t%s\n' "$OUTPUT_NAME" "$CERT_EXPIRES_AT" "$CERT_DAYS_LEFT" "$CERT_REVOCATION" >> "$CERT_METADATA_FILE"
  if [[ -n "$CERT_NAME_LIST_FILE" ]]; then printf '%s\n' "$OUTPUT_NAME" >> "$CERT_NAME_LIST_FILE"; fi

  restore_keychains
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  SUCCESS=$((SUCCESS + 1))
done < <(find "$TMP_DIR" -type f -name '*.p12' | LC_ALL=C sort)

if [[ $FOUND_P12 -eq 0 ]]; then
  fail "No .p12 files were found in the certificate archive"; exit 1
fi

echo
echo "[✓] Done"
echo "[✓] Successful: $SUCCESS"
echo "[!] Failed: $FAILED"

if [[ $SUCCESS -eq 0 ]]; then
  fail "No signed IPAs were created"; exit 1
fi
