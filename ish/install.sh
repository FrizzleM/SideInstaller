#!/bin/sh
# Bootstrap for running SideInstaller's signer inside iSH (Alpine on iOS).
#
#   sh install.sh                 install dependencies and run the signer
#   sh install.sh --build-signer  compile zsign (once, slow) and stop
#   sh install.sh --deps          install dependencies and stop
#   sh install.sh -- <args>       pass the rest through to sideinstaller.py
#
# Everything lands in ~/.sideinstaller. Nothing is installed system-wide except
# Alpine packages.

set -eu

REPO_RAW="https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/ish"
ZSIGN_VERSION="v1.1.2"
ZSIGN_URL="https://github.com/zhlynn/zsign/archive/refs/tags/${ZSIGN_VERSION}.tar.gz"

HERE="$(cd "$(dirname "$0")" && pwd)"
STORE="${SIDEINSTALLER_HOME:-$HOME/.sideinstaller}"
BIN="$STORE/bin"

say()  { printf '\033[1;36m==> \033[0m\033[1m%s\033[0m\n' "$1"; }
note() { printf '    %s\n' "$1"; }
bad()  { printf '\033[1;31m  x \033[0m%s\n' "$1" >&2; exit 1; }


install_deps() {
  say "Installing dependencies"
  apk update >/dev/null 2>&1 || note "apk update failed; continuing with the cached index"
  apk add --no-cache python3 openssl ca-certificates >/dev/null
  update-ca-certificates >/dev/null 2>&1 || true
  note "python3 $(python3 -c 'import sys;print("%d.%d.%d"%sys.version_info[:3])')"
  note "$(openssl version)"
}

build_signer() {
  if [ -x "$BIN/zsign" ]; then
    say "zsign is already built"
    note "$BIN/zsign"
    return
  fi

  say "Building zsign $ZSIGN_VERSION"
  note "iSH emulates a 32-bit x86 CPU, so this compiles at a fraction of native"
  note "speed — expect 10 to 40 minutes. It only ever happens once."
  note "Keep iSH in the foreground; iOS suspends backgrounded apps."

  apk add --no-cache build-base git pkgconf openssl-dev zlib-dev >/dev/null

  work="$STORE/build"
  rm -rf "$work"
  mkdir -p "$work"
  ( cd "$work" && wget -q -O zsign.tar.gz "$ZSIGN_URL" && tar xzf zsign.tar.gz )

  src="$work/zsign-${ZSIGN_VERSION#v}"
  [ -d "$src/build/linux" ] || bad "zsign source does not look right: $src"

  ( cd "$src/build/linux" && make VERSION="${ZSIGN_VERSION#v}" ) || bad "zsign failed to build."
  [ -x "$src/bin/zsign" ] || bad "zsign built but produced no binary."

  cp "$src/bin/zsign" "$BIN/zsign"
  chmod +x "$BIN/zsign"
  rm -rf "$work"
  say "zsign installed"
  note "$BIN/zsign"
}

fetch_script() {
  if [ -f "$HERE/sideinstaller.py" ]; then
    echo "$HERE/sideinstaller.py"
    return
  fi
  target="$STORE/sideinstaller.py"
  if [ ! -f "$target" ]; then
    say "Downloading sideinstaller.py" >&2
    wget -q -O "$target" "$REPO_RAW/sideinstaller.py" \
      || bad "Could not download sideinstaller.py from $REPO_RAW"
    note "Read it before running it: less $target" >&2
  fi
  echo "$target"
}

case "${1:-}" in
  -h|--help)
    awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
    exit 0
    ;;
esac

[ -f /etc/alpine-release ] || bad "This is meant for iSH (Alpine Linux). /etc/alpine-release is missing."
mkdir -p "$BIN"

case "${1:-}" in
  --deps)
    install_deps
    exit 0
    ;;
  --build-signer)
    install_deps
    build_signer
    exit 0
    ;;
  --)
    shift
    ;;
esac

install_deps
if [ ! -x "$BIN/zsign" ] && ! command -v zsign >/dev/null 2>&1; then
  say "No signer found"
  note "zsign has to be compiled once before anything can be signed."
  printf '    Build it now? [Y/n] '
  read -r answer
  case "$answer" in
    [Nn]*) bad "Nothing to sign with. Run: sh install.sh --build-signer" ;;
    *) build_signer ;;
  esac
fi

SCRIPT="$(fetch_script)"
exec python3 "$SCRIPT" "$@"
