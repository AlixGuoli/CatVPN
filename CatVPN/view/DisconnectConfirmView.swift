//
//  DisconnectConfirmView.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/25.
//

import SwiftUI

struct DisconnectConfirmView: View {
    
    var onConfirm: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // 弹窗内容
            VStack(spacing: 10) {
                // 关闭按钮
                btnTopClose
                
                // 图标
                Image("disconnectHint")
                    .resizable()
                    .frame(width: 66, height: 66)
                
                // 确认文本
                Text("Disconnect_Confirm_Message".localstr())
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                
                // 按钮区域
                HStack(spacing: 15) {
                    // 取消按钮
                    btnCancel
                    
                    // 确认按钮
                    btnConfirm
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .padding(.vertical, 30)
            .background(.regularMaterial)
            .background(
                RoundedRectangle(cornerRadius: 25)
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
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .overlay(
                RoundedRectangle(cornerRadius: 25)
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
    }
    
    private var btnTopClose: some View {
        Button(action: {
            onCancel()
        }) {
            HStack {
                Spacer()
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(8)
                    .frame(width: 35, height: 35)
                    .foregroundColor(.gray)
                    .background(.regularMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.linearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.green.opacity(0.3),
                                    Color.mint.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.0)
                    )
                    .shadow(color: .green.opacity(0.15), radius: 10, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var btnCancel: some View {
        Button(action: {
            onCancel()
        }) {
            Text("Cancel".localstr())
                .font(.system(size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.regularMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.gray.opacity(0.1),
                                    Color.gray.opacity(0.06),
                                    Color.gray.opacity(0.04)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.linearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.gray.opacity(0.2),
                                Color.gray.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 1.0)
                )
                .shadow(color: .gray.opacity(0.1), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var btnConfirm: some View {
        Button(action: {
            onConfirm()
        }) {
            Text("Yes".localstr())
                .font(.system(size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green,
                            Color.mint,
                            Color.green.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.linearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.green.opacity(0.3),
                                Color.mint.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 1.0)
                )
                .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    DisconnectConfirmView(
        onConfirm: {
            print("Disconnect confirmed")
        },
        onCancel: {
            print("Disconnect cancelled")
        }
    )
}
