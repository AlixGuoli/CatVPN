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

    // MARK: - Embedded cipher

    /// Active seed (test). Swap `a`/`b`/`c` from `ProductionHostCipher` for release.
    private enum EmbeddedHostCipher {
        static let a = "1Bl6iTEEJIggAmCsE4HgvtnXrqfhyOUP4vL5nIlTAdWk2E44zK73gY3O/v7e74JcQuEPeop8ZTS485Zny87d6W0bdNpy2oP6UxyEobMoLm0SI4VpBz5ab8QPvRTF+GvLh1Yn5egjhZv8WaaVA9ttDdut3MryiPiUzVqdi2YCuhW5vIvq36sqNdXpoAIhKhUV7e2zX26iQwyqwcXMrqiJE2yt36LZ2gD0FajWr9vx/cvxNe1cvFEBV9dF3w7Xpfv1f0ODHRXQ5BGGRF/g7QLBCnvhE9MiJwCiY/wEi0Aip/1rM2O7Oqex5Ueed+FDBkaOWQikpuj1TMCa/Ksg"
        static let b = "73a4641d32a21cba0b5fe46d"
        static let c = "a6f2759a1f4cb957f9a90ce1e2871e4e"
        static var line: String { [a, b, c].joined(separator: ",") }
    }

    /// Production seed (love.silkbrightpetal.baby). Not active until swapped in above.
    private enum ProductionHostCipher {
        static let a = "f+a5lGy2I+cI2Npr7gVzNXEih7vwoFkrX3YA+Mc/GgfdR64UVQl4nT8ExnUxp406MotFzh5bMB/sMLmwRcN1cBYW4SoxEQyjvjpo5tlSYymXJblkg+tqtumk6gS8eSKaB42Bph1OYe/uP+KqfQwWC2Sbo+nvy8T3UFNz+zi5ZEHjLF3y5LTjQA6CKgslkcMnJajUz+4ZINRViP00nPxckl3nIRqUdMM1U859Fo2f3Addw1lHq3XJnzmt02yTSF6N4P+Z+bFxC13U9Roc+Y6fGPN8Bocn3+Z6XXVHH1iMt1y8L4UyrxdzqQDzfIxfKuZN+N9zPklzVyiSpwwoSjL/a+u2htDEBQ=="
        static let b = "e80d8abb1b2fc722899729ea"
        static let c = "7b2abdc5e14274b2938e6bd635e80490"
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
            gitURLs: (api["git"] as? [String] ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
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
