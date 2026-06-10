//
//  VPNModel.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI

enum VPNConnectionStatus {
    case disconnected
    case connecting
    case connected
    case failed

    var statusText: String {
        switch self {
        case .disconnected:
            return "Disconnected".localstr()
        case .connecting:
            return "Connecting...".localstr()
        case .connected:
            return "Connected".localstr()
        case .failed:
            return "Connection_Failed".localstr()
        }
    }

    var statusColor: Color {
        switch self {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}

struct VPNServer: Identifiable, Hashable {
    let id: Int
    let name: String
    let country: String
    let flagEmoji: String
    let ping: Int

    static let availableServers = [
        VPNServer(id: -1, name: "Auto", country: "AUTO", flagEmoji: "⚡️", ping: Int.random(in: 10...30)),
        VPNServer(id: 104, name: "Germany", country: "DE", flagEmoji: "🇩🇪", ping: Int.random(in: 8...30)),
        VPNServer(id: 105, name: "United States", country: "US", flagEmoji: "🇺🇸", ping: Int.random(in: 9...40)),
        VPNServer(id: 102, name: "United Kingdom", country: "GB", flagEmoji: "🇬🇧", ping: Int.random(in: 13...45)),
        VPNServer(id: 106, name: "Netherlands", country: "NL", flagEmoji: "🇳🇱", ping: Int.random(in: 12...30))
    ]
}
