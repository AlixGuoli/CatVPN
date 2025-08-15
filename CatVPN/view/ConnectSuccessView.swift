//
//  ConnectSuccessView.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/25.
//

import SwiftUI

struct ConnectSuccessView: View {
    
    @Environment(\.dismiss) var dismiss
    @State var status: VPNConnectionStatus
    
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
            
            VStack(spacing: 30) {
                btnTopClose
                Text(getStatusText(status: status))
                    .fontWeight(.semibold)
                    .font(.title)
                shareView
                    .onTapGesture {
                        shareApp()
                    }
                tgView
                    .onTapGesture {
                        joinTelegramChannel()
                    }
                btnClose
                    .padding(.top, 50)
                Spacer()
                
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            ADSCenter.shared.prepareAllAd(moment: AdMoment.foreground)
        }
    }
    
    private var btnClose: some View {
        Button(action: {
            dismiss()
        }) {
            Text("Close".localstr())
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
    
    private var shareView: some View {
        VStack(alignment: .leading) {
            Image(.share)
                .resizable()
                .frame(width: 50, height: 50)
            Text("Tell_Friends_Title".localstr())
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tell_Friends_Description".localstr())
                .font(.caption)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.top, 25)
        .padding(.horizontal, 45)
        .frame(height: 170)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.bgGreen))
        .padding(.horizontal, 30)
    }
    
    private var tgView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(.tg)
                .resizable()
                .frame(width: 50, height: 50)
            Text("Follow_Us_Title".localstr())
                .font(.title2)
                .fontWeight(.semibold)
            Text("Follow_Us_Description".localstr())
                .font(.caption)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.top, 25)
        .padding(.horizontal, 45)
        .frame(height: 170)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.bgGreen))
        .padding(.horizontal, 30)
    }
    
    func getStatusText(status: VPNConnectionStatus) -> String {
        switch status {
        case .disconnected:
            return "Disconnected!".localstr()
        case .connecting:
            return "Connecting...".localstr()
        case .connected:
            return "Connection_Successful".localstr()
        case .failed:
            return "Connection_Failed".localstr()
        }
    }
    
    private func shareApp() {
        // App Store 链接
        let appStoreURL = "https://apps.apple.com/app/id6748526674"
        
        let activityVC = UIActivityViewController(
            activityItems: [appStoreURL],
            applicationActivities: nil
        )
        
        // 获取当前窗口
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
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
    ConnectSuccessView(status: .connected)
}
