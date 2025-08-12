//
//  ContentView.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI

struct ContentView: View {
    
    @State private var showSplashScreen = true
    @StateObject private var vm = MainViewmodel()
    
    var body: some View {
        if showSplashScreen {
            SplashScreenView()
                .environmentObject(vm)
                .onAppear {
                    // 启动配置检查
                    vm.checkNet { success in
                        logDebug("SplashScreen check completed: \(success)")
                        if success {
                            // 配置检查完成，进入主页
                            showSplashAd()
                            jump()
                        }
                    }
                    
                    // 20秒超时自动进入主页
                    DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                        if showSplashScreen {
                            logDebug("Splash screen timeout (20s), entering main view")
                            jump()
                        }
                    }
                }
        } else {
            // 主连接界面
            VPNMainView()
                .environmentObject(vm)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale),
                    removal: .opacity
                ))
        }
    }
    
    func jump() {
        withAnimation(.easeInOut(duration: 0.8)) {
            showSplashScreen = false
        }
    }
    
    func showSplashAd() {
        let adCenter = ADSCenter.shared
        logDebug("Splash start to show ad")
        if adCenter.isYanBannerReady() {
            logDebug("Yandex Banner is Ready ** Show Banner")
            adCenter.showYanBannerFromRoot()
        } else if adCenter.isYanIntReady() {
            logDebug("Yandex Banner is not Ready ** Show Int")
            adCenter.showYanIntFromRoot()
        }
    }
}

#Preview {
    ContentView()
}
