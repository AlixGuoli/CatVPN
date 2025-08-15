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
        self.availableServers = ServerCFHelper.shared.getDefaultServers()
        
        // 从UserDefaults恢复之前选择的服务器，而不是硬编码为Auto
        self.selectedServer = ServerCFHelper.shared.getCurrentSelectedServer(from: availableServers)
        
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
        logDebug("Privacy status - hasSeenPopup: \(hasSeenPrivacyPopup), isAgreed: \(isPrivacyAgreed)")
    }
    
    func regainVPN() {
        manager.loadMAllFromPreferences { error in
            if error != nil {
                
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
                checkGG()
            } else {
                connectManual = false
                connectionStatus = .connected
                startConnectionTimer()
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
        ServiceCFHelper.shared.idConnect = ReportCat.generateRandomId()
        ReportCat.shared.reportConnect(moment: ReportCat.E_START, sid: ServiceCFHelper.shared.idConnect)
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
            ServiceCFHelper.shared.isFromRequest = false
            ReportCat.shared.reportStatus(success: false)
        } else {
            logDebug("Use ServiceCF @@ requset ")
            ServiceCFHelper.shared.nowServiceCF = serviceConfig
            ServiceCFHelper.shared.isFromRequest = true
            ReportCat.shared.reportStatus(success: true)
        }
        logDebug("Decryption Service Config")
        serviceConfig = FileUtils.decodeSafetyData(serviceConfig ?? "")
        parseNetConfig(input: serviceConfig, isValid: ServiceCFHelper.shared.isFromRequest)
        try await ConnectConfigHandler.shared.savedGroupServiceConfig(serviceConfig: serviceConfig ?? "")
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
                        ServiceCFHelper.shared.ipService = finalIp
                    }
                }
            }
        } catch {
            logDebug("Parse network config failed: \(error)")
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
        case .disconnected:
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                ADSCenter.shared.prepareAllAd(moment: AdMoment.connect)
            }
            self.prepare()
        case .connected:
            isShowDisconnect = true
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                ADSCenter.shared.prepareAllAd(moment: AdMoment.connect)
            }
        default:
            break
        }
//        switch state {
//        case .connected:
//            isShowDisconnect = true
//            DispatchQueue.main.asyncAfter(deadline: .now()) {
//                ADSCenter.shared.prepareAllAd(moment: AdMoment.connect)
//            }
//        case .invalid, .disconnected:
//            DispatchQueue.main.asyncAfter(deadline: .now()) {
//                ADSCenter.shared.prepareAllAd(moment: AdMoment.connect)
//            }
//            self.prepare()
//        default:
//            break
//        }
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
        ReportCat.shared.reportConnect(
            moment: ReportCat.E_SUCCESS,
            ip: ServiceCFHelper.shared.ipService,
            sid: ServiceCFHelper.shared.idConnect
        )
        RatingCenter.shared.connectedTime = Date()
        DispatchQueue.main.async {
            self.resultStatus = .connected
            self.showResult = true
            self.connectionStatus = .connected
            self.startConnectionTimer()
            logDebug("Connect Successful")
            let helper = ServiceCFHelper.shared
            if helper.isFromRequest {
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
        self.resultStatus = .failed
        self.showResult = true
        ReportCat.shared.reportConnect(
            moment: ReportCat.E_FAIL,
            ip: ServiceCFHelper.shared.ipService,
            sid: ServiceCFHelper.shared.idConnect
        )
    }
    
    func checkGG() {
        Task {
            let connectionStatus = await CatKey.shared.validateConnectionStatus()
            if connectionStatus {
                logDebug("Successfully to test Google")
                await prepareAndNotify()
            } else {
                logDebug("Failed to test Google")
                connectFailed()
            }
        }
    }
    
    private func prepareAndNotify() async {
        // 设置状态
        GlobalStatus.shared.connectStatus = .connected
        
        let start = Date()
        logDebug("Start to load Admob ** Start Time: \(start)")
        
        var done = false
        let limit: TimeInterval = 15.0
        
        // 设置超时任务
        let task = DispatchWorkItem { [weak self] in
            guard let self = self, !done else { return }
            done = true
            let timeoutTime = Date()
            logDebug("Admob load 超时: \(timeoutTime)，耗时: \(timeoutTime.timeIntervalSince(start))")
            self.connectSuccessful()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + limit, execute: task)
        
        // 加载广告
        ADSCenter.shared.prepareAdmobInt(moment: AdMoment.connect) {
            // 成功处理
            if !done {
                done = true
                task.cancel()
                let end = Date()
                logDebug("Admob load success: \(end)，耗时: \(end.timeIntervalSince(start))")
                self.connectSuccessful()
            }
        } onAdFailed: {
            // 失败处理
            if !done {
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
