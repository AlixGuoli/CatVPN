//
//  ConnectSuccessView.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/25.
//

import SwiftUI

struct ConnectSuccessView: View {
    
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
            
            VStack {
                Spacer()
                Text("Connect Successful")
                    .font(.largeTitle)
                    .foregroundStyle(.black)
                Spacer()
            }
        }
    }
}

#Preview {
    ConnectSuccessView()
}
