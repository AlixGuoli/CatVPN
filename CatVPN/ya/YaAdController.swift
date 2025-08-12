////
////  YaAdController.swift
////  CatVPN
////
////  Created by Stephen Schaaf on 2025/8/7.
////
//
//import Foundation
//import YandexMobileAds
//class YaAdController{
//    
//    static var instance = YaAdController()
//    
//    
//    static let screenWidth = UIScreen.main.bounds.width
//    static let screenHeight = UIScreen.main.bounds.height
//    
//    private var bannerUnitIDs: [String] = []
//    private var interstitialUnitIDs: [String] = []
//    private var admobUnitIDs: [String] = []
//    
//    let bannerController = BannerAdController()
//    private let interstitialController = InterstitialAdController()
//    private let admobInterstitialViewModel = AdmobInterstitialViewModel()
//    
//    var isAdShowing = false
//    
//    var isAdsDisabled: Bool = true
//    var clickPenetration: Int = 0
//    var clickDelay: Int = 0
//    
//    var adType : [String] = []
//    
//    var isPro = false
//    
//    private init() {
//        isAdShowing = false
//        let defaults = UserDefaults.standard
//        let defaultValues: [String: Any] = [
//            ConstantDancyDefault.DEFAULT_KEY_AD_OFF: false,
//            ConstantDancyDefault.DEFAULT_KEY_AD_PENET: 100,
//            ConstantDancyDefault.DEFAULT_KEY_AD_DELAY: 15
//        ]
//        defaults.register(defaults: defaultValues)
//        
//        initDefaultKey()
//        
//        initType()
//    }
//    
//    func initDefaultKey(){
//        let bannerConfig = UserDefaults.standard.string(forKey: ConstantDancyDefault.DEFAULT_KEY_AD_BANNER) ?? "demo-banner-yandex;demo-banner-yandex"
//        let interstitialConfig = UserDefaults.standard.string(forKey: ConstantDancyDefault.DEFAULT_KEY_AD_INTERSTITIAL) ?? "demo-interstitial-yandex;demo-interstitial-yandex"
//        let admobIntConfig = UserDefaults.standard.string(forKey: ConstantDancyDefault.DEFAULT_KEY_AD_ADMOB) ?? "ca-app-pub-3940256099942544/4411468910"
//        
//        bannerUnitIDs = bannerConfig.components(separatedBy: ";")
//        bannerController.configureAdUnits(bannerUnitIDs)
//        
//        interstitialUnitIDs = interstitialConfig.components(separatedBy: ";")
//        interstitialController.configureAdUnits(interstitialUnitIDs)
//        
//        admobUnitIDs = admobIntConfig.components(separatedBy: ";")
//        admobInterstitialViewModel.configureAdUnits(admobUnitIDs)
//        
//        isPro = UserDefaults.standard.bool(forKey: ConstantDancyDefault.PRO)
//    }
//    
//    func initType(){
//        isAdsDisabled = UserDefaults.standard.bool(forKey: ConstantDancyDefault.DEFAULT_KEY_AD_OFF)
//        clickPenetration = UserDefaults.standard.integer(forKey: ConstantDancyDefault.DEFAULT_KEY_AD_PENET)
//        clickDelay = UserDefaults.standard.integer(forKey: ConstantDancyDefault.DEFAULT_KEY_AD_DELAY)
//        debugPrint("Ad settings - Penetration: \(clickPenetration), Delay: \(clickDelay)")
//        
//        adType = UserDefaults.standard.string(forKey: ConstantDancyDefault.DEFAULT_KEY_ADMOB_TYPE)?.components(separatedBy: ";") ?? []
//    }
//    
//    func updatePro(pro : Bool){
//        self.isPro = pro
//        UserDefaults.standard.set(isPro, forKey: ConstantDancyDefault.PRO)
//    }
//    
//    func configureBannerUnits(_ bannerKey: String?) {
//        guard let key = bannerKey else { return }
//        
//        bannerUnitIDs = key.components(separatedBy: ";")
//        bannerController.configureAdUnits(bannerUnitIDs)
//        UserDefaults.standard.set(key, forKey: ConstantDancyDefault.DEFAULT_KEY_AD_BANNER)
//    }
//    
//    func configureInterstitialUnits(_ interstitialKey: String?) {
//        guard let key = interstitialKey else { return }
//        
//        interstitialUnitIDs = key.components(separatedBy: ";")
//        interstitialController.configureAdUnits(interstitialUnitIDs)
//        UserDefaults.standard.set(key, forKey: ConstantDancyDefault.DEFAULT_KEY_AD_INTERSTITIAL)
//    }
//    
//    func configureAdmobUnits(_ admobKey: String?) {
//        guard let key = admobKey else { return }
//        
//        admobUnitIDs = key.components(separatedBy: ";")
//        admobInterstitialViewModel.configureAdUnits(admobUnitIDs)
//        UserDefaults.standard.set(key, forKey: ConstantDancyDefault.DEFAULT_KEY_AD_ADMOB)
//    }
//    
//    func setAdsEnabled(_ enabled: Bool?,admobTypeString : String?) {
//        if enabled != nil{
//            isAdsDisabled = enabled!
//            UserDefaults.standard.set(isAdsDisabled, forKey: ConstantDancyDefault.DEFAULT_KEY_AD_OFF)
//            debugPrint("Ads enabled: \(String(describing: enabled))")
//        }
//        
//        guard let admobTypeData = admobTypeString else { return }
//        adType = admobTypeData.components(separatedBy: ";")
//        UserDefaults.standard.set(admobTypeData, forKey: ConstantDancyDefault.DEFAULT_KEY_ADMOB_TYPE)
//    }
//    
//    func updateClickSettings(penetration: Int? = nil, delay: Int? = nil) {
//        if let penetration = penetration {
//            clickPenetration = penetration
//            UserDefaults.standard.set(penetration, forKey: ConstantDancyDefault.DEFAULT_KEY_AD_PENET)
//        }
//        
//        if let delay = delay {
//            clickDelay = delay
//            UserDefaults.standard.set(delay, forKey: ConstantDancyDefault.DEFAULT_KEY_AD_DELAY)
//        }
//    }
//    
//    func loadAllAds(scene : String? = nil) {
//        debugPrint("APIClient--- loadAllAds")
//        guard isAdsEnabled else { return }
//        
//        if isYandexEnabled{
//            bannerController.startLoadingAds()
//            interstitialController.startLoadingAds()
//        }
//        
//        if isAdmobEnabled{
//            admobInterstitialViewModel.startLoadingAds()
//        }
//    }
//    
//    func loadBannerAd(onLoaded: (() -> Void)? = nil,
//                      onLoadFailed: (() -> Void)? = nil) {
//        debugPrint("APIClient--- loadBannerAd")
//        if isAdsEnabled && isYandexEnabled {
//            if hasBannerAd(){
//                onLoaded?()
//            }else{
//                bannerController.onAdLoaded = onLoaded
//                bannerController.onAdLoadFailed = onLoadFailed
//                bannerController.startLoadingAds()
//            }
//            //            interstitialController.startLoadingAds()
//        } else {
//            onLoaded?()
//        }
//    }
//    
//    func loadInterstitialAd(onLoaded: (() -> Void)? = nil,
//                            onLoadFailed: (() -> Void)? = nil) {
//        if isAdsEnabled && isYandexEnabled {
//            if hasInterstitialAd(){
//                onLoaded?()
//            }else{
//                interstitialController.onAdReady = onLoaded
//                interstitialController.onAdLoadFailed = onLoadFailed
//                interstitialController.startLoadingAds()
//            }
//            
//        } else {
//            onLoaded?()
//        }
//    }
//    
//    func loadAdmobInt(onLoaded: (() -> Void)? = nil,
//                      onLoadFailed: (() -> Void)? = nil) {
//        if isAdsEnabled && isAdmobEnabled {
//                        admobInterstitialViewModel.onAdLoaded = onLoaded
//                        admobInterstitialViewModel.onAdLoadFailed = onLoadFailed
//                        admobInterstitialViewModel.startLoadingAds()
//        } else {
//            onLoaded?()
//        }
//    }
//    
//    private var isAdsEnabled: Bool {
//        //#if DEBUG
//        //        return true
//        //#endif
//        if isPro{
//            return false
//        }
//        
//        return !isAdsDisabled
//    }
//    
//    private var isAdmobEnabled : Bool{
//        //#if DEBUG
//        //        return true
//        //#endif
//        if adType.contains("a"){
//            if GlobalStatus.shared.connectStatus == .connected {
//                return true
//            }
//        }
//        debugPrint("Configured isAdmobEnabled false")
//        return false
//    }
//    
//    private var isYandexEnabled : Bool{
//        if adType.contains("y"){
//            return true
//        }
//        debugPrint("Configured isYandexEnabled false")
//        return false
//    }
//    
//    func getBannerAd() -> AdView? {
//        let adView = bannerController.getCurrentAd()
//        bannerController.refreshAd()
//        return adView
//    }
//    
//    func hasBannerAd() -> Bool {
//        return bannerController.isAdAvailable()
//    }
//    
//    func hasInterstitialAd() -> Bool {
//        return interstitialController.isAdAvailable()
//    }
//    
//    func hasAdmobAd() -> Bool{
//        if GlobalStatus.shared.connectStatus == .connected {
//            return admobInterstitialViewModel.isAdAvailable()
//        }else{
//            admobInterstitialViewModel.clearAdmobAd()
//            return false
//        }
//    }
//    
//    func hasFullScreenAd() -> Bool {
//        guard isAdsEnabled else { return false }
//        return hasBannerAd() || hasInterstitialAd()
//    }
//    
//    func hasYandexAdmobAd() -> Bool {
//        guard isAdsEnabled else { return false }
//        return hasFullScreenAd() || hasAdmobAd()
//    }
//    
//    func showInterstitialAd(from viewController: UIViewController, onClose: (() -> Void)? = nil) {
//        interstitialController.onAdClosed = onClose
//        interstitialController.displayAd(from: viewController)
//    }
//    
//    func showBannerAd(from viewController: UIViewController) {
//        bannerController.displayAd(from: viewController)
//    }
//    
//    func showAdmobAd(from viewController: UIViewController,scene : String?){
//        admobInterstitialViewModel.displayAd(from: viewController,scene : scene)
//    }
//    
//}
