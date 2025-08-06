//
//  ServerCFHelper.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/2.
//

import Foundation

class ServerCFHelper {
    
    static let shared = ServerCFHelper()
    
    private init() {}
    
    // MARK: - 全局服务器ID
    private let selectedServerIDKey = "SelectedServerID"
    
    // 当前选择的服务器ID
    var currentServerID: Int {
        get {
            let savedID = UserDefaults.standard.integer(forKey: selectedServerIDKey)
            // 如果没有保存的ID或ID为0，返回默认值-1
            return savedID != 0 ? savedID : -1
        }
        set {
            UserDefaults.standard.set(newValue, forKey: selectedServerIDKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: - 服务器列表管理
    
    /// 获取服务器列表
    func fetchServers() async -> [VPNServer] {
        logDebug("Start to fetch servers")
        let countryData = await HttpUtils.shared.fetchCountry()
        
        if let data = countryData {
            let servers = parseServerData(from: data)
            logDebug("Successfully fetched \(servers.count) servers from API")
            return servers
        } else {
            logDebug("Failed to fetch servers, using default servers")
            return VPNServer.availableServers
        }
    }
    
    /// 解析服务器数据
    private func parseServerData(from jsonString: String) -> [VPNServer] {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let serviceGroups = json["serviceGroups"] as? [[String: Any]] else {
            logDebug("Failed to parse server data")
            return []
        }
        
        var servers: [VPNServer] = []
        
        for group in serviceGroups {
            guard let id = group["id"] as? Int,
                  let name = group["name"] as? String,
                  let country = group["country"] as? String else {
                logDebug("Invalid server group data: \(group)")
                continue
            }
            
            let server = VPNServer(
                id: id,
                name: name,
                country: country,
                flagEmoji: getFlagEmoji(for: country),
                ping: Int.random(in: 10...50)  // 随机ping值
            )
            servers.append(server)
        }
        
        // 确保Auto选项始终在列表开头（如果接口数据中没有Auto，则添加）
        if !servers.contains(where: { $0.id == -1 }) {
            let autoServer = VPNServer(id: -1, name: "Auto", country: "AUTO", flagEmoji: "⚡️", ping: Int.random(in: 10...30))
            servers.insert(autoServer, at: 0)
            logDebug("Added Auto server to API data")
        }
        
        return servers
    }
    
    /// 根据国家代码获取国旗emoji
    private func getFlagEmoji(for countryCode: String) -> String {
        let flagMapping = [
            "DE": "🇩🇪",
            "NL": "🇳🇱", 
            "US": "🇺🇸",
            "GB": "🇬🇧",
            "JP": "🇯🇵",
            "SG": "🇸🇬",
            "KR": "🇰🇷",
            "CA": "🇨🇦",
            "UK": "🇬🇧",
            "FR": "🇫🇷",
            "AU": "🇦🇺",
            "BR": "🇧🇷",
            "IN": "🇮🇳",
            "IT": "🇮🇹",
            "ES": "🇪🇸",
            "SE": "🇸🇪",
            "NO": "🇳🇴",
            "DK": "🇩🇰",
            "FI": "🇫🇮",
            "CH": "🇨🇭",
            "AT": "🇦🇹",
            "BE": "🇧🇪",
            "IE": "🇮🇪",
            "PT": "🇵🇹",
            "GR": "🇬🇷",
            "PL": "🇵🇱",
            "CZ": "🇨🇿",
            "HU": "🇭🇺",
            "RO": "🇷🇴",
            "BG": "🇧🇬",
            "HR": "🇭🇷",
            "SI": "🇸🇮",
            "SK": "🇸🇰",
            "LT": "🇱🇹",
            "LV": "🇱🇻",
            "EE": "🇪🇪",
            "LU": "🇱🇺",
            "MT": "🇲🇹",
            "CY": "🇨🇾"
        ]
        return flagMapping[countryCode] ?? "🇩🇪"
    }
    
    // MARK: - 服务器选择管理
    
    /// 保存选择的服务器
    func saveSelectedServer(_ server: VPNServer) {
        currentServerID = server.id
        logDebug("Saved selected server: \(server.name) (ID: \(server.id))")
    }
    
    /// 获取当前选择的服务器
    func getCurrentSelectedServer(from servers: [VPNServer]) -> VPNServer {
        let savedID = currentServerID
        
        // 如果有保存的ID且不是默认值-1，尝试找到对应的服务器
        if savedID != -1 {
            if let savedServer = servers.first(where: { $0.id == savedID }) {
                logDebug("Restored selected server from API: \(savedServer.name) (ID: \(savedServer.id))")
                return savedServer
            } else {
                logDebug("Saved server ID (\(savedID)) not found in available servers")
            }
        }
        
        // 如果没有保存的ID或找不到服务器，选择Auto（ID: -1）
        if let autoServer = servers.first(where: { $0.id == -1 }) {
            logDebug("Using Auto server: \(autoServer.name) (ID: \(autoServer.id))")
            return autoServer
        }
        
        // 如果连Auto都找不到，使用第一个服务器
        let defaultServer = servers.first ?? VPNServer(id: -1, name: "Auto", country: "AUTO", flagEmoji: "⚡️", ping: 18)
        logDebug("Using default server: \(defaultServer.name) (ID: \(defaultServer.id))")
        return defaultServer
    }
    
    /// 获取默认服务器列表
    func getDefaultServers() -> [VPNServer] {
        return VPNServer.availableServers
    }
    
    /// 获取当前服务器ID（供其他地方使用）
    func getCurrentServerID() -> Int {
        return currentServerID
    }
    
    /// 设置当前服务器ID（供其他地方使用）
    func setCurrentServerID(_ id: Int) {
        currentServerID = id
        logDebug("Set current server ID to: \(id)")
    }
} 
