import Foundation

/// A `sideinstaller://` link opened from a web page, a chat or another app.
/// Nothing acts on one until the user says yes to its popup.
enum DeepLink: Hashable {
    /// `sideinstaller://install?url=<link to an .ipa>`: download that IPA as the
    /// custom build, then install it.
    case install(URL)
    /// `sideinstaller://pairingFile?data=<base64 plist>`: a pairing file to
    /// import. SideStore sends one back when asked with
    /// `sidestore://pairing?urlname=sideinstaller`.
    case pairingFile(LinkedPairingFile)

    /// The scheme registered in Info.plist.
    static let scheme = "sideinstaller"

    /// What a `sideinstaller://` URL asks for.
    enum Parsed {
        case link(DeepLink)
        /// Nothing to do: LocalDevVPN returning to the app, or an action this
        /// version doesn't know (named, when there is one).
        case ignored(action: String?)
        /// A known action carrying something unusable; the message says why.
        case invalid(String)
    }

    /// A pairing file is a few KB; anything far bigger isn't one.
    private static let maxPairingFileBytes = 1 << 20

    /// Reads a link. `answersSideStore` says SideInstaller asked SideStore for
    /// its pairing file a moment ago, so a pairing file arriving now is its reply.
    static func parse(_ url: URL, answersSideStore: Bool) -> Parsed {
        guard url.scheme?.lowercased() == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let action = components.host?.lowercased(), !action.isEmpty
        else { return .ignored(action: nil) }
        // Names compared case-insensitively, as SideStore does.
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value { query[item.name.lowercased()] = value }
        }

        switch action {
        case "install":
            guard let raw = query["url"], let link = Engine.downloadLink(raw) else {
                return .invalid(L("That install link has no .ipa in it. It needs ?url= followed by the https:// address the .ipa downloads from."))
            }
            return .link(.install(link))

        case "pairingfile":
            guard let raw = query["data"], let data = decodeBase64(raw),
                  data.count <= maxPairingFileBytes
            else {
                return .invalid(L("That link was meant to carry a pairing file, but what it holds can't be read."))
            }
            let kind = PairingFileKind.of(data: data)
            guard kind.isUsable else {
                return .invalid(L("That link carries a file, but it isn't a pairing file."))
            }
            return .link(.pairingFile(LinkedPairingFile(data: data, kind: kind,
                                                        fromSideStore: answersSideStore)))

        default:
            return .ignored(action: action)
        }
    }

    /// Base64 as senders actually write it: `+` turned into a space by form
    /// decoding, base64url's `-` and `_`, line breaks, and padding left off.
    static func decodeBase64(_ text: String) -> Data? {
        var cleaned = text.replacingOccurrences(of: " ", with: "+")
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .filter { !$0.isWhitespace }
        guard !cleaned.isEmpty else { return nil }
        let remainder = cleaned.count % 4
        if remainder != 0 { cleaned += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: cleaned)
    }

    /// One line for the log, without the pairing file's contents.
    var logDescription: String {
        switch self {
        case .install(let url):
            return "install \(url.absoluteString)"
        case .pairingFile(let file):
            let records = [file.kind.hasLockdown ? "lockdown" : nil,
                           file.kind.hasRemotePairing ? "remote-pairing" : nil]
                .compactMap { $0 }.joined(separator: " + ")
            return "pairing file\(file.fromSideStore ? " from SideStore" : "") (\(file.data.count) bytes, \(records))"
        }
    }
}

/// A pairing file a link carried, checked and waiting to be imported.
struct LinkedPairingFile: Hashable {
    let data: Data
    let kind: PairingFileKind
    /// True when it came back soon after SideStore was asked for its file.
    let fromSideStore: Bool

    /// The name the Install tab shows for it once imported, as it does a
    /// picked file's.
    var displayName: String {
        fromSideStore ? "SideStore.plist" : "pairingFile.plist"
    }
}
