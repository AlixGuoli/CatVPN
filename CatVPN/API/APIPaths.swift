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
    static let systemSettings = "/fetch/system/settings"
    static let advertisementList = "/fetch/advertisement/list"
    static let groupList = "/getCategory"
    static let nodeConfig = "/fetch/service/info"

    static func kind(for path: String) -> APIPayloadKind {
        if path == nodeConfig { return .encryptedJSON }
        return .json
    }
}
