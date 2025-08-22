//
//  ReportCat.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/13.
//

import Foundation

class ReportCat {
    
    static let shared = ReportCat()
    private init() {}
    
    // MARK: - 配置常量
    private static let TIMEOUT = 15
    private static let DEVICE = "iPhone"
    
    // MARK: - 事件类型
    static let E_START = "start_connect"
    static let E_FAIL = "connect_failed"
    static let E_SUCCESS = "connect_success"
    static let E_DISCONNECT = "disconnect"
    static let E_AD_START = "start_get_ad"
    static let E_AD_SUCCESS = "get_ad_success"
    static let E_AD_SHOW = "show_ad"
    
    // MARK: - 连接事件上报

    func reportConnect(moment: String, ip: String? = nil, sid: String? = nil) {
        let time = getTime()
        let code = "\(time)-\(sid ?? "")"
        
        let msg: String
        switch moment {
        case ReportCat.E_START:
            msg = "\(ReportCat.E_START),\(code),0.0.0.0"
        case ReportCat.E_FAIL:
            msg = "\(ReportCat.E_FAIL),\(code),\(ip ?? "0.0.0.0")"
        case ReportCat.E_SUCCESS:
            msg = "\(ReportCat.E_SUCCESS),0,\(code),\(ip ?? "0.0.0.0")"
        default:
            logDebug("ReportCat: Unknown connect moment: \(moment)")
            return
        }
        
        logDebug("ReportCat reportConnect msg: \(msg)")
        send(msg: msg)
    }
    
    // MARK: - 广告事件上报

    func reportAd(moment: String, key: String? = nil, adMoment: String? = nil) {
        let ip = getIP()
        
        let msg: String
        switch moment {
        case ReportCat.E_AD_START:
            msg = "\(ReportCat.E_AD_START),\(adMoment ?? ""),\(ip),ad"
        case ReportCat.E_AD_SUCCESS:
            msg = "\(ReportCat.E_AD_SUCCESS),\(adMoment ?? ""),\(ip),ad,\(key ?? "")"
        case ReportCat.E_AD_SHOW:
            msg = "\(ReportCat.E_AD_SHOW),\(adMoment ?? ""),\(ip),ad,\(key ?? "empty")"
        default:
            logDebug("ReportCat: Unknown ad moment: \(moment)")
            return
        }
        
        logDebug("ReportCat reportAd msg: \(msg)")
        send(msg: msg)
    }
    
    // MARK: - 状态上报
    
    /// 上报服务状态
    func reportStatus(success: Bool) {
        Task.detached {
            guard let endpoint = HostCFHelper.shared.getGReport() else {
                logDebug("ReportCat: No report endpoint available")
                return
            }
            
            let statusCode = success ? "0" : "1"
            logDebug("ReportCat: Reporting service status: \(statusCode)")
            
            guard let url = self.buildURL(endpoint: endpoint, message: statusCode, type: "status") else {
                logDebug("ReportCat: Invalid status URL")
                return
            }
            
            await self.request(urlString: url)
        }
    }
    
    // MARK: - 私有方法
    
    /// 发送日志
    private func send(msg: String) {
        Task.detached {
            guard let endpoints = HostCFHelper.shared.getConnReport(),
                  !endpoints.isEmpty else {
                logDebug("ReportCat: No log endpoints available")
                return
            }
            
            guard let url = self.buildURL(endpoint: endpoints, message: msg, type: "log") else {
                logDebug("ReportCat: Invalid log URL")
                return
            }
            
            await self.request(urlString: url)
        }
    }
    
    /// 构建URL
    private func buildURL(endpoint: String, message: String, type: String) -> String? {
        let baseURL = type == "status" ? endpoint + "/report_total" : endpoint
        guard var components = URLComponents(string: baseURL) else { return nil }
        
        components.queryItems = type == "status" ? 
            buildStatusParams(status: message) : 
            buildLogParams(message: message)
        
        return components.url?.absoluteString
    }
    
    /// 构建状态参数
    private func buildStatusParams(status: String) -> [URLQueryItem] {
        return [
            URLQueryItem(name: "name", value: "getService"),
            URLQueryItem(name: "cty", value: CatKey.getCountryCode()),
            URLQueryItem(name: "pk", value: CatKey.getBundleID()),
            URLQueryItem(name: "v", value: CatKey.getAppVersion()),
            URLQueryItem(name: "asn", value: "0"),
            URLQueryItem(name: "isf", value: status),
            URLQueryItem(name: "cnt", value: "1")
        ]
    }
    
    /// 构建日志参数
    private func buildLogParams(message: String) -> [URLQueryItem] {
        return [
            URLQueryItem(name: "imei", value: CatKey.getUserUUID()),
            URLQueryItem(name: "country", value: CatKey.getCountryCode()),
            URLQueryItem(name: "lang", value: CatKey.getLanguageCode()),
            URLQueryItem(name: "mobile", value: ReportCat.DEVICE),
            URLQueryItem(name: "pk", value: CatKey.getBundleID()),
            URLQueryItem(name: "version", value: CatKey.getAppVersion()),
            URLQueryItem(name: "info", value: message)
        ]
    }
    
    /// 发送请求
    private func request(urlString: String) async {
        guard let url = URL(string: urlString) else {
            logDebug("ReportCat: Invalid URL")
            return
        }
        
        //let request = URLRequest(url: url, timeoutInterval: TimeInterval(ReportCat.TIMEOUT))
        let request = URLRequest(url: url)
        let startTime = Date()
        logDebug("ReportCat: Request start ** start time: \(startTime)")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            let httpResponse = response as! HTTPURLResponse
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                logDebug("ReportCat: Request success ** url: \(url) ** status: \(httpResponse.statusCode) ** duration: \(String(format: "%.2f", duration))s")
            } else {
                logDebug("ReportCat: Request failed with status ** url: \(url) ** status: \(httpResponse.statusCode) ** duration: \(String(format: "%.2f", duration))s")
            }
        } catch {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            logDebug("ReportCat: Request failed: \(error.localizedDescription) ** url: \(url) ** duration: \(String(format: "%.2f", duration))s")
        }
    }
    
    /// 获取当前连接的IP
    private func getIP() -> String {
        if GlobalStatus.shared.connectStatus == .connected {
            let ip = ServiceCFHelper.shared.ipService
            return (ip?.isEmpty == false) ? ip! : "0.0.0.0"
        } else {
            return "local"
        }
    }
    
    /// 生成时间戳
    private func getTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddHHmmss"
        return formatter.string(from: Date())
    }
    
    /// 生成随机ID
    static func generateRandomId() -> String {
        return String(UUID().uuidString.prefix(8))
    }
}
