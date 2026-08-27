#!/usr/bin/env python3
"""siboot for a-Shell — a PC-free, certificate-free bootstrap for SideInstaller.

Runs inside a-Shell (App Store, `AsheKube.app.a-Shell`) on the iPhone it installs
to. a-Shell is a local terminal on ios_system, and that decides everything about
how this is built:

  * Commands run **in-process**. There is no fork and no exec, so no binary can
    be shipped here. The iSH build (`../ish-bootstrap`, Rust, i686 ELF) cannot be
    ported; it has to be rewritten in Python, and so does the code signer.
  * a-Shell's clang targets WebAssembly, and WASM here has "no sockets, no
    forks". So WASM cannot carry the networking either.
  * What is left is CPython with the stdlib, and that turns out to be enough:
    real BSD sockets, `ssl`, `hashlib`, and `plistlib` — and the whole device
    protocol is plists.

**The reason this host was chosen.** iSH holds no iOS Local Network permission,
so its connections to this iPhone's own services are dropped before they are
answered. That is where the Rust build stopped, at step 2 of 7. a-Shell ships
`ping`, `nslookup` and `ifconfig`, so it has to declare
`NSLocalNetworkUsageDescription` — which should mean the same connection is
allowed. **Should** — that is the one thing this checkpoint exists to prove.

a-Shell mini works too; it has Python, curl and the same network utilities. So
does Terminus (`com.a.terminal.app.ATerminal`), which is a repackage of a-Shell
and credits it in its own Settings screen.

**Checkpoint 1 of 5: the runtime proof.** Nothing here touches an Apple account
and nothing asks for a password; there are no credentials to handle until
checkpoint 3. What it does is answer, on the actual device, every question the
rest of the design rests on — above all whether a TCP connection from this
process reaches RemoteServiceDiscovery on this iPhone.

Usage:

    python siboot.py --self-test          # everything
    python siboot.py --self-test --offline    # skip the checks needing internet
"""

import base64
import os
import platform
import re
import shutil
import socket
import struct
import sys
import time

VERSION = "0.10.0"

# RemoteServiceDiscovery. Fixed across boots, and the door every later step goes
# through. `../ish-bootstrap/src/preflight.rs` explains why this is knocked on
# first and why lockdownd on 62078 is not: it hangs up on network clients within
# ~250us (measured on device, 2026-08-27).
RSD_PORT = 49152
# The service pairing runs over. "untrusted" is the point: it is reachable with
# no pairing record, which is what breaks the deadlock (see ../ish-bootstrap).
TUNNEL_SERVICE = "com.apple.internal.dt.coredevice.untrusted.tunnelservice"
# LocalDevVPN's peer address. Kept as a candidate, but on this host it should no
# longer be needed — see `local_network()`.
VPN_PEER_IP = "10.7.0.1"

CONNECT_TIMEOUT = 3.0
READ_TIMEOUT = 6.0


# Apple Root CA (self-signed, 2006-2035). `gsa.apple.com` serves a chain ending
# here, and a-Shell's OpenSSL 1.1.1i bundle does not carry it — which is why
# sign-in's own host fails to verify while github.com and developerservices2
# both pass. isideload vendors this same certificate for the same reason
# (`../ish-bootstrap/vendor/isideload/src/auth/apple_root.der`), so pinning it
# is the established fix rather than a workaround.
APPLE_ROOT_CA_B64 = """\
MIIEuzCCA6OgAwIBAgIBAjANBgkqhkiG9w0BAQUFADBiMQswCQYDVQQGEwJVUzETMBEG
A1UEChMKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRo
b3JpdHkxFjAUBgNVBAMTDUFwcGxlIFJvb3QgQ0EwHhcNMDYwNDI1MjE0MDM2WhcNMzUw
MjA5MjE0MDM2WjBiMQswCQYDVQQGEwJVUzETMBEGA1UEChMKQXBwbGUgSW5jLjEmMCQG
A1UECxMdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxFjAUBgNVBAMTDUFwcGxl
IFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDkkakJH5HbHkdQ
6wXtXnmELes2oldMVeyLGYne+Uts9QerIjAC6Bg++FAJ039BqJj50cpmnCRrEdCju+Qb
KsMflZ56DKRHi1vUFjczy8QPTc4UadHJGXL1XQ7Vf1+b8iUDulWPTV0N8WQ1IxVLFVkd
s5T39pyez1C6wVhQZ48ItCD3y6wsIG9wtj8BMIy3Q88PnT3zK0koGsj+zrW5DtleHNbL
PbU6rfQPDgCSC7EhFi501TwN22IWq6NxkkdTVcGvL0Gz+PvjcM3mo0xFfh9Ma1CWQYnE
dGILEINBhzOKgbEwWOxaBDKMaLOPHd5lc/9nXmW8Sdh2nzMUZaF3lMktAgMBAAGjggF6
MIIBdjAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUK9Bp
R5R2Cf70a40uQKb3R01/CF4wHwYDVR0jBBgwFoAUK9BpR5R2Cf70a40uQKb3R01/CF4w
ggERBgNVHSAEggEIMIIBBDCCAQAGCSqGSIb3Y2QFATCB8jAqBggrBgEFBQcCARYeaHR0
cHM6Ly93d3cuYXBwbGUuY29tL2FwcGxlY2EvMIHDBggrBgEFBQcCAjCBthqBs1JlbGlh
bmNlIG9uIHRoaXMgY2VydGlmaWNhdGUgYnkgYW55IHBhcnR5IGFzc3VtZXMgYWNjZXB0
YW5jZSBvZiB0aGUgdGhlbiBhcHBsaWNhYmxlIHN0YW5kYXJkIHRlcm1zIGFuZCBjb25k
aXRpb25zIG9mIHVzZSwgY2VydGlmaWNhdGUgcG9saWN5IGFuZCBjZXJ0aWZpY2F0aW9u
IHByYWN0aWNlIHN0YXRlbWVudHMuMA0GCSqGSIb3DQEBBQUAA4IBAQBcNplMLXi37Yyb
3PN3m/J20ncwT8EfhYOFG5k9RzfyqZtAjizUsZAS2L70c5vu0mQPy3lPNNiiPvl4/2vI
B+x9OYOLUyDTOMSxv5pPCmv/K/xZpwUJfBdAVhEedNO3iyM7R6PVbyTi69G3cN8PReEn
yvFteO3ntRcXqNx+IjXKJdXZD9Zr1KIkIxH3oayPc4FgxhtbCS+SsvhESPBgOJ4V9T0m
ZyCKM2r3DYLP3uujL/lTaltkwGMzd/c6ByxW69oPIQ7aunMZT7XZNn/Bh1XZp5m5MkL7
2NVxnn6hUrcbvZNCJBIqxw8dtk2cXmPIS4AXUKqK1drk/NAJBzewdXUh"""


def apple_root_pem():
    import ssl
    return ssl.DER_cert_to_PEM_cert(base64.b64decode(APPLE_ROOT_CA_B64))


def apple_aware_context():
    """The default trust store, plus Apple's own root."""
    import ssl
    ctx = ssl.create_default_context()
    try:
        ctx.load_verify_locations(cadata=apple_root_pem())
    except Exception:                               # noqa: BLE001
        pass
    return ctx


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

_COLOR = sys.stdout.isatty() and os.environ.get("TERM") != "dumb"


def _c(code, text):
    return f"\033[{code}m{text}\033[0m" if _COLOR else text


LINES = []          # everything printed, for the report file
FINDINGS = {}       # machine-readable, for the paste-back summary


def emit(text=""):
    LINES.append(text)
    print(text)


def section(title):
    emit()
    emit(_c("1;36", f"── {title} " + "─" * max(0, 58 - len(title))))


def ok(text):
    emit(f"  {_c('1;32', 'ok')}    {text}")


def bad(text):
    emit(f"  {_c('1;31', 'FAIL')}  {text}")


def warn(text):
    emit(f"  {_c('1;33', 'warn')}  {text}")


def info(text):
    emit(f"        {text}")


def record(key, value):
    FINDINGS[key] = value


# --------------------------------------------------------------------------
# 1. Interpreter and stdlib
# --------------------------------------------------------------------------

# Modules the finished pipeline cannot be written without, and why. If any of
# these is missing the design has to change, so they are checked before
# anything else runs.
REQUIRED = {
    "socket":   "every device connection",
    "ssl":      "HTTPS to Apple's sign-in and developer portal",
    "hashlib":  "SHA-1/256/512 and PBKDF2 — signing and SRP",
    "hmac":     "SRP, HKDF, anisette",
    "plistlib": "lockdown, installation_proxy and .mobileprovision are all plists",
    "zlib":     "the .ipa is a zip; CRC-32 comes from here",
    "struct":   "every binary protocol below",
    "select":   "the tunnel's software TCP stack",
    "threading": "the tunnel pumps packets while the foreground task waits",
    "secrets":  "key material that must not be guessable",
    "base64":   "tokens and certificate bodies",
    "binascii": "hex and CRC helpers",
}

OPTIONAL = {
    "ctypes":     "reading every local interface address (there is a fallback)",
    "subprocess": "shelling out — expected to be unavailable on ios_system",
    "sqlite3":    "not needed; a signal of how complete this stdlib is",
    "getpass":    "no-echo password entry in checkpoint 3 (there is a fallback)",
    "termios":    "the no-echo fallback",
    "lzma":       "some .ipa members; zlib covers the normal case",
}


def check_interpreter():
    section("Interpreter")
    emit(f"        {sys.version.splitlines()[0]}")
    record("python", platform.python_version())
    record("platform", platform.platform())
    info(f"platform  {platform.platform()}")
    info(f"machine   {platform.machine()}")
    info(f"cwd       {os.getcwd()}")

    major, minor = sys.version_info[:2]
    if (major, minor) >= (3, 9):
        ok(f"Python {major}.{minor} — new enough")
    else:
        bad(f"Python {major}.{minor} is older than the 3.9 this assumes")
    record("py_ok", (major, minor) >= (3, 9))

    section("Standard library")
    missing = []
    for name, why in REQUIRED.items():
        try:
            __import__(name)
            ok(f"{name:<11} {why}")
        except Exception as e:                      # noqa: BLE001
            bad(f"{name:<11} MISSING — {why} ({e})")
            missing.append(name)
    record("missing_required", missing)

    emit()
    present_optional = []
    for name, why in OPTIONAL.items():
        try:
            __import__(name)
            info(f"{_c('32', 'have')}  {name:<11} {why}")
            present_optional.append(name)
        except Exception:                           # noqa: BLE001
            info(f"{_c('33', 'none')}  {name:<11} {why}")
    record("optional_present", present_optional)

    try:
        import ssl
        info("")
        info(f"ssl       {ssl.OPENSSL_VERSION}")
        record("openssl", ssl.OPENSSL_VERSION)
        ctx = ssl.create_default_context()
        ok(f"SSLContext builds; max TLS {ctx.maximum_version.name}")
    except Exception as e:                          # noqa: BLE001
        bad(f"ssl is present but unusable: {e!r}")

    try:
        import hashlib
        want = {"sha1", "sha256", "sha512", "md5"}
        have = want & set(hashlib.algorithms_available)
        if have == want:
            ok("hashlib has sha1, sha256, sha512, md5")
        else:
            bad(f"hashlib is missing {sorted(want - have)}")
        hashlib.pbkdf2_hmac("sha256", b"x", b"y", 10)
        ok("pbkdf2_hmac works (GrandSlam's s2k needs it)")
    except Exception as e:                          # noqa: BLE001
        bad(f"hashlib incomplete: {e!r}")

    return not missing


# --------------------------------------------------------------------------
# 2. Crypto — correctness first, then cost
# --------------------------------------------------------------------------

_P25519 = 2 ** 255 - 19
_A24 = 121665


def _cswap(swap, x2, x3):
    dummy = swap * ((x2 - x3) % _P25519)
    return (x2 - dummy) % _P25519, (x3 + dummy) % _P25519


def x25519(k: bytes, u: bytes) -> bytes:
    """RFC 7748 X25519, pure Python.

    Included in the probe rather than merely timed with a stand-in, because it
    is both the primitive the pairing handshake needs and the best predictor of
    what every other curve operation will cost here. It checks itself against
    the RFC vector below, so a wrong answer is caught on the device rather than
    three checkpoints later.
    """
    kb = bytearray(k)
    kb[0] &= 248
    kb[31] &= 127
    kb[31] |= 64
    kk = int.from_bytes(bytes(kb), "little")
    x1 = int.from_bytes(u, "little") & ((1 << 255) - 1)
    x2, z2, x3, z3, swap = 1, 0, x1, 1, 0
    for t in range(254, -1, -1):
        kt = (kk >> t) & 1
        swap ^= kt
        x2, x3 = _cswap(swap, x2, x3)
        z2, z3 = _cswap(swap, z2, z3)
        swap = kt
        a = (x2 + z2) % _P25519
        aa = a * a % _P25519
        b = (x2 - z2) % _P25519
        bb = b * b % _P25519
        e = (aa - bb) % _P25519
        c = (x3 + z3) % _P25519
        d = (x3 - z3) % _P25519
        da = d * a % _P25519
        cb = c * b % _P25519
        x3 = (da + cb) % _P25519
        x3 = x3 * x3 % _P25519
        z3 = (da - cb) % _P25519
        z3 = z3 * z3 % _P25519
        z3 = z3 * x1 % _P25519
        x2 = aa * bb % _P25519
        z2 = e * ((aa + _A24 * e) % _P25519) % _P25519
    x2, x3 = _cswap(swap, x2, x3)
    z2, z3 = _cswap(swap, z2, z3)
    return (x2 * pow(z2, _P25519 - 2, _P25519) % _P25519).to_bytes(32, "little")


# RFC 7748 section 5.2, first vector.
_X25519_K = bytes.fromhex("a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4")
_X25519_U = bytes.fromhex("e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c")
_X25519_OUT = bytes.fromhex("c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552")

# RFC 5054 group 2048, the modulus GrandSlam's SRP uses. Only its size matters
# for the timing — a modexp here is what sign-in spends its arithmetic on.
_SRP_N_BITS = 2048


def check_crypto():
    section("Crypto — does it work, and what does it cost")
    import hashlib
    import secrets

    # Correctness before speed: a fast wrong answer is worse than a slow one.
    t0 = time.monotonic()
    got = x25519(_X25519_K, _X25519_U)
    dt = time.monotonic() - t0
    if got == _X25519_OUT:
        ok(f"X25519 matches the RFC 7748 vector — {dt * 1000:.0f} ms per operation")
    else:
        bad(f"X25519 is WRONG: got {got.hex()}")
    record("x25519_ms", round(dt * 1000))
    record("x25519_correct", got == _X25519_OUT)

    # The pairing handshake does a handful of these, not thousands. Anything
    # under a second each is comfortable; this is only alarming in the hundreds.
    if dt > 1.0:
        warn("that is slow enough to be felt — the handshake does a few of these")

    # 2048-bit modexp: one per SRP round trip.
    n = (1 << (_SRP_N_BITS - 1)) | secrets.randbits(_SRP_N_BITS - 2) | 1
    a = secrets.randbits(256)
    t0 = time.monotonic()
    pow(2, a, n)
    dt = time.monotonic() - t0
    ok(f"2048-bit modexp — {dt * 1000:.0f} ms (SRP sign-in does a few)")
    record("modexp_ms", round(dt * 1000))

    # PBKDF2 is C, so this should be quick; it is checked because GrandSlam's
    # s2k runs it on the password and a slow one would be felt at sign-in.
    t0 = time.monotonic()
    hashlib.pbkdf2_hmac("sha256", b"password", b"salt", 20000)
    dt = time.monotonic() - t0
    ok(f"PBKDF2-SHA256 x20000 — {dt * 1000:.0f} ms")
    record("pbkdf2_ms", round(dt * 1000))

    # The signer hashes every 4 KB page of every Mach-O plus every resource, so
    # its cost scales with the .ipa. This is the number that says whether
    # signing on-device takes seconds or minutes.
    blob = secrets.token_bytes(1 << 20)
    t0 = time.monotonic()
    h = hashlib.sha256()
    for _ in range(16):
        h.update(blob)
    dt = time.monotonic() - t0
    rate = 16 / dt if dt else float("inf")
    ok(f"SHA-256 — {rate:.0f} MB/s ({dt * 1000:.0f} ms for 16 MB)")
    record("sha256_mbs", round(rate))
    if rate < 20:
        warn("a 60 MB .ipa would spend over 3 s just being hashed")

    # RSA keygen is one-off per Apple ID but is pure-Python prime search, and it
    # is the single slowest thing in the design. Probability of a random odd
    # 1024-bit number being prime is ~1/355, so this estimates rather than runs.
    t0 = time.monotonic()
    trials = 0
    cand = secrets.randbits(1024) | (1 << 1023) | 1
    while trials < 40:
        pow(2, cand - 1, cand)          # one Fermat round, the dominant cost
        cand += 2
        trials += 1
    per = (time.monotonic() - t0) / trials
    est = per * 355 * 2                 # two primes for RSA-2048
    ok(f"1024-bit Fermat test — {per * 1000:.0f} ms; RSA-2048 keygen ~{est:.0f} s")
    record("rsa_keygen_est_s", round(est))
    if est > 120:
        warn("keygen would need a progress indicator, and to be done once and cached")


# --------------------------------------------------------------------------
# 3. Filesystem
# --------------------------------------------------------------------------

def check_filesystem():
    section("Filesystem")
    home = os.path.expanduser("~")
    info(f"home      {home}")
    candidates = [os.path.join(home, "Documents"), home, os.getcwd()]
    chosen = None
    for path in candidates:
        try:
            os.makedirs(path, exist_ok=True)
            probe = os.path.join(path, ".siboot-write-probe")
            with open(probe, "wb") as fh:
                fh.write(b"siboot")
            with open(probe, "rb") as fh:
                assert fh.read() == b"siboot"
            os.remove(probe)
            ok(f"writable: {path}")
            chosen = chosen or path
        except Exception as e:                      # noqa: BLE001
            warn(f"not writable: {path} ({e})")
    record("workdir", chosen)

    if chosen:
        try:
            usage = shutil.disk_usage(chosen)
            free_mb = usage.free / (1 << 20)
            # Room for the download, the unpacked bundle and the signed copy.
            if free_mb > 600:
                ok(f"{free_mb:,.0f} MB free — enough for an .ipa and its signed copy")
            else:
                warn(f"only {free_mb:,.0f} MB free; signing needs roughly 3x the .ipa")
            record("free_mb", round(free_mb))
        except Exception as e:                      # noqa: BLE001
            warn(f"could not measure free space: {e}")
    return chosen


# --------------------------------------------------------------------------
# 4. What this shell can run
# --------------------------------------------------------------------------

# Commands worth knowing about by name, and what each would change.
OF_INTEREST = {
    "python":   "the interpreter this is running in",
    "pip":      "pure-Python wheels only, so not depended on",
    "curl":     "fetching the .ipa",
    "openssl":  "would spare us writing RSA, CSRs and PKCS#7 by hand",
    "ifconfig": "enumerating this device's own addresses",
    "ping":     "reachability, and proof the app holds Local Network permission",
    "nslookup": "DNS without the resolver",
    "scp":      "moving files off the device",
    "unzip":    "the .ipa is a zip; Python's zipfile covers it anyway",
    "vim":      "reading a log on the device",
}

# How commands get run here, decided once. `None` until detect_runner has run.
_RUNNER = None


def _read_and_clear(path):
    try:
        with open(path, "r", errors="replace") as fh:
            text = fh.read().strip()
    except Exception:                               # noqa: BLE001
        return ""
    try:
        os.remove(path)
    except OSError:
        pass
    return text


def detect_runner(workdir):
    """Find the one mechanism that can reach an ios_system built-in.

    Three are tried, because it is not obvious which a-Shell honours and the
    answer changes what the rest of the program may assume. `os.system` first:
    ios_system substitutes itself at the libc level, so it is the one most
    likely to reach a built-in. `subprocess` is expected to fail — there is no
    fork here — and `os.popen` needs a pipe, which may not exist either.
    """
    global _RUNNER
    out_path = os.path.join(workdir or ".", ".siboot-cmd-out")
    token = "siboot-probe-ok"

    try:
        os.system(f"echo {token} > {out_path} 2>&1")
        if token in _read_and_clear(out_path):
            _RUNNER = "os.system"
            return _RUNNER
    except Exception:                               # noqa: BLE001
        pass

    try:
        import subprocess
        r = subprocess.run(f"echo {token}", shell=True, capture_output=True, timeout=30)
        if token in (r.stdout + r.stderr).decode(errors="replace"):
            _RUNNER = "subprocess"
            return _RUNNER
    except Exception:                               # noqa: BLE001
        pass

    try:
        with os.popen(f"echo {token}") as fh:
            if token in fh.read():
                _RUNNER = "os.popen"
                return _RUNNER
    except Exception:                               # noqa: BLE001
        pass

    _RUNNER = None
    return None


def run_command_rc(cmd, workdir):
    """Run one command with whatever detect_runner settled on -> (rc, text).

    `rc` is None when the mechanism cannot report one. It matters because a
    missing command still writes to stderr, so output alone cannot tell
    "openssl printed its version" from "sh: openssl: command not found".
    """
    if _RUNNER == "os.system":
        out_path = os.path.join(workdir or ".", ".siboot-cmd-out")
        try:
            raw = os.system(f"{cmd} > {out_path} 2>&1")
        except Exception:                           # noqa: BLE001
            return None, ""
        # POSIX wait status on a real shell; ios_system may hand back the exit
        # code directly, so only shift when it is plainly a wait status.
        rc = (raw >> 8) if raw > 255 else raw
        return rc, _read_and_clear(out_path)
    if _RUNNER == "subprocess":
        try:
            import subprocess
            r = subprocess.run(cmd, shell=True, capture_output=True, timeout=60)
            return r.returncode, (r.stdout + r.stderr).decode(errors="replace").strip()
        except Exception:                           # noqa: BLE001
            return None, ""
    if _RUNNER == "os.popen":
        try:
            with os.popen(cmd) as fh:
                return None, fh.read().strip()
        except Exception:                           # noqa: BLE001
            return None, ""
    return None, ""


def run_command(cmd, workdir):
    """Just the output. ("" when nothing can be run.)"""
    return run_command_rc(cmd, workdir)[1]


# One safe, non-interactive probe per command. `nslookup` and `scp` would sit
# at a prompt if run bare, and `ping` would run forever, so each is pinned.
PROBE = {
    "python": "python --version",
    "pip": "pip --version",
    "curl": "curl --version",
    "openssl": "openssl version",
    "ifconfig": "ifconfig -l",
    "ping": "ping -c 1 -t 1 127.0.0.1",
    "nslookup": "nslookup -version",
    "scp": "scp",
    "unzip": "unzip -v",
    "vim": "vim --version",
}

_ABSENT = ("not found", "no such file", "unknown command", "not recognized")


def command_exists(name, workdir):
    rc, text = run_command_rc(PROBE.get(name, f"{name} --version"), workdir)
    low = text.lower()
    if any(marker in low for marker in _ABSENT):
        return False
    if rc == 0:
        return True
    if rc == 127:
        return False
    # A usage message on a non-zero exit still proves the command is there.
    return bool(text)


def check_filesystem_quiet():
    """Just the writable directory, for report-only paths."""
    home = os.path.expanduser("~")
    for path in (os.path.join(home, "Documents"), home, os.getcwd()):
        try:
            probe = os.path.join(path, ".siboot-write-probe")
            with open(probe, "wb") as fh:
                fh.write(b"siboot")
            os.remove(probe)
            return path
        except Exception:                           # noqa: BLE001
            continue
    return None


def check_tooling(workdir):
    section("What this shell can run")
    runner = detect_runner(workdir)
    if runner:
        ok(f"commands are reachable from Python via {runner}")
    else:
        warn("no way to run a command from Python — neither os.system,")
        info("subprocess nor os.popen reached a built-in. Everything below")
        info("falls back to pure Python, which is the plan anyway.")
    record("runner", runner)

    # a-Shell answers this itself, which beats probing one command at a time:
    # it lists what is actually built in, including things worth knowing about
    # that were never guessed at.
    listing = run_command("help -l", workdir) if runner else ""
    commands = set()
    if listing:
        for token in re.split(r"[\s,]+", listing):
            token = token.strip().strip("`'\"()[]{}.:;")
            if token and re.fullmatch(r"[A-Za-z][A-Za-z0-9_.+-]*", token):
                commands.add(token)
    # a-Shell's `help -l` prints its whole built-in list, which is worth having.
    # A desktop shell's `help` means something else entirely and would answer
    # with a handful of shell keywords, so the listing is only believed when it
    # is long enough to be the real thing.
    if len(commands) >= 20:
        ok(f"`help -l` lists {len(commands)} commands")
        record("command_count", len(commands))
    else:
        if commands:
            info(f"`help -l` answered with only {len(commands)} entries — that is a")
            info("shell's own help, not a-Shell's command list. Probing directly.")
        else:
            info("`help -l` returned nothing usable; probing directly instead.")
        commands = set()
        record("command_count", None)
        if runner:
            for name in OF_INTEREST:
                if command_exists(name, workdir):
                    commands.add(name)

    emit()
    present = []
    for name, why in sorted(OF_INTEREST.items()):
        if name in commands:
            ok(f"{name:<9} {why}")
            present.append(name)
        else:
            info(f"{_c('33', 'none')}  {name:<9} {why}")
    record("commands", present)

    emit()
    if "openssl" in present:
        info("openssl is here, but the signer still gets written in Python:")
        info("nothing can pipe a Mach-O CodeDirectory through a CLI.")
    else:
        info("No openssl. RSA keygen, CSR building and PKCS#7 all become")
        info("Python — which was the plan; this only confirms there is no")
        info("shortcut. `zsign` was never an option here either: no compiler.")

# --------------------------------------------------------------------------
# 5. The internet
# --------------------------------------------------------------------------

def check_internet():
    section("Internet")
    import ssl

    # Exactly the hosts the finished pipeline talks to, so a corporate proxy or
    # a content filter shows up here rather than half way through sign-in.
    targets = [
        ("gsa.apple.com", 443, "Apple sign-in (GrandSlam)"),
        ("developerservices2.apple.com", 443, "the developer portal"),
        ("github.com", 443, "the .ipa download"),
    ]
    reached = []
    needed_apple_root = []
    for host, port, why in targets:
        t0 = time.monotonic()
        try:
            with socket.create_connection((host, port), timeout=10) as raw:
                with ssl.create_default_context().wrap_socket(raw, server_hostname=host) as tls:
                    ver = tls.version()
            dt = (time.monotonic() - t0) * 1000
            ok(f"{host:<32} {ver}  {dt:.0f} ms   — {why}")
            reached.append(host)
            continue
        except ssl.SSLCertVerificationError as e:
            first = f"{type(e).__name__}: {getattr(e, 'verify_message', None) or e}"
        except Exception as e:                      # noqa: BLE001
            bad(f"{host:<32} {type(e).__name__}: {e}")
            continue

        # The trust store rejected it. Before calling that a failure, try again
        # with Apple's own root added — on this host that is the whole problem.
        try:
            with socket.create_connection((host, port), timeout=10) as raw:
                with apple_aware_context().wrap_socket(raw, server_hostname=host) as tls:
                    ver = tls.version()
            dt = (time.monotonic() - t0) * 1000
            ok(f"{host:<32} {ver}  {dt:.0f} ms   — {why}")
            info(f"{'':<8}the system store rejected it ({first});")
            info(f"{'':<8}it verifies against the pinned Apple Root CA.")
            reached.append(host)
            needed_apple_root.append(host)
        except Exception as e:                      # noqa: BLE001
            bad(f"{host:<32} {first}")
            info(f"{'':<8}and still fails with Apple's root pinned: {type(e).__name__}")
    record("internet", reached)
    record("needed_apple_root", needed_apple_root)
    if needed_apple_root:
        emit()
        info("Pinning Apple's root is what sign-in will do from now on; the")
        info("certificate is embedded in this file, so nothing is downloaded.")
    return len(reached) == len(targets)


# --------------------------------------------------------------------------
# 6. The local network — the reason this host was chosen
# --------------------------------------------------------------------------

def source_address_for(target, port=9):
    """The address this device would send from to reach `target`.

    The fallback for when `ifconfig` cannot be run. A connected UDP socket sends
    nothing, so this is free and silent, and it picks the route the kernel would
    actually pick — but it only ever names the one interface the default route
    uses, which is why ifconfig is preferred.
    """
    fam = socket.AF_INET6 if ":" in target else socket.AF_INET
    s = socket.socket(fam, socket.SOCK_DGRAM)
    try:
        s.settimeout(1.0)
        s.connect((target, port))
        return s.getsockname()[0]
    except Exception:                               # noqa: BLE001
        return None
    finally:
        s.close()


def describe_iface(name):
    """What an interface name means on iOS."""
    if name == "default":
        return "Wi-Fi"
    if name == "vpn":
        return "VPN tunnel"
    if name.startswith("lo"):
        return "loopback"
    if name.startswith("en"):
        return "Wi-Fi"
    if name.startswith(("utun", "ipsec", "tap", "tun")):
        return "VPN tunnel"
    if name.startswith("pdp_ip"):
        return "cellular"
    if name.startswith(("awdl", "llw")):
        return "AirDrop / AWDL"
    if name.startswith("bridge"):
        return "bridge"
    if name.startswith("ap"):
        return "personal hotspot"
    return "unknown kind"


def local_addresses(workdir):
    """Every address on this device, read from `ifconfig`.

    Worth using rather than guessing: ifconfig names the interface each address
    sits on, so a loopback VPN's utun is distinguishable from Wi-Fi, and a
    cellular-only device is visible as such instead of looking like a failure.
    Returns [(iface, family, address)], falling back to the UDP-connect trick.
    """
    text = run_command("ifconfig", workdir)
    found = []
    if text:
        iface = None
        for line in text.splitlines():
            head = re.match(r"^([A-Za-z][\w.]*):\s", line)
            if head:
                iface = head.group(1)
                continue
            if not iface:
                continue
            m4 = re.search(r"\binet (\d+\.\d+\.\d+\.\d+)", line)
            if m4:
                found.append((iface, "inet", m4.group(1)))
                continue
            m6 = re.search(r"\binet6 ([0-9a-fA-F:]+)", line)
            if m6:
                found.append((iface, "inet6", m6.group(1)))
    if found:
        return found

    # No ifconfig. Ask the routing table the only two questions that matter.
    for target, label in [("8.8.8.8", "default"), (VPN_PEER_IP, "vpn")]:
        addr = source_address_for(target)
        if addr:
            found.append((label, "inet", addr))
    return found


HTTP2_MAGIC = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
# An empty SETTINGS frame: 3-byte length 0, type 0x04, flags 0, stream 0. The
# client preface is the magic *plus* this frame, and a strict server is entitled
# to object to the magic on its own.
HTTP2_SETTINGS = b"\x00\x00\x00\x04\x00\x00\x00\x00\x00"


def errno_name(e):
    # socket.timeout is an OSError subclass with no errno, so asking for the
    # code first gives "errno None" for the commonest failure of all.
    code = getattr(e, "errno", None)
    if code is None:
        return type(e).__name__
    try:
        import errno
        return errno.errorcode.get(code, f"errno {code}")
    except Exception:                               # noqa: BLE001
        return str(e)


def probe_variant(host, port, payload, connect_timeout=None, read_timeout=None):
    """Connect, optionally send `payload`, then read. -> (verdict, detail).

    Verdicts: connect-failed, reset, closed, silent, data.
    """
    connect_timeout = connect_timeout or CONNECT_TIMEOUT
    read_timeout = read_timeout or READ_TIMEOUT
    fam = socket.AF_INET6 if ":" in host else socket.AF_INET
    s = socket.socket(fam, socket.SOCK_STREAM)
    s.settimeout(connect_timeout)
    t0 = time.monotonic()
    try:
        s.connect((host, port))
    except socket.timeout:
        s.close()
        return "connect-failed", f"no answer in {connect_timeout:.0f}s (a silent drop)"
    except OSError as e:
        s.close()
        return "connect-failed", f"{errno_name(e)}"
    try:
        s.settimeout(read_timeout)
        if payload:
            s.sendall(payload)
        data = s.recv(256)
    except socket.timeout:
        return "silent", f"held open, nothing sent to us in {read_timeout:.0f}s"
    except OSError as e:
        return "reset", f"{errno_name(e)} after {(time.monotonic() - t0) * 1000:.0f} ms"
    finally:
        s.close()
    if not data:
        return "closed", f"closed cleanly after {(time.monotonic() - t0) * 1000:.0f} ms"
    if len(data) >= 4 and data[3] == 0x04:
        return "data", f"{len(data)} bytes — an HTTP/2 SETTINGS frame"
    return "data", f"{len(data)} bytes — {data[:24]!r}"


def analyse_port(host, port=RSD_PORT):
    """The three experiments that tell a peer rejection from a protocol fault.

    v0.2 could not tell them apart. It wrote the preface and *then* read, so a
    reset that arrived the moment the connection was accepted looked exactly
    like one provoked by what we sent — and the run reported "connected, then
    ECONNRESET" for both.

    Reading first, having sent nothing, settles it:

      * reset before we write   the service is refusing this peer, and nothing
                                we could send would change that;
      * held open in silence    it is waiting for us, so the fault is in what we
                                send next, and the two preface variants say
                                which;
      * data unprompted         it speaks first, and we are simply mis-reading.
    """
    return [
        ("read first, send nothing", probe_variant(host, port, b"")),
        ("HTTP/2 magic only", probe_variant(host, port, HTTP2_MAGIC)),
        ("magic + SETTINGS", probe_variant(host, port, HTTP2_MAGIC + HTTP2_SETTINGS)),
    ]


# --------------------------------------------------------------------------
# Finding what else listens

FOCUSED_PORTS = list(range(49152, 49301)) + [58783, 62078, 27015, 5000, 7000]


def scan(host, ports, workers=48, timeout=0.5):
    """Which ports accept, and which of those stay open once accepted.

    A port that accepts and then holds the connection open is the interesting
    one: everything that accepts-then-resets is behaving like 49152 already
    does, and tells us nothing new.
    """
    import queue
    import threading

    todo = queue.Queue()
    for port in ports:
        todo.put(port)
    found = []
    lock = threading.Lock()

    def worker():
        while True:
            try:
                port = todo.get_nowait()
            except queue.Empty:
                return
            fam = socket.AF_INET6 if ":" in host else socket.AF_INET
            sk = socket.socket(fam, socket.SOCK_STREAM)
            sk.settimeout(timeout)
            try:
                sk.connect((host, port))
            except Exception:                       # noqa: BLE001
                sk.close()
                continue
            # It accepted. Does it stay?
            state = "open"
            try:
                sk.settimeout(0.8)
                data = sk.recv(64)
                state = "speaks" if data else "closed"
            except socket.timeout:
                state = "open"
            except OSError:
                state = "reset"
            finally:
                sk.close()
            with lock:
                found.append((port, state))

    threads = [threading.Thread(target=worker, daemon=True) for _ in range(workers)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=120)
    return sorted(found)


def check_scan(hosts, all_ports=False):
    section("What else is listening")
    ports = list(range(1, 65536)) if all_ports else FOCUSED_PORTS
    info(f"{len(ports)} ports per address. A port that accepts and then holds the")
    info("connection open is the one worth having: accept-then-reset is what")
    info(f"{RSD_PORT} already does.")
    emit()
    summary = {}
    for host in hosts:
        t0 = time.monotonic()
        found = scan(host, ports)
        dt = time.monotonic() - t0
        if not found:
            info(f"{host:<22} nothing accepted ({dt:.0f}s)")
            continue
        ok(f"{host:<22} {len(found)} accepted ({dt:.0f}s)")
        for port, state in found:
            marker = "  <- holds the connection open" if state in ("open", "speaks") else ""
            info(f"{'':<22} {port:<7} {state}{marker}")
        summary[host] = [f"{p}:{st}" for p, st in found]
    record("scan", summary)


MAX_CANDIDATES = 6


def check_local_network(workdir):
    section("This iPhone's own services  <- the make-or-break")

    addresses = local_addresses(workdir)
    if addresses:
        for iface, family, addr in addresses:
            # fe80:: is link-local: every interface has one, none is reachable
            # from here, and printing them all buries the addresses that matter.
            if family == "inet6" and addr.lower().startswith("fe80"):
                continue
            suffix = "" if family == "inet" else "  (IPv6)"
            info(f"{iface:<10} {addr:<26} {describe_iface(iface)}{suffix}")
    else:
        warn("no local addresses found at all — is Wi-Fi off?")
    record("ifaces", [f"{i}:{a}" for i, f, a in addresses if f == "inet"])

    wifi = [a for i, f, a in addresses if f == "inet" and describe_iface(i) == "Wi-Fi"]
    vpn = [a for i, f, a in addresses if f == "inet" and describe_iface(i) == "VPN tunnel"]
    other = [a for i, f, a in addresses
             if f == "inet" and describe_iface(i) in ("cellular", "personal hotspot", "unknown kind")
             and not a.startswith("127.")]
    record("wifi_addr", wifi[0] if wifi else None)
    record("vpn_addr", vpn[0] if vpn else None)

    emit()
    candidates = []
    for addr in wifi:
        candidates.append((addr, "this iPhone's own Wi-Fi address - no VPN needed"))
    if vpn:
        candidates.append((VPN_PEER_IP, "the LocalDevVPN peer - the Rust build's route"))
    else:
        candidates.append((VPN_PEER_IP, "the LocalDevVPN peer (no VPN interface is up)"))
    candidates.append(("127.0.0.1", "plain loopback"))
    candidates.append(("::1", "loopback over IPv6"))
    for addr in other:
        candidates.append((addr, "another local interface"))
    candidates = candidates[:MAX_CANDIDATES]

    results = {}
    reached = False
    refuses_peer = []
    for host, why in candidates:
        emit(f"  {_c('1;37', host + ':' + str(RSD_PORT))}   {why}")
        variants = analyse_port(host)
        first_verdict = variants[0][1][0]
        if first_verdict == "connect-failed":
            info(f"{'':<4}{variants[0][1][1]}")
            results[host] = "unreachable"
            emit()
            continue
        for label, (verdict, detail) in variants:
            mark = {"data": "ok", "silent": "..", "reset": "no", "closed": "no"}.get(verdict, "??")
            info(f"{label:<26} {mark}  {detail}")
        results[host] = first_verdict
        if any(v[1][0] == "data" for v in variants):
            reached = True
        if first_verdict in ("reset", "closed"):
            refuses_peer.append(host)
        emit()

    record("rsd", results)
    record("rsd_reached", reached)
    record("refuses_peer", refuses_peer)

    if reached:
        ok("RemoteXPC answered — the way in is open.")
        return True

    if refuses_peer:
        bad("Every address accepts the connection and then drops it before")
        bad("reading a byte from us.")
        emit()
        info("That is a different failure from the one this port was chosen to")
        info("test, and it is worth being exact about what it rules out:")
        info("")
        info("  * It is not Local Network permission. Permission governs whether")
        info("    the connection is allowed at all, and these connections are")
        info("    allowed — loopback and 127.0.0.1 behave identically, and")
        info("    neither is gated by that permission in the first place.")
        info("  * It is not the HTTP/2 preface. The connection is gone before")
        info("    anything is sent, so nothing we could write would help.")
        info("")
        info("Something on this device is accepting on 49152 and then refusing")
        info("this process specifically. The two things worth checking next:")
        info("")
        info("  1. Developer Mode, at Settings > Privacy & Security. If it is")
        info("     off, turn it on (it needs a reboot) and run this again — it")
        info("     is the cheapest explanation and it has not been ruled out.")
        info("  2. What else listens. Run with --scan; a port that accepts and")
        info("     stays open is a lead this one is not.")
    else:
        bad("Nothing accepted on port 49152 at all.")
        info("Check Wi-Fi, and that Developer Mode is on.")
    return False


# --------------------------------------------------------------------------
# 6b. Why does it reset?  (--probe)
# --------------------------------------------------------------------------
#
# The self-test found one address that behaves differently from every other:
# the LocalDevVPN peer holds the connection open and waits, where loopback and
# the Wi-Fi address both close immediately. So `10.7.0.1:49152` is a live
# service expecting us to speak first, and it drops us when we do.
#
# These frames are lifted byte-for-byte from the implementation that is known
# to drive this service — `rust-core/vendor/idevice/src/xpc/http2/frame.rs` and
# `RemoteXpcClient::do_handshake`. Guessing at the opening bytes is what the
# last run did; replaying the real ones removes that variable.


def h2_settings(settings, stream=0, flags=0):
    """SETTINGS frame. `settings` is [(id, value)]."""
    body = b"".join(struct.pack(">HI", ident, value) for ident, value in settings)
    return struct.pack(">I", len(body))[1:] + bytes([0x04, flags]) + struct.pack(">I", stream) + body


def h2_window_update(increment, stream=0):
    return b"\x00\x00\x04\x08\x00" + struct.pack(">I", stream) + struct.pack(">I", increment)


def h2_headers(stream):
    # idevice sends length 0, type 0x01, flags 0x04 (END_HEADERS) — purely to
    # open the channel; the spec's header block is not used.
    return b"\x00\x00\x00\x01\x04" + struct.pack(">I", stream)


# do_handshake's opening, in order.
IDEVICE_SETTINGS = h2_settings([(0x03, 100), (0x04, 1048576)])
IDEVICE_WINDOW_UPDATE = h2_window_update(983041)
IDEVICE_OPEN_ROOT = h2_headers(1)

LOCKDOWN_QUERYTYPE = (
    b'<?xml version="1.0" encoding="UTF-8"?>'
    b'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
    b'"http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    b'<plist version="1.0"><dict><key>Request</key><string>QueryType</string>'
    b"</dict></plist>"
)


def probe_tls(host, port):
    """Does this service want a TLS ClientHello?

    The distinction the error makes is the point. "wrong version number" means
    it answered in plaintext and is not TLS at all. A TLS *alert* means it is
    TLS and merely rejected us — which would explain everything: a service
    waiting for a ClientHello would sit silent, then reset the moment it were
    handed `PRI * HTTP/2.0`.
    """
    import ssl
    try:
        raw = socket.create_connection((host, port), timeout=CONNECT_TIMEOUT)
    except OSError as e:
        return "connect-failed", errno_name(e)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        ctx.set_ciphers("ALL:@SECLEVEL=0")
    except Exception:                               # noqa: BLE001
        pass
    try:
        raw.settimeout(READ_TIMEOUT)
        with ctx.wrap_socket(raw, server_hostname=host) as tls:
            return "data", f"TLS HANDSHAKE COMPLETED — {tls.version()}"
    except ssl.SSLError as e:
        text = str(e)
        if "wrong version number" in text or "record layer failure" in text:
            return "reset", "not TLS (it answered in plaintext)"
        return "data", f"SPOKE TLS AND REJECTED US — {text[:90]}"
    except socket.timeout:
        return "silent", "no reply to a ClientHello within the read timeout"
    except OSError as e:
        return "reset", f"{errno_name(e)} — no TLS reply"
    finally:
        try:
            raw.close()
        except OSError:
            pass


def probe_split(host, port):
    """The magic in two halves, 200 ms apart.

    Separates "it dislikes these bytes" from "it dislikes a first packet of
    this shape" — a peer doing a cheap first-datagram check behaves
    differently when the same bytes arrive in two segments.
    """
    try:
        s = socket.create_connection((host, port), timeout=CONNECT_TIMEOUT)
    except OSError as e:
        return "connect-failed", errno_name(e)
    try:
        s.settimeout(READ_TIMEOUT)
        s.sendall(HTTP2_MAGIC[:12])
        time.sleep(0.2)
        s.sendall(HTTP2_MAGIC[12:])
        data = s.recv(256)
    except socket.timeout:
        return "silent", "held open after both halves"
    except OSError as e:
        return "reset", errno_name(e)
    finally:
        s.close()
    if not data:
        return "closed", "closed cleanly"
    return "data", f"{len(data)} bytes back"


def reachable(host, port, timeout=3.0):
    """One connect, so a wrong address costs 3 seconds instead of three minutes."""
    fam = socket.AF_INET6 if ":" in host else socket.AF_INET
    sk = socket.socket(fam, socket.SOCK_STREAM)
    sk.settimeout(timeout)
    try:
        sk.connect((host, port))
        return True, ""
    except OSError as e:
        return False, errno_name(e)
    finally:
        sk.close()


def check_probe(host, port=RSD_PORT):
    section(f"Why {host}:{port} resets")

    # Every row below opens its own connection and waits out its own timeout.
    # Against an address that answers nothing that is forty-odd timeouts in a
    # row, so establish once that there is something there at all.
    alive, why = reachable(host, port)
    if not alive:
        bad(f"nothing is accepting on {host}:{port} ({why})")
        info("With LocalDevVPN disconnected this is what you get — the peer")
        info("address exists only while the tunnel is up. Connect it and")
        info("re-run. Skipping the rest; there is nothing to ask.")
        return False

    info("Each row is a fresh connection. The service holds an idle connection")
    info("open, so whatever kills it is in what we send — and the control rows")
    info("say whether it is these particular bytes or any bytes at all.")
    emit()

    magic_settings = HTTP2_MAGIC + IDEVICE_SETTINGS
    magic_wu = magic_settings + IDEVICE_WINDOW_UPDATE
    magic_full = magic_wu + IDEVICE_OPEN_ROOT
    lockdown = struct.pack(">I", len(LOCKDOWN_QUERYTYPE)) + LOCKDOWN_QUERYTYPE
    randbytes = os.urandom(24)

    def send(payload):
        return lambda: probe_variant(host, port, payload)

    # Sorted by payload length, not by protocol. Sorting by protocol is what
    # hid the pattern for two runs: the rows that survived were simply the
    # short ones, and grouping HTTP/2 things together made that invisible.
    battery = [
        ("connect, send nothing", 0, lambda: probe_variant(host, port, b"", read_timeout=4)),
        ("a single zero byte", 1, send(b"\x00")),
        ("CRLF", 2, send(b"\r\n")),
        ("empty SETTINGS, no magic", len(h2_settings([])), send(h2_settings([]))),
        ("PING frame, no magic", len(h2_ping()), send(h2_ping())),
        ("SETTINGS frame, no magic", len(IDEVICE_SETTINGS), send(IDEVICE_SETTINGS)),
        ("24 random bytes", len(randbytes), send(randbytes)),
        ("HTTP/2 magic only", len(HTTP2_MAGIC), send(HTTP2_MAGIC)),
        ("magic + SETTINGS (idevice's)", len(magic_settings), send(magic_settings)),
        ("+ WINDOW_UPDATE", len(magic_wu), send(magic_wu)),
        ("+ HEADERS(1) — full opening", len(magic_full), send(magic_full)),
        ("lockdown plist", len(lockdown), send(lockdown)),
        ("magic, split in two", None, lambda: probe_split(host, port)),
        ("TLS ClientHello", None, lambda: probe_tls(host, port)),
    ]

    results = {}
    lengths = {}
    for entry in battery:
        label, run = entry[0], entry[-1]
        nbytes = entry[1] if len(entry) == 3 else None
        try:
            verdict, detail = run()
        except Exception as e:                      # noqa: BLE001
            verdict, detail = "error", f"{type(e).__name__}: {e}"
        mark = {"data": "ok", "silent": "..", "reset": "no",
                "closed": "no", "connect-failed": "??"}.get(verdict, "??")
        colour = "1;32" if verdict == "data" else ("1;33" if verdict == "silent" else "33")
        size = f"{nbytes:>4}B" if nbytes is not None else "   ?"
        info(f"{label:<28} {size}  {_c(colour, mark)}  {detail}")
        results[label] = verdict
        lengths[label] = nbytes
    record("probe", results)
    record("probe_lengths", lengths)

    emit()
    talkers = [k for k, v in results.items() if v == "data"]
    survivors = [k for k, v in results.items() if v == "silent"]
    trivial_killed = results.get("a single zero byte") in ("reset", "closed")

    # Length explains the survivors far more often than content does, and
    # saying "some payloads are tolerated" without checking that was wrong
    # twice. If every survivor is shorter than every casualty, say so plainly.
    sized_ok = [lengths[k] for k in survivors if lengths.get(k) is not None]
    sized_dead = [lengths[k] for k, v in results.items()
                  if v in ("reset", "closed") and lengths.get(k) is not None]
    length_explains = bool(sized_ok and sized_dead and max(sized_ok) < min(sized_dead))

    if talkers:
        ok("Something got an answer: " + "; ".join(talkers))
        info("That is the thread to pull — it is the only row where the device")
        info("said anything back rather than hanging up.")
        if any("no magic" in t for t in talkers):
            info("")
            info(_c("1;37", "And it answered a frame sent with no preface, which says the"))
            info(_c("1;37", "connection was already established as far as it is concerned."))
    elif trivial_killed:
        bad("Even a single zero byte kills the connection.")
        info("So this is not about HTTP/2, or about any protocol we might speak:")
        info("the peer drops us on first data whatever it is. That points at the")
        info("transport rather than the service — most likely LocalDevVPN's")
        info("rewriting, which NOTES.md already records as unreliable (its")
        info("on-demand rules never match our traffic, so iOS is free to tear")
        info("the tunnel down). Worth re-running with the VPN freshly")
        info("reconnected before concluding anything about the device.")
    elif length_explains:
        ok(f"Every payload of {max(sized_ok)} bytes or fewer survives; every one of")
        ok(f"{min(sized_dead)} bytes or more is reset — whatever the bytes are.")
        info("So this is length, not content, and no protocol we could speak")
        info("would change it. The rows are sorted by what they contain, which")
        info("makes that easy to miss: read the byte column instead.")
    elif survivors:
        ok("Some payloads are tolerated: " + "; ".join(survivors))
        info("They are not all shorter than the casualties, so content may")
        info("matter after all — which would be new.")
    else:
        bad("Every payload resets, but an idle connection survives.")
        info("The peer reads, dislikes everything offered, and never speaks")
        info("first. Next: capture what SideInstaller itself sends on this port")
        info("from the app side, and replay it byte-for-byte.")
    return True


def h2_ping(payload=b"siboot!!"):
    """A PING frame — the one frame that *demands* an immediate reply.

    RFC 7540 6.7: a peer receiving PING must answer with PING+ACK. So on an
    established HTTP/2 connection this is a guaranteed round trip, and it needs
    no streams, no HPACK and no state. If the service answers this without ever
    having been sent the 24-byte preface, then it never wanted the preface —
    it believes the connection is already up, and that is why every payload
    beginning with `PRI * HTTP/2.0` is garbage to it.
    """
    return b"\x00\x00\x08\x06\x00" + struct.pack(">I", 0) + payload[:8].ljust(8, b"\x00")


def sweep_length(host, port, lengths, filler, read_timeout=1.5):
    """Where exactly does payload length stop being tolerated?

    Content is held constant so only length varies. The reset arrived within
    25 ms every time it arrived at all, so 1.5 s is a generous read window and
    keeps the whole sweep well under a minute.
    """
    out = []
    for n in lengths:
        body = (filler * (n // len(filler) + 1))[:n]
        verdict, _ = probe_variant(host, port, body, read_timeout=read_timeout)
        out.append((n, verdict))
    return out


def drip(host, port, payload, delay=0.05, read_timeout=1.0):
    """One connection, one byte at a time.

    The discriminator between "the service counts bytes" and "something in the
    path cannot carry a segment this size". Same total bytes, same content,
    different packet shape: if 24 bytes dripped one at a time survive where 24
    bytes at once do not, the fault is in the transport — LocalDevVPN's
    rewriting — and nothing about the service. If it dies at the same
    cumulative count either way, the service is doing the counting.
    """
    try:
        s = socket.create_connection((host, port), timeout=CONNECT_TIMEOUT)
    except OSError as e:
        return None, f"connect failed: {errno_name(e)}"
    try:
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    except OSError:
        pass
    sent = 0
    try:
        for i in range(len(payload)):
            s.sendall(payload[i:i + 1])
            sent += 1
            time.sleep(delay)
        s.settimeout(read_timeout)
        try:
            data = s.recv(64)
        except socket.timeout:
            return sent, f"all {sent} bytes accepted, held open"
        if data:
            return sent, f"all {sent} bytes accepted, {len(data)} bytes back"
        return sent, f"all {sent} bytes accepted, then closed cleanly"
    except OSError as e:
        return sent, f"died after {sent} bytes ({errno_name(e)})"
    finally:
        s.close()


def check_threshold(host, port=RSD_PORT):
    section(f"Where {host}:{port} draws the line")
    info("The battery resets on every payload of 12 bytes or more and tolerates")
    info("every payload of 2 or fewer, whatever the bytes are — the correct")
    info("HTTP/2 magic dies exactly like 24 random bytes. So it is not judging")
    info("content. These rows find the exact length, and then whether length is")
    info("even the right way to describe it.")
    emit()

    lengths = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 16, 24]
    zeros = sweep_length(host, port, lengths, b"\x00")
    info("zero bytes")
    info("   " + "  ".join(f"{n}:{'ok' if v == 'silent' else 'RST'}" for n, v in zeros))
    emit()
    randoms = sweep_length(host, port, lengths, os.urandom(64))
    info("random bytes — same lengths, different content")
    info("   " + "  ".join(f"{n}:{'ok' if v == 'silent' else 'RST'}" for n, v in randoms))
    emit()

    def first_reset(rows):
        for n, v in rows:
            if v != "silent":
                return n
        return None

    z, r = first_reset(zeros), first_reset(randoms)
    record("threshold_zeros", z)
    record("threshold_random", r)

    if z:
        ok(f"zeros are refused from {z} bytes; random from {r}")
        if z == r:
            info("The same length for both, so content really is irrelevant.")
        HINTS = {
            9: "9 bytes is exactly an HTTP/2 frame header (3-byte length, type,\n"
               "flags, 4-byte stream id). The service is parsing our first bytes\n"
               "as a FRAME, which means it never expected the 24-byte preface.",
            16: "16 bytes is the XPC wire header (magic, flags, 8-byte length).",
            4: "4 bytes is a bare length prefix.",
            8: "8 bytes is a length/type pair.",
        }
        if z in HINTS:
            emit()
            for ln in HINTS[z].split("\n"):
                info(_c("1;37", ln))
    else:
        ok("nothing up to 24 bytes was refused — the battery's resets came from")
        info("content after all, and the earlier reading was wrong.")

    emit()
    sent, detail = drip(host, port, HTTP2_MAGIC)
    info(f"the 24-byte magic, one byte at a time   {detail}")
    record("drip", detail)
    if sent == len(HTTP2_MAGIC):
        emit()
        ok("Dripped, the whole magic is accepted. Sent in one segment it is not.")
        info("Same bytes, same total, different packet shape — so this is the")
        info("transport, not the service. LocalDevVPN is the only thing in that")
        info("path, and NOTES.md already records it as unreliable.")
    elif sent is not None and z is not None and sent >= z:
        emit()
        ok(f"Dripping dies at {sent} bytes, near the {z}-byte threshold.")
        info("So the service is counting bytes, not segments, and the framing")
        info("of the write does not matter.")



# --------------------------------------------------------------------------
# 6d. Is the VPN carrying data at all?  (the control)
# --------------------------------------------------------------------------
#
# Everything so far has measured one service through one path and cannot tell
# them apart. The threshold is 11 bytes, content-independent, and cumulative
# rather than per-packet — which is not how any protocol behaves. No service
# rejects at exactly 11 bytes.
#
# So put a server we control at the far end of the *same* path. LocalDevVPN
# rewrites by address, not by port (`NOTES.md`: dst == fakeIP -> deviceIP), so a
# listener bound here should be reachable at 10.7.0.1 on its own port, through
# exactly the rewriting that 49152 goes through. Then the same length sweep
# answers a question with no ambiguity left in it:
#
#   * our own server also loses the connection around 11 bytes
#         -> LocalDevVPN is corrupting the stream, the device is innocent, and
#            every conclusion drawn about `remoted` so far is about the VPN.
#   * our own server receives everything
#         -> the path is sound and `remoted` really is doing this.
#   * 10.7.0.1 never reaches our listener at all
#         -> the rewrite target is not this device, and 49152 has been
#            answering from somewhere else entirely.

CONTROL_SIZES = [1, 8, 10, 11, 16, 64, 1024, 8192]


def _control_server(sock, results, stop):
    """Accept, read for a moment, then report the count back to the client."""
    while not stop.is_set():
        try:
            conn, peer = sock.accept()
        except OSError:
            return
        try:
            conn.settimeout(1.5)
            got = 0
            deadline = time.monotonic() + 1.5
            while time.monotonic() < deadline:
                try:
                    chunk = conn.recv(65536)
                except socket.timeout:
                    break
                except OSError:
                    break
                if not chunk:
                    break
                got += len(chunk)
            results.append((peer[0], got))
            try:
                conn.sendall(struct.pack(">I", got))
            except OSError:
                pass
        finally:
            conn.close()


def check_vpn_control(workdir):
    section("Is the VPN carrying data at all?  (the control)")
    info("A server we control, at the far end of the same path. Every earlier")
    info("row measured one service through one route and could not separate")
    info("them. This can: the bytes are ours, the server is ours, and only the")
    info("route varies.")
    emit()

    import threading

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(("0.0.0.0", 0))
    except OSError as e:
        bad(f"could not bind a listener: {e}")
        return
    server.listen(8)
    port = server.getsockname()[1]
    ok(f"listening on 0.0.0.0:{port}")

    results = []
    stop = threading.Event()
    thread = threading.Thread(target=_control_server, args=(server, results, stop), daemon=True)
    thread.start()

    addresses = local_addresses(workdir)
    wifi = [a for i, f, a in addresses if f == "inet" and describe_iface(i) == "Wi-Fi"]
    routes = [("127.0.0.1", "loopback — the control's control")]
    if wifi:
        routes.append((wifi[0], "straight out of en0 and back"))
    routes.append((VPN_PEER_IP, "through LocalDevVPN's rewriting"))

    table = {}
    for host, why in routes:
        emit()
        emit(f"  {_c('1;37', host)}   {why}")
        alive, reason = reachable(host, port)
        if not alive:
            info(f"nothing answered ({reason}) — skipping this route")
            table[host] = [(size, None) for size in CONTROL_SIZES]
            continue
        row = []
        for size in CONTROL_SIZES:
            before = len(results)
            try:
                sk = socket.create_connection((host, port), timeout=CONNECT_TIMEOUT)
            except OSError as e:
                info(f"{size:>6} bytes   connect failed: {errno_name(e)}")
                row.append((size, None))
                continue
            try:
                sk.settimeout(4.0)
                sk.sendall(b"\x5a" * size)
                data = sk.recv(4)
                got = struct.unpack(">I", data)[0] if len(data) == 4 else None
            except OSError as e:
                got = None
                note = errno_name(e)
            except Exception:                       # noqa: BLE001
                got = None
                note = "no reply"
            else:
                note = ""
            finally:
                sk.close()

            # The server records what it actually read even when the reply
            # cannot get back, so prefer its own count.
            if got is None and len(results) > before:
                got = results[-1][1]
                note = note or "(reply did not return)"

            if got == size:
                info(f"{size:>6} bytes   {_c('32', 'arrived intact')} {note}")
            elif got is None:
                info(f"{size:>6} bytes   {_c('31', 'LOST')} — never reached the server  {note}")
            else:
                info(f"{size:>6} bytes   {_c('31', f'only {got} arrived')}  {note}")
            row.append((size, got))
        table[host] = row

    stop.set()
    server.close()
    record("control", {h: {s: g for s, g in r} for h, r in table.items()})

    emit()
    vpn_row = dict(table.get(VPN_PEER_IP, []))
    direct_row = dict(table.get("127.0.0.1", []))
    vpn_ok = [s for s, g in vpn_row.items() if g == s]
    vpn_bad = [s for s, g in vpn_row.items() if g != s]
    direct_ok = [s for s, g in direct_row.items() if g == s]

    if not vpn_row or all(g is None for g in vpn_row.values()):
        bad("Nothing sent to 10.7.0.1 reached our own listener.")
        info("So the VPN is not rewriting to this device — whatever has been")
        info("answering on 10.7.0.1:49152 is somewhere else. That alone")
        info("explains every result so far, and it makes the LocalDevVPN")
        info("device-IP setting the first thing to check.")
    elif vpn_bad and len(direct_ok) == len(CONTROL_SIZES):
        bad(f"Through the VPN our own server loses data at {min(vpn_bad)} bytes,")
        bad("while the same server over loopback receives everything.")
        info("LocalDevVPN is corrupting the stream. The device's service was")
        info("never the problem, and neither was any protocol — which is why")
        info("the magic, a TLS ClientHello and random bytes all died alike.")
        info("")
        info("Next: a route that does not go through this VPN at all.")
    elif not vpn_bad:
        ok("Our own server receives everything through the VPN, at every size.")
        info("So the path is sound, and the 11-byte cutoff on 49152 really is")
        info("that service. That is a much stranger result, and worth keeping.")
    else:
        warn("Mixed: the loopback control is not clean either, so the")
        warn("measurement cannot separate the two. Re-run with Wi-Fi settled.")



# --------------------------------------------------------------------------
# 6e. What protocol is it, then?  (--probe)
# --------------------------------------------------------------------------
#
# The cutoff is 10 bytes tolerated, 11 refused. That is not an arbitrary number:
# `rust-core/vendor/idevice/src/tunnel.rs` shows the CDTunnel handshake framing
# is an 8-byte magic plus a 2-byte big-endian length — a **10-byte header**. A
# parser that reads that header and then judges it would behave exactly like
# this: hold while the header is still incomplete, reject the moment it is.
#
# `core_device_proxy.rs` also says, in its own words, that over the network this
# same CDTunnel protocol runs over TLS-PSK. So 49152 through the loopback VPN is
# very likely the CoreDevice tunnel listener rather than RSD — which
# `preflight.rs` had already wondered about ("If 49152 is the tunnel service
# rather than RSD, our extra message is the thing being reset").
#
# One flaw in every earlier content test, worth being explicit about: they were
# all longer than 11 bytes. The TLS ClientHello and the lockdown plist died on
# the length rule before anything looked at what they contained, so they proved
# nothing about content. The sweep below fixes that by varying content *at the
# same length*.

CDTUNNEL_MAGIC = b"CDTunnel"
# Byte-for-byte what `CdTunnel::handshake` sends: serde_json emits the keys in
# declaration order, so this is the same JSON the working implementation writes.
CDTUNNEL_BODY = b'{"type":"clientHandshakeRequest","mtu":16000}'
CDTUNNEL_REQUEST = CDTUNNEL_MAGIC + struct.pack(">H", len(CDTUNNEL_BODY)) + CDTUNNEL_BODY


def parse_cdtunnel_reply(data):
    """Pull the handshake response apart, if that is what came back."""
    if not data.startswith(CDTUNNEL_MAGIC) or len(data) < 10:
        return None
    length = struct.unpack(">H", data[8:10])[0]
    body = data[10:10 + length]
    try:
        import json
        return json.loads(body.decode("utf-8", "replace"))
    except Exception:                               # noqa: BLE001
        return {"raw": body[:200].decode("utf-8", "replace")}


def probe_cdtunnel(host, port, use_tls=False):
    """Send the real CDTunnel handshake and see what comes back."""
    import ssl
    try:
        sk = socket.create_connection((host, port), timeout=CONNECT_TIMEOUT)
    except OSError as e:
        return "connect-failed", errno_name(e), None
    stream = sk
    try:
        if use_tls:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            try:
                ctx.set_ciphers("ALL:@SECLEVEL=0")
            except Exception:                       # noqa: BLE001
                pass
            try:
                stream = ctx.wrap_socket(sk, server_hostname=host)
            except Exception as e:                  # noqa: BLE001
                return "reset", f"TLS refused: {type(e).__name__}: {str(e)[:70]}", None
        stream.settimeout(10.0)
        stream.sendall(CDTUNNEL_REQUEST)
        data = stream.recv(4096)
    except socket.timeout:
        return "silent", "sent, no reply in 10s (but not reset either)", None
    except OSError as e:
        return "reset", errno_name(e), None
    finally:
        try:
            stream.close()
        except Exception:                           # noqa: BLE001
            pass
    if not data:
        return "closed", "closed without replying", None
    info_ = parse_cdtunnel_reply(data)
    if info_ is not None:
        return "data", f"CDTUNNEL REPLY — {len(data)} bytes", info_
    return "data", f"{len(data)} bytes back: {data[:40]!r}", None


def check_protocol(host, port=RSD_PORT):
    section(f"Is {host}:{port} the CoreDevice tunnel?")
    info("The 10-byte cutoff matches CDTunnel's header exactly: 8-byte magic")
    info("plus a 2-byte length. If that is what this is, a payload carrying the")
    info("right magic should survive where the same number of zero bytes does")
    info("not — and the full handshake should be answered.")
    emit()

    # The decisive comparison: identical lengths, different leading bytes.
    lengths = [9, 10, 11, 12, 14, 16, 20, 24, 32, len(CDTUNNEL_REQUEST)]
    candidates = [
        ("zero bytes", b"\x00" * 64),
        ("CDTunnel magic", CDTUNNEL_REQUEST + b"\x00" * 64),
        ("HTTP/2 magic", HTTP2_MAGIC + b"\x00" * 64),
    ]
    deaths = {}
    for label, filler in candidates:
        row = []
        died = None
        for n in lengths:
            verdict, _ = probe_variant(host, port, filler[:n], read_timeout=1.5)
            alive = verdict == "silent"
            row.append(f"{n}:{'ok' if alive else 'RST'}")
            if not alive and died is None:
                died = n
        deaths[label] = died
        info(f"{label:<16} " + "  ".join(row))
    record("protocol_deaths", deaths)
    emit()

    zeros_died = deaths.get("zero bytes")
    cd_died = deaths.get("CDTunnel magic")
    if cd_died is None and zeros_died is not None:
        ok("The CDTunnel magic is accepted at every length; zeros are not.")
        info("So the magic is what it is reading, and this is the CoreDevice")
        info("tunnel listener — not RemoteServiceDiscovery.")
    elif cd_died and zeros_died and cd_died > zeros_died:
        ok(f"CDTunnel survives to {cd_died} bytes where zeros die at {zeros_died}.")
        info("Content does matter once the payload is short enough for the")
        info("length rule not to mask it. The magic is being read.")
    elif cd_died == zeros_died:
        warn("The magic makes no difference — it dies at the same length as")
        warn("zeros, so this is a flat length rule and not a header parse.")

    emit()
    for label, tls in [("plain TCP", False), ("inside TLS", True)]:
        verdict, detail, parsed = probe_cdtunnel(host, port, use_tls=tls)
        mark = {"data": "ok", "silent": "..", "reset": "no"}.get(verdict, "??")
        colour = "1;32" if verdict == "data" else "33"
        info(f"full CDTunnel handshake, {label:<11} {_c(colour, mark)}  {detail}")
        if parsed:
            record("cdtunnel", parsed)
            emit()
            ok("THE DEVICE ANSWERED THE HANDSHAKE.")
            for key in sorted(parsed):
                info(f"    {key} = {parsed[key]}")
            emit()
            info("That is the tunnel's own parameters — the client and server")
            info("addresses, the MTU, and the RSD port reachable inside it.")
            info("Step 3 starts here.")
            return True
    return False



# --------------------------------------------------------------------------
# 6f. Map every service on the device  (--map)
# --------------------------------------------------------------------------
#
# Three protocol guesses have now been falsified against 49152 — the HTTP/2
# preface, TLS, and CDTunnel — and each cost a run. The cutoff is a flat 11
# bytes for zeros, random, the HTTP/2 magic and the CDTunnel magic alike, so
# the port is not parsing anything we can name.
#
# Guessing harder is not the way out of that. What has never been done is look
# at the whole device: the sweep so far covered 49152-49300 and five odd ports,
# which is 0.2% of the range. If RemoteServiceDiscovery is somewhere else — and
# on iOS 17+ RSD is normally reached at a port handed out per boot, not a fixed
# one — then everything measured about 49152 is a measurement of the wrong port.
#
# So: find every port that accepts, and characterise each one, rather than
# choosing a candidate in advance.



def port_occupied(port):
    """Is anything actually listening on this port on this device?

    Newly worth asking, because LocalDevVPN turns out to be a pure reflector:
    `PacketTunnelProvider.setPackets` swaps the IPv4 source and destination on
    every packet and never touches the ports, so `10.7.0.1:49152` is this
    device's own port 49152 reached with a forged source address. Nothing is
    forwarded anywhere.

    Which means we can simply try to bind it. EADDRINUSE says a real listener
    is there and we have been talking to it. A successful bind says the port
    was free all along — and then whatever answered was never a listener, and
    every measurement taken against it describes something else entirely.

    SO_REUSEADDR is deliberately not set: it is exactly what would paper over
    the answer.
    """
    sk = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sk.bind(("0.0.0.0", port))
        return False, "bound it ourselves — nothing was listening"
    except OSError as e:
        return True, f"{errno_name(e)} — a real listener holds it"
    finally:
        sk.close()


def classify_port(host, port, budget=1.0):
    """What kind of service is this?  -> (kind, detail)

    kind is one of:
      speaks    sent us bytes unprompted — a server that greets, the easiest
                thing in the world to talk to and the thing we most want
      holds     accepted and waited; then either tolerated 64 bytes or not
      closes    accepted and hung up without being asked anything
      reset     accepted and reset
    """
    fam = socket.AF_INET6 if ":" in host else socket.AF_INET
    sk = socket.socket(fam, socket.SOCK_STREAM)
    sk.settimeout(CONNECT_TIMEOUT)
    try:
        sk.connect((host, port))
    except OSError:
        sk.close()
        return None, ""
    try:
        sk.settimeout(budget)
        try:
            greeting = sk.recv(64)
        except socket.timeout:
            greeting = b""
        except OSError as e:
            return "reset", errno_name(e)
        if greeting:
            return "speaks", f"{len(greeting)} bytes unprompted: {greeting[:32]!r}"
        if greeting == b"" and _closed(sk):
            return "closes", "hung up without being asked"
    finally:
        sk.close()

    # It waited. Does it tolerate a real payload?
    verdict, detail = probe_variant(host, port, b"\x5a" * 64, read_timeout=budget)
    if verdict == "silent":
        return "holds", "tolerates 64 bytes and stays open"
    if verdict == "data":
        return "speaks", f"answered a 64-byte write: {detail}"
    return "holds", f"64 bytes -> {detail}"


def _closed(sk):
    """A zero-length read means the peer sent FIN."""
    try:
        sk.settimeout(0.2)
        return sk.recv(1) == b""
    except Exception:                               # noqa: BLE001
        return False


def byte_threshold(host, port, lo=0, hi=64):
    """Binary-search the payload length at which this port gives up.

    Only run on ports that accept and then reset, and only because the number
    turned out to be the most distinguishing thing about 49152. A port with a
    different threshold is a different kind of service.
    """
    verdict, _ = probe_variant(host, port, b"\x00" * hi, read_timeout=1.0)
    if verdict == "silent":
        return None                     # tolerates everything we tried
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        verdict, _ = probe_variant(host, port, b"\x00" * mid, read_timeout=1.0)
        if verdict == "silent":
            lo = mid
        else:
            hi = mid
    return hi


def check_map(host, all_ports=True):
    section(f"Every service reachable at {host}")
    ports = list(range(1, 65536)) if all_ports else FOCUSED_PORTS
    info(f"Sweeping {len(ports)} ports, then characterising each one that")
    info("accepts. On iOS 17+ RemoteServiceDiscovery is handed a port per boot")
    info("rather than a fixed one, so the port we have been measuring may")
    info("simply be the wrong one. This takes a few minutes.")
    emit()

    # Cheap and decisive, so it goes first.
    occupied, detail = port_occupied(RSD_PORT)
    if occupied:
        ok(f"port {RSD_PORT} on this device: {detail}")
    else:
        bad(f"port {RSD_PORT} on this device: {detail}")
        info("So nothing on this iPhone listens on 49152, and the thing that")
        info("has been accepting our connections through 10.7.0.1 is not a")
        info("service at all. Everything measured against it — the 11-byte")
        info("cutoff included — describes something other than remoted.")
    record("rsd_port_occupied", occupied)
    emit()

    t0 = time.monotonic()
    accepted = scan(host, ports, workers=64, timeout=0.6)
    dt = time.monotonic() - t0
    if not accepted:
        bad(f"nothing accepted a connection ({dt:.0f}s)")
        info("With the VPN down that is expected. Otherwise it is a real")
        info("result: the device exposes nothing at all on this address.")
        record("map", {})
        return
    ok(f"{len(accepted)} ports accept ({dt:.0f}s) — characterising them")
    emit()

    findings = {}
    for port, _state in accepted:
        kind, detail = classify_port(host, port)
        if kind is None:
            continue
        threshold = byte_threshold(host, port) if kind == "holds" else None
        held, _ = port_occupied(port)
        findings[port] = {"kind": kind, "threshold": threshold, "listener": held}
        cut = f"  cuts off at {threshold}B" if threshold else ""
        if not held:
            cut += "  [NO LISTENER — we can bind this port ourselves]"
        colour = "1;32" if kind == "speaks" else ("1;33" if kind == "holds" else "33")
        info(f"{port:<7} {_c(colour, kind):<8} {detail}{cut}")
    record("map", findings)

    emit()
    speakers = [p for p, f in findings.items() if f["kind"] == "speaks"]
    holders = [p for p, f in findings.items() if f["kind"] == "holds"]
    odd = [p for p in holders if findings[p]["threshold"] not in (None, 11)]

    if speakers:
        ok(f"Ports that speak first: {', '.join(str(p) for p in speakers)}")
        info("A service that greets is the one to talk to next — it tells us")
        info("what it is instead of having to be guessed at.")
    if odd:
        ok(f"Ports with a cutoff other than 11 bytes: {', '.join(str(p) for p in odd)}")
        info("Different threshold, different service. Worth probing directly")
        info(f"with --probe {host} on that port.")
    if not speakers and not odd:
        if holders:
            warn(f"All {len(holders)} listening ports behave identically to 49152.")
            info("A device-wide 11-byte cutoff on every port is not a property")
            info("of any one service — it is a property of this path or this")
            info("process. The next thing to rule out is Developer Mode: with")
            info("it off, iOS declines developer connections, and doing so")
            info("uniformly across every port would look exactly like this.")
        else:
            warn("Nothing that accepts will hold a conversation.")



# --------------------------------------------------------------------------
# 6g. RemoteXPC — actually talking to the service  (--rsd)
# --------------------------------------------------------------------------
#
# The map found port 61779 holding a connection open and tolerating a real
# payload, where 49152 cuts off at 11 bytes. That is the shape of the service
# we have been looking for all along, and on iOS 17+ RSD is handed an ephemeral
# port per boot — so 49152 was very likely never it.
#
# Everything below is the wire format as `rust-core/vendor/idevice/src/xpc`
# implements it, ported rather than guessed:
#
#   HTTP/2 (no TLS) -> per-stream DATA frames
#     -> XPC wrapper: magic 0x29b00b92, flags, u64 body length, u64 message id
#       -> XPC object: magic 0x42133742, version 5, then a typed tree
#
# This is pipeline step 1 — "find this iPhone's services" — not a probe.

XPC_OBJ_MAGIC = 0x42133742
XPC_OBJ_VERSION = 5
XPC_WRAPPER_MAGIC = 0x29B00B92
XPC_WRAPPER_LEN = 24

T_NULL, T_BOOL, T_INT64, T_UINT64 = 0x1000, 0x2000, 0x3000, 0x4000
T_DOUBLE, T_DATE, T_DATA, T_STRING = 0x5000, 0x7000, 0x8000, 0x9000
T_UUID, T_ARRAY, T_DICT = 0xA000, 0xE000, 0xF000

F_ALWAYS_SET, F_DATA, F_WANTING_REPLY = 0x1, 0x100, 0x10000
F_INIT_HANDSHAKE = 0x400000

ROOT_CHANNEL, REPLY_CHANNEL = 1, 3


def _pad(n):
    """Everything in this format is aligned to 4 bytes."""
    return (-n) % 4


class UInt64(int):
    """Marks an integer that must encode as UInt64 rather than Int64."""


def xpc_encode_object(value):
    if value is None:
        return struct.pack("<I", T_NULL)
    if isinstance(value, bool):
        return struct.pack("<I", T_BOOL) + (b"\x01" if value else b"\x00") + b"\x00" * 3
    if isinstance(value, UInt64):
        return struct.pack("<IQ", T_UINT64, int(value))
    if isinstance(value, int):
        return struct.pack("<Iq", T_INT64, value)
    if isinstance(value, float):
        return struct.pack("<Id", T_DOUBLE, value)
    if isinstance(value, str):
        raw = value.encode("utf-8")
        length = len(raw) + 1
        return struct.pack("<II", T_STRING, length) + raw + b"\x00" + b"\x00" * _pad(length)
    if isinstance(value, (bytes, bytearray)):
        return struct.pack("<II", T_DATA, len(value)) + bytes(value) + b"\x00" * _pad(len(value))
    if isinstance(value, dict):
        body = struct.pack("<I", len(value))
        for key, item in value.items():
            raw = key.encode("utf-8")
            body += raw + b"\x00" + b"\x00" * _pad(len(raw) + 1)
            body += xpc_encode_object(item)
        return struct.pack("<II", T_DICT, len(body)) + body
    if isinstance(value, (list, tuple)):
        body = struct.pack("<I", len(value))
        for item in value:
            body += xpc_encode_object(item)
        return struct.pack("<II", T_ARRAY, len(body)) + body
    raise TypeError(f"cannot encode {type(value).__name__} as XPC")


def xpc_encode(value):
    return struct.pack("<II", XPC_OBJ_MAGIC, XPC_OBJ_VERSION) + xpc_encode_object(value)


def xpc_decode_object(buf, off):
    """-> (value, new_offset). Raises IndexError when the buffer is short."""
    if off + 4 > len(buf):
        raise IndexError("truncated XPC object")
    kind = struct.unpack_from("<I", buf, off)[0]
    off += 4
    if kind == T_NULL:
        return None, off
    if kind == T_BOOL:
        return buf[off] != 0, off + 4
    if kind == T_INT64:
        return struct.unpack_from("<q", buf, off)[0], off + 8
    if kind == T_UINT64:
        return struct.unpack_from("<Q", buf, off)[0], off + 8
    if kind == T_DOUBLE:
        return struct.unpack_from("<d", buf, off)[0], off + 8
    if kind == T_DATE:
        return struct.unpack_from("<Q", buf, off)[0], off + 8
    if kind == T_UUID:
        return buf[off:off + 16].hex(), off + 16
    if kind == T_STRING:
        length = struct.unpack_from("<I", buf, off)[0]
        off += 4
        raw = buf[off:off + length - 1] if length else b""
        return raw.decode("utf-8", "replace"), off + length + _pad(length)
    if kind == T_DATA:
        length = struct.unpack_from("<I", buf, off)[0]
        off += 4
        return bytes(buf[off:off + length]), off + length + _pad(length)
    if kind in (T_DICT, T_ARRAY):
        content_len = struct.unpack_from("<I", buf, off)[0]
        off += 4
        end = off + content_len
        count = struct.unpack_from("<I", buf, off)[0]
        off += 4
        if kind == T_ARRAY:
            items = []
            for _ in range(count):
                item, off = xpc_decode_object(buf, off)
                items.append(item)
            return items, end
        out = {}
        for _ in range(count):
            stop = buf.index(b"\x00", off)
            key = buf[off:stop].decode("utf-8", "replace")
            klen = stop - off + 1
            off += klen + _pad(klen)
            out[key], off = xpc_decode_object(buf, off)
        return out, end
    raise ValueError(f"unknown XPC type 0x{kind:x}")


def xpc_decode(buf):
    magic, version = struct.unpack_from("<II", buf, 0)
    if magic != XPC_OBJ_MAGIC:
        raise ValueError(f"bad XPC object magic 0x{magic:08x}")
    if version != XPC_OBJ_VERSION:
        raise ValueError(f"unexpected XPC version {version}")
    value, _ = xpc_decode_object(buf, 8)
    return value


def xpc_wrapper(flags, body=None, message_id=1):
    payload = xpc_encode(body) if body is not None else b""
    return struct.pack("<IIQQ", XPC_WRAPPER_MAGIC, flags, len(payload), message_id) + payload


def h2_data(stream, payload):
    return struct.pack(">I", len(payload))[1:] + b"\x00\x00" + struct.pack(">I", stream) + payload


SETTINGS_ACK = b"\x00\x00\x00\x04\x01\x00\x00\x00\x00"

FRAME_NAMES = {0x00: "DATA", 0x01: "HEADERS", 0x03: "RST_STREAM", 0x04: "SETTINGS",
               0x06: "PING", 0x07: "GOAWAY", 0x08: "WINDOW_UPDATE"}


class RemoteXpc:
    """A minimal RemoteXPC client, enough to ask RSD what it is running."""

    def __init__(self, sock):
        self.sock = sock
        self.error = None
        self.buf = b""
        self.streams = {}
        self.frames = []

    def send(self, data):
        self.sock.sendall(data)

    def open_handshake(self):
        """`Http2Client::new` + `RemoteXpcClient::do_handshake`, in order."""
        self.send(HTTP2_MAGIC)
        self.send(IDEVICE_SETTINGS)
        self.send(IDEVICE_WINDOW_UPDATE)
        self.send(h2_headers(ROOT_CHANNEL))
        self.send(h2_data(ROOT_CHANNEL, xpc_wrapper(F_ALWAYS_SET, {})))
        self.send(h2_headers(REPLY_CHANNEL))
        self.send(h2_data(REPLY_CHANNEL, xpc_wrapper(F_INIT_HANDSHAKE | F_ALWAYS_SET)))
        self.send(h2_data(ROOT_CHANNEL, xpc_wrapper(0x201)))

    def send_device_handshake(self):
        """Announce ourselves to remoted as a modern RemoteXPC peer."""
        import uuid as _uuid
        message = {
            "MessageType": "Handshake",
            "MessagingProtocolVersion": UInt64(7),
            "UUID": _uuid.uuid4().bytes,
            "Properties": {
                "RemoteXPCVersionFlags": UInt64(0x0100000000000006),
                "SensitivePropertiesVisible": True,
            },
            "Services": {},
        }
        self.send(h2_data(ROOT_CHANNEL, xpc_wrapper(F_DATA | F_ALWAYS_SET, message)))

    def pump(self, deadline):
        """Read one frame; route DATA to its stream.

        -> frame name, "timeout" (nothing yet, keep waiting), or None (closed).
        """
        while len(self.buf) < 9:
            state = self._fill(deadline)
            if state == "closed":
                return None
            if state == "timeout":
                return "timeout"
        length, kind, flags = struct.unpack(">IBB", b"\x00" + self.buf[0:3] + self.buf[3:5])
        stream = struct.unpack(">I", self.buf[5:9])[0] & 0x7FFFFFFF
        while len(self.buf) < 9 + length:
            state = self._fill(deadline)
            if state == "closed":
                return None
            if state == "timeout":
                return "timeout"
        body = self.buf[9:9 + length]
        self.buf = self.buf[9 + length:]
        name = FRAME_NAMES.get(kind, f"type 0x{kind:02x}")
        self.frames.append((name, stream, length))
        if kind == 0x04 and not (flags & 0x01):
            self.send(SETTINGS_ACK)
        elif kind == 0x06 and not (flags & 0x01):
            self.send(b"\x00\x00\x08\x06\x01" + struct.pack(">I", 0) + body[:8])
        elif kind == 0x00:
            self.streams[stream] = self.streams.get(stream, b"") + body
        return name

    def _fill(self, deadline):
        """-> "data" | "timeout" | "closed".

        The three have to stay distinct. An earlier version collapsed them into
        a bool, so one quiet two-second window ended the whole exchange and a
        device that simply had not spoken yet was indistinguishable from one
        that had hung up. Only "closed" is terminal.
        """
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return "timeout"
        self.sock.settimeout(min(remaining, 2.0))
        try:
            chunk = self.sock.recv(65536)
        except socket.timeout:
            return "timeout"
        except OSError as e:
            self.error = errno_name(e)
            return "closed"
        if not chunk:
            self.error = self.error or "peer closed the connection"
            return "closed"
        self.buf += chunk
        return "data"

    def take_message(self, channel=ROOT_CHANNEL):
        """Pull one complete XPC message off a channel, if there is one."""
        data = self.streams.get(channel, b"")
        if len(data) < XPC_WRAPPER_LEN:
            return None
        magic, flags, body_len, _mid = struct.unpack_from("<IIQQ", data, 0)
        if magic != XPC_WRAPPER_MAGIC:
            return None
        total = XPC_WRAPPER_LEN + body_len
        if len(data) < total:
            return None
        self.streams[channel] = data[total:]
        if body_len == 0:
            return {"_flags": flags, "_empty": True}
        try:
            return xpc_decode(data[XPC_WRAPPER_LEN:total])
        except Exception as e:                      # noqa: BLE001
            return {"_undecodable": str(e), "_raw": data[XPC_WRAPPER_LEN:total][:64].hex()}


def rsd_handshake(host, port, use_tls=False, budget=12.0):
    """Run the handshake and report everything observed.

    Always returns a result rather than printing: the previous version hid the
    frame counts behind `quiet`, so a discovery run could only say "no port
    completed a handshake" and not whether any port had answered at all. What
    came back is the finding; suppressing it wasted a run.
    """
    import ssl
    out = {"port": port, "tls": use_tls, "frames": [], "services": None, "error": None}
    try:
        sock = socket.create_connection((host, port), timeout=CONNECT_TIMEOUT)
    except OSError as e:
        out["error"] = f"connect: {errno_name(e)}"
        return out
    try:
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    except OSError:
        pass
    if use_tls:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        try:
            ctx.set_ciphers("ALL:@SECLEVEL=0")
        except Exception:                           # noqa: BLE001
            pass
        try:
            sock = ctx.wrap_socket(sock, server_hostname=host)
        except Exception as e:                      # noqa: BLE001
            out["error"] = f"TLS: {type(e).__name__}: {str(e)[:70]}"
            sock.close()
            return out

    client = RemoteXpc(sock)
    try:
        client.open_handshake()
        client.send_device_handshake()
        deadline = time.monotonic() + budget
        while time.monotonic() < deadline:
            state = client.pump(deadline)
            if state is None:
                break
            message = client.take_message()
            while message is not None:
                if isinstance(message, dict) and "Services" in message:
                    out["services"] = message["Services"]
                    break
                message = client.take_message()
            if out["services"] is not None:
                break
    except OSError as e:
        out["error"] = errno_name(e)
    finally:
        try:
            sock.close()
        except Exception:                           # noqa: BLE001
            pass
    out["frames"] = client.frames
    out["error"] = out["error"] or client.error
    return out


def summarise_frames(frames):
    if not frames:
        return "no frames"
    seen = {}
    for name, _stream, _length in frames:
        seen[name] = seen.get(name, 0) + 1
    return ", ".join(f"{n} x{c}" for n, c in sorted(seen.items()))


def print_services(services):
    ok(f"{len(services)} services advertised")
    emit()
    for name in sorted(services):
        entry = services[name]
        port_ = entry.get("Port") if isinstance(entry, dict) else entry
        info(f"    {str(port_):<8} {name}")
    record("services", {k: (v.get("Port") if isinstance(v, dict) else v)
                        for k, v in services.items()})
    emit()
    if TUNNEL_SERVICE in services:
        ok("the untrusted tunnel service is advertised — step 2 can start.")
    else:
        warn("the untrusted tunnel service is NOT in that list, so pairing has")
        warn("no door here. Worth sending the full list back.")


def check_rsd(host, port, use_tls=False):
    section(f"RemoteXPC handshake with {host}:{port}")
    result = rsd_handshake(host, port, use_tls=use_tls)
    if result["frames"]:
        ok(f"the device sent {len(result['frames'])} HTTP/2 frames")
        info("   " + summarise_frames(result["frames"]))
    else:
        bad("no HTTP/2 frames came back")
        if result["error"]:
            info(f"   {result['error']}")
    if result["services"]:
        emit()
        print_services(result["services"])
        return result["services"]
    if result["frames"]:
        emit()
        warn("frames came back but no service list arrived.")
        info("That is still progress: the port speaks HTTP/2, so the transport")
        info("is right and only the XPC layer above it is unfinished.")
    return None


def check_rsd_discover(host):
    """Find the RSD port, then talk to it.

    The port is ephemeral and changes every boot, so hard-coding one is how
    several runs went wrong. Sweep, then try the handshake on every port that
    could plausibly carry it — including, in TLS, the ones that answer
    plaintext with a TLS alert.
    """
    section(f"Finding RemoteServiceDiscovery on {host}")
    info("RSD's port is handed out per boot, so it is found rather than assumed.")
    info("Every port that accepts gets the handshake tried on it, and what came")
    info("back is printed either way — a port that answers frames but no service")
    info("list is a different result from one that says nothing at all.")
    emit()

    accepted = scan(host, list(range(1, 65536)), workers=64, timeout=0.6)
    if not accepted:
        bad("nothing accepted a connection — is the VPN connected?")
        return None
    ok(f"{len(accepted)} ports accept; trying the handshake on each")
    emit()

    attempts = {}
    for port, _state in accepted:
        kind, detail = classify_port(host, port)
        # A TLS server answers plaintext with an alert record (0x15). Those are
        # worth a TLS attempt rather than being written off: 8443 does exactly
        # this, and RemoteXPC over TLS is how remoted speaks on some routes.
        greeting_is_tls = "\\x15" in detail or "\\x16" in detail
        modes = [False]
        if greeting_is_tls or kind == "speaks":
            modes = [True, False]
        elif kind == "closes":
            info(f"{port:<7} {kind} — {detail}")
            continue

        for use_tls in modes:
            label = "TLS" if use_tls else "plain"
            result = rsd_handshake(host, port, use_tls=use_tls)
            attempts[f"{port}/{label}"] = {
                "frames": summarise_frames(result["frames"]),
                "error": result["error"],
            }
            note = summarise_frames(result["frames"])
            if result["error"] and not result["frames"]:
                note = result["error"]
            info(f"{port:<7} {label:<5} {note}")
            if result["services"]:
                emit()
                ok(f"port {port} is RemoteServiceDiscovery ({label})")
                record("rsd_port", port)
                emit()
                print_services(result["services"])
                return result["services"]
    record("rsd_attempts", attempts)

    emit()
    answered = [k for k, v in attempts.items() if v["frames"] != "no frames"]
    if answered:
        ok(f"Ports that sent HTTP/2 frames back: {', '.join(answered)}")
        info("The transport is right there and only the XPC layer above it is")
        info("wrong — which is a much smaller problem than finding the port.")
    else:
        bad("No port sent a single HTTP/2 frame back.")
        info("Every one accepted the connection, took the whole opening, and")
        info("said nothing. So none of them is RemoteXPC over plain HTTP/2,")
        info("and the transport assumption is what needs revisiting — not the")
        info("port. Send this back with the frame column; it is the evidence.")
    return None


# --------------------------------------------------------------------------
# 7. Throughput
# --------------------------------------------------------------------------

def check_throughput():
    section("Socket throughput")
    info("The install uploads the whole signed .ipa through a TCP stack written")
    info("in Python, so this sets the floor on how long step 6 can take.")
    emit()
    import threading

    payload = b"\x5a" * (1 << 16)
    total = 1 << 23          # 8 MB
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", 0))
    server.listen(1)
    port = server.getsockname()[1]
    ok(f"bound a listener on 127.0.0.1:{port}")

    def sink():
        conn, _ = server.accept()
        got = 0
        while got < total:
            chunk = conn.recv(1 << 16)
            if not chunk:
                break
            got += len(chunk)
        conn.close()

    thread = threading.Thread(target=sink, daemon=True)
    thread.start()
    try:
        client = socket.create_connection(("127.0.0.1", port), timeout=10)
        t0 = time.monotonic()
        sent = 0
        while sent < total:
            client.sendall(payload)
            sent += len(payload)
        client.close()
        thread.join(timeout=30)
        dt = time.monotonic() - t0
        rate = (total / (1 << 20)) / dt if dt else float("inf")
        ok(f"loopback TCP — {rate:.0f} MB/s")
        record("loopback_mbs", round(rate))
        # Every byte crosses Python twice more inside the tunnel: once through
        # the software TCP stack, once through the tunnel's own framing.
        info(f"a 60 MB upload would cost at least {60 / rate:.1f} s of pure socket time")
    except Exception as e:                          # noqa: BLE001
        bad(f"loopback test failed: {e!r}")
    finally:
        server.close()


# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------

def probe_report(workdir, started):
    """Just the probe's findings. The full summary would print None for every
    line the probe never ran, which is worse than saying nothing."""
    section("Summary")
    emit(f"  siboot {VERSION} — probe only")
    for key in ("probe_lengths", "probe", "threshold_zeros", "threshold_random",
                "drip", "protocol_deaths", "cdtunnel", "control", "rsd_port_occupied", "map", "rsd_port", "services", "rsd_attempts"):
        emit(f"  {key:<18}{FINDINGS.get(key)}")
    emit(f"  {'elapsed':<18}{time.monotonic() - started:.1f} s")
    path = os.path.join(workdir, "siboot-probe.txt") if workdir else None
    if path:
        try:
            with open(path, "w") as fh:
                fh.write("\n".join(LINES) + "\n")
            emit()
            emit(f"  Full log written to {path}")
        except Exception as e:                      # noqa: BLE001
            warn(f"could not write the report: {e}")
    emit()


def write_report(workdir, started):
    section("Summary")
    verdict_lines = []

    def line(text):
        verdict_lines.append(text)
        emit(f"  {text}")

    line(f"siboot {VERSION} self-test — Python {FINDINGS.get('python')}")
    line(f"platform      {FINDINGS.get('platform')}")
    missing = FINDINGS.get("missing_required") or []
    line(f"stdlib        {'complete' if not missing else 'MISSING ' + ','.join(missing)}")
    count = FINDINGS.get("command_count")
    listed = f"{count} commands listed" if count else "no command list"
    line(f"runner        {FINDINGS.get('runner')}   ({listed})")
    line(f"of interest   {', '.join(FINDINGS.get('commands') or []) or 'none reachable'}")
    line(f"interfaces    {', '.join(FINDINGS.get('ifaces') or []) or 'none'}")
    line(f"internet      {len(FINDINGS.get('internet') or [])}/3 hosts")
    line(f"RSD reached   {FINDINGS.get('rsd_reached')}   {FINDINGS.get('rsd') or ''}")
    line(f"wifi addr     {FINDINGS.get('wifi_addr')}   vpn {FINDINGS.get('vpn_addr')}")
    line(f"x25519        {FINDINGS.get('x25519_ms')} ms   modexp {FINDINGS.get('modexp_ms')} ms")
    line(f"sha256        {FINDINGS.get('sha256_mbs')} MB/s   loopback {FINDINGS.get('loopback_mbs')} MB/s")
    line(f"rsa keygen    ~{FINDINGS.get('rsa_keygen_est_s')} s estimated")
    line(f"free space    {FINDINGS.get('free_mb')} MB")
    line(f"elapsed       {time.monotonic() - started:.1f} s")

    path = None
    if workdir:
        path = os.path.join(workdir, "siboot-selftest.txt")
        try:
            with open(path, "w") as fh:
                fh.write("\n".join(LINES) + "\n")
        except Exception as e:                      # noqa: BLE001
            warn(f"could not write the report: {e}")
            path = None

    emit()
    if path:
        emit(f"  Full log written to {path}")
        if os.path.basename(workdir) == "Documents":
            emit("  It is reachable from the Files app, under a-Shell.")
    emit()
    emit(_c("1;36", "  Send the Summary block above back — those lines decide what"))
    emit(_c("1;36", "  checkpoint 2 is allowed to assume."))
    emit()


def usage():
    print(f"""\
siboot {VERSION} for a-Shell — installs SideInstaller onto this iPhone.

USAGE
    python siboot.py --self-test [--offline]

OPTIONS
    --self-test   Check that this device and this app can run the pipeline.
    --offline     Skip the checks that need internet.
    --scan        Also sweep for other ports that accept a connection, and
                  say which of them hold it open.
    --scan-all    The same sweep over all 65535 ports. Slow; a few minutes.
    --probe [IP]  Find out why a service that holds the connection open still
                  drops us when we speak. Defaults to the LocalDevVPN peer.
    --rsd [IP[:PORT]]
                  Do the RemoteXPC handshake and list this iPhone's services.
                  With no port, finds RSD first — its port changes every boot.
    --map [IP]    Sweep all 65535 ports and characterise every one that
                  accepts: does it greet, wait, or hang up, and where does it
                  cut off. Defaults to the LocalDevVPN peer. A few minutes.
    -h, --help    Show this message.

THIS BUILD IS CHECKPOINT 1 OF 5 and does nothing but the self-test. It asks
for no password and touches no Apple account.

REQUIREMENTS
    Wi-Fi on, and Local Network permission granted to a-Shell. The first run
    should prompt for it; if it did not, Settings > Privacy & Security >
    Local Network > a-Shell.

    Keep a-Shell in the foreground while it runs.""")


def main(argv):
    if "-h" in argv or "--help" in argv:
        usage()
        return 0
    if ("--self-test" not in argv and "--probe" not in argv
            and "--map" not in argv and "--rsd" not in argv):
        usage()
        emit()
        print("siboot: nothing but --self-test is implemented yet.")
        return 1
    offline = "--offline" in argv
    scan_all = "--scan-all" in argv
    scan = scan_all or "--scan" in argv
    rsd_target = None
    if "--rsd" in argv:
        idx = argv.index("--rsd")
        rsd_target = argv[idx + 1] if idx + 1 < len(argv) and not argv[idx + 1].startswith("-") \
            else VPN_PEER_IP
    map_host = None
    if "--map" in argv:
        idx = argv.index("--map")
        map_host = argv[idx + 1] if idx + 1 < len(argv) and not argv[idx + 1].startswith("-") \
            else VPN_PEER_IP
    probe_host = None
    if "--probe" in argv:
        idx = argv.index("--probe")
        probe_host = argv[idx + 1] if idx + 1 < len(argv) and not argv[idx + 1].startswith("-") \
            else VPN_PEER_IP

    started = time.monotonic()
    emit()
    emit(_c("1;37", f"  siboot {VERSION} — self-test"))
    emit("  checkpoint 1 of 5: can this device and this app run the pipeline?")

    # `--probe` on its own is a focused follow-up, not a fresh survey: it skips
    # straight to the one question it exists to answer.
    if rsd_target and "--self-test" not in argv:
        workdir = check_filesystem_quiet()
        if ":" in rsd_target and not rsd_target.count(":") > 1:
            rhost, rport = rsd_target.rsplit(":", 1)
            check_rsd(rhost, int(rport))
        else:
            check_rsd_discover(rsd_target)
        probe_report(workdir, started)
        return 0

    if map_host and "--self-test" not in argv:
        workdir = check_filesystem_quiet()
        check_map(map_host)
        probe_report(workdir, started)
        return 0

    if probe_host and "--self-test" not in argv:
        workdir = check_filesystem_quiet()
        if check_probe(probe_host):
            check_threshold(probe_host)
            check_protocol(probe_host)
        check_vpn_control(workdir)
        probe_report(workdir, started)
        return 0

    check_interpreter()
    check_crypto()
    workdir = check_filesystem()
    check_tooling(workdir)
    if offline:
        section("Internet")
        info("skipped (--offline)")
    else:
        check_internet()
        check_local_network(workdir)
    if scan:
        hosts = ["127.0.0.1"]
        if FINDINGS.get("wifi_addr"):
            hosts.append(FINDINGS["wifi_addr"])
        if FINDINGS.get("vpn_addr"):
            hosts.append(VPN_PEER_IP)
        check_scan(hosts, all_ports=scan_all)
    if probe_host:
        if check_probe(probe_host):
            check_threshold(probe_host)
            check_protocol(probe_host)
        check_vpn_control(workdir)
    check_throughput()
    write_report(workdir, started)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print("\ninterrupted")
        sys.exit(130)
