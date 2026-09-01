import Foundation
import Darwin

/// Detects the loopback tunnel (a `utun*` interface) and Wi-Fi (`en0`) by
/// scanning the active interfaces. A readout only; connecting is the real proof.
enum NetworkStatus {

    struct Interface {
        let name: String
        let ipv4: String
        /// The kernel's netmask, so subnet tests needn't assume a prefix length.
        let netmask: String?
    }

    static func interfaces() -> [Interface] {
        var result: [Interface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: cur.pointee.ifa_name)
            guard let ipv4 = numericHost(addr) else { continue }
            result.append(Interface(name: name, ipv4: ipv4,
                                    netmask: cur.pointee.ifa_netmask.flatMap(numericHost)))
        }
        return result
    }

    private static func numericHost(_ addr: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        // A netmask's sa_len is sometimes short, so size from the family.
        let len = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard getnameinfo(addr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
        else { return nil }
        return String(cString: host)
    }

    /// (vpnUp, wifiUp, detail) for the current interfaces.
    static func summarize(deviceIP: String) -> (vpn: Bool, wifi: Bool, detail: String) {
        let ifs = interfaces()
        let vpn = isLoopbackTunnelUp(in: ifs, deviceIP: deviceIP)
        let wifi = ifs.contains { $0.name == "en0" }
        let detail = ifs.map { "\($0.name)=\($0.ipv4)" }.joined(separator: ", ")
        return (vpn, wifi, detail)
    }

    /// True when a tunnel carries traffic to `deviceIP`. Never equality:
    /// `deviceIP` is the peer, which no interface holds.
    static func loopbackTunnelUp(deviceIP: String) -> Bool {
        isLoopbackTunnelUp(in: interfaces(), deviceIP: deviceIP)
    }

    private static func isLoopbackTunnelUp(in ifs: [Interface], deviceIP: String) -> Bool {
        guard let target = ipv4Value(deviceIP) else {
            // Unparseable target IP — fall back to the broad tunnel-name check.
            return ifs.contains { isTunnelInterface($0.name) }
        }
        // The routing table is the authority; ask it first.
        if tunnelCarriesRoute(to: deviceIP, in: ifs) == true { return true }
        // Then the subnet test, which still answers for tunnels wide enough to
        // hold their peer. Both, since iOS keeps system `utun` interfaces up
        // with no VPN, and a home LAN can share the tunnel's range.
        return ifs.contains { isTunnelInterface($0.name) && subnet($0, contains: target) }
    }

    /// Whether traffic to `deviceIP` would leave through a tunnel interface by
    /// a route of its own. Nil when the routing table can't answer — no route,
    /// or a source address belonging to no interface we can see.
    ///
    /// This, not the interface mask, is the reliable test. A point-to-point
    /// tunnel gives its own end a /32 and reaches the peer over a host route,
    /// so no interface's subnet contains the peer even while the tunnel carries
    /// it perfectly well. LocalDevVPN's 2026-08 rewrite moved to exactly that
    /// shape — `10.7.1.1/32` on the `utun`, peer `10.7.0.1/32` — which the
    /// subnet test alone reads as "no tunnel".
    private static func tunnelCarriesRoute(to deviceIP: String, in ifs: [Interface]) -> Bool? {
        guard let source = routeSource(to: deviceIP),
              let iface = ifs.first(where: { $0.ipv4 == source })
        else { return nil }
        guard isTunnelInterface(iface.name) else { return false }
        // A full-tunnel VPN swallows every address, `deviceIP` included, and so
        // says nothing about a loopback tunnel being up. Only a route more
        // specific than the default one counts.
        return routeSource(to: defaultRouteProbe) != source
    }

    /// TEST-NET-3 (RFC 5737), reserved for documentation: no VPN app routes it
    /// deliberately, so only a default route can claim it. Nothing is ever sent.
    private static let defaultRouteProbe = "203.0.113.1"

    /// The local address the kernel would send from when dialling `ip`, or nil
    /// when it has no route there. A UDP `connect` transmits nothing — it only
    /// resolves the route and selects a source — so this costs no packets.
    private static func routeSource(to ip: String) -> String? {
        var remote = sockaddr_in()
        remote.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        remote.sin_family = sa_family_t(AF_INET)
        remote.sin_port = in_port_t(UInt16(9).bigEndian) // discard, and unused
        guard ip.withCString({ inet_pton(AF_INET, $0, &remote.sin_addr) }) == 1
        else { return nil }

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        let dialled = withUnsafePointer(to: remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard dialled == 0 else { return nil }

        var local = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard named == 0, local.sin_addr.s_addr != 0 else { return nil }
        return withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1, numericHost)
        }
    }

    /// True when `deviceIP` is an address this iPhone holds, always a
    /// misconfiguration: the address to connect to is the tunnel's peer.
    static func isOwnAddress(_ deviceIP: String) -> Bool {
        interfaces().contains { $0.ipv4 == deviceIP }
    }

    /// Local addresses worth dialling when the device opens a tunnel listener
    /// and names a port but no host. Wi-Fi first: the remote-pairing session
    /// itself is established over `en0`, so the listener is reachable there
    /// even when the VPN's subnet forwards the RSD port and nothing else.
    ///
    /// Loopback is left out — the Rust side already tries `127.0.0.1` — and so
    /// are the tunnel interfaces, whose peer address is the one being dialled
    /// first anyway.
    static func tunnelHostCandidates() -> [String] {
        let ifs = interfaces().filter {
            !isTunnelInterface($0.name) && !$0.ipv4.hasPrefix("127.")
        }
        return (ifs.filter { $0.name == "en0" } + ifs.filter { $0.name != "en0" })
            .map(\.ipv4)
    }

    private static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }

    /// Whether `target` is in `interface`'s subnet, assuming /24 without a mask.
    private static func subnet(_ interface: Interface, contains target: UInt32) -> Bool {
        guard let address = ipv4Value(interface.ipv4) else { return false }
        guard let mask = interface.netmask.flatMap(ipv4Value), mask != 0 else {
            return (address & 0xFFFF_FF00) == (target & 0xFFFF_FF00)
        }
        return (address & mask) == (target & mask)
    }

    /// The host part of `value`, dropping any CIDR suffix and surrounding
    /// space. LocalDevVPN has printed its addresses as `10.7.0.1/32` since its
    /// 2026-08 rewrite, so a Device IP copied out of it arrives with a prefix
    /// attached; everything here — and `inet_pton` below us — wants a bare host.
    static func host(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slash = trimmed.firstIndex(of: "/") else { return trimmed }
        return String(trimmed[..<slash]).trimmingCharacters(in: .whitespaces)
    }

    /// `"10.7.0.1"` -> `0x0A070001`. Nil if `ip` isn't a dotted quad.
    private static func ipv4Value(_ ip: String) -> UInt32? {
        let octets = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }
        var value: UInt32 = 0
        for octet in octets {
            guard let byte = UInt8(octet) else { return nil }
            value = (value << 8) | UInt32(byte)
        }
        return value
    }
}
