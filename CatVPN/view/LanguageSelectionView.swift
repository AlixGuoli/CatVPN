//
//  LanguageSelectionView.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/14.
//

import SwiftUI

struct LanguageSelectionView: View {
    @Binding var isPresented: Bool
    @StateObject private var languageCenter = LanguageCenter.shared
    @State private var floatingAnimation = false
    @State private var pulseAnimation = false
    @State private var selectedLanguage: Language = .english
    @State private var isLoading = false
    
    // 支持的语言列表
    private let languages: [Language] = [
        .english,
        .russian,
        .german,
        .french,
        .chinese
    ]
    
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
                
                VStack(spacing: 0) {
                    // 标题区域
                    titleSection
                    
                    // 语言列表
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(languages, id: \.self) { language in
                                GlassyLanguageRowView(
                                    language: language,
                                    isSelected: language == selectedLanguage,
                                    isLoading: isLoading,
                                    onSelect: {
                                        selectLanguage(language)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
                
                // 加载覆盖层
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Switching language...".localstr())
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                            .padding(.top, 16)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
            }
        }
        .navigationTitle("Language".localstr())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationBarItems(
            leading: glassyCancelButton,
            trailing: glassyDoneButton
        )
        .onAppear {
            startAnimations()
            loadCurrentLanguage()
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
    
    // 标题区域
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Select Language".localstr())
                .font(.system(size: 24, weight: .bold))
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
            
            Text("Choose your preferred language".localstr())
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
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
            
            // 切换语言
            switchLanguage(selectedLanguage)
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
        .disabled(isLoading)
    }
    
    // 选择语言
    private func selectLanguage(_ language: Language) {
        selectedLanguage = language
        
        // 添加触感反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // 切换语言
    private func switchLanguage(_ language: Language) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoading = true
            languageCenter.updateLanguage(language.rawValue)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isLoading = false
                isPresented = false
            }
        }
    }
    
    // 加载当前语言
    private func loadCurrentLanguage() {
        if let language = Language(rawValue: languageCenter.currentLanguage) {
            selectedLanguage = language
        } else {
            selectedLanguage = .english
        }
    }
}

// 语言枚举
enum Language: String, CaseIterable {
    case english = "en"
    case russian = "ru"
    case german = "de"
    case french = "fr"
    case chinese = "zh-Hans"
    
    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .russian:
            return "Русский"
        case .german:
            return "Deutsch"
        case .french:
            return "Français"
        case .chinese:
            return "中文"
        }
    }
    
    var flagEmoji: String {
        switch self {
        case .english:
            return "🇺🇸"
        case .russian:
            return "🇷🇺"
        case .german:
            return "🇩🇪"
        case .french:
            return "🇫🇷"
        case .chinese:
            return "🇨🇳"
        }
    }
}

// 毛玻璃语言行视图
struct GlassyLanguageRowView: View {
    let language: Language
    let isSelected: Bool
    let isLoading: Bool
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
                    
                    Text(language.flagEmoji)
                        .font(.system(size: 28))
                }
                
                // 语言信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(language.displayName)
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
                    
                    Text(language.rawValue.uppercased())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.thinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color(.systemGray5), lineWidth: 1)
                                )
                        )
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
                    
                    if isLoading && isSelected {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            .scaleEffect(0.8)
                    } else if isSelected {
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
        .opacity(isLoading && !isSelected ? 0.6 : 1.0)
        .disabled(isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}


#Preview {
    NavigationView {
        LanguageSelectionView(isPresented: .constant(true))
    }
}
