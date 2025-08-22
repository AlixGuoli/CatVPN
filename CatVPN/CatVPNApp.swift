//
//  CatVPNApp.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/11.
//

import SwiftUI
import GoogleMobileAds
import YandexMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
    
    let gameKey = "6314cf102784579085d957185ecdc4d2"
    let secretKey = "6e9d0598ea329a950701b175fd139e2f32f8ad33"
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // 初始化语言
        _ = LanguageCenter.shared
        
        initAdmob()
        initYandex()
        initGameAnalytics()
        return true
    }
    
    func initAdmob() {
        MobileAds.shared.start { status in
            let adpterStatuses = status.adapterStatusesByClassName
            let success = adpterStatuses.values.contains { $0.state == .ready }
            
            if success {
                logDebug("Admob 初始化成功")
            } else {
                logDebug("Admob 初始化失败")
            }
        }
    }
    
    func initYandex() {
        MobileAds.initializeSDK {
            logDebug("Yandex 初始化成功")
        }
    }
    
    func initGameAnalytics() {
        logDebug("initGameAnalytics")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
       
        // Enable log
        GameAnalytics.setEnabledInfoLog(true)
        GameAnalytics.setEnabledVerboseLog(true)
        GameAnalytics.configureAutoDetectAppVersion(true)
        GameAnalytics.configureBuild(version)
        GameAnalytics.initialize(withGameKey: gameKey, gameSecret: secretKey)
    }
}

@main
struct CatVPNApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplashOnForeground = false
    @State private var wasInBackground = false
    @State private var isAppStarted = true  // 启动状态
    @State private var splashFinishTrigger = false
    @State private var shouldShowStartupAd = false
    // 回退：不再通过触发补齐动画关闭
    
    @StateObject private var vm = MainViewmodel()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                VPNMainView()
                    .environmentObject(vm)
                    .localview()   // 确保整个应用都能响应语言变化
                // 启动阶段覆盖页
                if isAppStarted {
                    SplashScreenView(isColdStart: true, finishNow: $splashFinishTrigger) {
                        completeStartup()
                        if shouldShowStartupAd {
                            // 延迟展示广告，避免与切换动画竞争
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showSplashAd()
                            }
                            shouldShowStartupAd = false
                        }
                    }
                        .environmentObject(vm)
                        .background(Color(UIColor.systemBackground).opacity(1.0)) // 适配暗黑模式的完全不透明背景
                        .onAppear {
                            logDebug("~~ADSCenter SplashScreen ** Splash Screen shown from ** Start App")
                            // 启动配置检查
                            vm.checkNet { success in
                                logDebug("~~ADSCenter SplashScreen ** Initial check completed: \(success)")
                                if success {
                                    // 标记待展示广告，等进度补齐后再展示
                                    if isAppStarted {
                                        logDebug("~~ADSCenter SplashScreen ** 标记启动页广告，等待进度补齐后展示")
                                        shouldShowStartupAd = true
                                    }
                                }
                                logDebug("~~ADSCenter SplashScreen ** 触发补齐进入主页")
                                splashFinishTrigger = true
                            }
                            
                            // 20秒超时自动进入主页
                            DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                                if isAppStarted {
                                    logDebug("~~ADSCenter SplashScreen ** Initial splash timeout (20s), entering main view (complete to 100%)")
                                    splashFinishTrigger = true
                                }
                            }
                        }
                }
                
                // 后台返回覆盖页
                if !isAppStarted && showSplashOnForeground {
                    SplashScreenView(isColdStart: false, finishNow: $splashFinishTrigger) {
                        showSplashOnForeground = false
                    }
                        .background(Color(UIColor.systemBackground).opacity(1.0)) // 适配暗黑模式的完全不透明背景
                        .onAppear {
                            logDebug("~~ADSCenter SplashScreen ** Splash Screen shown from ** background")
                            
                            // 2秒后展示广告
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                showBackgroundAd()
                            }
                            
                            // 3秒后自动关闭
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                splashFinishTrigger = true
                            }
                        }
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            logDebug("******** App entered foreground")
            handleAppDidEnterForeground()
        case .inactive:
            logDebug("******** App became inactive")
        case .background:
            logDebug("******** App entered background")
            handleAppDidEnterBackground()
        @unknown default:
            logDebug("******** Unknown scene phase")
        }
    }
    
    private func handleAppDidEnterForeground() {
        // App 进入前台时的处理
        logDebug("******** App isAppStarted: \(isAppStarted) & wasInBackground: \(wasInBackground) & showSplashOnForeground \(showSplashOnForeground)")
        
        // 只有在 App 启动完成后才显示从后台回来的 Splash 页面
        if wasInBackground && !isAppStarted {
            let adCenter = ADSCenter.shared
            // 拉广告
            adCenter.prepareAllAd(moment: AdMoment.foreground)
            // 检查并更新配置（如果需要）
            vm.checkAndUpdateConfigsIfNeeded()
            
            // 检查隐私状态
            guard vm.isPrivacyAgreed else {
                logDebug("~~ADSCenter SplashScreen ** Privacy not agreed, skip showing splash ads")
                wasInBackground = false
                return
            }
            
            // 检查连接状态
            if vm.connectionStatus == .connecting {
                logDebug("~~ADSCenter SplashScreen ** Returning from background, but VPN is connecting, skip splash screen")
                wasInBackground = false
                return
            }
            
            // 检查是否有广告正在展示
            if !adCenter.isShowingAd {
                // 检查是否有广告可以展示
                if adCenter.isAllAdReady() {
                    logDebug("~~ADSCenter SplashScreen ** Returning from background, showing splash screen")
                    showSplashOnForeground = true
                    wasInBackground = false
                } else {
                    logDebug("~~ADSCenter SplashScreen ** Returning from background, but no ads available, skip splash screen")
                    wasInBackground = false
                }
            } else {
                logDebug("~~ADSCenter SplashScreen ** Returning from background, but ad is showing, skip splash screen")
                wasInBackground = false
            }
        }
    }
    
    
    private func handleAppDidEnterBackground() {
        // App 进入后台时的处理
        //logDebug("******** App did enter background")
        wasInBackground = true
    }
    
    // MARK: - 启动相关方法
    
    private func showSplashAd() {
        // 只有在隐私同意后才展示启动页广告
        guard vm.isPrivacyAgreed else {
            logDebug("SplashScreen ** Privacy not agreed, skip showing splash ads")
            return
        }
        
        let adCenter = ADSCenter.shared
        logDebug("SplashScreen ** Start to show ad")
        if adCenter.isYanBannerReady() {
            logDebug("SplashScreen ** Yandex Banner is Ready ** Show Banner")
            adCenter.showYanBannerFromRoot()
        } else if adCenter.isYanIntReady() {
            logDebug("SplashScreen ** Yandex Banner is not Ready ** Show Int")
            adCenter.showYanIntFromRoot()
        }
    }
    
    private func showBackgroundAd() {
        // 只有在隐私同意后才展示后台返回广告
        guard vm.isPrivacyAgreed else {
            logDebug("SplashScreen ** Privacy not agreed, skip showing background ads")
            return
        }
        
        let adCenter = ADSCenter.shared
        
        // 检查是否有广告可以展示，优先级顺序：Admob > Yandex Banner > Yandex Int
        if adCenter.isAllAdReady() {
            // 按优先级展示广告，广告展示成功，立即关闭 Splash 页面
            if adCenter.isAdmobReady() {
                logDebug("SplashScreen ** Showing Admob ad from splash")
                adCenter.showAdmobIntFromRoot(moment: AdMoment.foreground)
                // 广告展示成功，立即关闭 Splash 页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showSplashOnForeground = false
                }
            } else if adCenter.isYanBannerReady() {
                logDebug("SplashScreen ** Showing Yandex Banner ad from splash")
                adCenter.showYanBannerFromRoot()
                // 广告展示成功，立即关闭 Splash 页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showSplashOnForeground = false
                }
            } else if adCenter.isYanIntReady() {
                logDebug("SplashScreen ** Showing Yandex Int ad from splash")
                adCenter.showYanIntFromRoot()
                // 广告展示成功，立即关闭 Splash 页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showSplashOnForeground = false
                }
            }
        } else {
            logDebug("SplashScreen ** No ads available, will close at natural 3s timeout")
        }
    }
    
    private func completeStartup() {
        logDebug("SplashScreen ** Completing startup process")
        DispatchQueue.main.async {
            self.isAppStarted = false
            logDebug("SplashScreen ** App startup completed, background splash enabled")
        }
    }
}


