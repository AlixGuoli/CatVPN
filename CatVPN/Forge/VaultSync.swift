//
//  VaultSync.swift
//  CatVPN
//

import Foundation

enum VaultSync {

    static func pullRemote() async {
        goLog("ad list start")
        guard let raw = await APIRequest.get(APIPaths.advertisementList, scene: .go),
              let root = VaultPayload.extractAdConfig(from: raw),
              let mixed = VaultPayload.extractAdMixed(from: root) else {
            goWarn("ad list failed")
            return
        }

        if let k = VaultPayload.extractYandexIntConfig(from: mixed) {
            VaultCache.saveYandexIntKey(k)
        }
        if let k = VaultPayload.extractYandexEMIntConfig(from: mixed) {
            VaultCache.saveYandexEMIntKey(k)
        }
        VaultCache.saveAdConfigDate()
        goLog("ad list saved")
    }
}
