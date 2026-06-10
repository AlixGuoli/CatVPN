//
//  TrafficMeter.swift
//  CatVPN
//

import Foundation
import NetworkExtension

final class TrafficMeter {

    private weak var owner: MainViewmodel?

    private var connectionTimer: Timer?
    private var speedTimer: Timer?
    private var startTime: Date?

    private var previousUploadBytes: UInt64 = 0
    private var previousDownloadBytes: UInt64 = 0
    private var lastSpeedUpdateTime = Date()

    init(owner: MainViewmodel) {
        self.owner = owner
    }

    func startConnectionTimer(anchor: Date) {
        startTime = anchor
        connectionTimer?.invalidate()
        updateConnectionTime()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateConnectionTime()
        }
    }

    func stopConnectionTimer() {
        guard let owner else { return }
        owner.connectionTime = "00:00:00"
        owner.dataTransferred = "0 MB"
        connectionTimer?.invalidate()
        connectionTimer = nil
        startTime = nil
    }

    func startSpeedTimer() {
        speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNetworkSpeed()
        }
    }

    func stopSpeedTimer() {
        speedTimer?.invalidate()
        speedTimer = nil
    }

    func teardown() {
        stopConnectionTimer()
        stopSpeedTimer()
    }

    private func updateConnectionTime() {
        guard let owner, let startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        owner.connectionTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

        // 模拟数据传输
        let dataInMB = elapsed / 60 * Double.random(in: 1...5)
        owner.dataTransferred = String(format: "%.1f MB", dataInMB)
    }

    private func updateNetworkSpeed() {
        guard let owner else { return }
        let currentBytes = getNetworkBytes(vpnState: owner.state)
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(lastSpeedUpdateTime)

        if timeInterval >= 1.0 && previousUploadBytes > 0 && previousDownloadBytes > 0 {
            let uploadDiff = currentBytes.upload > previousUploadBytes ? currentBytes.upload - previousUploadBytes : 0
            let downloadDiff = currentBytes.download > previousDownloadBytes ? currentBytes.download - previousDownloadBytes : 0

            let uploadSpeed = Double(uploadDiff) / timeInterval
            let downloadSpeed = Double(downloadDiff) / timeInterval

            DispatchQueue.main.async {
                owner.uploadSpeed = self.formatSpeed(uploadSpeed)
                owner.downloadSpeed = self.formatSpeed(downloadSpeed)
            }

            lastSpeedUpdateTime = currentTime
        }

        previousUploadBytes = currentBytes.upload
        previousDownloadBytes = currentBytes.download
    }

    private func getNetworkBytes(vpnState: NEVPNStatus) -> (upload: UInt64, download: UInt64) {
        // 模拟网络数据，因为实际获取系统网络数据需要更复杂的API
        let baseUpload: UInt64 = UInt64.random(in: 1000...50000) // 1KB-50KB
        let baseDownload: UInt64 = UInt64.random(in: 5000...500000) // 5KB-500KB

        // 如果VPN连接，模拟更稳定的速度
        if vpnState == .connected {
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
}
