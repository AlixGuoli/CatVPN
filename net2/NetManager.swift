//
//  NetManager.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/30.
//
import Foundation
import NetworkExtension
import os

var globalConfigPath: URL? = nil

class NetManager {
    
    var applyNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    
    func connTunnelConnection() async throws {
        logOS("=== Starting Tunnel Connection ===")
        
        let networkConfig = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
        networkConfig.mtu = 9000
     
        let ipv4Config = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
        ipv4Config.includedRoutes = [NEIPv4Route.default()]
        networkConfig.ipv4Settings = ipv4Config
        
        networkConfig.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "114.114.114.114"])
        self.applyNetworkSettings?(networkConfig) { error in
            if error != nil {
                logOS("Network settings application failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            } else {
                logOS("Network settings applied successfully")
            }
        }
        
        do {
            try connSocksProxy()
            try connTunnelService()
            logOS("=== Tunnel Connection Completed ===")
        } catch {
            logOS("Failed to start proxy services: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func connTunnelService() throws {
        logOS("Starting Xray tunnel service...")
        
        let dirConfig = NetHelper.getDirConfig()
        let encodedConfig = Data(dirConfig.utf8).base64EncodedString()
        logOS("Configuration encoded, length: \(encodedConfig.count) chars")
        
        let configString = strdup(encodedConfig)
        defer { free(configString) }
        
        if let configString = configString {
            CGoRunLuxJag(UnsafeMutablePointer(mutating: configString))
            logOS("Xray service started successfully")
        } else {
            logOS("Failed to allocate memory for configuration")
            throw NSError(domain: "NetManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate memory"])
        }
    }
    
    private func connSocksProxy() throws {
        logOS("Starting SOCKS proxy...")
        
        let configPath = NetHelper.getSocksFilePath()
        logOS("SOCKS config path: \(configPath)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            NetSocks.startProxyService(withConfig: configPath)
            logOS("SOCKS proxy activated")
        }
    }
    
    func terminateTunnelConnection() {
        logOS("=== Terminating Tunnel Connection ===")
        CGoStopLuxJag()
        logOS("Xray service stopped")
    }
}
