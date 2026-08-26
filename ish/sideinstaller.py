#!/usr/bin/env python3
"""
Sign and install SideInstaller from inside iSH, using your own Apple account.

This is a from-scratch Python port of the parts of `isideload` that don't need a
device connection: GrandSlam sign-in, the developerservices2 (Xcode) portal, and
the certificate/App ID/provisioning-profile dance. It exists so that a phone with
nothing on it but the App Store copy of iSH can produce a SideInstaller build
signed with the user's OWN free developer certificate, instead of depending on
the shared certificates the install page hands out (which Apple revokes).

What leaves the device, and where it goes:
  * The password is never transmitted. GrandSlam authenticates over SRP-6a, so
    what goes to Apple is a proof derived from the password, not the password.
  * The anisette server sees only device-identity headers it generates itself —
    no Apple ID, no password, no token.
  * Everything else (the RSA key, the certificate, the signed .ipa) stays in
    ~/.sideinstaller and is never uploaded anywhere.

Protocol reference: rust-core/vendor/isideload/src/{auth,anisette,dev}. Where a
constant looks arbitrary here it was copied from there deliberately; Apple's
endpoints reject the plausible-looking alternative.
"""

import base64
import binascii
import getpass
import hashlib
import hmac
import http.client
import json
import os
import plistlib
import re
import secrets
import shutil
import socket
import ssl
import struct
import subprocess
import sys
import tempfile
import time
import urllib.parse
import uuid
import zipfile

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

HOME = os.path.expanduser("~")
STORAGE = os.environ.get("SIDEINSTALLER_HOME", os.path.join(HOME, ".sideinstaller"))

# The App Store build of iSH is a normal sandboxed app, so it cannot ask the
# device for its own UDID. Every route to one is listed in ask_udid().
UDID_RE = re.compile(r"^(?:[0-9A-Fa-f]{40}|[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16})$")

GSA_URL_BAG = "https://gsa.apple.com/grandslam/GsService2/lookup"
DEV_HOST = "developerservices2.apple.com"
# clientId/protocolVersion identify us as Xcode to the portal. Not decorative:
# the .action endpoints 404 without the matching path segment.
DEV_CLIENT_ID = "XABBG36SBA"
DEV_PROTOCOL = "QH65B2"

DEFAULT_ANISETTE = os.environ.get("ANISETTE_URL", "https://ani.sidestore.io")
# Same live list the app reads, with the same bundled fallback, so a server
# going down here fails over exactly the way it does in SideInstaller.
ANISETTE_LIST_URL = "https://servers.sidestore.io/servers.json"
BUNDLED_ANISETTE = [
    "https://ani.sidestore.io",
    "https://ani.sidestore.app",
    "https://ani.sidestore.zip",
    "https://ani.846969.xyz",
    "https://ani.npeg.us",
    "https://anisette.wedotstud.io",
    "https://ani.neoarz.com",
    "https://ani.jaydenha.uk",
]
# Anisette servers are volunteer-run and half of any list is usually down;
# stop after this many so a bad day doesn't turn into a long wait.
MAX_ANISETTE_TRIES = 6

RELEASE_API = "https://api.github.com/repos/FrizzleM/SideInstaller/releases"
# Matches the machineName SideInstaller itself sends, so a certificate minted
# here is the same one the app would look for later.
MACHINE_NAME = os.environ.get("MACHINE_NAME", "SideInstaller")

# RFC 5054 2048-bit group, the one GrandSlam negotiates.
SRP_N = int(
    "ac6bdb41324a9a9bf166de5e1389582faf72b6651987ee07fc3192943db56050"
    "a37329cbb4a099ed8193e0757767a13dd52312ab4b03310dcd7f48a9da04fd50"
    "e8083969edb767b0cf6095179a163ab3661a05fbd5faaae82918a9962f0b93b8"
    "55f97993ec975eeaa80d740adbf4ff747359d041d5c33ea71d281e446b14773b"
    "ca97b43a23fb801676bd207a436c6481f1d2b9078717461a5b9d32e688f87748"
    "544523b524b0d57d5ea77a2775d2ecfa032cfbdbf52fb3786160279004e57ae6"
    "af874e7303ce53299ccc041c7bc308d82a5698f3a8d0c38271ae35f8e9dbfbb6"
    "94b5c803d89f7ae435de236d525f54759b65e372fcd68ef20fa7111f9e4aff73",
    16,
)
SRP_g = 2


# ----------------------------------------------------------------------------
# Terminal output
# ----------------------------------------------------------------------------

_TTY = sys.stdout.isatty()


def _c(code, text):
    return "\033[%sm%s\033[0m" % (code, text) if _TTY else text


def step(msg):
    print(_c("1;36", "==> ") + _c("1", msg))


def info(msg):
    print("    " + msg)


def warn(msg):
    print(_c("1;33", "  ! ") + msg)


def die(msg):
    print(_c("1;31", "  x ") + msg, file=sys.stderr)
    sys.exit(1)


def ok(msg):
    print(_c("1;32", "  ✓ ") + msg)


def ask(prompt, default=None):
    suffix = " [%s]: " % default if default else ": "
    while True:
        try:
            value = input(prompt + suffix).strip()
        except EOFError:
            die("No input available; run this script interactively.")
        if value:
            return value
        if default is not None:
            return default


def confirm(prompt, default=False):
    hint = "[Y/n]" if default else "[y/N]"
    try:
        value = input("%s %s " % (prompt, hint)).strip().lower()
    except EOFError:
        return default
    if not value:
        return default
    return value in ("y", "yes")


class Fail(Exception):
    """Anything the user can act on. Raised instead of a traceback."""


# ----------------------------------------------------------------------------
# HTTP
#
# http.client rather than urllib: urllib title-cases header names through
# str.capitalize(), which turns X-Apple-I-MD into X-apple-i-md. isideload goes
# out of its way to keep reqwest's title casing for these endpoints, so the
# safest thing is to send the header names exactly as written.
# ----------------------------------------------------------------------------

SSL_CTX = ssl.create_default_context()


def request(method, url, headers=None, body=None, timeout=60, redirects=5):
    """Return (status, header_dict, body_bytes). Follows redirects."""
    parts = urllib.parse.urlsplit(url)
    host = parts.hostname
    port = parts.port or (443 if parts.scheme == "https" else 80)
    path = parts.path or "/"
    if parts.query:
        path += "?" + parts.query

    if parts.scheme == "https":
        conn = http.client.HTTPSConnection(host, port, timeout=timeout, context=SSL_CTX)
    else:
        conn = http.client.HTTPConnection(host, port, timeout=timeout)

    if isinstance(body, str):
        body = body.encode("utf-8")

    try:
        conn.putrequest(method, path, skip_host=True, skip_accept_encoding=True)
        conn.putheader("Host", parts.netloc)
        sent = set()
        for key, value in (headers or {}).items():
            conn.putheader(key, value)
            sent.add(key.lower())
        if body is not None and "content-length" not in sent:
            conn.putheader("Content-Length", str(len(body)))
        if "accept-encoding" not in sent:
            conn.putheader("Accept-Encoding", "identity")
        conn.endheaders(body)
        response = conn.getresponse()
        data = response.read()
        status = response.status
        got = {k.lower(): v for k, v in response.getheaders()}
    finally:
        conn.close()

    if status in (301, 302, 303, 307, 308) and redirects > 0 and got.get("location"):
        target = urllib.parse.urljoin(url, got["location"])
        # 303, and 301/302 on POST, degrade to GET the way every client does.
        if status == 303 or (status in (301, 302) and method == "POST"):
            method, body = "GET", None
        return request(method, target, headers, body, timeout, redirects - 1)

    return status, got, data


def download(url, dest, headers=None):
    """Stream a URL to a file, printing progress. Returns the byte count."""
    parts = urllib.parse.urlsplit(url)
    port = parts.port or (443 if parts.scheme == "https" else 80)
    if parts.scheme == "https":
        conn = http.client.HTTPSConnection(parts.hostname, port, timeout=120, context=SSL_CTX)
    else:
        conn = http.client.HTTPConnection(parts.hostname, port, timeout=120)
    path = parts.path + ("?" + parts.query if parts.query else "")
    try:
        conn.request("GET", path, headers=dict(headers or {}, **{"Host": parts.netloc}))
        response = conn.getresponse()
        if response.status in (301, 302, 303, 307, 308):
            location = response.getheader("Location")
            response.read()
            conn.close()
            return download(urllib.parse.urljoin(url, location), dest, headers)
        if response.status != 200:
            raise Fail("Download failed (HTTP %d): %s" % (response.status, url))
        total = int(response.getheader("Content-Length") or 0)
        written = 0
        with open(dest, "wb") as handle:
            while True:
                chunk = response.read(65536)
                if not chunk:
                    break
                handle.write(chunk)
                written += len(chunk)
                if total and _TTY:
                    sys.stdout.write("\r    %d%% (%.1f MB)" % (written * 100 // total, written / 1e6))
                    sys.stdout.flush()
        if total and _TTY:
            sys.stdout.write("\r" + " " * 32 + "\r")
            sys.stdout.flush()
        return written
    finally:
        conn.close()


# ----------------------------------------------------------------------------
# openssl
#
# Everything asymmetric shells out. Alpine's python3 has no AES and no RSA, and
# the wheels that would supply them need a Rust toolchain, which under iSH's
# i386 emulation is not a realistic ask.
# ----------------------------------------------------------------------------

def openssl(args, stdin=None, capture=True):
    proc = subprocess.run(
        ["openssl"] + args,
        input=stdin,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        detail = (proc.stderr or b"").decode("utf-8", "replace").strip()
        raise Fail("openssl %s failed: %s" % (args[0], detail))
    return proc.stdout


def aes_cbc_decrypt(key, iv, data):
    return openssl([
        "enc", "-d", "-aes-256-cbc",
        "-K", binascii.hexlify(key).decode(),
        "-iv", binascii.hexlify(iv).decode(),
    ], stdin=data)


# ----------------------------------------------------------------------------
# AES-GCM
#
# GrandSlam returns app tokens under AES-256-GCM with a 16-byte nonce, which
# `openssl enc` cannot do at all (no GCM) and which even the 12-byte fast path
# wouldn't cover. GCM only ever runs AES forwards, so this is the encrypt-side
# cipher plus GHASH — a few hundred bytes of plaintext, so speed is irrelevant.
# ----------------------------------------------------------------------------

_SBOX = None
_RCON = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36, 0x6C, 0xD8, 0xAB, 0x4D]


def _build_sbox():
    global _SBOX
    if _SBOX is not None:
        return _SBOX
    p = q = 1
    sbox = [0] * 256
    while True:
        # p *= 3 in GF(2^8)
        p = p ^ ((p << 1) & 0xFF) ^ (0x1B if p & 0x80 else 0)
        # q /= 3
        q ^= (q << 1) & 0xFF
        q ^= (q << 2) & 0xFF
        q ^= (q << 4) & 0xFF
        if q & 0x80:
            q ^= 0x09
        value = q ^ ((q << 1) | (q >> 7)) ^ ((q << 2) | (q >> 6)) ^ ((q << 3) | (q >> 5)) ^ ((q << 4) | (q >> 4))
        sbox[p] = (value ^ 0x63) & 0xFF
        if p == 1:
            break
    sbox[0] = 0x63
    _SBOX = sbox
    return sbox


def _xtime(a):
    a <<= 1
    return (a ^ 0x1B) & 0xFF if a & 0x100 else a


class AES:
    """AES-256 forward direction only (all GCM needs)."""

    def __init__(self, key):
        sbox = _build_sbox()
        nk = len(key) // 4
        if nk != 8:
            raise Fail("AES: expected a 256-bit key, got %d bits" % (len(key) * 8))
        self.rounds = nk + 6
        words = [list(key[4 * i:4 * i + 4]) for i in range(nk)]
        for i in range(nk, 4 * (self.rounds + 1)):
            temp = list(words[i - 1])
            if i % nk == 0:
                temp = temp[1:] + temp[:1]
                temp = [sbox[b] for b in temp]
                temp[0] ^= _RCON[i // nk - 1]
            elif i % nk == 4:
                temp = [sbox[b] for b in temp]
            words.append([a ^ b for a, b in zip(words[i - nk], temp)])
        self.round_keys = [sum(words[4 * r:4 * r + 4], []) for r in range(self.rounds + 1)]
        self.sbox = sbox

    def encrypt_block(self, block):
        sbox = self.sbox
        state = [b ^ k for b, k in zip(block, self.round_keys[0])]
        for rnd in range(1, self.rounds + 1):
            state = [sbox[b] for b in state]
            # ShiftRows, on a column-major state
            state = [
                state[0], state[5], state[10], state[15],
                state[4], state[9], state[14], state[3],
                state[8], state[13], state[2], state[7],
                state[12], state[1], state[6], state[11],
            ]
            if rnd != self.rounds:
                mixed = []
                for c in range(4):
                    a = state[4 * c:4 * c + 4]
                    t = a[0] ^ a[1] ^ a[2] ^ a[3]
                    mixed += [
                        a[0] ^ t ^ _xtime(a[0] ^ a[1]),
                        a[1] ^ t ^ _xtime(a[1] ^ a[2]),
                        a[2] ^ t ^ _xtime(a[2] ^ a[3]),
                        a[3] ^ t ^ _xtime(a[3] ^ a[0]),
                    ]
                state = mixed
            state = [b ^ k for b, k in zip(state, self.round_keys[rnd])]
        return bytes(state)


def _ghash(h_key, data):
    """GF(2^128) multiply-accumulate, the GCM authentication primitive."""
    h = int.from_bytes(h_key, "big")
    y = 0
    for offset in range(0, len(data), 16):
        block = data[offset:offset + 16].ljust(16, b"\0")
        y ^= int.from_bytes(block, "big")
        z = 0
        v = h
        for bit in range(127, -1, -1):
            if (y >> bit) & 1:
                z ^= v
            if v & 1:
                v = (v >> 1) ^ 0xE1000000000000000000000000000000
            else:
                v >>= 1
        y = z
    return y.to_bytes(16, "big")


def aes_gcm_decrypt(key, nonce, ciphertext, aad, tag):
    cipher = AES(key)
    h = cipher.encrypt_block(b"\0" * 16)

    if len(nonce) == 12:
        j0 = nonce + b"\0\0\0\1"
    else:
        padded = nonce + b"\0" * ((-len(nonce)) % 16) + b"\0" * 8 + struct.pack(">Q", len(nonce) * 8)
        j0 = _ghash(h, padded)

    counter = int.from_bytes(j0, "big")
    out = bytearray()
    for offset in range(0, len(ciphertext), 16):
        counter = (counter & ~0xFFFFFFFF) | ((counter + 1) & 0xFFFFFFFF)
        stream = cipher.encrypt_block(counter.to_bytes(16, "big"))
        block = ciphertext[offset:offset + 16]
        out += bytes(a ^ b for a, b in zip(block, stream))

    auth = (
        aad + b"\0" * ((-len(aad)) % 16)
        + ciphertext + b"\0" * ((-len(ciphertext)) % 16)
        + struct.pack(">QQ", len(aad) * 8, len(ciphertext) * 8)
    )
    expected = bytes(a ^ b for a, b in zip(_ghash(h, auth), cipher.encrypt_block(j0)))
    if not hmac.compare_digest(expected, tag):
        raise Fail("App token failed its authentication check.")
    return bytes(out)


# ----------------------------------------------------------------------------
# SRP-6a, GrandSlam flavour
#
# Ported byte-for-byte from what isideload gets out of srp 0.7.0-rc.3 with
# `new_with_options(false)`. Two deviations from textbook RFC 5054 matter:
#   * the username is left OUT of x, so x = H(salt | H(":" | password))
#   * `password` is not the password but PBKDF2 over its SHA-256 digest
# Everything is serialised as big-endian with leading zero bytes stripped,
# matching `to_be_bytes_trimmed_vartime`, except inside PAD() where values are
# left-padded to the width of N.
# ----------------------------------------------------------------------------

def _trim(value):
    length = max(1, (value.bit_length() + 7) // 8)
    return value.to_bytes(length, "big")


def _pad(value_bytes, width):
    return value_bytes.rjust(width, b"\0")


def _sha256(*chunks):
    digest = hashlib.sha256()
    for chunk in chunks:
        digest.update(chunk)
    return digest.digest()


class SRPClient:
    def __init__(self):
        self.n_bytes = _trim(SRP_N)
        self.width = len(self.n_bytes)
        self.a = int.from_bytes(secrets.token_bytes(32), "big")
        self.a_pub = _trim(pow(SRP_g, self.a, SRP_N))

    def process(self, username, password_key, salt, b_pub_bytes):
        b_pub = int.from_bytes(b_pub_bytes, "big")
        if b_pub % SRP_N == 0:
            raise Fail("Apple returned an invalid SRP parameter (B ≡ 0).")

        g_bytes = _trim(SRP_g)
        u = int.from_bytes(
            _sha256(_pad(self.a_pub, self.width), _pad(b_pub_bytes, self.width)), "big"
        )
        k = int.from_bytes(_sha256(self.n_bytes, _pad(g_bytes, self.width)), "big")

        identity_hash = _sha256(b"", b":", password_key)
        x = int.from_bytes(_sha256(salt, identity_hash), "big")

        premaster = pow(b_pub - k * pow(SRP_g, x, SRP_N), self.a + u * x, SRP_N)
        self.premaster = _trim(premaster)
        self.session_key = _sha256(self.premaster)

        n_xor_g = bytes(
            a ^ b for a, b in zip(_sha256(self.n_bytes), _sha256(_pad(g_bytes, self.width)))
        )
        self.m1 = _sha256(
            n_xor_g,
            _sha256(username.encode("utf-8")),
            salt,
            self.a_pub,
            b_pub_bytes,
            self.session_key,
        )
        self.m2 = _sha256(self.a_pub, self.m1, self.session_key)
        return self.m1

    def verify(self, server_m2):
        return hmac.compare_digest(self.m2, server_m2)

    def decrypt_spd(self, blob):
        """Unwrap the AES-CBC 'extra data' the server returns with M2.

        The HMAC key here is the one place two working implementations differ:
        isideload keys it on the raw premaster secret S, while everything built
        on pysrp keys it on H(S). Rather than bet on one, try both and keep the
        one that yields a parseable plist.
        """
        errors = []
        for label, base in (("H(S)", self.session_key), ("S", self.premaster)):
            key = hmac.new(base, b"extra data key:", hashlib.sha256).digest()
            iv = hmac.new(base, b"extra data iv:", hashlib.sha256).digest()[:16]
            try:
                return plistlib.loads(aes_cbc_decrypt(key, iv, blob))
            except Exception as exc:  # noqa: BLE001 - any failure means "wrong key"
                errors.append("%s: %s" % (label, exc))
        raise Fail("Could not decrypt the sign-in response (%s)." % "; ".join(errors))


def srp_password_key(password, salt, iterations, protocol):
    """Apple's s2k / s2k_fo password pre-hash, fed to PBKDF2-HMAC-SHA256."""
    digest = hashlib.sha256(password.encode("utf-8")).digest()
    if protocol == "s2k_fo":
        digest = binascii.hexlify(digest)
    elif protocol != "s2k":
        raise Fail("Apple asked for an unsupported SRP protocol: %s" % protocol)
    return hashlib.pbkdf2_hmac("sha256", digest, salt, iterations, 32)


# ----------------------------------------------------------------------------
# Minimal RFC 6455 client
#
# Only used to talk to the anisette server's provisioning socket. Alpine's
# py3-websockets is an extra package and an extra thing to trust; the subset
# needed here (text frames, one message in flight) is small enough to inline.
# ----------------------------------------------------------------------------

class WebSocket:
    def __init__(self, url, timeout=45):
        parts = urllib.parse.urlsplit(url)
        secure = parts.scheme == "wss"
        port = parts.port or (443 if secure else 80)
        path = (parts.path or "/") + ("?" + parts.query if parts.query else "")

        raw = socket.create_connection((parts.hostname, port), timeout=timeout)
        self.sock = SSL_CTX.wrap_socket(raw, server_hostname=parts.hostname) if secure else raw

        nonce = base64.b64encode(secrets.token_bytes(16)).decode()
        handshake = (
            "GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
            "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n"
            % (path, parts.netloc, nonce)
        )
        self.sock.sendall(handshake.encode())

        self.buffer = b""
        while b"\r\n\r\n" not in self.buffer:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise Fail("Anisette server closed the provisioning socket during the handshake.")
            self.buffer += chunk
        head, self.buffer = self.buffer.split(b"\r\n\r\n", 1)
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise Fail("Anisette server refused the provisioning socket: %s"
                       % head.split(b"\r\n")[0].decode("utf-8", "replace"))

    def _recv_exactly(self, count):
        while len(self.buffer) < count:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise Fail("Anisette provisioning socket closed unexpectedly.")
            self.buffer += chunk
        head, self.buffer = self.buffer[:count], self.buffer[count:]
        return head

    def recv(self):
        """Return the next text message, or None once the peer closes."""
        while True:
            header = self._recv_exactly(2)
            opcode = header[0] & 0x0F
            masked = header[1] & 0x80
            length = header[1] & 0x7F
            if length == 126:
                length = struct.unpack(">H", self._recv_exactly(2))[0]
            elif length == 127:
                length = struct.unpack(">Q", self._recv_exactly(8))[0]
            mask = self._recv_exactly(4) if masked else None
            payload = self._recv_exactly(length) if length else b""
            if mask:
                payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
            if opcode == 0x8:
                return None
            if opcode == 0x9:
                self._send_frame(0xA, payload)
                continue
            if opcode in (0x1, 0x2):
                return payload.decode("utf-8", "replace")

    def _send_frame(self, opcode, payload):
        header = bytearray([0x80 | opcode])
        length = len(payload)
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", length)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", length)
        mask = secrets.token_bytes(4)
        header += mask
        header += bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(bytes(header))

    def send_json(self, payload):
        self._send_frame(0x1, json.dumps(payload).encode())

    def close(self):
        try:
            self._send_frame(0x8, b"")
        except OSError:
            pass
        try:
            self.sock.close()
        except OSError:
            pass


# ----------------------------------------------------------------------------
# Anisette
#
# Apple will not authenticate a client that cannot produce a machine
# identifier issued by their own ADI library. Nobody can run that library here,
# so an anisette server runs it instead: we hand it an opaque identifier, it
# hands back one-time headers. It never sees the Apple ID or the password.
#
# Two protocols are in the wild. v3 provisions once over a websocket and then
# mints headers from the stored blob; v1 just returns a header set per request.
# ----------------------------------------------------------------------------

V1_USER_AGENT = "akd/1.0 CFNetwork/808.1.4 Darwin/16.1.0"
V1_CLIENT_INFO = "<MacBookPro13,2> <Mac OS X;10.12.1;16B2657> <com.apple.AuthKit/1 (com.apple.dt.Xcode/3594.4.19)>"


class Anisette:
    def __init__(self, url, state_path):
        self.url = url.rstrip("/")
        self.state_path = state_path
        self.version = None
        self.client_info = None
        self.user_agent = None
        self.routing_info = "0"
        self.identifier = None
        self.adi_pb = None
        self._load()

    # -- persisted identity ---------------------------------------------------

    def _load(self):
        try:
            with open(self.state_path) as handle:
                saved = json.load(handle)
            self.identifier = base64.b64decode(saved["identifier"])
            if saved.get("adi_pb"):
                self.adi_pb = base64.b64decode(saved["adi_pb"])
        except (OSError, ValueError, KeyError):
            self.identifier = secrets.token_bytes(16)

    def _save(self):
        os.makedirs(os.path.dirname(self.state_path), exist_ok=True)
        payload = {"identifier": base64.b64encode(self.identifier).decode()}
        if self.adi_pb:
            payload["adi_pb"] = base64.b64encode(self.adi_pb).decode()
        with open(self.state_path, "w") as handle:
            json.dump(payload, handle)
        os.chmod(self.state_path, 0o600)

    @property
    def device_id(self):
        return str(uuid.UUID(bytes=self.identifier))

    @property
    def md_lu(self):
        return hashlib.sha256(self.identifier).hexdigest()

    # -- protocol detection ---------------------------------------------------

    @staticmethod
    def _json(body, what):
        try:
            return json.loads(body)
        except ValueError:
            snippet = body[:120].decode("utf-8", "replace").strip()
            raise Fail("Anisette server answered %s with something that isn't JSON: %s"
                       % (what, snippet or "an empty body"))

    def detect(self):
        status, _, body = request("GET", self.url + "/v3/client_info")
        if status == 200:
            try:
                payload = json.loads(body)
                self.client_info = payload["client_info"]
                self.user_agent = payload["user_agent"]
                self.version = 3
                return 3
            except (ValueError, KeyError):
                pass

        status, _, body = request("GET", self.url + "/")
        if status == 200:
            try:
                payload = json.loads(body)
            except ValueError:
                payload = {}
            if "X-Apple-I-MD" in payload:
                self.client_info = payload.get("X-Mme-Client-Info", V1_CLIENT_INFO)
                self.user_agent = V1_USER_AGENT
                self.version = 1
                return 1

        raise Fail("%s does not look like an anisette server." % self.url)

    # -- v3 provisioning ------------------------------------------------------

    def needs_provisioning(self):
        return self.version == 3 and not self.adi_pb

    def forget_provisioning(self):
        self.adi_pb = None
        self._save()

    def provision(self, gs):
        ws_url = self.url.replace("https://", "wss://").replace("http://", "ws://")
        socket_ = WebSocket(ws_url + "/v3/provisioning_session")
        headers = {"X-Apple-I-MD-LU": self.md_lu, "X-Mme-Device-Id": self.device_id}
        try:
            while True:
                message = socket_.recv()
                if message is None:
                    raise Fail("Anisette provisioning socket closed before it finished.")
                payload = json.loads(message)
                result = payload.get("result")

                if result == "GiveIdentifier":
                    socket_.send_json({"identifier": base64.b64encode(self.identifier).decode()})

                elif result == "GiveStartProvisioningData":
                    response = gs.plist_request(
                        gs.url("midStartProvisioning"),
                        {"Header": {}, "Request": {}},
                        extra_headers=headers,
                    )
                    socket_.send_json({"spim": response["spim"]})

                elif result == "GiveEndProvisioningData":
                    response = gs.plist_request(
                        gs.url("midFinishProvisioning"),
                        {"Header": {}, "Request": {"cpim": payload["cpim"]}},
                        extra_headers=headers,
                    )
                    socket_.send_json({"ptm": response["ptm"], "tk": response["tk"]})

                elif result == "ProvisioningSuccess":
                    self.adi_pb = base64.b64decode(payload["adi_pb"])
                    self._save()
                    return

                elif result in ("Timeout", "InvalidIdentifier"):
                    raise Fail("Anisette provisioning failed: %s" % result)

                else:
                    raise Fail("Anisette provisioning failed: %s"
                               % payload.get("message", result or message))
        finally:
            socket_.close()

    # -- headers --------------------------------------------------------------

    def headers(self):
        """The three headers Apple checks, refreshed per request (X-Apple-I-MD
        is a one-time password and does not survive being reused)."""
        if self.version == 1:
            status, _, body = request("GET", self.url + "/")
            if status != 200:
                raise Fail("Anisette server returned HTTP %d." % status)
            payload = self._json(body, "a header request")
            self.routing_info = payload.get("X-Apple-I-MD-RINFO", "0")
            return {
                "X-Mme-Device-Id": payload.get("X-Mme-Device-Id", self.device_id),
                "X-Apple-I-MD": payload["X-Apple-I-MD"],
                "X-Apple-I-MD-M": payload["X-Apple-I-MD-M"],
            }

        status, _, body = request(
            "POST", self.url + "/v3/get_headers",
            headers={"Content-Type": "application/json"},
            body=json.dumps({
                "identifier": base64.b64encode(self.identifier).decode(),
                "adi_pb": base64.b64encode(self.adi_pb).decode(),
            }),
        )
        payload = self._json(body, "a header request") if body else {}
        if status != 200 or payload.get("result") != "Headers":
            raise Fail("Anisette server refused to mint headers: %s"
                       % payload.get("message", "HTTP %d" % status))
        self.routing_info = payload.get("X-Apple-I-MD-RINFO", "0")
        return {
            "X-Mme-Device-Id": self.device_id,
            "X-Apple-I-MD": payload["X-Apple-I-MD"],
            "X-Apple-I-MD-M": payload["X-Apple-I-MD-M"],
        }

    def client_provided_data(self):
        # These really are the strings "true"/"false", not plist booleans —
        # isideload sends them that way and Apple accepts it.
        cpd = {
            "bootstrap": "true",
            "icscrec": "true",
            "loc": "en_US",
            "pbe": "false",
            "prkgen": "true",
            "svct": "iCloud",
        }
        cpd.update(self.headers())
        return cpd


# ----------------------------------------------------------------------------
# GrandSlam
# ----------------------------------------------------------------------------

class GrandSlam:
    def __init__(self, anisette):
        self.anisette = anisette
        status, _, body = request("GET", GSA_URL_BAG, headers=self.base_headers())
        if status != 200:
            raise Fail("Could not reach Apple's GrandSlam service (HTTP %d)." % status)
        self.url_bag = plistlib.loads(body)["urls"]

    def base_headers(self, plist=True):
        headers = {}
        if plist:
            headers["Content-Type"] = "text/x-xml-plist"
            headers["Accept"] = "text/x-xml-plist"
        headers["X-Mme-Client-Info"] = self.anisette.client_info
        headers["User-Agent"] = self.anisette.user_agent
        headers["X-Xcode-Version"] = "14.2 (14C18)"
        headers["X-Apple-App-Info"] = "com.apple.gs.xcode.auth"
        return headers

    def url(self, key):
        if key not in self.url_bag:
            raise Fail("Apple's URL bag has no '%s' entry." % key)
        return self.url_bag[key]

    def plist_request(self, url, body, extra_headers=None):
        headers = self.base_headers()
        headers.update(extra_headers or {})
        payload = plistlib.dumps(body, fmt=plistlib.FMT_XML)
        status, _, response = request("POST", url, headers=headers, body=payload)
        if status != 200:
            raise Fail("Apple returned HTTP %d for %s." % (status, url))
        parsed = plistlib.loads(response)
        if "Response" not in parsed:
            raise Fail("Unexpected reply from Apple (no Response section).")
        return check_gs_error(parsed["Response"])


def check_gs_error(response):
    status = response.get("Status", response)
    code = status.get("ec", 0)
    if code:
        raise Fail("Apple rejected the request (%s): %s"
                   % (code, status.get("em", "no message")))
    return response


# ----------------------------------------------------------------------------
# Apple ID sign-in
# ----------------------------------------------------------------------------

class AppleAccount:
    def __init__(self, email, gs, anisette):
        self.email = email
        self.gs = gs
        self.anisette = anisette
        self.spd = None

    def login(self, password, ask_code):
        state = self._login_once(password)
        for _ in range(10):
            if state == "ok":
                return
            if state == "device-2fa":
                self._device_2fa(ask_code)
            elif state == "sms-2fa":
                self._sms_2fa(ask_code)
            else:
                # "repair" and friends: the session is usable if a PET came back.
                if self._pet():
                    return
                raise Fail("Apple wants an extra sign-in step this script cannot do: %s.\n"
                           "    Sign in once at https://appleid.apple.com in Safari, then retry." % state)
            state = self._login_once(password)
        raise Fail("Sign-in did not settle after 10 attempts.")

    def _pet(self):
        try:
            return self.spd["t"]["com.apple.gs.idms.pet"]["token"]
        except (KeyError, TypeError):
            return None

    def _login_once(self, password):
        # One anisette fetch for both legs of the handshake. X-Apple-I-MD is a
        # one-time password, but the pair belongs to a single SRP exchange —
        # isideload reuses it here and refreshing mid-handshake risks Apple
        # rejecting the second leg.
        cpd = self.anisette.client_provided_data()
        srp = SRPClient()

        first = self.gs.plist_request(self.gs.url("gsService"), {
            "Header": {"Version": "1.0.1"},
            "Request": {
                "A2k": srp.a_pub,
                "cpd": cpd,
                "o": "init",
                "ps": ["s2k", "s2k_fo"],
                "u": self.email,
            },
        })

        password_key = srp_password_key(
            password, bytes(first["s"]), int(first["i"]), first["sp"]
        )
        proof = srp.process(self.email, password_key, bytes(first["s"]), bytes(first["B"]))

        second = self.gs.plist_request(
            self.gs.url("gsService"),
            {
                "Header": {"Version": "1.0.1"},
                "Request": {
                    "M1": proof,
                    "c": first["c"],
                    "cpd": cpd,
                    "o": "complete",
                    "u": self.email,
                },
            },
            extra_headers={"Connection": "close"},
        )

        if not srp.verify(bytes(second["M2"])):
            raise Fail("Apple's server proof did not verify. Refusing to continue.")

        self.spd = srp.decrypt_spd(bytes(second["spd"]))

        au = second.get("Status", {}).get("au")
        if au == "trustedDeviceSecondaryAuth":
            return "device-2fa"
        if au == "secondaryAuth":
            return "sms-2fa"
        if au == "repair" or au is None:
            return "ok"
        return au

    def _identity_headers(self):
        headers = self.anisette.headers()
        identity = "%s:%s" % (self.spd["adsid"], self.spd["GsIdmsToken"])
        headers["X-Apple-Identity-Token"] = base64.b64encode(identity.encode()).decode()
        headers["X-Apple-I-MD-RINFO"] = self.anisette.routing_info
        return headers

    def _device_2fa(self, ask_code):
        headers = self.gs.base_headers()
        headers.update(self._identity_headers())
        status, _, _ = request("GET", self.gs.url("trustedDeviceSecondaryAuth"), headers=headers)
        if status >= 400:
            raise Fail("Apple would not send a verification code (HTTP %d)." % status)
        info("A verification code has been sent to your trusted devices.")

        code = ask_code("Two-factor code")
        headers = self.gs.base_headers()
        headers.update(self._identity_headers())
        headers["security-code"] = code
        status, _, body = request("GET", self.gs.url("validateCode"), headers=headers)
        if status >= 400:
            raise Fail("Apple rejected the verification code (HTTP %d)." % status)
        check_gs_error(plistlib.loads(body))

    def _sms_2fa(self, ask_code):
        headers = self.gs.base_headers(plist=False)
        headers.update(self._identity_headers())
        status, _, _ = request("GET", self.gs.url("secondaryAuth"), headers=headers)
        if status >= 400:
            raise Fail("Apple would not send an SMS code (HTTP %d)." % status)
        info("A verification code has been sent by SMS.")

        code = ask_code("SMS code")
        headers = self.gs.base_headers(plist=False)
        headers.update(self._identity_headers())
        headers["Content-Type"] = "application/json"
        headers["Accept"] = "application/json, text/javascript, */*; q=0.01"
        status, _, body = request(
            "POST", "https://gsa.apple.com/auth/verify/phone/securitycode",
            headers=headers,
            body=json.dumps({
                "securityCode": {"code": code},
                "phoneNumber": {"id": 1},
                "mode": "sms",
            }),
        )
        if status >= 400:
            detail = body.decode("utf-8", "replace")
            try:
                first = json.loads(detail)["serviceErrors"][0]
                detail = "%s — %s" % (first.get("title", ""), first.get("message", ""))
            except (ValueError, KeyError, IndexError):
                pass
            raise Fail("Apple rejected the SMS code: %s" % detail.strip())

    def app_token(self, app):
        """Exchange the sign-in for a service token — 'xcode.auth' is the one
        the developer portal accepts."""
        if not app.startswith("com.apple.gs."):
            app = "com.apple.gs." + app

        adsid = self.spd["adsid"]
        session_key = bytes(self.spd["sk"])
        checksum = hmac.new(session_key, digestmod=hashlib.sha256)
        checksum.update(b"apptokens")
        checksum.update(adsid.encode())
        checksum.update(app.encode())

        response = self.gs.plist_request(self.gs.url("gsService"), {
            "Header": {"Version": "1.0.1"},
            "Request": {
                "app": [app],
                "c": self.spd["c"],
                "checksum": checksum.digest(),
                "cpd": self.anisette.client_provided_data(),
                "o": "apptokens",
                "u": adsid,
                "t": self.spd["GsIdmsToken"],
            },
        })

        blob = bytes(response["et"])
        if len(blob) < 35 or blob[:3] != b"XYZ":
            raise Fail("App token came back in an unrecognised format.")
        decrypted = aes_gcm_decrypt(
            session_key, blob[3:19], blob[19:-16], blob[:3], blob[-16:]
        )
        token = plistlib.loads(decrypted)
        if token.get("status-code") != 200:
            raise Fail("Apple refused the developer token (status %s)." % token.get("status-code"))
        return token["t"][app]["token"], adsid


# ----------------------------------------------------------------------------
# The developer portal (developerservices2 — the API Xcode itself uses)
# ----------------------------------------------------------------------------

def dev_url(endpoint, device_type="ios/"):
    return "https://%s/services/%s/%s%s.action?clientId=%s" % (
        DEV_HOST, DEV_PROTOCOL, device_type, endpoint, DEV_CLIENT_ID
    )


class DeveloperSession:
    def __init__(self, account, token, adsid):
        self.account = account
        self.gs = account.gs
        self.anisette = account.anisette
        self.token = token
        self.adsid = adsid

    def headers(self):
        headers = self.gs.base_headers()
        headers.update(self.anisette.headers())
        headers["X-Apple-GS-Token"] = self.token
        headers["X-Apple-I-Identity-Id"] = self.adsid
        return headers

    def call(self, endpoint, body=None, key=None, device_type="ios/"):
        payload = {
            "clientId": DEV_CLIENT_ID,
            "protocolVersion": DEV_PROTOCOL,
            "requestId": str(uuid.uuid4()).upper(),
            "userLocale": ["en_US"],
        }
        payload.update(body or {})

        url = dev_url(endpoint, device_type)
        status, _, raw = request(
            "POST", url, headers=self.headers(),
            body=plistlib.dumps(payload, fmt=plistlib.FMT_XML),
        )
        if status != 200:
            raise Fail("Developer portal returned HTTP %d for %s." % (status, endpoint))

        response = plistlib.loads(raw)
        code = response.get("resultCode", 0)
        if code:
            message = response.get("userString") or response.get("resultString") or "no message"
            raise PortalError(int(code), message)
        if key is not None:
            if key not in response:
                raise Fail("Developer portal reply for %s had no '%s'." % (endpoint, key))
            return response[key]
        return response


class PortalError(Fail):
    def __init__(self, code, message):
        super().__init__("Apple developer portal error %d: %s" % (code, message))
        self.code = code
        self.message = message


# -- teams --------------------------------------------------------------------

def pick_team(session):
    teams = session.call("listTeams", key="teams", device_type="")
    if not teams:
        raise Fail("This Apple account has no developer team.\n"
                   "    Open https://developer.apple.com in Safari, sign in once, and accept the\n"
                   "    free developer agreement, then run this again.")
    if len(teams) == 1:
        return teams[0]

    info("This account is on more than one team:")
    for index, team in enumerate(teams, 1):
        info("  %d) %s (%s, %s)" % (index, team.get("name", "?"), team["teamId"],
                                    team.get("type", "?")))
    while True:
        choice = ask("Which team should sign the app?", "1")
        if choice.isdigit() and 1 <= int(choice) <= len(teams):
            return teams[int(choice) - 1]


# -- device -------------------------------------------------------------------

def ensure_device(session, team, udid, name):
    devices = session.call("listDevices", {"teamId": team["teamId"]}, key="devices")
    if any(d.get("deviceNumber") == udid for d in devices):
        return
    try:
        session.call("addDevice", {
            "teamId": team["teamId"], "name": name, "deviceNumber": udid,
        }, key="device")
    except PortalError as exc:
        if exc.code == 35:  # already registered on this team
            return
        raise


# -- signing identity ---------------------------------------------------------

def private_key_path(email):
    digest = hashlib.sha256(email.encode()).hexdigest()
    return os.path.join(STORAGE, digest, "key.pem")


def ensure_private_key(email):
    """One RSA key per Apple ID, kept forever. Apple ties the certificate to
    this key, so losing it means burning one of the account's two cert slots."""
    path = private_key_path(email)
    if os.path.exists(path):
        return path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    step("Generating a 2048-bit RSA key (slow under emulation — one time only)")
    openssl(["genrsa", "-out", path, "2048"], capture=False)
    os.chmod(path, 0o600)
    return path


def key_modulus(path):
    return openssl(["rsa", "-in", path, "-noout", "-modulus"]).strip()


def cert_modulus(der_path):
    return openssl(["x509", "-inform", "DER", "-in", der_path, "-noout", "-modulus"]).strip()


def list_ios_certs(session, team):
    certs = session.call(
        "listAllDevelopmentCerts", {"teamId": team["teamId"]}, key="certificates"
    )
    result = []
    for cert in certs:
        platform = (cert.get("certificatePlatform")
                    or (cert.get("certificateType") or {}).get("platform") or "ios")
        if str(platform).lower() == "ios":
            result.append(cert)
    return result


def obtain_certificate(session, team, key_path, workdir):
    """Return (cert_pem_path, was_reused).

    Mirrors isideload's rule: a certificate is reusable only when its
    machineName matches ours AND it was issued to this exact private key.
    """
    cert_der = os.path.join(workdir, "cert.der")
    cert_pem = os.path.join(workdir, "cert.pem")
    mine = key_modulus(key_path)

    def match(certs):
        for cert in certs:
            if not cert.get("certContent") or not cert.get("machineId"):
                continue
            if cert.get("machineName") != MACHINE_NAME:
                continue
            with open(cert_der, "wb") as handle:
                handle.write(bytes(cert["certContent"]))
            try:
                if cert_modulus(cert_der) == mine:
                    return cert
            except Fail:
                continue
        return None

    existing = list_ios_certs(session, team)
    found = match(existing)
    if found:
        openssl(["x509", "-inform", "DER", "-in", cert_der, "-out", cert_pem], capture=False)
        return cert_pem, True

    csr = openssl([
        "req", "-new", "-key", key_path, "-sha256",
        "-subj", "/C=US/ST=STATE/L=LOCAL/O=ORGNIZATION/CN=CN",
    ]).decode()

    for attempt in range(4):
        try:
            result = session.call("submitDevelopmentCSR", {
                "teamId": team["teamId"],
                "csrContent": csr,
                "machineName": MACHINE_NAME,
                "machineId": str(uuid.uuid4()).upper(),
            }, key="certRequest")
        except PortalError as exc:
            # 7460: the account is already at its certificate limit. A free
            # account gets two, and Xcode/AltStore/SideStore each eat one.
            if exc.code != 7460 or attempt == 3:
                raise
            if not revoke_to_make_room(session, team):
                raise Fail(
                    "Apple says this account already has the maximum number of development\n"
                    "    certificates, and nothing was revoked. Free accounts get two — revoke one at\n"
                    "    https://developer.apple.com/account/resources/certificates and try again."
                )
            continue

        request_id = result["certRequestId"]
        for cert in list_ios_certs(session, team):
            if cert.get("certificateId") == request_id and cert.get("certContent"):
                with open(cert_der, "wb") as handle:
                    handle.write(bytes(cert["certContent"]))
                openssl(["x509", "-inform", "DER", "-in", cert_der, "-out", cert_pem],
                        capture=False)
                return cert_pem, False
        raise Fail("Apple issued a certificate but would not hand it back.")

    raise Fail("Could not obtain a signing certificate.")


def revoke_to_make_room(session, team):
    """Ask before revoking: it breaks every app already signed with that
    certificate, including ones this script did not create."""
    certs = [c for c in list_ios_certs(session, team) if c.get("serialNumber")]
    if not certs:
        return False

    warn("Apple will not issue another certificate until an old one is revoked.")
    warn("Revoking one stops every app already signed with it from launching.")
    for index, cert in enumerate(certs, 1):
        info("  %d) %s — %s (expires %s)" % (
            index,
            cert.get("machineName") or "unnamed",
            cert.get("name") or cert.get("serialNumber"),
            cert.get("expirationDate", "?"),
        ))
    info("  0) cancel")

    choice = ask("Revoke which certificate?", "0")
    if not choice.isdigit() or not 1 <= int(choice) <= len(certs):
        return False
    victim = certs[int(choice) - 1]
    if not confirm("Really revoke '%s'?" % (victim.get("machineName") or victim["serialNumber"])):
        return False

    session.call("revokeDevelopmentCert", {
        "teamId": team["teamId"], "serialNumber": victim["serialNumber"],
    })
    ok("Revoked.")
    return True


# -- App ID and profile -------------------------------------------------------

def ensure_app_id(session, team, identifier, name):
    listing = session.call("listAppIds", {"teamId": team["teamId"]})
    for app_id in listing.get("appIds", []):
        if app_id.get("identifier") == identifier:
            return app_id

    available = listing.get("availableQuantity")
    if available is not None and available <= 0:
        raise Fail(
            "This account has no free App ID slots left (they expire after 7 days on a\n"
            "    free account). Delete one at\n"
            "    https://developer.apple.com/account/resources/identifiers and try again."
        )
    return session.call("addAppId", {
        "teamId": team["teamId"], "identifier": identifier, "name": name,
    }, key="appId")


def download_profile(session, team, app_id):
    profile = session.call("downloadTeamProvisioningProfile", {
        "teamId": team["teamId"], "appIdId": app_id["appIdId"],
    }, key="provisioningProfile")
    return bytes(profile["encodedProfile"])


def profile_entitlements(profile):
    plist = profile_plist(profile)
    entitlements = plist.get("Entitlements")
    if not entitlements:
        raise Fail("Apple's provisioning profile carries no entitlements — the App ID may "
                   "not be fully registered yet. Try again in a minute.")
    return entitlements


def profile_plist(data):
    """Pull the plist out of the CMS envelope a .mobileprovision is wrapped in.
    Same trick isideload uses: the payload is plain XML in the middle."""
    start = data.find(b"<plist")
    end = data.rfind(b"</plist>")
    if start < 0 or end < 0:
        raise Fail("The provisioning profile Apple returned is not readable.")
    return plistlib.loads(data[start:end + 8])


# ----------------------------------------------------------------------------
# The .ipa
# ----------------------------------------------------------------------------

def latest_release_ipa(beta=False):
    status, _, body = request("GET", RELEASE_API, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "sideinstaller-ish",
    })
    if status != 200:
        raise Fail("Could not ask GitHub for the latest SideInstaller release (HTTP %d)." % status)
    for release in json.loads(body):
        if release.get("draft"):
            continue
        if release.get("prerelease") != beta:
            continue
        for asset in release.get("assets", []):
            if asset["name"].endswith(".ipa"):
                return release["tag_name"], asset["browser_download_url"]
    raise Fail("No %s release with an .ipa asset was found." % ("beta" if beta else "stable"))


def read_app_info(ipa_path):
    """Bundle id, version and display name, straight out of the archive."""
    with zipfile.ZipFile(ipa_path) as archive:
        candidates = [
            n for n in archive.namelist()
            if re.match(r"^Payload/[^/]+\.app/Info\.plist$", n)
        ]
        if not candidates:
            raise Fail("That .ipa has no Payload/*.app/Info.plist — is it really an IPA?")
        name = sorted(candidates)[0]
        plist = plistlib.loads(archive.read(name))
    return {
        "bundle_id": plist["CFBundleIdentifier"],
        "version": plist.get("CFBundleShortVersionString", "1.0"),
        "title": plist.get("CFBundleDisplayName") or plist.get("CFBundleName") or "SideInstaller",
    }


def find_zsign():
    for candidate in (
        os.environ.get("ZSIGN"),
        os.path.join(STORAGE, "bin", "zsign"),
        shutil.which("zsign"),
    ):
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def sign_ipa(ipa_path, out_path, workdir, key_path, cert_path, profile, entitlements,
             bundle_id):
    zsign = find_zsign()
    if not zsign:
        raise Fail(
            "zsign is not installed.\n"
            "    Run:  sh install.sh --build-signer\n"
            "    (it compiles zsign from source; under iSH's emulation expect 10–30 minutes,\n"
            "     but only once — the binary is cached in %s/bin.)" % STORAGE
        )

    profile_path = os.path.join(workdir, "profile.mobileprovision")
    with open(profile_path, "wb") as handle:
        handle.write(profile)
    ent_path = os.path.join(workdir, "entitlements.plist")
    with open(ent_path, "wb") as handle:
        handle.write(plistlib.dumps(entitlements, fmt=plistlib.FMT_XML))

    command = [
        zsign,
        "-k", key_path,
        "-c", cert_path,
        "-m", profile_path,
        "-e", ent_path,
        "-b", bundle_id,
        "-z", "1",          # emulated CPU: deflate level 9 is minutes of nothing
        "-o", out_path,
        ipa_path,
    ]
    proc = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = proc.stdout.decode("utf-8", "replace")
    if proc.returncode != 0 or not os.path.exists(out_path):
        raise Fail("zsign failed:\n%s" % output.strip())
    return output


# ----------------------------------------------------------------------------
# Delivery
#
# iSH cannot install an app: it is an ordinary sandboxed App Store app with no
# route to installd. The only install channel available to anyone without a
# computer is itms-services://, which Safari hands to the App Store daemon —
# and that daemon insists the manifest be served over HTTPS with a chain the
# device trusts. So the script becomes a small HTTPS server, with a throwaway
# CA the user installs, and Safari does the last step.
# ----------------------------------------------------------------------------

import http.server  # noqa: E402 - kept next to the code that uses it
import threading    # noqa: E402


def make_local_tls(workdir):
    """A one-off CA plus a leaf for localhost. EC, not RSA: on an emulated i386
    two RSA keygens are a coffee break, and iOS is happy with P-256."""
    ca_key = os.path.join(workdir, "ca.key")
    ca_crt = os.path.join(workdir, "ca.crt")
    srv_key = os.path.join(workdir, "srv.key")
    srv_crt = os.path.join(workdir, "srv.crt")
    srv_csr = os.path.join(workdir, "srv.csr")
    ext = os.path.join(workdir, "srv.ext")

    openssl(["ecparam", "-genkey", "-name", "prime256v1", "-out", ca_key], capture=False)
    openssl([
        "req", "-x509", "-new", "-key", ca_key, "-sha256", "-days", "365",
        "-subj", "/CN=SideInstaller Local CA",
        "-addext", "basicConstraints=critical,CA:TRUE,pathlen:0",
        "-addext", "keyUsage=critical,keyCertSign,cRLSign",
        "-out", ca_crt,
    ], capture=False)

    openssl(["ecparam", "-genkey", "-name", "prime256v1", "-out", srv_key], capture=False)
    openssl(["req", "-new", "-key", srv_key, "-subj", "/CN=localhost", "-out", srv_csr],
            capture=False)
    with open(ext, "w") as handle:
        # iOS 13+ rejects server certs without a SAN, without serverAuth, or
        # valid for more than 398 days. All three are set deliberately.
        handle.write(
            "basicConstraints=critical,CA:FALSE\n"
            "keyUsage=critical,digitalSignature,keyEncipherment\n"
            "extendedKeyUsage=serverAuth\n"
            "subjectAltName=DNS:localhost,IP:127.0.0.1\n"
        )
    openssl([
        "x509", "-req", "-in", srv_csr, "-CA", ca_crt, "-CAkey", ca_key,
        "-CAcreateserial", "-sha256", "-days", "365", "-extfile", ext, "-out", srv_crt,
    ], capture=False)

    return ca_crt, srv_key, srv_crt


def ca_mobileconfig(ca_crt_path):
    der = openssl(["x509", "-in", ca_crt_path, "-outform", "DER"])
    payload = {
        "PayloadContent": [{
            "PayloadType": "com.apple.security.root",
            "PayloadVersion": 1,
            "PayloadIdentifier": "net.sideinstaller.ish.ca",
            "PayloadUUID": str(uuid.uuid4()).upper(),
            "PayloadDisplayName": "SideInstaller local CA",
            "PayloadCertificateFileName": "ca.crt",
            "PayloadContent": der,
        }],
        "PayloadType": "Configuration",
        "PayloadVersion": 1,
        "PayloadIdentifier": "net.sideinstaller.ish",
        "PayloadUUID": str(uuid.uuid4()).upper(),
        "PayloadDisplayName": "SideInstaller local CA",
        "PayloadDescription":
            "Temporary certificate authority so this phone can install an app from a web "
            "server running inside iSH. Remove it once SideInstaller is installed.",
        "PayloadRemovalDisallowed": False,
    }
    return plistlib.dumps(payload, fmt=plistlib.FMT_XML)


def udid_mobileconfig(callback_url):
    payload = {
        "PayloadContent": {
            "URL": callback_url,
            "DeviceAttributes": ["UDID", "PRODUCT", "VERSION", "DEVICE_NAME"],
        },
        "PayloadType": "Profile Service",
        "PayloadVersion": 1,
        "PayloadIdentifier": "net.sideinstaller.ish.udid",
        "PayloadUUID": str(uuid.uuid4()).upper(),
        "PayloadDisplayName": "SideInstaller — read this device's UDID",
        "PayloadDescription":
            "Sends this device's UDID to the copy of iSH running on it, so the app can be "
            "signed for this device. Nothing leaves the phone.",
        "PayloadOrganization": "SideInstaller",
    }
    return plistlib.dumps(payload, fmt=plistlib.FMT_XML)


PAGE = """<!doctype html><meta name=viewport content="width=device-width,initial-scale=1">
<title>SideInstaller</title>
<style>body{font:17px -apple-system,sans-serif;margin:0;padding:2rem 1.25rem;
background:#111;color:#eee}a.btn{display:block;text-align:center;background:#2ea44f;color:#fff;
text-decoration:none;padding:1rem;border-radius:14px;font-weight:600;margin:1.5rem 0}
code{background:#222;padding:.15rem .35rem;border-radius:5px}h1{font-size:1.4rem}
p{line-height:1.5;color:#bbb}</style><h1>%s</h1>%s"""


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "SideInstaller-iSH"

    def log_message(self, *args):
        pass

    def _send(self, body, content_type, status=200):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        state = self.server.state
        path = urllib.parse.urlsplit(self.path).path

        if path == "/ca.mobileconfig":
            self._send(state["ca_profile"], "application/x-apple-aspen-config")
        elif path == "/udid.mobileconfig":
            self._send(state["udid_profile"], "application/x-apple-aspen-config")
        elif path == "/manifest.plist" and state.get("manifest"):
            self._send(state["manifest"], "text/xml")
        elif path == "/app.ipa" and state.get("ipa"):
            with open(state["ipa"], "rb") as handle:
                self._send(handle.read(), "application/octet-stream")
        elif path == "/":
            self._send(self.index(), "text/html; charset=utf-8")
        else:
            self._send("not found", "text/plain", status=404)

    def do_POST(self):
        state = self.server.state
        if urllib.parse.urlsplit(self.path).path != "/udid":
            self._send("not found", "text/plain", status=404)
            return
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length)
        # The device posts a CMS-signed plist. The UDID is plain text inside it.
        match = re.search(rb"<key>UDID</key>\s*<string>([^<]+)</string>", body)
        if match:
            state["udid"] = match.group(1).decode()
            state["udid_event"].set()
        self._send(PAGE % ("Got it", "<p>You can go back to iSH now.</p>"),
                   "text/html; charset=utf-8")

    def index(self):
        state = self.server.state
        trust = (
            "<p>Install it from <b>Settings → General → VPN &amp; Device Management</b>, then "
            "switch it on under <b>Settings → General → About → Certificate Trust "
            "Settings</b>.</p>")
        if state.get("manifest"):
            link = ("itms-services://?action=download-manifest&url="
                    + urllib.parse.quote(state["base"] + "/manifest.plist", safe=""))
            return PAGE % ("SideInstaller is signed", (
                '<a class=btn href="%s">Install SideInstaller</a>'
                "<p>Signed for this device with your own Apple account. Good for 7 days, "
                "after which SideInstaller can renew itself.</p>"
                "<p>If tapping Install does nothing, this phone does not trust the local "
                'certificate yet: <a href="/ca.mobileconfig">download it here</a>.</p>%s'
                % (link, trust)))
        return PAGE % ("SideInstaller setup", (
            '<a class=btn href="/ca.mobileconfig">1. Download the local certificate</a>%s'
            '<a class=btn href="/udid.mobileconfig">2. Send this device\'s UDID to iSH</a>'
            "<p>Step 2 only works once step 1 is installed and trusted.</p>" % trust))


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def start_servers(state, http_port, https_port, srv_key, srv_crt):
    plain = Server(("0.0.0.0", http_port), Handler)
    plain.state = state
    threading.Thread(target=plain.serve_forever, daemon=True).start()

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(srv_crt, srv_key)
    secure = Server(("0.0.0.0", https_port), Handler)
    secure.state = state
    secure.socket = context.wrap_socket(secure.socket, server_side=True)
    threading.Thread(target=secure.serve_forever, daemon=True).start()

    return plain, secure


def make_manifest(base_url, bundle_id, version, title):
    return plistlib.dumps({
        "items": [{
            "assets": [{"kind": "software-package", "url": base_url + "/app.ipa"}],
            "metadata": {
                "bundle-identifier": bundle_id,
                "bundle-version": version,
                "kind": "software",
                "title": title,
            },
        }]
    }, fmt=plistlib.FMT_XML)


# ----------------------------------------------------------------------------
# UDID
# ----------------------------------------------------------------------------

def capture_udid(state, http_port, https_port):
    """Serve a Profile Service payload and wait for the device to post back."""
    step("Reading this device's UDID")
    info("In Safari, open:  http://127.0.0.1:%d/" % http_port)
    info("Install the certificate (step 1), trust it, then tap step 2.")
    info("Leave iSH open in the background — if iOS suspends it, the page stops answering.")
    info("Ctrl-C to give up and type the UDID by hand instead.")
    try:
        while not state["udid_event"].wait(1):
            pass
    except KeyboardInterrupt:
        print()
        return None
    ok("UDID: %s" % state["udid"])
    return state["udid"]


def ask_udid():
    print()
    info("This device's UDID is needed: a free Apple account can only sign an app for")
    info("devices it has registered, and a sandboxed app like iSH cannot read its own.")
    info("Ways to get it without a computer:")
    info("  • if SideStore or AltStore was ever set up here, it shows the UDID in Settings")
    info("  • run this script with --capture-udid to have the phone report it to iSH")
    info("  • a UDID-lookup website in Safari (it will see your UDID — pick one you trust)")
    print()
    while True:
        value = ask("UDID").strip()
        if UDID_RE.match(value):
            return value
        warn("That isn't a UDID. Expect 25 characters with a dash, or 40 hex characters.")


# ----------------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------------

BANNER = """
  SideInstaller — sign it with your own Apple account, from iSH

  Your password is not sent anywhere. Apple's sign-in uses SRP, so what goes
  over the wire is a proof derived from the password, never the password. The
  anisette server sees only device identifiers, never your account.

  Only ever run this script from FrizzleM/SideInstaller. A fork of this file
  could send your credentials somewhere else and you would not be able to tell.
"""


def parse_args(argv):
    options = {
        "udid": os.environ.get("UDID"),
        "email": os.environ.get("APPLE_ID"),
        "ipa": None,
        "beta": False,
        "anisette": DEFAULT_ANISETTE,
        "http_port": 8888,
        "https_port": 8443,
        "serve": True,
        "capture_udid": False,
        "out": None,
    }
    args = list(argv)
    while args:
        arg = args.pop(0)
        if arg in ("-h", "--help"):
            print(__doc__)
            print("usage: sideinstaller.py [--udid UDID] [--email ADDRESS] [--ipa PATH|URL]")
            print("                        [--beta] [--anisette URL] [--capture-udid]")
            print("                        [--port N] [--tls-port N] [--no-serve] [--out PATH]")
            sys.exit(0)
        elif arg == "--udid":
            options["udid"] = args.pop(0)
        elif arg == "--email":
            options["email"] = args.pop(0)
        elif arg == "--ipa":
            options["ipa"] = args.pop(0)
        elif arg == "--beta":
            options["beta"] = True
        elif arg == "--anisette":
            options["anisette"] = args.pop(0)
        elif arg == "--port":
            options["http_port"] = int(args.pop(0))
        elif arg == "--tls-port":
            options["https_port"] = int(args.pop(0))
        elif arg == "--no-serve":
            options["serve"] = False
        elif arg == "--capture-udid":
            options["capture_udid"] = True
        elif arg == "--out":
            options["out"] = args.pop(0)
        else:
            die("Unknown option: %s (try --help)" % arg)
    return options


def anisette_candidates(preferred):
    """The user's choice first, then the live community list, then the copy
    baked in here."""
    urls = [preferred]
    try:
        status, _, body = request("GET", ANISETTE_LIST_URL,
                                  headers={"User-Agent": "SideInstaller"}, timeout=15)
        if status == 200:
            for server in json.loads(body).get("servers", []):
                address = (server.get("address") or "").rstrip("/")
                if address.startswith("http"):
                    urls.append(address)
    except (OSError, ValueError, ssl.SSLError):
        pass
    urls.extend(BUNDLED_ANISETTE)

    seen = set()
    unique = []
    for url in urls:
        key = url.rstrip("/")
        if key and key not in seen:
            seen.add(key)
            unique.append(key)
    return unique


def connect_anisette(url_hint, state_path):
    """Return (anisette, grandslam), both proven to work.

    Provisioning is inside the loop on purpose: a server that answers
    /v3/client_info happily will still drop the provisioning socket when it is
    busy, and that has to fail over to the next one like any other outage.
    """
    tried = []
    for url in anisette_candidates(url_hint)[:MAX_ANISETTE_TRIES]:
        try:
            anisette = Anisette(url, state_path)
            version = anisette.detect()
            gs = GrandSlam(anisette)

            if anisette.needs_provisioning():
                info("Provisioning with %s (first run only)…" % url)
                anisette.provision(gs)
            try:
                anisette.headers()
            except Fail:
                # A stored blob this server won't accept: throw it away and
                # provision again before giving up on the server.
                if anisette.version != 3 or not anisette.adi_pb:
                    raise
                warn("Stored anisette identity was rejected; provisioning again.")
                anisette.forget_provisioning()
                anisette.provision(gs)
                anisette.headers()

            ok("Anisette: %s (v%d)" % (url, version))
            return anisette, gs
        except (Fail, OSError, ssl.SSLError) as exc:
            tried.append("%s — %s" % (url, exc))
            warn("Anisette server unavailable: %s" % url)
    raise Fail("No anisette server answered. Tried:\n      " + "\n      ".join(tried))


def main(argv):
    options = parse_args(argv)
    os.makedirs(STORAGE, exist_ok=True)
    for stale in os.listdir(STORAGE):
        if stale.startswith("sideinstaller-"):
            shutil.rmtree(os.path.join(STORAGE, stale), ignore_errors=True)
    workdir = tempfile.mkdtemp(prefix="sideinstaller-", dir=STORAGE)

    if not shutil.which("openssl"):
        die("openssl is missing. Run:  apk add openssl")

    print(BANNER)

    # -- the delivery server doubles as the UDID reader, so it comes up first --
    ca_crt, srv_key, srv_crt = make_local_tls(workdir)
    base_url = "https://127.0.0.1:%d" % options["https_port"]
    state = {
        "ca_profile": ca_mobileconfig(ca_crt),
        "udid_profile": udid_mobileconfig(base_url + "/udid"),
        "udid_event": threading.Event(),
        "base": base_url,
    }
    try:
        servers = start_servers(state, options["http_port"], options["https_port"],
                                srv_key, srv_crt)
    except OSError as exc:
        die("Could not open the local web server: %s\n"
            "    Another copy may already be running; try --port/--tls-port." % exc)

    udid = options["udid"]
    if options["capture_udid"] or (not udid and confirm(
            "Try to read this device's UDID automatically?", True)):
        udid = capture_udid(state, options["http_port"], options["https_port"]) or udid
        if options["capture_udid"]:
            if not udid:
                die("No UDID captured.")
            print("UDID: %s" % udid)
            return
    if not udid:
        udid = ask_udid()

    # -- credentials ----------------------------------------------------------
    step("Apple account")
    email = options["email"] or ask("Apple ID (email)")
    password = getpass.getpass("Password (not shown, not stored, not transmitted): ")
    if not password:
        die("No password entered.")

    def ask_code(label):
        code = ask(label)
        return re.sub(r"\D", "", code)

    # -- sign in --------------------------------------------------------------
    step("Signing in to Apple")
    anisette, gs = connect_anisette(options["anisette"],
                                    os.path.join(STORAGE, "anisette.json"))
    account = AppleAccount(email, gs, anisette)
    account.login(password, ask_code)
    password = None
    name = account.spd.get("fn", "")
    ok("Signed in%s" % (" as %s" % name if name else ""))

    token, adsid = account.app_token("xcode.auth")
    session = DeveloperSession(account, token, adsid)

    team = pick_team(session)
    ok("Team: %s (%s)" % (team.get("name", "?"), team["teamId"]))

    step("Registering this device")
    ensure_device(session, team, udid, "iPhone (iSH)")
    ok("Device %s is registered for development" % udid)

    # -- certificate ----------------------------------------------------------
    step("Signing certificate")
    key_path = ensure_private_key(email)
    cert_pem, reused = obtain_certificate(session, team, key_path, workdir)
    ok("Certificate %s" % ("reused" if reused else "issued"))

    # -- the app --------------------------------------------------------------
    step("Fetching SideInstaller")
    if options["ipa"] and os.path.exists(options["ipa"]):
        ipa_path = options["ipa"]
        info("Using %s" % ipa_path)
    else:
        if options["ipa"]:
            url, tag = options["ipa"], "custom"
        else:
            tag, url = latest_release_ipa(options["beta"])
        ipa_path = os.path.join(workdir, "unsigned.ipa")
        info("%s — %s" % (tag, url))
        download(url, ipa_path)
        ok("Downloaded %.1f MB" % (os.path.getsize(ipa_path) / 1e6))

    app = read_app_info(ipa_path)
    bundle_id = "%s.%s" % (app["bundle_id"], team["teamId"])

    step("Registering the app with Apple")
    app_id = ensure_app_id(session, team, bundle_id, "SideInstaller")
    profile = download_profile(session, team, app_id)
    entitlements = profile_entitlements(profile)
    ok("Provisioning profile for %s" % bundle_id)

    step("Signing")
    out_path = options["out"] or os.path.join(HOME, "SideInstaller-signed.ipa")
    sign_ipa(ipa_path, out_path, workdir, key_path, cert_pem, profile, entitlements,
             bundle_id)
    ok("Signed → %s (%.1f MB)" % (out_path, os.path.getsize(out_path) / 1e6))

    # -- install --------------------------------------------------------------
    state["ipa"] = out_path
    state["manifest"] = make_manifest(base_url, bundle_id, app["version"], app["title"])

    if not options["serve"]:
        step("Done")
        info("The signed .ipa is at %s — reachable from the Files app under iSH." % out_path)
        return

    step("Installing")
    print()
    info("Open Safari and go to:   http://127.0.0.1:%d/" % options["http_port"])
    info("Tap Install. If nothing happens, that page also links to the local")
    info("certificate — install it, trust it under Settings → General → About →")
    info("Certificate Trust Settings, and tap Install again.")
    print()
    info("Keep iSH in the foreground or the server stops answering.")
    info("Ctrl-C when the app has installed.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print()
        for server in servers:
            server.shutdown()
        ok("The signed .ipa is also at %s if you need it again." % out_path)
        info("Free-account signing lasts 7 days. SideInstaller can re-sign itself before then.")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except Fail as error:
        die(str(error))
    except ssl.SSLError as error:
        die("TLS error: %s\n    If this keeps happening: apk add ca-certificates && "
            "update-ca-certificates" % error)
    except OSError as error:
        die("Network error: %s\n    iSH loses its sockets when iOS suspends it — keep it in "
            "the foreground and try again." % error)
    except KeyboardInterrupt:
        print()
        die("Cancelled.")
