<div align="center">

<img src="app-icon.png" alt="SideInstaller" width="120" />

# SideInstaller

**Install SideStore and LiveContainer directly on your iPhone. No PC required.**

[![Install](https://img.shields.io/badge/Install-SideInstaller-2ea44f?style=for-the-badge)](https://frizzlem.github.io/SideInstaller/)
[![Version](https://img.shields.io/badge/version-0.6.5-blue?style=for-the-badge)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-iOS-lightgrey?style=for-the-badge&logo=apple)](#requirements)
[![License](https://img.shields.io/badge/license-Custom-orange?style=for-the-badge)](LICENSE.md)


</div>

---

> [!CAUTION]
> **Only install SideInstaller from the official source.**
>
> This project is open source, which means anyone can fork the code, insert a credential stealer that
> uploads your Apple ID and password to their own server, rebuild it, and redistribute it under the same
> name and icon. A malicious fork looks identical to the real app from the outside.
>
> The **only** builds we publish are:
> - **Website:** https://frizzlem.github.io/SideInstaller/
> - **Repository:** https://github.com/FrizzleM/SideInstaller
>
> Do not install SideInstaller from any other site, AltStore source, Telegram channel, Discord server,
> app repo, or mirror, no matter how official it looks. Redistributing my builds without explicit consent is also prohibited by
> the [license](LICENSE.md).

---

## What it is

SideStore and LiveContainer are currently the best way to sideload on iOS. However, there's one big
problem: installing them requires a PC, which many people don't have. That's why I made SideInstaller,
a free and open-source iOS app that installs them directly on your iPhone, no PC required.

SideInstaller handles the entire setup process on-device. It takes care of the pairing, provisioning, and
installation steps that normally force you to plug into a computer and run desktop tools, all from a single
app running on the phone itself. Once it's done, you get a fully working SideStore and LiveContainer
setup ready to sideload your own apps.

The whole thing is built to be simple. There's no complicated configuration, no command line, and no need
to understand how any of the underlying machinery works. You just open the app, follow a few steps, and let
it do the rest. For anyone who's ever wanted to sideload but didn't own a Mac or PC, this removes the
biggest barrier to getting started.

And because it's open source, you don't have to take my word for any of it. The full code is available for
anyone to read, audit, or contribute to, so you can see exactly what's running on your device.

## Requirements

- An iPhone or iPad on iOS 27
- A Wi-Fi router or a hotspot connection
- Your Apple account credentials (not collected)


## How to use it

1. Install **LocalDevVPN** and connect to the VPN.
2. Open [the official install page](https://frizzlem.github.io/SideInstaller/) and install the app using any
   of the certificates.
3. Once it's installed, open it.
4. Log in with your Apple account credentials.
5. Tap **Install SideStore** or **Install SideStore + LiveContainer**.
6. Wait while your selection installs.
7. That's it. No PC and no extra steps required.

## Is SideInstaller safe?

SideInstaller is built with safety and privacy in mind. The app is fully local and open source, which means
anyone can inspect exactly what it does.

**Your Apple credentials never leave your device.** They're used locally, only to sign and install your
  apps, and are never transmitted, logged, or collected in any way.

**No server, no analytics, no account.** Nothing is collected and there's nothing to sign up for.

**Fully auditable.** Every line of it can be verified in the source code.

> [!WARNING]
> All of the above is true of **this** repository and the builds published from it. It is **not** a guarantee
> that applies to forks, re-signed IPAs, or copies you find elsewhere — those can be modified to steal the
> Apple ID you type into them. If you didn't get it from
> [frizzlem.github.io/SideInstaller](https://frizzlem.github.io/SideInstaller/), don't trust it with your
> credentials.

## Project layout

| Path | What's in it |
| :-- | :-- |
| `ios-app/` | The SwiftUI app — UI, install engine, certificate handling, translations |
| `rust-core/` | Rust core compiled into `SideInstallerFFI.xcframework` |
| `scripts/` | Build, signing, and install-page generation scripts |
| `.github/` | Workflows for signing and publishing the install page |

## Contributing

Issues and pull requests are welcome. If you're reporting a bug, please include your iOS version, the app
version, and the step where it failed.

## License

See [LICENSE.md](LICENSE.md). In short: you may read, modify, and share the **source**, with attribution,
for non-commercial purposes. Redistributing the official builds (IPAs) or monetizing the project in any
form requires written permission.

<div align="center">

**SideInstaller by [FrizzleM](https://github.com/FrizzleM)**

</div>
