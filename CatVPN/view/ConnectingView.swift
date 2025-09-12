import SwiftUI

struct ConnectingView: View {
    @EnvironmentObject var mainViewModel: MainViewmodel
    @Environment(\.dismiss) var dismiss
    @State private var waterRippleAnimation: Bool = false
    @State private var liquidAnimation: Bool = false
    @State private var floatingAnimation: Bool = false
    
    // 背景球体的固定位置数据
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
    
    var body: some View {
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
            
            // 浮动装饰圆圈
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
            
            VStack(spacing: 15) {
                // 顶部关闭按钮和标题
                btnTopClose
                Text("VPN_Button_Connecting".localstr() + " 🐸💫")
                    .fontWeight(.semibold)
                    .font(.title)
                
                // 连接动画区域
                VStack(spacing: 30) {
                    
                    // 连接动画按钮
                    ZStack {
                        // 水波纹效果背景层
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.green.opacity(0.6),
                                            Color.mint.opacity(0.4),
                                            Color.green.opacity(0.2),
                                            Color.clear
                                        ]),
                                        startPoint: .center,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                                .scaleEffect(waterRippleAnimation ? 2.2 : 0.8)
                                .opacity(waterRippleAnimation ? 0 : 0.8)
                                .animation(
                                    Animation.easeOut(duration: 2.5)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(index) * 0.6),
                                    value: waterRippleAnimation
                                )
                        }
                        
                        // 外围的液体波纹
                        ForEach(0..<2, id: \.self) { index in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.green.opacity(0.3),
                                            Color.mint.opacity(0.2),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 60,
                                        endRadius: 100
                                    )
                                )
                                .scaleEffect(liquidAnimation ? 1.3 : 0.9)
                                .opacity(liquidAnimation ? 0.6 : 0.3)
                                .animation(
                                    Animation.easeInOut(duration: 4.0)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 2.0),
                                    value: liquidAnimation
                                )
                        }
                        
                        // 主按钮区域
                        ZStack {
                            // 背景圆形
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.green.opacity(0.2),
                                            Color.mint.opacity(0.15),
                                            Color.green.opacity(0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 160, height: 160)
                            
                            // 青蛙图标 - 静态，不跳动
                            Image("frog")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                // .scaleEffect(frogBounceAnimation ? 1.1 : 1.0)  // 注释掉跳动动画
                                // .animation(
                                //     Animation.easeInOut(duration: 1.5)
                                //         .repeatForever(autoreverses: true),
                                //     value: frogBounceAnimation
                                // )
                        }
                        .frame(width: 160, height: 160)
                    }
                    .frame(width: 300, height: 300)
                }
                
                Spacer()
                
                // 评分引导卡片
                RatingGuideCardView {
                    openReviewPage()
                }
                .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            startAnimations()
            // 启动实际连接
            startConnection()
        }
        .onChange(of: mainViewModel.connectionStatus) { status in
            updateAnimations(for: status)
        }
    }
    
    private func startAnimations() {
        // 延迟启动浮动动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.0)) {
                floatingAnimation = true
            }
        }
        
        // 根据连接状态启动相应动画
        updateAnimations(for: mainViewModel.connectionStatus)
    }
    
    private func updateAnimations(for status: VPNConnectionStatus) {
        switch status {
        case .connecting, .connected:
            // 启动水波纹动画
            withAnimation(.easeOut(duration: 2.5).repeatForever()) {
                waterRippleAnimation = true
            }
            
            // 启动液体动画
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                liquidAnimation = true
            }
            
        case .disconnected, .failed:
            // 停止动画
            waterRippleAnimation = false
            liquidAnimation = false
        }
    }
    
    private func startConnection() {
        // 启动实际连接
        mainViewModel.prepare()
    }
    
    private func openReviewPage() {
        let reviewURL = "https://apps.apple.com/app/id6748526674?action=write-review"
        if let url = URL(string: reviewURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    // 顶部关闭按钮 - 参考结果页设计
    private var btnTopClose: some View {
        Button(action: {
            dismiss()
        }) {
            HStack {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
                    .font(.headline)
                    .padding(12)
                    .background(.regularMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
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
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
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
                    .padding(.leading, 20)
                Spacer()
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    ConnectingView()
        .environmentObject(MainViewmodel())
}
