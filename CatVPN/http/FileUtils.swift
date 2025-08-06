//
//  FileUtils.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/31.
//
import Foundation
import CryptoKit

class FileUtils {
    
    static let aesKey = "f92mUj0K1uBnMlXGFQKrYP07Emgc4yFmWYS8WRgy4IY="
    
    // 从本地文件获取默认配置（默认配置永远保留）
    static func fetchLocalHostConf() -> String? {
        let localConf = readHostConfFile()
        if let decryptedJson = decodeSafetyData(localConf ?? "") {
            //logDebug("Local Host config \(decryptedJson)")
            return decryptedJson
        }
        return nil
    }
    
    // 从本地文件获取默认连接服务配置（默认配置永远保留）
    static func fetchLocalServiceConf() -> String? {
        let localConf = readServiceConfFile()
        if let decryptedJson = decodeSafetyData(localConf ?? "") {
            logDebug("Local Service config \(decryptedJson)")
            return decryptedJson
        }
        return nil
    }
    
    // 读取本地hostConf.local文件内容
    static func readHostConfFile() -> String? {
        guard let bundlePath = Bundle.main.path(forResource: "hostConf", ofType: "local") else {
            logDebug("No find the file: hostConf.local")
            return nil
        }
        
        do {
            let fileContent = try String(contentsOfFile: bundlePath, encoding: .utf8)
            logDebug("Read successful hostConf.local")
            logDebug("File content: \(fileContent)")
            return fileContent
        } catch {
            logDebug("Read hostConf.local error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 读取本地serviceConf.local文件内容
    static func readServiceConfFile() -> String? {
        guard let bundlePath = Bundle.main.path(forResource: "serviceConf", ofType: "local") else {
            logDebug("No find the file: serviceConf.local")
            return nil
        }
        
        do {
            let fileContent = try String(contentsOfFile: bundlePath, encoding: .utf8)
            logDebug("Read successful serviceConf.local")
            logDebug("File content: \(fileContent)")
            return fileContent
        } catch {
            logDebug("Read serviceConf.local error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 解密
    static func decodeSafetyData(_ encodedData: String) -> String? {
        do {
            // 1. 解析加密数据格式
            let payloadSegments = encodedData.split(separator: ",")
            guard payloadSegments.count == 3 else {
                logDebug("数据格式错误：需要3个部分，实际有\(payloadSegments.count)个")
                return nil
            }
            
            // 2. 提取数据组件
            let base64EncodedContent = String(payloadSegments[0].trimmingCharacters(in: .whitespacesAndNewlines))
            let hexVectorString = String(payloadSegments[1].trimmingCharacters(in: .whitespacesAndNewlines))
            
//            logDebug("Base64编码的加密数据: \(base64EncodedContent)")
//            logDebug("十六进制向量: \(hexVectorString)")
            
            // 3. 生成解密密钥（截取前32字节）
            let secretKeyData = aesKey.data(using: .utf8)?.subdata(in: 0..<min(32, aesKey.count))
            let decryptionKey = SymmetricKey(data: secretKeyData!)
            
            // 4. 数据格式转换
            guard let ivData = Data(fromHexString: hexVectorString),
                  let encryptedData = Data(base64Encoded: base64EncodedContent) else {
                logDebug("数据转换失败")
                return nil
            }
            
            // 5. 执行AES-GCM解密操作
            let sealedBox = try AES.GCM.SealedBox(combined: ivData + encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: decryptionKey)
            
            // 6. 转换为可读字符串
            guard let finalResult = String(data: decryptedData, encoding: .utf8) else {
                logDebug("Decrypt result to String failed")
                return nil
            }
            
            logDebug("Successful！Decrypted result ** ⬇️")
            logDebug(finalResult)
            return finalResult
            
        } catch {
            logDebug("Decrypt Failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    
}

//Data扩展
extension Data {
    init?(fromHexString hexString: String) {
        let byteCount = hexString.count / 2
        var resultData = Data(capacity: byteCount)
        
        for index in 0..<byteCount {
            let startPos = hexString.index(hexString.startIndex, offsetBy: index * 2)
            let endPos = hexString.index(startPos, offsetBy: 2)
            let hexBytes = hexString[startPos..<endPos]
            
            if var byteValue = UInt8(hexBytes, radix: 16) {
                resultData.append(&byteValue, count: 1)
            } else {
                return nil
            }
        }
        
        self = resultData
    }
}
