# SideInstaller from iSH

Sign SideInstaller with **your own** Apple account, on the phone, using nothing but
[iSH](https://apps.apple.com/app/ish-shell/id1436902243) from the App Store.

The install page hands out builds signed with shared certificates. Apple revokes those,
and when it does, nobody can install SideInstaller. A build signed with your own free
developer certificate can't be revoked out from under you — it just expires after 7 days,
by which point SideInstaller can renew itself.

## Running it

In iSH:

```sh
wget https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/ish/install.sh
wget https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/ish/sideinstaller.py
less sideinstaller.py     # read it first — see below
sh install.sh
```

The first run compiles a code signer (`zsign`) from source. iSH emulates a 32-bit x86 CPU,
so that takes **10–40 minutes**, once, ever. Everything after that is minutes.

```
sh install.sh --build-signer   # just build the signer, then stop
sh install.sh --deps           # just install Alpine packages
sh install.sh -- --capture-udid # read this device's UDID and stop
sh install.sh -- --no-serve    # sign only; leave the .ipa in ~ for the Files app
```

## Read it before you run it

You are about to type your Apple ID password into a script. The repository's own warning
applies double here: anyone can fork this file, add four lines that POST your credentials
somewhere, and publish it under the same name.

What this script actually does with the password:

* **It is never transmitted.** Apple's GrandSlam sign-in is SRP-6a. The password becomes a
  PBKDF2 key, then a zero-knowledge proof. Apple never receives it and neither does anyone
  else. Read `SRPClient` and `AppleAccount._login_once`.
* **It is never written to disk.** It lives in one local variable, which is cleared once
  sign-in finishes.
* **The anisette server sees no account data.** It gets a random 16-byte identifier this
  script generated and Apple's provisioning blobs. Not the Apple ID, not the password, not
  the token.
* **The only hosts contacted** are `gsa.apple.com`, `developerservices2.apple.com`, your
  anisette server, `servers.sidestore.io` (the anisette list), and `github.com` (the .ipa).
  `grep -n 'https://' sideinstaller.py` shows all of them.

State lives in `~/.sideinstaller`: the RSA private key (one per Apple ID, `0600`), the
anisette identity, and the signed .ipa. Nothing is uploaded.

## What it does

1. Reads this device's UDID (see below).
2. Signs in to Apple over SRP, handling two-factor by device or SMS.
3. Trades the sign-in for an `xcode.auth` token — the developer portal's own credential.
4. Registers the device, then reuses or issues an iOS development certificate.
5. Downloads the latest unsigned SideInstaller release.
6. Registers `com.frizzlem.sideinstaller.<TEAMID>` as an App ID and pulls its provisioning
   profile.
7. Signs the .ipa with `zsign`, using the entitlements out of that profile.
8. Serves an `itms-services://` manifest over local HTTPS so Safari can install it.

Steps 2–6 are a direct port of `rust-core/vendor/isideload/src/{auth,anisette,dev}` — the
same endpoints, the same request bodies, the same SRP variant.

## What is verified, and what is not

Verified against the real thing:

* The SRP implementation is byte-identical to the `srp` crate isideload uses, for both
  `s2k` and `s2k_fo`, checked against vectors generated from that crate.
* AES-GCM (including the 16-byte-nonce path Apple uses for app tokens) matches the NIST
  vectors.
* Anisette v3 provisioning completes end to end against `ani.sidestore.io` and Apple's
  `midStartProvisioning`/`midFinishProvisioning`.
* Apple's GrandSlam URL bag parses and yields every endpoint the flow needs.
* A `listTeams` call reaches `developerservices2.apple.com` and comes back as a structured
  portal error (`1100 — Your session has expired`) rather than a 404 or a parse failure, so
  the URL shape, the headers and the plist body are all accepted. Only a valid token is
  missing.
* The release lookup, download, and .ipa inspection work against the live repository.
* The local CA, TLS leaf, both mobileconfigs, the manifest, and the UDID capture endpoint
  all work — tested locally over real TLS.

**Not verified, because it needs credentials and a phone:**

* the SRP handshake against Apple's live server, and the 2FA paths;
* every `developerservices2` call with a real token (certificate, App ID, profile);
* whether `zsign` compiles and runs correctly under iSH's i386 emulation;
* **the install step itself.** This is the weak link, and it deserves a paragraph.

### About the install step

iSH is an ordinary sandboxed App Store app. It cannot reach `installd`, so it cannot
install anything. The only route available without a computer is `itms-services://`, which
Safari hands to the App Store daemon — and that daemon insists on fetching the manifest
over HTTPS from a chain the device trusts.

So the script becomes that server: it mints a throwaway CA, asks you to install and trust
it, and serves the manifest and the .ipa from `https://127.0.0.1:8443`. Three things about
this are untested on hardware:

1. whether iOS lets Safari reach a socket another app has bound on loopback (it generally
   does — people run web servers in iSH);
2. whether the App Store daemon honours a user-installed root for that fetch;
3. whether iSH survives being backgrounded long enough for the install to finish. **This is
   the most likely thing to break.** Keep iSH in the foreground where you can.

If it fails, `--no-serve` leaves the signed `.ipa` in your home directory, reachable from
the Files app under iSH, and you can install it however you like.

## The UDID problem

A free Apple account can only sign an app for devices it has registered, so the UDID is
required — and a sandboxed app cannot read its own device's UDID.

`--capture-udid` serves a Profile Service payload; installing it makes iOS post the UDID
back to iSH. That uses the same untested local-HTTPS machinery as the install step. If it
doesn't work, the script asks you to paste the UDID. SideStore and AltStore both display
it, and UDID-lookup websites exist (they see your UDID — pick one you trust).

## Free account limits

* **Two development certificates.** Xcode, AltStore and SideStore each take one. When Apple
  refuses (error 7460), the script lists what's there and asks before revoking anything —
  revoking breaks every app already signed with that certificate.
* **Ten App IDs per week**, and they expire after 7 days.
* **Signed apps last 7 days.** Re-run this, or let SideInstaller renew itself.
