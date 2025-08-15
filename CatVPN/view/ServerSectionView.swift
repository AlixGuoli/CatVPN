//
//  ServerSelectionView.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI

struct ServerSelectionView: View {
    @ObservedObject var mainViewModel: MainViewmodel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var floatingAnimation = false
    @State private var pulseAnimation = false
    @State private var isLoading = true  // 添加loading状态
    
    var filteredServers: [VPNServer] {
        let servers = mainViewModel.availableServers
        if searchText.isEmpty {
            return servers
        } else {
            return servers.filter { server in
                server.name.localizedCaseInsensitiveContains(searchText) ||
                server.country.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // 背景装饰圆圈
    private var backgroundCircles: [BackgroundCircle] {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        return [
            BackgroundCircle(startX: screenWidth * 0.1, startY: screenHeight * 0.15, endX: screenWidth * 0.2, endY: screenHeight * 0.25, size: 60),
            BackgroundCircle(startX: screenWidth * 0.8, startY: screenHeight * 0.2, endX: screenWidth * 0.7, endY: screenHeight * 0.3, size: 80),
            BackgroundCircle(startX: screenWidth * 0.15, startY: screenHeight * 0.7, endX: screenWidth * 0.25, endY: screenHeight * 0.8, size: 70),
            BackgroundCircle(startX: screenWidth * 0.85, startY: screenHeight * 0.6, endX: screenWidth * 0.75, endY: screenHeight * 0.7, size: 50)
        ]
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 动态背景
                dynamicBackground
                
                if isLoading {
                    // Loading 视图
                    loadingView
                } else {
                    VStack(spacing: 0) {
                        // 毛玻璃搜索栏
                        glassySearchBar
                        
                        // 服务器列表
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredServers) { server in
                                    GlassyServerRowView(
                                        server: server,
                                        isSelected: server.id == mainViewModel.selectedServer.id,
                                        onSelect: {
                                            selectServer(server)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Server".localstr())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationBarItems(
            leading: glassyCancelButton,
            trailing: glassyDoneButton
        )
        .onAppear {
            startAnimations()
            
            // 获取服务器列表
            Task {
                isLoading = true
                
                // 延迟3秒，展示loading效果
                //try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
                
                await mainViewModel.fetchServers()
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    // 启动动画
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 1.0)) {
                floatingAnimation = true
            }
        }
    }
    
    // 动态背景
    private var dynamicBackground: some View {
        ZStack {
            // 主渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color.green.opacity(0.12),
                    Color.mint.opacity(0.08),
                    Color.green.opacity(0.05),
                    Color(.systemGray6).opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 浮动装饰圆圈
            ForEach(0..<backgroundCircles.count, id: \.self) { index in
                let circle = backgroundCircles[index]
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.15),
                                Color.mint.opacity(0.1),
                                Color.green.opacity(0.05),
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
                    .blur(radius: 3)
                    .opacity(floatingAnimation ? 0.6 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 6.0 + Double(index) * 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.8),
                        value: floatingAnimation
                    )
            }
        }
    }
    
    // 毛玻璃搜索栏
    private var glassySearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField("Search servers...".localstr(), text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16, weight: .medium))
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 16)
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.linearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.green.opacity(0.3),
                        Color.mint.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .shadow(color: .green.opacity(0.08), radius: 10, x: 0, y: 3)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // 毛玻璃取消按钮
    private var glassyCancelButton: some View {
        Button("Cancel".localstr()) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            isPresented = false
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.red.opacity(0.8),
                    Color.orange.opacity(0.6)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    // 毛玻璃完成按钮
    private var glassyDoneButton: some View {
        Button("Done".localstr()) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            isPresented = false
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.green,
                    Color.mint.opacity(0.8)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    // 选择服务器
    private func selectServer(_ server: VPNServer) {
        mainViewModel.selectServer(server)
        
        // 添加触感反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 延迟关闭弹窗，让用户看到选择效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
        }
    }
    
    // Loading 视图
    private var loadingView: some View {
        VStack(spacing: 20) {
            // 旋转的圆圈
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green,
                            Color.mint.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1.0)
                        .repeatForever(autoreverses: false),
                    value: pulseAnimation
                )
            
            Text("loading...".localstr())
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .opacity(pulseAnimation ? 0.6 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 毛玻璃服务器行视图
struct GlassyServerRowView: View {
    let server: VPNServer
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onSelect()
            }
        }) {
            HStack(spacing: 16) {
                // 国旗容器
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.green.opacity(0.1),
                                            Color.mint.opacity(0.05)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text(server.flagEmoji)
                        .font(.system(size: 28))
                }
                
                // 服务器信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(server.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.primary,
                                    Color.primary.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    HStack(spacing: 12) {
                        // Ping显示
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(pingColor)
                            
                            Text("\(server.ping)ms")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(pingColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.thinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(pingColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // 信号强度指示器
                        signalStrengthView
                    }
                }
                
                Spacer()
                
                // 选择状态指示器
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            isSelected ? Color.green.opacity(0.2) : Color.clear,
                                            isSelected ? Color.mint.opacity(0.1) : Color.clear
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected ? Color.green.opacity(0.4) : Color(.systemGray4),
                                    lineWidth: 2
                                )
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.green,
                                        Color.mint
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isSelected ? Color.green.opacity(0.12) : Color.clear,
                                isSelected ? Color.mint.opacity(0.08) : Color.clear,
                                isSelected ? Color.green.opacity(0.05) : Color.clear
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
                            isSelected ? Color.green.opacity(0.4) : Color(.systemGray5),
                            isSelected ? Color.mint.opacity(0.3) : Color(.systemGray5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            )
            .shadow(
                color: isSelected ? .green.opacity(0.15) : .black.opacity(0.05),
                radius: isSelected ? 15 : 8,
                x: 0,
                y: isSelected ? 6 : 3
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    // Ping颜色
    private var pingColor: Color {
        switch server.ping {
        case 0...30:
            return .green
        case 31...100:
            return .orange
        default:
            return .red
        }
    }
    
    // 信号强度视图
    private var signalStrengthView: some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                index < signalStrength ? pingColor : Color(.systemGray4),
                                index < signalStrength ? pingColor.opacity(0.8) : Color(.systemGray4)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: CGFloat(6 + index * 2))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.1), value: signalStrength)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.thinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
    
    // 根据ping计算信号强度
    private var signalStrength: Int {
        switch server.ping {
        case 0...20:
            return 4
        case 21...50:
            return 3
        case 51...100:
            return 2
        default:
            return 1
        }
    }
}

#Preview {
    ServerSelectionView(
        mainViewModel: MainViewmodel(),
        isPresented: .constant(true)
    )
}
