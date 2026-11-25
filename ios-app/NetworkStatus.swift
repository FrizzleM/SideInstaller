import Foundation
import Darwin
import Network

/// Detects the loopback tunnel (a `utun*` interface) and Wi-Fi (`en0`) by
/// scanning the active interfaces and asking the routing table. The answer
/// gates Install, the Pairing and Location pages, and whether LocalDevVPN is
/// started, though a successful connect is still the real test.
///
/// The route to Device IP is one of three kinds (`TunnelRoute`):
/// (a) a tunnel's own route, as LocalDevVPN sets up: the tunnel is up;
/// (b) no tunnel, or a route the table can't tell: down, unless a tunnel
///     interface's subnet holds Device IP;
/// (c) a tunnel that also carries the default route, a full-tunnel VPN. Some
///     (ClashMi, Shadowrocket and other proxy VPNs, with a direct rule) loop
///     Device IP back to this iPhone and most don't, so the subnet test is
///     tried and then a probe: a TCP connect to Device IP's RSD port
///     (`probeConnect`). Engine runs and caches it, never on the main thread.
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

    /// How traffic to Device IP leaves this iPhone.
    enum TunnelRoute: Equatable {
        /// (a) Through a tunnel interface, on a route of its own: a loopback
        /// VPN such as LocalDevVPN is on.
        case dedicated
        /// (b) Not through a tunnel interface, or the routing table can't tell.
        case other
        /// (c) Through a tunnel interface that also carries the default route:
        /// a full-tunnel VPN, which may or may not loop Device IP back.
        case fullTunnel(interface: String, source: String)
    }

    /// What a probe of Device IP through a full-tunnel VPN found.
    enum ProbeResult: Equatable, CustomStringConvertible {
        case connected
        /// Something answered with a reset (ECONNREFUSED): the device is there
        /// but not listening on that port, as `DeviceConnection.wasRefused`
        /// assumes too.
        case refused
        case timedOut
        case failed(errno: Int32)

        /// True when something on the far end answered, so the VPN carries
        /// Device IP back to this iPhone.
        var answered: Bool { self == .connected || self == .refused }

        var description: String {
            switch self {
            case .connected: return "connected"
            case .refused: return "refused"
            case .timedOut: return "timed out"
            case .failed(let code): return "error \(code)"
            }
        }
    }

    /// A full-tunnel VPN that only a probe can judge, and where to probe.
    struct ProbeTarget: Equatable {
        /// Device IP, as dialled.
        let deviceIP: String
        /// The tunnel interface, e.g. `utun4`.
        let interface: String
        /// The tunnel's own address, which changes with the VPN.
        let source: String

        /// What a cached answer is kept under: a new Device IP or another VPN
        /// makes it stale.
        var key: String { "\(deviceIP) via \(source)" }
    }

    /// One look at the interfaces and the routes.
    struct Scan {
        let route: TunnelRoute
        /// The fallback test passed: a tunnel interface's subnet holds Device
        /// IP, or, when Device IP isn't an IPv4 address, any tunnel is up.
        let fallbackMatch: Bool
        let wifi: Bool
        let detail: String
        /// Set only in case (c) when the fallback test failed: the one case a
        /// probe decides.
        let probeTarget: ProbeTarget?
    }

    static func scan(deviceIP: String) -> Scan {
        let ifs = interfaces()
        let (route, fallbackMatch) = tunnelRoute(in: ifs, deviceIP: deviceIP)
        var probeTarget: ProbeTarget?
        if case .fullTunnel(let interface, let source) = route, !fallbackMatch {
            probeTarget = ProbeTarget(deviceIP: deviceIP, interface: interface, source: source)
        }
        return Scan(route: route,
                    fallbackMatch: fallbackMatch,
                    wifi: ifs.contains { $0.name == "en0" },
                    detail: ifs.map { "\($0.name)=\($0.ipv4)" }.joined(separator: ", "),
                    probeTarget: probeTarget)
    }

    /// Whether the loopback tunnel counts as up, from the route to Device IP,
    /// the subnet fallback, and, for a full-tunnel VPN, a probe (nil while
    /// none has answered). Pure, so the rules are easy to test.
    static func tunnelIsUp(route: TunnelRoute, fallbackMatch: Bool, probe: ProbeResult?) -> Bool {
        switch route {
        case .dedicated: return true
        case .other: return fallbackMatch
        case .fullTunnel: return fallbackMatch || probe?.answered == true
        }
    }

    /// True when a tunnel carries traffic to `deviceIP`, without probing: a
    /// full-tunnel VPN counts only when its subnet holds `deviceIP`. Never
    /// equality: `deviceIP` is the peer, which no interface holds.
    static func loopbackTunnelUp(deviceIP: String) -> Bool {
        let (route, fallbackMatch) = tunnelRoute(in: interfaces(), deviceIP: deviceIP)
        return tunnelIsUp(route: route, fallbackMatch: fallbackMatch, probe: nil)
    }

    private static func tunnelRoute(in ifs: [Interface],
                                    deviceIP: String) -> (route: TunnelRoute, fallbackMatch: Bool) {
        guard let target = ipv4Value(deviceIP) else {
            // Unparseable target IP — fall back to the broad tunnel-name check.
            return (.other, ifs.contains { isTunnelInterface($0.name) })
        }
        // The routing table is the authority; ask it first.
        let route = tunnelRoute(to: deviceIP, in: ifs)
        // Fall back to a subnet check on tunnel interfaces only: iOS keeps system
        // `utun`s up without a VPN, and a home LAN can overlap the tunnel's range.
        let fallbackMatch = route != .dedicated
            && ifs.contains { isTunnelInterface($0.name) && subnet($0, contains: target) }
        return (route, fallbackMatch)
    }

    /// Which kind of route carries traffic to `deviceIP` (see `TunnelRoute`).
    ///
    /// More reliable than a subnet check: point-to-point tunnels (e.g.
    /// LocalDevVPN's `10.7.1.1/32` with peer `10.7.0.1/32`) reach the peer over a
    /// host route, so no interface's subnet contains it.
    private static func tunnelRoute(to deviceIP: String, in ifs: [Interface]) -> TunnelRoute {
        guard let source = routeSource(to: deviceIP),
              let iface = ifs.first(where: { $0.ipv4 == source })
        else { return .other }
        guard isTunnelInterface(iface.name) else { return .other }
        // A full-tunnel VPN routes every address, so a tunnel only counts by
        // itself when `deviceIP` uses a different route than the default.
        if routeSource(to: defaultRouteProbe) != source { return .dedicated }
        return .fullTunnel(interface: iface.name, source: source)
    }

    /// Whether `host:port` answers through the current route: opens a TCP
    /// connection, waits up to `timeout` milliseconds, and closes it without
    /// sending anything. Blocks the calling thread for up to `timeout`, so
    /// only `probe(host:port:)` calls it.
    ///
    /// Some proxy TUN stacks (Mihomo's gVisor mode, for one) accept every TCP
    /// connection themselves, so they read as up here and fail later at the
    /// real connection, with the usual “couldn't reach the device” error.
    static func probeConnect(host: String, port: UInt16, timeout: Int32 = 500) -> ProbeResult {
        var remote = sockaddr_in()
        remote.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        remote.sin_family = sa_family_t(AF_INET)
        remote.sin_port = in_port_t(port.bigEndian)
        guard host.withCString({ inet_pton(AF_INET, $0, &remote.sin_addr) }) == 1
        else { return .failed(errno: EINVAL) }

        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return .failed(errno: errno) }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0
        else { return .failed(errno: errno) }

        let dialled = withUnsafePointer(to: remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if dialled == 0 { return .connected }
        switch errno {
        case EINPROGRESS: break
        case ECONNREFUSED: return .refused
        case let code: return .failed(errno: code)
        }

        // Wait for the handshake to finish, one way or the other.
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeout) * 1_000_000
        var poller = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        while true {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else { return .timedOut }
            let ready = poll(&poller, 1, Int32((deadline - now) / 1_000_000))
            if ready > 0 { break }
            if ready == 0 { return .timedOut }
            guard errno == EINTR else { return .failed(errno: errno) }
        }
        var outcome: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &outcome, &length) == 0
        else { return .failed(errno: errno) }
        switch outcome {
        case 0: return .connected
        case ECONNREFUSED: return .refused
        default: return .failed(errno: outcome)
        }
    }

    /// `probeConnect` on a background queue, so no caller's thread waits on it.
    static func probe(host: String, port: UInt16) async -> ProbeResult {
        await withCheckedContinuation { continuation in
            probeQueue.async {
                continuation.resume(returning: probeConnect(host: host, port: port))
            }
        }
    }

    private static let probeQueue = DispatchQueue(label: "sideinstaller.tunnel-probe",
                                                  qos: .utility)

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

    /// Extra local addresses to try when the device's tunnel listener gives a
    /// port but no host. Wi-Fi (`en0`) first, since remote pairing runs over it.
    /// Loopback and tunnel interfaces are excluded; they're already tried.
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

    /// The host part of `value`, without whitespace or a CIDR suffix
    /// (`10.7.0.1/32` → `10.7.0.1`). LocalDevVPN shows addresses with the suffix.
    static func host(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slash = trimmed.firstIndex(of: "/") else { return trimmed }
        return String(trimmed[..<slash]).trimmingCharacters(in: .whitespaces)
    }

    /// This app's internet path as iOS sees it now. It's evaluated per app, so
    /// it shows what fails every request without the request saying why:
    /// Cellular Data or Wireless Data switched off for SideInstaller, or a VPN
    /// holding traffic back while it's down.
    static func internetPath() async -> NWPath {
        let monitor = NWPathMonitor()
        let (paths, continuation) = AsyncStream.makeStream(of: NWPath.self)
        monitor.pathUpdateHandler = { continuation.yield($0) }
        monitor.start(queue: DispatchQueue(label: "sideinstaller.internet-path"))
        defer {
            monitor.cancel()
            continuation.finish()
        }
        // The monitor reports the current path as soon as it starts.
        for await path in paths { return path }
        return monitor.currentPath
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

// MARK: - This iPhone's remote pairing listener

extension NetworkStatus {

    /// What a look for this iPhone's `_remotepairing._tcp` advertisement found.
    struct PairingAdvert {
        /// The port this iPhone advertises, nil when none was seen.
        let port: UInt16?
        /// What was seen, for the log.
        let summary: String
    }

    /// Looks for the `_remotepairing._tcp` service this iPhone advertises: the
    /// listener `tunnel_create_rppairing` dials. Its port is whatever the
    /// listener got when it started. That's 49152 (`DeviceConnection.rsdPort`),
    /// the first port iOS hands out, as long as nothing took it first, which
    /// can't be counted on: on a Mac it's rapportd's. Other iPhones on the
    /// network advertise the same service, so only one resolving to an address
    /// this iPhone holds counts.
    ///
    /// Blocks for up to `timeout`. The browse runs on the main run loop, so
    /// never call this on the main thread.
    static func ownRemotePairingAdvert(timeout: TimeInterval = 3) -> PairingAdvert {
        precondition(!Thread.isMainThread, "the browse needs the main run loop")
        let finder = RemotePairingAdvertFinder(ownAddresses: ownAddresses())
        DispatchQueue.main.async { finder.start() }
        let advert = finder.wait(timeout: timeout)
        DispatchQueue.main.async { finder.stop() }
        return advert
    }

    /// Every address this iPhone holds, IPv4 and IPv6, without a scope suffix.
    static func ownAddresses() -> Set<String> {
        var result = Set<String>()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return result }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr,
                  let host = numericHost(addr, length: socklen_t(addr.pointee.sa_len)) else { continue }
            result.insert(host)
        }
        return result
    }

    /// `addr` as a numeric address, without a `%scope` suffix; nil for a
    /// family other than IPv4 or IPv6.
    static func numericHost(_ addr: UnsafePointer<sockaddr>, length: socklen_t) -> String? {
        let family = Int32(addr.pointee.sa_family)
        guard family == AF_INET || family == AF_INET6 else { return nil }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(addr, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
        else { return nil }
        return String(cString: host).split(separator: "%").first.map(String.init)
    }
}

/// Browses `_remotepairing._tcp` and resolves each service found until one
/// resolves to an address this iPhone holds. Used from the main thread, except
/// `wait`.
private final class RemotePairingAdvertFinder: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {

    private let ownAddresses: Set<String>
    private let browser = NetServiceBrowser()
    /// Held while they resolve, or they'd go away.
    private var services: [NetService] = []
    private var othersResolved = 0
    private let lock = NSLock()
    private var found: NetworkStatus.PairingAdvert?
    private let done = DispatchSemaphore(value: 0)

    init(ownAddresses: Set<String>) {
        self.ownAddresses = ownAddresses
    }

    func start() {
        browser.delegate = self
        // Common modes, so a scroll doesn't hold the callbacks back.
        browser.remove(from: .main, forMode: .default)
        browser.schedule(in: .main, forMode: .common)
        browser.searchForServices(ofType: "_remotepairing._tcp.", inDomain: "local.")
    }

    /// Their delegates are unretained, so they're cleared before this goes.
    func stop() {
        browser.delegate = nil
        browser.stop()
        for service in services {
            service.delegate = nil
            service.stop()
        }
        services.removeAll()
    }

    func wait(timeout: TimeInterval) -> NetworkStatus.PairingAdvert {
        _ = done.wait(timeout: .now() + timeout)
        lock.lock()
        defer { lock.unlock() }
        if let found { return found }
        let others = othersResolved == 0 ? "" : " (\(othersResolved) from other devices)"
        return NetworkStatus.PairingAdvert(
            port: nil, summary: "none from this iPhone in \(Int(timeout)) s\(others)")
    }

    private func finish(_ advert: NetworkStatus.PairingAdvert) {
        lock.lock()
        let first = found == nil
        if first { found = advert }
        lock.unlock()
        if first { done.signal() }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.remove(from: .main, forMode: .default)
        service.schedule(in: .main, forMode: .common)
        service.resolve(withTimeout: 2)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        // Without Local Network permission, or without the type in NSBonjourServices.
        let code = errorDict[NetService.errorCode]?.intValue ?? 0
        finish(NetworkStatus.PairingAdvert(port: nil, summary: "the browse failed (error \(code))"))
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let addresses: [String] = (sender.addresses ?? []).compactMap { data in
            data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress, raw.count >= MemoryLayout<sockaddr>.size else { return nil }
                return NetworkStatus.numericHost(base.assumingMemoryBound(to: sockaddr.self),
                                                 length: socklen_t(raw.count))
            }
        }
        guard sender.port > 0, addresses.contains(where: ownAddresses.contains) else {
            if !addresses.isEmpty { lock.lock(); othersResolved += 1; lock.unlock() }
            return
        }
        // Not the service's name, which can be the iPhone's.
        finish(NetworkStatus.PairingAdvert(port: UInt16(sender.port),
                                           summary: "port \(sender.port)"))
    }
}
