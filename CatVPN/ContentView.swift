//
//  ContentView.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI

struct ContentView: View {
    @State private var showSplashScreen = true
    
    var body: some View {
        if showSplashScreen {
            SplashScreenView()
                .onAppear {
                    // 3秒后自动切换到主界面
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            showSplashScreen = false
                        }
                    }
                }
        } else {
            // 主连接界面
            VPNMainView()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale),
                    removal: .opacity
                ))
                .onAppear {
                    Task {
                        await HttpUtils.instance.fetchServiceCF()
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
