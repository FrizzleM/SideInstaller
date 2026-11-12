# siboot for Open Minis

Installs SideInstaller onto the iPhone it runs on, signed with your own Apple
Account, from the Linux shell of [Open Minis](https://apps.apple.com/app/id6759188481)
(free, App Store): no computer, no certificate. The pairing comes from
siboot-pair in rootshell ([`../rootshell`](../rootshell)), which runs first.

## Running it

Needs iOS 27 or later, Developer Mode on, Wi-Fi, LocalDevVPN (App Store)
connected, and siboot-pair in rootshell paired and still running
([`../rootshell`](../rootshell#running-it)). Then, in Open Minis's terminal:

```sh
wget -qO- https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/minis/install.sh | sh
```

The first time, type the transfer code rootshell shows; after that siboot uses
the pairing file it saved and doesn't ask. Then type your Apple Account email,
password and verification code. Keep Minis open until siboot says it's done:
iOS pauses it in the background. The first time, trust your Apple Account in
Settings › General › VPN & Device Management. Free accounts' apps last 7 days;
SideInstaller can renew itself from then on.

[`install.sh`](install.sh) downloads [`bin/siboot-aarch64`](bin) from this
repository, checks it against the SHA-256 the script carries, keeps it at
`~/.siboot/bin/siboot` (and `/usr/local/bin/siboot`), and runs it. After that,
`siboot` on its own runs it again without downloading.

## The steps

| # | Step | How |
|---|---|---|
| 1 | Check | GitHub and Apple's sign-in server answer; the iPhone answers RPPairing on `10.7.0.1:49152` through LocalDevVPN |
| 2 | Pairing | the file saved in `~/.siboot` on an earlier run, while the iPhone accepts it; else the one siboot-pair offers on `127.0.0.1:61207`, for its transfer code (20 s for each answer), pair-verified with the iPhone |
| 3 | Connect | pair-verify → `createListener` → TLS-PSK → CDTunnel → software TCP → RSD, as `tunnel_create_rppairing_multihost` does; lockdownd gives the UDID |
| 4 | Apple ID | rust-core's `apple_session.rs`, compiled unchanged: saved token first, then GrandSlam + 2FA, Mac-ADI anisette servers in SideInstaller's Auto order |
| 5 | Sign | the latest `SideInstaller.ipa` release, signed with isideload's `sign_app` (device registered, app group, no Increased Memory Limit), as Side by Side does |
| 6 | Install | AFC upload to `/PublicStaging`, every file checked, `installation_proxy` with `PackageType: Developer` |
| 7 | Hand over | house_arrest writes the pairing file to `Library/Application Support/rp_pairing_file.plist` and marks it imported (`importedPairingFileName`), as Side by Side hands one to SideInstaller |

`siboot check` runs step 1 only, and `siboot connect` steps 1–3.
`siboot developer-mode` runs steps 1–3 and then asks for Developer Mode
([below](#developer-mode)).
`SIBOOT_APPLE_ID` and `SIBOOT_PASSWORD` skip the prompts. Everything is kept in
`~/.siboot`: the pairing file (mode 600), isideload's store (signing key,
anisette identity, saved token) and the download. The password is never
written anywhere.

## Developer Mode

```sh
siboot developer-mode
```

Before siboot is installed, the same is
`wget -qO- https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/minis/install.sh | sh -s developer-mode`.

It works as SideInstaller's Settings › Developer Mode does. siboot opens the
install's tunnel (steps 1–3, without the internet checks), and lockdownd says
whether Developer Mode is on (`DeveloperModeStatus` in
`com.apple.security.mac.amfi`). When it's on, nothing is sent. When it's off,
AMFI's RSD shim (`com.apple.amfi.lockdown.shim.remote`) is asked to show the
switch under Settings › Privacy & Security, where you turn it on: iOS restarts,
and once you unlock it, asks you to tap Turn On.

`siboot developer-mode --turn-on` turns it on instead, once you type `yes`: the
iPhone restarts at once, and Minis stops with it. iOS does that only while the
iPhone has no passcode. With one, it refuses, and siboot shows the switch
instead.

It needs what the install needs: a pairing the iPhone accepts, and a tunnel
that opens. So it can't bring the switch back on an iPhone that has never been
paired, since pairing happens under that same Developer Mode page. Whether
iOS 27 still answers on its pairing port with Developer Mode off hasn't been
tried.

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

## Tests

`cargo test` runs on any host (macOS included): the hand-off from rootshell
against a stand-in for siboot-pair's side (the right code, a mistyped one, three
wrong ones, something that isn't a pairing file, nothing offered), argument
parsing, `developer-mode` against stand-ins for lockdownd and AMFI (on already,
off, unreadable, a declined restart, the passcode refusal, a hang-up), the bundle walk, 2FA answers, server order, the sign-in errors that
stop it, install refusals, and rust-core's own `apple_session.rs` and
`error_text.rs` tests. A test also stands in for a rootshell that iOS has
paused: the connection goes through and nothing answers. siboot-pair's own
tests, with a fake iPhone, are in
[`../rootshell`](../rootshell#tests).

## What's been tested

- **On an iPhone (iOS 27, November 2026):** this route end to end. siboot
  0.12.0 in Open Minis's App Store build took the pairing from siboot-pair 0.1.0
  in rootshell and installed SideInstaller.
- **0.13.0** is 0.12.0 without what that route doesn't use: pairing inside
  Minis (through `minis-bonjour`, which only Minis's TestFlight builds have),
  its silent-audio keep-alive and notifications, and the Files › Minis › shared
  import. Steps 3–7 are unchanged. Tested on macOS and Alpine aarch64 (29 tests;
  `install.sh` installed it, skipped a current copy and refused a tampered one).
  On the iPhone it got stuck with rootshell offering: it took rootshell's offer
  before the saved file, and rootshell showed no request.
- **0.13.1** goes back to 0.12.0's order, the saved file first, and stops
  waiting for rootshell's answer after 20 s. Tested the same way; not yet run on
  an iPhone. The hand-off itself (two apps on one iPhone's loopback) hasn't
  completed on an iPhone yet: the runs that worked there used a file moved over
  the LAN or saved by an earlier run.
- **0.14.0** adds `siboot developer-mode`; the install is unchanged. Tested on
  macOS and Alpine aarch64 (39 tests, the new ones against stand-ins for
  lockdownd and AMFI; `install.sh | sh -s developer-mode` ran it). Not run on
  an iPhone yet. SideInstaller's own helper, which sends the same requests, has
  only read the status and shown the switch on an iPhone where Developer Mode
  was already on.

Not tested yet: other iPhones and iOS versions, an Apple Account at its
certificate or App ID limit (siboot then asks which certificate to revoke), and
a second run after the 7-day profile expires.
