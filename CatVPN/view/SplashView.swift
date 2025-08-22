//
//  SplashScreenView.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI
import UIKit

struct SplashScreenView: View {
    // true 表示冷启动；false 表示后台→前台
    let isColdStart: Bool
    // 触发补齐到 100% 后再退出
    @Binding var finishNow: Bool
    // 补齐动画完成后的回调
    var onFinished: (() -> Void)? = nil
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0.0
    @State private var titleOpacity: Double = 0.0
    @State private var backgroundAnimation = false
    @State private var rippleAnimation = false
    @State private var floatingParticles = false
    @State private var liquidAnimation = false
    @State private var waveAnimation = false
    @State private var rotationAngle: Double = 0
    @State private var progress: Double = 0.0
    @State private var progressTimer: Timer? = nil
    @State private var runDuration: TimeInterval = 20.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lightMode: Bool = true
    
    // 粒子效果数据
    private var particles: [FloatingParticle] {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        return (0..<20).map { index in
            FloatingParticle(
                x: CGFloat.random(in: 0...screenWidth),
                y: CGFloat.random(in: 0...screenHeight),
                size: CGFloat.random(in: 3...8),
                animationDuration: Double.random(in: 3...6),
                delay: Double(index) * 0.2
            )
        }
    }
    
    // 波纹效果数据
    private var ripples: [SplashRipple] {
        let centerX = UIScreen.main.bounds.width / 2
        let centerY = UIScreen.main.bounds.height / 2
        
        return [
            SplashRipple(centerX: centerX, centerY: centerY, maxRadius: 150, duration: 2.0, delay: 0.5),
            SplashRipple(centerX: centerX, centerY: centerY, maxRadius: 250, duration: 3.0, delay: 1.0),
            SplashRipple(centerX: centerX, centerY: centerY, maxRadius: 350, duration: 4.0, delay: 1.5)
        ]
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 动态渐变背景
                dynamicBackground
                
                // 液体流动背景层
                if !lightMode {
                    liquidFlowBackground
                }
                
                // 浮动粒子效果
                if !lightMode {
                    floatingParticlesLayer
                }
                
                // 波纹效果层
                if !lightMode {
                    rippleEffectLayer
                }
                
                // 主要内容
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Logo区域
                    logoSection
                    
                    // 标题和副标题
                    titleSection
                    
                    // 加载指示器
                    loadingIndicator
                    
                    Spacer()
                    Spacer()
                }
            }
        }
        .onAppear {
            runDuration = isColdStart ? 20.0 : 2.0
            // 默认启用轻量模式，避免卡顿
            lightMode = true || reduceMotion
            startSplashAnimations()
            startProgress()
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
        }
        .onChange(of: finishNow) { newValue in
            guard newValue else { return }
            // 停止定时器，避免冲突
            progressTimer?.invalidate()
            progressTimer = nil
            withAnimation(.easeInOut(duration: 0.25)) {
                progress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                onFinished?()
                finishNow = false
            }
        }
        .localview()  // 确保启动页也能响应语言变化
    }
    
    // 启动所有动画
    private func startSplashAnimations() {
        if lightMode {
            // 轻量模式：只做最小淡入
            logoScale = 1.0
            withAnimation(.easeInOut(duration: 0.4)) {
                logoOpacity = 1.0
                titleOpacity = 1.0
            }
            return
        }
        // 背景动画
        withAnimation(.easeInOut(duration: 1.0)) {
            backgroundAnimation = true
        }
        
        // Logo动画 - 延迟0.3秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.6, blendDuration: 0)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
        
        // 标题动画 - 延迟0.8秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.8)) {
                titleOpacity = 1.0
            }
        }
        
        // 波纹动画 - 延迟1.0秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                rippleAnimation = true
            }
        }
        
        // 粒子动画 - 延迟0.5秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.0)) {
                floatingParticles = true
            }
        }
        
        // 液体动画
        withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
            liquidAnimation = true
        }
        
        // 波浪动画
        withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
            waveAnimation = true
        }
        
        // Logo旋转动画
        withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
    
    // 进度条逻辑
    private func startProgress() {
        progress = 0
        progressTimer?.invalidate()
        let startTime = Date()
        let interval = 1.0 / 60.0
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            let elapsed = Date().timeIntervalSince(startTime)
            let p = min(1.0, elapsed / max(0.1, runDuration))
            progress = p
            if p >= 1.0 {
                t.invalidate()
                progressTimer = nil
            }
        }
        progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    // 动态渐变背景
    private var dynamicBackground: some View {
        if lightMode || reduceMotion {
            return AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color.mint.opacity(0.12),
                        Color.green.opacity(0.12)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
        return AnyView(
            ZStack {
                // 主渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color.green.opacity(backgroundAnimation ? 0.3 : 0.1),
                        Color.mint.opacity(backgroundAnimation ? 0.25 : 0.08),
                        Color.green.opacity(backgroundAnimation ? 0.2 : 0.05),
                        Color(.systemGray6).opacity(0.1)
                    ]),
                    startPoint: backgroundAnimation ? .topTrailing : .topLeading,
                    endPoint: backgroundAnimation ? .bottomLeading : .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: backgroundAnimation)
                
                // 径向渐变覆盖层
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.mint.opacity(backgroundAnimation ? 0.4 : 0.1),
                        Color.green.opacity(backgroundAnimation ? 0.2 : 0.05),
                        Color.clear
                    ]),
                    center: backgroundAnimation ? .topLeading : .bottomTrailing,
                    startRadius: 50,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: backgroundAnimation)
            }
        )
    }
    
    // 液体流动背景
    private var liquidFlowBackground: some View {
        ZStack {
            // 液体波浪形状
            Wave(animationProgress: liquidAnimation ? 1.0 : 0.0, amplitude: 40, frequency: 1.5)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.3), Color.mint.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(0.6)
                .blur(radius: 3)
                .offset(y: 80)
            
            Wave(animationProgress: waveAnimation ? 1.0 : 0.0, amplitude: 60, frequency: 1.0)
                .fill(
                    LinearGradient(
                        colors: [Color.mint.opacity(0.2), Color.green.opacity(0.15)],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                )
                .opacity(0.4)
                .blur(radius: 5)
                .offset(y: 150)
        }
    }
    
    // 浮动粒子层
    private var floatingParticlesLayer: some View {
        ZStack {
            ForEach(0..<particles.count, id: \.self) { index in
                let particle = particles[index]
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.8), Color.mint.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: particle.size, height: particle.size)
                    .position(
                        x: floatingParticles ? particle.x + CGFloat.random(in: -50...50) : particle.x,
                        y: floatingParticles ? particle.y + CGFloat.random(in: -100...100) : particle.y
                    )
                    .opacity(floatingParticles ? Double.random(in: 0.3...0.8) : 0.0)
                    .blur(radius: 2)
                    .animation(
                        Animation.easeInOut(duration: particle.animationDuration)
                            .repeatForever(autoreverses: true)
                            .delay(particle.delay),
                        value: floatingParticles
                    )
            }
        }
    }
    
    // 波纹效果层
    private var rippleEffectLayer: some View {
        ZStack {
            ForEach(0..<ripples.count, id: \.self) { index in
                let ripple = ripples[index]
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.green.opacity(0.8), Color.mint.opacity(0.4), Color.clear],
                            startPoint: .center,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(
                        width: rippleAnimation ? ripple.maxRadius * 2 : 0,
                        height: rippleAnimation ? ripple.maxRadius * 2 : 0
                    )
                    .position(x: ripple.centerX, y: ripple.centerY)
                    .opacity(rippleAnimation ? 0.0 : 1.0)
                    .animation(
                        Animation.easeOut(duration: ripple.duration)
                            .repeatForever(autoreverses: false)
                            .delay(ripple.delay),
                        value: rippleAnimation
                    )
            }
        }
    }
    
    // Logo部分
    private var logoSection: some View {
        ZStack {
            // 外层光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.green.opacity(0.3), Color.mint.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(logoScale * 1.2)
                .opacity(logoOpacity * 0.8)
                .blur(radius: 10)
            
            // 主Logo圆圈
            ZStack {
                // 背景圆圈 - 毛玻璃效果
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.green.opacity(0.3), radius: 20, x: 0, y: 10)
                
                // 内层装饰圆圈
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.green, Color.mint, Color.green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotationAngle))
                
                // Logo图标或文字 (这里使用青蛙emoji作为示例)
                if let frogImage = UIImage(named: "frog") {
                    Image(uiImage: frogImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else {
                    Text("🐸")
                        .font(.system(size: 50))
                }
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
        }
    }
    
    // 标题部分
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("VPN Shield".localstr())
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green, Color.mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(titleOpacity)
            
            Text("Secure connection, enjoy the network smoothly".localstr())
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .opacity(titleOpacity * 0.8)
        }
    }
    
    // 加载指示器（线性进度条）
    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .frame(height: 6)
                .padding(.horizontal, 40)
                .opacity(titleOpacity)
            HStack(spacing: 8) {
                Text("Initializing...".localstr())
                    .font(.body)
                    .foregroundColor(.secondary)
                Text("\(Int(progress * 100))%")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .opacity(titleOpacity * 0.8)
        }
    }
}

// 波浪形状
struct Wave: Shape {
    var animationProgress: Double
    let amplitude: CGFloat
    let frequency: CGFloat
    
    var animatableData: Double {
        get { animationProgress }
        set { animationProgress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height * 0.85  // 从0.7调整到0.85，让波浪更靠近底部
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin((relativeX * frequency * 2 * .pi) + (animationProgress * 2 * .pi))
            let y = midHeight + sine * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

// 浮动粒子数据结构
struct FloatingParticle {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let animationDuration: Double
    let delay: Double
}

// 波纹数据结构
struct SplashRipple {
    let centerX: CGFloat
    let centerY: CGFloat
    let maxRadius: CGFloat
    let duration: Double
    let delay: Double
}

#Preview {
    SplashScreenView(isColdStart: false, finishNow: .constant(false))
}
