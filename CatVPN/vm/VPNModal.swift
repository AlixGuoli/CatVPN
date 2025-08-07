//
//  VPNModel.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI
import Foundation
import Network

// VPN连接状态枚举
enum VPNConnectionStatus {
    case disconnected   // 未连接
    case connecting     // 连接中
    case connected      // 已连接
    case failed         // 连接失败
    
    var statusText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .failed:
            return "Connection Failed"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}

// VPN服务器模型
struct VPNServer: Identifiable, Hashable {
    let id: Int
    let name: String
    let country: String
    let flagEmoji: String
    let ping: Int
    
    static let availableServers = [
        VPNServer(id: -1, name: "Auto", country: "AUTO", flagEmoji: "⚡️", ping: Int.random(in: 10...30)),
        VPNServer(id: 104, name: "Germany", country: "DE", flagEmoji: "🇩🇪", ping: Int.random(in: 8...30)),
        VPNServer(id: 105, name: "United States", country: "US", flagEmoji: "🇺🇸", ping: Int.random(in: 9...40)),
        VPNServer(id: 102, name: "United Kingdom", country: "GB", flagEmoji: "🇬🇧", ping: Int.random(in: 13...45)),
        VPNServer(id: 106, name: "Netherlands", country: "NL", flagEmoji: "🇳🇱", ping: Int.random(in: 12...30))
    ]
}

// VPN状态管理类
class VPNManager: ObservableObject {
    @Published var connectionStatus: VPNConnectionStatus = .disconnected
    @Published var selectedServer: VPNServer = VPNServer.availableServers[0]
    @Published var connectionTime: String = "00:00:00"
    @Published var dataTransferred: String = "0 MB"
    @Published var uploadSpeed: String = "0 KB/s"
    @Published var downloadSpeed: String = "0 KB/s"
    
    private var connectionTimer: Timer?
    private var speedTimer: Timer?
    private var startTime: Date?
    private var networkMonitor = NWPathMonitor()
    private var monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    // 网络数据监测变量
    private var previousUploadBytes: UInt64 = 0
    private var previousDownloadBytes: UInt64 = 0
    private var lastSpeedUpdateTime = Date()

    init() {
        startNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
        stopSpeedTimer()
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.start(queue: monitorQueue)
        startSpeedTimer()
    }
    
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
        // 在真实应用中，可以使用 SystemConfiguration 框架或其他系统API
        let baseUpload: UInt64 = UInt64.random(in: 1000...50000) // 1KB-50KB
        let baseDownload: UInt64 = UInt64.random(in: 5000...500000) // 5KB-500KB
        
        // 如果VPN连接，模拟更稳定的速度
        if connectionStatus == .connected {
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
    
    // 模拟连接VPN
    func toggleConnection() {
        switch connectionStatus {
        case .disconnected:
            startConnection()
        case .connected:
            disconnect()
        case .connecting, .failed:
            break
        }
    }
    
    private func startConnection() {
        connectionStatus = .connecting
        
        // 模拟连接过程（2-4秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...4)) {
            // 90%成功率
            if Int.random(in: 1...100) <= 90 {
                self.connectionStatus = .connected
                self.startConnectionTimer()
            } else {
                self.connectionStatus = .failed
                // 5秒后重置状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.connectionStatus = .disconnected
                }
            }
        }
    }
    
    private func disconnect() {
        connectionStatus = .disconnected
        stopConnectionTimer()
        connectionTime = "00:00:00"
        dataTransferred = "0 MB"
    }
    
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
    
    func selectServer(_ server: VPNServer) {
        selectedServer = server
    }
}
