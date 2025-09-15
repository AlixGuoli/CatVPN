//
//  ServiceUnavailableView.swift
//  CatVPN
//
//  Created by Assistant on 2025/12/9.
//

import SwiftUI

struct ServiceUnavailableView: View {
    
    @Environment(\.dismiss) var dismiss
    @State private var showEmailView = false
    
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
            
            VStack(spacing: 20) {
                btnTopClose
                Text("ServiceUnavailable_Message".localstr())
                    .fontWeight(.semibold)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 40)
                
                supportView
                    
                    .onTapGesture {
                        contactSupport()
                    }
                
                tgView
                    .onTapGesture {
                        joinTelegramChannel()
                    }
                
                Spacer()
                
                closeButton
                    .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showEmailView) {
            EmailView {
                showEmailView = false
            }
        }
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
    
    private var supportView: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(.inSupport)
                .resizable()
                .frame(width: 30, height: 30)
                .padding(4)
            VStack(alignment: .leading, spacing: 6) {
                Text("ServiceUnavailable_Support".localstr())
                    .font(.system(size: 16, weight: .semibold))
                    .fontWeight(.semibold)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.bgGreen))
        .padding(.horizontal, 30)
    }
    
    private var tgView: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(.inTg)
                .resizable()
                .frame(width: 30, height: 30)
                .padding(4)
            VStack(alignment: .leading, spacing: 6) {
                Text("ServiceUnavailable_Telegram".localstr())
                    .font(.system(size: 16, weight: .semibold))
                    .fontWeight(.semibold)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.bgGreen))
        .padding(.horizontal, 30)
    }
    
    private var closeButton: some View {
        Button(action: {
            dismiss()
        }) {
            Text("ServiceUnavailable_Close".localstr())
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.linearGradient(
                                    colors: [
                                        Color.gray.opacity(0.3),
                                        Color.gray.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 30)
    }
    
    private func contactSupport() {
        logDebug("Contact support tapped")
        
        // 检查设备是否支持发送邮件
        if EmailView.canSendEmail() {
            showEmailView = true
        } else {
            // 显示提示对话框
            let alert = UIAlertController(
                title: "ServiceUnavailable_EmailNotAvailable".localstr(),
                message: "ServiceUnavailable_EmailNotAvailableMessage".localstr(),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            // 获取当前窗口的根视图控制器来显示对话框
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
    
    private func joinTelegramChannel() {
        let channelURL = BaseCFHelper.shared.getTgLink()
        
        if let url = URL(string: channelURL) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ServiceUnavailableView()
}
