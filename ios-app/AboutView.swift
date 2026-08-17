import SwiftUI

/// The About page: what this build is, where the project lives, and whose work
/// it stands on. A tab of its own, so it owns the `NavigationStack` the settings
/// toolbar hangs from.
struct AboutView: View {
    /// Declared so every label on this screen redraws when the language changes.
    @EnvironmentObject private var loc: Localizer

    @State private var showSettings = false

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
            // The heaviest of the three washes, `Backdrop.darkest`, set by the
            // tab switch so the tabs read as a descent: Install, Tools, then this.
            .background(AppBackground())
            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: Header

    private var header: some View {
        BrandHeader(icon: "info.circle.fill", image: "AppLogo", title: "SideInstaller",
                    subtitle: L("an app by Frizzle")) {
            StatusPill(text: versionText, systemImage: "tag.fill", color: Theme.accent2)
        }
    }

    /// Marketing version with the build number after it, both read from the
    /// bundle so this line can never drift from what was actually installed.
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

/// One entry on this page: a tinted glyph, a name and — where there is one — a
/// line about it. Rows carrying a `urlString` open it and wear an arrow; the
/// rest are plain credits.
private struct AboutRow: View {
    var systemImage: String
    var tint: Color
    var title: String
    var detail: String? = nil
    var urlString: String? = nil

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url = urlString.flatMap(URL.init(string:)) {
            Button { openURL(url) } label: { content(isLink: true) }
                // Otherwise the whole row is drawn in the accent colour, and
                // `.secondary` under it resolves to a faded blue.
                .buttonStyle(.plain)
        } else {
            content(isLink: false)
        }
    }

    private func content(isLink: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.gradient(tint))
                // Fixed, so the column of glyphs lines up whatever their width.
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
            if isLink {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
