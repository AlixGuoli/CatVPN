//
//  AdsUtils.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/24.
//
import SwiftUI
import GoogleMobileAds
import YandexMobileAds
import Foundation

class AdsUtils: NSObject, ObservableObject {
 
    @Published var isAdmobLoading = false
    @Published var isAdmobShowing = false
    
    @Published var isYandexLoading = false
    @Published var isYandexShowing = false
    
    typealias admobInter = GoogleMobileAds.InterstitialAd
    typealias yandexInter = YandexMobileAds.InterstitialAd

    var admobIntAd: admobInter?
    private let admobIntId = "ca-app-pub-3940256099942544/4411468910"
    
    var yandexIntAd: yandexInter?
    private let yandexIntId = "demo-interstitial-yandex"
    
    private lazy var adLoader: InterstitialAdLoader = {
        let loader = InterstitialAdLoader()
        loader.delegate = self
        return loader
    }()
    
    override init() {
        super.init()
        
    }
    
    func loadIntAdmob() {
        // 检查是否正在加载
        if isAdmobLoading {
            logDebug("Admob ** 插页广告正在加载中")
            return
        }
        
        // 检查是否已有广告
        if admobIntAd != nil {
            logDebug("Admob ** 插页广告已存在，无需重复加载")
            return
        }
        
        logDebug("开始加载 ** Admob ** 插页广告")
        isAdmobLoading = true
        
        Task {
            do {
                admobIntAd = try await admobInter.load(
                    with: admobIntId,
                    request: Request()
                )
                admobIntAd?.fullScreenContentDelegate = self
                
                // 在主线程更新 @Published 属性
                await MainActor.run {
                    isAdmobLoading = false
                }
                logDebug("Admob 插页广告加载成功")
            } catch {
                // 在主线程更新 @Published 属性
                await MainActor.run {
                    isAdmobLoading = false
                    admobIntAd = nil
                }
                logDebug("Admob 插页广告加载失败: \(error.localizedDescription)")
            }
        }
    }
    
    func showIntAdmob() {
        guard let admobIntAd = admobIntAd else {
            logDebug("Admob 没有插页广告可以展示 ** 去加载")
            loadIntAdmob()
            return
        }

        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            logDebug("开始展示 Admob 插页广告")
            admobIntAd.present(from: rootVC)
        }
    }
    
    func loadIntYandex() {
        // 检查是否正在加载
        if isYandexLoading {
            logDebug("Yandex ** 插页广告正在加载中")
            return
        }
        
        // 检查是否已有广告
        if yandexIntAd != nil {
            logDebug("Yandex ** 插页广告已存在，无需重复加载")
            return
        }
        
        logDebug("开始加载 ** Yandex ** 插页广告")
        isYandexLoading = true
        let config = AdRequestConfiguration(adUnitID: yandexIntId)
        adLoader.loadAd(with: config)
    }
    
    func showIntYandex() {
        guard let yandexIntAd = yandexIntAd else {
            logDebug("Yandex 没有插页广告可以展示 ** 去加载")
            loadIntYandex()
            return
        }
        
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            logDebug("开始展示 Yandex 插页广告")
            yandexIntAd.show(from: rootVC)
        }
    }
    
}

// MARK: - Admob Delegate
extension AdsUtils: FullScreenContentDelegate {
    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
        logDebug("Admob 广告成功展示")
        self.isAdmobShowing = true
    }
    
    func adDidRecordClick(_ ad: any FullScreenPresentingAd) {
        logDebug("Admob 广告被点击")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        logDebug("Admob 广告展示失败")
        self.isAdmobShowing = false
        self.admobIntAd = nil
    }
    
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        logDebug("Admob 广告已关闭")
        self.isAdmobShowing = false
        self.admobIntAd = nil
        
        logDebug("Admob ** 加载下一次Admob广告 **")
        loadIntAdmob()
    }
}

// MARK: - Yandex Delegate
// InterstitialAdLoaderDelegate
extension AdsUtils: InterstitialAdLoaderDelegate {
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: yandexInter) {
        logDebug("Yandex 插页广告加载成功")
        self.isYandexLoading = false
        self.yandexIntAd = interstitialAd
        self.yandexIntAd?.delegate = self
    }
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        logDebug("Yandex 插页广告加载失败: \(error.description)")
        self.isYandexLoading = false
        self.yandexIntAd = nil
    }
}

// InterstitialAdDelegate
extension AdsUtils: InterstitialAdDelegate {
    func interstitialAdDidShow(_ interstitialAd: yandexInter) {
        logDebug("Yandex 插页广告已展示")
        self.isYandexShowing = true
    }
    
    func interstitialAd(_ interstitialAd: yandexInter, didFailToShowWithError error: Error) {
        logDebug("Yandex 插页广告展示失败: \(error.localizedDescription)")
        self.isYandexShowing = false
        self.yandexIntAd = nil
    }
    
    func interstitialAdDidClick(_ interstitialAd: yandexInter) {
        logDebug("Yandex 插页广告被点击")
    }
    
    func interstitialAdDidDismiss(_ interstitialAd: yandexInter) {
        logDebug("Yandex 插页广告已关闭")
        self.isYandexShowing = false
        self.yandexIntAd = nil
        
        logDebug("Yandex ** 加载下一次Yandex广告 **")
        loadIntYandex()
    }
}
