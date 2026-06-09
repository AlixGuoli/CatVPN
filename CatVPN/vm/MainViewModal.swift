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
    
    @Published var showResult = false
    @Published var resultStatus: VPNConnectionStatus = .disconnected
    @Published var isServiceUnavailable = false
    @Published var showConnecting = false
    
    @Published var showEmail: Bool = false
    @Published var isShowDisconnect: Bool = false
    @Published var isPrivacyAgreed: Bool = false
    @Published var isBaseConfigReady = false
    @Published var isSplashAdReady = false
    
    @Published var isConnecting: Bool = false
    
    @Published var connectionStatus: VPNConnectionStatus = .disconnected {
        didSet {
            // 同步到GlobalStatus
            GlobalStatus.shared.connectStatus = connectionStatus
            cvLog("status=\(GlobalStatus.shared.connectStatus)")
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
    
    var buttonText: String {
        switch state {
        case .disconnected, .invalid:
            return "Start".localstr()
        case .connecting:
            return "Connecting".localstr()
        case .connected:
            return "Stop".localstr()
        case .disconnecting:
            return "Disconnecting".localstr()
        case .reasserting:
            return "Reasserting".localstr()
        @unknown default:
            return "Unknown".localstr()
        }
    }
    
    var statusText: String {
        switch state {
        case .disconnected:
            return "Disconnected".localstr()
        case .connecting:
            return "Connecting".localstr()
        case .connected:
            return "Connected".localstr()
        case .disconnecting:
            return "Disconnecting".localstr()
        case .invalid:
            return "Invalid".localstr()
        case .reasserting:
            return "Reasserting".localstr()
        @unknown default:
            return "Unknown".localstr()
        }
    }
    
    init() {
        self.state = manager.connectionManager.connection.status
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusDidChange(_:)), name: .NEVPNStatusDidChange, object: nil)
        startSpeedTimer()
        
        // 初始化时使用默认服务器列表
        self.availableServers = VPNServer.availableServers
        
        // 从UserDefaults恢复之前选择的服务器，而不是硬编码为Auto
        self.selectedServer = NodeSelectionStore.selectedServer(from: availableServers)
        
        // 检查隐私状态
        checkPrivacyStatus()
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
        stopConnectionTimer()
        stopSpeedTimer()
    }
    
    // MARK: - 隐私状态管理
    
    private func checkPrivacyStatus() {
        let hasSeenPrivacyPopup = UserDefaults.standard.bool(forKey: "hasSeenPrivacyPopup")
        isPrivacyAgreed = hasSeenPrivacyPopup
        cvLog("privacy agreed=\(isPrivacyAgreed)")
    }
    
    func regainVPN() {
//        manager.loadMAllFromPreferences { error in
//            if error != nil {
//                
//            }
//        }
        manager.loadMAllFromPreferences { [weak self] error in
            guard let self = self, error == nil else {
                cvWarn("load preferences failed")
                return
            }
            
            // 获取当前系统VPN状态
            let currentStatus = self.manager.connectionManager.connection.status
            cvLog("restore status=\(currentStatus)")
            
            // 更新UI状态以反映当前VPN状态
            DispatchQueue.main.async {
                self.state = currentStatus
            }
        }
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        state = VPNConnectionManager.instance().connectionManager.connection.status
        linkLog("NEVPN status=\(state) ui=\(connectionStatus)")
    }
    
    private func updateConnectionStatusIfNeeded() {
        // 只在特定条件下更新UI状态
        switch state {
        case .connected:
            linkLog("connected")
            if self.connectManual {
                checkGG()
            } else {
                connectManual = false
                connectionStatus = .connected
                startConnectionTimer()
            }
        case .disconnected, .invalid:
            linkLog("disconnected")
            connectionStatus = .disconnected
            stopConnectionTimer()
        case .connecting:
            linkLog("connecting")
            connectionStatus = .connecting
        case .disconnecting, .reasserting:
            linkLog("disconnecting")
            connectionStatus = .connecting
        @unknown default:
            linkWarn("unknown status")
            connectionStatus = .failed
        }
    }
    
    func prepare(){
        connectManual = true
        manager.loadMAllFromPreferences() { error in
            linkLog("prepare")
            if error != nil {
                linkWarn("prepare failed")
            } else{
                self.startConnect()
            }
        }
    }
    
    func startConnect(){
        ConnectionRuntimeStore.resetForNewConnection()
        FlowReport.connect(FlowReport.connectStart, sid: ConnectionRuntimeStore.sid)
        self.connectionStatus = .connecting
        Task {
            linkLog("prepare node config")
            do {
                try await prepareServiceCF()
            } catch {
                linkWarn("node config failed: \(error)")
                await MainActor.run {
                    self.connectFailed()
                }
                return
            }

            manager.enableAndConfigureVPNManager() { error in
                guard error == nil else {
                    linkWarn("enable VPN failed")
                    return
                }
                self.manager.startVpnConnection() { error in
                    guard error == nil else {
                        linkWarn("start tunnel failed")
                        return
                    }
                }
            }
        }
    }
    
    func prepareServiceCF() async throws {
        let groupID = NodeSelectionStore.currentServerID
        linkLog("resolve config group=\(groupID)")
        let (encrypted, fromRequest) = try await NodeService.resolveEncryptedConfig(group: groupID, vip: 0)
        guard let json = NodeService.decryptConfig(encrypted) else {
            throw NodeConfigError.decryptFailed
        }

        if fromRequest {
            linkLog("config from API")
            ConnectionRuntimeStore.encryptedConfig = encrypted
            ConnectionRuntimeStore.isFromRequest = true
            FlowReport.status(success: true)
        } else {
            linkLog("config from cache")
            ConnectionRuntimeStore.isFromRequest = false
            FlowReport.status(success: false)
        }

        parseNetConfig(input: json, isValid: fromRequest)
        try await ConnectConfigHandler.shared.savedGroupServiceConfig(serviceConfig: json)
    }
    
    func parseNetConfig(input: String?, isValid: Bool) {
        guard let data = input?.data(using: .utf8) else { return }
        
        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            let bounds = parsed?["outbounds"] as? [[String: Any]]
            
            bounds?.forEach { bound in
                let config = bound["settings"] as? [String: Any]
                let nodes = config?["vnext"] as? [[String: Any]]
                
                nodes?.forEach { node in
                    if let ip = node["address"] as? String {
                        let finalIp = isValid ? ip : "f\(ip)"
                        ConnectionRuntimeStore.ip = finalIp
                    }
                }
            }
        } catch {
            linkWarn("parse outbound failed")
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
        switch connectionStatus {
        case .disconnected, .failed:
            // 首先检查是否为中国地区
            if CatKey.getCountryCode() == "cn" {
                linkLog("blocked region=cn")
                handleChinaRestrictedFlow()
                return
            }
            
            linkLog("show connecting")
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                ForgeHub.shared.warmInventory(tag: "connect")
            }
            // 跳转到连接中页面，而不是直接连接
            self.showConnecting = true
        case .connected:
            isShowDisconnect = true
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                ForgeHub.shared.warmInventory(tag: "connect")
            }
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
        FlowReport.connect(
            FlowReport.connectSuccess,
            ip: ConnectionRuntimeStore.ip,
            sid: ConnectionRuntimeStore.sid
        )
        DispatchQueue.main.async {
            self.resultStatus = .connected
            self.connectionStatus = .connected
            self.startConnectionTimer()
            linkLog("connect success")
            if ConnectionRuntimeStore.isFromRequest,
               let encryptedConfig = ConnectionRuntimeStore.encryptedConfig,
               !encryptedConfig.isEmpty {
                NodeConfigStore.saveEncryptedConfig(encryptedConfig)
            }
            // 先设置结果页状态，再关闭连接中页面，确保直接跳转
            self.showResult = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showConnecting = false
            }
        }
    }
    
    func connectFailed() {
        linkLog("connect failed")
        FlowReport.connect(
            FlowReport.connectFailed,
            ip: ConnectionRuntimeStore.ip,
            sid: ConnectionRuntimeStore.sid
        )
        stopConnect()
        DispatchQueue.main.async {
            self.resultStatus = .failed
            // 先设置结果页状态，再关闭连接中页面，确保直接跳转
            self.showResult = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showConnecting = false
            }
        }
    }
    
    func checkGG() {
        Task {
            let connectionStatus = await CatKey.shared.validateConnectionStatus()
            if connectionStatus {
                linkLog("probe pass")
                await prepareAndNotify()
            } else {
                linkWarn("probe fail")
                connectFailed()
            }
        }
    }
    
    private func prepareAndNotify() async {
        GlobalStatus.shared.connectStatus = .connected
        connectSuccessful()
    }
    
    var netWorkManager = NetworkReachabilityManager()
    func checkNet(completion: @escaping (Bool) -> Void) {
        netWorkManager?.startListening {[weak self] status in
            
            guard let self = self else { return }
            
            switch status {
            case .notReachable:
                goWarn("network unreachable")
            case .unknown:
                goLog("network unknown")
            case .reachable(.ethernetOrWiFi):
                goLog("network wifi")
                self.requestBaseConf(completion: completion)
            case .reachable(.cellular):
                goLog("network cellular")
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
        goLog("init system settings")
        let baseOK = await AppConfigService.refreshSystemSettings()
        goLog("init system settings done ok=\(baseOK)")

        await MainActor.run {
            isBaseConfigReady = baseOK
            isSplashAdReady = false
        }

        guard baseOK else { return false }

        guard VaultRegistry.shared.isForgeEnabled() else {
            goLog("ads disabled, skip ad list and preload")
            return true
        }

        goLog("init ads: list + preload parallel")
        async let adListTask: Void = AppConfigService.refreshAdvertisementList()
        async let preloadTask: Bool = loadSplashInt()
        await adListTask
        let adLoaded = await preloadTask
        goLog("splash preload result=\(adLoaded)")

        await MainActor.run {
            isSplashAdReady = adLoaded
        }
        return true
    }
    
    func loadSplashInt() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var hasResumed = false
                
                ForgeHub.shared.warmInventory(onReady: {
                    if !hasResumed {
                        hasResumed = true
                        adLog("splash preload ok successfully")
                        continuation.resume(returning: true)
                    }
                }, onFailed: {
                    if !hasResumed {
                        hasResumed = true
                        adLog("splash preload fail")
                        continuation.resume(returning: false)
                    }
                })
            }
        }
    }
    
    // MARK: - 广告配置管理
    
    func requestAdsInBackground() {
        Task { await AppConfigService.refreshAdvertisementList() }
    }
    
    // MARK: - 服务器管理
    
    /// 获取服务器列表
    func fetchServers() async {
        let servers = await NodeListService.fetchServers()
        await MainActor.run {
            self.availableServers = servers
            self.selectedServer = NodeSelectionStore.selectedServer(from: servers)
        }
    }
    
    // 选择服务器
    func selectServer(_ server: VPNServer) {
        selectedServer = server
        NodeSelectionStore.save(server)
    }
    
    // MARK: - 配置更新检查
    
    /// 检查并更新配置（仅在后台切前台时调用）
    func checkAndUpdateConfigsIfNeeded() {
        cvLog("check config TTL")
        
        let now = Date()
        
        // 检查 baseconf 配置更新时间（6小时）
        if let baseconfUpdateTime = UserDefaults.standard.object(forKey: CatKey.CAT_BASE_CONF_SAVE_DATE) as? Date {
            let baseconfTimeInterval = now.timeIntervalSince(baseconfUpdateTime)
            let baseconfHours = baseconfTimeInterval / 3600
            
            cvLog("baseconf age=\(String(format: "%.1f", baseconfHours))h")
            
            if baseconfHours >= 6.0 {
                goLog("baseconf expired, refresh")
                Task {
                    await AppConfigService.refreshSystemSettings()
                }
            }
        } else {
            goLog("baseconf missing, refresh")
            Task {
                await AppConfigService.refreshSystemSettings()
            }
        }
        
        // 检查 ads 配置更新时间（4小时）
        if let adsUpdateTime = VaultCache.getAdConfigSaveDate() {
            let adsTimeInterval = now.timeIntervalSince(adsUpdateTime)
            let adsHours = adsTimeInterval / 3600
            
            adLog("ad config age: \(adsHours) hours ago")
            
            if adsHours >= 4.0 {
                adLog("ad config expired (>=4h), updating...")
                requestAdsInBackground()
            }
        } else {
            adLog("ad config missing time found, updating...")
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
            self.isServiceUnavailable = false
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
                self.isServiceUnavailable = true
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
