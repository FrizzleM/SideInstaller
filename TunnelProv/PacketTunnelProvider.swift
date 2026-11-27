//
//  PacketTunnelProvider.swift
//  TunnelProv
//
//  Created by Stossy11 on 28/03/2025.
//

import NetworkExtension
#if DEBUG
import os.log
#endif

@inline(__always)
private func tunnelLog(_ message: @autoclosure () -> String) {
#if DEBUG
    os_log("[TunnelProv] %{public}@", type: .error, message())
#endif
}


class PacketTunnelProvider: NEPacketTunnelProvider {
    var tunnelIfaceIP: String = TunnelConstants.defaultIfaceIP
    var tunnelPeerIP: String = TunnelConstants.defaultPeerIP
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        if let options = options {
            for (key, val) in options {
                tunnelLog("startTunnel option \(key) = \(String(describing: val))")
            }
        } else {
            tunnelLog("startTunnel: options is nil")
        }
        
        let providerConfiguration =
            (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration

        if let ifaceIp = options?[TunnelConstants.ifaceIPConfigurationKey] as? String
            ?? providerConfiguration?[TunnelConstants.ifaceIPConfigurationKey] as? String {
            tunnelLog("TunnelIfaceIP configured as: \(ifaceIp)")
            tunnelIfaceIP = ifaceIp
        }
        if let peerIp = options?[TunnelConstants.peerIPConfigurationKey] as? String
            ?? providerConfiguration?[TunnelConstants.peerIPConfigurationKey] as? String {
            tunnelLog("TunnelPeerIP configured as: \(peerIp)")
            tunnelPeerIP = peerIp
        }
        
        let ifaceEndpoint = CIDREndpoint(tunnelIfaceIP, defaultPrefix: 24)
        let peerEndpoint = CIDREndpoint(tunnelPeerIP, defaultPrefix: 32)
        
        tunnelLog("Configuring P2P settings: peer=\(peerEndpoint.ip)/\(peerEndpoint.prefix) (\(peerEndpoint.subnetMask)), iface=\(ifaceEndpoint.ip)/\(ifaceEndpoint.prefix) (\(ifaceEndpoint.subnetMask))")
        
        // tunnel iface configuration
        let ifaceIPv4 = NEIPv4Settings(addresses: [ifaceEndpoint.ip], subnetMasks: [ifaceEndpoint.subnetMask])
        let tunnelDestinationIPv4Routes = [
            // actual destination routes of this VPN tunnel
            NEIPv4Route(destinationAddress: peerEndpoint.ip, subnetMask: peerEndpoint.subnetMask)
        ]
        ifaceIPv4.includedRoutes = tunnelDestinationIPv4Routes
        ifaceIPv4.excludedRoutes = [.default()]

        // Tunneling config
        let settings = NEPacketTunnelNetworkSettings(
            // NOTE: 'tunnelRemoteAddress' is just for UI concerns and is not involved in routing
            tunnelRemoteAddress: peerEndpoint.ip
        )   
        settings.ipv4Settings = ifaceIPv4
        
        tunnelLog("Calling setTunnelNetworkSettings...")
        setTunnelNetworkSettings(settings) { error in
            if let error = error {
                tunnelLog("Failed to set settings: \(error.localizedDescription)")
                return completionHandler(error)
            }
            tunnelLog("Tunnel network settings set successfully. Starting packet loops.")
            self.setPackets()
            completionHandler(nil)
        }
    }
    
    func setPackets() {
        packetFlow.readPackets { [self] packets, protocols in
            var modified = packets
            
            for i in modified.indices where protocols[i].int32Value == AF_INET && modified[i].count >= 20 {
                modified[i].withUnsafeMutableBytes { bytes in
                    guard let ptr = bytes.baseAddress?.assumingMemoryBound(to: UInt32.self) else { return }
                    let src = ptr[3]
                    let dst = ptr[4]
                    ptr[3] = dst
                    ptr[4] = src
                }
            }
            
            self.packetFlow.writePackets(modified, withProtocols: protocols)
            setPackets()
        }
    }
}
