# siboot for a-Shell

A PC-free, certificate-free bootstrap for SideInstaller that runs on the iPhone
it installs to — using [a-Shell](https://apps.apple.com/us/app/a-shell/id1473805438)
from the App Store instead of iSH.

**a-Shell mini** works too: it has Python, curl and the same network utilities,
at 386 MB instead of 2 GB. So does Terminus (`com.a.terminal.app.ATerminal`),
which is a repackage of a-Shell and credits it in its own Settings screen.

**Status: checkpoint 1 of 5 — the runtime proof.** Only `--self-test` is
implemented. It asks for no password and touches no Apple account.

### What the first device run settled (iPhone 17,3, iOS 27.0, a-Shell, 2026-08-27)

The runtime is comfortable, and two premises did not survive.

**The runtime is fine.** Python 3.13.1 native arm64, complete stdlib, 385
commands, `os.system` reaches them. X25519 1 ms, SHA-256 2.9 GB/s, RSA-2048
keygen ~2 s, loopback TCP 2.4 GB/s. Nothing here constrains the design. No
`openssl` and no `unzip`, both as expected — `zipfile` covers one and the signer
was always going to be Python.

**Local Network permission was not the blocker.** With it granted, port 49152
behaves exactly as it did under iSH: the connection is *accepted* and then
dropped. Loopback and `::1` do the same, and neither is gated by that permission
at all. The hypothesis in `preflight.rs` — that iSH was refused for lacking the
permission — is falsified. The pivot was still worth making (a-Shell is the
better host regardless), but it did not fix what it was meant to fix.

**One address behaves differently, and it is the right one.** The second run
(v0.3, reading before writing) found that `10.7.0.1:49152` — the LocalDevVPN
peer — *holds an idle connection open and waits*, while `127.0.0.1`,
`::1` and the Wi-Fi address all close immediately. The sweep agreed: `10.7.0.1`
is the only address where 49152 stays open. So the VPN peer really is the door,
exactly as the Rust build assumed, and it is a live service expecting us to
speak first. It then resets the moment we send anything — including the bare
24-byte HTTP/2 magic, which is precisely what `Http2Client::new` writes.

That last point matters: the Rust build writes the same bytes and only ever
reads at `recv_root`, several writes later. So the Rust build was almost
certainly being reset at exactly the same instant and could not tell.

`--probe` is the follow-up. It replays the opening sequence byte-for-byte from
`rust-core/vendor/idevice` — SETTINGS `MaxConcurrentStreams=100` /
`InitialWindowSize=1048576`, `WINDOW_UPDATE 983041`, `HEADERS` on stream 1 —
alongside controls that are the actual discriminator: a single zero byte, 24
random bytes, a TLS ClientHello, a lockdown plist. If one zero byte kills the
connection, no protocol we could speak would have helped and the fault is in
the transport. If some payloads survive, the service is judging what we send
and the failures name what it wants.

**It is not judging content — it is counting bytes.** The `--probe` battery
(v0.4) sorted by payload length rather than by protocol:

| bytes | result |
|---|---|
| 0, 1, 2 | held open |
| 12 (magic, split) | reset after the first half |
| 24 (random) / 24 (correct HTTP/2 magic) | reset |
| 45, 58, 67 (idevice's real opening) | reset |
| 240 (lockdown plist) | reset |

24 random bytes, the byte-exact HTTP/2 magic, a TLS ClientHello and a lockdown
plist all die identically, while two bytes of CRLF survive. So no protocol we
could speak was ever going to help, and the working theory that this service
was rejecting our *preface* is wrong.

v0.5 pins the threshold (a length sweep, zeros against random, 1–24 bytes) and
then asks whether "length" is even the right description: the same 24 magic
bytes are dripped one at a time. If they all get through that way, the fault is
packet shape and therefore LocalDevVPN's rewriting, not the device. If it dies
at the same cumulative count, the service is counting. A threshold of exactly
**9** would be an HTTP/2 frame header, meaning the service never wanted the
preface at all — which is why v0.5 also sends bare frames with no preface,
including a **PING**, the one frame RFC 7540 obliges any peer to answer.

**The cutoff is 11 bytes, and it is not a protocol boundary.** v0.5's sweep:
10 bytes survive, 11 resets — identically for zeros and for random content —
and dripping the magic one byte at a time dies at the same cumulative count, so
it is bytes received, not packet shape. (The 9-byte "empty SETTINGS" row that
survived proves nothing: it is simply under the threshold. Reading it as HTTP/2
tolerance was the second time content was blamed for a length effect, which is
why the battery is now sorted by payload length and prints a byte column.)

No service rejects at exactly 11 bytes. That points at the path rather than the
device, and v0.6 settles it with a **control**: bind a listener here, then reach
it through `10.7.0.1` on its own port — LocalDevVPN rewrites by address, not by
port, so it travels the identical path that 49152 does. Same bytes, same server,
only the route varies. Three outcomes, each conclusive:

* our own server also loses data around 11 bytes → **LocalDevVPN is corrupting
  the stream**, the device was never the problem, and every reading taken
  through `10.7.0.1` so far describes the VPN;
* our own server receives everything → the path is sound and `remoted` really
  does this, which is far stranger and worth keeping;
* `10.7.0.1` never reaches our listener → the rewrite target is not this device,
  and whatever has been answering on 49152 is **somewhere else entirely**.

**The control came back clean, and that relocated the problem.** Our own
listener, reached through `10.7.0.1` on its own port, received every payload
intact from 1 byte to 8 KB. So LocalDevVPN carries data faithfully, its rewrite
really does target this device, and the 11-byte cutoff on 49152 is that
service's own behaviour.

**~~10 bytes is CDTunnel's header.~~ Withdrawn — off by one.** CDTunnel is
`b"CDTunnel"` + 2 = **10** (`tunnel.rs:14`), and the cutoff was **11**.

**11 bytes is RPPairing's header, and 49152 is the RPPairing listener.**
`rust-core/vendor/idevice/src/remote_pairing/socket.rs:69` frames every message
as `b"RPPairing"` (9 bytes) + a 2-byte big-endian length + JSON — a **9+2 =
11-byte header** — and `recv_plain` in that same file reads those 11 bytes
before it looks at anything. A peer that finds the wrong magic there resets at
exactly 11 bytes received, identically for zeros, random bytes, the HTTP/2
magic, a TLS ClientHello and a lockdown plist. That is the whole battery below,
explained.

`tunnel_create_rppairing_multihost`
(`rust-core/vendor/idevice-ffi/src/tunnel_provider.rs:871`) opens a plain
`TcpStream` to that address and wraps it in `RpPairingSocket::new` — "Connect
directly and use raw RPPairing protocol" — and that is the call
`DeviceConnection.connectRemotePairing` makes, at `rsdPort = 49152`. So
shipping SideInstaller speaks **RPPairing** on 49152: not RSD, not RemoteXPC,
not HTTP/2, not CDTunnel. Every probe recorded above spoke the wrong protocol
to a service that was answering correctly. Nothing about a-Shell, the sandbox,
Local Network permission or Developer Mode was ever involved.

`ashell/rppairing_probe.py` sends the real first message in the real framing,
with a wrong-magic control that reproduces the cutoff on purpose.

**The port map.** The full 65535-port map (v0.8) found four ports listening on
the device. Its *readings* stand; the conclusion drawn from them does not:

| port | behaviour |
|---|---|
| 8443 | speaks first — answers plaintext with a TLS fatal alert (`level 2, protocol_version`) |
| 49152 | holds, then resets at 11 bytes; a real listener holds the port |
| **61779** | **holds and tolerates 64 bytes — no cutoff** |
| 62078 | lockdownd; classified from a read with **nothing sent** — see below |

Two rows were misread. **49152** was the right port with the wrong protocol, not
the wrong port: it is the RPPairing listener, and 11 bytes is its header.
**62078** was never actually asked anything — `classify_port` calls `recv()`
first and sends nothing, and lockdownd never speaks first; it waits for a
request. So "hangs up unasked" describes our probe, not the service.
`ashell/lockdown_probe.py` sends real requests, and what it returns decides the
size of this project.

**v0.9 stopped probing and implemented RemoteXPC**, ported from
`rust-core/vendor/idevice/src/xpc` rather than guessed: HTTP/2 without TLS, DATA
frames per stream, an XPC wrapper (magic `0x29b00b92`, flags, u64 length, u64
message id) around an XPC object (magic `0x42133742`, version 5). The codec is
checked byte-for-byte against the Rust encoder — an empty dictionary is
`423713420500000000f000000400000000000000` — and the whole handshake round-trips
against a mock RSD.

Two bugs in that first version, both found by the run it produced:

* **A single quiet moment ended the exchange.** `_fill` returned a bool for both
  "timed out" and "peer closed", so two seconds of silence was indistinguishable
  from a hang-up. A device that simply had not spoken yet was abandoned. The
  three states are now distinct and only "closed" is terminal.
* **Discovery threw away its own evidence.** `quiet=True` suppressed the frame
  counts, so the run could report "no port completed a handshake" without saying
  whether any port had answered *anything*. It now prints what came back for
  every port and every mode, because that is the finding.

`--rsd` also tries TLS on ports that answer plaintext with a TLS alert, which is
what 8443 does.

**`gsa.apple.com` fails to verify**, while `github.com` and
`developerservices2.apple.com` pass. a-Shell's OpenSSL 1.1.1i bundle does not
carry **Apple Root CA**, which is where that chain ends. Fixed: the certificate
is embedded in `siboot.py` and pinned. Verified here that Apple Root CA *alone*
verifies `gsa.apple.com`, so the pin is sufficient. isideload vendors the same
certificate for the same reason.

## Why the host changed

**The reason recorded here was wrong, in both directions.** The Rust build in
[`../ish-bootstrap`](../ish-bootstrap) stopped because it spoke HTTP/2 to a port
that speaks RPPairing — not because iSH lacked **Local Network** permission.
iSH's own Info.plist declares `NSLocalNetworkUsageDescription`, so it was never
missing it; and granting it in a-Shell changed nothing, which the a-Shell run
recorded above and then explained away. `preflight.rs`'s hypothesis is
falsified, and so is the inference that replaced it.

a-Shell is still the better host — native arm64 Python 3.13 with a full stdlib
beats an emulated x86 Alpine — so the pivot stands on its own merits. It just
did not fix what it was chosen to fix, because there was nothing there to fix.

## What a-Shell is, and what it forces

a-Shell is a local terminal built on **ios_system**, with most commands compiled
native arm64. That single fact settles the design:

| ios_system's rule | What it costs us |
|---|---|
| Commands run **in-process**; no fork, no exec | No binary can ship here. The i686 ELF is unusable, and so is anything compiled. |
| clang targets **WebAssembly**, and WASM has "no sockets, no forks" | WASM cannot carry the networking either. |
| `pip` installs **pure-Python wheels only** | No `cryptography`, no `pycryptodome` — every primitive is written out. |
| CPython with a full stdlib, on native arm64 | Real BSD sockets, `ssl`, `hashlib`, and `plistlib` — and the device protocol is plists. |

What a-Shell gives back is a genuine toolbox: `ifconfig` names every interface
and the addresses on it, so nothing about this device's own network has to be
guessed, and `help -l` prints the entire built-in command list rather than
leaving the program to probe one name at a time. The self-test uses both.

So this is a **rewrite, not a port**: pure Python, stdlib only, no pip step. Two
things the iSH build leaned on are gone for good, and both have to be written
here —

* **`openssl`** for RSA, CSRs and PKCS#7.
* **`zsign`** for codesigning. The iSH build spent 10–40 minutes compiling it
  once; there is no compiler here at all, so the code signer becomes Python:
  Mach-O parsing, a CodeDirectory over every 4 KB page, the entitlements and
  requirements blobs, and a CMS signature.

One thing gets *cheaper*, though. iSH emulates a 32-bit x86 CPU; a-Shell's
Python is native arm64. Pure-Python curve arithmetic that would have been
painful under emulation is ordinary here — which the self-test measures rather
than assumes.

## The pipeline

Numbering is fixed now and matches the Rust build, so output means the same
thing at every checkpoint.

| # | Stage | Notes |
|---|---|---|
| 1 | Preflight — reach a device service that answers | **Rewritten.** 49152 is not RSD; it is the RPPairing listener. Which service this step targets depends on the route (below), and `lockdown_probe.py` / `rppairing_probe.py` choose it. |
| 2 | Pair — `RemotePairingClient` against `untrusted.tunnelservice` | Client role, so nothing is advertised and no Bonjour is involved. Puts a PIN on screen. |
| 3 | Tunnel — reach the services behind RSD | **The open design question.** See below. |
| 4 | Apple ID — GrandSlam SRP + anisette + the developer portal | Mostly portable from [`../ish/sideinstaller.py`](../ish/sideinstaller.py), which already does this in stdlib Python and was checked against live services. |
| 5 | Sign | Pure-Python code signer. Nothing to reuse. |
| 6 | Install — AFC + `installation_proxy` | Replaces the iSH build's `itms-services://` handoff, and with it the three untested premises that route carried. |
| 7 | Seed — `house_arrest` | Places the pairing file inside the installed container. |

### Step 3 is not settled

The Rust build never reached it, so nothing about it is decided. What is known:

* **RPPairing's `createListener` route cannot work on-device.** The device opens
  that listener on its Wi-Fi interface only, and then refuses to build a tunnel
  to itself — it completes the TLS-PSK handshake and hangs up with
  `close_notify` before reading the request. Three fresh listeners, same result.
  (`../NOTES.md`.)
* **~~lockdownd on 62078 is not a way round it.~~ Withdrawn — never tested.**
  The "~250 µs" traces to `ish-bootstrap/src/selftest.rs:231`, where `probe()`
  does a bare `TcpStream::connect_timeout` and drops the stream: it never reads
  and never writes, and the duration it reports is the connect latency of an
  **open** port. a-Shell's own reading came from a `recv()` with nothing sent.
  lockdownd waits for a request, so neither probe is evidence either way.

That leaves the in-band tunnel — the one that rides the connection to
`untrusted.tunnelservice` that pairing already opened, needing no inbound
listener and no second dial. On top of it sits a **software TCP stack**, since
the tunnel carries IPv6 packets rather than a stream. In Rust that was one
feature flag (`tunnel_tcp_stack`); here it is code to write, and it is the
largest single risk in the project.

The self-test measures loopback socket throughput for exactly this reason: every
byte of the .ipa crosses Python twice inside that stack.

## Running it

In a-Shell:

```sh
curl -O https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/ashell/siboot.py
python siboot.py --self-test
```

Wi-Fi on, and keep a-Shell in the foreground. The first run should raise the
Local Network prompt — allow it. If it was dismissed, it is at
**Settings → Privacy & Security → Local Network → a-Shell**.

Developer Mode is **not** the explanation for the accept-then-drop on 49152 —
the 11-byte header is — so it is no longer part of the instructions here.

`--scan` sweeps for other ports that accept, and reports which of them hold the
connection open rather than dropping it — a port that stays open is a lead that
49152 is not. `--scan-all` does the same across all 65535 ports.

The run writes `~/Documents/siboot-selftest.txt`, which is reachable from the
Files app under a-Shell.

## What the self-test decides

It is not a smoke test; each check exists because some later decision depends on
it.

* **Does a TCP connection reach RSD on this iPhone?** The headline, and since
  v0.3 it is three experiments rather than one. v0.2 wrote the HTTP/2 preface
  and *then* read, which cannot tell a reset that arrived on accept from one
  provoked by the write — both print as "connected, then ECONNRESET", and that
  ambiguity cost a run. It now reads first having sent nothing:

  | what happens | what it means |
  |---|---|
  | reset before we write | the service refuses this peer; nothing we send matters |
  | held open, silent | it is waiting for us, and the preface variants say what it wants |
  | data unprompted | it speaks first and we were mis-reading it |

  The two preface variants — magic alone, and magic + an empty SETTINGS frame —
  only run because a strict server may object to the magic on its own.
* **Which address answers.** Every address is read from `ifconfig`, so a
  loopback VPN's `utun` is told apart from Wi-Fi and a cellular-only device is
  visible as such rather than looking like a failure. If this iPhone's own Wi-Fi
  address works, LocalDevVPN drops out of the requirements entirely and the
  install gets simpler.
* **Is the stdlib complete**, and is `ssl` real — sign-in is HTTPS.
* **What does pure-Python crypto cost here.** X25519 is run against the RFC 7748
  vector, so it is checked for correctness as well as speed; RSA-2048 keygen is
  estimated from a Fermat round because it is the slowest thing in the design.
* **Can anything be shelled out to, and what is there.** Three mechanisms are
  tried — `os.system`, `subprocess`, `os.popen` — because it is not obvious
  which one ios_system honours, and the answer changes what the rest of the
  program may assume. Then `help -l` is asked for the real command list. Even
  if `openssl` turns out to be present, the signer is still written in Python:
  nothing can pipe a Mach-O CodeDirectory through a CLI.
* **Socket throughput**, which sets the floor on how long step 6 can take.

## Layout

```
ashell/
  siboot.py      checkpoint 1 — the self-test. Single file, stdlib only.
  README.md      this file.
```

Single file is deliberate: one `curl` and it runs, with no archive to unpack and
no directory to get wrong on a phone. It stays that way as long as it can.

## Credentials

There are none to handle before checkpoint 3, and the promise is recorded now
because it is the project's central one. When sign-in arrives it follows
`../ish/sideinstaller.py`: GrandSlam is SRP-6a, so the password becomes a PBKDF2
key and then a zero-knowledge proof — Apple never receives it and neither does
anyone else. It is never written to disk, never logged, and the anisette server
sees no account data.
