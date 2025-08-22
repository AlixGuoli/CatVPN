//
//  AdmobCenter.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/7.
//
import GoogleMobileAds

class AdmobCenter: NSObject {
    
    private var currentAd: InterstitialAd?
    private var displayingAd: InterstitialAd?
    private var adKeyList: [String] = []
    private var isLoadingAd = false
    private var loadBeginTime: Date? = nil
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    
    // MARK: - 广告配置和展示
    
    func setupAdKeys() {
        let admobKey = AdCFHelper.shared.getAdmobIntKey()
        if !admobKey.isEmpty {
            self.adKeyList = admobKey.components(separatedBy: ";").filter { !$0.isEmpty }
            logDebug("~~ADSCenter Admob ads Int keys from AdCFHelper: \(adKeyList)")
        } else {
            self.adKeyList = []
            logDebug("~~ADSCenter Admob ads Int no keys found in AdCFHelper")
        }
    }
    
    func presentAd(from controller: UIViewController, moment: String?) {
        guard let currentAd = currentAd else {
            return
        }
        let adKeyId = currentAd.adUnitID
        currentAd.present(from: controller)
        ReportCat.shared.reportAd(moment: ReportCat.E_AD_SHOW, key: adKeyId, adMoment: moment)
    }
    
    func isReady() -> Bool {
        return currentAd != nil
    }
    
    func clearAd() {
        currentAd = nil
        logDebug("~~ADSCenter Admob ads Int clearAd")
    }
    
    // MARK: - 广告加载管理
    
    func beginAdLoading(moment: String? = nil) {
        logDebug("~~ADSCenter Admob ads Int beginAdLoading ** Current connect status: \(GlobalStatus.shared.connectStatus)")
        if canBeginLoading() && GlobalStatus.shared.connectStatus == .connected {
            logDebug("~~ADSCenter Admob ads Int beginAdLoading ** Start")
            // 先从 AdCFHelper 获取最新的广告密钥
            setupAdKeys()
            if !adKeyList.isEmpty {
                isLoadingAd = true
                loadBeginTime = Date()
                Task {
                    await loadAdRecursively(index: 0, moment: moment)
                }
            } else {
                logDebug("~~ADSCenter !!! Admob ads Int beginAdLoading ** Failed - no ad keys available")
                onAdFailed?()
            }
        }
    }
    
    func reloadAd(moment: String? = nil) {
        currentAd = nil
        beginAdLoading(moment: moment)
    }
    
    // MARK: - 私有方法
    
    private func loadAdRecursively(index: Int, moment: String? = nil) async {
        guard index < adKeyList.count else {
            // 所有广告密钥都尝试过了，失败
            logDebug("~~ADSCenter !!! Admob ads Int all ad keys failed")
            isLoadingAd = false
            onAdFailed?()
            return
        }
        
        let adKey = adKeyList[index]
        logDebug("~~ADSCenter Admob ads Int loadAdRecursively ** Start ** adkey: \(adKey) (index: \(index))")
        do {
            ReportCat.shared.reportAd(moment: ReportCat.E_AD_START, adMoment: moment)
            currentAd = try await InterstitialAd.load(with: adKey, request: Request())
            currentAd?.fullScreenContentDelegate = self
            isLoadingAd = false
            onAdReady?()
            ReportCat.shared.reportAd(moment: ReportCat.E_AD_SUCCESS, key: adKey, adMoment: moment)
            logDebug("~~ADSCenter Admob ads Int loadAdRecursively ** Success AdKey: \(adKey)")
        } catch {
            logDebug("~~ADSCenter !!! Admob ads Int loadAdRecursively failed adKey: \(adKey) error: \(error.localizedDescription)")
            // 当前广告密钥失败，递归尝试下一个
            await loadAdRecursively(index: index + 1, moment: moment)
        }
    }
    
    private func canBeginLoading() -> Bool {
        if currentAd != nil {
            return false
        }
        
        if isLoadingAd {
            guard let startTime = loadBeginTime,
                  Date().timeIntervalSince(startTime) > 120 else {
                return false
            }
            return true
        }
        
        return true
    }
}

// MARK: - Admob Delegate
extension AdmobCenter: FullScreenContentDelegate {
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        logDebug("~~ADSCenter Admob ads Show success")
        ADSCenter.shared.isShowingAd = true
        displayingAd = currentAd
        currentAd = nil
        reloadAd(moment: AdMoment.closead)
    }
    
    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
        logDebug("~~ADSCenter Admob ads is Showing")
    }
    
    func adDidRecordClick(_ ad: any FullScreenPresentingAd) {
        logDebug("~~ADSCenter Admob ads is Clicked")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        logDebug("~~ADSCenter Admob ads show error: \(error.localizedDescription)")
        reloadAd()
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        logDebug("~~ADSCenter Admob ads will Close")
        ADSCenter.shared.isShowingAd = false
    }
    
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        logDebug("~~ADSCenter Admob ads is Closed")
    }
}
