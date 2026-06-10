//
//  VaultCache.swift
//  CatVPN
//

import Foundation

enum VaultCache {

    enum Keys {
        static let isVip = "CAT_IS_VIP"
        static let isOff = "CAT_AD_IS_OFF"
        static let type = "CAT_AD_TYPE"
        static let yandexInt = "CAT_AD_KEY_YANDEX_INT"
        static let yandexEMInt = "CAT_AD_KEY_YANDEX_EM_INT"
        static let savedAt = "CAT_AD_KEY_SAVE_DATE"
    }

    private static let bootstrapped: Void = {
        if UserDefaults.standard.object(forKey: Keys.isOff) == nil {
            UserDefaults.standard.set(true, forKey: Keys.isOff)
            adLog("cfg default adsOff=true")
        }
    }()

    static func getYandexIntKey() -> String {
        _ = bootstrapped
        /// 测试服
        return "demo-banner-yandex"
        return UserDefaults.standard.string(forKey: Keys.yandexInt) ?? "R-M-16910303-3"
    }

    static func getYandexEMIntKey() -> String {
        _ = bootstrapped
        /// 测试服
        return "demo-banner-yandex"
        return UserDefaults.standard.string(forKey: Keys.yandexEMInt) ?? "R-M-19374584-1"
    }

    static func getAdsOff() -> Bool {
        _ = bootstrapped
        /// 测试服
        return true
        return UserDefaults.standard.bool(forKey: Keys.isOff)
    }

    static func getAdsType() -> String? {
        _ = bootstrapped
        /// 测试服
        return "y;a"
        return UserDefaults.standard.string(forKey: Keys.type)
    }

    static func getAdConfigSaveDate() -> Date? {
        UserDefaults.standard.object(forKey: Keys.savedAt) as? Date
    }

    static func saveAdConfigDate() {
        UserDefaults.standard.set(Date(), forKey: Keys.savedAt)
        adLog("cfg saved at=\(Date())")
    }

    static func saveYandexIntKey(_ key: String?) {
        if let key {
            UserDefaults.standard.set(key, forKey: Keys.yandexInt)
            adLog("cfg yandex key=\(key)")
        }
    }

    static func saveYandexEMIntKey(_ key: String?) {
        if let key {
            UserDefaults.standard.set(key, forKey: Keys.yandexEMInt)
            adLog("cfg em key=\(key)")
        }
    }

    static func saveAdsOff(_ isOff: Bool?) {
        if let isOff {
            UserDefaults.standard.set(isOff, forKey: Keys.isOff)
            adLog("cfg adsOff=\(isOff)")
        }
    }

    static func saveAdsType(_ adsType: String?) {
        if let adsType {
            UserDefaults.standard.set(adsType, forKey: Keys.type)
            adLog("cfg adType=\(adsType)")
        }
    }
}
