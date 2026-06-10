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
    private var sdksActivated = false
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        _ = LanguageCenter.shared
        AdBootstrap.migrateLegacyUserIfNeeded()
        AdBootstrap.registerSDKActivator { [weak self] in
            self?.activateSDKsIfNeeded()
        }
        return true
    }

    func activateSDKsIfNeeded() {
        guard AdBootstrap.isAdStackUnlocked, !sdksActivated else { return }
        sdksActivated = true
        adLog("sdk activate")
        initAdmob()
        initYandex()
        initGameAnalytics()
    }

    func initAdmob() {
        MobileAds.shared.start { status in
            let adapterStatuses = status.adapterStatusesByClassName
            let success = adapterStatuses.values.contains { $0.state == .ready }
            if success {
                adLog("sdk admob ready")
            } else {
                adLog("sdk admob not ready")
            }
        }
    }
    
    func initYandex() {
        MobileAds.initializeSDK {
            adLog("sdk yandex ready")
        }
    }
    
    func initGameAnalytics() {
        adLog("sdk ga init")
        goLog("ga init")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

#if DEBUG
        GameAnalytics.setEnabledInfoLog(true)
        GameAnalytics.setEnabledVerboseLog(true)
#else
        GameAnalytics.setEnabledInfoLog(false)
        GameAnalytics.setEnabledVerboseLog(false)
#endif
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
    @State private var isAppStarted = true
    @State private var splashFinishTrigger = false
    @State private var shouldShowStartupAd = false
    
    @StateObject private var vm = MainViewmodel()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                VPNMainView()
                    .environmentObject(vm)
                    .localview()
                if isAppStarted {
                    SplashScreenView(isColdStart: true, finishNow: $splashFinishTrigger) {
                        completeStartup()
                        if shouldShowStartupAd {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showSplashAd()
                            }
                            shouldShowStartupAd = false
                        }
                    }
                        .environmentObject(vm)
                        .background(Color(UIColor.systemBackground).opacity(1.0))
                        .onAppear {
                            goLog("splash cold start")
                            vm.checkNet { success in
                                goLog("init done ok=\(success) splashAd=\(vm.isSplashAdReady)")
                                if success, isAppStarted, vm.isSplashAdReady {
                                    shouldShowStartupAd = true
                                }
                                goLog("enter main")
                                splashFinishTrigger = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                                if isAppStarted {
                                    goLog("splash timeout 20s")
                                    splashFinishTrigger = true
                                }
                            }
                        }
                }
                
                if !isAppStarted && showSplashOnForeground {
                    SplashScreenView(isColdStart: false, finishNow: $splashFinishTrigger) {
                        showSplashOnForeground = false
                    }
                        .background(Color(UIColor.systemBackground).opacity(1.0))
                        .onAppear {
                            goLog("splash warm start")
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                showBackgroundAd()
                            }
                            
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
            cvLog("scene active")
            handleAppDidEnterForeground()
        case .inactive:
            cvLog("scene inactive")
        case .background:
            cvLog("scene background")
            handleAppDidEnterBackground()
        @unknown default:
            cvWarn("scene unknown")
        }
    }
    
    private func handleAppDidEnterForeground() {
        let action = ResumeOverlay.didBecomeActive(
            wasInBackground: wasInBackground,
            isAppStarted: isAppStarted,
            showSplashOnForeground: showSplashOnForeground,
            vm: vm
        )
        if wasInBackground && !isAppStarted {
            wasInBackground = false
            if action == .showWarmSplash {
                showSplashOnForeground = true
            }
        }
    }
    
    
    private func handleAppDidEnterBackground() {
        wasInBackground = true
    }
    
    private func showSplashAd() {
        guard vm.isPrivacyAgreed else {
            adLog("splash skip privacy")
            return
        }
        
        let forge = ForgeHub.shared
        adLog("splash show try")
        if forge.hasInventory() {
            adLog("splash show int")
            forge.presentFullscreen()
        }
    }
    
    private func showBackgroundAd() {
        guard vm.isPrivacyAgreed else {
            adLog("splash skip privacy")
            return
        }
        
        let forge = ForgeHub.shared
        if forge.hasInventory() {
            adLog("splash warm show int")
            forge.presentFullscreen()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showSplashOnForeground = false
            }
        } else {
            adLog("splash warm no inventory")
        }
    }
    
    private func completeStartup() {
        goLog("startup complete")
        DispatchQueue.main.async {
            self.isAppStarted = false
            goLog("warm splash enabled")
        }
    }
}

