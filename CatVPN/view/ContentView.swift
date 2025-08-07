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
                        logDebug("Configuration check completed: \(success)")
                        // 配置检查完成，进入主页
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                showSplashScreen = false
                            }
                        }
                    }
                    
                    // 20秒超时自动进入主页
                    DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                        if showSplashScreen {
                            logDebug("Splash screen timeout (20s), entering main view")
                            withAnimation(.easeInOut(duration: 0.8)) {
                                showSplashScreen = false
                            }
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
}

#Preview {
    ContentView()
}
