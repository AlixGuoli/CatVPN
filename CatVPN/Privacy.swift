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
            .navigationTitle("Privacy Guide")
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
                title: "Why Privacy Matters",
                content: """
                In today's digital world, your online privacy is more important than ever. Every website you visit, every search you make, and every app you use can potentially collect your personal data.
                
                A VPN (Virtual Private Network) is one of the most effective tools to protect your privacy and secure your internet connection.
                """,
                color: .blue
            )
            
            privacyCard(
                icon: "eye.slash.fill",
                title: "What We Protect",
                content: """
                • Your IP address and location
                • Your browsing history and online activities
                • Your personal data from hackers and snoopers
                • Your connection on public Wi-Fi networks
                • Your access to geo-restricted content
                """,
                color: .green
            )
            
            privacyCard(
                icon: "lock.shield.fill",
                title: "Our Commitment",
                content: """
                We are committed to protecting your privacy with:
                • No-logs policy - We don't track or store your online activities
                • Military-grade encryption to secure your data
                • Secure servers located in privacy-friendly countries
                • Transparent privacy practices and regular security audits
                """,
                color: .purple
            )
        }
    }
    
    // VPN基础知识
    private var vpnBasicsSection: some View {
        VStack(spacing: 20) {
            privacyCard(
                icon: "network",
                title: "How VPN Works",
                content: """
                A VPN creates a secure, encrypted tunnel between your device and our servers. Here's what happens:
                
                1. Your device connects to our VPN server
                2. All your internet traffic is encrypted
                3. Your real IP address is hidden
                4. Websites see our server's IP, not yours
                5. Your ISP can't see what websites you visit
                """,
                color: .blue
            )
            
            privacyCard(
                icon: "key.fill",
                title: "Encryption Explained",
                content: """
                We use AES-256 encryption, the same standard used by:
                • Government agencies
                • Banks and financial institutions
                • Military organizations
                
                This encryption is so strong that it would take billions of years for a computer to crack it using brute force methods.
                """,
                color: .orange
            )
            
            privacyCard(
                icon: "globe",
                title: "Server Locations",
                content: """
                Our servers are strategically located around the world to provide:
                • Fast connection speeds
                • Access to geo-restricted content
                • Protection under privacy-friendly laws
                • Redundancy and reliability
                
                Choose servers closer to your location for better speeds, or farther away for enhanced privacy.
                """,
                color: .green
            )
        }
    }
    
    // 数据保护
    private var dataProtectionSection: some View {
        VStack(spacing: 20) {
            privacyCard(
                icon: "doc.text.fill",
                title: "No-Logs Policy",
                content: """
                We strictly follow a no-logs policy, which means:
                
                ✅ We DON'T log:
                • Your browsing history
                • Your real IP address
                • Your DNS queries
                • Your connection timestamps
                • Any content of your communications
                
                ❌ We only keep minimal data for service operation:
                • Aggregated bandwidth usage (not linked to users)
                • Server performance metrics
                • Payment information (processed by third parties)
                """,
                color: .blue
            )
            
            privacyCard(
                icon: "creditcard.fill",
                title: "Payment Privacy",
                content: """
                Your payment information is handled securely:
                
                • We accept anonymous payment methods
                • Credit card processing is handled by certified payment processors
                • We don't store your payment details on our servers
                • You can use cryptocurrency for maximum anonymity
                • Account creation requires minimal personal information
                """,
                color: .green
            )
            
            privacyCard(
                icon: "externaldrive.fill",
                title: "Data Storage",
                content: """
                All our servers operate on RAM-only systems:
                
                • No data is written to hard drives
                • All data is wiped when servers restart
                • Physical server security in certified data centers
                • Regular security audits by independent firms
                • Compliance with international privacy standards
                """,
                color: .purple
            )
        }
    }
    
    // 在线安全
    private var onlineSafetySection: some View {
        VStack(spacing: 20) {
            privacyCard(
                icon: "wifi",
                title: "Public Wi-Fi Safety",
                content: """
                Public Wi-Fi networks are convenient but dangerous:
                
                🚨 Risks:
                • Hackers can intercept your data
                • Fake hotspots can steal your information
                • Man-in-the-middle attacks
                • Malware distribution
                
                ✅ VPN Protection:
                • Encrypts all your traffic
                • Prevents data interception
                • Hides your activity from network operators
                • Secures your connection on any network
                """,
                color: .red
            )
            
            privacyCard(
                icon: "eye.slash",
                title: "ISP Tracking Prevention",
                content: """
                Your Internet Service Provider (ISP) can see:
                • Every website you visit
                • How long you spend on each site
                • Your download and upload activities
                • Your online habits and interests
                
                With a VPN:
                • Your ISP only sees encrypted traffic to our servers
                • Your browsing history remains private
                • No throttling based on content type
                • Protection from ISP data selling
                """,
                color: .orange
            )
            
            privacyCard(
                icon: "location.slash",
                title: "Location Privacy",
                content: """
                Your IP address reveals:
                • Your approximate physical location
                • Your internet service provider
                • Your timezone and region
                • Potentially your identity
                
                VPN benefits:
                • Masks your real location
                • Prevents geo-tracking
                • Bypasses location-based restrictions
                • Enables access to global content
                """,
                color: .blue
            )
        }
    }
    
    // 最佳实践
    private var bestPracticesSection: some View {
        VStack(spacing: 20) {
            privacyCard(
                icon: "checkmark.shield.fill",
                title: "VPN Best Practices",
                content: """
                🔹 Always connect before browsing
                • Turn on VPN before opening any apps
                • Use auto-connect for trusted networks
                • Enable kill switch to prevent leaks
                
                🔹 Choose the right server
                • Nearby servers for speed
                • Distant servers for privacy
                • Specific countries for content access
                
                🔹 Keep your VPN updated
                • Install updates promptly
                • Use the latest app version
                • Report any issues immediately
                """,
                color: .green
            )
            
            privacyCard(
                icon: "person.crop.circle.badge.exclamationmark",
                title: "Additional Privacy Tips",
                content: """
                🔒 Use strong, unique passwords
                • Enable two-factor authentication
                • Use a password manager
                • Regularly update your passwords
                
                🔒 Browser privacy
                • Use private/incognito mode
                • Clear cookies and cache regularly
                • Disable location services
                • Use privacy-focused browsers
                
                🔒 Social media safety
                • Review privacy settings
                • Limit personal information sharing
                • Be cautious with public posts
                • Use privacy-focused alternatives
                """,
                color: .purple
            )
            
            privacyCard(
                icon: "exclamationmark.triangle.fill",
                title: "What VPN Cannot Do",
                content: """
                🚫 VPN limitations:
                • Cannot protect against malware
                • Doesn't prevent phishing attacks
                • Cannot secure compromised accounts
                • Doesn't make illegal activities legal
                
                🛡️ Additional protection needed:
                • Use antivirus software
                • Keep software updated
                • Be cautious with email links
                • Verify website authenticity
                • Use secure messaging apps
                """,
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
            return "Overview"
        case .vpnBasics:
            return "VPN Basics"
        case .dataProtection:
            return "Data Protection"
        case .onlineSafety:
            return "Online Safety"
        case .bestPractices:
            return "Best Practices"
        }
    }
}

#Preview {
    PrivacyGuideView()
}
