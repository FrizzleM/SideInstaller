# siboot for Open Minis

A PC-free, certificate-free bootstrap for SideInstaller that runs on the iPhone
it installs to, from the Linux shell of
[Open Minis](https://apps.apple.com/app/id6759188481) (free, App Store).

It continues the siboot line of [`../ashell`](../ashell) (a-Shell, Python, 0.10.0)
and [`../ish-bootstrap`](../ish-bootstrap) (iSH, Rust, 0.1.0). Both stopped at
step 2 of 7 for the same reason, which Minis is the first host to get past.

**Status (2026-11-10): worked end to end on an iPhone 16 on iOS 27** — paired
with itself in Settings, signed in, installed SideInstaller and handed it the
pairing, all from Minis. One device, one run so far; the rest is under
[What's been tested](#whats-been-tested).

## Install

In Open Minis's terminal (Minis › Settings › Terminal):

```sh
wget -qO- https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/minis/install.sh | sh
```

[`install.sh`](install.sh) downloads [`bin/siboot-aarch64`](bin) from this
repository, checks it against the SHA-256 the script carries, keeps it at
`~/.siboot/bin/siboot` (and `/usr/local/bin/siboot`), and runs it. After that,
`siboot` on its own runs it again. Arguments go after `sh -s --`, e.g.
`… | sh -s -- check`.

## Why Minis

From iOS 27 an iPhone can pair *with itself*, but only one way round: a host
advertises `_remotepairing-pairable-host._tcp` over Bonjour, Settings ›
Privacy & Security › Developer Mode lists it as "Pair with …", and the iPhone
dials in. Dialling the iPhone instead, which both earlier siboots did, only
pair-*verifies*: the device answers `allowsPairSetup: false` and hangs up on a
pair-setup request ([`../ashell/README.md`](../ashell/README.md), "The direction
was the blocker all along").

Advertising needs the app to declare that service type in its Info.plist
(`NSBonjourServices`); a script can't add it, and a shell's own multicast is
refused (`EHOSTUNREACH`, no multicast entitlement). a-Shell, a-Shell mini, iSH,
Carnets, Code App and Blink declare no Bonjour types, and Pyto only its own.
Open Minis declares this one (with `_remotepairing._tcp` and `_remoted._tcp`)
and lets its shell use it through the `minis-bonjour` command, which advertises
from the app and forwards connections to a port inside the shell.

Minis also runs real Linux binaries: Alpine aarch64 on an ARM64 fork of iSH
([OpenMinis/ish-arm64](https://github.com/OpenMinis/ish-arm64)). So unlike the
a-Shell build, which had to be stdlib-only Python, this is Rust on the same
vendored idevice and isideload SideInstaller ships, and every step after pairing
is code SideInstaller already runs.

## The steps

| # | Step | How |
|---|---|---|
| 1 | Check | `minis-bonjour types` declares the type; notifications allowed; the iPhone answers RPPairing on `10.7.0.1:49152` through LocalDevVPN |
| 2 | Pair | idevice's `PairableHost` on a loopback port, advertised with `minis-bonjour advertise`; silent audio through `apple-player` keeps Minis running while you're in Settings; the code arrives as an `apple-notification` |
| 3 | Connect | pair-verify → `createListener` → TLS-PSK → CDTunnel → software TCP → RSD, as `tunnel_create_rppairing_multihost` does; lockdownd gives the UDID |
| 4 | Apple ID | rust-core's `apple_session.rs`, compiled unchanged: saved token first, then GrandSlam + 2FA, Mac-ADI anisette servers in SideInstaller's Auto order |
| 5 | Sign | the latest `SideInstaller.ipa` release, signed with isideload's `sign_app` (device registered, app group, no Increased Memory Limit), as Side by Side does |
| 6 | Install | AFC upload to `/PublicStaging`, every file checked, `installation_proxy` with `PackageType: Developer` |
| 7 | Hand over | house_arrest writes the pairing file to `Library/Application Support/rp_pairing_file.plist` and marks it imported (`importedPairingFileName`), as Side by Side hands one to SideInstaller |

### Keeping Minis awake

The pairing happens in Settings, with Minis in the background, and iOS suspends
a background app within seconds. `minis-bonjour` withdraws its advertisements
while Minis is suspended, so the "Pair with …" entry vanishes before it can be
tapped. That is the likeliest reason Minis's own `pair_via_bonjour.py`
(OpenMinis/MinisSkills, `ios-dev`) never got the entry to show, though the
advertisement was visible from a Mac. SideInstaller and StikPair both play
silent audio through pairing for the same reason.

Minis has background audio, and `apple-player play` plays a file with the
playback session category, so siboot writes 16 minutes of silence (8 kHz, 8-bit
WAV, 7.7 MB) to `~/.siboot` and plays it until pairing ends and you're back in
Minis: the code is typed in Settings, so pairing ends with Minis behind it, and
the rest of the run needs Minis awake (and its terminal), so siboot posts a
"go back to Minis" notification and waits for `minis-bonjour list` to report
Minis in front before closing the player. Minis's own
Settings › Background › Enhanced Background does something similar, but only
while an agent task runs, not for a command typed into its terminal.

## Running it

Needs: iOS 27 or later, Wi-Fi, Developer Mode on, LocalDevVPN (App Store)
connected, and Open Minis with `minis-bonjour` (its TestFlight build from late
October 2026 on; App Store 1.15, of 2026-10-11, predates it).

Run the [install command](#install), or `siboot` once it's installed. When it
says so, open Settings › Privacy & Security › Developer Mode, scroll down, tap
**Pair with siboot**, enter the passcode, then the 6-digit code from the Minis
notification. Leave the player Minis opens over the terminal alone: it keeps
Minis running while you're in Settings.

`siboot check` only checks, `siboot pair` stops after pairing, and
`siboot connect` only proves the tunnel. `SIBOOT_APPLE_ID` and `SIBOOT_PASSWORD` skip the prompts, for an agent
run. Everything is kept in `~/.siboot`: the pairing file (mode 600), the host's
altIRK, isideload's store (signing key, anisette identity, saved token) and the
download. The password is never written anywhere.

## Building

Any aarch64 Linux with a musl toolchain builds it; on a Mac, a Lima Alpine VM
does (`limactl create --name=siboot template:alpine`, then
`apk add build-base cmake perl clang linux-headers rustup`):

```sh
RUSTFLAGS="-C target-feature=+crt-static -C relocation-model=static" \
  cargo build --release --locked --target aarch64-unknown-linux-musl
```

A static non-PIE executable, like the `pair_host` Minis's own packages ship.
`--target` must be explicit, or the static flags reach the proc macros too.

To publish a new build, copy it to `bin/siboot-aarch64` and put its
`sha256sum` in `install.sh`'s `SHA256`, in the same commit: the script refuses a
binary that doesn't match.

`cargo test` runs on any host (macOS included).

## What's been tested

- **On an iPhone (2026-11-10).** An iPhone 16 on iOS 27, Open Minis's TestFlight
  build with `minis-bonjour`, LocalDevVPN: `siboot check` passed, then `siboot`
  ran all seven steps. "Pair with siboot" showed in Settings with the silence
  playing, the code came as a notification, and SideInstaller was signed with a
  free Apple Account, installed, and handed the pairing (0.11.0). On some runs
  the terminal stopped updating right after "paired with …": pairing ends with
  Minis still behind Settings, and 0.11.0 stopped the silence there, closing the
  player while Minis was in the background and letting iOS suspend it. 0.11.1
  keeps the silence playing, asks you back with a notification, and closes the
  player only once Minis is in front again (`minis-bonjour list`); not yet run
  on the iPhone.
- **Pairing, end to end, in tests.** `src/fake_iphone.rs` plays the iPhone's
  side of device-initiated pair-setup (handshake, SRP M1–M6 with the PIN, its
  identity in M5) against idevice's real `PairableHost`, and checks the host's
  M6 signature. Tests pair through it directly and through stand-ins for Minis's
  commands (`minis_stub`), and check the advertisement's name and TXT records,
  that it's withdrawn, that a mistyped code gets another try (and three end the
  run), that a connection dropping before the code doesn't end the wait, that
  nobody tapping times out, and that pairing again keeps the host identity.
  Plus argument parsing, the bridge's JSON envelope, the silent WAV, the bundle
  walk, 2FA answers, server order, the sign-in errors that stop it, and
  rust-core's own `apple_session.rs` and `error_text.rs` tests: 40 in all, on
  macOS and on Alpine aarch64.
- **Under Minis's own emulator.** [OpenMinis/ish-arm64](https://github.com/OpenMinis/ish-arm64)
  (c5c264d) builds as a command-line `ish` on an Apple Silicon Mac
  (`meson setup build -Dguest_arch=arm64 --buildtype=release`; its gadgets use
  Mach-O assembly, so not on Linux). Running Alpine 3.21.10 aarch64, as Minis
  does, from a plain folder (`ish -r`):
  - the static release binary runs, and all 40 tests pass inside it (2.5 s);
  - `siboot check` with stand-in Minis commands reads them, and reaches GitHub and
    `gsa.apple.com` over TLS (aws-lc, Apple Root CA for Apple's server);
  - `siboot pair`, the real binary, advertises through the stand-in, plays the
    silence, posts the code, and pairs with the fake iPhone dialling in from the
    Mac (`SIBOOT_FAKE_LOG=… cargo test dial_a_running_siboot -- --ignored`), which
    reads the code from the notification; the advertisement and the player are
    stopped after, and the pairing file is written with mode 600.

  iSH refuses `TCP_USER_TIMEOUT`, which hyper-util warns about on every
  connection; harmless, so that warning only shows with `--verbose`.

Not tested yet: other iPhones and iOS versions, an Apple Account at its
certificate or App ID limit (siboot then asks which certificate to revoke), a
second run after the 7-day profile expires, and Minis with notifications off.

### What the player does to the screen

`apple-player play` presents Minis's audio player as a sheet over the terminal,
and dismissing that sheet stops the audio. siboot says so before it starts
playing, and stops the player itself when pairing ends, which closes the sheet.
With Minis's notifications off, the code is printed only in the terminal, under
the sheet, so `siboot check` warns about that case.
