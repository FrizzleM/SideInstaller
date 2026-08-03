import Foundation
import Darwin

/// Best-effort detection of the loopback tunnel + Wi-Fi by scanning the active
/// network interfaces. A loopback VPN brings up a `utun*` tunnel interface;
/// Wi-Fi is `en0`. This is a quick readout — the real proof is whether the
/// lockdown connection succeeds.
enum NetworkStatus {

    struct Interface {
        let name: String
        let ipv4: String
        /// The interface's own netmask, when the kernel reported one. Used to
        /// test subnet membership properly instead of assuming a prefix length.
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
        // A netmask's sa_len is sometimes reported short; size from the family
        // instead so getnameinfo doesn't reject an otherwise valid mask.
        let len = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard getnameinfo(addr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
        else { return nil }
        return String(cString: host)
    }

    /// (vpnUp, wifiUp, detail) — vpnUp when a loopback tunnel to `deviceIP` is
    /// up (see `loopbackTunnelUp`).
    static func summarize(deviceIP: String) -> (vpn: Bool, wifi: Bool, detail: String) {
        let ifs = interfaces()
        let vpn = isLoopbackTunnelUp(in: ifs, deviceIP: deviceIP)
        let wifi = ifs.contains { $0.name == "en0" }
        let detail = ifs.map { "\($0.name)=\($0.ipv4)" }.joined(separator: ", ")
        return (vpn, wifi, detail)
    }

    /// True when the loopback tunnel is up: a tunnel interface exists whose own
    /// subnet contains `deviceIP` — that is, traffic to the address we're about
    /// to connect to would actually be routed into that tunnel.
    ///
    /// The convention is `10.7.0.0/24`: the tunnel interface takes `10.7.0.0`
    /// and the address we connect to is the peer `10.7.0.1`, which no interface
    /// holds — the VPN app rewrites packets addressed to it back to the local
    /// side. So the test can't look for `deviceIP` itself; it has to ask which
    /// interface would carry traffic to it.
    ///
    /// Testing the subnet is also what keeps this app-agnostic: nothing here
    /// asks *which* VPN client put the address there, so LocalDevVPN, ClashMi or
    /// anything else that exposes the same loopback all read as connected.
    ///
    /// Using the interface's real netmask rather than assuming a /24 is what
    /// makes it survive a reconfigured tunnel. LocalDevVPN exposes the tunnel
    /// IP, device IP *and* subnet mask as editable settings, and it only routes
    /// its own configured subnet — so "is `deviceIP` inside this interface's
    /// subnet?" is exactly the question that decides whether the connection can
    /// work, at whatever mask the user chose.
    static func loopbackTunnelUp(deviceIP: String) -> Bool {
        isLoopbackTunnelUp(in: interfaces(), deviceIP: deviceIP)
    }

    private static func isLoopbackTunnelUp(in ifs: [Interface], deviceIP: String) -> Bool {
        guard let target = ipv4Value(deviceIP) else {
            // Unparseable target IP — fall back to the broad tunnel-name check.
            return ifs.contains { isTunnelInterface($0.name) }
        }
        // Both conditions together. The name alone yields false positives — iOS
        // keeps system `utun` interfaces around for Handoff, Wi-Fi calling and
        // the like even with no VPN. The subnet alone yields a false positive
        // for anyone whose Wi-Fi LAN happens to use the same range as the
        // tunnel, which for `10.7.0.0/24` is an ordinary enough home network.
        return ifs.contains { isTunnelInterface($0.name) && subnet($0, contains: target) }
    }

    /// True when `deviceIP` is an address this iPhone itself holds.
    ///
    /// Always a misconfiguration: the address to connect to is the tunnel's
    /// *peer*, which by construction is not assigned to any local interface. It
    /// is an easy mistake to make, because LocalDevVPN's main screen reports
    /// "connected to 10.7.0.0" — its tunnel-side address — while the address to
    /// put here is the 10.7.0.1 shown under Settings › Device IP. Typing the one
    /// on the status line gives a tunnel that reads as up and a connection that
    /// can never complete, so it's worth naming rather than leaving to a timeout.
    static func isOwnAddress(_ deviceIP: String) -> Bool {
        interfaces().contains { $0.ipv4 == deviceIP }
    }

    private static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }

    /// Whether `target` falls inside `interface`'s subnet. Falls back to a /24
    /// comparison when the kernel gave us no usable netmask.
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
