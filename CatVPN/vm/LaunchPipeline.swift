//
//  LaunchPipeline.swift
//  CatVPN
//

import Foundation
import Alamofire

final class LaunchPipeline {

    private weak var owner: MainViewmodel?
    var netWorkManager = NetworkReachabilityManager()

    init(owner: MainViewmodel) {
        self.owner = owner
    }

    func checkNet(completion: @escaping (Bool) -> Void) {
        netWorkManager?.startListening { [weak self] status in
            guard let self else { return }

            switch status {
            case .notReachable:
                goWarn("network unreachable")
            case .unknown:
                goLog("network unknown")
            case .reachable(.ethernetOrWiFi):
                goLog("network wifi")
                self.requestBaseConf(completion: completion)
            case .reachable(.cellular):
                goLog("network cellular")
                self.requestBaseConf(completion: completion)
            }
        }
    }

    func requestBaseConf(completion: @escaping (Bool) -> Void) {
        Task {
            let success = await performInitialization()
            DispatchQueue.main.async {
                completion(success)
            }
            netWorkManager = nil
        }
    }

    func performInitialization() async -> Bool {
        goLog("init system settings")
        let baseOK = await AppConfigService.refreshSystemSettings()
        goLog("init system settings done ok=\(baseOK)")

        await MainActor.run {
            owner?.isBaseConfigReady = baseOK
            owner?.isSplashAdReady = false
        }

        guard baseOK else { return false }

        guard VaultRegistry.shared.isForgeEnabled() else {
            goLog("ads disabled, skip ad list and preload")
            return true
        }

        if AdBootstrap.isAdStackUnlocked {
            goLog("init ads: list + preload parallel")
            async let adListTask: Void = AppConfigService.refreshAdvertisementList()
            async let preloadTask: Bool = loadSplashInt()
            await adListTask
            let adLoaded = await preloadTask
            goLog("splash preload result=\(adLoaded)")
            await MainActor.run {
                owner?.isSplashAdReady = adLoaded
            }
        } else {
            goLog("init ads: fetch list")
            await AppConfigService.refreshAdvertisementList()
            goLog("ads preload wait att")
        }
        return true
    }

    func loadSplashInt() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var hasResumed = false

                ForgeHub.shared.warmInventory(onReady: {
                    if !hasResumed {
                        hasResumed = true
                        adLog("splash preload ok successfully")
                        continuation.resume(returning: true)
                    }
                }, onFailed: {
                    if !hasResumed {
                        hasResumed = true
                        adLog("splash preload fail")
                        continuation.resume(returning: false)
                    }
                })
            }
        }
    }

    func bootstrapAdsAfterATTUnlock() {
        guard AdBootstrap.isAdStackUnlocked else { return }
        Task {
            guard owner?.isBaseConfigReady == true else {
                goLog("bootstrap ads skip baseconf not ready")
                return
            }
            guard VaultRegistry.shared.isForgeEnabled() else {
                goLog("bootstrap ads skip gate closed")
                return
            }
            goLog("bootstrap ads preload after att")
            let adLoaded = await loadSplashInt()
            goLog("bootstrap ads preload result=\(adLoaded)")
            await MainActor.run {
                owner?.isSplashAdReady = adLoaded
            }
        }
    }

    func requestAdsInBackground() {
        Task { await AppConfigService.refreshAdvertisementList() }
    }

    func checkAndUpdateConfigsIfNeeded() {
        cvLog("check config TTL")

        let now = Date()

        // 检查 baseconf 配置更新时间（6小时）
        if let baseconfUpdateTime = UserDefaults.standard.object(forKey: CatKey.CAT_BASE_CONF_SAVE_DATE) as? Date {
            let baseconfTimeInterval = now.timeIntervalSince(baseconfUpdateTime)
            let baseconfHours = baseconfTimeInterval / 3600

            cvLog("baseconf age=\(String(format: "%.1f", baseconfHours))h")

            if baseconfHours >= 6.0 {
                goLog("baseconf expired, refresh")
                Task {
                    await AppConfigService.refreshSystemSettings()
                }
            }
        } else {
            goLog("baseconf missing, refresh")
            Task {
                await AppConfigService.refreshSystemSettings()
            }
        }

        // 检查 ads 配置更新时间（4小时）
        if let adsUpdateTime = VaultCache.getAdConfigSaveDate() {
            let adsTimeInterval = now.timeIntervalSince(adsUpdateTime)
            let adsHours = adsTimeInterval / 3600

            adLog("ad config age: \(adsHours) hours ago")

            if adsHours >= 4.0 {
                adLog("ad config expired (>=4h), updating...")
                requestAdsInBackground()
            }
        } else {
            adLog("ad config missing time found, updating...")
            requestAdsInBackground()
        }
    }
}
