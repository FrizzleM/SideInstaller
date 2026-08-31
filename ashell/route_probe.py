#!/usr/bin/env python3
"""route_probe.py -- one command, the whole route matrix.

Supersedes running `lockdown_probe.py` and `rppairing_probe.py` by hand against
one address at a time. That way lost the single most important measurement to
typeahead, guessed at a Wi-Fi address, and never tried the address the user
actually has (`10.7.0.0`).

It answers, per address, the question the earlier probes could not:

    Does it reset *before* we write, or *because of* what we wrote?

Everything before this conflated the two. `classify_port` in siboot.py read with
nothing sent; `probe()` in ish-bootstrap's selftest.rs did a bare connect and
dropped the socket, never reading and never writing at all. A reset provoked by
our payload and a reset that arrived on accept both printed the same, and that
ambiguity is why 62078 was written off unasked.

The discriminator that settles port 49152 is the *header split*. RPPairing's
header is `b"RPPairing"` + u16be(len) = 11 bytes
(rust-core/vendor/idevice/src/remote_pairing/socket.rs:69), and `recv_plain`
reads exactly those 11 before it looks at anything. So:

    correct magic, header only, no body   -> a real RPPairing peer WAITS
    wrong magic, same 11 bytes            -> a real RPPairing peer RESETS

If those two differ, the magic is being read and 49152 is the RPPairing
listener. If they are identical, it is not, and the 11-byte cutoff means
something else entirely.

Nothing here pairs, nothing is written to disk, no Apple account is touched.
`QueryType` needs no pair record, and `attemptPairVerify` without one gets a
refusal -- a refusal that arrives *in framing* is the whole point.

Usage (a-Shell):

    python3 route_probe.py                  # auto: VPN peer, ifconfig, loopback
    python3 route_probe.py 10.7.0.1 10.7.0.0    # only these
"""

import json
import os
import plistlib
import re
import socket
import struct
import sys
import time

RPPAIRING_PORT = 49152
LOCKDOWN_PORT = 62078
MAGIC = b"RPPairing"
WIRE_PROTOCOL_VERSION = 19          # remote_pairing/mod.rs:43
LABEL = "siboot"

CONNECT_TIMEOUT = 3.0
READ_TIMEOUT = 3.0

# Verified against remote_pairing/mod.rs:310 (attempt_pair_verify) wrapped in
# socket.rs:85 (send_plain). `connect()` sends exactly this first, at seq 0.
HELLO = {
    "message": {"plain": {"_0": {"request": {"_0": {"handshake": {"_0": {
        "hostOptions": {"attemptPairVerify": True},
        "wireProtocolVersion": WIRE_PROTOCOL_VERSION,
    }}}}}}},
    "originatedBy": "host",
    "sequenceNumber": 0,
}


def _c(code, text):
    return "\033[%sm%s\033[0m" % (code, text) if sys.stdout.isatty() else text


def errno_name(exc):
    import errno as E
    n = getattr(exc, "errno", None)
    return "%s (errno %s)" % (E.errorcode.get(n, type(exc).__name__), n) if n else str(exc)


# --------------------------------------------------------------------------
# Addresses
# --------------------------------------------------------------------------

def _shell(cmd):
    """a-Shell runs commands in-process; os.system + a file is what works
    there (siboot.py:470 settled this). Returns "" if nothing came back."""
    out = ".route-probe-out"
    try:
        os.system("%s > %s 2>&1" % (cmd, out))
        with open(out, "r", errors="replace") as fh:
            text = fh.read()
    except Exception:                               # noqa: BLE001
        return ""
    finally:
        try:
            os.remove(out)
        except OSError:
            pass
    return text


def local_address():
    """No shell needed: a connected UDP socket picks the route without sending."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.7.0.1", 9))
        addr = s.getsockname()[0]
        s.close()
        return addr
    except OSError:
        return None


def addresses():
    """The VPN peer, the user's stated device IP, every ifconfig address, loopback."""
    found, seen = [], set()

    def add(a, why):
        if a and a not in seen:
            seen.add(a)
            found.append((a, why))

    add("10.7.0.1", "LocalDevVPN tunnel address")
    add("10.7.0.0", "LocalDevVPN device address")
    add(local_address(), "this process's own route to the peer")
    for a in re.findall(r"inet (\d+\.\d+\.\d+\.\d+)", _shell("ifconfig")):
        add(a, "ifconfig")
    add("127.0.0.1", "loopback (control)")
    return found


# --------------------------------------------------------------------------
# One connection, one experiment
# --------------------------------------------------------------------------

def frame_len_lockdown(buf):
    """Total bytes of a lockdown frame: u32be length + body."""
    return 4 + struct.unpack(">I", buf[:4])[0] if len(buf) >= 4 else None


def frame_len_rppairing(buf):
    """Total bytes of an RPPairing frame: 9 magic + u16be length + body."""
    return 11 + struct.unpack(">H", buf[9:11])[0] if len(buf) >= 11 else None


def attempt(host, port, payload, read_timeout=READ_TIMEOUT, want=4096, frame_len=None):
    """-> (verdict, detail, data). Verdicts: refused, held, closed, reset, data.

    `payload` of b"" means send nothing and read -- which is how you find out
    whether the reset was ever about us.

    `frame_len` reads the *whole* reply rather than one bufferful. Without it a
    single recv() capped the read, and lockdownd's QueryType answer is a ~300
    byte XML plist -- so a device that answered would have been reported as
    unparseable. Found by the mock, not by the phone.
    """
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(CONNECT_TIMEOUT)
    t0 = time.monotonic()
    try:
        s.connect((host, port))
    except socket.timeout:
        s.close()
        return "refused", "no answer in %.0fs" % CONNECT_TIMEOUT, b""
    except OSError as e:
        s.close()
        return "refused", errno_name(e), b""
    data = b""
    try:
        s.settimeout(read_timeout)
        if payload:
            s.sendall(payload)
        deadline = time.monotonic() + read_timeout
        while True:
            chunk = s.recv(want)
            if not chunk:
                break
            data += chunk
            if frame_len is None:
                break
            need = frame_len(data)
            if need is not None and len(data) >= need:
                break
            left = deadline - time.monotonic()
            if left <= 0:
                break
            s.settimeout(left)
    except socket.timeout:
        if not data:
            return "held", "open and silent for %.0fs" % read_timeout, b""
    except OSError as e:
        if not data:
            return "reset", "%s after %.0f ms" % (errno_name(e), (time.monotonic() - t0) * 1000), b""
    finally:
        s.close()
    if not data:
        return "closed", "clean close after %.0f ms" % ((time.monotonic() - t0) * 1000), b""
    return "data", "%d bytes" % len(data), data


def threshold(host, port, hi=64):
    """Binary-search the payload length that kills it. None = tolerates `hi`."""
    if attempt(host, port, b"\x00" * hi, read_timeout=1.0)[0] == "held":
        return None
    lo = 0
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if attempt(host, port, b"\x00" * mid, read_timeout=1.0)[0] == "held":
            lo = mid
        else:
            hi = mid
    return hi


# --------------------------------------------------------------------------
# Port 49152 -- RPPairing
# --------------------------------------------------------------------------

def rppairing_frame(obj):
    body = json.dumps(obj, separators=(",", ":")).encode()
    return MAGIC + struct.pack(">H", len(body)) + body


def probe_rppairing(host):
    port = RPPAIRING_PORT
    print(_c("1", "  %s:%d  RPPairing" % (host, port)))
    out = {}

    v, d, _ = attempt(host, port, b"")
    out["silent"] = v
    print("    sent nothing         %-7s %s" % (_c("1;33", v), d))
    if v == "refused":
        return out
    if v == "reset":
        print("    " + _c("1;31", "resets before we write -- it is refusing this peer,"))
        print("    " + _c("1;31", "and no protocol we could speak would change that."))
        return out

    # The discriminator. Same length, same shape, only the magic differs.
    body = json.dumps(HELLO, separators=(",", ":")).encode()
    head_ok = MAGIC + struct.pack(">H", len(body))
    head_no = b"\x00" * 11
    v_ok, d_ok, _ = attempt(host, port, head_ok, read_timeout=2.0)
    v_no, d_no, _ = attempt(host, port, head_no, read_timeout=2.0)
    out["header_correct_magic"] = v_ok
    out["header_wrong_magic"] = v_no
    print("    11B correct magic    %-7s %s" % (_c("1;32" if v_ok == "held" else "1;33", v_ok), d_ok))
    print("    11B wrong magic      %-7s %s" % (_c("1;33", v_no), d_no))

    v, d, data = attempt(host, port, rppairing_frame(HELLO), read_timeout=6.0,
                         frame_len=frame_len_rppairing)
    out["hello"] = v
    print("    full attemptPairVerify %-5s %s" % (_c("1;32" if v == "data" else "1;33", v), d))
    if v == "data":
        if data[:9] == MAGIC:
            n = struct.unpack(">H", data[9:11])[0]
            print("    " + _c("1;32", "<- RPPairing framed, %d json bytes" % n))
            try:
                print("    " + json.dumps(json.loads(data[11:11 + n]), indent=2).replace("\n", "\n    ")[:1500])
            except ValueError:
                print("    raw: %r" % data[11:11 + n][:300])
            out["framed_reply"] = True
        else:
            print("    " + _c("1;33", "reply is NOT RPPairing framed: %r" % data[:32]))
            out["framed_reply"] = False
    elif v == "reset":
        t = threshold(host, port)
        out["threshold"] = t
        print("    cutoff               %s bytes" % (t if t else "none under 64"))
    return out


# --------------------------------------------------------------------------
# Port 62078 -- classic lockdown
# --------------------------------------------------------------------------

def lockdown_request(payload):
    body = plistlib.dumps(payload)
    return struct.pack(">I", len(body)) + body


def probe_lockdown(host):
    port = LOCKDOWN_PORT
    print(_c("1", "  %s:%d  lockdown" % (host, port)))
    out = {}

    v, d, _ = attempt(host, port, b"")
    out["silent"] = v
    print("    sent nothing         %-7s %s" % (_c("1;33", v), d))
    if v == "refused":
        return out
    if v == "reset":
        print("    " + _c("1;31", "resets before we write -- refusing the peer, not the request."))
        return out

    # Both forms. Some lockdownd builds are particular about the envelope, and
    # a bare QueryType is the smallest thing that can legitimately be answered.
    variants = [
        ("QueryType + Label", {"Request": "QueryType", "Label": LABEL, "ProtocolVersion": "2"}),
        ("QueryType bare", {"Request": "QueryType"}),
    ]
    for name, req in variants:
        v, d, data = attempt(host, port, lockdown_request(req), read_timeout=6.0,
                             frame_len=frame_len_lockdown)
        out[name] = v
        print("    %-20s %-7s %s" % (name, _c("1;32" if v == "data" else "1;33", v), d))
        if v == "data":
            try:
                n = struct.unpack(">I", data[:4])[0]
                reply = plistlib.loads(data[4:4 + n])
                print("    " + _c("1;32", repr(reply)))
                out["reply"] = reply
                return out
            except Exception as e:                  # noqa: BLE001
                print("    unparseable: %s -- raw %r" % (e, data[:64]))

    if out.get("QueryType + Label") == "reset":
        t = threshold(host, port)
        out["threshold"] = t
        print("    cutoff               %s bytes" % (t if t else "none under 64"))
        if t == 4:
            print("    " + _c("1;33", "4 = the u32 length prefix. It reads our framing and rejects it."))
        elif t == 11:
            print("    " + _c("1;33", "11 = RPPairing's header. This is not lockdownd."))
        elif t is None:
            print("    " + _c("1;33", "tolerates 64 zeros but rejects a well-formed request:"))
            print("    " + _c("1;33", "it read the request and refused it at the policy layer."))
    return out


# --------------------------------------------------------------------------

def main(argv):
    hosts = [(a, "given on the command line") for a in argv[1:]] or addresses()

    print(_c("1", "route_probe -- which door opens on this iPhone"))
    print("")
    results = {}
    for host, why in hosts:
        print(_c("1;36", "%s  (%s)" % (host, why)))
        results[host] = {
            "lockdown": probe_lockdown(host),
            "rppairing": probe_rppairing(host),
        }
        print("")

    # ---- verdict ----
    print(_c("1", "verdict"))
    route_a = [h for h, r in results.items() if r["lockdown"].get("reply")]
    route_b = [h for h, r in results.items() if r["rppairing"].get("framed_reply")]
    magic_read = [h for h, r in results.items()
                  if r["rppairing"].get("header_correct_magic") == "held"
                  and r["rppairing"].get("header_wrong_magic") in ("reset", "closed")]

    if route_a:
        print(_c("1;32", "  ROUTE A. lockdownd answered on: %s" % ", ".join(route_a)))
        print("  Pair here, then StartService for AFC and installation_proxy over")
        print("  plain sockets. No tunnel, no TLS-PSK, no software TCP stack.")
    elif route_b:
        print(_c("1;32", "  ROUTE B. RPPairing answered on: %s" % ", ".join(route_b)))
        print("  Pair-setup with a PIN, then TLS-PSK, CDTunnel, a TCP stack, RSD.")
    else:
        print(_c("1;31", "  NEITHER answered on any address."))
        if magic_read:
            print("  But %s reads the RPPairing magic: the correct header is" % ", ".join(magic_read))
            print("  held where the wrong one resets. So it IS the RPPairing")
            print("  listener, and the refusal is at the protocol layer, not the")
            print("  transport -- worth reporting verbatim.")
        else:
            print("  And no address distinguished a correct RPPairing header from")
            print("  a wrong one, so 49152 is not behaving as an RPPairing peer")
            print("  either. Report this output before any more code is written.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
