#!/bin/sh
# Installs siboot into Open Minis and runs it, which pairs this iPhone with
# itself, signs SideInstaller with your Apple Account and installs it.
#
# In Minis's terminal (Minis › Settings › Terminal):
#
#   wget -qO- https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/minis/install.sh | sh
#
# Arguments for siboot go after `sh -s --`, e.g. `… | sh -s -- check`.
# Afterwards `siboot` runs it again, without downloading.
set -eu

BASE="${SIBOOT_BASE:-https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/minis}"
# Of bin/siboot-aarch64, updated with it: a download that doesn't match (an
# error page, a cut-off transfer) is never run.
SHA256="132b3d70f6c7cf6a967717663d7e744d311fc698b10c778b357d239f44caad48"

DIR="$HOME/.siboot/bin"
BIN="$DIR/siboot"

case "$(uname -m)" in
  aarch64 | arm64) ;;
  *)
    echo "siboot runs in Open Minis on an iPhone (aarch64); this is $(uname -m)." >&2
    exit 1
    ;;
esac

fetch() {
  if command -v curl > /dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  else
    wget -qO "$2" "$1"
  fi
}

sha() { sha256sum "$1" | cut -d ' ' -f 1; }

mkdir -p "$DIR"
if [ -f "$BIN" ] && [ "$(sha "$BIN")" = "$SHA256" ]; then
  echo "siboot is up to date"
else
  echo "downloading siboot (12 MB) …"
  if ! fetch "$BASE/bin/siboot-aarch64" "$BIN.part"; then
    rm -f "$BIN.part"
    echo "Couldn't download siboot. Check the internet connection and try again." >&2
    exit 1
  fi
  if [ "$(sha "$BIN.part")" != "$SHA256" ]; then
    rm -f "$BIN.part"
    echo "The siboot download didn't match its checksum. Try again in a few minutes." >&2
    exit 1
  fi
  chmod 755 "$BIN.part"
  mv "$BIN.part" "$BIN"
fi

# So `siboot` works on its own from now on (Minis's shell runs as root).
ln -sf "$BIN" /usr/local/bin/siboot 2> /dev/null || true

# Piped into sh, stdin is this script, and siboot's prompts need the terminal.
if [ -t 0 ]; then
  exec "$BIN" "$@"
elif [ -r /dev/tty ] && { : < /dev/tty; } 2> /dev/null; then
  exec "$BIN" "$@" < /dev/tty
else
  exec "$BIN" "$@"
fi
