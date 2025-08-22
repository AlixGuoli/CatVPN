//
//  Y.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/2.
//

import Foundation

import CryptoKit
import Network

class ConnectConfigHandler {
    
    static let shared = ConnectConfigHandler()
    
    func savedGroupServiceConfig(serviceConfig: String) async throws {
        logDebug("[直连配置] === 开始处理连接配置 ===")
        var groupConfig : String
        groupConfig = adjustInboundParameters(in: serviceConfig) ?? serviceConfig
        
        groupConfig = enhanceDomainRouting(in: groupConfig) ?? groupConfig
        
        let userDefaults = UserDefaults(suiteName: ServiceDefaults.targetGroup)
        userDefaults?.set(Date(), forKey: ServiceDefaults.targetDate)
        userDefaults?.set(groupConfig, forKey: ServiceDefaults.targetConfig)
        userDefaults?.synchronize()
        
        logDebug("[直连配置] Save Connect Config to Group UserDefaults ** ⬇️")
        logDebug("[直连配置] 最终配置: \(groupConfig)")
    }
    
    private func adjustInboundParameters(in jsonPayload: String) -> String? {
        guard let jsonPayload = jsonPayload.data(using: .utf8),
              var configurationMap = (try? JSONSerialization.jsonObject(with: jsonPayload, options: [])) as? [String: Any] else {
            return nil
        }
        
        if var entryProtocols = configurationMap["inbounds"] as? [[String: Any]],
           var firstEntryProtocol = entryProtocols.first {
            firstEntryProtocol["listen"] = "[::1]"
            firstEntryProtocol["port"] = "8080"
            entryProtocols[0] = firstEntryProtocol
            configurationMap["inbounds"] = entryProtocols
        }
        
        guard let updatedData = try? JSONSerialization.data(withJSONObject: configurationMap, options: .prettyPrinted),
              let updatedJsonString = String(data: updatedData, encoding: .utf8) else {
            return nil
        }
        
        return updatedJsonString
    }

    func enhanceDomainRouting(in jsonPayload: String) -> String? {
        let editableConfig = jsonPayload
        guard let configurationData = jsonPayload.data(using: .utf8),
              var configMap = (try? JSONSerialization.jsonObject(with: configurationData, options: [])) as? [String: Any] else {
            logDebug("[直连配置] !!! enhanceDomainRouting: Failed to parse JSON")
            return editableConfig
        }
        
        logDebug("[直连配置] === 开始添加直连规则 ===")
        var domainRules: [[String: Any]] = []
        
        let addDirectRoute = { (domain: [String]) in
            domainRules.append([
                "type" : "field",
                "domain" : domain,
                "outboundTag" : "direct"
            ])
            logDebug("[直连配置] 添加直连规则: \(domain)")
        }
        
        // 添加固定的直连域名
        addDirectRoute(["raw.githubusercontent.com"])
        addDirectRoute(["yastatic","yandex","gameanalytics","mradx.net","target.my.com","vk.ru","vk.me","vk.com","mail.ru"])
        
        var bypassHosts: [String] = []

        // 缓存配置，避免重复调用
        let hostConfig = HostCFHelper.shared.getCurOrLoaclHostCF()
        logDebug("[直连配置] 获取到的host配置: \(hostConfig ?? "nil")")
        
        // 获取 connReport 域名
        if let connReport = HostCFHelper.shared.getConnReport(from: hostConfig) {
            logDebug("[直连配置] connReport: \(connReport)")
            if let connHost = URL(string: connReport)?.host {
                bypassHosts.append(connHost)
                logDebug("[直连配置] 添加 connReport 域名到直连: \(connHost)")
            } else {
                logDebug("[直连配置] !!! 无法解析 connReport 域名: \(connReport)")
            }
        } else {
            logDebug("[直连配置] !!! 未获取到 connReport")
        }
        
        // 获取 genReport 域名
        if let genReport = HostCFHelper.shared.getGReport(from: hostConfig) {
            logDebug("[直连配置] genReport: \(genReport)")
            if let genHost = URL(string: genReport)?.host {
                bypassHosts.append(genHost)
                logDebug("[直连配置] 添加 genReport 域名到直连: \(genHost)")
            } else {
                logDebug("[直连配置] !!! 无法解析 genReport 域名: \(genReport)")
            }
        } else {
            logDebug("[直连配置] !!! 未获取到 genReport")
        }
        
        // 获取 hostList 域名
        if let hosts = HostCFHelper.shared.getHostList(from: hostConfig) {
            logDebug("[直连配置] hostList: \(hosts)")
            let hostDomains = hosts.compactMap { URL(string: $0)?.host }
            bypassHosts.append(contentsOf: hostDomains)
            logDebug("[直连配置] 添加 hostList 域名到直连: \(hostDomains)")
        } else {
            logDebug("[直连配置] !!! 未获取到 hostList")
        }
        
        logDebug("[直连配置] 所有需要直连的域名: \(bypassHosts)")
        
        if !bypassHosts.isEmpty {
            addDirectRoute(bypassHosts)
        } else {
            logDebug("[直连配置] !!! 没有需要直连的域名")
        }
        
        logDebug("[直连配置] 最终直连规则数量: \(domainRules.count)")
        for (index, rule) in domainRules.enumerated() {
            logDebug("[直连配置] 规则 \(index + 1): \(rule)")
        }
        
        // 更新配置
        if configMap["routing"] == nil {
            configMap["routing"] = [
                "domainStrategy" : "AsIs",
                "rules" : domainRules
            ]
            logDebug("[直连配置] 创建新的 routing 配置")
        } else if var routing = configMap["routing"] as? [String: Any] {
            routing["rules"] = domainRules
            configMap["routing"] = routing
            logDebug("[直连配置] 更新现有 routing 配置")
        }
        
        if let updatedConfigurationData = try? JSONSerialization.data(withJSONObject: configMap, options: .prettyPrinted) {
            let result = String(data: updatedConfigurationData, encoding: .utf8)
            logDebug("[直连配置] === 直连规则添加完成 ===")
            return result
        }
        
        logDebug("[直连配置] !!! 直连规则添加失败")
        return editableConfig
    }
    
}
