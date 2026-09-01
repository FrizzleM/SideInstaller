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

import base64
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
# --consent: one step past the handshake, to ask the device WHY
# --------------------------------------------------------------------------
#
# The handshake reply carries `deviceOptions.allowsPairSetup: false`. idevice
# never reads that flag -- `RemotePairingClient` only logs deviceOptions
# (remote_pairing/mod.rs:335) and `connect()` calls `pair()` regardless -- so
# shipping SideInstaller would walk straight into whatever refusal follows.
#
# `request_pair_consent` (mod.rs:379) is the message that finds out. Its reply
# is one of three things, and all three are worth more than a guess:
#
#   pairingRejectedWithError  -> wrappedError.userInfo.NSLocalizedDescription,
#                                the device's own words for why
#   awaitingUserConsent       -> a PIN is on screen; Route B is fully open
#   pairingData               -> the PIN came back inline (Apple TV shape)
#
# This sends exactly one message past the handshake and then stops. SRP is
# never started, so nothing pairs and no record is written either side.

# TLV8 from mod.rs:386 -- Method(0x00)=0x00, State(0x06)=0x01. Values from
# remote_pairing/tlv.rs:9-16; the serializer is type|len|data (tlv.rs:65).
CONSENT_TLV = bytes([0x00, 0x01, 0x00, 0x06, 0x01, 0x01])

# `sendingHost` is our identity to the device. The shipping app sends
# "SideInstaller" (DeviceConnection.swift:151); this deliberately does not, so
# a probe cannot disturb an existing SideInstaller pairing record.
SENDING_HOST = "siboot"


class RpConn:
    """A framed RPPairing connection. send_plain/recv_plain per socket.rs."""

    def __init__(self, host, port=RPPAIRING_PORT, timeout=15.0):
        self.sock = socket.create_connection((host, port), CONNECT_TIMEOUT)
        self.sock.settimeout(timeout)
        self.seq = 0

    def send_plain(self, value):
        """socket.rs:85 -- the plain envelope, with our sequence number."""
        env = {"message": {"plain": {"_0": value}},
               "originatedBy": "host",
               "sequenceNumber": self.seq}
        body = json.dumps(env, separators=(",", ":")).encode()
        self.sock.sendall(MAGIC + struct.pack(">H", len(body)) + body)
        self.seq += 1

    def recv_plain(self):
        head = self._exact(11)
        if head[:9] != MAGIC:
            raise ValueError("reply not RPPairing framed: %r" % head)
        return json.loads(self._exact(struct.unpack(">H", head[9:11])[0]))

    def _exact(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise EOFError("peer closed after %d of %d bytes" % (len(buf), n))
            buf += chunk
        return buf

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def _dig(obj, *keys):
    for k in keys:
        if not isinstance(obj, dict) or k not in obj:
            return None
        obj = obj[k]
    return obj


def probe_consent(host):
    print(_c("1;36", "%s:%d  pair-setup consent" % (host, RPPAIRING_PORT)))
    print("")
    try:
        conn = RpConn(host)
    except OSError as e:
        print(_c("1;31", "  connect failed: %s" % errno_name(e)))
        return 1

    try:
        # 1. handshake, exactly as before
        conn.send_plain({"request": {"_0": {"handshake": {"_0": {
            "hostOptions": {"attemptPairVerify": True},
            "wireProtocolVersion": WIRE_PROTOCOL_VERSION,
        }}}}})
        reply = conn.recv_plain()
        hs = _dig(reply, "message", "plain", "_0", "response", "_1", "handshake", "_0")
        if hs is None:
            print(_c("1;31", "  no handshake in reply: %s" % json.dumps(reply)[:400]))
            return 1
        opts = hs.get("deviceOptions", {})
        print("  handshake ok -- wireProtocolVersion %s, minimum %s"
              % (hs.get("wireProtocolVersion"), hs.get("minimumSupportedWireProtocolVersion")))
        for k in sorted(opts):
            flag = opts[k]
            print("    %-46s %s" % (k, _c("1;32" if flag else "1;33", flag)))
        print("")

        # 2. one step further: ask for pair-setup consent
        print("  -> setupManualPairing (mod.rs:397)")
        conn.send_plain({"event": {"_0": {"pairingData": {"_0": {
            "data": base64.b64encode(CONSENT_TLV).decode(),
            "kind": "setupManualPairing",
            "sendingHost": SENDING_HOST,
            "startNewSession": True,
        }}}}})
        try:
            reply = conn.recv_plain()
        except (EOFError, OSError, ValueError) as e:
            print(_c("1;31", "  no reply: %s" % e))
            print("  The device closed rather than answering. With allowsPairSetup")
            print("  false, that is a refusal without an explanation.")
            return 1

        print("")
        print(json.dumps(reply, indent=2)[:3000])
        print("")

        event = _dig(reply, "message", "plain", "_0", "event", "_0") or {}
        rejected = event.get("pairingRejectedWithError")
        if rejected is not None:
            why = _dig(rejected, "wrappedError", "userInfo", "NSLocalizedDescription")
            print(_c("1;31", "  REJECTED: %s" % (why or "no NSLocalizedDescription given")))
            print("  That is the device's own reason. Route B's pair-setup is shut")
            print("  until this is addressed -- it is not a bug in the framing.")
            return 1
        if "awaitingUserConsent" in event:
            print(_c("1;32", "  A PIN IS ON SCREEN. Route B is fully open."))
            print("  allowsPairSetup:false did not block setup. Nothing has been")
            print("  paired -- SRP was never started. Dismiss the prompt.")
            return 0
        if _dig(event, "pairingData", "_0", "data") is not None:
            print(_c("1;32", "  Pairing data returned inline. Route B is open."))
            return 0
        print(_c("1;33", "  Unrecognised reply shape -- report the JSON above verbatim."))
        return 1
    finally:
        conn.close()


# --------------------------------------------------------------------------
# --bonjour: can this process advertise a pairable host at all?
# --------------------------------------------------------------------------
#
# The device answers `allowsPairSetup: false` and closes on setupManualPairing,
# because iOS's remoted does not accept an inbound request to create a pairing.
# SideInstaller never asks it to: it goes the other way round, advertising
# `_remotepairing-pairable-host._tcp` over Bonjour
# (ios-app/PairingController.swift:217) so that Settings discovers it and the
# *device* connects in. In that role idevice advertises allowsPairSetup **true**
# (remote_pairing/responder.rs:227).
#
# So siboot needs the same role, and the open question is Bonjour. NSNetService
# is a Foundation API, but registration goes through the system mDNSResponder
# daemon -- the daemon multicasts, not us -- so it should not need
# `com.apple.developer.networking.multicast`, which is for sockets doing their
# own multicast. If ctypes can reach DNSServiceRegister, the role is available
# here.
#
# ish-bootstrap/src/pairing.rs:17 argued the opposite: that the client role
# "needs no multicast entitlement" and therefore sidesteps all of this. The
# handshake reply falsifies that. The client role pair-*verifies*; it cannot
# pair-*setup*.

BONJOUR_TYPE = "_remotepairing-pairable-host._tcp"
BONJOUR_NAME = "siboot-probe"


def probe_bonjour():
    try:
        import ctypes
    except ImportError:
        print(_c("1;31", "  no ctypes -- Bonjour is unreachable from Python here."))
        return 1
    print("  ctypes           available")

    lib = None
    for path in (None, "/usr/lib/libSystem.dylib", "/usr/lib/libsystem_dnssd.dylib"):
        try:
            cand = ctypes.CDLL(path)
            cand.DNSServiceRegister
            lib, which = cand, path or "the main image"
            break
        except (OSError, AttributeError):
            continue
    if lib is None:
        print(_c("1;31", "  DNSServiceRegister not found in any image."))
        print("  Without it there is no way to advertise a pairable host from")
        print("  Python here, and pairing needs a different host entirely.")
        return 1
    print("  DNSServiceRegister found in %s" % which)

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", 0))
    srv.listen(1)
    port = srv.getsockname()[1]
    print("  listener         bound on port %d" % port)

    # DNSServiceRegisterReply: (sdRef, flags, errorCode, name, regtype, domain, ctx)
    reply_t = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint32, ctypes.c_int32,
                               ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p,
                               ctypes.c_void_p)
    seen = {}

    def on_reply(sd, flags, err, name, regtype, domain, ctx):
        seen["err"] = err
        seen["name"] = name.decode() if name else ""
        seen["domain"] = domain.decode() if domain else ""

    cb = reply_t(on_reply)

    lib.DNSServiceRegister.restype = ctypes.c_int32
    lib.DNSServiceRegister.argtypes = [
        ctypes.POINTER(ctypes.c_void_p), ctypes.c_uint32, ctypes.c_uint32,
        ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p,
        ctypes.c_uint16, ctypes.c_uint16, ctypes.c_void_p, reply_t, ctypes.c_void_p]
    lib.DNSServiceRefSockFD.restype = ctypes.c_int
    lib.DNSServiceRefSockFD.argtypes = [ctypes.c_void_p]
    lib.DNSServiceProcessResult.restype = ctypes.c_int32
    lib.DNSServiceProcessResult.argtypes = [ctypes.c_void_p]
    lib.DNSServiceRefDeallocate.restype = None
    lib.DNSServiceRefDeallocate.argtypes = [ctypes.c_void_p]

    sd = ctypes.c_void_p()
    # port is passed in network byte order; empty TXT -- this probe only asks
    # whether registration is permitted, not whether the record is complete.
    err = lib.DNSServiceRegister(ctypes.byref(sd), 0, 0,
                                 BONJOUR_NAME.encode(), BONJOUR_TYPE.encode(),
                                 None, None, socket.htons(port), 0, None, cb, None)
    if err != 0:
        print(_c("1;31", "  DNSServiceRegister failed: error %d" % err))
        print("  -65555 is a policy refusal; -65537 an unknown/bad parameter.")
        srv.close()
        return 1
    print("  DNSServiceRegister accepted -- waiting for the daemon's callback")

    import select
    fd = lib.DNSServiceRefSockFD(sd)
    rc = 1
    try:
        ready, _, _ = select.select([fd], [], [], 8.0)
        if ready:
            lib.DNSServiceProcessResult(sd)
        if seen.get("err") == 0:
            print("")
            print(_c("1;32", "  REGISTERED as %r in %r" % (seen.get("name"), seen.get("domain"))))
            print("  Bonjour works from Python here, so the pairable-host role is")
            print("  available and pair-setup can be done the way SideInstaller")
            print("  does it. Next: port responder.rs, not the client side.")
            print("")
            print("  Check now, while this is still running:")
            print("  Settings > Privacy & Security > Developer Mode. If %r is" % BONJOUR_NAME)
            print("  listed as pairable, the whole approach is proven end to end.")
            print("")
            input("  press return when you have looked ... ")
            rc = 0
        elif "err" in seen:
            print(_c("1;31", "  the daemon refused it: error %d" % seen["err"]))
        else:
            print(_c("1;33", "  no callback in 8s -- registration neither confirmed nor refused."))
    finally:
        lib.DNSServiceRefDeallocate(sd)
        srv.close()
    return rc


# --------------------------------------------------------------------------

def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    if "--consent" in argv:
        return probe_consent(args[0] if args else "10.7.0.1")
    if "--bonjour" in argv:
        print(_c("1;36", "can this process advertise a pairable host?"))
        print("")
        return probe_bonjour()

    hosts = [(a, "given on the command line") for a in args] or addresses()

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
