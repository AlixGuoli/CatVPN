import Foundation

struct SystemConfig {
    let gitVersion: Int?
    let detectionServers: [String]
    let adsOff: Bool?
    let adsType: String?
}

enum SystemConfigStore {
    static func save(_ raw: String) {
        UserDefaults.standard.set(raw, forKey: CatKey.CAT_BASE_CONF)
        UserDefaults.standard.set(Date(), forKey: CatKey.CAT_BASE_CONF_SAVE_DATE)
        UserDefaults.standard.synchronize()
        goLog("system config saved")
    }

    static func currentRaw() -> String? {
        guard let raw = UserDefaults.standard.string(forKey: CatKey.CAT_BASE_CONF),
              !raw.isEmpty else {
            goWarn("system config missing")
            return nil
        }
        return raw
    }

    static func current() -> SystemConfig? {
        guard let raw = currentRaw() else { return nil }
        return parse(raw)
    }

    static func parse(_ raw: String) -> SystemConfig? {
        guard let common = commonConfig(from: raw) else { return nil }
        let detectionConfig = common["detectionConfig"] as? [String: Any]
        return SystemConfig(
            gitVersion: common["git_version"] as? Int,
            detectionServers: detectionConfig?["detectionServers"] as? [String] ?? [],
            adsOff: common["adsOff"] as? Bool,
            adsType: common["adsType"] as? String
        )
    }

    static func detectionServers() -> [String] {
        current()?.detectionServers ?? []
    }

    private static func commonConfig(from raw: String) -> [String: Any]? {
        do {
            guard let data = raw.data(using: .utf8),
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let common = root["commonConf"] as? [String: Any] else {
                goWarn("system config parse failed")
                return nil
            }
            return common
        } catch {
            goWarn("system config parse error")
            return nil
        }
    }
}
