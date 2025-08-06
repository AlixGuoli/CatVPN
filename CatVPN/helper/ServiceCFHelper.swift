import Foundation

/// 全局服务配置管理器
class ServiceCFHelper {
    
    static let shared = ServiceCFHelper()
    private init() {}
    
    /// 加密的服务配置
    var nowServiceCF: String? = nil
    var serverIp: String? = nil
    var connectid: String? = nil
    var isUseServer = true
    var stopByHome: Bool = false
    
    
    /// 获取 UserDefaults 域名配置
    func getCurrentServiceCF() -> String? {
        let currentConfig = UserDefaults.standard.string(forKey: CatKey.CAT_NOW_SERVICE_CONF)
        
        if let config = currentConfig, !config.isEmpty {
            logDebug("UserDefaults Service config ** ⬇️")
            logDebug(config)
            return config
        } else {
            logDebug("!!! UserDefaults Service config is null")
            return nil
        }
    }
}
