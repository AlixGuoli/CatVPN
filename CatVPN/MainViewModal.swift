//
//  MainViewmodel.swift
//  TestNust
//
//  Created by 稻花香 on 2025/3/29.
//

import Foundation
import NetworkExtension
import Alamofire

class MainViewmodel : ObservableObject{
    
    var manager = VPNConnectionManager.instance()
    
    @Published var state: NEVPNStatus = VPNConnectionManager.instance().connectionManager.connection.status {
        didSet {
            guard oldValue != state else { return }
        }
    }
    
    // 新增属性以支持UI显示
    @Published var selectedServer: VPNServer = VPNServer.availableServers[0]
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
    
    // 将NEVPNStatus转换为VPNConnectionStatus以保持UI一致性
    var connectionStatus: VPNConnectionStatus {
        switch state {
        case .disconnected, .invalid:
            return .disconnected
        case .connecting:
            return .connecting
        case .connected:
            return .connected
        case .disconnecting:
            return .connecting // 显示为连接中状态
        case .reasserting:
            return .connecting // 显示为连接中状态
        @unknown default:
            return .failed
        }
    }
    
    init() {
        self.state = manager.connectionManager.connection.status
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusDidChange(_:)), name: .NEVPNStatusDidChange, object: nil)
        startSpeedTimer()
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
        stopConnectionTimer()
        stopSpeedTimer()
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        state = VPNConnectionManager.instance().connectionManager.connection.status
        debugPrint("****** NEVPNConnection state : \(state)")
        debugPrint("****** ConnectionStatus state : \(connectionStatus)")
        // 根据状态变化管理定时器
        if state == .connected && connectionTimer == nil {
            startConnectionTimer()
        } else if state != .connected {
            stopConnectionTimer()
            connectionTime = "00:00:00"
            dataTransferred = "0 MB"
        }
    }
    
    func prepare(){
        manager.loadMAllFromPreferences() { error in
            print("prepare2")
            if let error = error {
//                print(error)
            }else{
                self.startConnect()
            }
        }
    }
    
    func startConnect(){
        manager.enableAndConfigureVPNManager() { error in
            guard error == nil else {
                print("startConnect error")
                print(error)
                return
            }
            self.manager.startVpnConnection() { error in
                guard error == nil else {
                    print("startConnect error2")
                    print(error)
                    return
                }
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
            // 先切换到连接中状态，2秒后实际开始连接
            self.state = .connecting
           
            // 延迟2秒后再执行
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.prepare()
            }
        default:
            break
        }
    }
    
    // 选择服务器
    func selectServer(_ server: VPNServer) {
        selectedServer = server
    }
    
    // 连接定时器管理
    private func startConnectionTimer() {
        startTime = Date()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateConnectionTime()
        }
    }
    
    private func stopConnectionTimer() {
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
    
    func checkNet(){
        let netWorkManager = NetworkReachabilityManager()
        netWorkManager?.startListening { status in
            
            switch status {
            case .notReachable:
                print("network is not reachable")
            case .unknown :
                print("It is unknown whether the network is reachable")
            case .reachable(.ethernetOrWiFi):
                print("network reachable over the WiFi or Ethernet connection")
            case .reachable(.cellular):
                print("network reachable over the cellular connection")
            }
            
        }
    }
}

// 预览专用的 Mock ViewModel
#if DEBUG
class MockMainViewmodel: ObservableObject {
    @Published var state: NEVPNStatus = .disconnected
    @Published var selectedServer: VPNServer = VPNServer.availableServers[0]
    @Published var connectionTime: String = "00:00:00"
    @Published var dataTransferred: String = "0 MB"
    @Published var uploadSpeed: String = "0 KB/s"
    @Published var downloadSpeed: String = "0 KB/s"
    
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
    
    var connectionStatus: VPNConnectionStatus {
        switch state {
        case .disconnected, .invalid:
            return .disconnected
        case .connecting:
            return .connecting
        case .connected:
            return .connected
        case .disconnecting:
            return .connecting
        case .reasserting:
            return .connecting
        @unknown default:
            return .failed
        }
    }
    
    init() {
        // Mock 初始化，不依赖 NetworkExtension
    }
}
#endif
