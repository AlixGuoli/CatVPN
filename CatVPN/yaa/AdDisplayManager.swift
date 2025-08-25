//
//  AdDisplayManager.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/11.
//

import Foundation
import UIKit
import YandexMobileAds

// 广告类型枚举
enum AdType {
    case yandexBanner
    case yandexInt
    case admobInt
}

class AdDisplayManager {
    
    static var shared = AdDisplayManager()
    
    private init() {}
    
    // MARK: - 基础展示方法
    
    func displayYandexInt(from viewController: UIViewController, onClose: (() -> Void)? = nil) {
        AdConfigManager.shared.yanIntCenter.onAdClosed = onClose
        AdConfigManager.shared.yanIntCenter.presentAd(from: viewController, moment: nil)
    }
    
    func displayYandexBanner(from viewController: UIViewController) {
        AdConfigManager.shared.yanBannerCenter.presentAd(from: viewController)
    }
    
    func displayAdmobInt(from viewController: UIViewController, moment: String?) {
        AdConfigManager.shared.admobCenter.presentAd(from: viewController, moment: moment)
    }
    
    // MARK: - 便捷展示方法（合并为一个）
    
    func displayAdFromRoot(type: AdType, moment: String? = nil, onClose: (() -> Void)? = nil) {
        guard let rootVC = getRootViewController() else { return }
        switch type {
        case .yandexBanner:
            displayYandexBanner(from: rootVC)
        case .yandexInt:
            displayYandexInt(from: rootVC, onClose: onClose)
        case .admobInt:
            displayAdmobInt(from: rootVC, moment: moment)
        }
    }
    
    // MARK: - 辅助方法
    
    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
    
    func getCurrentBannerAd() -> AdView? {
        let adView = AdConfigManager.shared.yanBannerCenter.getCurrentAd()
        AdConfigManager.shared.yanBannerCenter.refreshAd()
        return adView
    }
}
