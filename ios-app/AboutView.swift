import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// About tab: version, project links and credits. Owns its `NavigationStack`
/// for the settings toolbar.
struct AboutView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer

    @State private var showSettings = false
    @State private var showCrypto = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.cascadeItem(0)
                    summary.cascadeItem(1)
                    links.cascadeItem(2)
                    thanks.cascadeItem(3)
                    builtWith.cascadeItem(4)
                }
                .padding(20)
            }
            // Uses the same bright backdrop level as the Install tab.
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showCrypto) { CryptoDonationsView() }
        }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "info.circle.fill", image: "AppLogo", title: "SideInstaller",
                    subtitle: L("an app by Frizzle")) {
            StatusPill(text: versionText, systemImage: "tag.fill", color: Theme.accent2)
        }
    }

    /// Version and build number, read from the app bundle.
    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return L("Version %@ (%@)", short, build)
    }

    // MARK: What it is

    private var summary: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(L("About"), systemImage: "info.circle.fill")
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
                         tint: Theme.accent2,
                         title: L("Source code"),
                         urlString: "https://github.com/FrizzleM/SideInstaller/tree/main")
                AboutRow(systemImage: "bubble.left.and.bubble.right.fill",
                         tint: Color(red: 0.35, green: 0.40, blue: 0.95),
                         title: L("Discord"),
                         urlString: "https://discord.gg/sQ5Y8vbYJS")
                AboutRow(systemImage: "cup.and.saucer.fill",
                         tint: Color(red: 1.0, green: 0.36, blue: 0.42),
                         title: L("Support the project"),
                         urlString: "https://ko-fi.com/frizzlem")
                AboutRow(systemImage: "bitcoinsign.circle.fill",
                         tint: Color(red: 0.97, green: 0.58, blue: 0.10),
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
                sectionTitle(L("Special thanks"), systemImage: "heart.fill")
                AboutRow(systemImage: "hammer.fill",
                         tint: Theme.accent,
                         title: "jkcoxson",
                         detail: L("For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it."),
                         urlString: "https://github.com/jkcoxson/idevice")
                AboutRow(systemImage: "ladybug.fill",
                         tint: .orange,
                         title: "Vexon",
                         detail: L("For the support, and for spotting the bugs that got fixed because of it."))
                AboutRow(systemImage: "character.bubble.fill",
                         tint: Color(red: 0.95, green: 0.35, blue: 0.45),
                         title: "so-5699",
                         detail: L("For the Japanese translation."),
                         urlString: "https://github.com/so-5699")
            }
        }
    }

    // MARK: Built with

    private var builtWith: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle(L("Built with"), systemImage: "shippingbox.fill")
                Text(L("The open source work this app is built on:"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                AboutRow(systemImage: "iphone.gen3",
                         tint: Theme.accent2,
                         title: "idevice",
                         detail: L("Pairing, the tunnel and the install itself. By jkcoxson, MIT."),
                         urlString: "https://github.com/jkcoxson/idevice")
                AboutRow(systemImage: "signature",
                         tint: Theme.accent2,
                         title: "isideload",
                         detail: L("Apple ID sign in, certificates and signing on the device. By nab138, MIT."),
                         urlString: "https://github.com/nab138/isideload")
                AboutRow(systemImage: "shippingbox.fill",
                         tint: .green,
                         title: "SideStore",
                         detail: L("The sideloading app this installs for you."),
                         urlString: "https://github.com/SideStore/SideStore")
                AboutRow(systemImage: "square.stack.3d.up.fill",
                         tint: .green,
                         title: "LiveContainer",
                         detail: L("Runs sideloaded apps without spending an app slot on each one."),
                         urlString: "https://github.com/LiveContainer/LiveContainer")
                AboutRow(systemImage: "externaldrive.fill",
                         tint: .purple,
                         title: "DeveloperDiskImage",
                         detail: L("The developer disk image location spoofing mounts. Mirrored by doronz88."),
                         urlString: "https://github.com/doronz88/DeveloperDiskImage")
            }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.brand)
        }
    }
}

// MARK: - Row

/// A row with a tinted icon, a title and an optional detail line. Rows with a
/// `urlString` open it and show an arrow; rows with an `action` run it and
/// show a chevron.
private struct AboutRow: View {
    var systemImage: String
    var tint: Color
    var title: String
    var detail: String? = nil
    var urlString: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let action {
            Button(action: action) { content(accessory: "chevron.right") }
                .buttonStyle(.plain)
        } else if let url = urlString.flatMap(URL.init(string:)) {
            Button { openURL(url) } label: { content(accessory: "arrow.up.right") }
                // `.plain` keeps the row from using the accent color.
                .buttonStyle(.plain)
        } else {
            content(accessory: nil)
        }
    }

    private func content(accessory: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.gradient(tint))
                // Fixed width so the icons line up.
                .frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let accessory {
                Image(systemName: accessory)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
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
                VStack(spacing: 18) {
                    Text(L("Donations are entirely optional. They don't buy anything, unlock any feature or get you anything in return; they're just a way to say thanks if SideInstaller has helped you."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
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
            VStack(spacing: 14) {
                QRCodeView(text: wallet.address)
                    .frame(width: 200, height: 200)
                    .accessibilityLabel(L("QR code for the %@ address", wallet.name))
                Text(L("Network: %@", wallet.network))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
                .buttonStyle(PrimaryButtonStyle())
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
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
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
