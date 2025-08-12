////
////  BannerAdController.swift
////  CatVPN
////
////  Created by Stephen Schaaf on 2025/8/7.
////
//
//import Foundation
//import YandexMobileAds
//
//class BannerAdController:NSObject, AdViewDelegate{
//    
//    private var bannerView: AdView?
//    private var adUnitIDs: [String] = []
//    private var isAdLoading = false
//    private var isAdReady = false
//    private var currentAdIndex = 0
//    private var loadStartTime: Date?
//    
//    
//    var onAdLoaded: (() -> Void)?
//    var onAdLoadFailed: (() -> Void)?
//    var onAdClicked: (() -> Void)?
//    
//    
//    func displayAd(from viewController: UIViewController){
//        if isAdAvailable(){
//            let adScreen = BannerScreen()
//            adScreen.modalPresentationStyle = .fullScreen
//            viewController.present(adScreen, animated: true)
//        }else{
//            return
//        }
//    }
//    
//    
//    func configureAdUnits(_ units: [String]) {
//        self.adUnitIDs = units
//        
////#if DEBUG
////        self.adUnitIDs = ["demo-banner-yandex"]
////#endif
//        debugPrint("AdState banner units: \(adUnitIDs)")
//    }
//    
//    func startLoadingAds() {
//        if canLoadAd() {
//            currentAdIndex = 0
//            guard adUnitIDs.count > currentAdIndex else { return }
//            isAdLoading = true
//            loadStartTime = Date()
//            loadAd(unitID: adUnitIDs[currentAdIndex])
//        }
//    }
//    
//    func isAdAvailable() -> Bool {
//        return isAdReady && bannerView != nil
//    }
//    
//    func getCurrentAd() -> AdView? {
//        return isAdAvailable() ? bannerView : nil
//    }
//    
//    func refreshAd() {
//        isAdReady = false
//        bannerView = nil
//        startLoadingAds()
//    }
//    
//    private func canLoadAd() -> Bool {
//        if isAdReady { return false }
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
//        debugPrint("APIClient--- AdState banner failed")
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
//        debugPrint("APIClient--- AdState banner start ad unit ID: \(unitID)")
//        
//        let screenWidth = YaAdController.screenWidth
//        let screenHeight = YaAdController.screenHeight
//        
//        var safeAreaInsets = UIEdgeInsets.zero
//        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//           let window = windowScene.windows.first {
//            safeAreaInsets = window.safeAreaInsets
//        } else {
//            debugPrint("APIClient--- AdState banner safe area insets")
//        }
//        
//        let adjustedHeight = screenHeight - safeAreaInsets.top - safeAreaInsets.bottom
//        let bannerSize = BannerAdSize.inlineSize(withWidth: screenWidth, maxHeight: adjustedHeight)
//        
//        bannerView = AdView(adUnitID: unitID, adSize: bannerSize)
//        bannerView?.delegate = self
//        bannerView?.translatesAutoresizingMaskIntoConstraints = false
//        bannerView?.loadAd()
//    }
//    
//    func adViewDidLoad(_ adView: AdView) {
//        debugPrint("APIClient--- AdState banner success ad unit ID: \(adView.adUnitID)")
//        isAdLoading = false
//        isAdReady = true
//        onAdLoaded?()
//    }
//    
//    func adViewDidFailLoading(_ adView: AdView, error: Error) {
//        debugPrint("APIClient--- AdState banner failed unit: \(adView.adUnitID), error: \(error.localizedDescription)")
//        loadNextAd()
//    }
//    
//    func adViewDidClick(_ adView: AdView) {
//        onAdClicked?()
//    }
//}
