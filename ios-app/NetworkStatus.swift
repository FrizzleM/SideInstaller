import Foundation
import Darwin

/// Best-effort detection of the LocalDevVPN loopback + Wi-Fi by scanning the
/// active network interfaces. LocalDevVPN brings up a `utun*` tunnel interface;
/// Wi-Fi is `en0`. This is a quick readout — the real proof is whether the
/// lockdown connection succeeds.
enum NetworkStatus {

    struct Interface {
        let name: String
        let ipv4: String
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

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let r = getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                &host, socklen_t(host.count),
                                nil, 0, NI_NUMERICHOST)
            guard r == 0 else { continue }
            result.append(Interface(name: name, ipv4: String(cString: host)))
        }
        return result
    }

    /// (vpnUp, wifiUp, detail) — vpnUp when the LocalDevVPN loopback tunnel is up
    /// for the given `deviceIP` (see `localDevVPNUp`).
    static func summarize(deviceIP: String) -> (vpn: Bool, wifi: Bool, detail: String) {
        let ifs = interfaces()
        let vpn = isLocalDevVPNUp(in: ifs, deviceIP: deviceIP)
        let wifi = ifs.contains { $0.name == "en0" }
        let detail = ifs.map { "\($0.name)=\($0.ipv4)" }.joined(separator: ", ")
        return (vpn, wifi, detail)
    }

    /// True when LocalDevVPN's loopback tunnel is up: some interface holds an
    /// IPv4 in the same /24 as `deviceIP`. LocalDevVPN's default is `10.7.0.0/24`
    /// (device side `10.7.0.0`, peer `10.7.0.1` — the address we connect to), so
    /// the device gains a `utun*` address in that subnet while it's connected.
    ///
    /// Scoping to the subnet — rather than matching any `utun*` — is what makes
    /// this reliable: iOS keeps system `utun` interfaces around (Handoff, Wi-Fi
    /// calling, …) even with no VPN, so a bare name check yields false positives.
    static func localDevVPNUp(deviceIP: String) -> Bool {
        isLocalDevVPNUp(in: interfaces(), deviceIP: deviceIP)
    }

    private static func isLocalDevVPNUp(in ifs: [Interface], deviceIP: String) -> Bool {
        guard let prefix = subnetPrefix24(deviceIP) else {
            // Unparseable target IP — fall back to the broad tunnel-name check.
            return ifs.contains { isTunnelInterface($0.name) }
        }
        return ifs.contains { $0.ipv4.hasPrefix(prefix) }
    }

    private static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }

    /// `"10.7.0.1"` -> `"10.7.0."` — the first three octets plus a trailing dot,
    /// for /24 membership tests via `hasPrefix`. The trailing dot keeps `10.7.0.`
    /// from matching `10.7.0X` (e.g. `10.70.0.5`). nil if `ip` isn't dotted-quad.
    private static func subnetPrefix24(_ ip: String) -> String? {
        let octets = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4, octets.allSatisfy({ UInt8($0) != nil }) else { return nil }
        return octets.prefix(3).joined(separator: ".") + "."
    }
}
