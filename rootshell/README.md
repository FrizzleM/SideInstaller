# siboot-pair for rootshell

siboot's pairing step as a WASM program for
[rootshell](https://apps.apple.com/app/rootshell-local-terminal-ssh/id6755794662)
("rootshell - Local Terminal & SSH", free, App Store). It pairs the iPhone with
itself from an App Store app, which Open Minis's App Store build can't do yet.
[`../minis`](../minis) then takes the pairing file for the other six steps, so
SideInstaller installs with two App Store apps and no TestFlight build.

**Status (2026-11-10): worked end to end on an iPhone** — paired in
rootshell, then Minis's App Store build installed SideInstaller with the file.
That run took the address as an argument and moved the file over the LAN; the
`ifconfig` pipe and the hand-off to Minis below came after it and have only
run off the iPhone. See [What's been tested](#whats-been-tested).

## Why rootshell

iOS 27 lists a host in Settings › Privacy & Security › Developer Mode ›
"Pair with …" when it advertises `_remotepairing-pairable-host._tcp`
([`../minis/README.md`](../minis/README.md), "Why Minis"). An app may only
advertise the Bonjour types its Info.plist declares, **unless it has Apple's
multicast entitlement**, which lets it send mDNS itself. Of the App Store apps
that run user code, rootshell is the one that has it
(`com.apple.developer.networking.multicast`, for its croc LAN discovery); it
declares only `_ssh._tcp` and `_rfb._tcp`. It runs WASI Preview 1 programs
dropped into its folder, and lends them sockets (`rootshell_socket_*`): TCP
listen/accept through `NWListener`, and UDP `sendto` through an
`NWConnection` per destination.

On 2026-11-10 a probe in rootshell on an iPhone (iOS 27) sent an mDNS
announcement for a test type through that `sendto` to 224.0.0.251:5353, and a
Mac on the same Wi-Fi saw it. A Mac's own mDNSResponder also takes such an
announcement from another process on the same machine (from port 5353 or any
other), so the iPhone's should cache its own app's announcement for Settings.

## What it does

1. Builds the pairable host's records: PTR, SRV (port), TXT (the seven keys
   idevice's `PairableHostInfo` gives) and an A record for this iPhone's Wi-Fi
   address. The program can't find that out itself (rootshell's `getsockname`
   always says 0.0.0.0), so it reads `ifconfig en0` piped into it
   (rootshell has `ifconfig`), or takes it as an argument.
2. Listens on a random port and sends the announcement three times, each on a
   fresh UDP socket, with a 75-minute TTL. It can't answer queries — the ABI
   has no poll and the program then blocks in `accept` — so Settings is
   answered from mDNSResponder's cache.
3. Pairs with idevice's `PairableHost`, the responder SideInstaller uses,
   over the accepted connection. The code is printed and posted as a
   notification (OSC 777, which Ghostty, rootshell's terminal, turns into one
   also in the background). A stray connection or a mistyped code leaves the
   entry up for another tap, three connections in all.
4. Writes `rp_pairing_file.plist` (idevice's format, the same as `siboot
   pair`) and `host_alt_irk` into rootshell's folder, and sends a goodbye.
5. Offers the file to siboot in Minis on the iPhone's own loopback, port
   61207, and shows a 6-digit transfer code. siboot, finding no way to pair in
   Minis's App Store build and no file, asks for the code and takes the file.
   The code keeps other apps on the iPhone from taking it: five wrong ones end
   the offer. The file stays in Files › rootshell either way, for Files ›
   Minis › shared.

iOS suspends a background app within seconds, and pairing happens in
Settings. rootshell's **Settings › Location Diary Mode › Session Only** keeps
it running in the background until turned off, through background location
updates: an App Store feature of rootshell's own.

## Running it

Needs: iOS 27 or later, Wi-Fi, Developer Mode on, rootshell with Local
Network access, and Location Diary on as above.

In rootshell's local shell:

```sh
curl -fsSLO https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/rootshell/bin/siboot-pair.wasm && ifconfig en0 | ./siboot-pair.wasm
```

(or `./siboot-pair.wasm 192.168.1.20`, with the address in Settings › Wi-Fi ›
ⓘ). Then Settings › Privacy & Security › Developer Mode, scroll down, **Pair
with siboot**, passcode, code. Leave rootshell running, and in Minis's
terminal run siboot ([`../minis`](../minis)):

```sh
wget -qO- https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/minis/install.sh | sh
```

It asks for the transfer code rootshell shows.

## Building

```sh
rustup target add wasm32-wasip1
cargo build --release --target wasm32-wasip1
cp target/wasm32-wasip1/release/siboot-pair.wasm bin/
```

idevice's `wasm` feature is meant for browsers, but on WASI its randomness
shims fall back to WASI's `random_get` and none of its JS shims are linked:
the module imports only `wasi_snapshot_preview1` and `rootshell_socket`.
`cargo test` runs the host-side tests.

## What's been tested

- **On an iPhone (2026-11-10):** siboot-pair 0.1.0 in rootshell, run with the
  address as an argument and Location Diary on: "Pair with siboot" showed in
  Settings, pairing finished, and siboot 0.12.0 in Minis's App Store build
  installed SideInstaller with the file (moved over the LAN for that run).
- The real `.wasm` under wasmtime, with rootshell's eight socket calls stood
  in for by real sockets: it announced, accepted, and paired with siboot's fake
  iPhone (`../minis/src/fake_iphone.rs`, which reads the port and the OSC 777
  code as a person would), wrote the pairing file and sent the goodbye.
- Its announcement, sent for real with a test service type: a Mac's
  `dns-sd` browsed the instance, resolved host, port and all seven TXT keys,
  and the A record, all from cache while the program sat in `accept`.
- siboot 0.12.0 in Minis's emulator with no `minis-bonjour`: it took the
  file from `/home` (Minis › shared) and skipped pairing.
- The hand-off: the `.wasm` under wasmtime, given `ifconfig en0` output on
  stdin, paired with the fake iPhone, then gave the file to siboot (on the
  Mac, and inside Minis's emulator) for the transfer code it printed; a wrong
  code got another try. The file arrived byte for byte, mode 600.

Not tested on the iPhone: the `ifconfig` pipe, the hand-off over the
iPhone's loopback (two apps, rather than two processes on a Mac), and the
OSC 777 notification.
