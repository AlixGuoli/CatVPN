//
//  RatingView.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/13.
//

import SwiftUI

struct RatingView: View {
    
    @EnvironmentObject var vm: MainViewmodel
    @Environment(\.dismiss) var dismiss
    @State private var selectedRating: Int = 0

    var onRatingSubmit: ((Int) -> Void)?
    
    // 获取按钮文字
    private func getButtonText() -> String {
        // 如果不是俄罗斯地区，都显示 Rate Us
        if RatingCenter.shared.checkVersionAndRu() {
            return "Rate Us"
        }
        
        // 如果是俄罗斯地区，根据评分显示不同文字
        if selectedRating == 5 {
            return "Rate Us"
        } else if selectedRating > 0 {
            return "Feedback"
        } else {
            return "Rate Us"
        }
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
            
            VStack(spacing: 0) {
                btnTopClose
                
                // 标题
                Text("Evaluate Connection Quality")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.textGreen)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                
                // 青蛙图片 - 从标题延伸到毛玻璃卡片
                Image(.imageRate)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 220)
                    .padding(.top, 30)
                
                // 毛玻璃评分卡片
                VStack(spacing: 30) {
                    // 评分描述
                    Text("Great")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textGreen)
                    
                    // 反馈说明文字
                    Text("Your feedback and support help us improve constantly.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 15)
                    
                    // 星级评分
                    HStack(spacing: 20) {
                        ForEach(1...5, id: \.self) { star in
                            Button(action: {
                                selectedRating = star
                            }) {
                                Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundColor(star <= selectedRating ? .orange : .gray)
                                    .scaleEffect(star <= selectedRating ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedRating)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // 评分按钮
                    Button(action: {
                        if selectedRating == 5 {
                            onRatingSubmit?(selectedRating)
                            dismiss()
                        } else if (selectedRating > 0 && selectedRating < 5) {
                            if EmailView.canSendEmail() {
                                vm.showEmail.toggle()
                            } else {
                                logDebug("不支持邮件")
                                onRatingSubmit?(selectedRating)
                                dismiss()
                            }
                        }
                    }) {
                        Text(getButtonText())
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(selectedRating > 0 ? Color.orange : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    .disabled(selectedRating == 0)
                    
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
                .background(.regularMaterial.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.2),
                                    Color.green.opacity(0.15),
                                    Color.mint.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(.linearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.green.opacity(0.15),
                                Color.mint.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 1)
                )
                .shadow(color: .green.opacity(0.1), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 30)
                
                // 关闭按钮 - 在毛玻璃框外面
                btnClose
                    .padding(.top, 30)
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            RatingCenter.shared.register()
        }
        .sheet(isPresented: $vm.showEmail) {
            EmailView {
                onRatingSubmit?(selectedRating)
                dismiss()
            }
        }
    }
    
    private var btnClose: some View {
        Button(action: {
            dismiss()
        }) {
            Text("Close")
                .font(.headline)
                .frame(maxWidth: .infinity)
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
                .padding(.horizontal, 30)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var btnTopClose: some View {
        Button(action: {
            dismiss()
        }) {
            HStack {
                Image(systemName: "xmark")
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
    RatingView()
}
