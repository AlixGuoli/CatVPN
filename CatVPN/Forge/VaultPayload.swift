//
//  VaultPayload.swift
//  CatVPN
//

import Foundation

enum VaultPayload {

    static func extractAdConfig(from configString: String) -> [String: Any]? {
        do {
            let jsonData = configString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            return json
        } catch {
            adLog("cfg parse error=\(error.localizedDescription)")
            return nil
        }
    }

    static func extractAdMixed(from config: [String: Any]) -> [[String: Any]]? {
        guard let adConfig = config["adConfig"] as? [String: Any],
              let adMixed = adConfig["adMixed"] as? [[String: Any]] else {
            return nil
        }
        return adMixed
    }

    static func extractYandexIntConfig(from adMixed: [[String: Any]]) -> String? {
        for ad in adMixed {
            if let name = ad["name"] as? String, name == "Yandex_Int_List" {
                return ad["key"] as? String
            }
        }
        return nil
    }

    static func extractYandexEMIntConfig(from adMixed: [[String: Any]]) -> String? {
        for ad in adMixed {
            if let name = ad["name"] as? String, name == "Yandex_EMInt_List" {
                return ad["key"] as? String
            }
        }
        return nil
    }
}
