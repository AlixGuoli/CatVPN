//
//  Nust5.swift
//  IfyLiteNetworkTunnel
//
//  Created by 云帆 on 10/6/2025.
//

import Foundation
import NetworkExtension
import os
import CommonCrypto
import Network

class NetworkProtocolHandler {
    var tcpSocket: NWConnection?
    var dispatchWorkQueue: DispatchQueue?
    
//    var remoteServerPort = "49155"
    var remoteServerPort = "8443"
    var remoteServerHost = "157.254.140.149"
    
    var regionCode = "us"
    var localeIdentifier = "en"
    var bundleIdentifier = "vpn.demo.test"
    var appVersion = "1.0.0"
    
    var encryptionKey = "3e027e48ec6f5a9c705dfe17bed37201"
    var incomingDataBuffer = Data()
    var packetDataBuffer = Data()
    
    var secretKeyString = "hfor1"
    var randomPaddingLength = 128
    
    var networkConfigurationHandler: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var tunnelDataFlow: NEPacketTunnelFlow
    
    init(packetFlow: NEPacketTunnelFlow) {
        self.tunnelDataFlow = packetFlow
    }
    
    func initializeConnectionSequence() {
        os_log("hellovpn nust5 setupConfuseTCPConnection: %{public}@", log: OSLog.default, type: .error, "setupConfuseTCPConnection")
        guard let port = NWEndpoint.Port(remoteServerPort) else { return }
        
        let endpointHost = NWEndpoint.Host(remoteServerHost)
        tcpSocket = NWConnection(host: endpointHost, port: port, using: .tcp)
        self.dispatchWorkQueue = .global()
        self.tcpSocket?.stateUpdateHandler = self.handleConnectionStateChange(to:)
        self.tcpSocket?.start(queue: self.dispatchWorkQueue!)
    }
    
    func handleConnectionStateChange(to connectionState: NWConnection.State) {
        switch connectionState {
        case .ready:
            performInitialAuthentication()
        case .failed(_), .cancelled:
            os_log("hellovpn getNutsIP failed: %{public}@", log: OSLog.default, type: .error, "getNutsIP failed")
        default:
            os_log("hellovpn handleConnectionStateChange failed: %{public}@", log: OSLog.default, type: .error, "getNutsIP \(connectionState)")
            break
        }
    }
    
    func performInitialAuthentication() {
        os_log("hellovpn getNutsIP: %{public}@", log: OSLog.default, type: .error, "performInitialAuthentication")
        guard let authenticationData = createAuthenticationPayload() else { return }
        os_log("hellovpn getNutsIP2: %{public}@", log: OSLog.default, type: .error, "performInitialAuthentication")
        let processedAuthData = applyDataObfuscation(data: authenticationData, key: self.secretKeyString.data(using: .utf8)!)
        self.tcpSocket?.send(content: processedAuthData, completion: .contentProcessed({ [weak self] error in
            guard let self = self, error == nil else { return }
            os_log("hellovpn getNutsIP3: %{public}@", log: OSLog.default, type: .error, "beginResponseHeaderProcessing")
            self.beginResponseHeaderProcessing()
        }))
    }
    
    private func beginResponseHeaderProcessing() {
        tcpSocket?.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            self.incomingDataBuffer.append(data)
            if self.incomingDataBuffer.count >= 2 {
                let dataLength = self.incomingDataBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                self.incomingDataBuffer.removeFirst(2)
                self.processIncomingDataWithLength(Int(dataLength))
                os_log("hellovpn getNutsIP: %{public}@", log: OSLog.default, type: .error, "processIncomingDataWithLength")
            } else {
                self.beginResponseHeaderProcessing()
            }
        }
    }
    
    private func processIncomingDataWithLength(_ expectedLength: Int) {
        tcpSocket?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            self.incomingDataBuffer.append(data)
            if self.incomingDataBuffer.count >= expectedLength {
                let encryptedServerResponse = self.incomingDataBuffer.prefix(expectedLength)
                self.incomingDataBuffer.removeFirst(expectedLength)
                let decryptedServerResponse = self.reverseDataObfuscation(data: encryptedServerResponse, key: self.secretKeyString.data(using: .utf8)!)
                self.processServerResponseAndSetupTunnel(decryptedServerResponse)
                os_log("hellovpn getNutsIP: %{public}@", log: OSLog.default, type: .error, "processServerResponseAndSetupTunnel")
            } else {
                self.processIncomingDataWithLength(expectedLength)
            }
        }
    }
    
    private func processServerResponseAndSetupTunnel(_ responseData: Data) {
        let serverResponseString = String(data: responseData, encoding: .utf8)
        let assignedInternalIP = self.extractAssignedIPAddress(responseIPs: serverResponseString!)
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, assignedInternalIP)
        self.configureNetworkTunnelSettings(intranetIP: assignedInternalIP)
    }
    
    func configureNetworkTunnelSettings(intranetIP: String) {
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, "configureNetworkTunnelSettings")
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.10.0.1")
        tunnelSettings.mtu = 1400
        tunnelSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
        tunnelSettings.ipv4Settings = {
            let ipv4Config = NEIPv4Settings(addresses: [intranetIP], subnetMasks: ["255.255.0.0"])
            ipv4Config.includedRoutes = [NEIPv4Route.default()]
            return ipv4Config
        }()
        self.networkConfigurationHandler?(tunnelSettings) { [weak self] error in
            guard let self = self, error == nil else { return }
            self.startDataForwardingOperations()
        }
    }
    
    private func startDataForwardingOperations() {
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, "startDataForwardingOperations")
        self.initiateLocalToRemoteDataFlow()
        self.initiateRemoteToLocalDataFlow()
    }
    
    func initiateLocalToRemoteDataFlow() {
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, "initiateLocalToRemoteDataFlow")
        let obfuscationKey = "hfor1".data(using: .utf8)!
        self.tunnelDataFlow.readPackets { [weak self] (packets: [Data], _) in
            guard let self = self else { return }
            for packet in packets {
                let obfuscatedPacket = self.applyDataObfuscation(data: packet, key: obfuscationKey)
                self.tcpSocket?.send(content: obfuscatedPacket, completion: .contentProcessed({ error in
                    if error != nil { return }
                }))
            }
            self.initiateLocalToRemoteDataFlow()
        }
    }
    
    func initiateRemoteToLocalDataFlow() {
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, "initiateRemoteToLocalDataFlow")
        self.tcpSocket?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] data, _, _, error in
            guard let self = self, let data = data, !data.isEmpty else { return }
            self.packetDataBuffer.append(data)
            self.processAccumulatedPacketData()
            self.initiateRemoteToLocalDataFlow()
        }
    }
    
    private func processAccumulatedPacketData() {
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, "processAccumulatedPacketData")
        let deobfuscationKey = "hfor1".data(using: .utf8)!
        while self.packetDataBuffer.count >= 2 {
            let packetLength = self.packetDataBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            self.packetDataBuffer.removeSubrange(0..<2)
            if self.packetDataBuffer.count >= packetLength {
                let obfuscatedPacketData = self.packetDataBuffer.prefix(Int(packetLength))
                self.packetDataBuffer.removeSubrange(0..<Int(packetLength))
                let clearPacketData = self.reverseDataObfuscation(data: obfuscatedPacketData, key: deobfuscationKey)
                let networkProtocolIdentifier = AF_INET as NSNumber
                self.tunnelDataFlow.writePackets([clearPacketData], withProtocols: [networkProtocolIdentifier])
            } else {
                self.packetDataBuffer.insert(contentsOf: withUnsafeBytes(of: packetLength.bigEndian, Array.init), at: 0)
                break
            }
        }
    }
    
    func applyDataObfuscation(data: Data, key: Data) -> Data {
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, "applyDataObfuscation")
        let maxRandomLength = UInt8(self.randomPaddingLength)
        let actualRandomLength = UInt8.random(in: 0...maxRandomLength)
        let paddingData = Data((0..<Int(actualRandomLength)).map { _ in UInt8.random(in: 0...255) })
        let dataWithPadding = paddingData + data + Data([actualRandomLength])
        let obfuscatedData = Data(dataWithPadding.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        })
        let lengthPrefix = UInt16(obfuscatedData.count).convertToByteSequence()
        return lengthPrefix + obfuscatedData
    }
    
    func extractAssignedIPAddress(responseIPs: String) -> String {
        let ipAddressList = responseIPs.split(separator: ",").map { String($0) }
        return ipAddressList.first ?? ""
    }
    
    func terminatePacketTunnelConnection() {
        self.tcpSocket?.cancel()
    }
    
    func createAuthenticationPayload() -> Data? {
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, "createAuthenticationPayload")
        let authenticationParameters: [String: Any] = ["package": bundleIdentifier, "version": appVersion, "SDK": "7.0", "country": regionCode, "language": localeIdentifier, "action": "new_connect"]
        guard let serializedAuthData = try? JSONSerialization.data(withJSONObject: authenticationParameters, options: []),
              let keyMaterial = encryptionKey.data(using: .utf8) else {
            return nil
        }
        return performAESEncryption(plainData: serializedAuthData, keyData: keyMaterial)
    }
    
    private func performAESEncryption(plainData: Data, keyData: Data) -> Data? {
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, "performAESEncryption")
        let plaintextBytes = [UInt8](plainData)
        let keyBytes = [UInt8](keyData)
        
        var ciphertextBuffer = [UInt8](repeating: 0, count: plaintextBytes.count + kCCBlockSizeAES128)
        var encryptedByteCount = 0
        let encryptionStatus = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode), keyBytes, keyData.count, nil, plaintextBytes, plaintextBytes.count, &ciphertextBuffer, ciphertextBuffer.count, &encryptedByteCount)
        guard encryptionStatus == kCCSuccess else {
            return nil
        }
        return Data(bytes: ciphertextBuffer, count: encryptedByteCount)
    }
    
    func reverseDataObfuscation(data: Data, key: Data) -> Data {
        os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, "reverseDataObfuscation")
        let deobfuscatedData = Data(data.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        })
        if deobfuscatedData.count > 0 {
            let paddingLengthIndicator = deobfuscatedData.last!
            let paddingLength = Int(paddingLengthIndicator)
            if paddingLength < deobfuscatedData.count {
                return deobfuscatedData.subdata(in: paddingLength..<(deobfuscatedData.count - 1))
            }
        }
        return deobfuscatedData
    }
}

extension UInt16 {
    func convertToByteSequence() -> Data {
        return Data([UInt8(self >> 8), UInt8(self & 0xFF)])
    }
}
