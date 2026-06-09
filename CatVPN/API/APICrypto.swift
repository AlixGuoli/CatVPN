//
//  APICrypto.swift
//  CatVPN
//

import Foundation
import CryptoKit

enum APICrypto {

    private static var keyMaterial: String {
        let a = "f92mUj0K1uBnMlXGFQKrYP07Emgc4yFm"
        let b = "WYS8WRgy4IY="
        return a + b
    }

    static func decryptPayload(_ encoded: String, logResult: Bool = false, scene: CVLogScene = .general) -> String? {
        let parts = encoded.split(separator: ",")
        guard parts.count == 3 else {
            cvWarn(scene, "decrypt bad format")
            return nil
        }

        let cipherB64 = String(parts[0].trimmingCharacters(in: .whitespacesAndNewlines))
        let ivHex = String(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        guard let keyData = keyMaterial.data(using: .utf8)?.prefix(32),
              let iv = Data(hex: ivHex),
              let cipher = Data(base64Encoded: cipherB64) else {
            cvWarn(scene, "decrypt bad payload")
            return nil
        }

        do {
            let key = SymmetricKey(data: keyData)
            let box = try AES.GCM.SealedBox(combined: iv + cipher)
            let plain = try AES.GCM.open(box, using: key)
            let text = String(data: plain, encoding: .utf8)
            if logResult, let text {
                cvLog(scene, "decrypt ok text=\(text)")
            }
            return text
        } catch {
            cvWarn(scene, "decrypt error=\(error)")
            return nil
        }
    }

    static func plainText(for raw: String, kind: APIPayloadKind, logDecrypted: Bool = false, scene: CVLogScene = .general) -> String? {
        switch kind {
        case .json: return raw
        case .encryptedJSON: return decryptPayload(raw, logResult: logDecrypted, scene: scene)
        }
    }

    static func isValidJSON(_ text: String, scene: CVLogScene = .general) -> Bool {
        guard !text.isEmpty, text != "{}" else {
            cvWarn(scene, "json empty")
            return false
        }
        guard let data = text.data(using: .utf8) else {
            cvWarn(scene, "json not utf8")
            return false
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            cvLog(scene, "json ok")
            return true
        } catch {
            cvWarn(scene, "json parse error")
            return false
        }
    }

    static func isValidResponse(_ raw: String, path: String, scene: CVLogScene = .general) -> Bool {
        guard let plain = plainText(for: raw, kind: APIPaths.kind(for: path), logDecrypted: false, scene: scene) else {
            cvWarn(scene, "response plain nil path=\(path)")
            return false
        }
        return isValidJSON(plain, scene: scene)
    }
}

private extension Data {
    init?(hex: String) {
        let n = hex.count / 2
        var out = Data(capacity: n)
        for i in 0..<n {
            let s = hex.index(hex.startIndex, offsetBy: i * 2)
            let e = hex.index(s, offsetBy: 2)
            guard var b = UInt8(hex[s..<e], radix: 16) else { return nil }
            out.append(&b, count: 1)
        }
        self = out
    }
}
