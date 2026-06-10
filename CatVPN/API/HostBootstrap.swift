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
    /// Active seed (production). Swap `a`/`b`/`c` from `TestHostCipher` for local git-refresh tests.
    private enum EmbeddedHostCipher {
        static let a = "f+a5lGy2I+cI2Npr7gVzNXEih7vwoFkrX3YA+Mc/GgfdR64UVQl4nT8ExnUxp406MotFzh5bMB/sMLmwRcN1cBYW4SoxEQyjvjpo5tlSYymXJblkg+tqtumk6gS8eSKaB42Bph1OYe/uP+KqfQwWC2Sbo+nvy8T3UFNz+zi5ZEHjLF3y5LTjQA6CKgslkcMnJajUz+4ZINRViP00nPxckl3nIRqUdMM1U859Fo2f3Addw1lHq3XJnzmt02yTSF6N4P+Z+bFxC13U9Roc+Y6fGPN8Bocn3+Z6XXVHH1iMt1y8L4UyrxdzqQDzfIxfKuZN+N9zPklzVyiSpwwoSjL/a+u2htDEBQ=="
        static let b = "e80d8abb1b2fc722899729ea"
        static let c = "7b2abdc5e14274b2938e6bd635e80490"
        static var line: String { [a, b, c].joined(separator: ",") }
    }

    /// Test seed (wrong blob for git-refresh validation). Not active.
    private enum TestHostCipher {
        static let a = "XFc/lvYN93zIZfG9Xkpl97syGPTJNjilIZSL8dgjwPq7Zj02N/FUwKiYfOYIhDj08k0uOlTjRDtwaiQ2DWA01oi92l26NOFRoU3+frVtpxZ2w/Iqsv2xixbjiNdIoShwb7+NiooKrNzXYwJ9MzadSfcrFAXIahMX2vE2lI90QcEfcTHtt4Bnd5b/tYaZo4/h/FIFR7Jial+/AFcc+n13/iwKw5dVEQYp/ZLyLRpMlYr16YRg8CoVkesLPTsyMHPSOudzF1bgkk6BUDbr2kE3UTonaDzcXeSkbK4Y0f/LeRtxZyqsC3gA9JEuBGRRvfvz"
        static let b = "92fab3e6d3816682d87e98b5"
        static let c = "aca4b7b57340e5bcb6d5a405a2e75edf"
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
