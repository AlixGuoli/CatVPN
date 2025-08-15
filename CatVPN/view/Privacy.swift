//
//  PrivacyGuideView.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI

struct PrivacyGuideView: View {
    @State private var selectedSection: PrivacySection = .overview
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部选择器
                sectionPicker
                
                // 内容区域
                ScrollView {
                    VStack(spacing: 24) {
                        contentForSelectedSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Privacy Guide".localstr())
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // 选择器
    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(PrivacySection.allCases, id: \.self) { section in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedSection = section
                        }
                    }) {
                        Text(section.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedSection == section ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedSection == section ? Color.blue : Color(.systemGray6))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // 根据选择的部分显示内容
    @ViewBuilder
    private var contentForSelectedSection: some View {
        switch selectedSection {
        case .overview:
            overviewSection
        case .vpnBasics:
            vpnBasicsSection
        case .dataProtection:
            dataProtectionSection
        case .onlineSafety:
            onlineSafetySection
        case .bestPractices:
            bestPracticesSection
        }
    }
    
    // 概述部分
    private var overviewSection: some View {
        VStack(spacing: 20) {
            privacyCard(
                icon: "shield.lefthalf.filled",
                title: "Privacy_Matters_Title".localstr(),
                content: "Privacy_Matters_Content".localstr(),
                color: .blue
            )
            
            privacyCard(
                icon: "eye.slash.fill",
                title: "What_We_Protect_Title".localstr(),
                content: "What_We_Protect_Content".localstr(),
                color: .green
            )
            
            privacyCard(
                icon: "lock.shield.fill",
                title: "Our_Commitment_Title".localstr(),
                content: "Our_Commitment_Content".localstr(),
                color: .purple
            )
        }
    }
    
    // VPN基础知识
    private var vpnBasicsSection: some View {
        VStack(spacing: 20) {
            privacyCard(
                icon: "network",
                title: "How_VPN_Works_Title".localstr(),
                content: "How_VPN_Works_Content".localstr(),
                color: .blue
            )
            
            privacyCard(
                icon: "key.fill",
                title: "Encryption_Explained_Title".localstr(),
                content: "Encryption_Explained_Content".localstr(),
                color: .orange
            )
            
            privacyCard(
                icon: "globe",
                title: "Server_Locations_Title".localstr(),
                content: "Server_Locations_Content".localstr(),
                color: .green
            )
        }
    }
    
    // 数据保护
    private var dataProtectionSection: some View {
        VStack(spacing: 20) {
            privacyCard(
                icon: "doc.text.fill",
                title: "No_Logs_Policy_Title".localstr(),
                content: "No_Logs_Policy_Content".localstr(),
                color: .blue
            )
            
            privacyCard(
                icon: "creditcard.fill",
                title: "Payment_Privacy_Title".localstr(),
                content: "Payment_Privacy_Content".localstr(),
                color: .green
            )
            
            privacyCard(
                icon: "externaldrive.fill",
                title: "Data_Storage_Title".localstr(),
                content: "Data_Storage_Content".localstr(),
                color: .purple
            )
        }
    }
    
    // 在线安全
    private var onlineSafetySection: some View {
        VStack(spacing: 20) {
            privacyCard(
                icon: "wifi",
                title: "Public_WiFi_Safety_Title".localstr(),
                content: "Public_WiFi_Safety_Content".localstr(),
                color: .red
            )
            
            privacyCard(
                icon: "eye.slash",
                title: "ISP_Tracking_Prevention_Title".localstr(),
                content: "ISP_Tracking_Prevention_Content".localstr(),
                color: .orange
            )
            
            privacyCard(
                icon: "location.slash",
                title: "Location_Privacy_Title".localstr(),
                content: "Location_Privacy_Content".localstr(),
                color: .blue
            )
        }
    }
    
    // 最佳实践
    private var bestPracticesSection: some View {
        VStack(spacing: 20) {
            privacyCard(
                icon: "checkmark.shield.fill",
                title: "VPN_Best_Practices_Title".localstr(),
                content: "VPN_Best_Practices_Content".localstr(),
                color: .green
            )
            
            privacyCard(
                icon: "person.crop.circle.badge.exclamationmark",
                title: "Additional_Privacy_Tips_Title".localstr(),
                content: "Additional_Privacy_Tips_Content".localstr(),
                color: .purple
            )
            
            privacyCard(
                icon: "exclamationmark.triangle.fill",
                title: "What_VPN_Cannot_Do_Title".localstr(),
                content: "What_VPN_Cannot_Do_Content".localstr(),
                color: .orange
            )
        }
    }
    
    // 隐私卡片组件
    private func privacyCard(icon: String, title: String, content: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// 隐私指南部分枚举
enum PrivacySection: CaseIterable {
    case overview
    case vpnBasics
    case dataProtection
    case onlineSafety
    case bestPractices
    
    var title: String {
        switch self {
        case .overview:
            return "Overview".localstr()
        case .vpnBasics:
            return "VPN_Basics".localstr()
        case .dataProtection:
            return "Data_Protection".localstr()
        case .onlineSafety:
            return "Online_Safety".localstr()
        case .bestPractices:
            return "Best_Practices".localstr()
        }
    }
}

#Preview {
    PrivacyGuideView()
}
