

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
            return
        }
        logOS("validateConnectionTimeframe true")
        connect()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        /// Nuts
        //networkHandler?.terminatePacketTunnelConnection()
        logOS("PacketTunnelProvider stopTunnel...")
        netManager?.shutdownNetworkInfrastructure()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // 处理来自主应用的消息
        if let handler = completionHandler {
            handler(messageData)
        }
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
    
    func connect() {
        if netManager == nil {
            netManager = TunnelConnectionHandler()
        }
        
        netManager?.applyNetworkSettings = { [weak self] settings, completion in
            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
        }
        
        Task {
            do {
                logOS("initializeNetworkTunnel")
                try await netManager?.initializeNetworkTunnel()
            } catch {
                logOS("initializeNetworkTunnel error")
            }
        }
    }
    
}




