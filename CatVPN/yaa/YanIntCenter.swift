//
//  YanIntCenter.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/7.
//
import Foundation
import YandexMobileAds

class YanIntCenter: NSObject {
    
    private var currentAd: InterstitialAd?
    private var displayingAd: InterstitialAd?
    private var adKeyList: [String] = []
    private var isLoadingAd = false
    private var loadBeginTime: Date? = nil
    private var currentKeyIndex = 0
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    var onAdClosed: (() -> Void)?
    
    private lazy var adLoader: InterstitialAdLoader = {
        let loader = InterstitialAdLoader()
        loader.delegate = self
        return loader
    }()
    
    // MARK: - 广告配置和展示
    
    func setupAdKeys() {
        let yandexIntKey = AdCFHelper.shared.getYandexIntKey()
        if !yandexIntKey.isEmpty {
            self.adKeyList = yandexIntKey.components(separatedBy: ";").filter { !$0.isEmpty }
            logDebug("YanInt ads keys from AdCFHelper: \(adKeyList)")
        } else {
            self.adKeyList = []
            logDebug("YanInt no keys found in AdCFHelper")
        }
    }
    
    func presentAd(from controller: UIViewController, moment: String?) {
        guard let currentAd = currentAd else {
            onAdClosed?()
            return
        }
        let adKeyId = currentAd.adInfo?.adUnitId ?? ""
        currentAd.show(from: controller)
        //ServerLog.shared.logAdShow(key: adKeyId, scene: moment)
    }
    
    func isReady() -> Bool {
        return currentAd != nil
    }
    
    func getCurrentAd() -> InterstitialAd? {
        return isReady() ? currentAd : nil
    }
    
    func clearAd() {
        currentAd = nil
        logDebug("YanInt clearAd")
    }
    
    // MARK: - 广告加载管理
    
    func beginAdLoading(moment: String? = nil) {
        logDebug("YanInt beginAdLoading ** Current connect status: \(GlobalStatus.shared.connectStatus)")
        if canBeginLoading() {
            // 先从 AdCFHelper 获取最新的广告密钥
            setupAdKeys()
            currentKeyIndex = 0
            guard adKeyList.count > currentKeyIndex else { return }
            
            logDebug("YanInt beginAdLoading ** Start")
            isLoadingAd = true
            loadBeginTime = Date()
            Task {
                await loadAdRecursively(index: 0, moment: moment)
            }
        }
    }
    
    func reloadAd(moment: String? = nil) {
        currentAd = nil
        beginAdLoading(moment: moment)
    }
    
    // MARK: - 私有方法
    
    private func loadAdRecursively(index: Int, moment: String? = nil) async {
        let adKey = adKeyList[index]
        logDebug("YanInt loadAdRecursively ** Start ** adkey: \(adKey) (index: \(index))")
        
        let config = AdRequestConfiguration(adUnitID: adKey)
        adLoader.loadAd(with: config)
    }
    
    private func canBeginLoading() -> Bool {
        if isReady() { return false }
        
        if isLoadingAd {
            guard let startTime = loadBeginTime else { return false }
            let elapsedTime = Date().timeIntervalSince(startTime)
            return elapsedTime > 100
        }
        
        return true
    }
    
    private func handleLoadFailure() {
        isLoadingAd = false
        onAdFailed?()
    }
    
    private func loadNextAd() {
        currentKeyIndex += 1
        if currentKeyIndex < adKeyList.count {
            Task {
                await loadAdRecursively(index: currentKeyIndex)
            }
        } else {
            handleLoadFailure()
        }
    }
}

// MARK: - Yandex Delegate
extension YanIntCenter: InterstitialAdLoaderDelegate, InterstitialAdDelegate {
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        logDebug("YanInt loadAdRecursively ** Success AdKey: \(interstitialAd.adInfo?.adUnitId ?? "")")
        isLoadingAd = false
        currentAd = interstitialAd
        currentAd?.delegate = self
        onAdReady?()
    }
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        logDebug("!!! YanInt loadAdRecursively failed adKey: \(error.adUnitId ?? "") error: \(error.error.localizedDescription)")
        loadNextAd()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        logDebug("YanInt show failed: \(error.localizedDescription)")
        reloadAd()
    }
    
    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        ADSCenter.shared.isShowingAd = true
        logDebug("YanInt ad shown: \(interstitialAd.adInfo?.adUnitId ?? "")")
    }
    
    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        onAdClosed?()
        reloadAd()
        ADSCenter.shared.isShowingAd = false
    }
    
    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        onAdClicked?()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {
        // Handle impression tracking if needed
    }
} 
