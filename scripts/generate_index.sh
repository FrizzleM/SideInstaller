#!/bin/bash
# Build the install page (index.html) from the signed IPAs + their OTA plists.
# One card per certificate, color-coded by remaining validity, sorted by days left.
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-sideinstaller}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
APP_NAME="${APP_NAME:-SideInstaller}"
APP_TAGLINE="${APP_TAGLINE:-On-device sideloader. Pick a certificate and tap install.}"
PAGE_TITLE="${PAGE_TITLE:-$APP_NAME — Install}"
LOGO_URL="${LOGO_URL:-}"
OUTPUT_HTML="${OUTPUT_HTML:-index.html}"
TEMPLATE="${TEMPLATE:-$SCRIPT_DIR/template.html}"
IPA_URL_FILE="${IPA_URL_FILE:-$ROOT_DIR/ipa-url.txt}"

if [[ -n "${GITHUB_REPOSITORY:-}" && "$GITHUB_REPOSITORY" == */* ]]; then
  GITHUB_USER="${GITHUB_USER:-${GITHUB_REPOSITORY%/*}}"
  GITHUB_REPO="${GITHUB_REPO:-${GITHUB_REPOSITORY#*/}}"
else
  GITHUB_USER="${GITHUB_USER:-SideInstaller}"
  GITHUB_REPO="${GITHUB_REPO:-SideInstaller}"
fi
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
OUTPUT_BASE_URL="${OUTPUT_BASE_URL:-https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/output}"

CERT_METADATA_FILE="$OUTPUT_DIR/certificate-validity.tsv"
APP_INFO_FILE="$OUTPUT_DIR/app-info.tsv"

if [[ "$OUTPUT_HTML" = /* ]]; then OUTPUT="$OUTPUT_HTML"; else OUTPUT="$ROOT_DIR/$OUTPUT_HTML"; fi

LAST_UPDATED="$(TZ=Europe/Paris date '+%d %b %Y, %H:%M CET')"

# --- app metadata (display name + version) from the unsigned IPA ---
APP_VERSION="—"
if [[ -f "$APP_INFO_FILE" ]]; then
  while IFS=$'\t' read -r k v; do
    case "$k" in
      title)   [[ -n "$v" ]] && APP_NAME="$v" ;;
      version) [[ -n "$v" ]] && APP_VERSION="$v" ;;
    esac
  done < "$APP_INFO_FILE"
fi

# --- logo: use provided image, else a built-in inline SVG glyph ---
if [[ -n "$LOGO_URL" ]]; then
  LOGO_HTML="<img src=\"$LOGO_URL\" alt=\"$APP_NAME\">"
else
  LOGO_HTML='<svg viewBox="0 0 24 24" fill="none" stroke="url(#g)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><defs><linearGradient id="g" x1="0" y1="0" x2="24" y2="24"><stop offset="0" stop-color="#6d8bff"/><stop offset="1" stop-color="#a06bff"/></linearGradient></defs><rect x="4" y="2.5" width="16" height="19" rx="3.5"/><path d="M12 7v8"/><path d="M8.5 11.5L12 15l3.5-3.5"/></svg>'
fi

html_escape() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }

# First non-blank, non-comment line of a file, CR-stripped and trimmed.
first_config_line() {
  [[ -f "$1" ]] || return 0
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

# --- unsigned IPA URL: explicit override, else first line of ipa-url.txt ---
UNSIGNED_IPA_URL="${UNSIGNED_IPA_URL:-$(first_config_line "$IPA_URL_FILE")}"

certificate_days_left() {
  local name="$1" cert_name cert_expires_at cert_days_left
  if [[ ! -f "$CERT_METADATA_FILE" ]]; then printf '%s\n' "-999999"; return 0; fi
  while IFS=$'\t' read -r cert_name cert_expires_at cert_days_left; do
    if [[ "$cert_name" == "$name" && "$cert_days_left" =~ ^-?[0-9]+$ ]]; then
      printf '%s\n' "$cert_days_left"; return 0
    fi
  done < "$CERT_METADATA_FILE"
  printf '%s\n' "-999999"
}

certificate_expires_at() {
  local name="$1" cert_name cert_expires_at cert_days_left
  [[ -f "$CERT_METADATA_FILE" ]] || { printf '\n'; return 0; }
  while IFS=$'\t' read -r cert_name cert_expires_at cert_days_left; do
    if [[ "$cert_name" == "$name" ]]; then printf '%s\n' "$cert_expires_at"; return 0; fi
  done < "$CERT_METADATA_FILE"
  printf '\n'
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

INSTALL_ICON='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12"/><path d="M7 11l5 5 5-5"/><path d="M5 21h14"/></svg>'

# --- "Download unsigned .ipa" button (omitted entirely if no URL is configured) ---
IPA_DOWNLOAD_HTML=""
if [[ -n "$UNSIGNED_IPA_URL" ]]; then
  ipa_url_esc="$(printf '%s' "$UNSIGNED_IPA_URL" | html_escape)"
  IPA_DOWNLOAD_HTML="<div class=\"ipa-dl\"><a class=\"ipa-btn\" href=\"$ipa_url_esc\" download>$INSTALL_ICON Download unsigned .ipa</a><p class=\"ipa-note\">The raw, unsigned build — for signing it yourself or sideloading with your own tool.</p></div>"
fi

shopt -s nullglob
PLISTS=("$OUTPUT_DIR"/"$OUTPUT_PREFIX"-*.plist)
shopt -u nullglob

CARDS_FILE="$(mktemp)"
CERT_COUNT=0

if [[ ${#PLISTS[@]} -gt 0 ]]; then
  while IFS=$'\t' read -r days_left name plist; do
    filename="$(basename "$plist")"
    expires_at="$(certificate_expires_at "$name")"
    IFS=$'\t' read -r pill_class pill_label <<< "$(pill_for "$days_left")"

    name_esc="$(printf '%s' "$name" | html_escape)"
    expires_line=""
    if [[ -n "$expires_at" && "$expires_at" != "unknown" ]]; then
      expires_line="<p class=\"cert-meta\">Expires $(printf '%s' "$expires_at" | html_escape)</p>"
    fi
    install_url="itms-services://?action=download-manifest&amp;url=$OUTPUT_BASE_URL/$filename"

    cat >> "$CARDS_FILE" <<EOF
    <article class="cert-card" data-name="$name_esc" data-days="$days_left">
      <div class="cert-head">
        <h3 class="cert-name">$name_esc</h3>
        <span class="pill $pill_class">$pill_label</span>
      </div>
      $expires_line
      <a class="install-btn" href="$install_url">$INSTALL_ICON Install</a>
    </article>
EOF
    CERT_COUNT=$((CERT_COUNT + 1))
  done < <(
    for plist in "${PLISTS[@]}"; do
      filename="$(basename "$plist")"; name="${filename%.plist}"; name="${name#"$OUTPUT_PREFIX"-}"
      printf '%s\t%s\t%s\n' "$(certificate_days_left "$name")" "$name" "$plist"
    done | LC_ALL=C sort -t $'\t' -k1,1nr -k2,2
  )
fi

if [[ $CERT_COUNT -eq 0 ]]; then
  printf '    <p class="empty show">No signed builds available yet. Check back soon.</p>\n' > "$CARDS_FILE"
fi

REPO_NOTE="Built automatically &middot; signed with $CERT_COUNT certificate(s)"

# --- assemble: stream template, swap single-line tokens, splice the cards block ---
PAGE_TITLE_ESC="$(printf '%s' "$PAGE_TITLE" | html_escape)"
APP_NAME_ESC="$(printf '%s' "$APP_NAME" | html_escape)"
APP_TAGLINE_ESC="$(printf '%s' "$APP_TAGLINE" | html_escape)"
APP_VERSION_ESC="$(printf '%s' "$APP_VERSION" | html_escape)"

awk \
  -v cards_file="$CARDS_FILE" \
  -v page_title="$PAGE_TITLE_ESC" \
  -v app_name="$APP_NAME_ESC" \
  -v app_tagline="$APP_TAGLINE_ESC" \
  -v app_version="$APP_VERSION_ESC" \
  -v cert_count="$CERT_COUNT" \
  -v logo="$LOGO_HTML" \
  -v last_updated="$LAST_UPDATED" \
  -v repo_note="$REPO_NOTE" \
  -v ipa_download="$IPA_DOWNLOAD_HTML" '
  # Literal find/replace — avoids gsub treating & or \ in the value specially,
  # which matters because names/notes can contain & (escaped to &amp;).
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
    s = rep(s, "{{REPO_NOTE}}", repo_note)
    s = rep(s, "{{IPA_DOWNLOAD}}", ipa_download)
    return s
  }
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
