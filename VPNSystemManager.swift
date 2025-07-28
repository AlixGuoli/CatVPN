import Foundation
import NetworkExtension

/// 自定义VPN连接状态，便于UI处理和扩展
enum AppVPNStatus: String, Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed
}

/// UI层VPN管理器，适配差异化TunnelProvider，便于SwiftUI/UIViewController调用
class VPNSystemManager: ObservableObject {
    /// 当前自定义VPN连接状态
    @Published var status: AppVPNStatus = .disconnected
    
    /// 单例
    static let shared = VPNSystemManager()
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusChanged),
            name: .NEVPNStatusDidChange,
            object: nil
        )
        updateStatus()
    }
    
    /// 监听系统VPN状态变化
    @objc private func statusChanged() {
        updateStatus()
    }
    
    /// 刷新当前VPN状态，并映射为自定义状态
    private func updateStatus() {
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            let sysStatus = managers?.first?.connection.status ?? .disconnected
            let mapped = Self.mapStatus(sysStatus)
            DispatchQueue.main.async {
                self.status = mapped
            }
        }
    }
    
    /// 系统状态映射为自定义状态
    static func mapStatus(_ sys: NEVPNStatus) -> AppVPNStatus {
        switch sys {
        case .disconnected, .invalid:
            return .disconnected
        case .connecting:
            return .connecting
        case .connected:
            return .connected
        case .disconnecting:
            return .disconnecting
        case .reasserting:
            return .connecting // 可自定义为reconnecting等
        @unknown default:
            return .failed
        }
    }
    
    /// 准备VPN配置（如无则新建）
    func prepare(completion: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                completion(error)
                return
            }
            let manager = managers?.first ?? NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            // 这里填写你的TunnelProvider扩展的BundleID
            proto.providerBundleIdentifier = "你的TunnelProvider扩展的BundleID"
            proto.serverAddress = "CatVPN" // 只是标识
            manager.protocolConfiguration = proto
            manager.localizedDescription = "我的VPN"
            manager.isEnabled = true
            manager.saveToPreferences { error in
                completion(error)
            }
        }
    }
    
    /// 启动VPN连接
    func connect(completion: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            guard let manager = managers?.first else {
                completion(error ?? NSError(domain: "VPN", code: -1, userInfo: [NSLocalizedDescriptionKey: "No VPN manager"]))
                return
            }
            do {
                try manager.connection.startVPNTunnel()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    /// 停止VPN连接
    func disconnect(completion: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            guard let manager = managers?.first else {
                completion(error ?? NSError(domain: "VPN", code: -1, userInfo: [NSLocalizedDescriptionKey: "No VPN manager"]))
                return
            }
            manager.connection.stopVPNTunnel()
            completion(nil)
        }
    }
    
    /// 一键连接（自动准备+连接）
    func quickConnect(completion: @escaping (Error?) -> Void) {
        prepare { error in
            if let error = error {
                completion(error)
            } else {
                self.connect(completion: completion)
            }
        }
    }
} 