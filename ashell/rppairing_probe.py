#!/usr/bin/env python3
"""rppairing_probe.py -- does this iPhone answer the RPPairing handshake?

Sends the *first* message SideInstaller sends (`attemptPairVerify`), framed the
way idevice frames it:

    b"RPPairing" + u16be(json_length) + json

Every earlier probe opened with the HTTP/2 preface instead, because both
bootstrap builds assumed port 49152 was RemoteServiceDiscovery. It is not.
`tunnel_create_rppairing_multihost` (rust-core/vendor/idevice-ffi/src/
tunnel_provider.rs) connects straight to that address and wraps the socket in
`RpPairingSocket`, which speaks the raw framing above -- no RSD, no RemoteXPC,
no HTTP/2. RSD lives *inside* the tunnel, after pairing.

That also explains the 11-byte cutoff the a-Shell battery measured: the header
is 9 magic bytes + a 2-byte length, so a peer that reads 11 bytes and finds the
wrong magic resets exactly there, whatever the content. The control below
reproduces it on purpose.

Usage (a-Shell, or iSH with `apk add python3`):

    python3 rppairing_probe.py                 # 10.7.0.1 (LocalDevVPN peer)
    python3 rppairing_probe.py 127.0.0.1       # control: does loopback answer?
    python3 rppairing_probe.py 192.168.1.42    # this iPhone's own Wi-Fi address
    python3 rppairing_probe.py 10.7.0.1 49152  # explicit port

Wi-Fi on, LocalDevVPN connected, app in the foreground. Nothing here touches an
Apple account and nothing pairs -- `attemptPairVerify` with no record gets a
refusal, and a refusal that arrives *in RPPairing framing* is the whole point.
"""

import json
import socket
import struct
import sys

MAGIC = b"RPPairing"
WIRE_PROTOCOL_VERSION = 19
DEFAULT_HOST = "10.7.0.1"
DEFAULT_PORT = 49152
TIMEOUT = 10.0

HELLO = {
    "message": {
        "plain": {
            "_0": {
                "request": {
                    "_0": {
                        "handshake": {
                            "_0": {
                                "hostOptions": {"attemptPairVerify": True},
                                "wireProtocolVersion": WIRE_PROTOCOL_VERSION,
                            }
                        }
                    }
                }
            }
        }
    },
    "originatedBy": "host",
    "sequenceNumber": 0,
}


def frame(obj):
    body = json.dumps(obj, separators=(",", ":")).encode()
    return MAGIC + struct.pack(">H", len(body)) + body


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise EOFError("peer closed after %d of %d bytes" % (len(buf), n))
        buf += chunk
    return buf


def handshake(host, port):
    """Send a real RPPairing frame. True if the device answers in kind."""
    print("[handshake] %s:%d" % (host, port))
    try:
        sock = socket.create_connection((host, port), TIMEOUT)
    except OSError as exc:
        print("  connect failed: %s" % exc)
        return False
    sock.settimeout(TIMEOUT)
    try:
        payload = frame(HELLO)
        sock.sendall(payload)
        print("  sent %d bytes (11-byte header + %d json)" % (len(payload), len(payload) - 11))
        try:
            head = recv_exact(sock, 11)
        except (EOFError, OSError) as exc:
            print("  no reply: %s" % exc)
            return False
        if head[:9] != MAGIC:
            print("  reply is NOT RPPairing framed: %r" % head)
            return False
        length = struct.unpack(">H", head[9:11])[0]
        body = recv_exact(sock, length)
        print("  <- RPPairing reply, %d json bytes" % length)
        try:
            parsed = json.loads(body)
        except ValueError:
            print("  raw: %r" % body[:400])
            return True
        text = json.dumps(parsed, indent=2)
        if len(text) > 2000:
            text = text[:2000] + "\n  ... (truncated)"
        print("  " + text.replace("\n", "\n  "))
        return True
    finally:
        sock.close()


def control(host, port):
    """The same 11 bytes with the wrong magic. Should reset -- that is the point."""
    print("[control ] %s:%d -- 11 bytes of zeros, wrong magic" % (host, port))
    try:
        sock = socket.create_connection((host, port), TIMEOUT)
    except OSError as exc:
        print("  connect failed: %s" % exc)
        return
    sock.settimeout(TIMEOUT)
    try:
        sock.sendall(b"\x00" * 11)
        try:
            data = sock.recv(64)
        except OSError as exc:
            print("  reset, as expected: %s" % exc)
            return
        if not data:
            print("  closed, as expected (the 11-byte cutoff)")
        else:
            print("  unexpected reply: %r" % data[:64])
    finally:
        sock.close()


def main(argv):
    host = argv[1] if len(argv) > 1 else DEFAULT_HOST
    port = int(argv[2]) if len(argv) > 2 else DEFAULT_PORT
    ok = handshake(host, port)
    print("")
    control(host, port)
    print("")
    if ok:
        print("ANSWERED. Port %d speaks RPPairing, and the protocol -- not the" % port)
        print("app, the sandbox, or Local Network permission -- was the blocker.")
    else:
        print("No RPPairing reply. Check LocalDevVPN is connected and that %s" % host)
        print("is its peer address; then try 127.0.0.1 and this iPhone's Wi-Fi address.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
