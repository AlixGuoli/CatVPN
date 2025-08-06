

import Foundation
import NetworkExtension

class VPNConnectionManager{
    public var connectionManager = NEVPNManager.shared()
  
    private static var myInstance: VPNConnectionManager = {
        return VPNConnectionManager()
    }()

    public class func instance() -> VPNConnectionManager {
        return myInstance
    }
  
    public init() {}
    
    public func loadMAllFromPreferences(completion: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences() { managers, error in
            guard let managers = managers, error == nil else {
                completion(error)
                return
            }
            
            if managers.count == 0 {
                let providerManager = NETunnelProviderManager()
                providerManager.protocolConfiguration = NETunnelProviderProtocol()
                providerManager.localizedDescription = "Cat VPN "
                providerManager.protocolConfiguration?.serverAddress = "Cat VPN"
                providerManager.saveToPreferences { error in
                    guard error == nil else {
                        completion(error)
                        return
                    }
                    providerManager.loadFromPreferences { error in
                        self.connectionManager = providerManager
                        completion(nil)
                    }
                }
            } else {
                self.connectionManager = managers[0]
                completion(nil)
            }
        }
    }
    
    public func enableAndConfigureVPNManager(completion: @escaping (Error?) -> Void) {
//        print("enableAndConfigureVPNManager")
        connectionManager.isEnabled = true
        connectionManager.saveToPreferences { error in
            guard error == nil else {
                completion(error)
                return
            }
            self.connectionManager.loadFromPreferences { error in
                completion(error)
            }
        }
    }
    
    public func startVpnConnection(completion: @escaping (Error?) -> Void) {
        if self.connectionManager.connection.status == .disconnected || self.connectionManager.connection.status == .invalid {
            do {
                print("startVpnConnection")
                try self.connectionManager.connection.startVPNTunnel()
            } catch {
                completion(error)
            }
        }
    }
    
    public func stopVpnConnection(completion: @escaping (Error?) -> Void) {
        if self.connectionManager.connection.status == .connected{
            do {
                try self.connectionManager.connection.stopVPNTunnel()
            } catch {
                completion(error)
            }
        }
    }
    
    public func retryConnection(completion: @escaping (Error?) -> Void) {
        self.connectionManager.connection.stopVPNTunnel()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.connectionManager.connection.status == .disconnected {
                timer.invalidate()
                logDebug("VPN disconnected, staring again...")
                do {
                    try self.connectionManager.connection.startVPNTunnel()
                } catch {
                    completion(error)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }
}
