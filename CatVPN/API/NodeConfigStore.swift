import Foundation

enum NodeConfigStore {
    static func cachedEncryptedConfig() -> String? {
        guard let config = UserDefaults.standard.string(forKey: CatKey.CAT_NOW_SERVICE_CONF),
              !config.isEmpty else {
            linkLog("UD cache miss")
            return nil
        }
        linkLog("UD cache hit len=\(config.count)")
        return config
    }

    static func saveEncryptedConfig(_ config: String) {
        UserDefaults.standard.setValue(config, forKey: CatKey.CAT_NOW_SERVICE_CONF)
        UserDefaults.standard.synchronize()
        linkLog("cache config to UD")
    }
}
