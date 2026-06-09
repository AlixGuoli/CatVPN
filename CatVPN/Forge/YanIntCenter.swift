//
//  YanIntCenter.swift
//  CatVPN
//

import Foundation
import YandexMobileAds

class YanIntCenter: NSObject {
    
    private var currentAd: InterstitialAd?
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
    
    func setupAdKeys() {
        let yandexIntKey = VaultCache.getYandexIntKey()
        if !yandexIntKey.isEmpty {
            self.adKeyList = yandexIntKey.components(separatedBy: ";").filter { !$0.isEmpty }
            adLog("yandex keys=\(adKeyList)")
        } else {
            self.adKeyList = []
            adLog("yandex keys empty")
        }
    }
    
    func presentAd(from controller: UIViewController, moment: String?) {
        guard let currentAd = currentAd else {
            onAdClosed?()
            return
        }
        currentAd.show(from: controller)
    }
    
    func isReady() -> Bool {
        return currentAd != nil
    }
    
    func clearAd() {
        currentAd = nil
        adLog("yandex clear")
    }
    
    func beginAdLoading(moment: String? = nil) {
        adLog("yandex load start vpn=\(GlobalStatus.shared.connectStatus)")
        if canBeginLoading() {
            setupAdKeys()
            currentKeyIndex = 0
            guard adKeyList.count > currentKeyIndex else { return }
            
            isLoadingAd = true
            loadBeginTime = Date()
            Task {
                await loadAdRecursively(index: 0, moment: moment)
            }
        }
    }
    
    func reloadAd() {
        currentAd = nil
        beginAdLoading()
    }
    
    private func loadAdRecursively(index: Int, moment: String? = nil) async {
        let adKey = adKeyList[index]
        adLog("yandex load try key=\(adKey) idx=\(index)")
        
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

extension YanIntCenter: InterstitialAdLoaderDelegate, InterstitialAdDelegate {
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        adLog("yandex load ok unit=\(interstitialAd.adInfo?.adUnitId ?? "")")
        isLoadingAd = false
        currentAd = interstitialAd
        currentAd?.delegate = self
        onAdReady?()
    }
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        adLog("yandex load fail unit=\(error.adUnitId ?? "") err=\(error.error.localizedDescription)")
        loadNextAd()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        adLog("yandex show fail err=\(error.localizedDescription)")
        reloadAd()
    }
    
    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        ForgeHub.shared.isPresenting = true
        adLog("yandex shown unit=\(interstitialAd.adInfo?.adUnitId ?? "")")
    }
    
    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        onAdClosed?()
        reloadAd()
        ForgeHub.shared.isPresenting = false
    }
    
    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        onAdClicked?()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {}
}
