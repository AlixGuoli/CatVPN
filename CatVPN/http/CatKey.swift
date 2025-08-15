import Foundation
import Alamofire

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
        /// 测试服
        return "ru"
        //return Locale.current.region?.identifier ?? "US"
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
        logDebug("=== Starting to test Google ===")
        
        var targetUrls: [String] = []
        
        if let serverList = BaseCFHelper.shared.getDetectionServers(),
           !serverList.isEmpty {
            targetUrls = serverList
            logDebug("Using server list for validation, count:", serverList.count)
        } else {
            targetUrls = ["",""]
            logDebug("Using fallback URLs for validation")
        }
        
        logDebug("Target URLs:", targetUrls)
        
        let syncGroup = DispatchGroup()
        var connectionEstablished = false
        var pendingRequests: [URLSessionTask] = []
        var requestUrlMapping: [URLSessionTask: String] = [:]
        
        logDebug("Starting concurrent network requests...")
        
        for url in targetUrls {
            syncGroup.enter()
            let networkTask = AF.request(url, method: .get)
                .validate(statusCode: 0..<1000)
                .response { response in
                    switch response.result {
                    case .success:
                        logDebug("Network check SUCCESS for URL:", url)
                        connectionEstablished = true
                        AF.session.getAllTasks { tasks in
                            tasks.forEach { task in
                                if let url = requestUrlMapping[task] {
                                    logDebug("Cancelling task for URL:", url)
                                }
                                task.cancel()
                            }
                        }
                    case .failure(let error):
                        logDebug("Network check FAILED for URL:", url, "Error:", error.localizedDescription)
                    }
                    syncGroup.leave()
                }
            if let task = networkTask.task {
                pendingRequests.append(task)
                requestUrlMapping[task] = url
                logDebug("Added network task for URL:", url)
            }
        }
        
        logDebug("Waiting for network responses with 10 second timeout...")
        let timeoutResult = syncGroup.wait(timeout: .now() + 10)
        
        if timeoutResult == .timedOut {
            logDebug("Network validation TIMEOUT - cancelling all tasks")
            AF.session.getAllTasks { tasks in
                tasks.forEach { task in
                    if let url = requestUrlMapping[task] {
                        logDebug("Cancelling timed out task for URL:", url)
                    }
                    task.cancel()
                }
            }
        } else {
            logDebug("Network validation completed within timeout")
        }
        
        logDebug("Network validation result:", connectionEstablished ? "SUCCESS" : "FAILED")
        logDebug("=== Network connectivity validation completed ===")
        
        return connectionEstablished
    }
}
