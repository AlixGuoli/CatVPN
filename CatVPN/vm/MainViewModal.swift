//
//  MainViewmodel.swift
//  TestNust
//
//  Created by 稻花香 on 2025/3/29.
//

import Foundation
import NetworkExtension

class MainViewmodel: ObservableObject {

    var manager = VPNConnectionManager.instance()

    @Published var showResult = false
    @Published var resultStatus: VPNConnectionStatus = .disconnected
    @Published var isServiceUnavailable = false
    @Published var showConnecting = false

    @Published var showEmail: Bool = false
    @Published var isShowDisconnect: Bool = false
    @Published var isPrivacyAgreed: Bool = false
    @Published var isBaseConfigReady = false
    @Published var isSplashAdReady = false

    @Published var connectionStatus: VPNConnectionStatus = .disconnected {
        didSet {
            GlobalStatus.shared.connectStatus = connectionStatus
            cvLog("status=\(GlobalStatus.shared.connectStatus)")
        }
    }

    @Published var state: NEVPNStatus = VPNConnectionManager.instance().connectionManager.connection.status {
        didSet {
            guard oldValue != state else { return }
            linkStatus.updateConnectionStatusIfNeeded()
        }
    }

    @Published var availableServers: [VPNServer] = []

    @Published var selectedServer: VPNServer = VPNServer(id: -1, name: "Auto", country: "AUTO", flagEmoji: "⚡️", ping: Int.random(in: 10...30))
    @Published var connectionTime: String = "00:00:00"
    @Published var dataTransferred: String = "0 MB"
    @Published var uploadSpeed: String = "0 KB/s"
    @Published var downloadSpeed: String = "0 KB/s"

    private lazy var trafficMeter = TrafficMeter(owner: self)
    private lazy var launchPipeline = LaunchPipeline(owner: self)
    private lazy var linkStatus = LinkStatus(owner: self)
    private lazy var linkFlow = LinkFlow(owner: self, linkStatus: linkStatus)

    private static let linkAnchorKey = "cv.link.session.anchor"

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
        linkStatus.install()
        trafficMeter.startSpeedTimer()

        self.availableServers = VPNServer.availableServers
        self.selectedServer = NodeSelectionStore.selectedServer(from: availableServers)

        checkPrivacyStatus()
    }

    deinit {
        linkStatus.uninstall()
        linkFlow.teardown()
        trafficMeter.teardown()
    }

    private func checkPrivacyStatus() {
        let hasSeenPrivacyPopup = UserDefaults.standard.bool(forKey: "hasSeenPrivacyPopup")
        isPrivacyAgreed = hasSeenPrivacyPopup
        cvLog("privacy agreed=\(isPrivacyAgreed)")
    }

    private func resolveLinkAnchor() -> Date {
        if let systemDate = manager.connectionManager.connection.connectedDate {
            return systemDate
        }
        if let saved = UserDefaults.standard.object(forKey: Self.linkAnchorKey) as? Date {
            return saved
        }
        return Date()
    }

    private func storeLinkAnchor(_ date: Date) {
        UserDefaults.standard.set(date, forKey: Self.linkAnchorKey)
    }

    private func clearLinkAnchor() {
        UserDefaults.standard.removeObject(forKey: Self.linkAnchorKey)
    }

    func beginConnectionTiming() {
        let anchor = resolveLinkAnchor()
        storeLinkAnchor(anchor)
        trafficMeter.startConnectionTimer(anchor: anchor)
    }

    func endConnectionTiming() {
        trafficMeter.stopConnectionTimer()
        clearLinkAnchor()
    }

    func regainVPN() {
        linkStatus.regainVPN()
    }

    func onConnectingPageAppeared() {
        linkFlow.onConnectingPageAppeared()
    }

    func dismissConnectingPageOnly() {
        linkFlow.dismissConnectingPageOnly()
    }

    func stopConnect() {
        linkFlow.stopConnect()
    }

    func handleButtonAction() {
        linkFlow.handleButtonAction()
    }

    func connectSuccessful() {
        linkFlow.connectSuccessful()
    }

    func connectFailed() {
        linkFlow.connectFailed()
    }

    func checkGG() {
        linkFlow.checkGG()
    }

    func checkNet(completion: @escaping (Bool) -> Void) {
        launchPipeline.checkNet(completion: completion)
    }

    func requestBaseConf(completion: @escaping (Bool) -> Void) {
        launchPipeline.requestBaseConf(completion: completion)
    }

    func performInitialization() async -> Bool {
        await launchPipeline.performInitialization()
    }

    func loadSplashInt() async -> Bool {
        await launchPipeline.loadSplashInt()
    }

    func requestAdsInBackground() {
        launchPipeline.requestAdsInBackground()
    }

    func checkAndUpdateConfigsIfNeeded() {
        launchPipeline.checkAndUpdateConfigsIfNeeded()
    }

    func fetchServers() async {
        let servers = await NodeListService.fetchServers()
        await MainActor.run {
            self.availableServers = servers
            self.selectedServer = NodeSelectionStore.selectedServer(from: servers)
        }
    }

    func selectServer(_ server: VPNServer) {
        selectedServer = server
        NodeSelectionStore.save(server)
    }
}
