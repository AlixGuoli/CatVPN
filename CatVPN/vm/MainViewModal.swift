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
    private struct TrafficMetrics: Decodable {
        let egressBytes: UInt64
        let ingressBytes: UInt64
    }
    
    enum ConnectionFlowError: LocalizedError {
        case emptyServiceConfig
        case decodeServiceConfigFailed
        case missingServiceEndpoint
        
        var errorDescription: String? {
            switch self {
            case .emptyServiceConfig:
                return "Service config is empty"
            case .decodeServiceConfigFailed:
                return "Service config decode failed"
            case .missingServiceEndpoint:
                return "Service endpoint is missing"
            }
        }
    }
    
    var manager = VPNConnectionManager.instance()
    
    private var connectManual: Bool = false
    private var isProbingConnection: Bool = false
    private var connectGeneration: Int = 0
    private var probeTask: Task<Void, Never>?
    
    @Published var showResult = false
    @Published var resultStatus: VPNConnectionStatus = .disconnected
    @Published var isServiceUnavailable = false
    @Published var showConnecting = false
    
    @Published var isShowRate: Bool = false
    @Published var showEmail: Bool = false
    @Published var isShowDisconnect: Bool = false
    @Published var isPrivacyAgreed: Bool = false
    
    @Published var isConnecting: Bool = false
    
    @Published var connectionStatus: VPNConnectionStatus = .disconnected {
        didSet {
            // 同步到GlobalStatus
            GlobalStatus.shared.connectStatus = connectionStatus
            logDebug("######## GlobalStatus connectStatus: \(GlobalStatus.shared.connectStatus)")
        }
    }
    
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
    private var isUpdatingTrafficMetrics = false
    private var trafficMetricsRequestID = 0
    private var trafficMetricsTimeoutWorkItem: DispatchWorkItem?
    
    // 修复(§3-7-A)：按钮文案与点击分发必须读同一个真值源。
    // handleButtonAction 读 connectionStatus，因此这里也改为读 connectionStatus，
    // 避免在探测窗口/失败瞬间，系统原始状态(state)与派生连接态(connectionStatus)背离时，
    // 出现"显示 Stop 却点击无效"或"显示 Stop 却触发 Start"的错配。
    var buttonText: String {
        switch connectionStatus {
        case .disconnected, .failed:
            return "Start".localstr()
        case .connecting:
            return "Connecting".localstr()
        case .connected:
            return "Stop".localstr()
        }
    }

    var statusText: String {
        switch connectionStatus {
        case .disconnected:
            return "Disconnected".localstr()
        case .connecting:
            return "Connecting".localstr()
        case .connected:
            return "Connected".localstr()
        case .failed:
            return "Connection_Failed".localstr()
        }
    }
    
    init() {
        self.state = manager.connectionManager.connection.status
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusDidChange(_:)), name: .NEVPNStatusDidChange, object: nil)
        
        // 初始化时使用默认服务器列表
        self.availableServers = ServerCFHelper.shared.getDefaultServers()
        
        // 从UserDefaults恢复之前选择的服务器，而不是硬编码为Auto
        self.selectedServer = ServerCFHelper.shared.getCurrentSelectedServer(from: availableServers)
        
        // 检查隐私状态
        checkPrivacyStatus()
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
        probeTask?.cancel()
        stopConnectionTimer()
        stopSpeedTimer()
    }
    
    // MARK: - 隐私状态管理
    
    private func checkPrivacyStatus() {
        let hasSeenPrivacyPopup = UserDefaults.standard.bool(forKey: "hasSeenPrivacyPopup")
        isPrivacyAgreed = hasSeenPrivacyPopup
        logDebug("Privacy status - hasSeenPopup: \(hasSeenPrivacyPopup), isAgreed: \(isPrivacyAgreed)")
    }
    
    func regainVPN() {
//        manager.loadMAllFromPreferences { error in
//            if error != nil {
//                
//            }
//        }
        manager.loadMAllFromPreferences { [weak self] error in
            guard let self = self, error == nil else {
                logDebug("Failed to load VPN preferences: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // 获取当前系统VPN状态
            let currentStatus = self.manager.connectionManager.connection.status
            logDebug("Current VPN status on app start: \(currentStatus)")
            
            // 更新UI状态以反映当前VPN状态
            DispatchQueue.main.async {
                self.state = currentStatus
                logDebug("VPN state restored - status: \(currentStatus)")
            }
        }
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        state = VPNConnectionManager.instance().connectionManager.connection.status
        logDebug("****** VpnStatusDidChange NEVPNConnection state : \(state)")
        logDebug("****** VpnStatusDidChange ConnectionStatus state : \(connectionStatus)")
    }
    
    private func updateConnectionStatusIfNeeded() {
        // 只在特定条件下更新UI状态
        switch state {
        case .connected:
            logDebug("NEVPNStatus: connected")
            if self.connectManual {
                startConnectivityProbeIfNeeded()
            } else {
                connectManual = false
                connectionStatus = .connected
                startConnectionTimer()
                startSpeedTimer()
            }
        case .disconnected, .invalid:
            logDebug("NEVPNStatus: disconnected")
            if isProbingConnection {
                invalidateCurrentProbe()
            }
            connectManual = false
            connectionStatus = .disconnected
            stopConnectionTimer()
            stopSpeedTimer()
            // 修复：连接窗口期内被系统断开（典型如连接层封禁在探测期间打掉隧道，
            // 探测任务被取消、verdict 永不回调），需要主动驱动到失败终态，
            // 否则会永远卡在"连接中"页面。仅在尚未到达任何结果页时触发，
            // 避免误伤"已连接成功后用户主动断开/隧道掉线"的正常场景。
            if showConnecting && !showResult {
                logDebug("System disconnected during connect window, drive to failure terminal state")
                handleConnectionFailure(stopTunnel: false, reportResult: true)
            }
        case .connecting:
            logDebug("NEVPNStatus: connecting")
            connectionStatus = .connecting
        case .disconnecting, .reasserting:
            logDebug("NEVPNStatus: disconnecting")
            if isProbingConnection {
                invalidateCurrentProbe()
            }
            // 拆除期间复位手动连接标志，防止 reasserting->connected 反弹时误走探测分支。
            connectManual = false
            // 注意：此处刻意保持 .connecting（而非 .disconnected），
            // 让 handleButtonAction 在拆除窗口走 default 分支不响应，
            // 阻止隧道拆除中途被再次点击触发新连接（按钮文案由 state 驱动，仍正确显示 Disconnecting）。
            connectionStatus = .connecting
        @unknown default:
            logDebug("NEVPNStatus: failed")
            if isProbingConnection {
                invalidateCurrentProbe()
            }
            connectionStatus = .failed
        }
    }
    
    private func beginConnectAttempt() {
        connectGeneration += 1
        probeTask?.cancel()
        probeTask = nil
        isProbingConnection = false
        connectionStatus = .connecting
        // 修复(§3-7-B)：在"开始新一次连接尝试"的同步入口清除上一轮的结果页标志，
        // 不依赖异步导航通知，避免上一轮成功/断开结果页与本轮连接中页同时生效。
        showResult = false
        logDebug("Begin VPN connect attempt, generation:", connectGeneration)
    }
    
    private func invalidateCurrentProbe() {
        connectGeneration += 1
        probeTask?.cancel()
        probeTask = nil
        isProbingConnection = false
        logDebug("Invalidate VPN connectivity probe, generation:", connectGeneration)
    }
    
    private func startConnectivityProbeIfNeeded() {
        guard !isProbingConnection else {
            logDebug("VPN probe skipped: probe is already running")
            return
        }
        
        isProbingConnection = true
        let generation = connectGeneration
        logDebug("VPN connected, start connectivity probe, generation:", generation)
        
        probeTask = Task { [weak self] in
            let verdict = await Self.makeConnectivityProber().verify()
            guard !Task.isCancelled else {
                logDebug("VPN connectivity probe cancelled before handling verdict")
                return
            }
            
            guard let self = self else { return }
            await MainActor.run {
                self.handleProbeVerdict(verdict, generation: generation)
            }
        }
    }
    
    private func handleProbeVerdict(_ verdict: ProbeVerdict, generation: Int) {
        guard generation == connectGeneration else {
            logDebug("Drop stale VPN probe verdict, verdict generation:", generation, "current generation:", connectGeneration)
            return
        }
        
        guard state == .connected else {
            logDebug("Drop VPN probe verdict because system state is not connected:", state.rawValue)
            invalidateCurrentProbe()
            return
        }
        
        isProbingConnection = false
        probeTask = nil
        
        if verdict.isAlive {
            logDebug("VPN connectivity probe succeeded, generation:", generation)
            Task {
                await self.prepareAndNotify(generation: generation)
            }
        } else {
            logDebug("VPN connectivity probe failed, reason:", verdict.reason.rawValue, "generation:", generation)
            connectFailed(reason: verdict.reason)
        }
    }
    
    private func isConnectionGenerationCurrent(_ generation: Int) -> Bool {
        return generation == connectGeneration && state == .connected
    }
    
    private static func makeConnectivityProber() -> ConnectivityProber {
        let configuredTargets = BaseCFHelper.shared.getDetectionServers()?
            .compactMap { ProbeTarget(urlString: $0) } ?? []
        let targets = configuredTargets.isEmpty ? ProbeTarget.defaultTargets : configuredTargets
        logDebug("Using VPN connectivity probe targets, count:", targets.count, configuredTargets.isEmpty ? "default" : "configured")
        return ConnectivityProber(targets: targets)
    }
    
    func prepare(){
        connectManual = true
        beginConnectAttempt()
        manager.loadMAllFromPreferences() { error in
            logDebug("prepare")
            if error != nil {
                logDebug(error ?? "prepare error")
                self.handleConnectionFailure(stopTunnel: false, reportResult: false)
            } else{
                self.startConnect()
            }
        }
    }
    
    func startConnect(){
        ServiceCFHelper.shared.idConnect = ReportCat.generateRandomId()
        logDebug("VPN authorization completed, report start before requesting service config")
        ReportCat.shared.reportConnect(moment: ReportCat.E_START, sid: ServiceCFHelper.shared.idConnect)
        self.connectionStatus = .connecting
        Task {
            do {
                logDebug("Start requesting service config")
                try await prepareServiceCF()
                
                let host = ServiceCFHelper.shared.ipService
                let port = ServiceCFHelper.shared.portService
                logDebug("Service endpoint parsed:", "\(host ?? "nil"):\(port)")
                
                let reachable = await CatKey.shared.validateServiceEndpoint(host: host, port: port)
                guard reachable else {
                    logDebug("TCP preflight failed, stop before starting VPN tunnel")
                    self.handleConnectionFailure(stopTunnel: false, reportResult: false)
                    return
                }
                
                logDebug("TCP preflight passed, enable VPN manager")
                try await self.enableVPNManager()
                
                logDebug("Start VPN tunnel")
                try await self.startVPNTunnel()
            } catch {
                logDebug("VPN start flow failed:", error.localizedDescription)
                self.handleConnectionFailure(stopTunnel: true, reportResult: true)
            }
        }
    }
    
    private func enableVPNManager() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.enableAndConfigureVPNManager() { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func startVPNTunnel() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.startVpnConnection() { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
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
            ServiceCFHelper.shared.isFromRequest = false
            ReportCat.shared.reportStatus(success: false)
        } else {
            logDebug("Use ServiceCF @@ requset ")
            ServiceCFHelper.shared.nowServiceCF = serviceConfig
            ServiceCFHelper.shared.isFromRequest = true
            ReportCat.shared.reportStatus(success: true)
        }
        logDebug("Decryption Service Config")
        guard let rawServiceConfig = serviceConfig, !rawServiceConfig.isEmpty else {
            throw ConnectionFlowError.emptyServiceConfig
        }
        guard let decodedServiceConfig = FileUtils.decodeSafetyData(rawServiceConfig), !decodedServiceConfig.isEmpty else {
            throw ConnectionFlowError.decodeServiceConfigFailed
        }
        serviceConfig = decodedServiceConfig
        parseNetConfig(input: decodedServiceConfig, isValid: ServiceCFHelper.shared.isFromRequest)
        guard ServiceCFHelper.shared.ipService?.isEmpty == false else {
            throw ConnectionFlowError.missingServiceEndpoint
        }
        try await ConnectConfigHandler.shared.savedGroupServiceConfig(serviceConfig: decodedServiceConfig)
    }
    
    func parseNetConfig(input: String?, isValid: Bool) {
        guard let data = input?.data(using: .utf8) else { return }
        ServiceCFHelper.shared.ipService = nil
        ServiceCFHelper.shared.portService = 443
        
        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            let bounds = parsed?["outbounds"] as? [[String: Any]]
            
            boundsLoop: for bound in bounds ?? [] {
                let config = bound["settings"] as? [String: Any]
                let nodes = config?["vnext"] as? [[String: Any]]
                
                for node in nodes ?? [] {
                    if let ip = node["address"] as? String {
                        let finalIp = isValid ? ip : "f\(ip)"
                        ServiceCFHelper.shared.ipService = finalIp
                        if let port = node["port"] as? Int {
                            ServiceCFHelper.shared.portService = port
                        } else if let port = node["port"] as? NSNumber {
                            ServiceCFHelper.shared.portService = port.intValue
                        }
                        logDebug("Parsed service endpoint:", "\(finalIp):\(ServiceCFHelper.shared.portService)")
                        break boundsLoop
                    }
                }
            }
        } catch {
            logDebug("Parse network config failed: \(error)")
        }
    }
    
    func stopConnect(){
        // 主动、幂等地清理本地状态，不完全依赖系统 .disconnected 通知是否/何时到达，
        // 避免上一次断开未清干净（残留 Timer / probe / 标志位）影响下一次连接。
        invalidateCurrentProbe()
        stopConnectionTimer()
        stopSpeedTimer()
        connectManual = false
        manager.stopVpnConnection() { error in
            guard error == nil else {
                logDebug("stopConnect error:", error?.localizedDescription ?? "Unknown error")
                return
            }
            logDebug("stopConnect success")
        }
    }

    /// 延迟断开（断开前先展示广告的场景）。捕获当前连接代次，到点后若期间已发起新的
    /// 连接尝试（connectGeneration 改变），则跳过这次已过期的断开，避免"死 IP 断开→
    /// 立即重连获取新 IP"时，旧的 3 秒延迟 stopConnect 误杀用户刚建立的新连接。
    func scheduleStopConnect(afterAdDelay delay: TimeInterval) {
        let generation = connectGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            guard generation == self.connectGeneration else {
                logDebug("Skip stale deferred stopConnect, scheduled generation:", generation, "current generation:", self.connectGeneration)
                return
            }
            logDebug("Delay finish *** stopConnect, generation:", generation)
            self.stopConnect()
        }
    }

    func handleButtonAction() {
        switch connectionStatus {
        case .disconnected, .failed:
            // 首先检查是否为中国地区
            if CatKey.getCountryCode() == "cn" {
                logDebug("vm: 检测到中国地区，直接跳转失败页")
                handleChinaRestrictedFlow()
                return
            }
            
            // 连接前判断是否可用
            if BaseCFHelper.shared.isServiceAvailable() {
                logDebug("vm: 服务可用")
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    ADSCenter.shared.prepareAllAd(moment: AdMoment.connect)
                }
                // 跳转到连接中页面，而不是直接连接
                self.showConnecting = true
            } else {
                logDebug("vm: 服务不可用")
                handleRestrictedConnectionFlow()
            }
        case .connected:
            isShowDisconnect = true
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                ADSCenter.shared.prepareAllAd(moment: AdMoment.connect)
            }
        default:
            break
        }
    }
    
    // 连接定时器管理
    private func startConnectionTimer() {
        // 修复：先失效旧 Timer，避免 reasserting 抖动反弹时（.connected -> .reasserting
        // -> .connected）重复创建定时器导致泄漏。同时仅在没有计时基准时才重置 startTime，
        // 使抖动回弹不会把已连接时长归零（stopConnectionTimer 会把 startTime 置 nil，
        // 因此全新连接时仍会正确从 0 开始计时）。
        connectionTimer?.invalidate()
        if startTime == nil {
            startTime = Date()
        }
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
        resetTrafficStats()
    }
    
    private func updateConnectionTime() {
        guard let startTime = startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        connectionTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // 网络速度监测
    private func startSpeedTimer() {
        guard speedTimer == nil else { return }
        speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateNetworkSpeed()
        }
    }
    
    private func stopSpeedTimer() {
        speedTimer?.invalidate()
        speedTimer = nil
    }
    
    private func updateNetworkSpeed() {
        guard state == .connected else {
            resetTrafficStats()
            return
        }

        guard !isUpdatingTrafficMetrics else { return }
        isUpdatingTrafficMetrics = true
        trafficMetricsRequestID += 1
        let requestID = trafficMetricsRequestID
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self,
                  self.trafficMetricsRequestID == requestID,
                  self.isUpdatingTrafficMetrics else {
                return
            }
            logDebug("Traffic metrics request timeout")
            self.isUpdatingTrafficMetrics = false
        }
        trafficMetricsTimeoutWorkItem?.cancel()
        trafficMetricsTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: timeoutWorkItem)
        
        requestTrafficMetrics { [weak self] currentBytes in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.trafficMetricsRequestID == requestID else { return }
                self.trafficMetricsTimeoutWorkItem?.cancel()
                self.trafficMetricsTimeoutWorkItem = nil
                self.isUpdatingTrafficMetrics = false
                guard self.state == .connected, let currentBytes = currentBytes else {
                    self.resetTrafficStats()
                    return
                }
                self.applyTrafficMetrics(currentBytes)
            }
        }
    }

    private func applyTrafficMetrics(_ currentBytes: (upload: UInt64, download: UInt64)) {
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(lastSpeedUpdateTime)
        
        if timeInterval >= 1.0 && (previousUploadBytes > 0 || previousDownloadBytes > 0) {
            let uploadDiff = currentBytes.upload > previousUploadBytes ? currentBytes.upload - previousUploadBytes : 0
            let downloadDiff = currentBytes.download > previousDownloadBytes ? currentBytes.download - previousDownloadBytes : 0
            
            let uploadBytesPerSecond = Double(uploadDiff) / timeInterval
            let downloadBytesPerSecond = Double(downloadDiff) / timeInterval
            
            uploadSpeed = formatSpeed(uploadBytesPerSecond)
            downloadSpeed = formatSpeed(downloadBytesPerSecond)
        }

        lastSpeedUpdateTime = currentTime
        dataTransferred = formatDataSize(currentBytes.upload + currentBytes.download)
        previousUploadBytes = currentBytes.upload
        previousDownloadBytes = currentBytes.download
    }
    
    private func requestTrafficMetrics(completion: @escaping (((upload: UInt64, download: UInt64)?) -> Void)) {
        guard let session = manager.connectionManager.connection as? NETunnelProviderSession,
              let messageData = ServiceDefaults.metricsMessage.data(using: .utf8) else {
            completion(nil)
            return
        }

        do {
            try session.sendProviderMessage(messageData) { responseData in
                guard let responseData = responseData,
                      let metrics = try? JSONDecoder().decode(TrafficMetrics.self, from: responseData) else {
                    completion(nil)
                    return
                }
                completion((upload: metrics.egressBytes, download: metrics.ingressBytes))
            }
        } catch {
            logDebug("Traffic metrics request failed:", error.localizedDescription)
            completion(nil)
        }
    }

    private func resetTrafficStats() {
        trafficMetricsRequestID += 1
        trafficMetricsTimeoutWorkItem?.cancel()
        trafficMetricsTimeoutWorkItem = nil
        previousUploadBytes = 0
        previousDownloadBytes = 0
        lastSpeedUpdateTime = Date()
        isUpdatingTrafficMetrics = false
        uploadSpeed = "0 KB/s"
        downloadSpeed = "0 KB/s"
        dataTransferred = "0 MB"
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

    private func formatDataSize(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value < 1024 {
            return String(format: "%.0f B", value)
        } else if value < 1024 * 1024 {
            return String(format: "%.1f KB", value / 1024)
        } else if value < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", value / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", value / (1024 * 1024 * 1024))
        }
    }
    
    func connectSuccessful() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.connectSuccessful()
            }
            return
        }
        
        guard state == .connected else {
            logDebug("Skip connectSuccessful because system state is not connected:", state.rawValue)
            return
        }
        isProbingConnection = false
        connectManual = false
        probeTask = nil
        reportConnectionResultAfterDelay(moment: ReportCat.E_SUCCESS)
        RatingCenter.shared.connectedTime = Date()
        resultStatus = .connected
        connectionStatus = .connected
        startConnectionTimer()
        startSpeedTimer()
        logDebug("Connect Successful")
        let helper = ServiceCFHelper.shared
        if helper.isFromRequest {
            if let serviceCF = helper.nowServiceCF, !serviceCF.isEmpty {
                logDebug("Save service config to UserDefaults")
                UserDefaults.standard.setValue(serviceCF, forKey: CatKey.CAT_NOW_SERVICE_CONF)
            }
        }
        // 先设置结果页状态，再关闭连接中页面，确保直接跳转
        showResult = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showConnecting = false
        }
    }
    
    func connectFailed() {
        connectFailed(reason: nil)
    }
    
    func connectFailed(reason: ProbeVerdictReason?) {
        if let reason = reason {
            logDebug("Connect Failed with connectivity probe reason:", reason.rawValue)
        }
        handleConnectionFailure(stopTunnel: true, reportResult: true)
    }
    
    private func handleConnectionFailure(stopTunnel: Bool, reportResult: Bool) {
        logDebug("Connect Failed, stopTunnel: \(stopTunnel), reportResult: \(reportResult)")
        invalidateCurrentProbe()
        connectManual = false
        
        if reportResult {
            reportConnectionResultAfterDelay(moment: ReportCat.E_FAIL)
        }
        
        if stopTunnel {
            stopConnect()
        }
        
        DispatchQueue.main.async {
            self.connectionStatus = .failed
            self.resultStatus = .failed
            // 先设置结果页状态，再关闭连接中页面，确保直接跳转
            self.showResult = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showConnecting = false
            }
        }
    }
    
    private func reportConnectionResultAfterDelay(moment: String) {
        let ip = ServiceCFHelper.shared.ipService
        let sid = ServiceCFHelper.shared.idConnect
        logDebug("Schedule connection result report after 2s:", moment)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            logDebug("Report connection result:", moment)
            ReportCat.shared.reportConnect(
                moment: moment,
                ip: ip,
                sid: sid
            )
        }
    }
    
    private func prepareAndNotify(generation: Int) async {
        guard isConnectionGenerationCurrent(generation) else {
            logDebug("Skip prepareAndNotify for stale generation:", generation, "current generation:", connectGeneration)
            return
        }
        
        // 设置状态
        GlobalStatus.shared.connectStatus = .connected
        
        let start = Date()
        logDebug("Start to load Admob ** Start Time: \(start)")
        
        var done = false
        let limit: TimeInterval = 15.0
        
        // 设置超时任务
        let task = DispatchWorkItem { [weak self] in
            guard let self = self, !done else { return }
            guard self.isConnectionGenerationCurrent(generation) else {
                logDebug("Skip connect success after Admob timeout for stale generation:", generation, "current generation:", self.connectGeneration)
                return
            }
            done = true
            let timeoutTime = Date()
            logDebug("Admob load 超时: \(timeoutTime)，耗时: \(timeoutTime.timeIntervalSince(start))")
            self.connectSuccessful()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + limit, execute: task)
        
        // 加载广告
        ADSCenter.shared.prepareAdmobInt(moment: AdMoment.connect) {
            // 成功处理
            DispatchQueue.main.async {
                guard !done else { return }
                guard self.isConnectionGenerationCurrent(generation) else {
                    logDebug("Skip connect success after Admob load for stale generation:", generation, "current generation:", self.connectGeneration)
                    return
                }
                done = true
                task.cancel()
                let end = Date()
                logDebug("Admob load success: \(end)，耗时: \(end.timeIntervalSince(start))")
                self.connectSuccessful()
            }
        } onAdFailed: {
            // 失败处理
            DispatchQueue.main.async {
                guard !done else { return }
                guard self.isConnectionGenerationCurrent(generation) else {
                    logDebug("Skip connect success after Admob failure for stale generation:", generation, "current generation:", self.connectGeneration)
                    return
                }
                done = true
                task.cancel()
                let end = Date()
                logDebug("Admob load failed: \(end)，耗时: \(end.timeIntervalSince(start))")
                self.connectSuccessful()
            }
        }
    }
    
    var netWorkManager = NetworkReachabilityManager()
    func checkNet(completion: @escaping (Bool) -> Void) {
        netWorkManager?.startListening {[weak self] status in
            
            guard let self = self else { return }
            
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
            let success = await performInitialization()
            DispatchQueue.main.async {
                completion(success)
            }
            netWorkManager = nil
        }
    }
    
    func performInitialization() async -> Bool {
        // 1. 先获取 BaseConf（必须等待完成）
        logDebug("Start to request Base Config")
        await HttpUtils.shared.fetchBaseConf()
        logDebug("Over to request Base Config")
        
        // 2. 同时进行：加载广告 + 请求广告接口（不等待广告配置完成）
        requestAdsInBackground()
        
        // 3. 优化广告加载逻辑：优先等待 Banner，如果 Banner 成功则直接返回
        logDebug("Start to load Yandex Ad")
        let result = await loadAdsWithPriority()
        
        logDebug("Over to load Yandex Ad with result: \(result)")
        return result
    }
    
    func loadAdsWithPriority() async -> Bool {
        // 同时开始加载两个广告
        async let bannerAd = loadBannerAd()
        async let interstitialAd = loadInterstitialAd()
        
        // 先等待 Banner 的结果
        let bannerSuccess = await bannerAd
        if bannerSuccess {
            // Banner 加载成功，直接返回
            logDebug("Banner ad loaded successfully ** return now")
            return true
        } else {
            // Banner 加载失败，等待 Interstitial 的结果
            logDebug("Banner ad failed, waiting for Interstitial result")
            let interstitialSuccess = await interstitialAd
            return interstitialSuccess
        }
    }
    
    func loadBannerAd() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var hasResumed = false
                
                ADSCenter.shared.prepareYanBanner {
                    if !hasResumed {
                        hasResumed = true
                        logDebug("Splash Yandex Banner ad loaded successfully")
                        continuation.resume(returning: true)
                    }
                } onAdFailed: {
                    if !hasResumed {
                        hasResumed = true
                        logDebug("Splash Yandex Banner ad load failed")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    func loadInterstitialAd() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var hasResumed = false
                
                ADSCenter.shared.prepareYanInt {
                    if !hasResumed {
                        hasResumed = true
                        logDebug("Splash Yandex Interstitial ad loaded successfully")
                        continuation.resume(returning: true)
                    }
                } onAdFailed: {
                    if !hasResumed {
                        hasResumed = true
                        logDebug("Splash Yandex Interstitial ad load failed")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    // MARK: - 广告配置管理
    
    func requestAdsInBackground() {
        Task {
            logDebug("Start to request Ads")
            await HttpUtils.shared.fetchAds()
            logDebug("Over to request Ads")
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
    
    // MARK: - 配置更新检查
    
    /// 检查并更新配置（仅在后台切前台时调用）
    func checkAndUpdateConfigsIfNeeded() {
        logDebug("Checking config update times...")
        
        let now = Date()
        
        // 检查 baseconf 配置更新时间（6小时）
        if let baseconfUpdateTime = UserDefaults.standard.object(forKey: CatKey.CAT_BASE_CONF_SAVE_DATE) as? Date {
            let baseconfTimeInterval = now.timeIntervalSince(baseconfUpdateTime)
            let baseconfHours = baseconfTimeInterval / 3600
            
            logDebug("Baseconf last update: \(baseconfHours) hours ago")
            
            if baseconfHours >= 6.0 {
                logDebug("Baseconf expired (>=6h), updating...")
                Task {
                    await HttpUtils.shared.fetchBaseConf()
                }
            }
        } else {
            logDebug("No baseconf update time found, updating...")
            Task {
                await HttpUtils.shared.fetchBaseConf()
            }
        }
        
        // 检查 ads 配置更新时间（4小时）
        if let adsUpdateTime = UserDefaults.standard.object(forKey: AdDefaults.CAT_AD_KEY_SAVE_DATE) as? Date {
            let adsTimeInterval = now.timeIntervalSince(adsUpdateTime)
            let adsHours = adsTimeInterval / 3600
            
            logDebug("Ads last update: \(adsHours) hours ago")
            
            if adsHours >= 4.0 {
                logDebug("Ads expired (>=4h), updating...")
                requestAdsInBackground()
            }
        } else {
            logDebug("No ads update time found, updating...")
            requestAdsInBackground()
        }
    }
}

// MARK: - 受限连接
extension MainViewmodel {
    
    /// 处理中国地区限制流程（直接跳转失败页，不出广告，不弹连接中）
    private func handleChinaRestrictedFlow() {
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.resultStatus = .failed
            self.isServiceUnavailable = !BaseCFHelper.shared.isServiceAvailable() // 基于实际服务状态
            self.showResult = true
        }
    }
    
    /// 处理不可用状态下的连接流程（不实际连接，只做UI和广告）
    private func handleRestrictedConnectionFlow() {
        
        // 显示连接中页面
        self.showConnecting = true
        self.connectionStatus = .connecting
        
        // 2秒后显示广告并跳转到不可用页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // 跳转到不可用页面
            DispatchQueue.main.async {
                self.connectionStatus = .disconnected
                self.resultStatus = .failed
                self.isServiceUnavailable = !BaseCFHelper.shared.isServiceAvailable() // 基于实际服务状态
                self.showResult = true
                // 关闭连接中页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showConnecting = false
                }
            }
        }
    }
    
    func handleFailed() {
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.resultStatus = .failed
            // 先设置结果页状态，再关闭连接中页面，确保直接跳转
            self.showResult = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showConnecting = false
            }
        }
    }
}
