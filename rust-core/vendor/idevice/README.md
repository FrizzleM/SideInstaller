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

Four files differ from upstream: `src/remote_pairing/opack.rs`,
`src/services/afc/packet.rs`, `src/remote_pairing/mod.rs` and
`src/remote_pairing/tls_psk.rs`, plus this README. To list them again, diff
against cargo's checkout of the pinned revision:
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

## Re-vendoring

Upstream merged change 1 as `6fb49ae` (2026-09-12, "fix(rppairing): decode
OPACK back-references"), copied from this file, so a re-vendor from a revision
at or after it can take upstream's `opack.rs` — diff it against this one and
keep the tests. Changes 2–4 are not upstream as of `master` @ `8970209`
(2026-10-27) and have to be carried over. Change 2 matters most:
`rust-core/src/logging.rs` holds idevice's DEBUG output back unless Verbose
logging is on, but the switch exists for exactly the runs where it is.

A re-vendor moves the pin in `rust-core/Cargo.toml` and `vendor/idevice-ffi` to
the same revision.
