//
//  LinkFlow.swift
//  CatVPN
//

import Foundation

final class LinkFlow {

    private weak var owner: MainViewmodel?
    private weak var linkStatus: LinkStatus?

    private var connectingPageTimeoutTask: Task<Void, Never>?
    private static let connectingPageTimeoutSeconds: UInt64 = 40

    init(owner: MainViewmodel, linkStatus: LinkStatus) {
        self.owner = owner
        self.linkStatus = linkStatus
    }

    func teardown() {
        cancelConnectingPageTimeout()
    }

    func onConnectingPageAppeared() {
        startConnectingPageTimeout()
        beginConnectFromConnectingPage()
    }

    func dismissConnectingPageOnly() {
        cancelConnectingPageTimeout()
        linkStatus?.connectManual = false
        owner?.showConnecting = false
        linkLog("connecting page closed")
    }

    func startConnect() {
        guard let owner else { return }
        ConnectionRuntimeStore.resetForNewConnection()
        FlowReport.connect(FlowReport.connectStart, sid: ConnectionRuntimeStore.sid)
        owner.connectionStatus = .connecting
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

            owner.manager.enableAndConfigureVPNManager() { error in
                guard error == nil else {
                    linkWarn("enable VPN failed")
                    return
                }
                owner.manager.startVpnConnection() { error in
                    guard error == nil else {
                        linkWarn("start tunnel failed")
                        return
                    }
                }
            }
        }
    }

    func stopConnect() {
        guard let owner else { return }
        owner.manager.enableAndConfigureVPNManager() { error in
            guard error == nil else {
                return
            }

            owner.manager.stopVpnConnection() { error in
                guard error == nil else {
                    return
                }
            }
        }
    }

    func handleButtonAction() {
        guard let owner else { return }
        switch owner.connectionStatus {
        case .disconnected, .failed:
            if CatKey.getCountryCode() == "cn" {
                linkLog("blocked region=cn")
                handleChinaRestrictedFlow()
                return
            }

            linkLog("connect tap, request vpn permission")
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                ForgeHub.shared.warmInventory(tag: "connect")
            }
            owner.manager.ensureVPNPermission { [weak self] error in
                guard let self, let owner = self.owner else { return }
                DispatchQueue.main.async {
                    if error != nil {
                        linkWarn("vpn permission failed")
                        owner.connectionStatus = .disconnected
                        return
                    }
                    linkLog("vpn permission ok, show connecting page")
                    owner.showConnecting = true
                }
            }
        case .connected:
            owner.isShowDisconnect = true
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                ForgeHub.shared.warmInventory(tag: "connect")
            }
        default:
            break
        }
    }

    func connectSuccessful() {
        guard let owner else { return }
        cancelConnectingPageTimeout()
        FlowReport.connect(
            FlowReport.connectSuccess,
            ip: ConnectionRuntimeStore.ip,
            sid: ConnectionRuntimeStore.sid
        )
        DispatchQueue.main.async {
            owner.resultStatus = .connected
            owner.connectionStatus = .connected
            owner.beginConnectionTiming()
            linkLog("connect success")
            if ConnectionRuntimeStore.isFromRequest,
               let encryptedConfig = ConnectionRuntimeStore.encryptedConfig,
               !encryptedConfig.isEmpty {
                NodeConfigStore.saveEncryptedConfig(encryptedConfig)
            }
            owner.showResult = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                owner.showConnecting = false
            }
        }
    }

    func connectFailed() {
        guard let owner else { return }
        cancelConnectingPageTimeout()
        linkLog("connect failed")
        FlowReport.connect(
            FlowReport.connectFailed,
            ip: ConnectionRuntimeStore.ip,
            sid: ConnectionRuntimeStore.sid
        )
        stopConnect()
        DispatchQueue.main.async {
            owner.resultStatus = .failed
            owner.showResult = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                owner.showConnecting = false
            }
        }
    }

    func checkGG() {
        Task {
            defer { linkStatus?.finishProbe() }
            let connectionStatus = await LinkProbe.validateConnection()
            if connectionStatus {
                linkLog("probe pass")
                await prepareAndNotify()
            } else {
                linkWarn("probe fail")
                connectFailed()
            }
        }
    }

    private func beginConnectFromConnectingPage() {
        linkStatus?.connectManual = true
        startConnect()
    }

    private func startConnectingPageTimeout() {
        cancelConnectingPageTimeout()
        connectingPageTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.connectingPageTimeoutSeconds * 1_000_000_000)
            guard !Task.isCancelled, self.owner?.showConnecting == true else { return }
            linkWarn("connecting page timeout 40s")
            dismissConnectingPageOnly()
        }
    }

    private func cancelConnectingPageTimeout() {
        connectingPageTimeoutTask?.cancel()
        connectingPageTimeoutTask = nil
    }

    private func prepareServiceCF() async throws {
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

    private func parseNetConfig(input: String?, isValid: Bool) {
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

    private func prepareAndNotify() async {
        GlobalStatus.shared.connectStatus = .connected
        connectSuccessful()
    }

    private func handleChinaRestrictedFlow() {
        guard let owner else { return }
        DispatchQueue.main.async {
            owner.connectionStatus = .disconnected
            owner.resultStatus = .failed
            owner.isServiceUnavailable = false
            owner.showResult = true
        }
    }
}
