import Foundation

enum FlowReport {
    static let connectStart = "start_connect"
    static let connectFailed = "connect_failed"
    static let connectSuccess = "connect_success"
    static let disconnect = "disconnect"

    private static let device = "iPhone"

    static func connect(_ moment: String, ip: String? = nil, sid: String? = nil) {
        let code = "\(timestamp())-\(sid ?? "")"

        let message: String
        switch moment {
        case connectStart:
            message = "\(connectStart),\(code),0.0.0.0"
        case connectFailed:
            message = "\(connectFailed),\(code),\(ip ?? "0.0.0.0")"
        case connectSuccess:
            message = "\(connectSuccess),0,\(code),\(ip ?? "0.0.0.0")"
        default:
            txWarn("connect unknown moment=\(moment)")
            return
        }

        txLog("connect payload=\(message)")
        sendLog(message)
    }

    static func status(success: Bool) {
        Task.detached {
            guard let endpoint = HostBootstrap.activeConfig()?.gReport else {
                txWarn("status no endpoint")
                return
            }

            let statusCode = success ? "0" : "1"
            txLog("status code=\(statusCode)")

            guard let url = buildURL(endpoint: endpoint, message: statusCode, type: .status) else {
                txWarn("status bad url")
                return
            }

            txLog("status url=\(url)")
            await request(urlString: url)
        }
    }

    static func makeSID() -> String {
        String(UUID().uuidString.prefix(8))
    }

    private static func sendLog(_ message: String) {
        Task.detached {
            guard let endpoint = HostBootstrap.activeConfig()?.connReport,
                  !endpoint.isEmpty else {
                txWarn("log no endpoint")
                return
            }

            guard let url = buildURL(endpoint: endpoint, message: message, type: .log) else {
                txWarn("log bad url")
                return
            }

            txLog("log url=\(url)")
            await request(urlString: url)
        }
    }

    private enum ReportType {
        case status
        case log
    }

    private static func buildURL(endpoint: String, message: String, type: ReportType) -> String? {
        let baseURL = type == .status ? endpoint + "/report_total" : endpoint
        guard var components = URLComponents(string: baseURL) else { return nil }

        switch type {
        case .status:
            components.queryItems = statusParams(status: message)
        case .log:
            components.queryItems = logParams(message: message)
        }

        return components.url?.absoluteString
    }

    private static func statusParams(status: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "name", value: "getService"),
            URLQueryItem(name: "cty", value: CatKey.getCountryCode()),
            URLQueryItem(name: "pk", value: CatKey.getBundleID()),
            URLQueryItem(name: "v", value: CatKey.getAppVersion()),
            URLQueryItem(name: "asn", value: "0"),
            URLQueryItem(name: "isf", value: status),
            URLQueryItem(name: "cnt", value: "1")
        ]
    }

    private static func logParams(message: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "imei", value: CatKey.getUserUUID()),
            URLQueryItem(name: "country", value: CatKey.getCountryCode()),
            URLQueryItem(name: "lang", value: CatKey.getLanguageCode()),
            URLQueryItem(name: "mobile", value: device),
            URLQueryItem(name: "pk", value: CatKey.getBundleID()),
            URLQueryItem(name: "version", value: CatKey.getAppVersion()),
            URLQueryItem(name: "info", value: message)
        ]
    }

    private static func request(urlString: String) async {
        guard let url = URL(string: urlString) else {
            txWarn("request bad url")
            return
        }

        let request = URLRequest(url: url)
        let startTime = Date()
        txLog("request start url=\(url)")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let duration = Date().timeIntervalSince(startTime)
            if (200..<300).contains(code) {
                txLog("request ok status=\(code) duration=\(String(format: "%.2f", duration))s")
            } else {
                txWarn("request fail status=\(code) duration=\(String(format: "%.2f", duration))s")
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            txWarn("request error=\(error.localizedDescription) duration=\(String(format: "%.2f", duration))s")
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddHHmmss"
        return formatter.string(from: Date())
    }
}
