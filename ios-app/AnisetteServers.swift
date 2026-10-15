import Foundation

/// One server from the community list, serving the device-attestation data
/// Apple's auth endpoints require.
struct AnisetteServer: Identifiable, Hashable, Decodable {
    let name: String
    let address: String

    /// Identified by address.
    var id: String { address }
}

extension AnisetteServer {
    /// The public list SideStore and iLoader read from.
    private static let listURL = URL(string: "https://servers.sidestore.io/servers.json")!

    private struct ServerList: Decodable {
        let servers: [AnisetteServer]
    }

    /// The default server for a first sign-in, and the fallback when a saved
    /// one can't be honoured: jkcoxson's, on Apple's Windows ADI library, which
    /// iLoader also defaults to and which its operator has said he'll keep
    /// running.
    static let fallback = AnisetteServer(name: "jkcoxson (Windows ADI)", address: "https://ani.jkcoxson.com")

    /// The default until 1.5.2, on Apple's Android ADI library. It wasn't
    /// saved while it stayed the default, so it's what anyone who signed in
    /// with an unsaved pick signed in through (see `Engine.savedAnisetteURL`).
    static let legacyDefault = AnisetteServer(name: "SideStore", address: "https://ani.sidestore.io")

    /// Servers on Apple's Windows ADI library that aren't on the community
    /// list, added to it. iLoader lists this one next to jkcoxson's.
    static let extras: [AnisetteServer] = [
        AnisetteServer(name: "StikStore (Windows ADI)", address: "https://ani2.stikstore.app"),
    ]

    /// Snapshot of the community list, shown on launch and used when the live
    /// list can't be fetched.
    static let bundledDefaults: [AnisetteServer] = [
        AnisetteServer(name: "SideStore",                 address: "https://ani.sidestore.io"),
        AnisetteServer(name: "SideStore (.app)",          address: "https://ani.sidestore.app"),
        AnisetteServer(name: "SideStore (.zip)",          address: "https://ani.sidestore.zip"),
        AnisetteServer(name: "SideStore (.xyz)",          address: "https://ani.846969.xyz"),
        AnisetteServer(name: "SideStore (Windows ADI)",   address: "https://win.ani.sidestore.io"),
        AnisetteServer(name: "jkcoxson (Windows ADI)",    address: "https://ani.jkcoxson.com"),
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
        AnisetteServer(name: "ethxn's omnisette server :3", address: "https://omni.ethxn.xyz"),
    ] + extras

    /// Fetch the live list, throwing so the caller can keep the bundled one.
    static func fetchList() async throws -> [AnisetteServer] {
        var req = URLRequest(url: listURL)
        req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        let servers = try JSONDecoder().decode(ServerList.self, from: data).servers
        return servers + extras.filter { extra in
            !servers.contains { normalized($0.address) == normalized(extra.address) }
        }
    }

    // MARK: - Order of servers to sign in through

    /// Hosts of the servers known to make anisette data with Apple's Windows
    /// ADI library. Sign-in tells Apple the client is a Windows PC through
    /// every server; only on these does that match the machine the data comes
    /// from. The others run Apple's Android library, which Apple has let pass
    /// with a Windows PC's client info since it blocked the Android phone
    /// (2026-10-15), and may stop letting pass. The two kinds keep separate
    /// anisette identities (isideload's `anisette_slots.json`).
    static let windowsADIHosts: Set<String> = ["ani.jkcoxson.com", "win.ani.sidestore.io", "ani2.stikstore.app"]

    /// Whether `address` is a server on the Windows ADI library: a known host,
    /// or one the list names as such ("… (Windows ADI)").
    static func isWindowsADI(_ address: String, in servers: [AnisetteServer] = bundledDefaults) -> Bool {
        let key = normalized(address)
        if let host = URL(string: key)?.host?.lowercased(), windowsADIHosts.contains(host) {
            return true
        }
        return servers.contains { normalized($0.address) == key && $0.name.lowercased().contains("windows") }
    }

    /// Addresses to sign in through, de-duplicated: `pick` (the one in use)
    /// first, then the Windows-ADI servers, then the rest in list order.
    ///
    /// The pick keeps its anisette identity, and with it the saved developer
    /// token and Apple's trust in that machine. Windows-ADI servers come next
    /// because the way Apple most likely closes next is the one where the
    /// client info doesn't match the library: a server on the same library
    /// as a refused pick would be refused the same way, and the sign-in loop
    /// stops after a second HTTP 503.
    static func candidates(pick: String, servers: [AnisetteServer]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        func add(_ address: String) {
            let a = address.trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty, seen.insert(normalized(a)).inserted { out.append(a) }
        }
        add(pick)
        let addresses = servers.map(\.address)
        addresses.filter { isWindowsADI($0, in: servers) }.forEach(add)
        addresses.forEach(add)
        return out
    }

    /// `addresses` on the same ADI library as the first of them, in order:
    /// the servers that can use the anisette identity the first one used.
    static func sameLibrary(asFirstOf addresses: [String], in servers: [AnisetteServer]) -> [String] {
        guard let first = addresses.first else { return [] }
        let windows = isWindowsADI(first, in: servers)
        return addresses.filter { isWindowsADI($0, in: servers) == windows }
    }

    private static func normalized(_ address: String) -> String {
        var a = address.trimmingCharacters(in: .whitespacesAndNewlines)
        while a.hasSuffix("/") { a.removeLast() }
        return a.lowercased()
    }
}
