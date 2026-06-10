//
//  ShellCipher.swift
//  net2
//

import Foundation
import CommonCrypto

enum ShellCipher {

  static func wrapFrame(_ payload: Data, key: Data, paddingCap: Int) -> Data {
    let maxRandomLength = UInt8(paddingCap)
    let actualRandomLength = UInt8.random(in: 0...maxRandomLength)
    let paddingData = Data((0..<Int(actualRandomLength)).map { _ in UInt8.random(in: 0...255) })
    let framed = paddingData + payload + Data([actualRandomLength])
    let mixed = Data(framed.enumerated().map { index, byte in
      byte ^ key[index % key.count]
    })
    return UInt16(mixed.count).bigEndianData + mixed
  }

  static func unwrapFrame(_ payload: Data, key: Data) -> Data {
    let mixed = Data(payload.enumerated().map { index, byte in
      byte ^ key[index % key.count]
    })
    guard !mixed.isEmpty else { return mixed }
    let paddingLength = Int(mixed.last!)
    guard paddingLength < mixed.count else { return mixed }
    return mixed.subdata(in: paddingLength..<(mixed.count - 1))
  }

  static func encryptAuthBlob(_ plain: Data, keyMaterial: Data) -> Data? {
    let plaintextBytes = [UInt8](plain)
    let keyBytes = [UInt8](keyMaterial)
    var ciphertext = [UInt8](repeating: 0, count: plaintextBytes.count + kCCBlockSizeAES128)
    var encryptedCount = 0
    let status = CCCrypt(
      CCOperation(kCCEncrypt),
      CCAlgorithm(kCCAlgorithmAES),
      CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
      keyBytes,
      keyMaterial.count,
      nil,
      plaintextBytes,
      plaintextBytes.count,
      &ciphertext,
      ciphertext.count,
      &encryptedCount
    )
    guard status == kCCSuccess else { return nil }
    return Data(bytes: ciphertext, count: encryptedCount)
  }
}

private extension UInt16 {

  var bigEndianData: Data {
    Data([UInt8(self >> 8), UInt8(self & 0xFF)])
  }
}
