#!/bin/bash
# Build index.html from the signed IPAs and their OTA plists: one card per
# certificate, colour-coded and ordered so the ones that still work come first —
# certificates Apple has not revoked, then unverified ones, then the dead.
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-sideinstaller}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
APP_NAME="${APP_NAME:-SideInstaller}"
APP_TAGLINE="${APP_TAGLINE:-On-device sideloader. Follow the three steps below to get set up.}"
PAGE_TITLE="${PAGE_TITLE:-$APP_NAME}"
OUTPUT_HTML="${OUTPUT_HTML:-index.html}"
TEMPLATE="${TEMPLATE:-$SCRIPT_DIR/template.html}"

if [[ -n "${GITHUB_REPOSITORY:-}" && "$GITHUB_REPOSITORY" == */* ]]; then
  GITHUB_USER="${GITHUB_USER:-${GITHUB_REPOSITORY%/*}}"
  GITHUB_REPO="${GITHUB_REPO:-${GITHUB_REPOSITORY#*/}}"
else
  GITHUB_USER="${GITHUB_USER:-SideInstaller}"
  GITHUB_REPO="${GITHUB_REPO:-SideInstaller}"
fi
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
OUTPUT_BASE_URL="${OUTPUT_BASE_URL:-https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/output}"
# The app icon, committed at the repo root so the page can load it by raw URL.
LOGO_URL="${LOGO_URL:-https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/app-icon.png}"
# The "Download IPA" target. By default it serves the latest release's asset
# directly and so never needs updating per release; when the run was started
# with a one-off IPA override (UNSIGNED_IPA_URL, the workflow's ipa_url input),
# the button points at that build instead, so the page always hands out the same
# IPA the install cards were signed from.
IPA_ASSET_NAME="${IPA_ASSET_NAME:-SideInstaller.ipa}"
DEFAULT_RELEASE_URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/latest/download/$IPA_ASSET_NAME"
LATEST_RELEASE_URL="${LATEST_RELEASE_URL:-${UNSIGNED_IPA_URL:-$DEFAULT_RELEASE_URL}}"

CERT_METADATA_FILE="$OUTPUT_DIR/certificate-validity.tsv"
APP_INFO_FILE="$OUTPUT_DIR/app-info.tsv"

if [[ "$OUTPUT_HTML" = /* ]]; then OUTPUT="$OUTPUT_HTML"; else OUTPUT="$ROOT_DIR/$OUTPUT_HTML"; fi

LAST_UPDATED="$(TZ=Europe/Paris date '+%d %b %Y, %H:%M CET')"

# App display name and version, from the unsigned IPA.
APP_VERSION="—"
if [[ -f "$APP_INFO_FILE" ]]; then
  while IFS=$'\t' read -r k v; do
    case "$k" in
      title)   [[ -n "$v" ]] && APP_NAME="$v" ;;
      version) [[ -n "$v" ]] && APP_VERSION="$v" ;;
    esac
  done < "$APP_INFO_FILE"
fi

# The provided image, or a built-in inline SVG glyph.
if [[ -n "$LOGO_URL" ]]; then
  LOGO_HTML="<img src=\"$LOGO_URL\" alt=\"$APP_NAME\">"
else
  LOGO_HTML='<svg viewBox="0 0 24 24" fill="none" stroke="url(#g)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><defs><linearGradient id="g" x1="0" y1="0" x2="24" y2="24"><stop offset="0" stop-color="#2170f5"/><stop offset="1" stop-color="#4dadff"/></linearGradient></defs><rect x="4" y="2.5" width="16" height="19" rx="3.5"/><path d="M12 7v8"/><path d="M8.5 11.5L12 15l3.5-3.5"/></svg>'
fi

html_escape() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }

certificate_days_left() {
  local name="$1" cert_name cert_expires_at cert_days_left cert_revocation
  if [[ ! -f "$CERT_METADATA_FILE" ]]; then printf '%s\n' "-999999"; return 0; fi
  while IFS=$'\t' read -r cert_name cert_expires_at cert_days_left cert_revocation; do
    if [[ "$cert_name" == "$name" && "$cert_days_left" =~ ^-?[0-9]+$ ]]; then
      printf '%s\n' "$cert_days_left"; return 0
    fi
  done < "$CERT_METADATA_FILE"
  printf '%s\n' "-999999"
}

certificate_expires_at() {
  local name="$1" cert_name cert_expires_at cert_days_left cert_revocation
  [[ -f "$CERT_METADATA_FILE" ]] || { printf '\n'; return 0; }
  while IFS=$'\t' read -r cert_name cert_expires_at cert_days_left cert_revocation; do
    if [[ "$cert_name" == "$name" ]]; then printf '%s\n' "$cert_expires_at"; return 0; fi
  done < "$CERT_METADATA_FILE"
  printf '\n'
}

# valid | revoked | unknown, as recorded by the last signing run. A metadata
# file written before the column existed yields "unknown" for every row, which
# is the honest answer: nothing asked Apple at the time.
certificate_revocation() {
  local name="$1" cert_name cert_expires_at cert_days_left cert_revocation
  [[ -f "$CERT_METADATA_FILE" ]] || { printf 'unknown\n'; return 0; }
  while IFS=$'\t' read -r cert_name cert_expires_at cert_days_left cert_revocation; do
    if [[ "$cert_name" == "$name" ]]; then
      case "$cert_revocation" in
        valid|revoked) printf '%s\n' "$cert_revocation" ;;
        *)             printf 'unknown\n' ;;
      esac
      return 0
    fi
  done < "$CERT_METADATA_FILE"
  printf 'unknown\n'
}

pill_for() {  # days -> "class<TAB>label"
  local d="$1"
  if ! [[ "$d" =~ ^-?[0-9]+$ ]] || (( d <= -999999 )); then printf 'unknown\tUnknown'; return; fi
  if   (( d < 0  )); then printf 'bad\tExpired'
  elif (( d == 0 )); then printf 'crit\tExpires today'
  elif (( d == 1 )); then printf 'crit\t1 day left'
  elif (( d <= 7 )); then printf 'crit\t%s days left' "$d"
  elif (( d <= 30 )); then printf 'warn\t%s days left' "$d"
  else printf 'good\t%s days left' "$d"; fi
}

# True when the metadata file had nothing at all to say about a certificate —
# certificate_days_left's miss sentinel. Cards like this are leftovers: a signed
# IPA still sitting in the output folder after its certificate left the pool.
no_metadata() { ! [[ "$1" =~ ^-?[0-9]+$ ]] || (( $1 <= -999999 )); }

# The headline verdict on a card: whether installing it is worth the reader's
# time. Revocation outranks everything — Apple kills these certificates far
# faster than they expire, and a revoked one installs perfectly and then refuses
# to launch, which is the single most confusing failure this page can hand out.
# An expired certificate is just as dead, so it collapses into the same answer.
status_pill_for() {  # revocation, days -> "class<TAB>label"
  local revocation="$1" d="$2"
  if [[ "$revocation" == "revoked" ]]; then printf 'bad\tRevoked'; return; fi
  if ! no_metadata "$d" && (( d < 0 )); then printf 'bad\tExpired'; return; fi
  case "$revocation" in
    valid) printf 'good\tValid' ;;
    *)     if no_metadata "$d"; then printf 'unknown\tUnknown'
           else printf 'unknown\tUnverified'; fi ;;
  esac
}

# Sort rank, and the ordering the reader actually wants: certificates that work
# first. Ties inside a rank fall back to days left, so the longest-lived working
# certificate leads the page.
#
# A leftover with no metadata ranks with the dead rather than the unverified.
# The page has never had anything to say about those cards and has always shown
# them last; promoting them above certificates Apple is known to have revoked
# would be a downgrade dressed up as caution.
rank_for() {  # revocation, days -> 0 (works) | 1 (unverified) | 2 (dead)
  local revocation="$1" d="$2"
  if [[ "$revocation" == "revoked" ]]; then printf '2'; return; fi
  case "$revocation" in
    valid) printf '0'; return ;;
  esac
  if no_metadata "$d"; then printf '2'; return; fi
  if (( d < 0 )); then printf '2'; return; fi
  printf '1'
}

INSTALL_ICON='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12"/><path d="M7 11l5 5 5-5"/><path d="M5 21h14"/></svg>'

shopt -s nullglob
PLISTS=("$OUTPUT_DIR"/"$OUTPUT_PREFIX"-*.plist)
shopt -u nullglob

CARDS_FILE="$(mktemp)"
CERT_COUNT=0
VALID_COUNT=0

if [[ ${#PLISTS[@]} -gt 0 ]]; then
  while IFS=$'\t' read -r rank days_left name plist; do
    filename="$(basename "$plist")"
    expires_at="$(certificate_expires_at "$name")"
    revocation="$(certificate_revocation "$name")"
    IFS=$'\t' read -r pill_class pill_label <<< "$(status_pill_for "$revocation" "$days_left")"
    IFS=$'\t' read -r days_class days_label <<< "$(pill_for "$days_left")"

    name_esc="$(printf '%s' "$name" | html_escape)"
    # Expiry moved out of the pill to make room for the verdict, so the meta
    # line now carries both the date and the countdown, still colour-coded.
    meta_bits=""
    if [[ -n "$expires_at" && "$expires_at" != "unknown" ]]; then
      meta_bits="Expires $(printf '%s' "$expires_at" | html_escape)"
    fi
    if [[ "$days_class" != "unknown" ]]; then
      [[ -n "$meta_bits" ]] && meta_bits="$meta_bits &middot; "
      meta_bits="$meta_bits<span class=\"days $days_class\">$days_label</span>"
    fi
    meta_line=""
    [[ -n "$meta_bits" ]] && meta_line="<p class=\"cert-meta\">$meta_bits</p>"

    install_url="itms-services://?action=download-manifest&amp;url=$OUTPUT_BASE_URL/$filename"

    cat >> "$CARDS_FILE" <<EOF
    <article class="cert-card" data-name="$name_esc" data-days="$days_left" data-rank="$rank" data-status="$revocation">
      <div class="cert-head">
        <h3 class="cert-name">$name_esc</h3>
        <span class="pill $pill_class">$pill_label</span>
      </div>
      $meta_line
      <a class="install-btn" href="$install_url">$INSTALL_ICON Install</a>
    </article>
EOF
    CERT_COUNT=$((CERT_COUNT + 1))
    if [[ "$rank" == "0" ]]; then VALID_COUNT=$((VALID_COUNT + 1)); fi
  done < <(
    for plist in "${PLISTS[@]}"; do
      filename="$(basename "$plist")"; name="${filename%.plist}"; name="${name#"$OUTPUT_PREFIX"-}"
      d="$(certificate_days_left "$name")"
      printf '%s\t%s\t%s\t%s\n' "$(rank_for "$(certificate_revocation "$name")" "$d")" "$d" "$name" "$plist"
    done | LC_ALL=C sort -t $'\t' -k1,1n -k2,2nr -k3,3
  )
fi

if [[ $CERT_COUNT -eq 0 ]]; then
  printf '    <p class="empty show">No signed builds available yet. Check back soon.</p>\n' > "$CARDS_FILE"
fi

REPO_NOTE="Built automatically &middot; signed with $CERT_COUNT certificate(s), $VALID_COUNT currently valid"

# The beta call-out ships on the public page only: on beta.html it would point
# at the page the reader is already on.
INCLUDE_BETA_BANNER=0
[[ "$(basename "$OUTPUT")" == "index.html" ]] && INCLUDE_BETA_BANNER=1

# Stream the template, swap its tokens, and splice in the cards block.
PAGE_TITLE_ESC="$(printf '%s' "$PAGE_TITLE" | html_escape)"
APP_NAME_ESC="$(printf '%s' "$APP_NAME" | html_escape)"
APP_TAGLINE_ESC="$(printf '%s' "$APP_TAGLINE" | html_escape)"
APP_VERSION_ESC="$(printf '%s' "$APP_VERSION" | html_escape)"
# An override URL is arbitrary text, and query separators would otherwise end up
# raw inside the href.
LATEST_RELEASE_URL_ESC="$(printf '%s' "$LATEST_RELEASE_URL" | html_escape)"

awk \
  -v cards_file="$CARDS_FILE" \
  -v page_title="$PAGE_TITLE_ESC" \
  -v app_name="$APP_NAME_ESC" \
  -v app_tagline="$APP_TAGLINE_ESC" \
  -v app_version="$APP_VERSION_ESC" \
  -v cert_count="$CERT_COUNT" \
  -v logo="$LOGO_HTML" \
  -v last_updated="$LAST_UPDATED" \
  -v latest_release_url="$LATEST_RELEASE_URL_ESC" \
  -v repo_note="$REPO_NOTE" \
  -v include_beta_banner="$INCLUDE_BETA_BANNER" '
  # Literal replace, since gsub would treat & or \ in the value specially.
  function rep(s, tok, val,   out, p){
    out=""
    while ((p=index(s, tok)) > 0){
      out = out substr(s, 1, p-1) val
      s = substr(s, p + length(tok))
    }
    return out s
  }
  function subst(s){
    s = rep(s, "{{PAGE_TITLE}}", page_title)
    s = rep(s, "{{APP_NAME}}", app_name)
    s = rep(s, "{{APP_TAGLINE}}", app_tagline)
    s = rep(s, "{{APP_VERSION}}", app_version)
    s = rep(s, "{{CERT_COUNT}}", cert_count)
    s = rep(s, "{{LOGO}}", logo)
    s = rep(s, "{{LAST_UPDATED}}", last_updated)
    s = rep(s, "{{LATEST_RELEASE_URL}}", latest_release_url)
    s = rep(s, "{{REPO_NOTE}}", repo_note)
    return s
  }
  # The banner lives in the template between its markers; drop the markers
  # always, and the block itself on every page but index.html.
  /<!-- BETA_BANNER:START -->/ { in_beta = 1; next }
  /<!-- BETA_BANNER:END -->/   { in_beta = 0; next }
  in_beta && include_beta_banner != 1 { next }
  {
    if ($0 ~ /{{CARDS}}/) {
      while ((getline line < cards_file) > 0) print line
      close(cards_file)
    } else {
      print subst($0)
    }
  }
' "$TEMPLATE" > "$OUTPUT"

rm -f "$CARDS_FILE"
echo "[✓] Generated $OUTPUT ($CERT_COUNT certificate card(s))"
