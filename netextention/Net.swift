

import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var networkHandler : NetworkProtocolHandler? = nil
    
    static var country = Locale.current.regionCode?.lowercased() ?? "Unknown"
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("hellovpn startTunnel: %{public}@", log: OSLog.default, type: .error, "setupConfuseTCPConnection")
        startSecureTunnelManager()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        networkHandler?.terminatePacketTunnelConnection()
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
    func startSecureTunnelManager(){
        if networkHandler == nil{
                  networkHandler = NetworkProtocolHandler(packetFlow: packetFlow)
              }
              networkHandler?.networkConfigurationHandler = { [weak self] settings, completion in
                  self?.setTunnelNetworkSettings(settings, completionHandler: completion)
              }
              networkHandler?.initializeConnectionSequence()
     }
}


