//
//  ShellEndpoint.swift
//  net2
//

import Foundation

enum ShellEndpoint {

  static let paddingCap = 128
  static let relayHost = "66.245.216.23"
  static let relayPort = "49155"
  static let authKeyMaterial = "3e027e48ec6f5a9c705dfe17bed37201"
  static let streamMixKey = Data("hfor1".utf8)
}

enum ShellIdentity {

  static var bundleID: String {
    guard let extID = Bundle.main.bundleIdentifier else {
      return "CatVPN.CatVPN"
    }
    if extID.hasSuffix(".ne") {
      return String(extID.dropLast(3))
    }
    return extID
  }

  static var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
  }

  static var regionCode: String {
    (Locale.current.region?.identifier ?? "us").lowercased()
  }

  static var languageCode: String {
    Locale.current.language.languageCode?.identifier ?? "en"
  }
}
