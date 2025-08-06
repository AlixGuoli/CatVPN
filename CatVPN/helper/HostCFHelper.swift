//
//  HostCFHelper.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/4.
//
import Foundation

/// 基础配置助手
/// 用于获取和管理本地配置，包括host列表、git源等
class HostCFHelper {
    
    static let shared = HostCFHelper()
    private init() {}
    
    // MARK: - 配置检查
    
    /// 检查UserDefaults是否有host配置
    func checkUdHostCFExist() -> Bool {
        let currentConfig = UserDefaults.standard.string(forKey: CatKey.CAT_NOW_HOST_CONF)
        return currentConfig != nil && !currentConfig!.isEmpty
    }
    
    /// 检查并保存配置（如果UserDefaults没有配置，则保存本地配置）
    func checkAndSaveConfigIfNeeded(_ config: String) {
        if !checkUdHostCFExist() {
            logDebug("UserDefaults has no host config, save local config to UserDefaults")
            saveCurrentHostConf(config)
        }
    }
    
    // MARK: - 配置获取
    
    /// 获取配置（优先UserDefaults，失败时回退到本地配置）
    func getCurOrLoaclHostCF() -> String? {
        // 优先从UserDefaults获取
        if let configString = getCurrentHostCF() {
            return configString
        }
        
        // 失败时回退到本地默认配置
        logDebug("!!! Get local config file")
        return getLocalHostConf()
    }
    
    /// 获取 UserDefaults 域名配置
    func getCurrentHostCF() -> String? {
        let currentConfig = UserDefaults.standard.string(forKey: CatKey.CAT_NOW_HOST_CONF)
        
        if let config = currentConfig, !config.isEmpty {
            logDebug("UserDefaults Host config ** ⬇️")
            logDebug(config)
            return config
        } else {
            logDebug("!!! UserDefaults Host config is null")
            return nil
        }
    }
    
    /// 获取本地文件域名配置
    private func getLocalHostConf() -> String? {
        let localConf = FileUtils.fetchLocalHostConf()
        
        if let config = localConf, !config.isEmpty {
            logDebug("Loacl file Host config ** ⬇️")
            logDebug(config)
            return config
        } else {
            logDebug("!!! Failed to get local file Host config: config is empty or nil")
            return nil
        }
    }
    
    // MARK: - 配置保存
    
    /// 保存配置到UserDefaults
    /// - Parameter config: 要保存的配置字符串
    func saveCurrentHostConf(_ config: String) {
        UserDefaults.standard.set(config, forKey: CatKey.CAT_NOW_HOST_CONF)
        
        // 记录保存时间
        let saveDate = Date()
        UserDefaults.standard.set(saveDate, forKey: CatKey.CAT_NOW_HOST_CONF_SAVE_DATE)
        
        UserDefaults.standard.synchronize()
        logDebug("Host config saved to UserDefaults, save time: \(saveDate)")
    }
    
    // MARK: - 数据提取
    
    /// 获取host列表
    func getHostList() -> [String]? {
        guard let config = getCurOrLoaclHostCF() else { return nil }
        return extractHostList(from: config)
    }
    
    /// 获取host列表（从指定配置）
    func getHostList(from config: String?) -> [String]? {
        guard let config = config else { return nil }
        return extractHostList(from: config)
    }
    
    /// 获取git源列表
    func getGitSources() -> [String]? {
        guard let config = getCurOrLoaclHostCF() else { return nil }
        return extractGitSources(from: config)
    }
    
    /// 获取git源列表（从指定配置）
    func getGitSources(from config: String?) -> [String]? {
        guard let config = config else { return nil }
        return extractGitSources(from: config)
    }
    
    /// 获取本地文件git源列表
    func getLocalGitSources() -> [String]? {
        guard let localConfig = getLocalHostConf() else { return nil }
        return extractGitSources(from: localConfig)
    }
    
    /// 获取greport地址
    func getGReport() -> String? {
        guard let config = getCurOrLoaclHostCF() else { return nil }
        return extractGReport(from: config)
    }
    
    /// 获取greport地址（从指定配置）
    func getGReport(from config: String?) -> String? {
        guard let config = config else { return nil }
        return extractGReport(from: config)
    }
    
    /// 获取connreport地址
    func getConnReport() -> String? {
        guard let config = getCurOrLoaclHostCF() else { return nil }
        return extractConnReport(from: config)
    }
    
    /// 获取connreport地址（从指定配置）
    func getConnReport(from config: String?) -> String? {
        guard let config = config else { return nil }
        return extractConnReport(from: config)
    }
    
    /// 从配置中获取host列表
    /// - Parameter config: 配置JSON字符串
    /// - Returns: host字符串数组
    private func extractHostList(from config: String) -> [String]? {
        guard let jsonData = config.data(using: .utf8),
              let configDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let apiDict = configDict["api"] as? [String: Any],
              let hostArray = apiDict["host"] as? [String] else {
            return nil
        }
        return hostArray
    }
    
    /// 从配置中获取git源列表
    /// - Parameter config: 配置JSON字符串
    /// - Returns: git源字符串数组
    private func extractGitSources(from config: String) -> [String]? {
        guard let jsonData = config.data(using: .utf8),
              let configDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let apiDict = configDict["api"] as? [String: Any],
              let gitArray = apiDict["git"] as? [String] else {
            return nil
        }
        return gitArray
    }
    
    /// 从配置中获取greport地址
    /// - Parameter config: 配置JSON字符串
    /// - Returns: greport地址字符串
    private func extractGReport(from config: String) -> String? {
        guard let jsonData = config.data(using: .utf8),
              let configDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let apiDict = configDict["api"] as? [String: Any],
              let gReport = apiDict["greport"] as? String else {
            return nil
        }
        return gReport
    }
    
    /// 从配置中获取connreport地址
    /// - Parameter config: 配置JSON字符串
    /// - Returns: connreport地址字符串
    private func extractConnReport(from config: String) -> String? {
        guard let jsonData = config.data(using: .utf8),
              let configDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let apiDict = configDict["api"] as? [String: Any],
              let connReport = apiDict["connreport"] as? String else {
            return nil
        }
        return connReport
    }
}
