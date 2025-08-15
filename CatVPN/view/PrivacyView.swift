

import SwiftUI

struct PrivacyPopupView: View {
    @EnvironmentObject var vm: MainViewmodel
    @Binding var isPresented: Bool
    @State private var pulseAnimation = false
    @State private var scaleAnimation = false
    var onDismiss: (() -> Void)?
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            // 弹窗内容
            VStack(spacing: 0) {
                // 头部图标区域
                VStack(spacing: 20) {
                    ZStack {
                        // 背景圆圈
                        Circle()
                            .fill(.thinMaterial)
                            .background(
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                            )
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                        
                        // 盾牌图标
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 32, weight: .medium))
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
                    
                    VStack(spacing: 12) {
                        Text("Privacy_First".localstr())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Privacy_Priority".localstr())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 30)
                
                // 内容区域
                VStack(spacing: 24) {
                    // 隐私特性列表
                    VStack(spacing: 16) {
//                        privacyFeatureRow(
//                            icon: "eye.slash.fill",
//                            title: "No Data Collection",
//                            description: "We don't collect, store, or track any of your personal data",
//                            color: .green
//                        )
                        
                        privacyFeatureRow(
                            icon: "network",
                            title: "Proxy_Only".localstr(),
                            description: "Proxy_Description".localstr(),
                            color: .mint
                        )
                        
                        privacyFeatureRow(
                            icon: "lock.shield.fill",
                            title: "Anonymous".localstr(),
                            description: "Anonymous_Description".localstr(),
                            color: .cyan
                        )
                    }
                    
                    // 底部说明
                    VStack(spacing: 12) {
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
                            .padding(.horizontal, 20)
                        
                        Text("Privacy_Agreement".localstr())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                
                // 按钮区域
                VStack(spacing: 12) {
                    Button(action: {
                        dismissPopup()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            
                            Text("I_Understand".localstr())
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.green,
                                    Color.mint
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
//                    Button(action: {
//                        // 这里可以打开隐私政策链接
//                        dismissPopup()
//                    }) {
//                        Text("Learn More About Privacy")
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                            .foregroundColor(.green)
//                    }
//                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .background(.regularMaterial)
            .background(
                RoundedRectangle(cornerRadius: 28)
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
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
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
            .shadow(color: .green.opacity(0.2), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 20)
            .scaleEffect(scaleAnimation ? 1.0 : 0.8)
            .opacity(scaleAnimation ? 1.0 : 0.0)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func privacyFeatureRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private func startAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            scaleAnimation = true
        }
        
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }
    
    private func dismissPopup() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            scaleAnimation = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
            // 标记已看过隐私弹窗
            UserDefaults.standard.set(true, forKey: "hasSeenPrivacyPopup")
            vm.isPrivacyAgreed = true
            // 调用关闭回调
            onDismiss?()
        }
    }
}

#Preview {
    PrivacyPopupView(isPresented: .constant(true))
}
