#!/bin/bash
# Sign one unsigned IPA with every certificate in the cert pool.
#
# Config, all overridable by env:
#   UNSIGNED_IPA_URL  the IPA to sign; falls back to ipa-url.txt, then the
#                     latest release's .ipa asset
#   RELEASE_REPO      owner/repo to pull that release from
#   CERT_ZIP_URL      pool sources, each a .zip URL, a GitHub repo URL or a
#                     local folder path (relative paths resolve against the repo
#                     root, e.g. "certs"); falls back to cert-url.txt
#   OUTPUT_DIR        where signed IPAs and metadata land (default: ./output)
#   OUTPUT_PREFIX     filename prefix for signed IPAs (default: sideinstaller)
#   P12_PASSWORD      fallback p12 password when no sidecar file exists
#   FORCED_BUNDLE_ID  override bundle id for wildcard profiles
#   SIGN_STATE_FILE   also record the resolved IPA URL and one line per unique
#                     certificate (name, leaf SHA-1, expiry date) here
#   PRECHECK_ONLY     1 = assemble the pool, write SIGN_STATE_FILE and stop —
#                     no IPA download, no keychains, no signing. Used by
#                     check_for_changes.sh to decide whether a run is needed.
#
# Pool layout, one folder per cert per source:
#   <Name>/<Name>.p12  +  <Name>/<Name>.mobileprovision  [+ <Name>/password.txt]
# Sources merge into one pool, keyed by the leaf certificate's SHA-1 so each is
# signed once, with the first source listed winning.
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-sideinstaller}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
CERT_URL_FILE="${CERT_URL_FILE:-$ROOT_DIR/cert-url.txt}"
IPA_URL_FILE="${IPA_URL_FILE:-$ROOT_DIR/ipa-url.txt}"
CERT_METADATA_FILE="${CERT_METADATA_FILE:-$OUTPUT_DIR/certificate-validity.tsv}"
APP_INFO_FILE="${APP_INFO_FILE:-$OUTPUT_DIR/app-info.tsv}"
CERT_NAME_LIST_FILE="${CERT_NAME_LIST_FILE:-}"

# Fallback sources, one per line, kept in sync with cert-url.txt.
DEFAULT_CERT_SOURCES="certs
https://github.com/WSF-Team/WSF/raw/refs/heads/main/portal/resources/certificates.zip
https://sideloading.net"

DEFAULT_P12_PASSWORD="${P12_PASSWORD:-WSF}"
KC_PASSWORD="${KC_PASSWORD:-temp123}"
FORCED_BUNDLE_ID="${FORCED_BUNDLE_ID:-}"
SIGN_STATE_FILE="${SIGN_STATE_FILE:-}"
PRECHECK_ONLY="${PRECHECK_ONLY:-0}"

# NexCerts is no longer cloned as a Git repo — it exposes a REST API
# (https://sideloading.net) that lists certificates and serves each one's p12,
# provisioning profile and password by id. Any source URL pointing at this host
# (or the legacy github.com/NovaDev404/NexCerts repo, kept as an alias) is routed
# through the API instead of a clone/zip download; see fetch_nexcerts_certs.
#   NEXCERTS_API_BASE  API origin (default https://sideloading.net)
#   NEXCERTS_STATUS    which list to pull: all | signed | revoked | missingP12
#                      (default all; 'signed' drops Apple-revoked certificates)
NEXCERTS_HOST="${NEXCERTS_HOST:-sideloading.net}"
NEXCERTS_API_BASE="${NEXCERTS_API_BASE:-https://$NEXCERTS_HOST}"
NEXCERTS_STATUS="${NEXCERTS_STATUS:-all}"

TMP_DIR="$(mktemp -d)"
POOL_DIR="$TMP_DIR/pool"                 # merged cert pool, one subdir per source
SEEN_FP_FILE="$TMP_DIR/seen-fingerprints.tsv"  # fingerprint<TAB>kept-name, for dedup
UNSIGNED_IPA="$TMP_DIR/unsigned.ipa"
APPLE_CERTS_DIR="$TMP_DIR/apple-certs"
INTERMEDIATES_KC="$TMP_DIR/intermediates.keychain-db"

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

# Every non-blank, non-comment line of a file, CR-stripped and trimmed.
all_config_lines() {
  awk '
    {
      sub(/\r$/, "")
      sub(/^[[:space:]]+/, "")
      if ($0 ~ /^#/ || $0 !~ /[^[:space:]]/) next
      sub(/[[:space:]]+$/, "")
      print
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

# The pool sources, one per line: CERT_ZIP_URL, else cert-url.txt, else the
# built-in list.
resolve_cert_sources() {
  if [[ -n "${CERT_ZIP_URL:-}" ]]; then
    # Word-split so one URL or many both normalise to one per line.
    printf '%s\n' $CERT_ZIP_URL
    return 0
  fi
  if [[ -f "$CERT_URL_FILE" ]]; then
    local lines; lines="$(all_config_lines "$CERT_URL_FILE")"
    [[ -n "$lines" ]] && { printf '%s\n' "$lines"; return 0; }
  fi
  printf '%s\n' "$DEFAULT_CERT_SOURCES"
}

# True when $1 names a folder rather than a remote URL — the repo's own certs/
# drop-in folder, or any other path. Checked before the URL kinds below.
is_local_source() {   # $1 = source
  case "${1%/}" in
    "" | http://* | https://* | git@* | *://*) return 1 ;;
    *) return 0 ;;
  esac
}

# Absolute path a local source points at; relative paths resolve against the
# repo root so cert-url.txt can just say "certs".
local_source_path() {   # $1 = source
  local src="${1%/}"
  [[ "$src" = /* ]] || src="$ROOT_DIR/${src#./}"
  echo "$src"
}

# Copy a local cert folder's contents into the pool. Everything is copied as-is;
# the walk below only ever looks for .p12 files, so notes and placeholders that
# live alongside them are inert.
copy_local_certs() {   # $1 src-dir  $2 dest-dir
  # The /. copies the folder's *contents*, so each per-cert subfolder lands
  # directly under $2 exactly like a zip or a clone would leave it.
  cp -R "$1/." "$2/" || return 1
}

# True when $1 is a GitHub repo root, which is sparse-cloned rather than
# downloaded as an archive.
is_github_repo_url() {
  local u="${1%/}"; u="${u%.git}"
  case "$u" in
    *.zip) return 1 ;;
    https://github.com/*/* | http://github.com/*/* | git@github.com:*/*)
      local rest="${u#*github.com[:/]}"       # owner/repo[/more…]
      case "$rest" in
        */*/*) return 1 ;;                     # 3+ segments => path into repo
        */*)   return 0 ;;                     # exactly owner/repo => root
        *)     return 1 ;;
      esac ;;
    *) return 1 ;;
  esac
}

# Sparse clone checking out only the cert material, so bundled assets such as
# .ipa files are never fetched.
clone_repo_certs() {   # $1 repo-url  $2 dest-dir
  local url="${1%/}"; url="${url%.git}"
  git clone --no-checkout --depth 1 --filter=blob:none "$url" "$2" >/dev/null 2>&1 || return 1
  (
    cd "$2" || exit 1
    git sparse-checkout init --no-cone >/dev/null 2>&1 || exit 1
    git sparse-checkout set --no-cone '*.p12' '*.mobileprovision' 'password.txt' '*.password' '*.pass' >/dev/null 2>&1 || exit 1
    git checkout >/dev/null 2>&1 || exit 1
  ) || return 1
  rm -rf "$2/.git"
}

fetch_zip_certs() {   # $1 url  $2 dest-dir
  local archive="$TMP_DIR/src-$(basename "$2").zip"
  curl -fsSL "$1" -o "$archive" || return 1
  unzip -q "$archive" -d "$2" || return 1
  rm -f "$archive"
}

# Echo the API base for a NexCerts source, non-zero for anything else. Matches
# the API host directly (any scheme/path) and the legacy NovaDev404/NexCerts
# GitHub URL, which is now served through the API rather than cloned.
nexcerts_api_base() {   # $1 = source url
  local u="${1%/}"; u="${u%.git}"
  case "$u" in
    *github.com/NovaDev404/NexCerts | *github.com/NovaDev404/NexCerts/*)
      echo "$NEXCERTS_API_BASE"; return 0 ;;
  esac
  case "$u" in
    http://* | https://*)
      # Separate declarations: a single `local a=.. b="${a..}"` would evaluate b
      # before a is committed, yielding an empty host under `set -u`.
      local scheme="${u%%://*}"
      local rest="${u#*://}"
      local host="${rest%%/*}"
      if [[ "$host" == "$NEXCERTS_HOST" || "$host" == *."$NEXCERTS_HOST" ]]; then
        echo "$scheme://$host"; return 0
      fi ;;
  esac
  return 1
}

# Fetch NexCerts through its REST API instead of cloning the repo. The list
# endpoint enumerates certificates; the per-id download endpoints return each
# cert's p12, provisioning profile and password. Files land in the same layout
# as every other source (<Name>/<Name>.p12 + .mobileprovision [+ password.txt]),
# so the signing loop treats the merged pool uniformly. $NEXCERTS_STATUS selects
# the list (all | signed | revoked | missingP12); each folder is named after the
# certificate exactly as the repo folder was, keeping output filenames stable.
fetch_nexcerts_certs() {   # $1 = api base  $2 = dest dir
  local base="${1%/}" dest="$2" status="${NEXCERTS_STATUS:-all}"
  local list_json="$TMP_DIR/nexcerts-$(basename "$dest").json"

  command -v python3 >/dev/null 2>&1 || { warn "python3 is required to read the NexCerts API"; return 1; }
  if ! curl -fsSL "$base/api/certificates/list/$status" -o "$list_json"; then
    warn "NexCerts API list request failed: $base/api/certificates/list/$status"
    return 1
  fi

  # One "id<TAB>name" line per certificate. folder_name is what the clone would
  # have produced on disk; fall back to name. Control characters and path
  # separators are neutralised so the value is a safe single path component.
  local roster
  if ! roster="$(python3 - "$list_json" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as fh:
        data = json.load(fh)
except Exception:
    sys.exit(1)
if not isinstance(data, list):
    sys.exit(1)
for entry in data:
    if not isinstance(entry, dict):
        continue
    cid = entry.get("id")
    name = entry.get("folder_name") or entry.get("name")
    if cid is None or not name:
        continue
    name = "".join((" " if ord(c) < 32 else c) for c in str(name))
    name = name.replace("/", "-").replace("\\", "-").strip()
    if name:
        print(f"{cid}\t{name}")
PY
)"; then
    warn "Could not parse the NexCerts API response from $base"
    return 1
  fi

  if [[ -z "$roster" ]]; then
    warn "NexCerts API returned no certificates for status '$status'"
    return 0
  fi

  local count=0 id name cert_dir pw
  while IFS=$'\t' read -r id name; do
    [[ -n "$id" && -n "$name" ]] || continue

    # Repo folder names are unique; guard the rare API duplicate so one cert
    # never clobbers another's files.
    cert_dir="$dest/$name"
    if [[ -e "$cert_dir" ]]; then name="$name ($id)"; cert_dir="$dest/$name"; fi
    mkdir -p "$cert_dir"

    if ! curl -fsSL "$base/api/certificates/download/$id/cert.p12" -o "$cert_dir/$name.p12"; then
      warn "NexCerts: could not download p12 for '$name' (id $id); skipping"
      rm -rf "$cert_dir"; continue
    fi
    if ! curl -fsSL "$base/api/certificates/download/$id/cert.mobileprovision" -o "$cert_dir/$name.mobileprovision"; then
      warn "NexCerts: could not download provisioning profile for '$name' (id $id); skipping"
      rm -rf "$cert_dir"; continue
    fi

    # Password is per-certificate ("NexCerts" today, not the WSF fallback), so
    # persist it as password.txt for resolve_p12_password. Optional: a missing
    # value just falls through to DEFAULT_P12_PASSWORD.
    if pw="$(curl -fsSL "$base/api/certificates/download/$id/password.txt" 2>/dev/null)" && [[ -n "$pw" ]]; then
      printf '%s\n' "$pw" > "$cert_dir/password.txt"
    fi

    count=$((count + 1))
  done <<< "$roster"

  echo "[*]   NexCerts API: fetched $count certificate(s) [status: $status]"
  [[ "$count" -gt 0 ]]
}

# Populate $POOL_DIR, each source in its own zero-padded subdir so the walk
# below visits them in list order and the first source wins a duplicate.
acquire_sources() {   # $1 = newline-separated source URLs
  local idx=0 url dest nex_base local_dir local_count
  mkdir -p "$POOL_DIR"
  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    dest="$POOL_DIR/$(printf '%02d' "$idx")-src"
    mkdir -p "$dest"
    if is_local_source "$url"; then
      local_dir="$(local_source_path "$url")"
      echo "[*] Source $idx (local folder): $local_dir"
      if [[ -d "$local_dir" ]]; then
        if copy_local_certs "$local_dir" "$dest"; then
          local_count="$(find "$dest" -type f -name '*.p12' | wc -l | tr -d ' ')"
          # An empty folder is the normal state until certificates are added to
          # it, so this is a note rather than a warning.
          echo "[*]   Local folder: found $local_count certificate(s)"
        else
          warn "Failed to read certificates from folder: $local_dir"
        fi
      else
        warn "Certificate folder does not exist, skipping: $local_dir"
      fi
    elif nex_base="$(nexcerts_api_base "$url")"; then
      echo "[*] Source $idx (NexCerts API @ $nex_base): $url"
      fetch_nexcerts_certs "$nex_base" "$dest" || warn "Failed to fetch certificates from the NexCerts API: $url"
    elif is_github_repo_url "$url"; then
      echo "[*] Source $idx (GitHub repo, cert files only): $url"
      clone_repo_certs "$url" "$dest" || warn "Failed to fetch certificates from repo: $url"
    else
      echo "[*] Source $idx (zip archive): $url"
      fetch_zip_certs "$url" "$dest" || warn "Failed to download/extract cert zip: $url"
    fi
    idx=$((idx + 1))
  done <<< "$1"
}

# Whether this fingerprint was signed already, printing the name it used.
dedup_lookup() {   # $1 = fingerprint
  [[ -f "$SEEN_FP_FILE" ]] || return 1
  awk -F'\t' -v fp="$1" '$1 == fp { print $2; found = 1; exit } END { exit(found ? 0 : 1) }' "$SEEN_FP_FILE"
}
dedup_record() { printf '%s\t%s\n' "$1" "$2" >> "$SEEN_FP_FILE"; }

# owner/repo for the Releases API: CI's slug, else the origin remote.
resolve_repo_slug() {
  if [[ -n "${RELEASE_REPO:-}" ]]; then echo "$RELEASE_REPO"; return 0; fi
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then echo "$GITHUB_REPOSITORY"; return 0; fi
  local url; url="$(git -C "$ROOT_DIR" config --get remote.origin.url 2>/dev/null || true)"
  url="${url%.git}"
  case "$url" in
    *github.com[:/]*) echo "${url#*github.com[:/]}"; return 0 ;;
  esac
  return 1
}

# Download URL of the newest .ipa on the latest release; include_pre=1 also
# considers prereleases.
resolve_release_ipa_url() {
  local repo="$1" include_pre="${2:-0}"
  local api="https://api.github.com/repos/$repo" endpoint json_file="$TMP_DIR/release.json"
  local auth=()
  [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

  if [[ "$include_pre" == "1" ]]; then
    endpoint="$api/releases?per_page=1"
  else
    endpoint="$api/releases/latest"
  fi

  # This expansion yields nothing when empty, rather than tripping `set -u`
  # on the runner's Bash 3.2.
  curl -fsSL ${auth[@]+"${auth[@]}"} -H "Accept: application/vnd.github+json" "$endpoint" -o "$json_file" 2>/dev/null || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$json_file" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
# /releases returns a list, /releases/latest a single object.
rel = (data[0] if data else None) if isinstance(data, list) else data
if not rel:
    raise SystemExit(1)
ipas = [a for a in rel.get("assets", []) if a.get("name", "").lower().endswith(".ipa")]
if not ipas:
    raise SystemExit(1)
print(ipas[0]["browser_download_url"])
PY
}

resolve_unsigned_ipa_url() {
  if [[ -n "${UNSIGNED_IPA_URL:-}" ]]; then
    echo "$UNSIGNED_IPA_URL"; return 0
  fi
  if [[ -f "$IPA_URL_FILE" ]]; then
    local u; u="$(first_config_line "$IPA_URL_FILE")"
    [[ -n "$u" ]] && { echo "$u"; return 0; }
  fi
  # Default to the latest release's .ipa; beta also considers prereleases.
  local repo include_pre=0
  [[ "${CHANNEL:-stable}" == "beta" ]] && include_pre=1
  if repo="$(resolve_repo_slug)"; then
    local url
    if url="$(resolve_release_ipa_url "$repo" "$include_pre")" && [[ -n "$url" ]]; then
      echo "$url"; return 0
    fi
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

# SHA-1 of the leaf certificate in a p12, the dedup key.
certificate_fingerprint() {
  local p12_file="$1" password="$2"
  local cert_pem="$TMP_DIR/fp-$(basename "$p12_file" .p12).pem" fp=""
  openssl pkcs12 $OPENSSL_LEGACY_FLAG -in "$p12_file" -passin "pass:$password" -nokeys -clcerts -out "$cert_pem" >/dev/null 2>&1 || return 1
  fp="$(openssl x509 -in "$cert_pem" -noout -fingerprint -sha1 2>/dev/null | sed 's/.*=//; s/://g')"
  rm -f "$cert_pem"
  [[ -n "$fp" ]] || return 1
  printf '%s\n' "$fp"
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

# Apple revokes leaked enterprise certificates constantly, and a revoked one
# still signs and still installs — it just refuses to launch. Expiry alone
# therefore says nothing about whether a build works, so ask Apple directly.
#
# The leaf carries both URLs we need in its Authority Information Access
# extension: the OCSP responder to query, and the CA Issuers URI for the
# intermediate that issued it (OCSP needs the issuer to compute the cert ID).
# Issuers are fetched once and cached, since a whole pool shares a handful.
OCSP_ISSUER_CACHE="$TMP_DIR/ocsp-issuers"

# Issuer PEM for a CA Issuers URI, downloaded on first use. DER is the norm at
# certs.apple.com; PEM is accepted too so a mirror can't break the check.
ocsp_issuer_pem() {
  local url="$1" key pem
  key="$(printf '%s' "$url" | shasum -a 256 | cut -c1-16)"
  pem="$OCSP_ISSUER_CACHE/$key.pem"
  if [[ ! -s "$pem" ]]; then
    mkdir -p "$OCSP_ISSUER_CACHE"
    curl -fsSL --max-time 20 "$url" -o "$pem.der" 2>/dev/null || return 1
    openssl x509 -inform DER -in "$pem.der" -out "$pem" 2>/dev/null \
      || openssl x509 -inform PEM -in "$pem.der" -out "$pem" 2>/dev/null \
      || { rm -f "$pem" "$pem.der"; return 1; }
    rm -f "$pem.der"
  fi
  printf '%s\n' "$pem"
}

# valid | revoked | unknown, for the leaf certificate in a p12. Anything that
# stops the query short — no AIA, no network, an unreadable response — is
# "unknown" rather than a guess in either direction: the page shows that as its
# own state, so an offline runner never advertises a dead cert as working, and
# never buries a live one either.
certificate_revocation_status() {
  local p12_file="$1" password="$2"
  local base="$TMP_DIR/ocsp-$(basename "$p12_file" .p12)"
  local cert_pem="$base.pem" txt ocsp_url ca_url issuer_pem out status="unknown"

  openssl pkcs12 $OPENSSL_LEGACY_FLAG -in "$p12_file" -passin "pass:$password" \
    -nokeys -clcerts -out "$cert_pem" >/dev/null 2>&1 || { printf 'unknown\n'; return 0; }

  txt="$(openssl x509 -in "$cert_pem" -noout -text 2>/dev/null || true)"
  ocsp_url="$(printf '%s' "$txt" | sed -n 's/.*OCSP - URI:\(.*\)/\1/p'       | head -n1 | tr -d ' \r')"
  ca_url="$(  printf '%s' "$txt" | sed -n 's/.*CA Issuers - URI:\(.*\)/\1/p' | head -n1 | tr -d ' \r')"

  if [[ -n "$ocsp_url" && -n "$ca_url" ]] && issuer_pem="$(ocsp_issuer_pem "$ca_url")"; then
    # -noverify skips the response signature check. The responder is reached
    # over plain HTTP (OCSP always is), so this trusts the transport; a lying
    # MITM could only mislabel a card on the page, never affect what gets
    # signed. Kept off because verifying needs a trust chain this script does
    # not otherwise assemble.
    #
    # The `|| true` matters: openssl ocsp exits non-zero on an unreachable
    # responder, and this script runs under set -e, so without it a network
    # blip would abort signing instead of recording "unknown" and moving on.
    out="$(openssl ocsp -issuer "$issuer_pem" -cert "$cert_pem" -url "$ocsp_url" \
             -no_nonce -noverify -timeout 20 2>&1 || true)"
    case "$out" in
      *": good"*)    status="valid"   ;;
      *": revoked"*) status="revoked" ;;
    esac
  fi

  rm -f "$cert_pem"
  printf '%s\n' "$status"
}

# Read display name and version from the unsigned IPA, for the page's hero.
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

# Apple's WWDR intermediates and root; without them codesign can't build the
# chain and reports "0 valid identities found".
download_apple_intermediates() {
  mkdir -p "$APPLE_CERTS_DIR"
  local ca="https://www.apple.com/certificateauthority"
  local u
  for u in \
    "$ca/AppleWWDRCAG2.cer" "$ca/AppleWWDRCAG3.cer" "$ca/AppleWWDRCAG4.cer" \
    "$ca/AppleWWDRCAG5.cer" "$ca/AppleWWDRCAG6.cer" \
    "https://developer.apple.com/certificationauthority/AppleWWDRCA.cer" \
    "https://www.apple.com/appleca/AppleIncRootCertificate.cer"; do
    curl -fsSL "$u" -o "$APPLE_CERTS_DIR/$(basename "$u")" 2>/dev/null || true
  done
  return 0
}

# Import the intermediates once, into a keychain that stays in the search list:
# macOS silently no-ops a duplicate import, so per-cert keychains would leave
# every leaf after the first unable to build its chain.
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
  # `security list-keychains` prints each path indented and quoted.
  existing_keychain="$(printf '%s' "$existing_keychain" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
  [[ -n "$existing_keychain" ]] || continue
  ORIGINAL_KEYCHAINS+=("$existing_keychain")
done < <(security list-keychains -d user 2>/dev/null || true)

OPENSSL_PKCS12_HELP="$(openssl pkcs12 -help 2>&1 || true)"
if [[ "$OPENSSL_PKCS12_HELP" == *"-legacy"* ]]; then OPENSSL_LEGACY_FLAG="-legacy"; fi

mkdir -p "$OUTPUT_DIR"
# Absolute, since zip writes relative to the cwd and the loop below pushd's.
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
# Never wipe sideinstaller-*.ipa here: each cert rewrites only its own file
# below, so builds from certs outside this pool survive.
# A precheck must leave the committed output untouched, so it writes neither of
# these — it only produces SIGN_STATE_FILE.
if [[ "$PRECHECK_ONLY" != "1" ]]; then
  printf 'name\tcertificate_expires_at\tdays_left\trevocation\n' > "$CERT_METADATA_FILE"
  if [[ -n "$CERT_NAME_LIST_FILE" ]]; then : > "$CERT_NAME_LIST_FILE"; fi
fi
if [[ -n "$SIGN_STATE_FILE" ]]; then : > "$SIGN_STATE_FILE"; fi

CERT_SOURCES="$(resolve_cert_sources)"
if ! UNSIGNED_IPA_RESOLVED_URL="$(resolve_unsigned_ipa_url)"; then
  fail "No unsigned IPA URL: the repo's latest release has no .ipa asset (and no override was given). Attach an IPA to the release, set the first line of $IPA_URL_FILE, or pass UNSIGNED_IPA_URL."
  exit 1
fi

echo "[*] Root dir: $ROOT_DIR"
echo "[*] Output dir: $OUTPUT_DIR"
echo "[*] Unsigned IPA URL: $UNSIGNED_IPA_RESOLVED_URL"
echo "[*] Certificate sources (merged, de-duplicated by certificate fingerprint):"
while IFS= read -r _src; do
  [[ -n "$_src" ]] || continue
  echo "      - $_src"
done <<< "$CERT_SOURCES"
echo "[*] Expected cert layout per source: <Name>/<Name>.p12 + <Name>/<Name>.mobileprovision [+ password]"

if [[ -n "$SIGN_STATE_FILE" ]]; then
  printf 'ipa\t%s\n' "$UNSIGNED_IPA_RESOLVED_URL" >> "$SIGN_STATE_FILE"
fi

# A precheck stops before all of this: it needs the certificate pool and nothing
# else, so it skips the IPA download, the WWDR intermediates and the keychains.
if [[ "$PRECHECK_ONLY" == "1" ]]; then
  echo "[*] Precheck mode: inspecting the certificate pool only"
else
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
fi
echo "[*] Assembling certificate pool"
acquire_sources "$CERT_SOURCES"

SUCCESS=0
FAILED=0
FOUND_P12=0
SKIPPED_DUP=0
: > "$SEEN_FP_FILE"

# Enumerate p12s across the pool. The zero-padded subdirs make this sorted walk
# follow list order, so the first source keeps a cert that recurs later.
while IFS= read -r P12_FILE; do
  [[ -n "$P12_FILE" ]] || continue
  FOUND_P12=1

  CERT_PATH="$(dirname "$P12_FILE")"
  RAW_NAME="$(basename "$P12_FILE" .p12)"
  CERT_GROUP_NAME="$(basename "$CERT_PATH")"
  # A p12 sitting loose at a source's root has no folder to take its name from,
  # so fall back to the file's own name instead of the pool's internal NN-src.
  if [[ "$(dirname "$CERT_PATH")" == "$POOL_DIR" ]]; then
    CERT_GROUP_NAME="$RAW_NAME"
  fi
  OUTPUT_NAME="$(safe_name "$CERT_GROUP_NAME")"
  PROFILE="$CERT_PATH/$RAW_NAME.mobileprovision"

  # Clear only this cert's own IPA, which drops its stale build if signing
  # fails and lets the zip below start from a clean archive.
  if [[ "$PRECHECK_ONLY" != "1" ]]; then
    rm -f "$OUTPUT_DIR/$OUTPUT_PREFIX-$OUTPUT_NAME.ipa"
  fi

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

  # Sign each unique certificate once, keyed on the leaf's SHA-1, since one
  # cert routinely appears across sources and profile variants. The first
  # occurrence wins and keeps its filename. A cert that can't be
  # fingerprinted is signed anyway rather than dropped.
  CERT_FP="$(certificate_fingerprint "$P12_FILE" "$P12_PASSWORD_FOR_CERT" || true)"
  if [[ -n "$CERT_FP" ]]; then
    if PRIOR="$(dedup_lookup "$CERT_FP")"; then
      warn "Skipping $CERT_GROUP_NAME — duplicate certificate (already signed as $PRIOR)"
      SKIPPED_DUP=$((SKIPPED_DUP + 1)); continue
    fi
    dedup_record "$CERT_FP" "$OUTPUT_NAME"
  else
    warn "Could not fingerprint $CERT_GROUP_NAME; signing without a duplicate check"
  fi

  CERT_EXPIRES_AT="unknown"; CERT_DAYS_LEFT="unknown"
  if CERT_EXPIRY_INFO="$(certificate_expiry_info "$P12_FILE" "$P12_PASSWORD_FOR_CERT")"; then
    IFS=$'\t' read -r CERT_EXPIRES_AT CERT_DAYS_LEFT <<< "$CERT_EXPIRY_INFO"
  else
    warn "Unable to read certificate expiry for $CERT_GROUP_NAME"
  fi

  CERT_REVOCATION="$(certificate_revocation_status "$P12_FILE" "$P12_PASSWORD_FOR_CERT")"
  if [[ "$CERT_REVOCATION" == "unknown" ]]; then
    warn "Could not check revocation for $CERT_GROUP_NAME"
  fi

  # Everything the install page needs to know about this certificate is settled
  # by now — name, identity, expiry and revocation — so a precheck can stop
  # here, before the expensive part. Certificates that fail later (bad profile,
  # codesign error) are recorded too: the next precheck reaches this same point
  # and produces the same line, so a permanently-broken certificate never forces
  # a pointless run.
  #
  # Revocation is part of the state on purpose. Expiry decays predictably and is
  # re-derived by check_for_changes.sh, but a revocation lands whenever Apple
  # decides — so recording it here is what makes the weekly run notice a cert
  # that died since the page was built, and rebuild the page to say so.
  if [[ -n "$SIGN_STATE_FILE" ]]; then
    printf 'cert\t%s\t%s\t%s\t%s\n' "$OUTPUT_NAME" "${CERT_FP:-unknown}" "$CERT_EXPIRES_AT" "$CERT_REVOCATION" >> "$SIGN_STATE_FILE"
  fi
  if [[ "$PRECHECK_ONLY" == "1" ]]; then
    log "Pool: $OUTPUT_NAME (expires $CERT_EXPIRES_AT, $CERT_REVOCATION)"
    SUCCESS=$((SUCCESS + 1))
    continue
  fi

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
    # Fall back to all identities: codesign needs only the private key.
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
done < <(find "$POOL_DIR" -type f -name '*.p12' | LC_ALL=C sort)

if [[ $FOUND_P12 -eq 0 ]]; then
  fail "No .p12 files were found in any certificate source"; exit 1
fi

echo
echo "[✓] Done"
if [[ "$PRECHECK_ONLY" == "1" ]]; then
  echo "[✓] Certificates in pool: $SUCCESS"
else
  echo "[✓] Successful: $SUCCESS"
fi
echo "[!] Failed: $FAILED"
echo "[=] Skipped (duplicate certificates): $SKIPPED_DUP"

if [[ $SUCCESS -eq 0 ]]; then
  if [[ "$PRECHECK_ONLY" == "1" ]]; then
    fail "No usable certificates found in the pool"; exit 1
  fi
  fail "No signed IPAs were created"; exit 1
fi
