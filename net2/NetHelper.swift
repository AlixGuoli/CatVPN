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

class NetworkConfigProcessor {
    
    // MARK: - 静态常量
    
    static let config = """
OR2W43TFNQ5AUIBANV2HKORAHEYDAMAKONXWG23TGU5AUIBAOBXXE5B2EA4DAOBQBIQCAYLEMRZGK43THIQDUORRBIQCA5LEOA5CAJ3VMRYCOCTNNFZWGOQKEAQHIYLTNMWXG5DBMNVS243JPJSTUIBSGA2DQMAKEAQGG33ONZSWG5BNORUW2ZLPOV2DUIBVGAYDACRAEBZGKYLEFV3XE2LUMUWXI2LNMVXXK5B2EA3DAMBQGAFCAIDMN5TS2ZTJNRSTUIDTORSGK4TSBIQCA3DPM4WWYZLWMVWDUIDFOJZG64QKEAQGY2LNNF2C23TPMZUWYZJ2EA3DKNJTGU======
"""
    
    // MARK: - 配置管理
    
    static func generateDirectoryConfiguration() -> String {
        let configData = fetchConfigFromDefaults()
        let configPath = writeConfigToFile(with: configData)
        return buildConfigJson(with: configPath)
    }
    
    static func generateSocksConfigurationPath() -> String {
        let socksData = convertConfigToData()
        let socksPath = writeSocksToFile(with: socksData)
        return socksPath.path()
    }
    
    // MARK: - 数据准备
    
    private static func fetchConfigFromDefaults() -> String {
        let userDefaults = UserDefaults(suiteName: ServiceDefaults.targetGroup)
        return userDefaults?.string(forKey: ServiceDefaults.targetConfig) ?? ""
    }
    
    private static func convertConfigToData() -> Data? {
        return decodedConfig?.data(using: .utf8)
    }
    
    // MARK: - 文件创建
    
    private static func writeConfigToFile(with configData: String) -> URL {
        return writeDataToFile(withName: "NetConfig", data: configData.data(using: .utf8))
    }
    
    private static func writeSocksToFile(with data: Data?) -> URL {
        return writeDataToFile(withName: "SocksConfig", data: data)
    }
    
    private static func buildConfigJson(with filePath: URL) -> String {
        return """
            {
                "datDir": "",
                "configPath": "\(filePath.path)",
                "maxMemory": \(31457280)
            }
            """
    }
    
    // MARK: - 配置解码
    
    static var decodedConfig: String? {
        return processBase32String(config)
    }
    
    // MARK: - Base32解码算法
    
    static func processBase32String(_ input: String) -> String? {
        let base32Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var bits = 0
        var value = 0
        var result = Data()
        
        for char in input.uppercased() {
            if char == "=" {
                break
            }
            
            guard let charValue = base32Chars.firstIndex(of: char)?.encodedOffset else {
                return nil
            }
            
            value = (value << 5) | charValue
            bits += 5
            
            while bits >= 8 {
                bits -= 8
                result.append(UInt8((value >> bits) & 0xFF))
            }
        }
        
        return String(data: result, encoding: .utf8)
    }
    
    // MARK: - 文件操作
    
    static func obtainDocumentDirectory() -> URL {
        let fileManager = FileManager.default
        let directoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directoryURL
    }
    
    static func writeDataToFile(withName name: String, data: Data?) -> URL {
        let directoryURL = obtainDocumentDirectory()
        let fileURL = directoryURL.appendingPathComponent(name)
        
        do {
            try data?.write(to: fileURL)
        } catch {
            logOS("writeDataToFile Error : \(error)")
        }
        
        return fileURL
    }
}
