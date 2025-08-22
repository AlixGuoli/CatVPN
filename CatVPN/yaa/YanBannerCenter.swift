//
//  BannerCenter.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/11.
//

import Foundation
import YandexMobileAds

class YanBannerCenter: NSObject {
    
    private var bannerView: AdView?
    private var adKeyList: [String] = []
    private var isLoadingAd = false
    private var isAdReady = false
    private var currentKeyIndex = 0
    private var loadBeginTime: Date?
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    
    // MARK: - 广告配置和展示
    
    func setupAdKeys() {
        // 直接从 AdCFHelper 获取 Yandex Banner 广告密钥
        let yandexBannerKey = AdCFHelper.shared.getYandexBannerKey()
        if !yandexBannerKey.isEmpty {
            self.adKeyList = yandexBannerKey.components(separatedBy: ";").filter { !$0.isEmpty }
            logDebug("~~ADSCenter YanBanner ads keys from AdCFHelper: \(adKeyList)")
        } else {
            self.adKeyList = []
            logDebug("~~ADSCenter YanBanner ads no keys found in AdCFHelper")
        }
    }
    
    func presentAd(from viewController: UIViewController) {
        if isReady() {
            let adScreen = CustomBanner()
            adScreen.modalPresentationStyle = .fullScreen
            viewController.present(adScreen, animated: true)
        }
    }
    
    func isReady() -> Bool {
        return isAdReady && bannerView != nil
    }
        
    func getCurrentAd() -> AdView? {
        return isReady() ? bannerView : nil
    }
    
    func clearAd() {
        isAdReady = false
        bannerView = nil
        logDebug("~~ADSCenter YanBanner ads clearAd")
    }
    
    // MARK: - 广告加载管理
    
    func beginAdLoading() {
        logDebug("~~ADSCenter YanBanner ads beginAdLoading ** Start")
        if canBeginLoading() {
            // 先从 AdCFHelper 获取最新的广告密钥
            setupAdKeys()
            if !adKeyList.isEmpty {
                currentKeyIndex = 0
                isLoadingAd = true
                loadBeginTime = Date()
                loadAdRecursively(index: currentKeyIndex)
            } else {
                logDebug("~~ADSCenter !!! YanBanner ads beginAdLoading ** Failed - no ad keys available")
                onAdFailed?()
            }
        }
    }
    
    func refreshAd() {
        clearAd()
        beginAdLoading()
    }
    
    // MARK: - 私有方法
    
    private func loadAdRecursively(index: Int) {
        guard index < adKeyList.count else {
            logDebug("~~ADSCenter !!! YanBanner ads all ad keys failed")
            isLoadingAd = false
            onAdFailed?()
            return
        }
        
        if let startTime = loadBeginTime, Date().timeIntervalSince(startTime) > 120 {
            logDebug("~~ADSCenter !!! YanBanner ads loading timeout")
            isLoadingAd = false
            onAdFailed?()
            return
        }
        
        let adKey = adKeyList[index]
        logDebug("~~ADSCenter YanBanner ads loadAdRecursively ** Start ** adkey: \(adKey) (index: \(index))")
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        var safeAreaInsets = UIEdgeInsets.zero
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            safeAreaInsets = window.safeAreaInsets
        } else {
            logDebug("~~ADSCenter !!! YanBanner ads failed to get safe area insets")
        }
        
        let adjustedHeight = screenHeight - safeAreaInsets.top - safeAreaInsets.bottom
        let bannerSize = BannerAdSize.inlineSize(withWidth: screenWidth, maxHeight: adjustedHeight)
        
        bannerView = AdView(adUnitID: adKey, adSize: bannerSize)
        bannerView?.delegate = self
        bannerView?.translatesAutoresizingMaskIntoConstraints = false
        bannerView?.loadAd()
    }
    
    private func canBeginLoading() -> Bool {
        if isAdReady { return false }
        
        if isLoadingAd {
            guard let startTime = loadBeginTime,
                  Date().timeIntervalSince(startTime) > 100 else {
                return false
            }
            return true
        }
        
        return true
    }
    
    private func loadNextAd() {
        currentKeyIndex += 1
        if currentKeyIndex < adKeyList.count {
            loadAdRecursively(index: currentKeyIndex)
        } else {
            logDebug("~~ADSCenter !!! YanBanner ads all ad keys failed")
            isLoadingAd = false
            onAdFailed?()
        }
    }
    
}

// MARK: - Yandex Banner Delegate
extension YanBannerCenter: AdViewDelegate {
    
    func adViewDidLoad(_ adView: AdView) {
        logDebug("YanBanner ads loadAdRecursively ** Success AdKey: \(adView.adUnitID)")
        isLoadingAd = false
        isAdReady = true
        onAdReady?()
    }
    
    func adViewDidFailLoading(_ adView: AdView, error: Error) {
        logDebug("!!! YanBanner ads loadAdRecursively failed adKey: \(adView.adUnitID) error: \(error.localizedDescription)")
        loadNextAd()
    }
    
    func adViewDidClick(_ adView: AdView) {
        logDebug("YanBanner ads is Clicked")
        onAdClicked?()
    }
}
