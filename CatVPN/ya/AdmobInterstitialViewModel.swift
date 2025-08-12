////
////  AdmobInterstitialViewModel.swift
////  CatVPN
////
////  Created by Stephen Schaaf on 2025/8/7.
////
//
//import Foundation
//import GoogleMobileAds
//
//class AdmobInterstitialViewModel: NSObject, FullScreenContentDelegate {
//    private var interstitialAd: InterstitialAd?
//    
//    private var showAd: InterstitialAd?
//    
//    private var adUnitIDs: [String] = []
//    private var isAdLoading = false
//    
//    private var currentAdIndex = 0
//    private var loadStartTime: Date? = nil
//    
//    var onAdLoaded: (() -> Void)?
//    var onAdLoadFailed: (() -> Void)?
//    
//    func configureAdUnits(_ units: [String]) {
//        self.adUnitIDs = units.filter { !$0.isEmpty }
//    }
//    
////    func displayAd(from controller: UIViewController) {
////        guard let interstitialAd = interstitialAd else {
////            return
////        }
////        interstitialAd.present(from: controller)
////    }
//    
//    func displayAd(from controller: UIViewController,scene : String?) {
//        guard let interstitialAd = interstitialAd else {
//            return
//        }
//        let currentId = interstitialAd.adUnitID
//        
//        interstitialAd.present(from: controller)
//        //ServerLog.shared.logAdShow(key: currentId, scene: scene)
//    }
//    
//    func isAdAvailable() -> Bool {
//        return interstitialAd != nil
//    }
//    
//    func clearAdmobAd() {
//        interstitialAd = nil
//        debugPrint("AdState admob int clearAdmobAd")
//    }
//    
//    func startLoadingAds(scene : String? = nil) {
//        debugPrint("AdState admob int startLoadingAds() \(canLoadAd()) state \(GlobalStatus.shared.connectStatus == .connected)")
//        if canLoadAd() && GlobalStatus.shared.connectStatus == .connected {
//            debugPrint("AdState admob int startLoadingAds ")
//            currentAdIndex = 0
//            if !adUnitIDs.isEmpty {
//                isAdLoading = true
//                loadStartTime = Date()
//                Task{
//                    await loadAd(unitId: adUnitIDs[currentAdIndex],scene: scene)
//                }
//            }else{
//                debugPrint("AdState admob startLoadingAds  onFailure")
//                onAdLoadFailed?()
//            }
//        }
//    }
//    
//    func loadNextAd() {
//        currentAdIndex += 1
//        if currentAdIndex < adUnitIDs.count && GlobalStatus.shared.connectStatus == .connected {
//            Task{
//                await loadAd(unitId: adUnitIDs[currentAdIndex])
//            }
//        } else {
//            handleLoadFailure()
//        }
//    }
//    
//    fileprivate func loadAd(unitId: String,scene : String? = nil) async {
//        do {
//            debugPrint("AdState admob loadAd start: \(unitId)")
//            //ServerLog.shared.logGetAdStart(scene: scene)
//            interstitialAd = try await InterstitialAd.load(
//                with: unitId, request: Request())
//            interstitialAd?.fullScreenContentDelegate = self
//            isAdLoading = false
//            onAdLoaded?()
//            //ServerLog.shared.logGetAdSuccess(key: unitId, scene: scene)
//            debugPrint("AdState admob loadAd success unitId : \(unitId)")
//        } catch {
//            debugPrint("AdState admob Failed unitId \(unitId)  error: \(error.localizedDescription)")
//            loadNextAd()
//        }
//    }
//    
//    func canLoadAd() -> Bool {
//        if interstitialAd != nil {
//            return false
//        }
//        
//        if isAdLoading {
//            guard let startTime = loadStartTime,
//                  Date().timeIntervalSince(startTime) > 120 else {
//                return false
//            }
//            return true
//        }
//        return true
//    }
//    
//    func refreshAd(scene : String? = nil) {
//        interstitialAd = nil
//        startLoadingAds(scene: scene)
//    }
//    
//    func handleLoadFailure() {
//        isAdLoading = false
//        onAdLoadFailed?()
//    }
//    
//    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
//        debugPrint("AdState admob \(#function) called")
//    }
//    
//    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
//        debugPrint("AdState admob \(#function) called")
//    }
//    
//    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
//        print("\(#function) AdState admob called with error: \(error.localizedDescription)")
//        // Clear the interstitial ad.
//        refreshAd()
//    }
//    
//    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
//        debugPrint("AdState admob \(#function) called")
//        YaAdController.instance.isAdShowing = true
//        showAd = interstitialAd
//        interstitialAd = nil
//        refreshAd(scene: LogScene.closead)
//    }
//    
//    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        debugPrint("AdState admob \(#function) called")
//        YaAdController.instance.isAdShowing = false
//    }
//    
//    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        debugPrint("AdState admob \(#function) called")
////        onAdClosed?()
//        //        interstitialAd = nil
//        //        refreshAd()
//    }
//    
//}
