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

    /// True when a tunnel interface's subnet contains `deviceIP`. Tested by
    /// subnet, not equality: `deviceIP` is the peer, which no interface holds.
    static func loopbackTunnelUp(deviceIP: String) -> Bool {
        isLoopbackTunnelUp(in: interfaces(), deviceIP: deviceIP)
    }

    private static func isLoopbackTunnelUp(in ifs: [Interface], deviceIP: String) -> Bool {
        guard let target = ipv4Value(deviceIP) else {
            // Unparseable target IP — fall back to the broad tunnel-name check.
            return ifs.contains { isTunnelInterface($0.name) }
        }
        // Both, since iOS keeps system `utun` interfaces up with no VPN, and a
        // home LAN can share the tunnel's range.
        return ifs.contains { isTunnelInterface($0.name) && subnet($0, contains: target) }
    }

    /// True when `deviceIP` is an address this iPhone holds, always a
    /// misconfiguration: the address to connect to is the tunnel's peer.
    static func isOwnAddress(_ deviceIP: String) -> Bool {
        interfaces().contains { $0.ipv4 == deviceIP }
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
