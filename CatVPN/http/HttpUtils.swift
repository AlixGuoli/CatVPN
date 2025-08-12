//
//  HttpUtils.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/31.
//
import Foundation
import Alamofire

class HttpUtils {
    
    static let shared = HttpUtils()
    
    private init() {}
    
    // MARK: - 基本参数
    
    lazy var baseParameters: [String: Any] = {
        return [
            "uid": CatKey.getUserUUID(),
            "country": CatKey.getCountryCode(),
            /// 测试服
            //"country": "ru",
            "language": CatKey.getLanguageCode(),
            "pk": CatKey.getBundleID(),
            "version": CatKey.getAppVersion()
        ]
    }()
    
    // MARK: - 接口请求方法
    /// 获取基本配置
    func fetchBaseConf() async {
        logDebug("Start request fetctBaseConf")
        let response = await performRequest(url: "/getconf", param: baseParameters)
        
        if let baseConf = response, !baseConf.isEmpty {
            logDebug("Successful fetctBaseConf result: \(baseConf)")
            BaseCFHelper.shared.saveBaseCF(baseConf)
            
            if let newGitVersion = BaseCFHelper.shared.getGitVersion() {
                let nowGitVersion = UserDefaults.standard.integer(forKey: CatKey.CAT_GIT_VERSION)
                logDebug("FetctBaseConf Loacl git version: \(nowGitVersion), Request new git version: \(newGitVersion)")
                if newGitVersion > nowGitVersion {
                    // 更新Git
                    logDebug("Loacl git version is old, update Git")
                    let updateSuccess = await updateConfigurationFromGitSources()
                    
                    // 如果Git更新成功，更新UserDefaults中的版本号
                    if updateSuccess {
                        UserDefaults.standard.set(newGitVersion, forKey: CatKey.CAT_GIT_VERSION)
                        UserDefaults.standard.synchronize()
                        logDebug("Git update successful, updated CAT_GIT_VERSION to: \(newGitVersion)")
                    } else {
                        logDebug("Git update failed, CAT_GIT_VERSION not updated")
                    }
                }
                
                let adIsOff = BaseCFHelper.shared.getAdsOff()
                let adType = BaseCFHelper.shared.getAdsType()
                let tgLink = BaseCFHelper.shared.getDynamicTgLink()
                let hotCode = BaseCFHelper.shared.getHotcode()
                
                logDebug("FetctBaseConf result ** ⬇️")
                logDebug("adIsOff: \(String(describing: adIsOff))")
                logDebug("adType: \(String(describing: adType))")
                logDebug("tgLink: \(String(describing: tgLink))")
                logDebug("hotCode: \(String(describing: hotCode))")
                
                // 保存广告开关设置
                AdCFHelper.shared.saveAdsOff(adIsOff)
                AdCFHelper.shared.saveAdsType(adType)
                
                //YaAdController.instance.setAdsEnabled(adIsOff, admobTypeString: adType)
            }
        }
    }
    
    /// 获取广告配置
    func fetchAds() async {
        logDebug("Start request fetchAds")
        
        let response = await performRequest(url: "/getAds", param: baseParameters)
        
        if let result = response, !result.isEmpty {
            logDebug("Successful fetchAds result: \(result)")
            
            // 解析配置
            if let config = AdCFHelper.shared.extractAdConfig(from: result),
               let adMixed = AdCFHelper.shared.extractAdMixed(from: config) {
                
                // 提取并保存 Yandex Banner 配置
                if let bannerConfig = AdCFHelper.shared.extractYandexBannerConfig(from: adMixed) {
                    AdCFHelper.shared.saveYandexBannerKey(bannerConfig.key)
                    AdCFHelper.shared.savePenetrateSettings(penetrate: bannerConfig.penetrate, clickDelay: bannerConfig.clickDelay)
                }
                
                // 提取并保存 Yandex Int 配置
                if let intKey = AdCFHelper.shared.extractYandexIntConfig(from: adMixed) {
                    AdCFHelper.shared.saveYandexIntKey(intKey)
                }
                
                // 提取并保存 AdMob Int 配置
                if let admobKey = AdCFHelper.shared.extractAdmobIntConfig(from: adMixed) {
                    AdCFHelper.shared.saveAdmobIntKey(admobKey)
                }
                
                // 保存配置时间
                AdCFHelper.shared.saveAdConfigDate()
                
                logDebug("Ads Config save success")
                
            } else {
                logDebug("!!! Ads Config save failed")
            }
            
        } else {
            logDebug("!!! fetchAds request failed")
        }
    }
    
    /// 获取国家列表
    func fetchCountry() async -> String? {
        logDebug("Start request fetchCountry")
        
        let response = await performRequest(url: "/getGroupList", param: baseParameters)
        
        if let result = response, !result.isEmpty {
            logDebug("Successful fetchCountry result: \(result)")
            return result
        } else {
            logDebug("!!! fetchCountry request failed")
            return nil
        }
    }
    
    /// 获取连接配置
    func fetchServiceCF() async -> String? {
        logDebug("Start request fetchServiceCF")
        var currentServerID = ServerCFHelper.shared.currentServerID
        logDebug("Current Server ID: \(currentServerID)")
        logDebug("Use default server: -1")
        currentServerID = -1

        let newPram: [String: Any] = ["group": currentServerID, "vip": 0]
        
        // 合并基本参数和新参数
        var allParams = baseParameters
        allParams.merge(newPram) { (_, new) in new }
        
        let response = await performRequest(url: "/getService", param: allParams)
        
        if let result = response, !result.isEmpty {
            logDebug("Successful fetchServiceCF result: \(result)")
            return result
        } else {
            logDebug("!!! fetchServiceCF request failed")
            return nil
        }
    }
    
    // MARK: - 请求相关
    
    /// 主请求方法
    /// 1. 获取UserDefaults配置，没有则读取本地配置并保存到UserDefaults
    /// 2. 使用UserDefaults配置尝试请求
    /// 3. 请求失败时，使用UserDefaults配置中的Git源更新配置
    /// 4. 使用更新后的配置重试
    /// - Parameters:
    /// - url: 接口（如 "/getconf"）
    /// - param: 请求参数
    /// - Returns: 响应字符串，失败返回nil
    func performRequest(url: String, param: [String: Any]) async -> String? {
        // 1. 获取配置(优先获取UserDefaults，没有就获取本地)
        logDebug("Get UserDefaults host config")
        let config = HostCFHelper.shared.getCurOrLoaclHostCF()
        
        // 检查是否有配置，没有就直接结束
        guard let config = config else {
            logDebug("!!! No host config available, request failed")
            return nil
        }
        
        // 2. 检查并保存配置（如果需要）
        HostCFHelper.shared.checkAndSaveConfigIfNeeded(config)
        
        // 3. 使用配置尝试请求
        logDebug("Request with host config")
        if let response = await performRequestWithConfig(hostConfig: config, url: url, param: param) {
            return response
        }
        
        // 4. 请求失败时，更新Git配置
        logDebug("!!! Request failed, update Git")
        let gitUpdateSuccess = await updateConfigurationFromGitSources()
        
        // 如果Git更新失败，直接结束
        if !gitUpdateSuccess {
            logDebug("!!! Git update failed, request terminated")
            return nil
        }
        
        // 5. 使用更新后的配置重试
        logDebug("Try again request with updated host config")
        return await performRequestWithConfig(hostConfig: HostCFHelper.shared.getCurOrLoaclHostCF(), url: url, param: param)
    }
    
    /// 使用指定配置发起请求
    /// - Parameters:
    ///   - hostConfig: 域名配置字符串
    ///   - url: 请求路径
    ///   - param: 请求参数
    /// - Returns: 响应字符串
    private func performRequestWithConfig(hostConfig: String?, url: String, param: [String: Any]) async -> String? {
        guard let hostList = HostCFHelper.shared.getHostList() else {
            logDebug("!!! Cannot get host list")
            return nil
        }
        
        /// 测试服
        logDebug("*** Now is Debug ***")
        let texthostList = ["https://test.nifymon.com"]
        for host in texthostList {
            
        //for host in hostList {
            logDebug("Host ** \(host)")
            logDebug("Url  ** \(url)")
            let fullUrl = fixFullUrl(baseUrl: "\(host)\(url)", parameters: param)
            let response = await executeHttpRequest(url: fullUrl)
            if response != nil && responseIsRight(response: response!, url: fullUrl) {
                return response
            }
        }
        return nil
    }
    
    /// 执行HTTP请求
    /// - Parameters:
    ///   - url: 完整请求URL
    /// - Returns: 响应字符串
    private func executeHttpRequest(url: String) async -> String? {
        return await withCheckedContinuation { continuation in
            logDebug("### Finally request url \(url)")
            
            // 构建 URLRequest 并设置超时时间
            guard let urlObj = URL(string: url) else {
                logDebug("!!! Invalid URL: \(url)")
                continuation.resume(returning: nil)
                return
            }
            var request = URLRequest(url: urlObj)
            request.timeoutInterval = 5.0  // 5秒超时

            var isCompleted = false
            
            // 启动倒计时任务
            DispatchQueue.global().async {
                for i in (1...5).reversed() {
                    if isCompleted { break }
                    logDebug("### Request timeout countdown: \(i) seconds")
                    Thread.sleep(forTimeInterval: 1.0)
                }
                if !isCompleted {
                    logDebug("!!! Request timeout after 5 seconds")
                }
            }

            AF.request(request)
                .responseData { response in
                    isCompleted = true
                    switch response.result {
                    case .success(let resultData):
                        if let statusCode = response.response?.statusCode,
                           statusCode >= 200 && statusCode < 300 {
                            if let result = String(data: resultData, encoding: .utf8) {
                                logDebug("### Finally request successful result \(result)")
                                continuation.resume(returning: result)
                            } else {
                                logDebug("!!! Request failed, cannot parse response data")
                                continuation.resume(returning: nil)
                            }
                        } else {
                            logDebug("!!! Request failed, status code: \(response.response?.statusCode ?? 0)")
                            continuation.resume(returning: nil)
                        }
                    case .failure(let error):
                        logDebug("!!! Finally request error \(error)")
                        continuation.resume(returning: nil)
                    }
                }
        }
    }
    
    // MARK: - 更新Git相关
    
    /// 从Git源更新配置
    /// 先用UserDefaults配置中的Git源，失败再用本地配置中的Git源
    private func updateConfigurationFromGitSources() async -> Bool {
        // 1. 尝试UserDefaults配置中的Git源
        logDebug("Update Git from UserDefaults host config")
        if let gitSources = HostCFHelper.shared.getGitSources() {
            for gitUrl in gitSources {
                if await updateConfigurationFromGit(gitUrl: gitUrl) {
                    logDebug("Git update successful from UserDefaults")
                    return true
                }
            }
        }
        
        // 2. UserDefaults配置Git源失败，尝试本地配置的Git源
        logDebug("Update Git from local host config")
        if let gitSources = HostCFHelper.shared.getLocalGitSources() {
            for gitUrl in gitSources {
                if await updateConfigurationFromGit(gitUrl: gitUrl) {
                    logDebug("Git update successful from local config")
                    return true
                }
            }
        }
        
        logDebug("!!! All Git sources update failed")
        return false
    }
    
    /// 从单个Git源更新配置
    /// - Parameter gitUrl: Git源URL
    /// - Returns: 是否更新成功
    private func updateConfigurationFromGit(gitUrl: String) async -> Bool {
        let encryptedJson = await executeHttpRequest(url: gitUrl)
        if encryptedJson == nil || encryptedJson!.isEmpty {
            logDebug("!!! Git update failed")
            return false
        }
        
        logDebug("Git request successful")
        logDebug("Git request encrypted result \(encryptedJson!)")
        
        // 解密Git返回的配置
        guard let decryptedJson = FileUtils.decodeSafetyData(encryptedJson!) else {
            logDebug("!!! Git response decryption failed")
            return false
        }
        
        // 验证JSON格式并保存
        if isValidJson(jsonString: decryptedJson) {
            HostCFHelper.shared.saveCurrentHostConf(decryptedJson)
            return true
        }
        
        logDebug("!!! Git response is not valid JSON")
        return false
    }
    
    // MARK: - 验证构建url相关
    
    /// 构建带参数的请求URL
    /// - Parameters:
    ///   - baseUrl: 基础URL
    ///   - parameters: 请求参数
    /// - Returns: 完整的请求URL
    private func fixFullUrl(baseUrl: String, parameters: [String: Any]) -> String {
        guard !parameters.isEmpty else {
            logDebug("Use base URL: \(baseUrl)")
            return baseUrl
        }
        
        let queryString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        let fullUrl = "\(baseUrl)?\(queryString)"
        
        logDebug("Full URL: \(fullUrl)")
        return fullUrl
    }
    
    /// 验证响应是否有效
    /// - Parameters:
    ///   - response: 响应字符串
    ///   - url: 请求路径
    /// - Returns: 是否有效
    private func responseIsRight(response: String, url: String) -> Bool {
        // 检查是否是getService接口，如果是则先解密再验证
        if url.contains("/getService") {
            logDebug("### getService interface detected, decrypting response")
            guard let decryptedResponse = FileUtils.decodeSafetyData(response) else {
                logDebug("!!! getService response decryption failed")
                return false
            }
            return isValidJson(jsonString: decryptedResponse)
        } else {
            // 其他接口直接验证JSON
            return isValidJson(jsonString: response)
        }
    }
    
    /// 检查JSON字符串是否有效
    /// - Parameter jsonString: JSON字符串
    /// - Returns: 是否有效
    private func isValidJson(jsonString: String) -> Bool {
        if jsonString.isEmpty || jsonString == "{}" {
            logDebug("!!! Result json is null")
            return false
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: jsonString.data(using: .utf8) ?? Data())
            logDebug("Result json is right")
            return true
        } catch {
            logDebug("!!! Result cannot be JSONObject")
            return false
        }
    }
    
}
