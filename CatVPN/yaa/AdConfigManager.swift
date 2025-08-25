//
//  AdConfigManager.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/11.
//

import Foundation
import UIKit
import YandexMobileAds

class AdConfigManager {
    
    static var shared = AdConfigManager()

    let admobCenter = AdmobCenter()
    let yanIntCenter = YanIntCenter()
    let yanBannerCenter = YanBannerCenter()
    
    var isShowingAd = false
    var isVip = false

    private var isAdsOpen: Bool {
        // 测试服 关闭广告
        //return false
        
        if isVip {
            logDebug("~~ADSCenter isAdsOpen: false. It's Vip")
            return false
        }
        let isAdsOff = AdCFHelper.shared.getAdsOff()
        let adType = AdCFHelper.shared.getAdsType()?.components(separatedBy: ";") ?? []
        logDebug("~~ADSCenter isAdsOff: \(isAdsOff)")
        logDebug("~~ADSCenter adType: \(adType)")
        return !isAdsOff
    }

    private var isYandexOpen: Bool {
        let adType = AdCFHelper.shared.getAdsType()?.components(separatedBy: ";") ?? []
        if adType.contains("y"){
            return true
        }
        logDebug("~~ADSCenter isYandexOpen: false")
        return false
    }

    private var isAdmobOpen: Bool {
        let adType = AdCFHelper.shared.getAdsType()?.components(separatedBy: ";") ?? []
        if adType.contains("a"){
            if GlobalStatus.shared.connectStatus == .connected {
                return true
            }
        }
        logDebug("~~ADSCenter isAdmobOpen: false")
        return false
    }
    
    private init() {
        isVip = UserDefaults.standard.bool(forKey: AdDefaults.CAT_IS_VIP)
    }

    // MARK: - 状态检查方法（重命名）
    
    func checkBannerStatus() -> Bool {
        return yanBannerCenter.isReady()
    }
    
    func checkIntStatus() -> Bool {
        return yanIntCenter.isReady()
    }
    
    func checkAdmobStatus() -> Bool {
        if GlobalStatus.shared.connectStatus == .connected {
            return admobCenter.isReady()
        }else{
            admobCenter.clearAd()
            return false
        }
    }
    
    func checkYandexAvailability() -> Bool {
        guard isAdsOpen else { return false }
        return checkBannerStatus() || checkIntStatus()
    }
    
    func checkOverallAvailability() -> Bool {
        guard isAdsOpen else { return false }
        return checkYandexAvailability() || checkAdmobStatus()
    }
    
    // MARK: - 广告加载管理（重命名）
    
    func loadAllAdvertisements(moment: String? = nil) {
        logDebug("~~ADSCenter loadAllAds ** moment: \(String(describing: moment))")
        guard isAdsOpen else {
            logDebug("~~ADSCenter loadAllAds - ads disabled")
            return
        }
        
        if isYandexOpen {
            yanBannerCenter.beginAdLoading()
            yanIntCenter.beginAdLoading()
        }
        
        if isAdmobOpen {
            admobCenter.beginAdLoading(moment: moment)
        }
    }
    
    func loadBannerAd(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        logDebug("~~ADSCenter load Yandex Banner")
        if isAdsOpen && isYandexOpen {
            if checkBannerStatus() {
                onAdReady?()
            } else {
                yanBannerCenter.onAdReady = onAdReady
                yanBannerCenter.onAdFailed = onAdFailed
                yanBannerCenter.beginAdLoading()
            }
        } else {
            onAdReady?()
        }
    }
    
    func loadIntAd(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        logDebug("~~ADSCenter load Yandex Int")
        if isAdsOpen && isYandexOpen {
            if checkIntStatus() {
                onAdReady?()
            } else {
                yanIntCenter.onAdReady = onAdReady
                yanIntCenter.onAdFailed = onAdFailed
                yanIntCenter.beginAdLoading()
            }
        } else {
            onAdReady?()
        }
    }
    
    func loadAdmobAd(moment: String? = nil, onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        logDebug("~~ADSCenter load Admob Int")
        if isAdsOpen && isAdmobOpen {
            admobCenter.onAdReady = onAdReady
            admobCenter.onAdFailed = onAdFailed
            admobCenter.beginAdLoading(moment: moment)
        } else {
            onAdReady?()
        }
    }
}
