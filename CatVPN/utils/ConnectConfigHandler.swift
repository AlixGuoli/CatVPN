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
        var groupConfig : String
        groupConfig = adjustInboundParameters(in: serviceConfig) ?? serviceConfig
        
        groupConfig = enhanceDomainRouting(in: groupConfig) ?? groupConfig
        
        let userDefaults = UserDefaults(suiteName: ServiceDefaults.targetGroup)
        userDefaults?.set(Date(), forKey: ServiceDefaults.targetDate)
        userDefaults?.set(groupConfig, forKey: ServiceDefaults.targetConfig)
        userDefaults?.synchronize()
        
        logDebug("Save Connect Config to Group UserDefaults ** ⬇️")
        logDebug(groupConfig)
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
        var editableConfig = jsonPayload
        guard let configurationData = jsonPayload.data(using: .utf8),
              var configMap = (try? JSONSerialization.jsonObject(with: configurationData, options: [])) as? [String: Any] else {
            return editableConfig
        }
        
        var domainRules: [[String: Any]] = []
        
        let addDirectRoute = { (domain: [String]) in
            domainRules.append([
                "type" : "field",
                "domain" : domain,
                "outboundTag" : "direct"
            ])
        }
        
        addDirectRoute(["raw.githubusercontent.com"])
        addDirectRoute(["yastatic","yandex","gameanalytics","mradx.net","target.my.com","vk.ru","vk.me","vk.com","mail.ru"])
        
        var bypassHosts: [String] = []
        
        // 缓存配置，避免重复调用
        let hostConfig = HostCFHelper.shared.getCurOrLoaclHostCF()
        
        if let connReport = HostCFHelper.shared.getConnReport(from: hostConfig) {
            if let connHost = URL(string: connReport)?.host {
                bypassHosts.append(connHost)
            }
        }
        
        if let genReport = HostCFHelper.shared.getGReport(from: hostConfig) {
            if let genHost = URL(string: genReport)?.host {
                bypassHosts.append(genHost)
            }
        }
        
        if let hosts = HostCFHelper.shared.getHostList(from: hostConfig) {
            bypassHosts.append(contentsOf: hosts.compactMap { URL(string: $0)?.host })
        }
        
        if !bypassHosts.isEmpty {
            addDirectRoute(bypassHosts)
        }
        
        if configMap["routing"] == nil {
            configMap["routing"] = [
                "domainStrategy" : "AsIs",
                "rules" : domainRules
            ]
        } else if var routing = configMap["routing"] as? [String: Any] {
            routing["rules"] = domainRules
            configMap["routing"] = routing
        }
        
        if let updatedConfigurationData = try? JSONSerialization.data(withJSONObject: configMap, options: .prettyPrinted) {
            return String(data: updatedConfigurationData, encoding: .utf8)
        }
        
        return editableConfig
    }
    
}
