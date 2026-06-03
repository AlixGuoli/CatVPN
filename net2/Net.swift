

import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var netManager: TunnelConnectionHandler? = nil
    
    //private var networkHandler : NetworkProtocolHandler? = nil
    //static var country = Locale.current.regionCode?.lowercased() ?? "Unknown"
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logOS("PacketTunnelProvider startTunnel...")
        //startSecureTunnelManager()
        if !validateConnectionTimeframe() {
            let error = NSError(domain: "com.CatVPN.CatVPN", code: 1, userInfo: ["timeout": "timeout error"])
            self.cancelTunnelWithError(error)
            logOS("validateConnectionTimeframe false")
            completionHandler(error)
            return
        }
        logOS("validateConnectionTimeframe true")
        connect(completionHandler: completionHandler)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        /// Nuts
        //networkHandler?.terminatePacketTunnelConnection()
        logOS("PacketTunnelProvider stopTunnel...")
        netManager?.shutdownNetworkInfrastructure()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let handler = completionHandler else { return }
        guard String(data: messageData, encoding: .utf8) == ServiceDefaults.metricsMessage else {
            handler(messageData)
            return
        }

        var egressPackets = 0
        var egressBytes = 0
        var ingressPackets = 0
        var ingressBytes = 0
        LuxJagNetworkBridgeExtractMetrics(&egressPackets, &egressBytes, &ingressPackets, &ingressBytes)

        let metrics: [String: Int] = [
            "egressPackets": egressPackets,
            "egressBytes": egressBytes,
            "ingressPackets": ingressPackets,
            "ingressBytes": ingressBytes
        ]
        let responseData = try? JSONSerialization.data(withJSONObject: metrics, options: [])
        handler(responseData)
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // 准备睡眠
        completionHandler()
    }
    
    override func wake() {
        // 从睡眠中唤醒
    }
    
    /// Nuts
//    func startSecureTunnelManager(){
//        if networkHandler == nil{
//            networkHandler = NetworkProtocolHandler(packetFlow: packetFlow)
//        }
//        networkHandler?.networkConfigurationHandler = { [weak self] settings, completion in
//            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
//        }
//        networkHandler?.initializeConnectionSequence()
//    }
    
    func validateConnectionTimeframe() -> Bool {
        if let userDefaults = UserDefaults(suiteName: ServiceDefaults.targetGroup) {
            if let startDate = userDefaults.object(forKey: ServiceDefaults.targetDate) as? Date {
                let currentDate = Date()
                let timeInterval = currentDate.timeIntervalSince(startDate)
                if timeInterval < 10 {
                    logOS("PacketTunnelProvider less 10s")
                    //os_log("PacketTunnelProvider less 10s.", log: OSLog.default, type: .error)
                    return true
                }
            }
        }
        return false
    }
    
    func connect(completionHandler: @escaping (Error?) -> Void) {
        if netManager == nil {
            netManager = TunnelConnectionHandler()
        }
        
        netManager?.applyNetworkSettings = { [weak self] settings, completion in
            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
        }
        netManager?.proxyFailureHandler = { [weak self] error in
            logOS("SOCKS proxy failure reported to packet tunnel provider: \(error.localizedDescription)")
            self?.cancelTunnelWithError(error)
        }
        
        Task {
            do {
                logOS("initializeNetworkTunnel")
                try await netManager?.initializeNetworkTunnel()
                completionHandler(nil)
            } catch {
                logOS("initializeNetworkTunnel error: \(error.localizedDescription)")
                self.cancelTunnelWithError(error)
                completionHandler(error)
            }
        }
    }
    
}


