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
        
        let processedConfig = processConfigurationPipeline(serviceConfig) ?? serviceConfig
        await persistConfiguration(processedConfig)
        
        logDebug("[直连配置] Save Connect Config to Group UserDefaults ** ⬇️")
        logDebug("[直连配置] 最终配置: \(processedConfig)")
    }
    
    // MARK: - 配置处理管道
    
    private func processConfigurationPipeline(_ jsonString: String) -> String? {
        guard let config = parseConfigurationData(jsonString) else { return nil }
        let updatedConfig = updateInboundConfiguration(config)
        let enhancedConfig = enhanceRoutingConfiguration(updatedConfig)
        return serializeConfiguration(enhancedConfig)
    }
    
    // MARK: - 配置解析和序列化
    
    private func parseConfigurationData(_ jsonString: String) -> [String: Any]? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: jsonData, options: [])) as? [String: Any]
    }
    
    private func serializeConfiguration(_ config: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    
    // MARK: - 入站配置更新
    
    private func updateInboundConfiguration(_ config: [String: Any]) -> [String: Any] {
        var updatedConfig = config
        guard var inbounds = updatedConfig["inbounds"] as? [[String: Any]],
              var firstInbound = inbounds.first else { return updatedConfig }
        
        firstInbound["listen"] = "[::1]"
        firstInbound["port"] = "8080"
        inbounds[0] = firstInbound
        updatedConfig["inbounds"] = inbounds
        
        return updatedConfig
    }
    
    // MARK: - 路由配置增强
    
    private func enhanceRoutingConfiguration(_ config: [String: Any]) -> [String: Any] {
        let enhancedConfig = config
        let bypassDomains = collectBypassDomains()
        let routingRules = constructRoutingRules(bypassDomains)
        return mergeRoutingConfiguration(enhancedConfig, rules: routingRules)
    }
    
    private func collectBypassDomains() -> [String] {
        var domains: [String] = []
        
        // 固定域名
        domains.append(contentsOf: ["yastatic","yandex","gameanalytics","mradx.net","target.my.com","vk.ru","vk.me","vk.com","mail.ru"])
        
        // 动态域名
        let hostConfig = HostCFHelper.shared.getCurOrLoaclHostCF()
        domains.append(contentsOf: extractDynamicDomains(from: hostConfig))
        
        return domains
    }
    
    private func extractDynamicDomains(from hostConfig: String?) -> [String] {
        var domains: [String] = []
        
        logDebug("[直连配置] 获取到的host配置: \(hostConfig ?? "nil")")
        
        // 获取 connReport 域名
        if let connReport = HostCFHelper.shared.getConnReport(from: hostConfig) {
            logDebug("[直连配置] connReport: \(connReport)")
            if let connHost = URL(string: connReport)?.host {
                domains.append(connHost)
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
                domains.append(genHost)
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
            domains.append(contentsOf: hostDomains)
            logDebug("[直连配置] 添加 hostList 域名到直连: \(hostDomains)")
        } else {
            logDebug("[直连配置] !!! 未获取到 hostList")
        }
        
        return domains
    }
    
    private func constructRoutingRules(_ domains: [String]) -> [[String: Any]] {
        logDebug("[直连配置] === 开始添加直连规则 ===")
        var rules: [[String: Any]] = []
        
        // 固定规则：raw.githubusercontent.com 单独处理
        rules.append([
            "type": "field",
            "domain": ["raw.githubusercontent.com"],
            "outboundTag": "direct"
        ])
        logDebug("[直连配置] 添加直连规则: [\"raw.githubusercontent.com\"]")
        
        // 动态规则：其他域名
        if !domains.isEmpty {
            rules.append([
                "type": "field",
                "domain": domains,
                "outboundTag": "direct"
            ])
            logDebug("[直连配置] 添加直连规则: \(domains)")
        } else {
            logDebug("[直连配置] !!! 没有需要直连的域名")
        }
        
        logDebug("[直连配置] 最终直连规则数量: \(rules.count)")
        for (index, rule) in rules.enumerated() {
            logDebug("[直连配置] 规则 \(index + 1): \(rule)")
        }
        
        return rules
    }
    
    private func mergeRoutingConfiguration(_ config: [String: Any], rules: [[String: Any]]) -> [String: Any] {
        var mergedConfig = config
        
        if mergedConfig["routing"] == nil {
            mergedConfig["routing"] = [
                "domainStrategy": "AsIs",
                "rules": rules
            ]
            logDebug("[直连配置] 创建新的 routing 配置")
        } else if var routing = mergedConfig["routing"] as? [String: Any] {
            routing["rules"] = rules
            mergedConfig["routing"] = routing
            logDebug("[直连配置] 更新现有 routing 配置")
        }
        
        logDebug("[直连配置] === 直连规则添加完成 ===")
        return mergedConfig
    }
    
    // MARK: - 配置持久化
    
    private func persistConfiguration(_ config: String) async {
        let userDefaults = UserDefaults(suiteName: ServiceDefaults.targetGroup)
        userDefaults?.set(Date(), forKey: ServiceDefaults.targetDate)
        userDefaults?.set(config, forKey: ServiceDefaults.targetConfig)
        userDefaults?.synchronize()
    }
}
