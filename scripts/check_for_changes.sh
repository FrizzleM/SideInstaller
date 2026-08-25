#!/bin/bash
# Decide whether a full signing run would actually change the install page.
#
# Everything that ends up on index.html comes from four inputs: the certificate
# pool, the unsigned IPA, the page template and the generator scripts. This
# script fingerprints all four into a small "state" file and compares it with
# the state the last full run recorded in $OUTPUT_DIR/sign-state.tsv. Identical
# state means re-signing would rebuild the very same cards, so the workflow can
# stop and leave the published page exactly as it is.
#
# The one part of a card that moves on its own is the validity pill, which is
# relative to today. Its exact wording ("39 days left") is only refreshed by a
# full run, but its status band — Expired / red / amber / green — is checked
# here against what the committed page currently shows, so a certificate that
# has crossed into a new band still forces a run.
#
# Revocation needs no such treatment: the pool walk re-queries Apple's OCSP
# responder for every certificate, so a cert Apple killed since the last run
# comes back with a different state line and the plain state diff catches it.
#
# Config, all overridable by env:
#   OUTPUT_DIR       channel output folder holding the recorded state
#   CHANNEL          stable | beta, recorded so channels never match each other
#   STATE_FILE       recorded state (default: $OUTPUT_DIR/sign-state.tsv)
#   NEW_STATE_FILE   where to write the freshly computed state
#   FORCE_RUN        true = report "changed" without inspecting anything
#
# Reports `skip` and `reason` on stdout, and as step outputs under Actions. The
# computed state is left at $NEW_STATE_FILE for the caller to commit after a
# successful run, so the next precheck compares against what actually shipped.
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
# Absolute, and exported, so the precheck pass below resolves the same folder
# whatever the caller's working directory is.
[[ "$OUTPUT_DIR" = /* ]] || OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
export OUTPUT_DIR
CHANNEL="${CHANNEL:-stable}"
STATE_FILE="${STATE_FILE:-$OUTPUT_DIR/sign-state.tsv}"
CERT_METADATA_FILE="$OUTPUT_DIR/certificate-validity.tsv"
FORCE_RUN="${FORCE_RUN:-false}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
NEW_STATE_FILE="${NEW_STATE_FILE:-${RUNNER_TEMP:-$TMP_DIR}/sign-state.tsv}"

# Report the verdict and stop. skip=true means "leave the page alone".
emit() {   # $1 = true|false  $2 = reason
  echo
  echo "[precheck] skip=$1 — $2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'skip=%s\nreason=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
  fi
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    printf 'NEW_STATE_FILE=%s\n' "$NEW_STATE_FILE" >> "$GITHUB_ENV"
  fi
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    if [[ "$1" == "true" ]]; then
      printf '### Nothing to do\n\n%s — the install page was left untouched.\n' "$2" >> "$GITHUB_STEP_SUMMARY"
    else
      printf '### Re-signing\n\n%s\n' "$2" >> "$GITHUB_STEP_SUMMARY"
    fi
  fi
  exit 0
}

# A forced run still walks the pool: the state it produces is what gets
# committed afterwards, and skipping that here would leave the next run
# comparing against a stale record.
if [[ "$FORCE_RUN" == "true" ]]; then
  echo "[precheck] Forced run — inspecting the pool anyway so fresh state is recorded"
fi

# ----- fingerprint the current inputs ---------------------------------------
# The pool walk, the password lookup and the de-duplication all have to match
# the signing run exactly, so this reuses the signing script itself rather than
# reimplementing them. It stops right after each certificate is identified.
POOL_STATE="$TMP_DIR/pool-state.tsv"
POOL_LOG="$TMP_DIR/pool.log"
echo "[precheck] Inspecting the certificate pool"
if ! PRECHECK_ONLY=1 SIGN_STATE_FILE="$POOL_STATE" "$SCRIPT_DIR/sign_with_all_certs.sh" > "$POOL_LOG" 2>&1; then
  tail -n 40 "$POOL_LOG" || true
  # Any doubt about the pool resolves in favour of running: at worst that costs
  # a rebuild, whereas skipping on bad data would freeze a stale page.
  emit false "Could not inspect the certificate pool; running the full job"
fi
grep -E '^\[(WARN|FAIL)\]|^\[\*\] Source|^\[✓\]' "$POOL_LOG" || true

IPA_URL="$(awk -F'\t' '$1 == "ipa" { print $2; exit }' "$POOL_STATE")"
# Size of the unsigned IPA, so a release that re-uploads its asset under the
# same URL still counts as a change. Best effort — an unreadable header just
# records an empty value on both sides of the comparison.
IPA_SIZE="$(curl -fsSLI "$IPA_URL" 2>/dev/null \
  | awk 'tolower($1) == "content-length:" { v = $2 } END { gsub(/\r/, "", v); print v }' || true)"

# Any edit to the page template or to the generators changes the output even
# when every certificate is identical, so they are part of the state too.
INPUTS_SHA="$(cat \
  "$SCRIPT_DIR/template.html" \
  "$SCRIPT_DIR/generate_index.sh" \
  "$SCRIPT_DIR/generate_plist.sh" \
  "$SCRIPT_DIR/sign_with_all_certs.sh" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)"

mkdir -p "$(dirname "$NEW_STATE_FILE")"
{
  echo "# sign-sideinstaller — the inputs that determine the install page."
  echo "# Written by the last full run and compared before the next one; the run"
  echo "# is skipped when this file would come out identical. Delete to force."
  printf 'channel\t%s\n'          "$CHANNEL"
  printf 'ipa_url\t%s\n'          "$IPA_URL"
  printf 'ipa_size\t%s\n'         "$IPA_SIZE"
  printf 'output_base_url\t%s\n'  "${OUTPUT_BASE_URL:-}"
  printf 'inputs_sha256\t%s\n'    "$INPUTS_SHA"
  # Sorted, so a reordered source list alone is not treated as a change.
  awk -F'\t' '$1 == "cert"' "$POOL_STATE" | LC_ALL=C sort
} > "$NEW_STATE_FILE"

CERT_TOTAL="$(grep -c $'^cert\t' "$NEW_STATE_FILE" || true)"
echo "[precheck] Pool resolved: ${CERT_TOTAL:-0} certificate(s), IPA ${IPA_URL}"

# ----- compare against what was published last ------------------------------
if [[ "$FORCE_RUN" == "true" ]]; then
  emit false "Forced run requested"
fi

if [[ ! -f "$STATE_FILE" ]]; then
  emit false "No recorded state yet ($STATE_FILE); running the full job"
fi

if ! diff -u "$STATE_FILE" "$NEW_STATE_FILE" > "$TMP_DIR/state.diff" 2>&1; then
  echo "[precheck] Inputs differ from the last run:"
  cat "$TMP_DIR/state.diff"
  changed_certs="$(grep -cE '^[+-]cert' "$TMP_DIR/state.diff" || true)"
  if [[ "${changed_certs:-0}" -gt 0 ]]; then
    emit false "Certificate pool changed"
  fi
  emit false "Build inputs changed (IPA, template or generator scripts)"
fi

if [[ ! -f "$CERT_METADATA_FILE" ]]; then
  emit false "No recorded certificate validity ($CERT_METADATA_FILE); running the full job"
fi

# Same pool, same IPA, same template. The page can still be out of date if a
# certificate has moved into a different validity band since it was rendered.
if ! python3 - "$NEW_STATE_FILE" "$CERT_METADATA_FILE" <<'PY'
import sys
from datetime import date

def band(days):
    """The pill generate_index.sh would draw for this many days left."""
    if days is None:
        return "unknown"
    if days < 0:
        return "expired"
    if days <= 7:
        return "red"
    if days <= 30:
        return "amber"
    return "green"

def days_until(iso):
    try:
        y, m, d = (int(p) for p in iso.split("-"))
    except ValueError:
        return None
    return (date(y, m, d) - date.today()).days

# What the committed page shows: days left as recorded by the last signing run.
shown = {}
with open(sys.argv[2]) as fh:
    next(fh, None)                       # header
    for line in fh:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 3:
            continue
        try:
            shown[parts[0]] = int(parts[2])
        except ValueError:
            shown[parts[0]] = None

moved = []
with open(sys.argv[1]) as fh:
    for line in fh:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 4 or parts[0] != "cert":
            continue
        name, expires_at = parts[1], parts[3]
        # Certificates with no row never made it onto the page; a re-run would
        # not add them, so they are not a reason to rebuild.
        if name not in shown:
            continue
        was, now = band(shown[name]), band(days_until(expires_at))
        if was != now:
            moved.append(f"{name}: {was} -> {now}")

for m in moved:
    print(f"[precheck] Validity band changed — {m}")
raise SystemExit(1 if moved else 0)
PY
then
  emit false "A certificate has changed validity band since the page was built"
fi

emit true "Same ${CERT_TOTAL:-0} certificate(s), same IPA, same template"
