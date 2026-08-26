# siboot

A PC-free, certificate-free bootstrap for SideInstaller.

`siboot` is one static Linux binary that runs inside [iSH](https://ish.app) — an
Alpine Linux x86 emulator on the App Store — and installs SideInstaller onto the
very iPhone it is running on, using only the user's own free Apple Developer
account. No computer, and no borrowed enterprise certificate.

```sh
curl -L -o siboot https://github.com/FrizzleM/SideInstaller/releases/latest/download/siboot-i686
chmod +x siboot && ./siboot
```

It asks for an Apple ID and password, and ends with SideInstaller installed.
SideInstaller then does what it already does: SideStore, LiveContainer, pairing.

This exists because the install page's certificate pool is borrowed and
revocable — **all 29 certificates in it are revoked right now**
(`output/certificate-validity.tsv`). A build signed with the user's own free
certificate cannot be revoked out from under them. It expires after 7 days, by
which point SideInstaller can renew itself.

## Status: checkpoint 1 of 5

The pipeline is being built in stages, and **only stage 1 exists**. What ships
today is a self-test whose job is to prove the toolchain on real hardware before
any pipeline code is written against it.

| # | Stage | State |
|---|---|---|
| 1 | Toolchain: i686 codegen, ring, TLS, VPN reachability | **code complete, needs a device run** |
| 2 | Preflight — lockdown `QueryType` against `10.7.0.1:62078` | not started |
| 3 | Pair + tunnel — mint a lockdown record, open CoreDeviceProxy, read device info | not started |
| 4 | Apple ID + sign | not started |
| 5 | Install + seed the pairing record | not started |

Stage 3 is make-or-break: see the open question below.

## Why it can work at all

A sandboxed non-native process **can** reach this device's own `lockdownd` and
`RemoteServiceDiscovery`, but only through a loopback VPN's peer address.
Measured on an iPhone running iOS 26, with iSH and LocalDevVPN from the App
Store:

| target | result |
|---|---|
| `10.7.0.1:62078` (lockdownd) | **open** |
| `10.7.0.1:49152` (RSD) | **open** |
| `127.0.0.1:62078` | `EPERM` — the sandbox denies loopback to system services |
| `127.0.0.1:<random>` | `ECONNREFUSED` (control) |

That is the load-bearing discovery, and it also answers a question `NOTES.md`
had left open — *"whether lockdownd answers on 62078 from on-device, and on
which address"*. The answer is the VPN peer address, which means
`DeviceConnection.lockdownPairRecordDirect` in the iOS app should target
`10.7.0.1` before loopback, not the other way round.

Over-the-air install (`itms-services://`) is **not** the route. It was tested end
to end and works at the transport layer, but it very likely requires
distribution-type signing, which a free account cannot issue. AFC +
`installation_proxy` has no such restriction — it is how SideInstaller, AltStore
and Feather already install everything.

## What iSH imposes

Every constraint below is measured, and each one shows up somewhere in the
design:

- **No Bonjour.** No `NSNetService`, so the RPPairing host role is impossible.
  Pairing must go through lockdownd on 62078, which is why `idevice`'s
  `remote_pairing` feature is switched off here.
- **No raw sockets**, so no `ping`.
- **No `/proc/net/dev`**, so `ifconfig` and `ip addr` both fail. The local
  address comes from a connected UDP socket instead.
- **Roughly 1–2 seconds of execution per return to the foreground.** Sockets are
  held rather than refused while suspended, so a transfer stalls instead of
  failing. Every stage prints before it starts so a stall is attributable, and
  the banner tells the user to keep iSH in front.
- **Terminal paste truncates** somewhere between 1,400 and 2,048 characters,
  which is why the binary is fetched with `curl` and never pasted.
- **32-bit x86 under emulation.** Slow — assume 50–100× native for crypto.

## Building

CI does it: `.github/workflows/build-siboot.yml` cross-compiles in a
`messense/rust-musl-cross:i686-musl` container and attaches `siboot-i686` to the
release. A container rather than `cross`, because siboot depends on
`rust-core/vendor/idevice` by path — outside its own cargo workspace, and so
outside what `cross` would mount.

Locally, on a Mac, everything except the two C dependencies can be checked
without a cross toolchain:

```sh
cargo check                                    # host target: all Rust, fastest
cargo check --target i686-unknown-linux-musl   # 32-bit typecheck; stops at ring's cc
```

A full local link is possible too, using rustc's bundled musl and `rust-lld`
instead of Apple's `ld`, which cannot emit ELF:

```sh
export CARGO_TARGET_I686_UNKNOWN_LINUX_MUSL_LINKER="$(rustc --print sysroot)/lib/rustlib/$(rustc -vV | sed -n 's/host: //p')/bin/rust-lld"
export CARGO_TARGET_I686_UNKNOWN_LINUX_MUSL_RUSTFLAGS="-Clinker-flavor=ld.lld -Clink-self-contained=yes"
```

That still needs an `i686-linux-musl` C compiler for `ring` and `liblzma-sys`,
so it only completes on a machine that has one. The environment variables are
deliberately not checked in as `.cargo/config.toml`: they are wrong on the Linux
host CI builds on.

## Dependencies

Two crates carry the pipeline, and both are referenced from this repository
rather than from the network:

- **`idevice`** — `../rust-core/vendor/idevice`, referenced by path and **not
  modified**. Features are the CoreDeviceProxy pipeline only; `remote_pairing`
  is deliberately absent (see above), which also drops ed25519-dalek, srp and
  chacha20poly1305 from the binary.
- **`isideload`** — forked into `vendor/isideload`, because getting off
  `aws-lc-sys` means editing its manifest and there is no way to unset a cargo
  feature from outside. `vendor/isideload/README.md` documents every change.

The aws-lc problem and how it was solved:

| pulled aws-lc via | fix |
|---|---|
| `rcgen`'s `aws_lc_rs` feature | `default-features = false, features = ["ring", "pem"]` |
| `reqwest`'s `default` → `default-tls` → `rustls` | `default-features = false` with `rustls-no-provider` |
| `tokio-tungstenite` | nothing — it only ever asked for `rustls`, and got aws-lc by unification with reqwest |

`rustls-no-provider` leaves the `CryptoProvider` unset, so `main` installs the
ring one on its first line. Get that wrong and the failure is a **runtime panic
on the first HTTPS request**, not a build error — which is why the self-test
makes a real request.

The same fork also finishes `isideload`'s `install` feature gate, which upstream
left incomplete (four `use idevice::…` sites outside the gate). With it closed,
`install` can be switched off and the tree resolves to a single `idevice`
instead of two — `rust-core` links both 0.1.61 and 0.1.63 for this reason. A
binary downloaded over a phone connection and run under emulation cannot afford
the duplicate.

## Verified, and not

**Verified on a development machine:**

- The dependency tree resolves and compiles with no `aws-lc-rs`, no
  `aws-lc-sys`, and exactly one `idevice` (0.1.63).
- `ring` 0.17.14 ships pregenerated 32-bit x86 ELF assembly, so the build needs
  a C compiler but neither Perl nor libclang. `liblzma-sys`' bindings are
  pregenerated too.
- The self-test runs end to end on the host: staged output, the FIPS 180-4
  SHA-256 vector, a real TLS request to the GitHub API, and the loopback probes
  correctly reporting no VPN.
- A static 32-bit ELF links from a trivial crate using rustc's bundled musl.

**Not verified — needs the phone:**

- **That the binary runs under iSH at all.** Rust's i686 targets assume a
  Pentium 4 baseline (SSE2). If iSH's emulator lacks an instruction rustc or
  ring chose, the process dies with SIGILL and prints nothing. Stage 1 of the
  self-test exists to localise exactly this.
- Alpine's trust store being reachable from a static binary. Strong indirect
  evidence that it is: the install instructions start with `curl https://…`,
  which needs one.
- Signing time under emulation. The self-test reports a SHA-256 throughput
  figure as the closest available proxy.
- **That the CI workflow builds.** It has never run. The container tag, the
  toolchain refresh and the C cross-compile of `ring` are all unexercised.

## Open questions

1. **Does lockdownd accept a pair request from the device itself, and does the
   trust dialog appear?** Stage 3 either works or the whole approach needs an
   imported pairing file, which puts a computer back in the loop. `--pairing-file`
   is planned as the override for that case.
2. **How long does signing actually take?** The IPA is 7.6 MB. If it is
   unbearable, the fallbacks are signing only the main executable rather than
   every Mach-O, or a smaller bootstrap payload.
3. **Does `installation_proxy` accept a development-signed bundle from a free
   account here?** It should — this is AltStore's path — but it will be
   confirmed rather than assumed.
