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
    /// its operator has said he'll keep running.
    ///
    /// Not his macOS-ADI server, which iLoader defaults to since 2.3.9: through
    /// the macOS servers Apple has asked an account with trusted devices for a
    /// code by text and then refused to send one (see `candidates`).
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
        AnisetteServer(name: "SideStore (New)",           address: "https://new.ani.sidestore.io"),
        AnisetteServer(name: "SideStore (Windows ADI)",   address: "https://win.ani.sidestore.io"),
        AnisetteServer(name: "jkcoxson",                  address: "https://mac-ani.jkcoxson.com"),
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

    // MARK: - ADI libraries

    /// The Apple ADI library a server makes its anisette data with. An
    /// anisette identity provisioned through one server works with every
    /// server on the same library, and the others refuse it (-45061), so
    /// isideload keeps one per library (`anisette_slots.json`).
    enum ADILibrary {
        /// macOS's, the one Xcode signs in with. These servers name the Mac
        /// they run as, and sign-in reports that Mac.
        case mac
        /// Windows's, as iTunes and iCloud for Windows use it. These servers
        /// name a Windows PC, and sign-in reports it.
        case windows
        /// Android's, which every older community server runs. Those servers
        /// name a stock Mac, which Apple refuses, so sign-in reports a Windows
        /// PC instead (isideload's `client_info_to_use`): Apple has let that
        /// pass since it blocked the Android phone (2026-10-15), and may stop.
        case android

        /// The device sign-in reports to Apple through a server on this
        /// library. Apple's HTTP 503 refusals have gone by it, whatever the
        /// server.
        var client: Client { self == .mac ? .mac : .windows }

        enum Client { case mac, windows }
    }

    /// Hosts of the servers known to run Apple's macOS ADI library. They name
    /// `<MacBookPro13,3> <Mac OS X;10.12.6;16G29>` and take each other's
    /// identities (checked 2026-10-16).
    static let macADIHosts: Set<String> = ["mac-ani.jkcoxson.com", "new.ani.sidestore.io"]

    /// Hosts of the servers known to run Apple's Windows ADI library.
    static let windowsADIHosts: Set<String> = ["ani.jkcoxson.com", "win.ani.sidestore.io", "ani2.stikstore.app"]

    /// The library `address` runs: a known host's, else what the list's name
    /// for it says ("… (Windows ADI)", "… (Mac ADI)"), else Android's.
    static func library(of address: String, in servers: [AnisetteServer] = bundledDefaults) -> ADILibrary {
        let key = normalized(address)
        if let host = URL(string: key)?.host?.lowercased() {
            if macADIHosts.contains(host) { return .mac }
            if windowsADIHosts.contains(host) { return .windows }
        }
        let name = servers.first { normalized($0.address) == key }?.name.lowercased() ?? ""
        if name.contains("mac adi") { return .mac }
        if name.contains("windows") { return .windows }
        return .android
    }

    // MARK: - Order of servers to sign in through

    /// Addresses to sign in through with Auto on, de-duplicated and most likely
    /// to work first: `pick` (the last one that signed in) first, then the rest
    /// of its library unless that is Android's, then the Windows-ADI servers,
    /// then the Android ones in list order, then the macOS ones. Within each of
    /// those groups, the servers in `failing` (`RecentFailures`) go last.
    ///
    /// The pick keeps its anisette identity, and with it the saved developer
    /// token and Apple's trust in that machine, and so do the servers on its
    /// library. The Windows servers come before the Android ones because on
    /// them the Windows PC sign-in reports is the machine the data comes
    /// from: the way Apple most likely closes next is the one where it isn't.
    /// The macOS servers come last: through them Apple took the password of a
    /// real account with trusted devices (2026-10-16), then asked for a code by
    /// text instead of sending one to the devices, and answered the request for
    /// it with HTTP 403, as iLoader 2.3.9's users reported the same day. Apple
    /// refusing one reported device doesn't end the sign-in while servers
    /// reporting the other are left (`AppleRefusals`).
    ///
    /// A server that just failed by itself is most often down, and the others
    /// of its group are as likely as it was otherwise, so it waits behind them.
    /// It stays in its group: moving to another library makes a new identity,
    /// which costs a second factor, and its servers are less likely to work.
    static func candidates(pick: String, servers: [AnisetteServer],
                           failing: Set<String> = []) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        func add(_ group: [String]) {
            var failed: [String] = []
            for address in group {
                let a = address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !a.isEmpty, seen.insert(normalized(a)).inserted else { continue }
                if failing.contains(normalized(a)) { failed.append(a) } else { out.append(a) }
            }
            out += failed
        }
        let addresses = servers.map(\.address)
        let pickLibrary = library(of: pick, in: servers)
        add([pick] + (pickLibrary == .android ? []
                      : addresses.filter { library(of: $0, in: servers) == pickLibrary }))
        add(addresses.filter { library(of: $0, in: servers) == .windows })
        add(addresses.filter { library(of: $0, in: servers) != .mac })
        add(addresses)
        return out
    }

    /// Servers that failed a sign-in by themselves lately, kept across launches
    /// so Auto tries them after the others of their group (`candidates`).
    /// A failure is forgotten when the server next signs in, or after `window`.
    enum RecentFailures {
        private static let key = "anisetteServerFailures"
        /// How long a failure keeps a server back. Servers that go down often
        /// come back within hours.
        static let window: TimeInterval = 12 * 60 * 60

        /// The normalized addresses of the servers still held back.
        static func addresses(now: Date = Date()) -> Set<String> {
            Set(stored().filter { now.timeIntervalSince1970 - $0.value < window }.keys)
        }

        /// Notes that a sign-in through `address` failed with `error`, if the
        /// error came from the server: Apple refusing, limiting or not being
        /// reached would have failed through any server.
        static func record(_ address: String, error: String, now: Date = Date()) {
            guard isServerFault(error) else { return }
            var failures = stored().filter { now.timeIntervalSince1970 - $0.value < window }
            failures[AnisetteServer.normalized(address)] = now.timeIntervalSince1970
            UserDefaults.standard.set(failures, forKey: key)
        }

        /// Forgets a failure of `address`, once it has signed in.
        static func clear(_ address: String) {
            var failures = stored()
            guard failures.removeValue(forKey: AnisetteServer.normalized(address)) != nil else { return }
            UserDefaults.standard.set(failures, forKey: key)
        }

        /// Whether a sign-in error is the anisette server's own: isideload names
        /// the server in every error about it ("Failed to get anisette headers",
        /// "The anisette server refused …", "Anisette provisioning timed out").
        static func isServerFault(_ error: String) -> Bool {
            error.lowercased().contains("anisette")
                && !Engine.isAppleServiceRefusal(error)
                && !Engine.isAppleRateLimit(error)
                && !Engine.isAppleUnreachable(error)
        }

        private static func stored() -> [String: Double] {
            UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        }
    }

    /// `addresses` on the same ADI library as the first of them, in order:
    /// the servers that can use the anisette identity the first one used.
    static func sameLibrary(asFirstOf addresses: [String], in servers: [AnisetteServer]) -> [String] {
        guard let first = addresses.first else { return [] }
        let kind = library(of: first, in: servers)
        return addresses.filter { library(of: $0, in: servers) == kind }
    }

    /// Apple's HTTP 503 refusals during one sign-in loop, counted by the
    /// device sign-in reported (`ADILibrary.client`).
    ///
    /// Apple refuses a reported device the same through every server, so once
    /// it has refused one twice the servers left that report it are skipped.
    /// One refusal only moves on to the next server, since Apple has also sent
    /// a 503 that passed on retry. The loop stops when every server left
    /// reports a device refused twice.
    struct AppleRefusals {
        private let servers: [AnisetteServer]
        private var byClient: [ADILibrary.Client: Int] = [:]
        /// Refusals so far.
        private(set) var count = 0

        init(servers: [AnisetteServer]) { self.servers = servers }

        /// Counts a refusal of the attempt through `address`.
        mutating func record(_ address: String) {
            count += 1
            byClient[AnisetteServer.library(of: address, in: servers).client, default: 0] += 1
        }

        /// Whether a sign-in through `address` would report a device Apple
        /// has refused twice already.
        func rulesOut(_ address: String) -> Bool {
            byClient[AnisetteServer.library(of: address, in: servers).client, default: 0] >= 2
        }

        /// Whether, after a refusal, the sign-in should stop: at least two
        /// refusals, and none of `remaining` worth trying.
        func endsSignIn(remaining: ArraySlice<String>) -> Bool {
            count >= 2 && remaining.allSatisfy(rulesOut)
        }
    }

    private static func normalized(_ address: String) -> String {
        var a = address.trimmingCharacters(in: .whitespacesAndNewlines)
        while a.hasSuffix("/") { a.removeLast() }
        return a.lowercased()
    }
}
