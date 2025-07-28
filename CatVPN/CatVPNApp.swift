//
//  CatVPNApp.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/11.
//

import SwiftUI
//import GoogleMobileAds
//import YandexMobileAds
//
class AppDelegate: NSObject, UIApplicationDelegate {
    
    let gameKey = "6314cf102784579085d957185ecdc4d2"
    let secretKey = "6e9d0598ea329a950701b175fd139e2f32f8ad33"
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
//        initAdmob()
//        initYandex()
        //initGameAnalytics()
        return true
    }
    
//    func initAdmob() {
//        MobileAds.shared.start { status in
//            let adpterStatuses = status.adapterStatusesByClassName
//            let success = adpterStatuses.values.contains { $0.state == .ready }
//            
//            if success {
//                logDebug("Admob 初始化成功")
//            } else {
//                logDebug("Admob 初始化失败")
//            }
//        }
//    }
//    
//    func initYandex() {
//        MobileAds.initializeSDK {
//            logDebug("Yandex 初始化成功")
//        }
//    }
    
//    func initGameAnalytics() {
//        logDebug("initGameAnalytics")
//        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
//       
//        // Enable log
//        GameAnalytics.setEnabledInfoLog(true)
//        GameAnalytics.setEnabledVerboseLog(true)
//        GameAnalytics.configureAutoDetectAppVersion(true)
//        GameAnalytics.configureBuild(version)
//        GameAnalytics.initialize(withGameKey: gameKey, gameSecret: secretKey)
//    }
}

@main
struct CatVPNApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}
