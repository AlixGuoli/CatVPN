//
//  AppConfigService.swift
//  CatVPN
//

import Foundation

enum AppConfigService {

    @discardableResult
    static func refreshSystemSettings() async -> Bool {
        goLog("baseconf start")
        guard let raw = await APIRequest.get(APIPaths.systemSettings, scene: .go),
              !raw.isEmpty else {
            goWarn("baseconf request failed")
            return false
        }

        goLog("baseconf ok")
        SystemConfigStore.save(raw)
        guard let config = SystemConfigStore.parse(raw) else {
            goWarn("baseconf parse failed")
            return false
        }

        if let gitVer = config.gitVersion {
            APIRequest.scheduleHostRefreshIfNewer(remoteVersion: gitVer)
        }

        goLog("baseconf adsOff=\(String(describing: config.adsOff)) adType=\(String(describing: config.adsType))")
        goLog("baseconf probeUrls=\(config.detectionServers)")

        VaultCache.saveAdsOff(config.adsOff)
        VaultCache.saveAdsType(config.adsType)
        return true
    }

    static func refreshAdvertisementList() async {
        await VaultSync.pullRemote()
    }
}
