

import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var netManager: NetManager? = nil
    
    //private var networkHandler : NetworkProtocolHandler? = nil
    //static var country = Locale.current.regionCode?.lowercased() ?? "Unknown"
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logOS("PacketTunnelProvider startTunnel...")
        //startSecureTunnelManager()
        if !isMyConnect() {
            let error = NSError(domain: "com.CatVPN.CatVPN", code: 1, userInfo: ["timeout": "timeout error"])
            self.cancelTunnelWithError(error)
            logOS("isMyConnect false")
            return
        }
        logOS("isMyConnect true")
        connect()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        /// Nuts
        //networkHandler?.terminatePacketTunnelConnection()
        logOS("PacketTunnelProvider stopTunnel...")
        netManager?.terminateTunnelConnection()
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
    
    func isMyConnect() -> Bool {
        if let userDefaults = UserDefaults(suiteName: ServiceDefaults.GroupId) {
            if let startDate = userDefaults.object(forKey: ServiceDefaults.GroupTime) as? Date {
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
            netManager = NetManager()
        }
        
        netManager?.applyNetworkSettings = { [weak self] settings, completion in
            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
        }
        
        Task {
            do {
                logOS("connTunnelConnection")
                try await netManager?.connTunnelConnection()
            } catch {
                logOS("connTunnelConnection error")
            }
        }
    }
    
}




