//
//  NetWorkexUtils.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/2.
//
import Foundation
import os

// MARK: - 全局日志方法
func logOS(_ message: String) {
    os_log("[🐱 CatCat **] %{public}@", log: OSLog.default, type: .error, message)
}

class NetHelper {
    
    static func getDirConfig() -> String{
        logOS("Getting directory configuration...")
        
        let userDefaults = UserDefaults(suiteName: ServiceDefaults.GroupId)
        let configDancyData = userDefaults?.string(forKey: ServiceDefaults.GroupConfig) ?? ""
        logOS("Config data length: \(configDancyData.count) chars")
        
        let filePath = NetHelper.getFile(withName: "config", data: (configDancyData.data(using: .utf8)))
        logOS("Config file path: \(filePath.path)")
        
        let dirConfigJson = """
            {
                "datDir": "",
                "configPath": "\(filePath.path)",
                "maxMemory": \(31457280)
            }
            """
        
        logOS("Directory config generated successfully")
        return dirConfigJson
    }
    
    static func getSocksFilePath() -> String{
        logOS("Getting SOCKS config file path...")
        
        let decodedData = decodedConfig?.data(using: .utf8)
        logOS("Decoded config data length: \(decodedData?.count ?? 0) bytes")
        
        let url = NetHelper.getFile(withName: "TunConfig", data: decodedData)
        logOS("SOCKS config file path: \(url.path())")
        
        return url.path()
    }
    
    static var decodedConfig: String? {
        logOS("Decoding Base32 configuration...")
        logOS("Original Base32 length: \(config.count) chars")
        
        let decoded = decodeBase32(config)
        logOS("=== Base32 decoded content ===")
        logOS(decoded ?? "Decoding failed")
        logOS("=== Decoded content end ===")
        
        if let decoded = decoded {
            logOS("Decoding successful, content length: \(decoded.count) chars")
        } else {
            logOS("Decoding failed")
        }
        
        return decoded
    }
    
    static let config = """
OR2W43TFNQ5AUIBANV2HKORAHEYDAMAKONXWG23TGU5AUIBAOBXXE5B2EA4DAOBQBIQCAYLEMRZGK43THIQDUORRBIQCA5LEOA5CAJ3VMRYCOCTNNFZWGOQKEAQHIYLTNMWXG5DBMNVS243JPJSTUIBSGA2DQMAKEAQGG33ONZSWG5BNORUW2ZLPOV2DUIBVGAYDACRAEBZGKYLEFV3XE2LUMUWXI2LNMVXXK5B2EA3DAMBQGAFCAIDMN5TS2ZTJNRSTUIDTORSGK4TSBIQCA3DPM4WWYZLWMVWDUIDFOJZG64QKEAQGY2LNNF2C23TPMZUWYZJ2EA3DKNJTGU======
"""
    
    static func decodeBase32(_ input: String) -> String? {
        logOS("开始Base32解码算法...")
        
        let base32Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var bits = 0
        var value = 0
        var result = Data()
        
        logOS("Base32字符集: \(base32Chars)")
        logOS("输入字符串长度: \(input.count)")
        
        for char in input.uppercased() {
            if char == "=" {
                logOS("遇到填充字符'='，停止解码")
                break
            }
            
            guard let charValue = base32Chars.firstIndex(of: char)?.encodedOffset else {
                logOS("无效字符: \(char)")
                return nil
            }
            
            value = (value << 5) | charValue
            bits += 5
            
            while bits >= 8 {
                bits -= 8
                result.append(UInt8((value >> bits) & 0xFF))
            }
        }
        
        let decodedString = String(data: result, encoding: .utf8)
        logOS("解码完成，结果长度: \(result.count) bytes")
        
        return decodedString
    }
    
    static func getDirURL() -> URL {
        logOS("获取文档目录URL...")
        
        let fileManager = FileManager.default
        let directoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        logOS("文档目录路径: \(directoryURL.path)")
        return directoryURL
    }
    
    static  func getFile(withName name: String, data: Data?) -> URL {
        logOS("开始写入文件: \(name)")
        
        let directoryURL = getDirURL()
        let fileURL = directoryURL.appendingPathComponent(name)
        
        logOS("文件完整路径: \(fileURL.path)")
        logOS("数据大小: \(data?.count ?? 0) bytes")
        
        do {
            try data?.write(to: fileURL)
            logOS("文件写入成功: \(name)")
        } catch {
            logOS("文件写入失败: \(error)")
            debugPrint("getFile Error : \(error)")
        }
        
        return fileURL
    }
}
