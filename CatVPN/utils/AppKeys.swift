import Foundation

class CatKey {

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

    static func getUserUUID() -> String {
        let userDefaults = UserDefaults.standard

        if let existingUUID = userDefaults.string(forKey: CAT_USER_UID) {
            return existingUUID
        } else {
            let newUUID = UUID().uuidString
            userDefaults.set(newUUID, forKey: CAT_USER_UID)
            cvLog("new uid created")
            return newUUID
        }
    }

    static func getCountryCode() -> String {
        return (Locale.current.region?.identifier ?? "us").lowercased()
    }

    static func getLanguageCode() -> String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }

    static func getBundleID() -> String {
        return Bundle.main.bundleIdentifier ?? "CatVPN.CatVPN"
    }

    static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
