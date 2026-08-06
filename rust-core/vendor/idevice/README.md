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

**One file: `src/remote_pairing/opack.rs` — OPACK back-reference decoding.**

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

## Re-vendoring

Upstream had not fixed this as of `master` @ `7fe8adb` (2026-08). Re-copying the
crate from a newer revision drops the patch unless upstream has landed an
equivalent — check `src/remote_pairing/opack.rs` for `0xA0` handling first, and
keep the tests either way.
