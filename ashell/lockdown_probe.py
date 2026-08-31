#!/usr/bin/env python3
"""lockdown_probe.py -- does this iPhone's lockdownd talk to a client that speaks?

The a-Shell port map recorded 62078 as "hangs up unasked". That probe connected
and read without sending anything, and lockdownd never speaks first: it waits for
a request. This one sends real ones.

The question it settles is worth an order of magnitude of work. Installing an app
needs AFC + installation_proxy, and those are *classic* lockdown services, not
developer services -- they are reached with `StartService` over a plain socket,
which is how SideStore installs apps over its own loopback VPN. Only the developer
services (debugserver, dvt) moved behind RemoteServiceDiscovery and its tunnel.

So if lockdownd answers here, the Python bootstrap needs the lockdown protocol
(length-prefixed plists) and nothing else: no RPPairing, no TLS-PSK, no CDTunnel,
no software TCP stack, no RemoteXPC. If it does not, the tunnel route is the only
one left and the work is several thousand lines larger.

Nothing here pairs, and nothing is written. `QueryType` needs no pair record;
`GetValue` without a session returns what the device gives out unauthenticated,
and its *error* is as informative as its success -- `InvalidHostID` means the
protocol is live and only a pair record is missing, which is the good outcome.

Usage (a-Shell, or iSH with `apk add python3`):

    python3 lockdown_probe.py                # 10.7.0.1 (LocalDevVPN peer)
    python3 lockdown_probe.py 127.0.0.1      # control
    python3 lockdown_probe.py 192.168.1.42   # this iPhone's Wi-Fi address
"""

import plistlib
import socket
import struct
import sys

DEFAULT_HOST = "10.7.0.1"
PORT = 62078
LABEL = "siboot"
TIMEOUT = 10.0


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise EOFError("peer closed after %d of %d bytes" % (len(buf), n))
        buf += chunk
    return buf


def send_request(sock, request):
    body = plistlib.dumps(request)
    sock.sendall(struct.pack(">I", len(body)) + body)


def read_reply(sock):
    length = struct.unpack(">I", recv_exact(sock, 4))[0]
    if length > 1 << 22:
        raise ValueError("implausible reply length %d" % length)
    return plistlib.loads(recv_exact(sock, length))


def request(sock, payload, what):
    payload = dict(payload)
    payload.setdefault("Label", LABEL)
    payload.setdefault("ProtocolVersion", "2")
    print("  -> %s" % what)
    send_request(sock, payload)
    try:
        reply = read_reply(sock)
    except (EOFError, OSError, ValueError) as exc:
        print("     no reply: %s" % exc)
        return None
    for key in ("Type", "Value", "Error", "Result"):
        if key in reply:
            print("     %s: %r" % (key, reply[key]))
    if not any(k in reply for k in ("Type", "Value", "Error", "Result")):
        print("     %r" % reply)
    return reply


def main(argv):
    host = argv[1] if len(argv) > 1 else DEFAULT_HOST
    print("[lockdown] %s:%d" % (host, PORT))
    try:
        sock = socket.create_connection((host, PORT), TIMEOUT)
    except OSError as exc:
        print("  connect failed: %s" % exc)
        return 1
    sock.settimeout(TIMEOUT)
    answered = False
    try:
        reply = request(sock, {"Request": "QueryType"}, "QueryType")
        answered = bool(reply and reply.get("Type"))
        if answered:
            for key in ("ProductVersion", "ProductType", "UniqueDeviceID", "DeviceName"):
                request(sock, {"Request": "GetValue", "Key": key}, "GetValue %s" % key)
    finally:
        sock.close()

    print("")
    if answered:
        print("lockdownd ANSWERED. The classic route is live: pair here, then")
        print("StartService for AFC and installation_proxy over plain sockets.")
        print("The tunnel, TLS-PSK and a software TCP stack are all unnecessary.")
    else:
        print("No lockdown reply. Check LocalDevVPN is connected and that %s is" % host)
        print("its peer address, then try this iPhone's own Wi-Fi address. If the")
        print("socket closes on a well-formed request, the tunnel route is the only one.")
    return 0 if answered else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
