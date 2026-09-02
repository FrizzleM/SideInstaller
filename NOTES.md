# SideInstaller — build notes

Raw, full-featured on-device sideloader. Combines StikPair's RPPairing, a
LocalDevVPN-loopback lockdown connection, and SideStore's install/refresh model
into one app. The UI is a deliberately raw test harness (buttons + log console);
everything below the UI is the real pipeline.

## How to build

```sh
./build-rust.sh        # cross-compiles rust-core -> SideInstallerFFI.xcframework
xcodegen generate      # regenerates SideInstaller.xcodeproj from project.yml
# then open SideInstaller.xcodeproj, or:
xcodebuild build -project SideInstaller.xcodeproj -scheme SideInstaller \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

Toolchain used here: Xcode 27.0 beta (iOS 27.0 SDK), Rust 1.96 with targets
`aarch64-apple-ios` + `aarch64-apple-ios-sim`, xcodegen.

## Pins

| dependency | pin | features |
|---|---|---|
| idevice (jkcoxson) | rev `7bd551c16c6dd2e058740d85a2d9399a51a776e9` | `remote_pairing tunnel_tcp_stack rsd tcp xpc core_device_proxy installation_proxy installcoordination_proxy afc house_arrest misagent heartbeat mobile_image_mounter pair usbmuxd aws-lc` |
| idevice-ffi (vendored) | same rev, `vendor/idevice-ffi` | `full aws-lc` |
| isideload (nab138) | git `main` | `install fs-storage` (no keyring) |

The idevice rev matches StikPair's (RPPairing host) and StikDebug's
(`tunnel_create_rppairing` loopback connection), so both replicated mechanisms
track known-good implementations.

### Architecture decision: reuse idevice's own FFI for connection/install

Rather than re-implement idevice's threading-sensitive RSD tunnel + service
clients by hand (untestable here, high risk), `rust-core` depends on **both**:

- `idevice` (library) — for our forked RPPairing host (`pairing.rs`) and the
  logging spine.
- `idevice-ffi` (the crate StikDebug ships) — for the proven C-FFI
  (`tunnel_create_rppairing`, `installation_proxy_*`, `afc_*`, `lockdownd_*`,
  `rsd_*`, `rp_pairing_file_*`). `extern crate idevice_ffi as _;` re-exports its
  `#[no_mangle]` symbols into our single staticlib; cargo unifies the one
  `idevice` instance (no duplicate symbols — verified with `nm`).

idevice-ffi is **vendored** under `rust-core/vendor/idevice-ffi` with exactly
one change — `crate-type = ["rlib"]` (upstream is `staticlib+cdylib+rlib`;
rustc emits all in one pass and the standalone **cdylib** link fails on the iOS
*device* target). Swift gets both headers via the module map and calls idevice's
FFI directly from `DeviceConnection.swift`, exactly as StikDebug does.

The generated `idevice.h` (8948 lines, cbindgen, plist.h appended) is copied to
`rust-core/include/idevice.h`.

## Environment limits (important, honest)

The four make-or-break **runtime** steps cannot be tested in this build
environment — they need a physical iOS 17.4+ device with Developer Mode, the
LocalDevVPN app, and a real Apple ID. A simulator has none of that. So:

- Steps that are **device-independent** (FFI/log spine, IPA download, project
  build) are verified here.
- Steps that are **device-dependent** (RPPairing PIN, loopback connect,
  install, Apple ID sign-in) are written as real code but **unverified** until
  run on hardware. No fake success is stubbed anywhere.

## Progress (gate-by-gate)

### Step 1 — scaffold + logging spine ✅ (runtime-verified in simulator)

- `rust-core/` C-FFI crate: `si_log_init` installs a global `tracing`
  subscriber whose writer forwards every formatted line to a Swift callback;
  `si_ping` exercises `tracing::info!`.
- `build-rust.sh` + `project.yml` mirror StikPair; produce
  `SideInstallerFFI.xcframework` (ios-arm64 + ios-arm64-simulator).
- `ios-app/`: `Engine` (all logic, singleton so the C log callback can target
  it), raw `ContentView` (inputs / per-stage buttons / scrollable monospaced
  log console with Copy + Clear), `SideInstallerApp`.
- **Gate result:** built for the simulator and launched; the console shows Rust
  tracing output live, e.g.
  `[rust]  INFO sideinstaller_ffi: si_ping: Rust core alive (idevice @7bd551c linked)`.
  Transport/pairing-record types: N/A at this step.

### Step 2 — pairing + connection — code complete; device steps unverified

**Pairing (RPPairing host, make-or-break #1).** `pairing.rs` ports StikPair's
`run_host` (FFI `si_pairing_run_host`); `PairingController.swift` requests Local
Network, keeps the app alive with silent audio (works iOS 17.4+, vs StikPair's
iOS-26 `BGContinuedProcessingTask`), advertises over Bonjour via `NetService`,
runs the host off-thread, surfaces the PIN, and writes the pairing file to
`Application Support/rp_pairing_file.plist`. Reports every step into the log
console.

**Re-read against StikPair 1.1.0 (2026-08-24).** `pairing.rs` is still a faithful
port — same bind, same `RpPairingSocket::new_device`, same TXT records from
`PairableHostInfo::mdns_txt_records`, same callback shape — plus the milestone
logging and the zero-byte guard, which StikPair doesn't have. **StikPair has no
tunnel code at all**: it pairs, writes the file, and stops, so it has nothing to
say about the `createListener` failure below. Two other differences are
deliberate and stay as they are: silent audio instead of
`BGContinuedProcessingTask` (iOS 17.4+ vs 26+), and no Apple TV path, which needs
`RemotePairingClient` as a *client* and is out of scope here.

One real defect came out of the comparison, and it was in both apps. StikPair's
own comment — *"A production app should persist both the pairing file and
`host_info.alt_irk` so already-paired devices keep working"* — describes what
neither did:

- `PairableHostInfo::generate` mints a **random `alt_irk` every run**, and the
  `authTag` in the Bonjour TXT record is derived from it
  (`compute_auth_tag(alt_irk, identifier)`). A device that has paired before can
  therefore never recognise this host.
- `RpPairingFile::generate` mints a **fresh Ed25519 key pair every run**. The
  identifier doesn't move (it's `Uuid::new_v3(NAMESPACE_DNS, name)` — which is
  why `d8442cca-…` is constant in every log), but the keys do. That costs
  SideInstaller much more than it costs StikPair, because SideInstaller *writes
  its pairing file into other apps*: every re-pair silently invalidated the copy
  already placed in SideStore, Feather and StikDebug, while the file on disk
  still looked fine.

Both are now carried across pairings. `si_pairing_run_host` takes the
`host_alt_irk_hex` a previous run returned (`PairingController` keeps it in
`UserDefaults` under `rpPairingHostAltIRK`; it was already being returned and
thrown away, exactly as in StikPair), and `run()` loads the existing
`rp_pairing_file.plist` and reuses its key pair instead of generating one,
falling back to generation when there isn't a usable file. Safe because
`pair_setup` only ever *reads* `e_private_key`/`e_public_key`/`identifier` — to
sign M6 — and the one field it writes is `pairing_file.alt_irk`, the **device's**
IRK (responder.rs:402), which is cleared before a re-pair so a different iPhone
can't inherit the last one's. Re-presenting a stable key across a pair-setup is
what a real Mac does; the device replaces its record for the identifier and every
previously placed file keeps working.

`si_pairing_run_host` gained a parameter, so `rust-core/include/sideinstaller.h`
had to be hand-edited alongside it — there is no cbindgen for that header.

**LocalDevVPN's actual shape** (read from its source, `TunnelProv/PacketTunnelProvider.swift`).
`NEIPv4Settings(addresses: [ifaceIP])` puts the tunnel's own end on the `utun`, with
`includedRoutes` = the peer's route only and `excludedRoutes = [.default()]`. We connect
to the peer, which is on no interface — the provider swaps source and destination on every
packet it reads, so anything sent to the peer comes back to the tunnel's own address.

**Its 2026-08 rewrite changed the address model, and broke our tunnel detection.** Before
it, `TunnelDeviceIP` = **10.7.0.0** with a separate user-editable subnet mask (/24) and
`TunnelFakeIP` = **10.7.0.1**. After it, the mask field is gone — addresses are CIDR now,
validated by a new `TunnelProv/CIDRValidator.swift` — and the defaults are
`TunnelIfaceIP` = **10.7.1.1/32**, `TunnelPeerIP` = **10.7.0.1/32**. The keys were renamed
with no migration, so upgrading users silently land on those defaults. Two things follow:

- A **/32 on the `utun` can never contain the peer**, so "is `deviceIP` inside a tunnel
  interface's subnet" — which is all `NetworkStatus` used to ask — reads a perfectly
  healthy point-to-point tunnel as "no tunnel". This is not a LocalDevVPN bug; a /32
  interface plus a host route is the correct shape for a P2P tunnel. `NetworkStatus`
  therefore asks the **routing table** first (`tunnelCarriesRoute`, a UDP `connect` that
  sends nothing and only resolves a source address), and keeps the subnet test as a
  fallback so wider tunnels still answer. The user workaround going round the community —
  setting the tunnel IP to `10.7.0.2/30` so its mask reaches the peer — only widens the
  mask far enough to satisfy the old test, and is unnecessary once the route test lands.
- LocalDevVPN now **prints its addresses with the prefix attached** (`10.7.0.1/32`), so a
  Device IP copied out of it arrives here as a CIDR string. `Engine.deviceHost` strips the
  suffix. Untreated, that string failed `ipv4Value`, fell through to the broad
  tunnel-name check — which iOS's own always-up `utun` satisfies — and reported a tunnel
  that wasn't there, before failing much later in `inet_pton`.

Two further consequences of the shape itself:

- The tunnel routes nothing off-device, so it needs **no Wi-Fi**. Only pairing does
  (Bonjour on the local network). `Engine.needsFreshPairing` is what gates the Wi-Fi
  requirement now.
- Its config sets `isOnDemandEnabled = true` with `NEEvaluateConnectionRule(matchDomains:
  [tunnelIfaceIP, tunnelPeerIP])`, and never disables it. Those are **DNS domain** matches and
  we connect by raw IP, so they can never fire for our traffic — iOS is left free to tear
  the tunnel down whenever it likes. That is the mechanism behind the 0.6.5 "adapter
  closed (NetworkUnreachable)" failures. **Never trust `DeviceConnection.isConnected` to
  mean the tunnel is alive** — it only says our handles are non-null. Re-establish before
  any device work; a pair-verify is cheap and needs no PIN.

Since 0.7.0 the pairing file and isideload's `FsStorage` root both live in
Application Support rather than Documents — `UIFileSharingEnabled` exposes the
whole of Documents in Files (so an IPA can be dropped in), and that's no place
for a pairing record or a signing certificate. `PrivateStore` in
`SideStoreDownloader.swift` owns both paths and migrates 0.6.x's copies across
on first use, falling back to the Documents location if the move can't complete.

**Connection (loopback lockdown, make-or-break #2).** `DeviceConnection.swift`
drives idevice's FFI on the StikDebug recipe:
`rp_pairing_file_read` → `tunnel_create_rppairing(deviceIP:49152, pairing)` →
`(AdapterHandle, RsdHandshakeHandle)`; device info via
`lockdownd_connect_rsd` + `lockdownd_get_value(nil)` → plist
(ProductVersion/ProductType/UDID/…); apps via `installation_proxy_connect_rsd`
+ `installation_proxy_get_apps`. Default device IP `10.7.0.1` (LocalDevVPN
default), configurable in the UI.

**Transport used:** RPPairing pair-verify over the LocalDevVPN Wi-Fi loopback →
TLS-PSK tunnel → in-process software TCP stack (`tunnel_tcp_stack`) → RSD
handshake → services over RSD. Pairing-record type for **our own connection**:
**RPPairing** (`rp_pairing_file.plist`), not a classic lockdown record. The file
handed to *other* apps carries both records — see the format section under
step 4.

**Verified here (simulator):** project builds for device + sim; app launches;
network scan works; the idevice FFI is callable and errors surface raw —
a connect attempt with no pairing file returned
`idevice FFI error code=1 sub=0: NotFound` and was handled gracefully (no crash).

**NOT verifiable here (needs a physical iOS 17.4+ device + LocalDevVPN):** the
actual RPPairing PIN approval, the loopback tunnel, real device info, and the
app list. These are real code, unverified until run on hardware.

#### Connect transport — `Socket(ENOENT)` was NOT usbmuxd

On-device `Connect` failed instantly with
`Socket(Os { code: 2, NotFound, "No such file or directory" })`. ENOENT on a
socket op *looks* like a usbmuxd Unix-socket attempt — but there is **no
usbmuxd anywhere** in the connect path (`grep` confirms; the transport is
`tunnel_create_rppairing`, pure TCP). The real cause, from idevice's own
source: `IdeviceError::Socket(#[from] io::Error)` maps **every** `io::Error` to
the `Socket` variant, and `RpPairingFile::read_from_file` is just
`tokio::fs::read(path)`. So the ENOENT is `rp_pairing_file_read` failing because
`rp_pairing_file.plist` **didn't exist** — pairing never completed.

Fixes applied (connect path + pairing gate only):
- `Connect` now refuses to run unless the pairing file exists and is non-empty,
  with a clear message — never calls into idevice with a missing file.
- The RPPairing step logs explicit milestones (device connected on advertised
  port → PIN issued → handshake complete → **pairing file path + byte size**),
  and fails loudly if the written file is zero bytes.
- **Proven TCP, not usbmuxd:** with a valid pairing file, connecting to a dead
  `127.0.0.1:49152` returns `InternalError("connect: Connection refused (os
  error 61)")` — ECONNREFUSED, a real TCP error, **never ENOENT**. (Verified in
  the simulator via a temporary helper, since removed.)

#### Tunnel dial — the candidate sweep is breadth-first, and why

`createListener` returns the port the device opened and **no host**, so
`finish_tunnel` (`tunnel_provider.rs`) guesses: the RSD peer address first, then
`127.0.0.1`, then the local interface addresses the Swift side passes in.

On a 2026-08-24 nightly log the three guesses behaved as three different
failures at once — `10.7.0.1` (the LocalDevVPN fake IP) black-holed the SYN,
`127.0.0.1` refused it, and the device's own Wi-Fi address `192.168.31.125`
accepted it, completed the TLS-PSK handshake (`Server Finished verified!`) and
then answered the CDTunnel request with a TLS alert. So the listener really is
bound to the local-network interface only, and the session key really is the
right one — the connection just arrived too late. The sweep used to be
**depth-first**: each candidate got its whole retry window before the next was
looked at, which spent **10.2s** — two black-holed SYNs waited out, then a
refusal re-tried six times at 700ms apart — before dialling the one address that
answers. Both runs in that log took the same 10.2s and failed the same way.

The sweep is now **breadth-first**: one attempt at every candidate, then round
again, up to `DIAL_MAX_ROUNDS` within the same 18s `DIAL_BUDGET`. Every
candidate is a local address, so `DIAL_ATTEMPT_TIMEOUT` dropped from 3s to
800ms — it is not a latency allowance, only a cap so a black-holed SYN can't
stall the candidates behind it. Same log, same candidates: the live listener is
now reached ~0.85s after `createListener` instead of 10.2s, and a listener that
genuinely isn't accepting yet still gets its six attempts.

Two smaller changes fall out of the same log:

- **A rejected handshake re-dials the same host immediately.** That connection
  burns the listener, so a replacement has to be requested either way; the
  replacement is at its youngest right now, so the sweep steps back onto the
  same candidate instead of advancing. Bounded by `DIAL_MAX_HANDSHAKES` (3).
- **`CACHED_TUNNEL_HOST` records a host that merely *accepted*,** not only one
  that completed a tunnel. It was written on full success only, so the second
  run in that log re-walked all three dead guesses in the same order. The cache
  decides ordering alone, so a weaker signal is the right thing to store.

None of that made the tunnel come up, and the next log said why. `read_app_data`
now decrypts the alert body and names it (`describe_alert`, from 36fc210 — which
**had never been built**: `build-rust.sh` last ran 2026-08-19, so every Rust
change from 36fc210 onwards was missing from the shipped `.a` while the Swift
half of that commit shipped. **Check `strings
SideInstallerFFI.xcframework/ios-arm64/libsideinstaller_ffi.a` against the source
before reading any FFI log as evidence.**) The alert is
`warning close_notify` — an *orderly* shutdown, not a rejection.

#### The RPPairing `createListener` route cannot work on-device

With the sweep fixed, the live listener is dialled 13ms after `createListener`
and still gets `close_notify`, three times in a row on three fresh listeners.
That kills the expiry reading and leaves a much simpler one. Put the three
candidates' behaviour together:

| candidate | tunnel port | what it means |
|---|---|---|
| `127.0.0.1` | refused (RST) | the listener is **not** bound to `0.0.0.0` |
| `10.7.0.1` (LocalDevVPN) | no answer, no RST | not on the VPN's address either |
| `192.168.31.125` (en0) | accepts, TLS-PSK completes | bound to the **local network interface** |

So `createListener` opens the tunnel listener on the Wi-Fi interface alone —
which is coherent, since the same response carries a Bonjour `serviceName`. Two
consequences, and they close the route off:

1. Over the loopback VPN the tunnel port is **unreachable by construction**. The
   VPN can forward the fixed RSD port all it likes; the tunnel port is a fresh
   ephemeral one the listener never binds on that interface.
2. Over en0 it is reachable, but the peer is this iPhone's own address — the
   device is being asked to build a tunnel to itself. It completes the TLS
   handshake (the PSK is genuinely right: `Server Finished verified!` compares
   real `verify_data`) and then hangs up cleanly, before it has even read the
   `clientHandshakeRequest` — the `close_notify` arrives in the same millisecond
   as the write.

Nothing the client sends changes that, which is why re-pairing, retrying, fresh
listeners and candidate ordering all failed identically. The whole point of the
loopback VPN is to present a peer address that is *not* the device's own; the
en0 fallback quietly threw that away and only looked like progress.

#### The way through: mint the classic record, take CoreDeviceProxy

CoreDeviceProxy needs no inbound listener at all — it rides the lockdown
connection that already works (see [Two tunnel routes](#step-2--pairing--connection--code-complete-device-steps-unverified)).
`DeviceConnection.connect` already prefers it whenever the pairing file carries a
classic lockdown record. On-device pairing produces only the RPPairing half, so
that route was never offered, and `lockdownPairRecord` — which mints the classic
half — runs *inside* the RSD tunnel, so it could never break the deadlock.

`DeviceConnection.pairOverLockdown` breaks it: `idevice_new_tcp_socket` →
`lockdownd_new` → `lockdownd_pair` against **lockdownd's own port (62078)**, no
tunnel, no provider, no pre-existing pair record. All three symbols were already
exported. `connect` falls back to it when every route the pairing file supports
is spent, stores the record (minting is interactive and spends a device pairing
slot), and retries CoreDeviceProxy with it.

**The open question is whether lockdownd answers on 62078 from on-device**, and
on which address — `enableWirelessLockdown`'s own comment says lockdownd answers
over USB only until `EnableWifiDebugging` is set, and setting it needs a session,
which needs a record. That is why `lockdownPairRecordDirect` takes a *list* of
hosts and tries the VPN peer and plain loopback in turn, logging each. If neither
answers, the record can't be minted on-device at all and an imported pairing file
stays the only way through for this iPhone.


### Step 3 — Apple ID + signing — code complete; device/account steps unverified

`account.rs` wraps isideload behind three FFI calls:
- `si_apple_signin` — `AppleAccount::builder().anisette_provider(RemoteV3…)
  .login(password, 2fa_cb)` → `DeveloperSession::from_account` →
  `SideloaderBuilder` (team `First`, `FsStorage`, machine name) → opaque
  `SignSession`. 2FA is bridged to a Swift prompt via a blocking semaphore
  callback (`SITwoFactorCb`).
- `si_sign_ipa(session, ipa, udid, device_name, …)` — first calls
  `DeveloperSession::ensure_device_registered(team, name, udid)` so the team has
  the connected device, then `Sideloader::sign_app(ipa, None, false)` → signed
  `.app` bundle path. sign_app internally registers the App ID + provisioning
  profile and retrieves/creates the dev certificate, then signs with
  `apple-codesign`. **Device registration is mandatory here:** we use the
  sign-only path (not isideload's `install_app`, which is the only place
  isideload registers the device), so without this step a fresh/free team has no
  devices and the profile download fails with developer error **8220** ("Your
  team has no devices …"). The UDID comes from the lockdown handshake, captured
  by Swift during Connect and passed down; a registration failure is prefixed
  `device registration failed for UDID <udid>:` so Swift can surface the UDID.
- `si_account_config(session, …)` — builds the `Account.sideconf` payload
  SideStore imports at launch: Apple ID, the signing certificate as a PKCS#12
  encrypted with its machine id (the convention AltStore-family apps expect),
  and the anisette identity. Swift writes it into SideStore's Documents in the
  same step as the pairing file (step 8), and SideStore's
  `LaunchViewController.detectAndImportAccountFile` adopts it and deletes it.

  **Why:** SideStore only signs with a certificate it holds the private key for.
  Ours never leaves this app, so its first sign-in revokes ours, mints its own,
  and shows "Resign SideStore". Nothing else fixes that. In particular isideload
  *already* injects `ALTCertificate.p12` + `ALTCertificateID` into the bundle
  (`application.rs::apply_special_app_behavior`) — recent SideStore reads
  neither for itself, so that path is inert here. `Account.sideconf` is the one
  hand-off it still honours automatically.

  Two **vendored additions** back this: `CertificateIdentity::retrieve_existing`
  (isideload's `retrieve` mints a certificate when it finds no match, which on a
  free account means revoking the one in use — reading the identity must never
  be able to do that, so this returns `None` instead), and `pub mod state` in
  `anisette::remote_v3`, so the stored `AnisetteState` can be read back.
  `anisetteIdentifier`/`anisetteAdiBlob` are base64 of `keychain_identifier` and
  `adi_pb` — exactly the encoding both sides already send the anisette server.
  The Apple ID password is omitted: it isn't needed to keep the certificate, and
  the file is plaintext JSON until SideStore consumes it.

  **Only builds that import it silently get the file.** SideStore's
  `ImportAccountAlertController` (2026-08-10) changed `detectAndImportAccountFile`:
  it now puts up an *Import Account* alert asking for a **file password**, accepts
  only the AES-GCM format `ImportExport.exportAccount` writes, never deletes the
  file, and records its checksum only once a decryption succeeds. Handing plaintext
  JSON to such a build means that alert on **every** launch, forever — it can never
  decrypt, so the checksum is never stored. iLoader shows no alert for the simple
  reason that it never writes the file (`install_sidestore_operation` places only
  `ALTPairingFile.mobiledevicepairing`), and step 8 now does the same when the
  hand-off can't land silently.

  `Engine.importsAccountConfigSilently()` decides, by scanning the SideStore
  binary in the signed bundle for `acctFileChecksum` — the `UserDefaults` key
  added in that same change, present as both a `#function` literal and an `@objc`
  accessor name. It is read off the binary rather than the version because the
  two don't track each other: LiveContainer's *stable* IPA bundles SideStore
  `0.6.4-20260714`, which still imports silently, while its nightly bundles
  `0.6.4-20260816`, which doesn't. Verified against all four shipping IPAs.
  Under LiveContainer the binary to read is the guest copy at
  `Frameworks/SideStoreApp.framework/SideStore`, where `build_github.sh` moves
  and dylibifies `SideStore.app`. When the check can't run, it errs towards not
  writing the file.

**idevice version coexistence:** isideload pulls idevice **0.1.61** (crates.io,
behind its `install` feature, which is required because its feature-gating is
incomplete) while the rest of the app uses idevice **0.1.63** (git). The two
versions coexist as distinct crates (different symbol hashes, no collision). We
only call the sign-only path, which takes no provider and never touches
idevice, so isideload's 0.1.61 install code is compiled-but-unused.

`SideStoreDownloader.swift` fetches the latest SideStore release IPA from the
GitHub API into `Documents/SideStore.ipa`.

**Verified here:** the account module compiles against isideload's API and the
whole tree cross-compiles for iOS; the SideStore download path is plain
URLSession (runs in the simulator).

**NOT verifiable here (needs a real Apple ID + 2FA + an Apple Developer
relationship):** the actual login, anisette handshake, cert/App ID/profile
creation, and signing. Real code, unverified until run with real credentials.

### Step 4 — install + finalize — code complete; device steps unverified

`DeviceConnection.swift` (idevice-ffi over the RSD tunnel from step 2):
- **Install:** `afc_client_connect_rsd` → recursively upload the signed `.app`
  bundle to `/PublicStaging/<name>.app` (afc_make_directory + chunked
  afc_file_write) → `installation_proxy_connect_rsd` →
  `installation_proxy_install_with_callback` (progress % streamed to the log).
- **Write pairing into SideStore:** `house_arrest_client_connect_rsd` →
  `house_arrest_vend_documents(bundleID)` → write the pairing file to
  `Documents/ALTPairingFile.mobiledevicepairing`. The bundle id is read from the
  signed bundle's Info.plist (isideload rewrites it to `<orig>.<teamID>`),
  falling back to `com.SideStore.SideStore`.

**Pairing-file format — resolved in 0.9.0 (was a documented caveat).** What the
RPPairing host produces is an **RPPairing** record (`public_key`,
`private_key`, `identifier`, `alt_irk`). That is all *our* tunnel needs, and all
StikDebug's sideloaded build reads — and nothing an AltStore-family app can
parse. SideStore hands its `ALTPairingFile.mobiledevicepairing` straight to
**minimuxer** (`AppBootManager.startMinimuxer`, via
`PairingFileManager.fetchPairingFile`), which wants a *classic* lockdown record:
`HostID`, `SystemBUID`, the host/root/device certificates and keys, `EscrowBag`,
`WiFiMACAddress`, `UDID`. Feather is the same.

iLoader ships **both records in one plist** (`pairing.rs::pairing_file` merges
`generate_lockdown_plist` with `generate_rppairing_plist`), and every reader
ignores the keys it doesn't know: idevice's `RpPairingFile::from_bytes` `remove`s
its four and drops the rest, and the classic side is a serde struct
(`RawPairingFile`) with no `deny_unknown_fields`.

We now build the same merged file, minting the missing half **on-device**:

- `DeviceConnection.lockdownPairRecord` runs the classic `Pair` handshake over
  the RSD tunnel that is already open — `lockdownd_connect_rsd` →
  `lockdownd_pair` → `idevice_pairing_file_serialize`. All of it is idevice-ffi
  that was already linked (`pair` is in our feature list); **no Rust change and
  no `build-rust.sh` run was needed**. idevice retries `Pair` internally on
  `PairingDialogResponsePending`, so the call blocks while the device shows its
  Trust prompt.
- Then `EnableWifiDebugging` in `com.apple.mobile.wireless_lockdown`, as iLoader
  does — without it lockdownd answers over USB only, and every app reading this
  record reaches it over a loopback. Tried **without** a session first: over USB
  (iLoader's route) `SetValue` in that domain needs `StartSession`, but over RSD
  the stream is already inside the RPPairing tunnel and the endpoint is the
  *trusted* one, while `StartSession` there would have to negotiate a second TLS
  session inside the first. A session attempt is the fallback.
- `CompositePairingFile` (in `PairingTargets.swift`) merges the two and stamps in
  the `UDID`, which the `Pair` response doesn't carry and minimuxer needs. Output
  is **XML, never binary**: SideStore reads the file with `String(contentsOf:)`
  and hands minimuxer the *string*.
- The classic half is cached (`Application Support/lockdown_pair_record.plist`,
  keyed on the device UDID) because minting it is interactive and spends a
  pairing slot; the merge itself is redone per write. A new RPPairing record
  invalidates the merged file but keeps the cached classic one.

Our lockdown half has the **same key set as iLoader's**: iLoader also
round-trips usbmuxd's record through `PairingFile::serialize()`, i.e. the same
`RawPairingFile` ten fields. Only the provenance differs — lockdown `Pair` over
RSD instead of a usbmuxd cache entry.

**Fallback, not a hard dependency:** if any of that fails, the write proceeds
with the RPPairing record alone — what shipped before — and says so in the log.

**Still unverified on hardware:** whether lockdownd accepts `Pair` on
`com.apple.mobile.lockdown.remote.trusted`, and which of the two
`EnableWifiDebugging` attempts lands. Both paths are logged explicitly.

**Transport used (whole pipeline):** the classic lockdown *transport* (usbmuxd,
port 62078) is **not** used — every device service (lockdown info,
installation_proxy, AFC, house_arrest) is reached over the in-process RSD tunnel
(`tunnel_create_rppairing` → software TCP stack → RSD handshake), authenticated
by the RPPairing record. The classic lockdown *protocol* is spoken over that same
tunnel for exactly one thing: minting the pair record other apps read
(`lockdownd_pair` on `com.apple.mobile.lockdown.remote.trusted`).

**Verified here:** full app builds for **both** the iOS *simulator* and a
*generic iOS device* (no undefined/duplicate symbols despite idevice 0.1.61 +
0.1.63 coexisting); launches; logging spine + ping + network scan + SideStore
download all run in the simulator.

**NOT verifiable here (needs a physical iOS 17.4+ device + LocalDevVPN + a real
Apple ID):** the AFC upload, installation_proxy install, and house_arrest write.
Real code, unverified until run on hardware.

#### Fix: house_arrest write double-free + write never committing

On-device, writing the pairing file crashed with `SIGABRT`
(`POINTER_BEING_FREED_WAS_NOT_ALLOCATED`) inside
`house_arrest_client_free`, and the file never landed. Root cause (confirmed in
idevice-ffi source): `house_arrest_vend_documents` does `Box::from_raw(client)`
— it **consumes** the HouseArrestClient (success *and* failure) and moves the
underlying `Idevice` into the returned AfcClient. The old code's
`defer { house_arrest_client_free(ha) }` then double-freed that `Idevice`. Fixes
(write path only):
- Never free the HouseArrestClient after vend (it's consumed); free only the
  AfcClient, once. `afc_file_close`/`afc_client_free` each consume their handle
  → called exactly once each.
- Check the `afc_file_close` error (AFC commits on close; the old defer ignored
  it — the silent-write bug).
- **Read-back verification:** re-open the path read-only and assert the byte
  length equals what was written (`afc_file_read_entire`); throw on mismatch.
  Returns the verified byte count, surfaced in the log.

#### Fix: house_arrest write `Afc(PermDenied)` — wrong AFC path

After the double-free fix, the install succeeded end-to-end (0→100%) but the
pairing write failed `Afc(PermDenied)` on the first `afc_file_open`. Cause:
idevice's `vend_documents` roots AFC at the app **container**, not at the
Documents dir, so writing bare `ALTPairingFile.mobiledevicepairing` targets the
(non-writable) container root. Fix (matches iLoader's `place_file`): write to
**`/Documents/ALTPairingFile.mobiledevicepairing`** (with the `/Documents/`
prefix), `mk_dir` the parent first, and open with `AfcWr`.

#### Fix: house_arrest `ApplicationLookupFailed` — wrong bundle id

In a session where the user hadn't just signed, `signedAppPath` was nil and the
code fell back to the hardcoded `com.SideStore.SideStore` — but isideload
installs the app as **`com.SideStore.SideStore.<teamID>`**, so `VendDocuments`
returned `ApplicationLookupFailed`. Fix: resolve the *installed* bundle id from
**installation_proxy** (`DeviceConnection.findInstalledBundleID(base:)` — exact
or `<base>.<teamID>` match), falling back to the signed bundle's id only if the
lookup finds nothing. The installation_proxy is the source of truth for what's
actually on the device.

#### Fix: LiveContainer nightly stopped shipping `LiveContainer+SideStore.ipa`

Checked 2026-09-02 against the live releases. Three of the four derived download
URLs answer 200; `releases/download/nightly/LiveContainer+SideStore.ipa` answers
**404**. LiveContainer's rolling `nightly` release now carries only
`LiveContainer.ipa` (4.7 MB) and `apps_nightly.json`, and that plain IPA has no
`Frameworks/SideStoreApp.framework` — verified by unzipping it — so it cannot
stand in. Its own `apps_nightly.json` advertises only the plain build, and
`apps_ss_lc.json` (release tag `1.0`) still points at 3.6.1, so upstream doesn't
treat a nightly combined build as a shipped product. The CI *artifact*
`LiveContainer+SideStore.ipa` (34 MB) does exist on the 2026-08-30 run, and every
step of that run reported success — it just never reaches the release.

`selectAsset` was already safe here: its loose fallback needs `"sidestore"` in
the asset name, so it does **not** silently pick the SideStore-less
`LiveContainer.ipa`. The run failed with `noIPAAsset` instead.

Fix: `SideStoreDownloader.fetchViaReleaseScan` — a third rung under the derived
URL and the `releaseAPI` lookup. On `noIPAAsset`/`noRelease` only (never a rate
limit, an outage or an undecodable body — see `DownloadError.isChannelEmpty`) it
reads `/releases?per_page=20` and takes the newest release whose assets
`selectAsset` matches. A `stable` request skips pre-releases, so asking for
stable is never answered with a nightly; a `nightly` request takes whatever is
newest. The file is filed under the *served* release's track (`Fetched.channel`),
so a tagged build is never listed in Downloads as a nightly.

Verified against the live API by compiling the real file with a test `main`
(there is no test target): LC nightly → release 3.8.0 →
`LiveContainer+SideStore.ipa` → filed as `LiveContainer+SideStore.ipa`; LC stable
→ 3.8.0; SideStore nightly → the `nightly` prerelease; SideStore stable → 0.6.3,
skipping the prerelease. Full `downloadLatest` run for LC nightly downloads 35.4
MB from 3.8.0 and logs each rung.

The fallback is a good one, not just a survivable one: 3.8.0's guest SideStore is
`0.6.4-20260714`, whose binary has **no** `acctFileChecksum`, so the certificate
hand-off still lands silently there — better than the nightly would have been.

## Running on a device (what you do)

1. Install LocalDevVPN (App Store id 6755608044), connect it, keep Wi-Fi on.
2. Build SideInstaller in Xcode (`./build-rust.sh && xcodegen generate`, then
   run on the device with your signing team).
3. In the app: type your Apple ID email + password and tap **Install
   SideStore**. The one-click flow runs every step in order — connect VPN →
   pair (it shows a PIN to enter + tells you where) → connect → Apple ID sign-in
   (enter the 2FA code when prompted) → download → sign → install → write
   pairing file — with a progress bar and a contextual instruction card at each
   gate. When it finishes, follow the final card to trust the cert
   (Settings › General › VPN & Device Management) and open SideStore.
4. If a step stops, the card shows a plain-English reason; open **Advanced** to
   run any step individually and **Copy** the raw log (idevice FFI codes +
   isideload `Report`s) for debugging.

### UI (friend-ready)

The raw test harness was replaced by a guided installer (`ContentView.swift`):
one primary **Install SideStore** button drives the whole `Engine.runOneClick()`
orchestrator; per-step buttons + the log console moved into a collapsible
**Advanced** section. The one-click path and the per-step buttons call the same
async step cores in `Engine`, so they can never drift. State for the progress
bar/checklist (`Engine.stepStates`, `installProgress`, `pairingPIN`, `guide`)
is all `@Published`. Reused-pairing/sign-in/download are skipped when already
valid; a stale pairing file triggers one automatic re-pair before giving up.

## Honest status summary

Everything below the UI is real, wired end-to-end, and compiles for device +
sim. The pieces that need a physical device, LocalDevVPN, or a real Apple ID
(RPPairing PIN, loopback tunnel, Apple ID login/2FA, cert/profile creation,
signing, install, house_arrest write) are written but **unverified** — they
cannot run in this environment. No step fakes success; failures surface raw
errors in the log.
