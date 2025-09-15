import SwiftUI

struct ConnectingView: View {
    @EnvironmentObject var mainViewModel: MainViewmodel
    @Environment(\.dismiss) var dismiss
    @State private var waterRippleAnimation: Bool = false
    @State private var liquidAnimation: Bool = false
    
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
            
            GeometryReader { geometry in
                ScrollView {
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
                        // 主按钮区域
                        ZStack {
                            // 主按钮背景 - 青蛙主题毛玻璃效果
                            Circle()
                                .fill(.regularMaterial)
                                .background(
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                gradient: Gradient(colors: [
                                                    Color.mint.opacity(0.25),
                                                    Color.mint.opacity(0.15),
                                                    Color.mint.opacity(0.05)
                                                ]),
                                                center: .center,
                                                startRadius: 10,
                                                endRadius: 90
                                            )
                                        )
                                )
                                .overlay(
                                    Circle()
                                        .stroke(.linearGradient(
                                            colors: [
                                                Color.white.opacity(0.5),
                                                Color.mint.opacity(0.6),
                                                Color.mint.opacity(0.4),
                                                Color.white.opacity(0.3)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ), lineWidth: 2)
                                )
                                .frame(width: 160, height: 160)
                            
                            // 内部装饰环 - 青蛙主题
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.mint.opacity(0.4),
                                            Color.green.opacity(0.3),
                                            Color.mint.opacity(0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .padding(0)
                                .opacity(0.1)
                                .frame(width: 160, height: 160)
                            
                            // 中心内容 - 青蛙图片
                            ZStack {
                                // 青蛙背景圆圈
                                Circle()
                                    .fill(.thinMaterial)
                                    .background(
                                        Circle()
                                            .fill(Color.mint.opacity(0.1))
                                    )
                                    .frame(width: 140, height: 140)
                                
                                // 青蛙图标 - 静态，不跳动
                                Image("frog")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                            }
                        }
                        .frame(width: 160, height: 160)
                    }
                    .frame(width: 300, height: 300)
                    .overlay(
                        // 简单的水波纹和液体动画
                        ZStack {
                            // 水波纹动画
                            ForEach(0..<3, id: \.self) { index in
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
                                    .scaleEffect(waterRippleAnimation ? 2.0 : 0.8)
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
                                    .stroke(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                Color.green.opacity(0.3),
                                                Color.mint.opacity(0.15),
                                                Color.clear
                                            ]),
                                            center: .center,
                                            startRadius: 50,
                                            endRadius: 120
                                        ),
                                        lineWidth: 1.5
                                    )
                                    .scaleEffect(liquidAnimation ? 1.8 : 1.2)
                                    .opacity(liquidAnimation ? 0.2 : 0.6)
                                    .animation(
                                        Animation.easeInOut(duration: 4.0)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 2.0),
                                        value: liquidAnimation
                                    )
                            }
                        }
                        .allowsHitTesting(false) // 不响应触摸事件
                    )
                }
                
                Spacer()
                
                // 评分引导卡片
                RatingGuideCardView {
                    openReviewPage()
                }
                .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            startAnimations()
            // 只有在服务可用时才启动实际连接
            if BaseCFHelper.shared.isServiceAvailable() {
                startConnection()
            }
        }
    }
    
    private func startAnimations() {
        // 启动水波纹动画
        withAnimation(.easeOut(duration: 2.5).repeatForever()) {
            waterRippleAnimation = true
        }
        
        // 启动液体动画
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            liquidAnimation = true
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
