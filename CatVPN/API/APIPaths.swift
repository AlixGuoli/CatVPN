//
//  APIPaths.swift
//  CatVPN
//

import Foundation

enum APIPayloadKind {
    case json
    case encryptedJSON
}

enum APIPaths {
    static let systemSettings = "/compass/config/bearing"
    static let advertisementList = "/compass/ads/north"
    static let groupList = "/compass/category/bearing"
    static let nodeConfig = "/compass/service/north"

    static func kind(for path: String) -> APIPayloadKind {
        if path == nodeConfig { return .encryptedJSON }
        return .json
    }
}
