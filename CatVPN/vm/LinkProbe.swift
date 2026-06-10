import Foundation
import Alamofire

enum LinkProbe {

    static func validateConnection() async -> Bool {
        var targetUrls: [String] = []
        let serverList = SystemConfigStore.detectionServers()
        if !serverList.isEmpty {
            targetUrls = serverList
        } else {
            targetUrls = ["", ""]
        }

        linkLog("probe start urls=\(targetUrls)")

        let syncGroup = DispatchGroup()
        var connectionEstablished = false

        for url in targetUrls {
            linkLog("probe try url=\(url)")
            syncGroup.enter()
            AF.request(url, method: .get)
                .validate(statusCode: 0..<1000)
                .response { response in
                    if case .success = response.result {
                        linkLog("probe ok url=\(url)")
                        connectionEstablished = true
                        AF.session.getAllTasks { tasks in tasks.forEach { $0.cancel() } }
                    } else if case .failure(let error) = response.result {
                        linkWarn("probe fail url=\(url) err=\(error.localizedDescription)")
                    }
                    syncGroup.leave()
                }
        }

        let timeoutResult = syncGroup.wait(timeout: .now() + 10)
        if timeoutResult == .timedOut {
            linkWarn("probe timeout 10s")
            AF.session.getAllTasks { tasks in tasks.forEach { $0.cancel() } }
        }

        linkLog(connectionEstablished ? "probe pass" : "probe fail")
        return connectionEstablished
    }
}
