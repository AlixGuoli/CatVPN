import Foundation

class CatKey {
    
    /// 用户UUID存储key
    static let CAT_USER_UID = "user_uuid"
    
    /// 连接超时时间
    static let CAT_HTTP_TIMEOUT = "CAT_HTTP_TIMEOUT"
    
    /// 本地UserDefault配置
    static let CAT_LOCAL_HOST_CONF = "CAT_LOCAL_HOST_CONF"
    
    /// 本地UserDefault配置存储时间
    static let CAT_LOCAL_HOST_CONF_SAVE_DATE = "CAT_LOCAL_HOST_CONF_SAVE_DATE"
    
    /// Git版本存储key
    static let CAT_GIT_VERSION = "CAT_GIT_VERSION"
    
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
            logDebug("创建新UUID: \(newUUID)")
            return newUUID
        }
    }
    
    // 获取国家代码
    static func getCountryCode() -> String {
        return Locale.current.region?.identifier ?? "US"
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
    
}
