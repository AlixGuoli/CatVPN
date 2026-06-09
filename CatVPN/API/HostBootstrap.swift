//
//  HostBootstrap.swift
//  CatVPN
//
//  Domain seed (embedded ciphertext) + UserDefaults cache + parsed host/git/report URLs.
//  REPLACE segments in EmbeddedHostCipher when backend sends a new bootstrap blob.
//

import Foundation

struct HostConfig: Equatable {
    let hosts: [String]
    let gitURLs: [String]
    let gReport: String?
    let connReport: String?
    let json: String
}

enum HostBootstrap {

    // MARK: - Embedded cipher (from legacy hostConf.local)

    private enum EmbeddedHostCipher {
        static let a = "R4f4s82GUEJb3mdR2S2iMXAkasdzeGlTUYwfJy3DOLhx9+otJ1BBQJNpAdq2Zj4H91SUwypkGG3g/mZP3ASOqr4dYHuDu2rEWjgUkZjg2/KlHs27kvLkjT739JCUZ4SxlWhnG7vWN9wJDqadqzl9m8vURWU4AmrcMNSdVtZVTJD7dcRrfz5J4toGy+uW+P4Zvi4UmuhnSz9KtjTctmoooe5/Xrps7ScyiPgjOhh3HP/Mu/yRP82e1scy+BJIION6rZEouRjHQFXlbzbfggw5RCIoQLbqIAxNmfsAMNMugIR0OjQ5cGq+b7+Sifo9y1TnnnHT2UJhe4rxsLVf/JPUGg=="
        static let b = "d262f9fbd9add18d50993222"
        static let c = "7d6c2d23591175936293a84e040e547f"
        static var line: String { [a, b, c].joined(separator: ",") }
    }

    // MARK: - Resolve config JSON

    static func activeJSON() -> String? {
        if let ud = UserDefaults.standard.string(forKey: CatKey.CAT_NOW_HOST_CONF), !ud.isEmpty {
            return ud
        }
        return embeddedJSON()
    }

    static func activeConfig() -> HostConfig? {
        guard let json = activeJSON() else { return nil }
        return parse(json: json)
    }

    static func embeddedJSON() -> String? {
        #if DEBUG
        if let path = Bundle.main.path(forResource: "hostConf", ofType: "local"),
           let text = try? String(contentsOfFile: path, encoding: .utf8),
           let line = text.split(separator: "\n").map({ String($0).trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }) {
            return APICrypto.decryptPayload(line)
        }
        #endif
        return APICrypto.decryptPayload(EmbeddedHostCipher.line)
    }

    static func embeddedConfig() -> HostConfig? {
        guard let json = embeddedJSON() else { return nil }
        return parse(json: json)
    }

    static func saveJSON(_ json: String) {
        UserDefaults.standard.set(json, forKey: CatKey.CAT_NOW_HOST_CONF)
        UserDefaults.standard.set(Date(), forKey: CatKey.CAT_NOW_HOST_CONF_SAVE_DATE)
        UserDefaults.standard.synchronize()
        if let count = parse(json: json)?.hosts.count {
            goLog("saved \(count) hosts to UD")
        }
        goLog("Host config saved to UserDefaults")
        goLog(json)
    }

    static func persistEmbeddedSeedIfNeeded() {
        guard UserDefaults.standard.string(forKey: CatKey.CAT_NOW_HOST_CONF) == nil,
              let json = embeddedJSON() else { return }
        goLog("UserDefaults has no host config, save local config to UserDefaults")
        saveJSON(json)
    }

    // MARK: - Parse

    static func parse(json: String) -> HostConfig? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let api = root["api"] as? [String: Any] else { return nil }
        let hosts = api["host"] as? [String] ?? []
        guard !hosts.isEmpty else { return nil }
        return HostConfig(
            hosts: hosts,
            gitURLs: api["git"] as? [String] ?? [],
            gReport: api["greport"] as? String,
            connReport: api["connreport"] as? String,
            json: json
        )
    }

    static func parse(json optional: String?) -> HostConfig? {
        guard let optional else { return nil }
        return parse(json: optional)
    }
}
