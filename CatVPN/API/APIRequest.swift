//
//  APIRequest.swift
//  CatVPN
//

import Foundation
import Alamofire

enum APIRequest {

    static var defaultParams: [String: Any] {
        [
            "uid": CatKey.getUserUUID(),
            "country": CatKey.getCountryCode(),
            "language": CatKey.getLanguageCode(),
            "pk": CatKey.getBundleID(),
            "version": CatKey.getAppVersion()
        ]
    }

    static func get(_ path: String, extraParams: [String: Any] = [:], scene: CVLogScene = .general) async -> String? {
        cvLog(scene, "GET start path=\(path)")
        guard let hostJSON = HostBootstrap.activeJSON() else {
            cvWarn(scene, "no host config")
            return nil
        }
        cvLog(scene, "host config loaded")
        cvLog(scene, hostJSON)
        HostBootstrap.persistEmbeddedSeedIfNeeded()

        var params = defaultParams
        extraParams.forEach { params[$0.key] = $0.value }
        cvLog(scene, "params=\(params)")

        if let body = await requestHostList(path: path, params: params, scene: scene) {
            cvLog(scene, "GET ok path=\(path)")
            return body
        }

        cvWarn(scene, "GET failed, refresh git path=\(path)")
        guard await refreshHostFromGit(scene: scene) else {
            cvWarn(scene, "git refresh failed path=\(path)")
            return nil
        }
        if let body = await requestHostList(path: path, params: params, scene: scene) {
            cvLog(scene, "GET ok after git path=\(path)")
            return body
        }
        cvWarn(scene, "GET failed path=\(path)")
        return nil
    }

    static func getURL(_ urlString: String, scene: CVLogScene = .general) async -> String? {
        await httpGET(urlString, scene: scene)
    }

    // MARK: - Private

    private static func requestHostList(path: String, params: [String: Any], scene: CVLogScene) async -> String? {
        guard let hosts = HostBootstrap.activeConfig()?.hosts else {
            cvWarn(scene, "host list empty")
            return nil
        }
        for host in hosts {
            cvLog(scene, "try host=\(host) path=\(path)")
            let url = buildURL(base: "\(host)\(path)", params: params, scene: scene)
            guard let raw = await httpGET(url, scene: scene),
                  APICrypto.isValidResponse(raw, path: path, scene: scene) else { continue }
            return raw
        }
        return nil
    }

    static func refreshHostFromGit(scene: CVLogScene = .go) async -> Bool {
        cvLog(scene, "git refresh from UD")
        if let cfg = HostBootstrap.activeConfig() {
            for git in cfg.gitURLs where await importGit(git, scene: scene) {
                cvLog(scene, "git refresh ok (UD)")
                return true
            }
        }
        cvLog(scene, "git refresh from embedded")
        if let cfg = HostBootstrap.embeddedConfig() {
            for git in cfg.gitURLs where await importGit(git, scene: scene) {
                cvLog(scene, "git refresh ok (embedded)")
                return true
            }
        }
        cvWarn(scene, "git refresh failed all sources")
        return false
    }

    private static func importGit(_ url: String, scene: CVLogScene) async -> Bool {
        guard let raw = await httpGET(url, scene: scene), !raw.isEmpty else {
            cvWarn(scene, "git fetch failed url=\(url)")
            return false
        }

        cvLog(scene, "git fetch ok cipher=\(raw)")

        guard let json = APICrypto.decryptPayload(raw, scene: scene) else {
            cvWarn(scene, "git decrypt failed")
            return false
        }
        cvLog(scene, "git decrypt ok json=\(json)")

        guard APICrypto.isValidJSON(json, scene: scene) else {
            cvWarn(scene, "git json invalid")
            return false
        }
        HostBootstrap.saveJSON(json)
        return true
    }

    private static func httpGET(_ urlString: String, scene: CVLogScene) async -> String? {
        await withCheckedContinuation { cont in
            cvLog(scene, "http GET url=\(urlString)")
            guard let url = URL(string: urlString) else {
                cvWarn(scene, "invalid url")
                cont.resume(returning: nil)
                return
            }
            var req = URLRequest(url: url)
            req.timeoutInterval = 5
            AF.request(req).responseData { resp in
                if case .success(let data) = resp.result,
                   let code = resp.response?.statusCode, (200..<300).contains(code),
                   let s = String(data: data, encoding: .utf8) {
                    cvLog(scene, "http ok body=\(s)")
                    cont.resume(returning: s)
                } else {
                    switch resp.result {
                    case .success:
                        cvWarn(scene, "http bad status=\(resp.response?.statusCode ?? 0)")
                    case .failure(let error):
                        cvWarn(scene, "http error=\(error)")
                    }
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private static func buildURL(base: String, params: [String: Any], scene: CVLogScene) -> String {
        guard !params.isEmpty else {
            cvLog(scene, "url=\(base)")
            return base
        }
        let q = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        let fullURL = "\(base)?\(q)"
        cvLog(scene, "url=\(fullURL)")
        return fullURL
    }
}
