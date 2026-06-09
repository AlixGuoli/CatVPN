//
//  YanEMIntCenter.swift
//  CatVPN
//

import Foundation
import YandexMobileAds

class YanEMIntCenter: NSObject {

    private var currentAd: InterstitialAd?
    private var adKeyList: [String] = []
    private var isLoadingAd = false
    private var loadBeginTime: Date?
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
        let emKey = VaultCache.getYandexEMIntKey()
        if !emKey.isEmpty {
            adKeyList = emKey.components(separatedBy: ";").filter { !$0.isEmpty }
            adLog("em keys=\(adKeyList)")
        } else {
            adKeyList = []
            adLog("em keys empty")
        }
    }

    func presentAd(from controller: UIViewController, moment: String?) {
        guard let currentAd else {
            onAdClosed?()
            return
        }
        currentAd.show(from: controller)
    }

    func isReady() -> Bool {
        currentAd != nil
    }

    func clearAd() {
        currentAd = nil
        adLog("em clear")
    }

    func beginAdLoading(moment: String? = nil) {
        adLog("em load start vpn=\(GlobalStatus.shared.connectStatus)")
        guard canBeginLoading() else { return }

        setupAdKeys()
        currentKeyIndex = 0
        guard !adKeyList.isEmpty else { return }

        isLoadingAd = true
        loadBeginTime = Date()
        Task {
            await loadAdRecursively(index: 0, moment: moment)
        }
    }

    func reloadAd() {
        currentAd = nil
        beginAdLoading()
    }

    private func loadAdRecursively(index: Int, moment: String? = nil) async {
        guard index < adKeyList.count else { return }
        let adKey = adKeyList[index]
        adLog("em load try key=\(adKey) idx=\(index)")
        let config = AdRequestConfiguration(adUnitID: adKey)
        adLoader.loadAd(with: config)
    }

    private func canBeginLoading() -> Bool {
        if isReady() { return false }

        if isLoadingAd {
            guard let startTime = loadBeginTime else { return false }
            return Date().timeIntervalSince(startTime) > 100
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

extension YanEMIntCenter: InterstitialAdLoaderDelegate, InterstitialAdDelegate {

    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        adLog("em load ok unit=\(interstitialAd.adInfo?.adUnitId ?? "")")
        isLoadingAd = false
        currentAd = interstitialAd
        currentAd?.delegate = self
        onAdReady?()
    }

    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        adLog("em load fail unit=\(error.adUnitId ?? "") err=\(error.error.localizedDescription)")
        loadNextAd()
    }

    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        adLog("em show fail err=\(error.localizedDescription)")
        reloadAd()
    }

    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        ForgeHub.shared.isPresenting = true
        adLog("em shown unit=\(interstitialAd.adInfo?.adUnitId ?? "")")
    }

    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        onAdClosed?()
        ForgeHub.shared.isPresenting = false
        reloadAd()
    }

    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        onAdClicked?()
    }

    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {}
}
