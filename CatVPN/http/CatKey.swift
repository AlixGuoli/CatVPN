import Foundation
import Alamofire
import Network

class CatKey {
    
    
    static var shared = CatKey()
    
    public init() {}
    
    /// 用户UUID存储key
    static let CAT_USER_UID = "user_uuid"
    
    /// 连接超时时间
    static let CAT_HTTP_TIMEOUT = "CAT_HTTP_TIMEOUT"
    
    /// UserDefault host域名配置
    static let CAT_NOW_HOST_CONF = "CAT_NOW_HOST_CONF"
    
    /// UserDefault host域名配置存储时间
    static let CAT_NOW_HOST_CONF_SAVE_DATE = "CAT_NOW_HOST_CONF_SAVE_DATE"
    
    /// UserDefault getconf配置
    static let CAT_BASE_CONF = "CAT_BASE_CONF"
    
    /// UserDefault getconf配置存储时间
    static let CAT_BASE_CONF_SAVE_DATE = "CAT_BASE_CONF_SAVE_DATE"
    
    /// UserDefaultf getService连接配置
    static let CAT_NOW_SERVICE_CONF = "CAT_NOW_SERVICE_CONF"
    
    /// Git版本存储key
    static let CAT_GIT_VERSION = "CAT_GIT_VERSION"
    
    /// TgLink存储key
    static let CAT_TG_LINK = "CAT_TG_LINK"
    
    /// hotcode 存储key
    static let CAT_HOTCODE = "CAT_HOTCODE"
    
    // MARK: - 用户信息管理
    
    // UUID管理
    static func getUserUUID() -> String {
        let userDefaults = UserDefaults.standard
        
        if let existingUUID = userDefaults.string(forKey: CAT_USER_UID) {
            return existingUUID
        } else {
            // 创建新的UUID
            let newUUID = UUID().uuidString
            userDefaults.set(newUUID, forKey: CAT_USER_UID)
            logDebug("Build new UUID: \(newUUID)")
            return newUUID
        }
    }
    
    // 获取国家代码
    static func getCountryCode() -> String {
        return (Locale.current.region?.identifier ?? "us").lowercased()
    }
    
    // 获取语言代码
    static func getLanguageCode() -> String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    // 获取Bundle ID
    static func getBundleID() -> String {
        return Bundle.main.bundleIdentifier ?? "CatVPN.CatVPN"
    }
    
    // 获取App版本号
    static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    
    func validateConnectionStatus() async -> Bool {
        logDebug("=== Starting VPN connectivity validation ===")
        let configuredTargets = BaseCFHelper.shared.getDetectionServers()?
            .compactMap { ProbeTarget(urlString: $0) } ?? []
        let targets = configuredTargets.isEmpty ? ProbeTarget.defaultTargets : configuredTargets
        logDebug("Using VPN connectivity probe targets, count:", targets.count, configuredTargets.isEmpty ? "default" : "configured")
        
        let verdict = await ConnectivityProber(targets: targets).verify()
        logDebug("VPN connectivity validation result:", verdict.isAlive ? "SUCCESS" : "FAILED", "reason:", verdict.reason.rawValue)
        logDebug("=== VPN connectivity validation completed ===")
        return verdict.isAlive
    }
    
    func validateServiceEndpoint(host: String?, port: Int, timeout: TimeInterval = 8) async -> Bool {
        // 测试服 true：强制 TCP 预检失败（起隧道前，不发 E_FAIL）
        let forcePreflightFailureForDebug = false
        if forcePreflightFailureForDebug {
            logDebug("TCP preflight forced failure for debug")
            return false
        }
        
        let rawHost = (host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let targetHost = rawHost.hasPrefix("f") ? String(rawHost.dropFirst()) : rawHost
        
        guard !targetHost.isEmpty else {
            logDebug("TCP preflight skipped: service host is empty")
            return false
        }
        
        let normalizedPort = UInt16(exactly: port).flatMap { NWEndpoint.Port(rawValue: $0) } ?? NWEndpoint.Port(rawValue: 443)!
        let connection = NWConnection(host: NWEndpoint.Host(targetHost), port: normalizedPort, using: .tcp)
        let lock = NSLock()
        var finished = false
        
        logDebug("TCP preflight start:", "\(targetHost):\(normalizedPort.rawValue)")
        
        return await withCheckedContinuation { continuation in
            func finish(_ success: Bool, message: String) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                connection.cancel()
                logDebug(message)
                continuation.resume(returning: success)
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true, message: "TCP preflight success")
                case .failed(let error):
                    finish(false, message: "TCP preflight failed: \(error.localizedDescription)")
                case .cancelled:
                    finish(false, message: "TCP preflight cancelled")
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                finish(false, message: "TCP preflight timeout after \(timeout)s")
            }
        }
    }
}
