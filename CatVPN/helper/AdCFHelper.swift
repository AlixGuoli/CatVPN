//
//  AdCFHelper.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/7.
//

import Foundation

class AdCFHelper {
    static let shared = AdCFHelper()
    
    private init() {
        initializeDefaultValues()
    }
    
    // MARK: - 获取广告配置保存时间
    
    func getAdConfigSaveDate() -> Date? {
        return UserDefaults.standard.object(forKey: AdDefaults.CAT_AD_KEY_SAVE_DATE) as? Date
    }
    
    // MARK: - 保存广告配置时间
    
    func saveAdConfigDate() {
        UserDefaults.standard.set(Date(), forKey: AdDefaults.CAT_AD_KEY_SAVE_DATE)
        logDebug("AdCFHelper saved ad config date to UserDefaults, save time: \(Date())")
    }
    
    // MARK: - 提取广告配置字段
    
    func extractAdConfig(from configString: String) -> [String: Any]? {
        do {
            let jsonData = configString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            return json
        } catch {
            logDebug("AdCFHelper extractAdConfig error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func extractAdMixed(from config: [String: Any]) -> [[String: Any]]? {
        guard let adConfig = config["adConfig"] as? [String: Any],
              let adMixed = adConfig["adMixed"] as? [[String: Any]] else {
            return nil
        }
        return adMixed
    }
    
    // MARK: - 提取具体广告类型配置
    
    func extractYandexBannerConfig(from adMixed: [[String: Any]]) -> (key: String?, penetrate: Int?, clickDelay: Int?)? {
        for ad in adMixed {
            if let name = ad["name"] as? String, name == "Yandex_Banner_List" {
                let key = ad["key"] as? String
                let penetrate = ad["penetrate"] as? Int
                let clickDelay = ad["clickDelayPenet"] as? Int
                return (key, penetrate, clickDelay)
            }
        }
        return nil
    }
    
    func extractYandexIntConfig(from adMixed: [[String: Any]]) -> String? {
        for ad in adMixed {
            if let name = ad["name"] as? String, name == "Yandex_Int_List" {
                return ad["key"] as? String
            }
        }
        return nil
    }
    
    func extractAdmobIntConfig(from adMixed: [[String: Any]]) -> String? {
        for ad in adMixed {
            if let name = ad["name"] as? String, name == "Admob_Int_List" {
                return ad["key"] as? String
            }
        }
        return nil
    }
    
    // MARK: - 保存具体广告配置
    
    func saveYandexBannerKey(_ key: String?) {
        if let key = key {
            UserDefaults.standard.set(key, forKey: AdDefaults.CAT_AD_KEY_YANDEX_BANNER)
            logDebug("AdCFHelper saved Yandex Banner key: \(key)")
        }
    }
    
    func saveYandexIntKey(_ key: String?) {
        if let key = key {
            UserDefaults.standard.set(key, forKey: AdDefaults.CAT_AD_KEY_YANDEX_INT)
            logDebug("AdCFHelper saved Yandex Int key: \(key)")
        }
    }
    
    func saveAdmobIntKey(_ key: String?) {
        if let key = key {
            UserDefaults.standard.set(key, forKey: AdDefaults.CAT_AD_KEY_ADMOB_INT)
            logDebug("AdCFHelper saved AdMob Int key: \(key)")
        }
    }
    
    func savePenetrateSettings(penetrate: Int?, clickDelay: Int?) {
        if let penetrate = penetrate {
            UserDefaults.standard.set(penetrate, forKey: AdDefaults.CAT_AD_KEY_PENETRATE)
            logDebug("AdCFHelper saved penetrate: \(penetrate)")
        }
        
        if let clickDelay = clickDelay {
            UserDefaults.standard.set(clickDelay, forKey: AdDefaults.CAT_AD_KEY_CLICK_DELAY)
            logDebug("AdCFHelper saved clickDelay: \(clickDelay)")
        }
    }
    
    func saveAdsOff(_ isOff: Bool?) {
        if let isOff = isOff {
            UserDefaults.standard.set(isOff, forKey: AdDefaults.CAT_AD_IS_OFF)
            logDebug("AdCFHelper saved adsOff: \(isOff)")
        }
    }
    
    func saveAdsType(_ adsType: String?) {
        if let adsType = adsType {
            UserDefaults.standard.set(adsType, forKey: AdDefaults.CAT_AD_TYPE)
            logDebug("AdCFHelper saved adsType: \(adsType)")
        }
    }
    
    // MARK: - 获取保存的广告配置
    
    func getYandexBannerKey() -> String {
        /// 测试服
        return "ss;ss;demo-banner-yandex"
        //return UserDefaults.standard.string(forKey: AdDefaults.CAT_AD_KEY_YANDEX_BANNER) ?? "demo-banner-yandex;demo-banner-yandex"
    }
    
    func getYandexIntKey() -> String {
        /// 测试服
        return "ss;demo-interstitial-yandex;demo-interstitial-yandex"
        //return UserDefaults.standard.string(forKey: AdDefaults.CAT_AD_KEY_YANDEX_INT) ?? "demo-interstitial-yandex;demo-interstitial-yandex"
    }
    
    func getAdmobIntKey() -> String {
        /// 测试服
        return "ca-app-pub-3940256099942544/4411468910"
        //return UserDefaults.standard.string(forKey: AdDefaults.CAT_AD_KEY_ADMOB_INT) ?? "ca-app-pub-3940256099942544/4411468910"
    }
    
    func getPenetrate() -> Int {
        return UserDefaults.standard.integer(forKey: AdDefaults.CAT_AD_KEY_PENETRATE)
    }
    
    func getClickDelay() -> Int {
        return UserDefaults.standard.integer(forKey: AdDefaults.CAT_AD_KEY_CLICK_DELAY)
    }
    
    func getAdsOff() -> Bool {
        return UserDefaults.standard.bool(forKey: AdDefaults.CAT_AD_IS_OFF)
    }
    
    func getAdsType() -> String? {
        return UserDefaults.standard.string(forKey: AdDefaults.CAT_AD_TYPE)
    }
    
    // MARK: - 初始化默认值（只在第一次调用）
    
    func initializeDefaultValues() {
        // 检查是否已经初始化过
        if UserDefaults.standard.object(forKey: AdDefaults.CAT_AD_KEY_PENETRATE) == nil {
            UserDefaults.standard.set(100, forKey: AdDefaults.CAT_AD_KEY_PENETRATE)
            logDebug("AdCFHelper initialized default penetrate: 100")
        }
        
        if UserDefaults.standard.object(forKey: AdDefaults.CAT_AD_KEY_CLICK_DELAY) == nil {
            UserDefaults.standard.set(15, forKey: AdDefaults.CAT_AD_KEY_CLICK_DELAY)
            logDebug("AdCFHelper initialized default clickDelay: 15")
        }
        
        if UserDefaults.standard.object(forKey: AdDefaults.CAT_AD_IS_OFF) == nil {
            UserDefaults.standard.set(false, forKey: AdDefaults.CAT_AD_IS_OFF)
            logDebug("AdCFHelper initialized default adsOff: false")
        }
        

    }
} 
