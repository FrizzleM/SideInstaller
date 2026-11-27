# idevice (vendored)

Copy of the `idevice/` crate from
[jkcoxson/idevice](https://github.com/jkcoxson/idevice) @
`7bd551c16c6dd2e058740d85a2d9399a51a776e9` — the same revision the git
dependency in `rust-core/Cargo.toml` pins, so nothing about the
StikPair/StikDebug parity described there changes.

It is vendored so `[patch."https://github.com/jkcoxson/idevice.git"]` can
redirect both our direct dependency *and* `idevice-ffi`'s to this copy, which
keeps cargo unifying a single `idevice` instance.

## Local changes

Changes 1–5 are this repo's own. Changes 6–11 are upstream fixes from after
the pinned revision, taken from `master` @ `c8fff6d` (2026-11-22) because
StikDebug ships them: they're in the idevice its 2026-11 builds link. To list
the files again, diff against cargo's checkout of the pinned revision:
`diff -rq ~/.cargo/git/checkouts/idevice-*/7bd551c/idevice rust-core/vendor/idevice`.

**1. `src/remote_pairing/opack.rs` — OPACK back-reference decoding.**

OPACK deduplicates: when a value repeats, the encoder emits a one-byte pointer
(`0xA0`–`0xC0`, or `0xC1`–`0xC4` with an out-of-line index) at the position of
the repeat instead of the literal, where the index counts scalars in the order
they first appeared. The decoder here never implemented that range, so any pair
record containing a repeat died with `unsupported OPACK tag: 0x??`.

Real devices do send them. An iPad 16,3 reports its `name` as a pointer back to
its `model`, which failed pairing immediately after the PIN was accepted:

```
RPPairing: FAILED — pairing failed: unexpected response from device: failed to
parse OPACK info payload from pair record response: unsupported OPACK tag: 0xab
```

The decoder now threads a back-reference table through the parse and resolves
those tags. Matching the encoder means interning only scalars (strings, data,
sized integers, floats — never collections, booleans, or the single-byte small
integers), and interning a repeated value only once, since a spurious entry
shifts every later index and silently yields wrong values rather than an error.
Cross-checked against pyatv's `pyatv/support/opack.py` and its pointer test
vectors, which are reproduced in this file's tests.

The tag ladder for `0xC1`–`0xC4` is 1/2/4/8 index bytes, matching the encoder
and OPACK's other size classes. (pyatv's *decoder* reads 1/2/3/4 there, which
disagrees with its own encoder; only `0xC1` is reachable below 256 objects, so
the discrepancy has never mattered in practice.)

Two adjacent fixes in the same match, both the identical "valid tag the decoder
never learned" failure:

- `0x31` (16-bit integer) was missing from the integer ladder, between the
  handled `0x30` and `0x32`.
- Encoding remains untouched. Emitting pointers is optional, and this host never
  re-serializes a device-supplied payload.

Still unimplemented, as upstream: `0x04` (null), `0x05` (UUID), `0x06`. None has
been observed in a pair record.

**2. `src/services/afc/packet.rs` — an AFC packet prints its lengths, not its
bytes.**

`AfcPacket::read` logs every packet it receives at DEBUG (`Recv afc: {res:?}`),
and the derived `Debug` printed `header_payload` and `payload` as lists of
decimal bytes. `DeviceConnection.writeVerified` reads back each file it writes,
so the pairing file, SideStore's `Account.sideconf` (a .p12 with its private key
and password, and the anisette `adi.pb`) and Madeira's sign-in hand-off all went
into the activity log, and from there into problem reports. `AfcPacket` now has
a hand-written `Debug` that prints the header and both lengths; a test checks
that no byte list gets through.

**3. `src/remote_pairing/mod.rs` — log the device's `attemptPairVerify` reply.**

Upstream logs only that the reply arrived. The reply carries the device's wire
protocol version and, under `deviceOptions`, what it says it will and won't do,
which is the first thing to look at when a device later accepts a tunnel
connection and then closes it without a reason. One `debug!` line, so it only
shows with Verbose logging on.

**4. `src/remote_pairing/tls_psk.rs` — name the TLS alert a device sends.**

- A shared `describe_alert` turns an alert body into words
  (`fatal handshake_failure (level=2 desc=40)`), covering every TLS 1.2 alert
  code instead of the eight the handshake error named before.
- The handshake loop uses it, and compares against a `CT_ALERT` constant rather
  than a bare `21`.
- `read_app_data` used to report an alert after the handshake as
  `Expected application data, got ct=21`. That alert is encrypted, so it is now
  decrypted (advancing the read sequence number) and named, which is what tells
  "the device hung up" (`close_notify`) apart from "the device rejected us". If
  it can't be decrypted, the error says so.

**5. `Cargo.toml` — no `tun-rs` dev-dependency.**

Only upstream's `tests/` and `examples/` use it, and neither is vendored, but
cargo still builds every dev-dependency for `cargo test`. Resolved fresh by
`scripts/test-rust.sh`, its newest release didn't compile against the tokio
rust-core locks (2026-11-09: `AsyncFd::register` not found), which failed the
pull-request checks for no change of ours. The app never builds dev-dependencies,
so nothing else is affected.

**6. `src/xpc/mod.rs`, `src/services/rsd.rs` — one RSD handshake UUID per
host (upstream `df53825`, `e564574`, 2026-11-16).**

Every RSD handshake sent a new random `UUID`. Since iOS 27.2 the device
remembers the UUID of the last RSD peer on a tunnel, even after it
disconnects, and when a later connection presents a different one it
re-attaches the peer and closes every service listener it advertised, to the
newcomer and to the connections before it. SideInstaller opens several
(the JIT session's own tunnel, a reconnect before each install), and siboot
opens one to check the iPhone and another to install. Now every handshake
presents `default_handshake_uuid()`: `uuid3(NAMESPACE_DNS, hostname)`, as
pymobiledevice3's host id is made, so apps on the same iPhone built on this
idevice (StikDebug's builds are) present the same one and don't close each
other's services. `RsdHandshake::new_with_uuid` and
`send_device_handshake_with_uuid` take another.

**7. `Cargo.toml` — jktcp 0.1.8 (upstream `63a341d`, `9c1ad29`).**

The software TCP stack every tunnel byte goes through. 0.1.7 stops waking every
open tunnel each millisecond (it polls its retransmission timer only while a
segment is unacknowledged); 0.1.8 queues IP packet writes so a write cancelled
in a `select!` can no longer leave half a packet on the tunnel and desync it,
answers an out-of-order segment with a duplicate ACK (fast retransmit) instead
of dropping it silently, takes overlapping segments, honours a FIN only in
order, and tells every reader when its connection closes. No API change.

**8. `src/services/core_device_proxy.rs` — segments capped at 8192 bytes
(upstream `edf2587`).**

The adapter's MSS was the tunnel's MTU less 60, however large the MTU the
device reported. It's now `min(mtu, 8192) - 60`, as upstream sets it.
`vendor/idevice-ffi`'s RPPairing tunnel and siboot's take the same cap.

**9. `src/services/cryptexd.rs`, `src/services/cryptexd/`, `src/darwin_errno.rs`,
`src/tss.rs`, `src/xpc/` — the DeveloperDiskImage as a cryptex (upstream
`7305894`, with `ded303b`'s fix).**

The `cryptexd` service over RemoteXPC, and `install_ddi`/`installed_ddi`, which
personalize and install the DeveloperDiskImage as a Cryptex1 and report it.
Each personalized-image build identity names a chip and board, so that image
only mounts on the devices Xcode knew when it was built (27.1's stops at
iPhone18,5); the Cryptex1 identity names none. StikDebug installs it this way
from iOS 26.4 on, and so does SideInstaller (`DeveloperDiskImage` in
`LocationView.swift`). Copied from upstream, except:

- `tss.rs` keeps the vendored reqwest client (upstream since hand-rolls its
  HTTP) and gains only `add_cryptex1_tags`, `cryptex1_udid`,
  `select_cryptex_build_identity`, and upstream's error that says what Apple
  answered when it refuses.
- `xpc/mod.rs` and `xpc/http2/` gain only what cryptexd's install needs: the
  outbound file transfer (`send_file_transfer`), DATA frames that can carry
  END_STREAM, and RST_STREAM as a frame, taken as completion on a finished
  transfer's stream and as the error it always was on any other.
- `lib.rs` numbers `IdeviceError::Cryptexd` 110, as upstream does.

Behind the new `cryptexd` feature (`xpc`, `rsd`, `tss`), which `full` includes.

**10. `src/services/afc/inner_file.rs` — reading a file to its end (upstream
`df4cf18`).**

`read` asked for a whole transfer however little was left, subtracted what came
back from what was left, and looped until that hit zero: a file that shrank
since its size was read looped for ever on empty reads, and one that grew
underflowed the count. It now asks for what's left and stops at an empty read,
as does `read_n`. SideInstaller reads back every file it writes into another
app's container with it.

**11. `src/services/house_arrest.rs` — a refused vend is an error (upstream
`0940073`).**

house_arrest answers a `VendContainer`/`VendDocuments` it won't do (no such
app, or a container it doesn't vend) with an `Error` key, which was read and
dropped, so the caller got an AFC client on a connection with nothing behind
it and a confusing failure on its first request. It's now
`UnexpectedResponse("house_arrest VendContainer failed: …")`.

## Re-vendoring

Upstream merged change 1 as `6fb49ae` (2026-09-12, "fix(rppairing): decode
OPACK back-references"), copied from this file, so a re-vendor from a revision
at or after it can take upstream's `opack.rs` — diff it against this one and
keep the tests. Changes 2–4 are not upstream as of `master` @ `8970209`
(2026-10-27) and have to be carried over, as does change 5 while upstream's
`tun-rs` requirement lets cargo pick a release that doesn't build. Changes 6–11
come with any revision at or after `c8fff6d` (2026-11-22); there, `tss.rs`
can be taken whole. Change 2 matters most:
`rust-core/src/logging.rs` holds idevice's DEBUG output back unless Verbose
logging is on, but the switch exists for exactly the runs where it is.

A re-vendor moves the pin in `rust-core/Cargo.toml` and `vendor/idevice-ffi` to
the same revision.
