import SwiftUI

// MARK: - Model

/// One published release and the notes written for it on GitHub.
struct ReleaseNote: Identifiable, Equatable {
    /// "2.2.0", from the tag "v2.2.0".
    let version: String
    let published: Date?
    /// The release's description, Markdown as typed on GitHub.
    let body: String
    /// The release's page on GitHub.
    let url: URL?

    var id: String { version }
}

/// A piece of a release's notes, as `ReleaseNotesView` draws it.
enum ReleaseNoteBlock: Equatable {
    /// A `#`, `##` or `###` line.
    case heading(String)
    /// A `-`, `*` or `+` item; `depth` 0 is the outermost list.
    case bullet(String, depth: Int)
    /// Lines that are neither, up to a blank line.
    case paragraph(String)
}

// MARK: - Loading

/// The release notes of every SideInstaller release, fetched from GitHub when
/// the version log first opens and kept for the rest of the launch.
/// Prereleases (betas) and drafts are left out, as the update banner leaves
/// them out.
@MainActor
final class ReleaseNotesStore: ObservableObject {

    static let shared = ReleaseNotesStore()

    /// Newest first; 100 is the most one page holds, and covers every release so far.
    static let releasesAPIURL =
        "https://api.github.com/repos/FrizzleM/SideInstaller/releases?per_page=100"
    /// Where the notes can be read when they can't be loaded here.
    static let releasesPageURL = URL(string: "https://github.com/FrizzleM/SideInstaller/releases")!

    enum State: Equatable {
        case idle
        case loading
        case loaded([ReleaseNote])
        /// The message to show, already translated.
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    /// Fetch the notes, unless they're already here or on their way. `force`
    /// fetches them again (pull to refresh, Try again).
    func load(force: Bool = false) async {
        switch state {
        case .loading: return
        case .loaded where !force: return
        default: break
        }
        // A refresh keeps the notes on screen while it runs.
        if case .loaded = state {} else { state = .loading }

        guard let url = URL(string: Self.releasesAPIURL) else { return }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 20
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                // GitHub allows 60 requests an hour per address without an account.
                state = .failed(status == 403 || status == 429
                    ? L("GitHub is limiting requests from this network. Try again in a few minutes.")
                    : L("Couldn't load the release notes. Check your connection and try again."))
                return
            }
            state = .loaded(try Self.notes(from: data))
        } catch {
            // Notes already on screen stay there when a refresh fails.
            if case .loaded = state { return }
            state = .failed(L("Couldn't load the release notes. Check your connection and try again."))
        }
    }

    // MARK: Parsing

    private struct APIRelease: Decodable {
        let tag_name: String
        let body: String?
        let html_url: String?
        let published_at: Date?
        let draft: Bool?
        let prerelease: Bool?
    }

    /// The published, non-prerelease releases in GitHub's `/releases` JSON,
    /// newest version first.
    nonisolated static func notes(from data: Data) throws -> [ReleaseNote] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([APIRelease].self, from: data)
            .filter { $0.draft != true && $0.prerelease != true }
            .compactMap { release in
                guard let version = UpdateChecker.version(fromTag: release.tag_name) else { return nil }
                return ReleaseNote(version: version,
                                   published: release.published_at,
                                   body: release.body ?? "",
                                   url: release.html_url.flatMap(URL.init(string:)))
            }
            .sorted { UpdateChecker.isNewer($0.version, than: $1.version) }
    }

    /// Splits a release's Markdown into headings, list items and paragraphs,
    /// the parts the notes are written in. Inline Markdown (bold, links,
    /// code) is left in the text for `inline(_:)`. GitHub's "Full Changelog"
    /// compare link and horizontal rules are dropped.
    nonisolated static func blocks(from markdown: String) -> [ReleaseNoteBlock] {
        var blocks: [ReleaseNoteBlock] = []
        var paragraph: [String] = []
        /// The indents of the lists the current item sits in, outermost first.
        var listIndents: [Int] = []
        /// True while the last block is an item a wrapped line belongs to.
        var inItem = false

        func endParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            paragraph = []
        }

        let text = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = line.prefix { $0 == " " || $0 == "\t" }
                .reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }

            if trimmed.isEmpty {
                endParagraph()
                inItem = false
                continue
            }
            if trimmed.hasPrefix("**Full Changelog**") || isRule(trimmed) {
                endParagraph()
                inItem = false
                continue
            }
            if let heading = heading(trimmed) {
                endParagraph()
                listIndents = []
                inItem = false
                blocks.append(.heading(heading))
                continue
            }
            if let item = listItem(trimmed) {
                endParagraph()
                while let last = listIndents.last, last > indent { listIndents.removeLast() }
                if listIndents.last != indent { listIndents.append(indent) }
                blocks.append(.bullet(item, depth: listIndents.count - 1))
                inItem = true
                continue
            }
            // A wrapped line carries on the item above it.
            if inItem, case .bullet(let item, let depth)? = blocks.last {
                blocks[blocks.count - 1] = .bullet(item + " " + trimmed, depth: depth)
                continue
            }
            listIndents = []
            paragraph.append(trimmed)
        }
        endParagraph()
        return blocks
    }

    /// "## Fixes:" → "Fixes". Nil when the line isn't an ATX heading.
    nonisolated private static func heading(_ line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.isEmpty || rest.first == " " else { return nil }
        var title = rest.trimmingCharacters(in: .whitespaces)
        // Closing #s, and the colon some notes end their headings with.
        while title.hasSuffix("#") { title.removeLast() }
        title = title.trimmingCharacters(in: .whitespaces)
        if title.hasSuffix(":") { title.removeLast() }
        return title.isEmpty ? nil : title
    }

    /// "- Fixed it" → "Fixed it". Nil when the line isn't a list item.
    nonisolated private static func listItem(_ line: String) -> String? {
        guard let marker = line.first, "-*+".contains(marker) else { return nil }
        let rest = line.dropFirst()
        guard rest.first == " " else { return nil }
        let item = rest.trimmingCharacters(in: .whitespaces)
        return item.isEmpty ? nil : item
    }

    /// `---`, `***` or `___`.
    nonisolated private static func isRule(_ line: String) -> Bool {
        let chars = line.filter { $0 != " " }
        guard chars.count >= 3, let first = chars.first, "-*_".contains(first) else { return false }
        return chars.allSatisfy { $0 == first }
    }

    /// A block's text with its bold, italics, code and links drawn, and bare
    /// URLs made tappable as GitHub makes them.
    nonisolated static func inline(_ text: String) -> AttributedString {
        var attributed = (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace,
                           failurePolicy: .returnPartiallyParsedIfPossible)))
            ?? AttributedString(text)

        let plain = String(attributed.characters)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in detector.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
                guard let url = match.url,
                      let range = Range(match.range, in: plain),
                      let lower = AttributedString.Index(range.lowerBound, within: attributed),
                      let upper = AttributedString.Index(range.upperBound, within: attributed)
                else { continue }
                let span = lower..<upper
                // Markdown links already have their own.
                if attributed[span].runs.contains(where: { $0.link != nil }) { continue }
                attributed[span].link = url
            }
        }
        return attributed
    }
}

// MARK: - View

/// The version log: each release's notes from GitHub, newest first, with the
/// version this iPhone runs and any newer ones marked. Opened from About and
/// from the update banner.
struct ReleaseNotesView: View {
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var store = ReleaseNotesStore.shared

    /// This build's marketing version, e.g. "2.2.0".
    private let currentVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(20)
                    .pageColumn()
            }
            .refreshable { await store.load(force: true) }
            .background(AppBackground())
            .navigationTitle(L("Release notes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { openURL(ReleaseNotesStore.releasesPageURL) } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel(L("Open on GitHub"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
            .task { await store.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        case .failed(let message):
            failure(message)
        case .loaded(let releases):
            LazyVStack(spacing: 16) {
                ForEach(releases) { release in
                    ReleaseCard(release: release, tag: tag(for: release))
                }
            }
        }
    }

    private func failure(_ message: String) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: L("Release notes"), systemImage: "exclamationmark.triangle")
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 20) {
                    Button(L("Try again")) { Task { await store.load(force: true) } }
                    Button(L("Open on GitHub")) { openURL(ReleaseNotesStore.releasesPageURL) }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain, sound: .tick)
            }
        }
    }

    private func tag(for release: ReleaseNote) -> String? {
        if UpdateChecker.isNewer(release.version, than: currentVersion) { return L("New") }
        if !UpdateChecker.isNewer(currentVersion, than: release.version) { return L("Installed") }
        return nil
    }
}

/// One release: its version, date and notes.
private struct ReleaseCard: View {
    let release: ReleaseNote
    /// "New" or "Installed", next to the version.
    let tag: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(release.version)
                        .font(.headline.monospacedDigit())
                    if let tag { VersionTag(text: tag) }
                    Spacer(minLength: 8)
                    if let date = release.published {
                        Text(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)
                            .locale(Localizer.locale)))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                let blocks = ReleaseNotesStore.blocks(from: release.body)
                if blocks.isEmpty {
                    Text(L("No notes for this version."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                            blockView(block, first: index == 0)
                        }
                    }
                }
                if let url = release.url {
                    Button { openURL(url) } label: {
                        HStack(spacing: 4) {
                            Text(L("View on GitHub"))
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain, sound: .tick)
                }
            }
            .tint(Theme.accent)
        }
    }

    @ViewBuilder
    private func blockView(_ block: ReleaseNoteBlock, first: Bool) -> some View {
        switch block {
        case .heading(let text):
            Text(ReleaseNotesStore.inline(text))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, first ? 0 : 6)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let text, let depth):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(depth == 0 ? "•" : "◦")
                    .foregroundStyle(Theme.muted)
                Text(ReleaseNotesStore.inline(text))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline)
            .padding(.leading, CGFloat(min(depth, 3)) * 16)
        case .paragraph(let text):
            Text(ReleaseNotesStore.inline(text))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "New" / "Installed" next to a version, drawn like `BetaBadge`.
private struct VersionTag: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1))
            .fixedSize()
    }
}
