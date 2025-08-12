////
////  InterstitialAdController.swift
////  CatVPN
////
////  Created by Stephen Schaaf on 2025/8/7.
////
//
//import Foundation
//import YandexMobileAds
//
//class InterstitialAdController:NSObject, InterstitialAdLoaderDelegate,InterstitialAdDelegate{
//    
//    private var currentAd: InterstitialAd?
//    private var isAdLoading = false
//   
//    private var currentAdIndex = 0
//    private var loadStartTime: Date?
//    private var adUnitIDs: [String] = []
//    
//    // Callbacks
//    var onAdReady: (() -> Void)?
//    var onAdLoadFailed: (() -> Void)?
//    var onAdClicked: (() -> Void)?
//    var onAdClosed: (() -> Void)?
//    
//    private lazy var adLoader: InterstitialAdLoader = {
//        let loader = InterstitialAdLoader()
//        loader.delegate = self
//        return loader
//    }()
//    
//    func configureAdUnits(_ units: [String]) {
//        self.adUnitIDs = units
////#if DEBUG
////        self.adUnitIDs = ["demo-interstitial-yandex"]
////#endif
//        debugPrint("AdState int units: \(adUnitIDs)")
//    }
//    
//    func startLoadingAds() {
//        if canLoadAd() {
//            currentAdIndex = 0
//            guard adUnitIDs.count > currentAdIndex else { return }
//            
//            isAdLoading = true
//            loadStartTime = Date()
//            loadAd(unitID: adUnitIDs[currentAdIndex])
//        }
//    }
//    
//    func isAdAvailable() -> Bool {
//        return currentAd != nil
//    }
//    
//    func getCurrentAd() -> InterstitialAd? {
//        return isAdAvailable() ? currentAd : nil
//    }
//    
//    func refreshAd() {
//        currentAd = nil
//        startLoadingAds()
//    }
//    
//    func displayAd(from viewController: UIViewController) {
//        guard let ad = currentAd else {
//            onAdClosed?()
//            return
//        }
//        ad.show(from: viewController)
//    }
//    
//    private func canLoadAd() -> Bool {
//        if isAdAvailable() { return false }
//        
//        if isAdLoading {
//            guard let startTime = loadStartTime else { return false }
//            let elapsedTime = Date().timeIntervalSince(startTime)
//            return elapsedTime > 100
//        }
//        
//        return true
//    }
//    
//    private func handleLoadFailure() {
//        isAdLoading = false
//        onAdLoadFailed?()
//    }
//    
//    private func loadNextAd() {
//        currentAdIndex += 1
//        if currentAdIndex < adUnitIDs.count {
//            loadAd(unitID: adUnitIDs[currentAdIndex])
//        } else {
//            handleLoadFailure()
//        }
//    }
//    
//    private func loadAd(unitID: String) {
//        debugPrint("AdState Interstitial Loading unit ID: \(unitID)")
//        let config = AdRequestConfiguration(adUnitID: unitID)
//        adLoader.loadAd(with: config)
//    }
//    
//    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
//        debugPrint("AdState Interstitial success unit ID: \(interstitialAd.adInfo?.adUnitId ?? "")")
//        isAdLoading = false
//        self.currentAd = interstitialAd
//        self.currentAd?.delegate = self
//        onAdReady?()
//    }
//    
//    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
//        debugPrint("AdState Interstitial failed for unit: \(error.adUnitId ?? ""), error: \(error.error.localizedDescription)")
//        loadNextAd()
//    }
//    
//    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
//        debugPrint("AdState Interstitial show failed: \(error.localizedDescription)")
//        refreshAd()
//    }
//    
//    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
//        YaAdController.instance.isAdShowing = true
//        debugPrint("AdState Interstitial ad shown: \(interstitialAd.adInfo?.adUnitId ?? "")")
//    }
//    
//    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
//        onAdClosed?()
//        refreshAd()
//        YaAdController.instance.isAdShowing = false
//    }
//    
//    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
//        onAdClicked?()
//    }
//    
//    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {
//        // Handle impression tracking if needed
//    }
//    
//}
