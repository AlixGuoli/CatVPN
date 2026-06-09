//
//  ConnectConfigHandler.swift
//  CatVPN
//

import Foundation
import CryptoKit
import Network

class ConnectConfigHandler {

    static let shared = ConnectConfigHandler()

    func savedGroupServiceConfig(serviceConfig: String) async throws {
        linkLog("xray process json")
        let processedConfig = processConfigurationPipeline(serviceConfig) ?? serviceConfig
        await persistConfiguration(processedConfig)
        linkLog("xray saved app group")
    }

    // MARK: - Pipeline

    private func processConfigurationPipeline(_ jsonString: String) -> String? {
        guard let config = parseConfigurationData(jsonString) else { return nil }
        let updatedConfig = updateInboundConfiguration(config)
        let enhancedConfig = enhanceRoutingConfiguration(updatedConfig)
        return serializeConfiguration(enhancedConfig)
    }

    private func parseConfigurationData(_ jsonString: String) -> [String: Any]? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: jsonData, options: [])) as? [String: Any]
    }

    private func serializeConfiguration(_ config: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }

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

    private func enhanceRoutingConfiguration(_ config: [String: Any]) -> [String: Any] {
        let bypassDomains = collectBypassDomains()
        let routingRules = constructRoutingRules(bypassDomains)
        return mergeRoutingConfiguration(config, rules: routingRules)
    }

    /// Yandex / Easy Monetization 广告请求走直连，避免 VPN 隧道拦截。
    private static let adDirectDomains = [
        "yandex.ru",
        "yandexadexchange.net",
        "adfox.ru",
        "appmetrica.yandex.ru",
        "yastatic",
        "yandex",
        "mradx.net",
        "target.my.com",
        "vk.ru",
        "vk.me",
        "vk.com",
        "mail.ru",
        "gameanalytics",
    ]

    private func collectBypassDomains() -> [String] {
        var domains = Self.adDirectDomains
        domains.append(contentsOf: extractDynamicDomains(from: HostBootstrap.activeJSON()))
        return domains
    }

    private func extractDynamicDomains(from hostJSON: String?) -> [String] {
        guard let cfg = HostBootstrap.parse(json: hostJSON) else { return [] }
        var domains: [String] = []
        if let conn = cfg.connReport, let h = URL(string: conn)?.host { domains.append(h) }
        if let gen = cfg.gReport, let h = URL(string: gen)?.host { domains.append(h) }
        domains.append(contentsOf: cfg.hosts.compactMap { URL(string: $0)?.host })
        return domains
    }

    private func constructRoutingRules(_ domains: [String]) -> [[String: Any]] {
        var rules: [[String: Any]] = [
            ["type": "field", "domain": ["raw.githubusercontent.com"], "outboundTag": "direct"]
        ]
        if !domains.isEmpty {
            rules.append(["type": "field", "domain": domains, "outboundTag": "direct"])
        }
        linkLog("xray direct rules=\(rules.count) domains=\(domains.count)")
        return rules
    }

    private func mergeRoutingConfiguration(_ config: [String: Any], rules: [[String: Any]]) -> [String: Any] {
        var mergedConfig = config
        if mergedConfig["routing"] == nil {
            mergedConfig["routing"] = ["domainStrategy": "AsIs", "rules": rules]
        } else if var routing = mergedConfig["routing"] as? [String: Any] {
            routing["rules"] = rules
            mergedConfig["routing"] = routing
        }
        return mergedConfig
    }

    private func persistConfiguration(_ config: String) async {
        let userDefaults = UserDefaults(suiteName: ServiceDefaults.targetGroup)
        userDefaults?.set(Date(), forKey: ServiceDefaults.targetDate)
        userDefaults?.set(config, forKey: ServiceDefaults.targetConfig)
        userDefaults?.synchronize()
    }
}
