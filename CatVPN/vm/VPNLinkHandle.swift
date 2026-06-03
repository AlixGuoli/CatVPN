

import Foundation
import NetworkExtension

class VPNConnectionManager{
    public var connectionManager = NEVPNManager.shared()
    
    private let providerBundleIdentifier = "CatVPN.CatVPN.ne"
  
    private static var myInstance: VPNConnectionManager = {
        return VPNConnectionManager()
    }()

    public class func instance() -> VPNConnectionManager {
        return myInstance
    }
  
    public init() {}
    
    private func applyTunnelProviderConfiguration(to manager: NEVPNManager) {
        let protocolConfiguration = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = providerBundleIdentifier
        protocolConfiguration.serverAddress = "Cat VPN"
        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = "Cat VPN "
    }
    
    private func isManagedTunnel(_ manager: NETunnelProviderManager) -> Bool {
        let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol
        return protocolConfiguration?.providerBundleIdentifier == providerBundleIdentifier ||
            manager.localizedDescription == "Cat VPN "
    }
    
    public func loadMAllFromPreferences(completion: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences() { managers, error in
            guard let managers = managers, error == nil else {
                completion(error)
                return
            }
            
            if let existingManager = managers.first(where: { self.isManagedTunnel($0) }) {
                self.connectionManager = existingManager
                self.applyTunnelProviderConfiguration(to: self.connectionManager)
                completion(nil)
            } else {
                let providerManager = NETunnelProviderManager()
                self.applyTunnelProviderConfiguration(to: providerManager)
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
            }
        }
    }
    
    public func enableAndConfigureVPNManager(completion: @escaping (Error?) -> Void) {
//        print("enableAndConfigureVPNManager")
        applyTunnelProviderConfiguration(to: connectionManager)
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
                completion(nil)
            } catch {
                completion(error)
            }
        } else {
            completion(nil)
        }
    }
    
    public func stopVpnConnection(completion: @escaping (Error?) -> Void) {
        if self.connectionManager.connection.status == .connected{
            do {
                try self.connectionManager.connection.stopVPNTunnel()
                completion(nil)
            } catch {
                completion(error)
            }
        } else {
            completion(nil)
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
