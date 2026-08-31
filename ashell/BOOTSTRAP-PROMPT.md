# Claude Code prompt — take the a-Shell bootstrap to a working install

Paste everything below the line into Claude Code, run from the repo root.
Supersedes `ish-bootstrap/FIX-PROMPT.md`, which targets a host we are not using.

---

You are working in the SideInstaller repo. The host is **a-Shell** (App Store), not
iSH. The deliverable stays what `ashell/siboot.py` already is: one file, stdlib only,
no pip step — one `curl` and it runs — which installs SideInstaller onto the iPhone it
is running on, with no computer and no shared certificate.

It is currently stuck at step 1 of 7, and the recorded reason is wrong. Read this
whole prompt before touching anything.

## Two findings to verify in the sources before you build on them

**1. Port 49152 speaks raw RPPairing framing. It is not RemoteServiceDiscovery and it
does not speak RemoteXPC or HTTP/2.**

- `rust-core/vendor/idevice-ffi/src/tunnel_provider.rs:871-884` —
  `tunnel_create_rppairing_multihost` opens a plain `TcpStream` to the address it is
  given and wraps it in `RpPairingSocket::new(stream)`, under the comment "Connect
  directly and use raw RPPairing protocol". That is the call
  `ios-app/DeviceConnection.swift → connectRemotePairing` makes, so it is what
  shipping SideInstaller does on device.
- `rust-core/vendor/idevice/src/remote_pairing/socket.rs:69` — the frame is
  `b"RPPairing"` (9 bytes) + `u16be(json_len)` (2 bytes) + JSON. An 11-byte header.
- That is the whole of the mystery in `ashell/README.md`: 49152 accepts and then
  resets after exactly 11 bytes, identically for zeros, random bytes, the HTTP/2
  magic, a TLS ClientHello and a lockdown plist, because the device reads an 11-byte
  header, finds the wrong magic and resets. The README blames CDTunnel's header,
  which is 8+2 = 10 and off by one. `--probe`, `--threshold`, `--map` and `--rsd`
  were all speaking HTTP/2 to a listener that never spoke it.
- Nothing about a-Shell, the sandbox, Local Network permission or Developer Mode is
  involved. (iSH's own Info.plist declares `NSLocalNetworkUsageDescription`, so the
  premise that sent this project from iSH to a-Shell was false in both directions.)
- The RemoteXPC codec in `siboot.py` is **not** wasted work. RSD speaks RemoteXPC —
  but inside the tunnel, after pairing. It was written one layer too early.

**2. There is probably a much shorter route than the tunnel, and it decides the size
of this project.**

Installing an app needs AFC and installation_proxy. Those are *classic lockdown*
services, reached with `StartService` over a plain socket — not developer services
behind RSD. SideStore installs apps exactly that way over a loopback VPN, and
SideInstaller 0.9.0's `DeviceConnection.connectByMintingLockdownRecord` already talks
to lockdownd over a plain TCP socket to mint a classic pair record. `NOTES.md`
records 62078 as "hangs up on network clients within ~250µs", but that probe
connected and read without sending anything, and lockdownd never speaks first — it
waits for a request. So the reading is not evidence.

If lockdownd answers a speaking client, then RPPairing, TLS-PSK, CDTunnel, the
software TCP stack and RemoteXPC are all unnecessary, and this becomes about a
thousand lines of plist plumbing instead of several thousand lines of protocol.

If any of the above contradicts what you read in the sources, stop and say so.

## Step 0 — settle it on hardware before writing any code

Two probes are already in the repo. Both are stdlib-only, both are safe: nothing
pairs, nothing is written to disk, no Apple account is touched.

- `ashell/rppairing_probe.py` — sends the exact first message `RemotePairingClient`
  sends (`attemptPairVerify`, wireProtocolVersion 19) in correct framing, with a
  wrong-magic control that should reproduce the 11-byte cutoff on purpose.
- `ashell/lockdown_probe.py` — sends `QueryType` and a few `GetValue`s to 62078.

Ask the user to run both in a-Shell with LocalDevVPN connected, against `10.7.0.1`,
then `127.0.0.1`, then the iPhone's own Wi-Fi address. **Do not start implementing
until you have their output.** Then:

- `lockdown_probe.py` prints `Type: com.apple.mobile.lockdown` → **Route A**.
- It doesn't, but `rppairing_probe.py` gets an RPPairing-framed reply → **Route B**.
- Neither answers on any address → report that and stop; the premise is broken and
  guessing further code is waste.

## Route A — classic lockdown

Pipeline: pair over lockdown → `StartSession` → `StartService` per service → AFC to
upload → installation_proxy to install → house_arrest to seed the pairing file.

Everything is length-prefixed plists (`struct.pack(">I", len)` + `plistlib`), and
`plistlib` and `ssl` are both in the stdlib. Port from, in order of usefulness:

- `rust-core/vendor/idevice/src/services/lockdown.rs` — `pair()` at line 282,
  `start_session`, `start_service`.
- `rust-core/vendor/idevice/src/ca.rs` (113 lines) — the host/device certificate
  generation, itself modelled on pymobiledevice3. This is the one genuinely new
  crypto chunk: no `openssl` binary and no `cryptography` wheel in a-Shell, so the
  ASN.1/DER writer and the minimal X.509 v3 structure are yours to write. RSA keygen
  in pure Python is ~2s here, which the self-test already measured.
- `rust-core/vendor/idevice/src/pairing_file.rs` — the record format, including the
  fields SideInstaller's own pairing file carries so other apps can read it.
- `services/afc/`, `services/installation_proxy.rs`, `services/house_arrest.rs` —
  port only the opcodes the install path uses, not the whole surface.

Two things fall out for free and are worth taking: lockdown gives you the **UDID**
via `GetValue`, which retires the Profile-Service capture hack in
`ish/sideinstaller.py`; and pairing here puts a Trust prompt on screen, which is the
same interaction SideInstaller 0.9.0 already asks users for.

## Route B — RPPairing, then the tunnel

Only if A is closed. Pipeline: RPPairing pair-setup on 49152 (PIN on screen) →
TLS-PSK → CDTunnel → software TCP stack → RSD → services. Port from
`rust-core/vendor/idevice/src/remote_pairing/` (`mod.rs`, `socket.rs`, `tlv.rs`,
`peer_device.rs`, `rp_pairing_file.rs`, `tls_psk.rs` — a self-contained TLS 1.2
PSK-AES256-CBC-SHA384 implementation) and `tunnel.rs` for the CDTunnel handshake.
New primitives needed: Ed25519, ChaCha20-Poly1305, HKDF-SHA512. Before hand-rolling
TLS-PSK, check whether a-Shell's Python 3.13 exposes `ssl.SSLContext`'s PSK client
callback against its bundled OpenSSL — if it does, that whole file is unnecessary.
The software TCP stack (upstream this is the `jktcp` crate, not vendored here) is the
largest single risk in this route and every byte of the .ipa crosses it twice.
`createListener` cannot work on-device — the device refuses to tunnel to itself, see
`NOTES.md` — so use the CoreDeviceProxy variant, which needs no inbound listener.

## What to reuse rather than rewrite

- `ish/sideinstaller.py` is the entire Apple-account half in stdlib Python, already
  checked against live services: SRP-6a byte-identical to the `srp` crate, AES-GCM
  against NIST vectors, anisette v3 provisioning end to end, GrandSlam, the developer
  portal (teams, device registration, certificate, App ID, profile), the release
  lookup and .ipa inspection. Lift it, don't redo it.
- `ashell/siboot.py` already has X25519 (checked against RFC 7748), the RemoteXPC
  codec, the Apple Root CA pin that `gsa.apple.com` needs because a-Shell's OpenSSL
  bundle lacks it, `ifconfig` parsing, and the whole self-test harness.

## The signer, which is the other real problem

a-Shell runs commands in-process: no fork, no exec, so no compiled binary and no
`zsign`. Three candidates, in the order I would try them:

1. **Defer it.** For the first working install, fetch the already-signed build the
   project's own site publishes and install *that*. SideInstaller re-signs itself
   with the user's Apple ID once it is running. This takes signing off the critical
   path entirely and makes the milestone "a-Shell installed an .ipa", which is the
   whole ballgame.
2. **WebAssembly.** a-Shell runs `.wasm` (see holzschu/a-Shell-commands, a whole set
   of shell commands precompiled to WebAssembly). Signing is pure compute and file
   I/O — no sockets, which is exactly what WASI in a-Shell can do. A signer compiled
   to `wasm32-wasi` and invoked from Python would retire the largest chunk of work in
   this project. Verify argv and file access before committing to it.
3. **Pure Python.** Mach-O parsing, a CodeDirectory over every 4 KB page,
   entitlements and requirements blobs, and a CMS signature. `macholib` is pure
   Python and installable, the rest is yours.

Pick one and say why; do not start writing a pure-Python code signer because it is
the obvious continuation.

## Milestones — do not skip ahead

1. Probes run, route chosen, and `ashell/README.md`'s falsified prose corrected (the
   11-byte reading, "Why the host changed", the step table). Keep the corrections
   short; do not rewrite the document.
2. Pair with this device from this device and persist a record that survives a re-run.
3. Reach one service and read something harmless back — device info, or the app list.
4. Install an already-signed .ipa. **This is the checkpoint that matters.**
5. Sign with the user's own Apple ID, then install that.

## Constraints

- a-Shell: commands run in-process, no fork/exec, no binaries; pip installs
  pure-Python wheels only; Python 3.13 native arm64 with a full stdlib; no `openssl`
  and no `unzip` (use `zipfile`); OpenSSL 1.1.1 without Apple Root CA, already pinned
  in `siboot.py`. Keep `siboot.py` a single stdlib-only file.
- Never edit anything under `rust-core/vendor/` — vendored upstream, read-only
  reference.
- The user's Apple ID password is used and discarded: never written to disk, never
  logged, never sent anywhere but Apple, and the anisette server sees no account
  data. `ish/sideinstaller.py` documents the promise; keep it exactly.
- Dead ends, do not revive: `itms-services`/OTA installation (it requires an Ad Hoc
  or Enterprise distribution profile — free-account development profiles are refused,
  which is what the "couldn't verify integrity" test hit), Local Network permission
  theories, Developer Mode theories, and scanning for an RSD port on the network.

## Reporting

Say which route the probe output chose and quote the line that chose it; which claims
you verified in the sources and which you took from this prompt; what you implemented;
and what is unverified because it needs the phone. Where you had to guess a wire
format, say so at the call site.
