import Foundation

/// One anisette server the user can pick from. Anisette servers hand back the
/// device-attestation data Apple's auth endpoints require; SideStore and iLoader
/// both let the user choose one from a shared, community-maintained list instead
/// of typing a URL by hand. We consume that same list here.
struct AnisetteServer: Identifiable, Hashable, Decodable {
    let name: String
    let address: String

    /// The address doubles as the identity — it's what we feed the sign-in call
    /// and what the picker tags its rows with.
    var id: String { address }
}

extension AnisetteServer {
    /// The public list SideStore/iLoader read from. Shape:
    /// `{ "servers": [ { "name": ..., "address": ... } ], "cache": "…" }`.
    private static let listURL = URL(string: "https://servers.sidestore.io/servers.json")!

    private struct ServerList: Decodable {
        let servers: [AnisetteServer]
    }

    /// The server selected by default, and the one we fall back to whenever a
    /// fetched/saved value can't be honoured.
    static let fallback = AnisetteServer(name: "SideStore", address: "https://ani.sidestore.io")

    /// Bundled snapshot of the community list, shown immediately on launch and
    /// used whenever the live list can't be fetched (offline, server down, …).
    /// Kept in sync by occasionally refreshing from `listURL`.
    static let bundledDefaults: [AnisetteServer] = [
        AnisetteServer(name: "SideStore",                 address: "https://ani.sidestore.io"),
        AnisetteServer(name: "SideStore (.app)",          address: "https://ani.sidestore.app"),
        AnisetteServer(name: "SideStore (.zip)",          address: "https://ani.sidestore.zip"),
        AnisetteServer(name: "SideStore (.xyz)",          address: "https://ani.846969.xyz"),
        AnisetteServer(name: "nythepegasus",              address: "https://ani.npeg.us"),
        AnisetteServer(name: "Macley",                    address: "http://5.249.163.88:6969"),
        AnisetteServer(name: "WE. Studio",                address: "https://anisette.wedotstud.io"),
        AnisetteServer(name: "SteX",                      address: "https://ani.xu30.top"),
        AnisetteServer(name: "owoellen",                  address: "https://ani.owoellen.rocks"),
        AnisetteServer(name: "iDH Server",                address: "https://ani.idevicehacked.com"),
        AnisetteServer(name: "neoarz",                    address: "https://ani.neoarz.com"),
        AnisetteServer(name: "pythonplayer123",           address: "https://ani3server.fly.dev"),
        AnisetteServer(name: "Jayden's Server",           address: "https://ani.jaydenha.uk"),
        AnisetteServer(name: "crystall1nedev's server",   address: "https://anisette.crystall1ne.dev"),
    ]

    /// Fetch the live list. Throws on any network/decoding failure so the caller
    /// can keep showing `bundledDefaults`.
    static func fetchList() async throws -> [AnisetteServer] {
        var req = URLRequest(url: listURL)
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(ServerList.self, from: data).servers
    }
}
