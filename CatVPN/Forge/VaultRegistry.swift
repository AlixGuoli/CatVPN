//
//  VaultRegistry.swift
//  CatVPN
//

import Foundation
import UIKit

class VaultRegistry {

    static var shared = VaultRegistry()

    let yanIntCenter = YanIntCenter()
    let yanEMIntCenter = YanEMIntCenter()

    var isPresenting = false
    var isVip = false

    private var adTypeTokens: [String] {
        VaultCache.getAdsType()?.components(separatedBy: ";") ?? []
    }

    var isMediationMode: Bool {
        adTypeTokens.contains("e")
    }

    private var isYandexIntMode: Bool {
        adTypeTokens.contains("y") && !isMediationMode
    }

    private var isForgeOpen: Bool {
        if isVip {
            adLog("gate closed vip")
            return false
        }
        let isAdsOff = VaultCache.getAdsOff()
        adLog("gate adsOff=\(isAdsOff) type=\(adTypeTokens) em=\(isMediationMode)")
        return !isAdsOff
    }

    private var isIntOpen: Bool {
        isMediationMode || isYandexIntMode
    }

    func isForgeEnabled() -> Bool {
        isForgeOpen && isIntOpen
    }

    private init() {
        isVip = UserDefaults.standard.bool(forKey: VaultCache.Keys.isVip)
    }

    func hasInventory() -> Bool {
        guard isIntOpen else { return false }
        if isMediationMode {
            return yanEMIntCenter.isReady()
        }
        return yanIntCenter.isReady()
    }

    func warmInventory(tag: String? = nil) {
        adLog("preload all moment=\(tag ?? "-")")
        guard isForgeOpen, isIntOpen else {
            adLog("preload skip gate closed")
            return
        }

        if isMediationMode {
            yanEMIntCenter.beginAdLoading(moment: tag)
        } else {
            yanIntCenter.beginAdLoading(moment: tag)
        }
    }

    func warmInventory(onReady: (() -> Void)? = nil, onFailed: (() -> Void)? = nil) {
        guard isForgeOpen, isIntOpen else {
            onFailed?()
            return
        }

        if isMediationMode {
            adLog("preload em")
            if yanEMIntCenter.isReady() {
                onReady?()
            } else {
                yanEMIntCenter.onAdReady = onReady
                yanEMIntCenter.onAdFailed = onFailed
                yanEMIntCenter.beginAdLoading()
            }
            return
        }

        adLog("preload yandex")
        if yanIntCenter.isReady() {
            onReady?()
        } else {
            yanIntCenter.onAdReady = onReady
            yanIntCenter.onAdFailed = onFailed
            yanIntCenter.beginAdLoading()
        }
    }

    func presentFullscreen(from controller: UIViewController, onClose: (() -> Void)? = nil) {
        if isMediationMode {
            yanEMIntCenter.onAdClosed = onClose
            yanEMIntCenter.presentAd(from: controller, moment: nil)
        } else {
            yanIntCenter.onAdClosed = onClose
            yanIntCenter.presentAd(from: controller, moment: nil)
        }
    }
}
