//
//  BaseCFHelper.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/4.
//

import Foundation

/// getconf配置
class BaseCFHelper {
    
    static let shared = BaseCFHelper()
    private init() {}
    
    /// 获取detectionServers列表
    func getDetectionServers() -> [String]? {
        guard let config = getBaseCF() else { return nil }
        return extractDetectionServers(from: config)
    }
    
    /// 获取git_version
    func getGitVersion() -> Int? {
        guard let config = getBaseCF() else { return nil }
        return extractGitVersion(from: config)
    }
    
    /// 获取adsOff
    func getAdsOff() -> Bool? {
        guard let config = getBaseCF() else { return nil }
        return extractAdsOff(from: config)
    }
    
    /// 获取adsType
    func getAdsType() -> String? {
        guard let config = getBaseCF() else { return nil }
        return extractAdsType(from: config)
    }
    
    /// 获取dynamic_tg_link
    func getDynamicTgLink() -> String? {
        guard let config = getBaseCF() else { return nil }
        return extractDynamicTgLink(from: config)
    }
    
    /// 获取ios_professional_versions
    func getIosProfessionalVersions() -> [String]? {
        guard let config = getBaseCF() else { return nil }
        return extractIosProfessionalVersions(from: config)
    }
    
    /// 获取hotcode
    func getHotcode() -> String? {
        guard let config = getBaseCF() else { return nil }
        return extractHotcode(from: config)
    }
    
    /// 获取rateus配置 (maxDailyPopups, cooldownDays)
    func getRateusConfig() -> (Int?, Int?) {
        guard let config = getBaseCF() else { return (nil, nil) }
        return extractRateusConfig(from: config)
    }
    
    
    /// 从配置中获取detectionServers列表
    /// - Parameter config: 配置JSON字符串
    /// - Returns: detectionServers字符串数组
    private func extractDetectionServers(from config: String) -> [String]? {
        do {
            guard let jsonData = config.data(using: .utf8),
                  let configDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let commonConfDict = configDict["commonConf"] as? [String: Any],
                  let detectionConfigDict = commonConfDict["detectionConfig"] as? [String: Any],
                  let detectionServersArray = detectionConfigDict["detectionServers"] as? [String] else {
                return nil
            }
            return detectionServersArray
        } catch {
            logDebug("[ BaseCFHelper ] extractDetectionServers error: \(error)")
            return nil
        }
    }
    
    /// 从配置中获取git_version
    /// - Parameter config: 配置JSON字符串
    /// - Returns: git_version整数
    private func extractGitVersion(from config: String) -> Int? {
        do {
            guard let jsonData = config.data(using: .utf8),
                  let configDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let commonConfDict = configDict["commonConf"] as? [String: Any],
                  let gitVersion = commonConfDict["git_version"] as? Int else {
                return nil
            }
            return gitVersion
        } catch {
            logDebug("[ BaseCFHelper ] extractGitVersion error: \(error)")
            return nil
        }
    }
    
    /// 从配置中获取adsOff
    /// - Parameter config: 配置JSON字符串
    /// - Returns: adsOff布尔值
    private func extractAdsOff(from config: String) -> Bool? {
        do {
            guard let jsonData = config.data(using: .utf8),
                  let configDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let commonConfDict = configDict["commonConf"] as? [String: Any],
                  let adsOff = commonConfDict["adsOff"] as? Bool else {
                return nil
            }
            return adsOff
        } catch {
            logDebug("[ BaseCFHelper ] extractAdsOff error: \(error)")
            return nil
        }
    }
    
    /// 从配置中获取adsType
    /// - Parameter config: 配置JSON字符串
    /// - Returns: adsType字符串
    private func extractAdsType(from config: String) -> String? {
        do {
            guard let jsonData = config.data(using: .utf8),
                  let configDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let commonConfDict = configDict["commonConf"] as? [String: Any],
                  let adsType = commonConfDict["adsType"] as? String else {
                return nil
            }
            return adsType
        } catch {
            logDebug("[ BaseCFHelper ] extractAdsType error: \(error)")
            return nil
        }
    }
    
    /// 从配置中获取dynamic_tg_link
    /// - Parameter config: 配置JSON字符串
    /// - Returns: dynamic_tg_link字符串
    private func extractDynamicTgLink(from config: String) -> String? {
        do {
            guard let jsonData = config.data(using: .utf8),
                  let configDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let commonConfDict = configDict["commonConf"] as? [String: Any],
                  let dynamicTgLink = commonConfDict["dynamic_tg_link"] as? String else {
                return nil
            }
            return dynamicTgLink
        } catch {
            logDebug("[ BaseCFHelper ] extractDynamicTgLink error: \(error)")
            return nil
        }
    }
    
    /// 从配置中获取ios_professional_versions
    /// - Parameter config: 配置JSON字符串
    /// - Returns: ios_professional_versions字符串数组
    private func extractIosProfessionalVersions(from config: String) -> [String]? {
        do {
            guard let jsonData = config.data(using: .utf8),
                  let configDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let commonConfDict = configDict["commonConf"] as? [String: Any],
                  let iosProfessionalVersions = commonConfDict["ios_professional_versions"] as? [String] else {
                return nil
            }
            return iosProfessionalVersions
        } catch {
            logDebug("[ BaseCFHelper ] extractIosProfessionalVersions error: \(error)")
            return nil
        }
    }
    
    /// 从配置中获取hotcode
    /// - Parameter config: 配置JSON字符串
    /// - Returns: hotcode字符串
    private func extractHotcode(from config: String) -> String? {
        do {
            guard let jsonData = config.data(using: .utf8),
                  let configDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let commonConfDict = configDict["commonConf"] as? [String: Any],
                  let hotcode = commonConfDict["hotcode"] as? String else {
                return nil
            }
            return hotcode
        } catch {
            logDebug("[ BaseCFHelper ] extractHotcode error: \(error)")
            return nil
        }
    }
    
    /// 从配置中获取rateus配置
    /// - Parameter config: 配置JSON字符串
    /// - Returns: (maxDailyPopups, cooldownDays)元组
    private func extractRateusConfig(from config: String) -> (Int?, Int?) {
        do {
            guard let jsonData = config.data(using: .utf8),
                  let configDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let commonConfDict = configDict["commonConf"] as? [String: Any],
                  let rateusDict = commonConfDict["rateus"] as? [String: Any] else {
                return (nil, nil)
            }
            
            let maxDailyPopups = rateusDict["maxDailyPopups"] as? Int
            let cooldownDays = rateusDict["cooldownDays"] as? Int
            
            return (maxDailyPopups, cooldownDays)
        } catch {
            logDebug("[ BaseCFHelper ] extractRateusConfig error: \(error)")
            return (nil, nil)
        }
    }
    
    /// 获取 UserDefaults getconf配置
    func getBaseCF() -> String? {
        let baseConfig = UserDefaults.standard.string(forKey: CatKey.CAT_BASE_CONF)
        
        if let config = baseConfig, !config.isEmpty {
            logDebug("UserDefaults Base config ** ⬇️")
            logDebug(config)
            return config
        } else {
            logDebug("!!! UserDefaults Base config is null")
            return nil
        }
    }
    
    /// 存储base配置到UserDefaults
    func saveBaseCF(_ config: String) {
        UserDefaults.standard.set(config, forKey: CatKey.CAT_BASE_CONF)
        
        // 记录保存时间
        let saveDate = Date()
        UserDefaults.standard.set(saveDate, forKey: CatKey.CAT_BASE_CONF_SAVE_DATE)
        
        UserDefaults.standard.synchronize()
        logDebug("Base config saved to UserDefaults, save time: \(saveDate)")
    }
    
}
