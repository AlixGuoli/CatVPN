//
//  ADSCenter.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/11.
//
import Foundation
import UIKit
import YandexMobileAds

class ADSCenter {
    
    static var shared = ADSCenter()
    
    private let configManager = AdConfigManager.shared
    private let displayManager = AdDisplayManager.shared
    
    private init() {}
    
    // MARK: - 保持原有属性可访问
    
    var isShowingAd: Bool {
        get { configManager.isShowingAd }
        set { configManager.isShowingAd = newValue }
    }
    
    var isVip: Bool {
        get { configManager.isVip }
        set { configManager.isVip = newValue }
    }
    
    // 保持原有属性可访问
    var yanBannerCenter: YanBannerCenter { return configManager.yanBannerCenter }
    var yanIntCenter: YanIntCenter { return configManager.yanIntCenter }
    var admobCenter: AdmobCenter { return configManager.admobCenter }
    
    // MARK: - 状态检查方法（保持原名）
    
    func isYanBannerReady() -> Bool { return configManager.checkBannerStatus() }
    func isYanIntReady() -> Bool { return configManager.checkIntStatus() }
    func isAdmobReady() -> Bool { return configManager.checkAdmobStatus() }
    func isYandexAdReady() -> Bool { return configManager.checkYandexAvailability() }
    func isAllAdReady() -> Bool { return configManager.checkOverallAvailability() }
    
    // MARK: - 加载方法（保持原名）
    
    func prepareAllAd(moment: String? = nil) { configManager.loadAllAdvertisements(moment: moment) }
    func prepareYanBanner(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) { configManager.loadBannerAd(onAdReady: onAdReady, onAdFailed: onAdFailed) }
    func prepareYanInt(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) { configManager.loadIntAd(onAdReady: onAdReady, onAdFailed: onAdFailed) }
    func prepareAdmobInt(moment: String? = nil, onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) { configManager.loadAdmobAd(moment: moment, onAdReady: onAdReady, onAdFailed: onAdFailed) }
    
    // MARK: - 展示方法（保持原名）
    
    func showYanInt(from viewController: UIViewController, onClose: (() -> Void)? = nil) { displayManager.displayYandexInt(from: viewController, onClose: onClose) }
    func showYanBanner(from viewController: UIViewController) { displayManager.displayYandexBanner(from: viewController) }
    func showAdmobInt(from viewController: UIViewController, moment: String?) { displayManager.displayAdmobInt(from: viewController, moment: moment) }
    
    // MARK: - 便捷展示方法（保持原名）
    
    func showYanBannerFromRoot() { displayManager.displayAdFromRoot(type: .yandexBanner) }
    func showYanIntFromRoot(onClose: (() -> Void)? = nil) { displayManager.displayAdFromRoot(type: .yandexInt, onClose: onClose) }
    func showAdmobIntFromRoot(moment: String?) { displayManager.displayAdFromRoot(type: .admobInt, moment: moment) }
    
    // MARK: - 获取方法（保持原名）
    
    func getYanBannerAd() -> AdView? { return displayManager.getCurrentBannerAd() }
}
