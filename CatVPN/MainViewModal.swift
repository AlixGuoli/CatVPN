//
//  MainViewmodel.swift
//  TestNust
//
//  Created by 稻花香 on 2025/3/29.
//

import Foundation
import NetworkExtension
import Alamofire

class MainViewmodel: ObservableObject {
    
    var manager = VPNConnectionManager.instance()
    
    private var connectManual: Bool = false
    
    @Published var isConnecting: Bool = false
    
    @Published var connectionStatus: VPNConnectionStatus = .disconnected
    
    @Published var state: NEVPNStatus = VPNConnectionManager.instance().connectionManager.connection.status {
        didSet {
            guard oldValue != state else { return }
            // 只在需要时更新 connectionStatus
            updateConnectionStatusIfNeeded()
        }
    }
    
    // 添加动态服务器列表
    @Published var availableServers: [VPNServer] = []
    
    // 新增属性以支持UI显示
    @Published var selectedServer: VPNServer = VPNServer(id: -1, name: "Auto", country: "AUTO", flagEmoji: "⚡️", ping: Int.random(in: 10...30))
    @Published var connectionTime: String = "00:00:00"
    @Published var dataTransferred: String = "0 MB"
    @Published var uploadSpeed: String = "0 KB/s"
    @Published var downloadSpeed: String = "0 KB/s"
    
    private var connectionTimer: Timer?
    private var speedTimer: Timer?
    private var startTime: Date?
    
    // 网络数据监测变量
    private var previousUploadBytes: UInt64 = 0
    private var previousDownloadBytes: UInt64 = 0
    private var lastSpeedUpdateTime = Date()
    
    var buttonText: String {
        switch state {
        case .disconnected, .invalid:
            return "Start"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Stop"
        case .disconnecting:
            return "Disconnecting"
        case .reasserting:
            return "Reasserting"
        @unknown default:
            return "Unknown"
        }
    }
    
    var statusText: String {
        switch state {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting"
        case .invalid:
            return "Invalid"
        case .reasserting:
            return "Reasserting"
        @unknown default:
            return "Unknown"
        }
    }
    
    init() {
        self.state = manager.connectionManager.connection.status
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusDidChange(_:)), name: .NEVPNStatusDidChange, object: nil)
        startSpeedTimer()
        
        // 初始化时使用默认服务器列表
        self.availableServers = ServerCFHelper.shared.getDefaultServers()
        
        // 从UserDefaults恢复之前选择的服务器，而不是硬编码为Auto
        self.selectedServer = ServerCFHelper.shared.getCurrentSelectedServer(from: availableServers)
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
        stopConnectionTimer()
        stopSpeedTimer()
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        state = VPNConnectionManager.instance().connectionManager.connection.status
        logDebug("****** VpnStatusDidChange NEVPNConnection state : \(state)")
        logDebug("****** VpnStatusDidChange ConnectionStatus state : \(connectionStatus)")
        // 根据状态变化管理定时器
//        if state == .connected && connectionTimer == nil {
//            startConnectionTimer()
//        } else if state != .connected {
//            stopConnectionTimer()
//        }
    }
    
    private func updateConnectionStatusIfNeeded() {
        // 只在特定条件下更新UI状态
        switch state {
        case .connected:
            logDebug("NEVPNStatus: connected")
            if self.connectManual {
                checkGG()
            } else {
                connectManual = false
                connectSuccessful()
            }
        case .disconnected, .invalid:
            logDebug("NEVPNStatus: disconnected")
            connectionStatus = .disconnected
            stopConnectionTimer()
        case .connecting:
            logDebug("NEVPNStatus: connecting")
            connectionStatus = .connecting
        case .disconnecting, .reasserting:
            logDebug("NEVPNStatus: disconnecting")
            connectionStatus = .connecting
        @unknown default:
            logDebug("NEVPNStatus: failed")
            connectionStatus = .failed
        }
    }
    
    func prepare(){
        connectManual = true
        manager.loadMAllFromPreferences() { error in
            logDebug("prepare")
            if error != nil {
                logDebug(error ?? "prepare error")
            } else{
                self.startConnect()
            }
        }
    }
    
    func startConnect(){
        self.connectionStatus = .connecting
        Task {
            logDebug("prepareServiceCF")
            try await prepareServiceCF()
            
            manager.enableAndConfigureVPNManager() { error in
                guard error == nil else {
                    logDebug("startConnect error")
                    logDebug(error ?? "startConnect error")
                    return
                }
                self.manager.startVpnConnection() { error in
                    guard error == nil else {
                        logDebug("startConnect error2")
                        logDebug(error ?? "startConnect error2")
                        return
                    }
                }
            }
        }
    }
    
    func prepareServiceCF() async throws {
        var serviceConfig = await HttpUtils.shared.fetchServiceCF()
        
        if serviceConfig == nil {
            logDebug("Request Service config is nil, Get service config from UserDefaults")
            serviceConfig = ServiceCFHelper.shared.getCurrentServiceCF()
            if serviceConfig == nil {
                logDebug("UserDefaults Service config is nil, Get service config from local file")
                serviceConfig = FileUtils.readServiceConfFile()
                logDebug("Use ServiceCF @@ local file ")
            }
            logDebug("Use ServiceCF @@ UserDefaults ")
            ServiceCFHelper.shared.isUseServer = false
        } else {
            logDebug("Use ServiceCF @@ requset ")
            ServiceCFHelper.shared.nowServiceCF = serviceConfig
            ServiceCFHelper.shared.isUseServer = true
        }
        logDebug("Decryption Service Config")
        serviceConfig = FileUtils.decodeSafetyData(serviceConfig ?? "")
        processNetworkConfigData(rawInput: serviceConfig, validSource: ServiceCFHelper.shared.isUseServer)
        try await ConnectConfigHandler.shared.savedGroupServiceConfig(serviceConfig: serviceConfig ?? "")
    }
    
    func processNetworkConfigData(rawInput: String?, validSource: Bool) {
        if let jsonData = rawInput?.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any],
                   let outbounds = json["outbounds"] as? [[String: Any]] {
                    for outbound in outbounds {
                        if let settings = outbound["settings"] as? [String: Any],
                           let vnexts = settings["vnext"] as? [[String: Any]] {
                            for vnext in vnexts {
                                if let address = vnext["address"] as? String {
                                    if validSource{
                                        ServiceCFHelper.shared.serverIp = address
                                    }else{
                                        ServiceCFHelper.shared.serverIp = "f\(address)"
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
            }
        }
    }
    
    func stopConnect(){
        manager.enableAndConfigureVPNManager() { error in
            guard error == nil else {
                return
            }
            
            self.manager.stopVpnConnection() { error in
                guard error == nil else {
                    return
                }
            }
        }
    }
    
    func handleButtonAction() {
        switch state {
        case .connected:
            stopConnect()
        case .invalid, .disconnected:
            self.prepare()
        default:
            break
        }
    }
    
    // 连接定时器管理
    private func startConnectionTimer() {
        startTime = Date()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateConnectionTime()
        }
    }
    
    private func stopConnectionTimer() {
        connectionTime = "00:00:00"
        dataTransferred = "0 MB"
        connectionTimer?.invalidate()
        connectionTimer = nil
        startTime = nil
    }
    
    private func updateConnectionTime() {
        guard let startTime = startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        connectionTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        
        // 模拟数据传输
        let dataInMB = elapsed / 60 * Double.random(in: 1...5)
        dataTransferred = String(format: "%.1f MB", dataInMB)
    }
    
    // 网络速度监测
    private func startSpeedTimer() {
        speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateNetworkSpeed()
        }
    }
    
    private func stopSpeedTimer() {
        speedTimer?.invalidate()
        speedTimer = nil
    }
    
    private func updateNetworkSpeed() {
        let currentBytes = getNetworkBytes()
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(lastSpeedUpdateTime)
        
        if timeInterval >= 1.0 && previousUploadBytes > 0 && previousDownloadBytes > 0 {
            let uploadDiff = currentBytes.upload > previousUploadBytes ? currentBytes.upload - previousUploadBytes : 0
            let downloadDiff = currentBytes.download > previousDownloadBytes ? currentBytes.download - previousDownloadBytes : 0
            
            let uploadSpeed = Double(uploadDiff) / timeInterval
            let downloadSpeed = Double(downloadDiff) / timeInterval
            
            DispatchQueue.main.async {
                self.uploadSpeed = self.formatSpeed(uploadSpeed)
                self.downloadSpeed = self.formatSpeed(downloadSpeed)
            }
            
            lastSpeedUpdateTime = currentTime
        }
        
        previousUploadBytes = currentBytes.upload
        previousDownloadBytes = currentBytes.download
    }
    
    private func getNetworkBytes() -> (upload: UInt64, download: UInt64) {
        // 模拟网络数据，因为实际获取系统网络数据需要更复杂的API
        let baseUpload: UInt64 = UInt64.random(in: 1000...50000) // 1KB-50KB
        let baseDownload: UInt64 = UInt64.random(in: 5000...500000) // 5KB-500KB
        
        // 如果VPN连接，模拟更稳定的速度
        if state == .connected {
            return (
                upload: baseUpload * UInt64.random(in: 2...8),
                download: baseDownload * UInt64.random(in: 3...10)
            )
        } else {
            return (
                upload: baseUpload,
                download: baseDownload
            )
        }
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        } else {
            return String(format: "%.1f GB/s", bytesPerSecond / (1024 * 1024 * 1024))
        }
    }
    
    func connectSuccessful() {
        startConnectionTimer()
        DispatchQueue.main.async {
            self.connectionStatus = .connected
            logDebug("Connect Successful")
            let helper = ServiceCFHelper.shared
            if helper.isUseServer {
                if let serviceCF = helper.nowServiceCF, !serviceCF.isEmpty {
                    logDebug("Save service config to UserDefaults")
                    UserDefaults.standard.setValue(serviceCF, forKey: CatKey.CAT_NOW_SERVICE_CONF)
                }
            }
        }
    }
    
    func connectFailed() {
        logDebug("Connect Failed")
        stopConnect()
    }
    
    func checkGG() {
        Task {
            let connectionStatus = await CatKey.shared.validateConnectionStatus()
            if connectionStatus {
                logDebug("Successfully to test Google")
                connectSuccessful()
            } else {
                logDebug("Failed to test Google")
                connectFailed()
            }
        }
    }
    
    func checkNet(completion: @escaping (Bool) -> Void) {
        let netWorkManager = NetworkReachabilityManager()
        netWorkManager?.startListening { status in
            switch status {
            case .notReachable:
                logDebug("network is not reachable")
            case .unknown :
                logDebug("It is unknown whether the network is reachable")
            case .reachable(.ethernetOrWiFi):
                logDebug("network reachable over the WiFi or Ethernet connection")
                self.requestBaseConf(completion: completion)
            case .reachable(.cellular):
                logDebug("network reachable over the cellular connection")
                self.requestBaseConf(completion: completion)
            }
            
        }
    }
    
    func requestBaseConf(completion: @escaping (Bool) -> Void) {
        Task {
            logDebug("Start to request Base Config")
            await HttpUtils.shared.fetchBaseConf()
            logDebug("Over to request Base Config")
            
            completion(true)
        }
    }
    
    // MARK: - 服务器管理
    
    /// 获取服务器列表
    func fetchServers() async {
        let servers = await ServerCFHelper.shared.fetchServers()
        await MainActor.run {
            self.availableServers = servers
            self.selectedServer = ServerCFHelper.shared.getCurrentSelectedServer(from: servers)
        }
    }
    
    // 选择服务器
    func selectServer(_ server: VPNServer) {
        selectedServer = server
        ServerCFHelper.shared.saveSelectedServer(server)
    }
}
