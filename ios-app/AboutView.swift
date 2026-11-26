import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// About tab: version, project links and credits. Owns its `NavigationStack`
/// for the settings toolbar.
struct AboutView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @EnvironmentObject private var updateChecker: UpdateChecker
    // F-1 (0.9.176): the self-update's state lives on `updateChecker`
    // now, shared with the Install tab's banner — this view only reads
    // it (see `versionPillText` / `updateCheckDetail`). The progress
    // line still redraws as the download advances: it reads
    // `Engine.shared` inside `selfUpdateProgressText`, and that read
    // happens during this view's body evaluation, so the view tracks it.

    @State private var showSettings = false
    @State private var showCrypto = false
    @State private var showReport = false
    /// True while a manual update check is in flight.
    @State private var isCheckingUpdate = false
    /// The in-flight manual check, so a second tap can cancel it.
    @State private var checkTask: Task<Void, Never>?
    /// What the last manual update check found; nil until one runs.
    @State private var updateCheckStatus: UpdateChecker.CheckResult?
    /// F-2 (0.9.178): true while the full release-notes sheet is up.
    @State private var showingReleaseNotes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header.cascadeItem(0)
                    updateCheck.cascadeItem(1)
                    summary.cascadeItem(2)
                    links.cascadeItem(3)
                    thanks.cascadeItem(4)
                    builtWith.cascadeItem(5)
                }
                .padding(20)
                .pageColumn()
            }
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showCrypto) { CryptoDonationsView() }
            .sheet(isPresented: $showReport) { ReportProblemView() }
        }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "info.circle.fill", image: "AppLogo", title: "SideInstaller 🅥",
                    subtitle: L("an app by Frizzle") + "\n解剖自我 🅥 " + L("Modified edition")) {
            versionPill
        }
    }

    /// The version line: static text when there's nothing to update, a
    /// button when a verified newer version is waiting (0.9.149). A tap
    /// with no update known runs a check first; a tap with one waiting
    /// installs it. It looks the same either way — the pill is the row.
    private var versionPill: some View {
        Button { CZFHaptics.impact(); versionRowTapped() } label: {
            StatusPill(text: versionPillText, systemImage: versionPillIcon, color: versionPillColor)
        }
        .buttonStyle(.plain, sound: .tick)
        // B-2 (0.9.164): no `.disabled(isSelfUpdating)` any more — the pill
        // is the cancel while a self-update runs (versionRowTapped below),
        // and the wait has no other handle.
    }

    /// The version line's text: the running version, or what the row is
    /// doing — checking, offering the new version, downloading it,
    /// installing it. The self-update's state is `updateChecker`'s now
    /// (F-1, 0.9.176); this row only reads it.
    private var versionPillText: String {
        // B-2 (0.9.164): while updating the pill is the cancel — the
        // progress itself still shows under "Check for updates".
        if updateChecker.isSelfUpdating { return L("Installing — tap to cancel") }
        if let progress = updateChecker.selfUpdateProgressText { return progress }
        if updateChecker.selfUpdateAvailable, let latest = updateChecker.latestVersion {
            return L("Update to %@", latest)
        }
        if isCheckingUpdate { return L("Checking for updates…") }
        return versionText
    }

    private var versionPillIcon: String {
        updateChecker.selfUpdateAvailable || updateChecker.isSelfUpdating ? "arrow.down.circle.fill" : "tag.fill"
    }

    private var versionPillColor: Color {
        updateChecker.selfUpdateAvailable || updateChecker.isSelfUpdating ? Theme.accent : Theme.accent2
    }

    /// The version row's tap: install when a verified update is waiting,
    /// otherwise check first (0.9.142 manual check, 0.9.146 timeout +
    /// cancel); a newer verified version lights the update state, and the
    /// next tap installs it. While a self-update runs the row cancels it
    /// instead (B-2, 0.9.164) — the install itself keeps going on the
    /// Install page; only the watching stops.
    private func versionRowTapped() {
        if updateChecker.isSelfUpdating {
            updateChecker.cancelSelfUpdate()
            return
        }
        if updateChecker.selfUpdateAvailable { updateChecker.startSelfUpdate(); return }
        runUpdateCheck()
    }

    /// Version and build number, read from the app bundle.
    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return L("Version %@ (%@)", short, build)
    }

    // MARK: Check for updates

    /// Manual update check, under the version line: the launch check only
    /// runs once a day, so this is how to ask right now. The row's detail
    /// line reports the outcome; a newer version also lights the Install
    /// tab's banner, which carries the download link.
    private var updateCheck: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                AboutRow(systemImage: "arrow.down.circle",
                         title: L("Check for updates"),
                         detail: updateCheckDetail,
                         action: { runUpdateCheck() })
                // F-1 (0.9.177): the verified newer release's notes —
                // the same section as the Install banner; only when an
                // install is actually offered.
                // F-2 (0.9.178): tap it for the full notes (the Install
                // banner's `ReleaseNotesSheet` 同款).
                if updateChecker.selfUpdateAvailable, let notes = updateChecker.releaseNotesPreview {
                    Button {
                        showingReleaseNotes = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(L("What's new"))
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                            }
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingReleaseNotes) {
                        ReleaseNotesSheet(updateChecker: updateChecker)
                    }
                }
            }
        }
    }

    /// The detail line under "Check for updates": nothing until a check runs.
    /// A failed self-update reports here too, so the reason stays on this
    /// page even after the Install sheet is dismissed.
    private var updateCheckDetail: String? {
        if let selfUpdateError = updateChecker.selfUpdateError { return selfUpdateError }
        if let progress = updateChecker.selfUpdateProgressText { return progress }
        if isCheckingUpdate { return L("Checking for updates… Tap again to cancel.") }
        switch updateCheckStatus {
        case nil, .skipped: return nil
        case .upToDate: return L("You're up to date.")
        case .newer(let latest):
            return L("SideInstaller %@ is available — you're on %@.",
                     latest, updateChecker.currentVersion)
        case .pendingRelease(let latest):
            // B-1 (0.9.177): txt 已新、门控未过 — the same sentence the
            // Install banner shows; the update itself stays unoffered
            // until the release verifies.
            return L("SideInstaller %@ is still being published — try again later.", latest)
        case .failed:
            return L("Couldn't check for updates. Check your connection and try again.")
        }
    }

    /// Run a check that ignores the 24-hour stamp. B5 (0.9.146): a second
    /// tap while one is in flight cancels it, and the detail line goes back
    /// to whatever the last check found — a cancelled check writes no
    /// outcome, so "Checking…" can't stick around after the tap.
    private func runUpdateCheck() {
        if isCheckingUpdate {
            checkTask?.cancel()
            return
        }
        // A fresh check clears the last self-update's outcome: it reports
        // the new check, not the old install.
        updateChecker.selfUpdateError = nil
        updateChecker.selfUpdateFinished = false
        isCheckingUpdate = true
        checkTask = Task {
            let result = await updateChecker.check(force: true)
            if !Task.isCancelled {
                updateCheckStatus = result
            }
            isCheckingUpdate = false
            checkTask = nil
        }
    }

    // MARK: What it is

    private var summary: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L("About"), systemImage: "info.circle")
                Text(L("SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved."))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Links

    private var links: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle(L("Links"), systemImage: "link")
                AboutRow(systemImage: "chevron.left.forwardslash.chevron.right",
                         title: L("Source code"),
                         urlString: "https://github.com/FrizzleM/SideInstaller/tree/main")
                AboutRow(systemImage: "exclamationmark.bubble",
                         title: L("Report a problem"),
                         detail: L("Opens a GitHub issue with this app's details, its log and crash logs."),
                         action: { showReport = true })
                AboutRow(systemImage: "bubble.left.and.bubble.right",
                         title: L("Discord"),
                         urlString: "https://discord.gg/sQ5Y8vbYJS")
                AboutRow(systemImage: "cup.and.saucer",
                         title: L("Support the project"),
                         urlString: "https://ko-fi.com/frizzlem")
                AboutRow(systemImage: "bitcoinsign.circle",
                         title: L("Crypto"),
                         detail: L("Donation wallets for Bitcoin, Ethereum and Solana."),
                         action: { showCrypto = true })
            }
        }
    }

    // MARK: Special thanks

    private var thanks: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle(L("Special thanks"), systemImage: "heart")
                AboutRow(systemImage: "hammer",
                         title: "jkcoxson",
                         detail: L("For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it."),
                         urlString: "https://github.com/jkcoxson/idevice")
                AboutRow(systemImage: "ladybug",
                         title: "Vexon",
                         detail: L("For the support, and for spotting the bugs that got fixed because of it."))
                AboutRow(systemImage: "character.bubble",
                         title: "so-5699",
                         detail: L("For the Japanese translation."),
                         urlString: "https://github.com/so-5699")
                AboutRow(systemImage: "character.bubble",
                         title: "kes158",
                         detail: L("For the Korean translation."),
                         urlString: "https://github.com/kes158")
                AboutRow(systemImage: "character.bubble",
                         title: "Mr3242-Scripter",
                         detail: L("For the Turkish translation."),
                         urlString: "https://github.com/Mr3242-Scripter")
            }
        }
    }

    // MARK: Built with

    private var builtWith: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle(L("Built with"), systemImage: "shippingbox")
                Text(L("The open source work this app is built on:"))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                AboutRow(systemImage: "iphone.gen3",
                         title: "idevice",
                         detail: L("Pairing, the tunnel and the install itself. By jkcoxson, MIT."),
                         urlString: "https://github.com/jkcoxson/idevice")
                AboutRow(systemImage: "signature",
                         title: "isideload",
                         detail: L("Apple ID sign in, certificates and signing on the device. By nab138, MIT."),
                         urlString: "https://github.com/nab138/isideload")
                AboutRow(systemImage: "checkmark.seal",
                         title: "apple-codesign-quick",
                         detail: L("The code signer isideload uses for each app. By Dadoum, LGPL-2.1."),
                         urlString: "https://github.com/Dadoum/apple-crates")
                AboutRow(systemImage: "shippingbox",
                         title: "SideStore",
                         detail: L("The sideloading app this installs for you."),
                         urlString: "https://github.com/SideStore/SideStore")
                AboutRow(systemImage: "square.stack.3d.up",
                         title: "LiveContainer",
                         detail: L("Runs sideloaded apps without spending an app slot on each one."),
                         urlString: "https://github.com/LiveContainer/LiveContainer")
                AboutRow(systemImage: "gamecontroller",
                         title: "Madeira",
                         detail: L("Runs Windows PC games on your iPhone. By Will Faust, GPL-3.0."),
                         urlString: "https://github.com/willfaust/Madeira")
                AboutRow(systemImage: "externaldrive",
                         title: "DeveloperDiskImage",
                         detail: L("The developer disk image location spoofing mounts. Mirrored by doronz88."),
                         urlString: "https://github.com/doronz88/DeveloperDiskImage")
            }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        SectionTitle(title: title, systemImage: systemImage)
    }
}

// MARK: - Row

/// A row with an icon, a title and an optional detail line. Rows with a
/// `urlString` open it and show an arrow; rows with an `action` run it and
/// show a chevron.
private struct AboutRow: View {
    var systemImage: String
    var title: String
    var detail: String? = nil
    var urlString: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let action {
            Button { CZFHaptics.impact(); action() } label: { content(accessory: "chevron.right") }
                .buttonStyle(.plain, sound: .tick)
        } else if let url = urlString.flatMap(URL.init(string:)) {
            Button { CZFHaptics.impact(); openURL(url) } label: { content(accessory: "arrow.up.right") }
                // `.plain` keeps the row from using the accent color.
                .buttonStyle(.plain, sound: .tick)
        } else {
            content(accessory: nil)
        }
    }

    private func content(accessory: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(Theme.muted)
                // Fixed width so the icons line up.
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let accessory {
                Image(systemName: accessory)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
            }
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Crypto donations

/// A wallet that takes donations.
private struct DonationWallet: Identifiable {
    var name: String
    var network: String
    var address: String

    var id: String { address }
}

/// The sheet behind the Crypto row: one donation wallet on screen at a time.
/// These are gifts, not a purchase, and the copy says so: nothing is sold or
/// unlocked in return.
private struct CryptoDonationsView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    /// Checked against the wallet's own QR codes, and against each address's
    /// checksum (bech32 for Bitcoin, EIP-55 for Ethereum).
    private static let wallets = [
        DonationWallet(name: "Bitcoin", network: "Bitcoin (Native SegWit)",
                       address: "bc1qf4t3feq47k0snhazqns89vnr83fxzshtr3p9pd"),
        DonationWallet(name: "Ethereum", network: "Ethereum",
                       address: "0xC0Ae728AdA099bADEEB5f866ee91b890b9D127d3"),
        DonationWallet(name: "Solana", network: "Solana",
                       address: "BSo1pYPQWNBjjLpzu8Ean5ZVXyEHHJRvJaiVNBUj4fLh"),
    ]

    @State private var selection = CryptoDonationsView.wallets[0].id
    /// The address just copied, for the button's brief "Copied" state.
    @State private var copied: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(L("Donations are entirely optional. They don't buy anything, unlock any feature or get you anything in return; they're just a way to say thanks if SideInstaller has helped you."))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker(L("Coin"), selection: $selection) {
                        ForEach(Self.wallets) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.segmented)
                    if let wallet = Self.wallets.first(where: { $0.id == selection }) {
                        walletCard(wallet)
                    }
                    Label(L("Send each coin only on the network shown. Crypto sent on another network can't be recovered."),
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .pageColumn()
            }
            .background(AppBackground())
            .navigationTitle(L("Crypto donations"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
    }

    private func walletCard(_ wallet: DonationWallet) -> some View {
        let isCopied = copied == wallet.address
        return PanelCard {
            VStack(spacing: 16) {
                QRCodeView(text: wallet.address)
                    .frame(width: 200, height: 200)
                    .accessibilityLabel(L("QR code for the %@ address", wallet.name))
                Text(L("Network: %@", wallet.network))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
                // One line, shrunk to fit: wrapped, it gets hyphenated in some
                // languages, and a hyphen copied by hand breaks the address.
                Text(wallet.address)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .textSelection(.enabled)
                Button { copy(wallet.address) } label: {
                    Label(isCopied ? L("Copied") : L("Copy"),
                          systemImage: isCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(PrimaryButtonStyle(sound: .rise))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func copy(_ address: String) {
        UIPasteboard.general.string = address
        withAnimation { copied = address }
        // Back to "Copy" after a moment, unless a later copy took over.
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if copied == address { withAnimation { copied = nil } }
        }
    }
}

/// A QR code for `text`, drawn with hard pixel edges on a white tile so any
/// wallet's scanner can read it.
private struct QRCodeView: View {
    var text: String

    private static let context = CIContext()

    var body: some View {
        if let image = Self.render(text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).fill(.white))
        }
    }

    private static func render(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
