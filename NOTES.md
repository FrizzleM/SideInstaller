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
`Documents/rp_pairing_file.plist`. Reports every step into the log console.

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
handshake → services over RSD. Pairing-record type: **RPPairing**
(`rp_pairing_file.plist`), not a classic lockdown pairing record.

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

### Step 3 — Apple ID + signing — code complete; device/account steps unverified

`account.rs` wraps isideload behind two FFI calls:
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

**Format caveat (documented, not papered over):** the pairing file we generate
is an **RPPairing** record (`rp_pairing_file.plist`). SideStore's
`ALTPairingFile.mobiledevicepairing` historically is a *classic* lockdown
pairing record. Recent SideStore builds that use the LocalDevVPN/RSD path may
accept the RPPairing record; this needs confirming on-device. The app logs this
caveat after writing.

**Transport used (whole pipeline):** classic lockdown is **not** used — every
device service (lockdown info, installation_proxy, AFC, house_arrest) is reached
over the in-process RSD tunnel (`tunnel_create_rppairing` → software TCP stack →
RSD handshake), authenticated by the RPPairing record.

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
