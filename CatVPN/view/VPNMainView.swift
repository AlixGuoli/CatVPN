//
//  VPNMainView.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI
import AppTrackingTransparency
import AdSupport

struct VPNMainView: View {
    
    @StateObject var adsManager = AdsUtils()
    
    @EnvironmentObject var mainViewModel: MainViewmodel
    @State private var showServerSelection = false
    @State private var showPrivacyGuide = false
    @State private var showPrivacyPopup = false
    @State private var pulseAnimation = false
    @State private var floatingAnimation = false
    @State private var waveAnimation = false
    @State private var rippleAnimation = false
    @State private var liquidAnimation = false
    
    @State private var showSuccess = false
    
    // 背景球体的固定位置数据 - 使用相对于屏幕的百分比位置
    private var backgroundCircles: [BackgroundCircle] {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        return [
            BackgroundCircle(startX: screenWidth * 0.15, startY: screenHeight * 0.12, endX: screenWidth * 0.25, endY: screenHeight * 0.18, size: 70),
            BackgroundCircle(startX: screenWidth * 0.7, startY: screenHeight * 0.25, endX: screenWidth * 0.6, endY: screenHeight * 0.35, size: 90),
            BackgroundCircle(startX: screenWidth * 0.9, startY: screenHeight * 0.08, endX: screenWidth * 0.85, endY: screenHeight * 0.15, size: 50),
            BackgroundCircle(startX: screenWidth * 0.2, startY: screenHeight * 0.6, endX: screenWidth * 0.3, endY: screenHeight * 0.7, size: 80),
            BackgroundCircle(startX: screenWidth * 0.8, startY: screenHeight * 0.75, endX: screenWidth * 0.7, endY: screenHeight * 0.85, size: 60),
            BackgroundCircle(startX: screenWidth * 0.05, startY: screenHeight * 0.4, endX: screenWidth * 0.15, endY: screenHeight * 0.5, size: 65)
        ]
    }
    
    // 水波纹数据
    private var waterRipples: [WaterRipple] {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        return [
            WaterRipple(x: screenWidth * 0.3, y: screenHeight * 0.2, initialSize: 30, finalSize: 120, duration: 3.0, delay: 0),
            WaterRipple(x: screenWidth * 0.7, y: screenHeight * 0.4, initialSize: 25, finalSize: 100, duration: 2.5, delay: 1.0),
            WaterRipple(x: screenWidth * 0.1, y: screenHeight * 0.6, initialSize: 35, finalSize: 140, duration: 3.2, delay: 2.0),
            WaterRipple(x: screenWidth * 0.9, y: screenHeight * 0.8, initialSize: 20, finalSize: 90, duration: 2.8, delay: 1.5)
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { geometry in
                    ZStack {
                        // 增强的动态背景，包含水的效果
                        enhancedDynamicBackground
                        
                        // 水波纹效果层
                        waterRippleLayer
                        
                        // 液体流动效果
                        liquidFlowLayer

                        ScrollView {
                            VStack(spacing: 25) {
                                // 网络质量指示器 - 毛玻璃效果
                                glassyNetworkQualityIndicator
                                
                                // 顶部状态栏 - 毛玻璃效果
                                glassyStatusHeaderView
                                
                                // 主连接按钮
                                VPNConnectionButton()
                                    .environmentObject(adsManager)
                                    .environmentObject(mainViewModel)
                                    .padding(.vertical, 25)
                                
                                // 服务器信息卡片 - 毛玻璃效果
                                glassyServerInfoCard
                                
                                // 连接统计信息
                                if mainViewModel.connectionStatus == .connected {
                                    glassyConnectionStatsView
                                }
                                
                                // 最近活动卡片 - 毛玻璃效果
                                glassyRecentActivityCard
                                
                                // 装饰分隔符
                                decorativeDivider
                                
                                // 快速操作按钮 - 毛玻璃效果
                                glassyQuickActionsView
                                
                                Spacer(minLength: 120)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 15)
                        }
                    }
                }
                .onAppear {
                    startAllAnimations()
                    requestTrackingAuthorization()
                    ADSCenter.shared.prepareAllAd()
                }
                .onChange(of: mainViewModel.connectionStatus) { status in
                    if status == .connected {
                        logDebug("~~~~~ View connectionStatus: \(mainViewModel.connectionStatus)")
                        showSuccess.toggle()
                    }
                }
                .navigationDestination(isPresented: $showSuccess) {
                    ConnectSuccessView(status: mainViewModel.connectionStatus)
                }
                .navigationDestination(isPresented: $showServerSelection) {
                    ServerSelectionView(mainViewModel: mainViewModel, isPresented: $showServerSelection)
                }
                .navigationDestination(isPresented: $showPrivacyGuide) {
                    PrivacyGuideView()
                }
                .overlay(
                    showPrivacyPopup ? PrivacyPopupView(isPresented: $showPrivacyPopup) : nil
                )
            }
        }
    }
    
    func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    logDebug("用户已授权，IDFA: \(ASIdentifierManager.shared().advertisingIdentifier)")
                    checkPrivacyPopup()
                case .denied:
                    logDebug("用户拒绝了追踪请求")
                    checkPrivacyPopup()
                case .notDetermined:
                    logDebug("用户尚未做出选择")
                    checkPrivacyPopup()
                case .restricted:
                    logDebug("追踪受限")
                    checkPrivacyPopup()
                @unknown default:
                    logDebug("未知状态")
                    checkPrivacyPopup()
                }
            }
        } else {
            checkPrivacyPopup()
        }
    }
    
    // 启动所有动画
    private func startAllAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
        
        // 延迟启动浮动动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.0)) {
                floatingAnimation = true
            }
        }
        
        // 启动水波动画
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            waveAnimation = true
        }
        
        // 启动波纹动画
        withAnimation(.easeInOut(duration: 3.0).repeatForever()) {
            rippleAnimation = true
        }
        
        // 启动液体动画
        withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
            liquidAnimation = true
        }
    }
    
    // 检查是否需要显示隐私弹窗
    private func checkPrivacyPopup() {
        let hasSeenPrivacyPopup = UserDefaults.standard.bool(forKey: "hasSeenPrivacyPopup")
        if !hasSeenPrivacyPopup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showPrivacyPopup = true
                UserDefaults.standard.set(true, forKey: "hasSeenPrivacyPopup")
            }
        }
    }
    
    // 增强的动态背景
    private var enhancedDynamicBackground: some View {
        ZStack {
            // 主渐变背景 - 青蛙绿色主题
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color.green.opacity(0.15),
                    Color.mint.opacity(0.12),
                    Color.green.opacity(0.08),
                    Color(.systemGray6).opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 水的流动效果背景
            WaterFlowBackground(animation: waveAnimation)
                .opacity(0.3)
                .blur(radius: 2)
            
            // 平滑浮动的装饰圆圈
            ForEach(0..<backgroundCircles.count, id: \.self) { index in
                let circle = backgroundCircles[index]
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.2),
                                Color.mint.opacity(0.15),
                                Color.green.opacity(0.08),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: circle.size / 2
                        )
                    )
                    .frame(width: circle.size, height: circle.size)
                    .position(
                        x: floatingAnimation ? circle.endX : circle.startX,
                        y: floatingAnimation ? circle.endY : circle.startY
                    )
                    .blur(radius: 4)
                    .opacity(floatingAnimation ? 0.8 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 8.0 + Double(index) * 1.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 1.2),
                        value: floatingAnimation
                    )
            }
        }
    }
    
    // 水波纹效果层
    private var waterRippleLayer: some View {
        ZStack {
            ForEach(0..<waterRipples.count, id: \.self) { index in
                let ripple = waterRipples[index]
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.6),
                                Color.mint.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .center,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(
                        width: rippleAnimation ? ripple.finalSize : ripple.initialSize,
                        height: rippleAnimation ? ripple.finalSize : ripple.initialSize
                    )
                    .position(x: ripple.x, y: ripple.y)
                    .opacity(rippleAnimation ? 0 : 0.8)
                    .animation(
                        Animation.easeOut(duration: ripple.duration)
                            .repeatForever()
                            .delay(ripple.delay),
                        value: rippleAnimation
                    )
            }
        }
    }
    
    // 液体流动效果层
    private var liquidFlowLayer: some View {
        ZStack {
            LiquidShapeView(animation: liquidAnimation)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green.opacity(0.15),
                            Color.mint.opacity(0.1),
                            Color.green.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 3)
                .ignoresSafeArea()
        }
    }

    // 毛玻璃效果的顶部状态栏
    private var glassyStatusHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Connection Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(mainViewModel.connectionStatus.statusColor.opacity(0.3))
                            .frame(width: 16, height: 16)
                            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(), value: pulseAnimation)
                        
                        Circle()
                            .fill(mainViewModel.connectionStatus.statusColor)
                            .frame(width: 10, height: 10)
                    }
                    
                    Text(mainViewModel.connectionStatus.statusText)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    mainViewModel.connectionStatus.statusColor,
                                    mainViewModel.connectionStatus.statusColor.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            
            Spacer()
            
            // IP保护状态
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: mainViewModel.connectionStatus == .connected ? "shield.fill" : "shield.slash")
                        .font(.caption)
                        .foregroundColor(mainViewModel.connectionStatus == .connected ? .green : .orange)
                    
                    Text("Your IP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                Text(mainViewModel.connectionStatus == .connected ? "Protected" : "Exposed")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.regularMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(
                                        mainViewModel.connectionStatus == .connected ? Color.green.opacity(0.3) : Color.orange.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .foregroundColor(mainViewModel.connectionStatus == .connected ? .green : .orange)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green.opacity(0.08),
                            Color.mint.opacity(0.05),
                            Color.green.opacity(0.03)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.linearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.green.opacity(0.3),
                        Color.mint.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1.5)
        )
        .shadow(color: .green.opacity(0.1), radius: 20, x: 0, y: 8)
    }

    // 毛玻璃效果的网络质量指示器
    private var glassyNetworkQualityIndicator: some View {
        HStack {
            Text("Network Quality")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 3) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    index < networkStrength ? .green : Color(.systemGray4),
                                    index < networkStrength ? .mint : Color(.systemGray4)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4, height: CGFloat(6 + index * 3))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1), value: networkStrength)
                }
            }
            
            Text("Excellent")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.05))
                .blur(radius: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.linearGradient(
                    colors: [
                        Color.white.opacity(0.3),
                        Color.green.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }

    private var networkStrength: Int {
        switch mainViewModel.selectedServer.ping {
        case 0...30: return 4
        case 31...60: return 3
        case 61...100: return 2
        default: return 1
        }
    }

    // 毛玻璃效果的服务器信息卡片
    private var glassyServerInfoCard: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            showServerSelection = true
        }) {
            HStack {
                HStack(spacing: 16) {
                    // 国旗
                    ZStack {
                        Circle()
                            .fill(.thinMaterial)
                            .background(
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                            )
                            .frame(width: 60, height: 60)
                        
                        Text(mainViewModel.selectedServer.flagEmoji)
                            .font(.largeTitle)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Selected Server")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(mainViewModel.selectedServer.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Label("\(mainViewModel.selectedServer.ping)ms", systemImage: "timer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Label("Fast", systemImage: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    // 更换按钮
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title3)
                            .foregroundColor(.green)
                        
                        Text("Change")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.regularMaterial)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.1),
                                Color.mint.opacity(0.06),
                                Color.green.opacity(0.04)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.linearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.green.opacity(0.3),
                            Color.mint.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            )
            .shadow(color: .green.opacity(0.15), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // 毛玻璃效果的连接统计信息
    private var glassyConnectionStatsView: some View {
        HStack(spacing: 16) {
            // 连接时间
            glassyStatCard(
                icon: "clock.fill",
                title: "Duration",
                value: mainViewModel.connectionTime,
                color: .green
            )
            
            // 数据传输
            glassyStatCard(
                icon: "arrow.up.arrow.down",
                title: "Data",
                value: mainViewModel.dataTransferred,
                color: .mint
            )
        }
    }

    private func glassyStatCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.regularMaterial)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.08),
                            color.opacity(0.04),
                            color.opacity(0.02)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.linearGradient(
                    colors: [
                        Color.white.opacity(0.3),
                        color.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.1), radius: 12, x: 0, y: 4)
    }

    // 毛玻璃效果的网络速度卡片
    private var glassyRecentActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Network Speed")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 实时指示器
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 1.0).repeatForever(), value: pulseAnimation)
                    
                    Text("Live")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
            
            HStack(spacing: 32) {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                        
                        Text("Upload")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                    
                    Text(mainViewModel.uploadSpeed)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .monospaced()
                }
                
                Rectangle()
                    .fill(Color(.systemGray5).opacity(0.5))
                    .frame(width: 1, height: 40)
                
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                            .foregroundColor(.cyan)
                        
                        Text("Download")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                    
                    Text(mainViewModel.downloadSpeed)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .monospaced()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.regularMaterial)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.08),
                            Color.cyan.opacity(0.05),
                            Color.blue.opacity(0.03)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.linearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.blue.opacity(0.3),
                        Color.cyan.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .shadow(color: .blue.opacity(0.1), radius: 15, x: 0, y: 6)
    }

    // 装饰分隔符
    private var decorativeDivider: some View {
        HStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.green.opacity(0.3),
                            Color.mint.opacity(0.2),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.horizontal, 40)
    }

    // 毛玻璃效果的快速操作按钮
    private var glassyQuickActionsView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    glassyActionButton(
                        icon: "server.rack",
                        title: "Servers",
                        color: .green,
                        action: { showServerSelection = true }
                    )
                    
                    glassyActionButton(
                        icon: "doc.text.fill",
                        title: "Privacy Guide",
                        color: .purple,
                        action: { showPrivacyGuide = true }
                    )
//                    glassyActionButton(
//                        icon: "gearshape.fill",
//                        title: "Settings",
//                        color: .gray,
//                        action: { /* TODO: 实现设置功能 */ }
//                    )
                }
                
//                HStack(spacing: 14) {
//                    glassyActionButton(
//                        icon: "arrow.clockwise",
//                        title: "Reset Privacy",
//                        color: .orange,
//                        action: {
//                            // 重置隐私弹窗状态（仅用于测试）
//                            UserDefaults.standard.set(false, forKey: "hasSeenPrivacyPopup")
//                            showPrivacyPopup = true
//                        }
//                    )
//                    
////                    glassyActionButton(
////                        icon: "questionmark.circle.fill",
////                        title: "Help",
////                        color: .orange,
////                        action: { /* TODO: 实现帮助功能 */ }
////                    )
//                }
            }
        }
    }

    private func glassyActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.thinMaterial)
                        .background(
                            Circle()
                                .fill(color.opacity(0.15))
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(.thinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.08),
                                color.opacity(0.04),
                                color.opacity(0.02)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.linearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            color.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.1), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// 背景圆圈数据结构
struct BackgroundCircle {
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let size: CGFloat
}

// 水波纹数据结构
struct WaterRipple {
    let x: CGFloat
    let y: CGFloat
    let initialSize: CGFloat
    let finalSize: CGFloat
    let duration: Double
    let delay: Double
}

// 水流背景效果
struct WaterFlowBackground: View {
    let animation: Bool
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let waveHeight: CGFloat = 60
                let waveLength: CGFloat = width / 2
                
                path.move(to: CGPoint(x: 0, y: height * 0.3))
                
                for x in stride(from: 0, through: width, by: 5) {
                    let relativeX = x / waveLength
                    let sine = sin(relativeX * .pi * 2 + (animation ? .pi : 0))
                    let y = height * 0.3 + sine * waveHeight
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.green.opacity(0.3),
                        Color.mint.opacity(0.2),
                        Color.green.opacity(0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// 液体形状视图
struct LiquidShapeView: Shape {
    let animation: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        let waveHeight: CGFloat = 40
        let waveLength: CGFloat = width / 3
        
        path.move(to: CGPoint(x: 0, y: height * 0.7))
        
        for x in stride(from: 0, through: width, by: 3) {
            let relativeX = x / waveLength
            let sine = sin(relativeX * .pi * 2 + (animation ? .pi * 1.5 : 0))
            let cosine = cos(relativeX * .pi * 1.5 + (animation ? .pi : 0))
            let y = height * 0.7 + sine * waveHeight + cosine * 20
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

// 按钮缩放样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    VPNMainView()
        .environmentObject(MainViewmodel()) // 使用环境对象
}

