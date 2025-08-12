//
//  ADSCenter.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/11.
//
import Foundation
import UIKit
import YandexMobileAds

class ADSCenter {
    
    static var shared = ADSCenter()

    let admobCenter = AdmobCenter()
    let yanIntCenter = YanIntCenter()
    let yanBannerCenter = YanBannerCenter()
    
    var isShowingAd = false
    var isVip = false
    var isAdsOff: Bool = true
    var adType : [String] = []

    private var isAdsOpen: Bool {
        if isVip {
            logDebug("isAdsOpen: false. It's Vip")
            return false
        }
        logDebug("isAdsOff: \(isAdsOff)")
        return !isAdsOff
    }

    private var isYandexOpen: Bool {
        if adType.contains("y"){
            return true
        }
        logDebug("isYandexOpen: false")
        return false
    }

    private var isAdmobOpen: Bool {
        if adType.contains("a"){
            if GlobalStatus.shared.connectStatus == .connected {
                return true
            }
        }
        logDebug("isAdmobOpen: false")
        return false
    }
    
    private init() {
        isVip = UserDefaults.standard.bool(forKey: AdDefaults.CAT_IS_VIP)
        isAdsOff = UserDefaults.standard.bool(forKey: AdDefaults.CAT_AD_IS_OFF)
        adType = UserDefaults.standard.string(forKey: AdDefaults.CAT_AD_TYPE)?.components(separatedBy: ";") ?? []
    }

    func isYanBannerReady() -> Bool {
        return yanBannerCenter.isReady()
    }
    
    func isYanIntReady() -> Bool {
        return yanIntCenter.isReady()
    }
    
    func isAdmobReady() -> Bool {
        if GlobalStatus.shared.connectStatus == .connected {
            return admobCenter.isReady()
        }else{
            admobCenter.clearAd()
            return false
        }
    }
    
    func isYandexAdReady() -> Bool {
        guard isAdsOpen else { return false }
        return isYanBannerReady() || isYanIntReady()
    }
    
    func isAllAdReady() -> Bool {
        guard isAdsOpen else { return false }
        return isYandexAdReady() || isAdmobReady()
    }
    
    // MARK: - 广告加载管理
    
    func prepareAllAd(scene: String? = nil) {
        logDebug("ADSCenter loadAllAds")
        guard isAdsOpen else { 
            logDebug("ADSCenter loadAllAds - ads disabled")
            return 
        }
        
        if isYandexOpen {
            yanBannerCenter.beginAdLoading()
            yanIntCenter.beginAdLoading()
        }
        
        if isAdmobOpen {
            admobCenter.beginAdLoading()
        }
    }
    
    func prepareYanBanner(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        logDebug("ADSCenter load Yandex Banner")
        if isAdsOpen && isYandexOpen {
            if isYanBannerReady() {
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
    
    func prepareYanInt(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        logDebug("ADSCenter load Yandex Int")
        if isAdsOpen && isYandexOpen {
            if isYanIntReady() {
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
    
    func prepareAdmobInt(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        logDebug("ADSCenter load Admob Int")
        if isAdsOpen && isAdmobOpen {
            admobCenter.onAdReady = onAdReady
            admobCenter.onAdFailed = onAdFailed
            admobCenter.beginAdLoading()
        } else {
            onAdReady?()
        }
    }
    
    // MARK: - 广告展示
    
    func showYanInt(from viewController: UIViewController, onClose: (() -> Void)? = nil) {
        yanIntCenter.onAdClosed = onClose
        yanIntCenter.presentAd(from: viewController, moment: nil)
    }
    
    func showYanBanner(from viewController: UIViewController) {
        yanBannerCenter.presentAd(from: viewController)
    }
    
    func showAdmobInt(from viewController: UIViewController, scene: String?) {
        admobCenter.presentAd(from: viewController, moment: scene)
    }
    
    // MARK: - 便捷展示方法
    
    func showYanBannerFromRoot() {
        if let rootVC = getRootViewController() {
            showYanBanner(from: rootVC)
        }
    }
    
    func showYanIntFromRoot(onClose: (() -> Void)? = nil) {
        if let rootVC = getRootViewController() {
            showYanInt(from: rootVC, onClose: onClose)
        }
    }
    
    func showAdmobIntFromRoot(scene: String?) {
        if let rootVC = getRootViewController() {
            showAdmobInt(from: rootVC, scene: scene)
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
    
    // MARK: - 广告获取方法
    
    func getYanBannerAd() -> AdView? {
        let adView = yanBannerCenter.getCurrentAd()
        yanBannerCenter.refreshAd()
        return adView
    }
    
}
