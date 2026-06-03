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

class TunnelConnectionHandler {
    
    var applyNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var proxyFailureHandler: ((Error) -> Void)?
    
    func initializeNetworkTunnel() async throws {
        logOS("=== Starting Tunnel Connection ===")
        
        try await setupNetworkInfrastructure()
        try enableProxyServices()
        
        logOS("=== Tunnel Connection Completed ===")
    }
    
    private func setupNetworkInfrastructure() async throws {
        let tunnelSettings = buildNetworkConfiguration()
        try await applyNetworkInfrastructure(tunnelSettings)
    }
    
    private func buildNetworkConfiguration() -> NEPacketTunnelNetworkSettings {
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
        tunnelSettings.mtu = 9000
        tunnelSettings.ipv4Settings = buildIPv4Infrastructure()
        tunnelSettings.dnsSettings = buildDNSInfrastructure()
        return tunnelSettings
    }
    
    private func buildIPv4Infrastructure() -> NEIPv4Settings {
        let ipv4Settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        return ipv4Settings
    }
    
    private func buildDNSInfrastructure() -> NEDNSSettings {
        return NEDNSSettings(servers: ["8.8.8.8", "114.114.114.114"])
    }
    
    private func applyNetworkInfrastructure(_ tunnelSettings: NEPacketTunnelNetworkSettings) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let applyNetworkSettings = self.applyNetworkSettings else {
                continuation.resume(throwing: NSError(
                    domain: "TunnelConnectionHandler",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Network settings callback is missing"]
                ))
                return
            }
            
            applyNetworkSettings(tunnelSettings) { error in
                if let error = error {
                    logOS("Network settings application failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    logOS("Network settings applied successfully")
                    continuation.resume()
                }
            }
        }
    }
    
    private func enableProxyServices() throws {
        try enableSocksInfrastructure()
        try enableTunnelInfrastructure()
    }
    
    private func enableTunnelInfrastructure() throws {
        let base64EncodedConfiguration = buildTunnelConfiguration()
        try enableXrayInfrastructure(with: base64EncodedConfiguration)
    }
    
    private func buildTunnelConfiguration() -> String {
        let directoryConfiguration = NetworkConfigProcessor.generateDirectoryConfiguration()
        let base64EncodedConfiguration = Data(directoryConfiguration.utf8).base64EncodedString()
        logOS("Configuration encoded, length: \(base64EncodedConfiguration.count) chars")
        return base64EncodedConfiguration
    }
    
    private func enableXrayInfrastructure(with config: String) throws {
        let encodedConfigString = strdup(config)
        defer { free(encodedConfigString) }
        
        guard let encodedConfigString = encodedConfigString else {
            logOS("Failed to allocate memory for configuration")
            throw NSError(domain: "TunnelConnectionHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate memory"])
        }
        
        CGoRunPotatochips(UnsafeMutablePointer(mutating: encodedConfigString))
        logOS("Xray service started successfully")
    }
    
    private func enableSocksInfrastructure() throws {
        let socksConfigPath = NetworkConfigProcessor.generateSocksConfigurationPath()
        logOS("SOCKS config path: \(socksConfigPath)")
        guard let fileDescriptor = NetworkProxyHandler.tunnelFileDescriptor else {
            logOS("Failed to get tunnel file descriptor before starting SOCKS proxy")
            throw NSError(
                domain: "TunnelConnectionHandler",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get tunnel file descriptor"]
            )
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            logOS("SOCKS proxy activation started")
            let result = NetworkProxyHandler.activateProxyService(withConfig: socksConfigPath, fileDescriptor: fileDescriptor)
            if result != 0 {
                let error = NSError(
                    domain: "TunnelConnectionHandler",
                    code: Int(result),
                    userInfo: [NSLocalizedDescriptionKey: "SOCKS proxy failed to start"]
                )
                logOS("SOCKS proxy activation failed with result: \(result)")
                self?.proxyFailureHandler?(error)
            } else {
                logOS("SOCKS proxy service exited")
            }
        }
    }
    
    func shutdownNetworkInfrastructure() {
        logOS("=== Terminating Tunnel Connection ===")
        NetworkProxyHandler.deactivateProxyService()
        CGoStopPotatochips()
        logOS("Xray service stopped")
    }
}
