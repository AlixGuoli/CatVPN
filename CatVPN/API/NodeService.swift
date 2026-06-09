//
//  NodeService.swift
//  CatVPN
//

import Foundation

enum NodeConfigError: Error {
    case unavailable
    case decryptFailed
}

enum NodeService {

    static func fetchEncryptedConfig(group: Int = -1, vip: Int = 0) async -> String? {
        linkLog("node config fetch start group=\(group) serverId=\(NodeSelectionStore.currentServerID)")
        let result = await APIRequest.get(
            APIPaths.nodeConfig,
            extraParams: ["group": group, "vip": vip],
            scene: .link
        )
        if let result, !result.isEmpty {
            linkLog("node config fetch ok")
        } else {
            linkWarn("node config fetch failed")
        }
        return result
    }

    static func decryptConfig(_ encrypted: String) -> String? {
        linkLog("node config decrypt")
        guard let json = APICrypto.decryptPayload(encrypted, logResult: true, scene: .link) else {
            linkWarn("node config decrypt failed")
            return nil
        }
        linkLog("node config decrypt ok")
        return json
    }

    static func resolveEncryptedConfig(group: Int = -1, vip: Int = 0) async throws -> (encrypted: String, fromRequest: Bool) {
        if let remote = await fetchEncryptedConfig(group: group, vip: vip), !remote.isEmpty {
            linkLog("node config source=remote group=\(group)")
            return (remote, true)
        }
        if let cached = NodeConfigStore.cachedEncryptedConfig() {
            linkLog("node config source=cache group=\(group) len=\(cached.count)")
            return (cached, false)
        }
        linkWarn("node config unavailable")
        throw NodeConfigError.unavailable
    }

    static func resolveDecryptedConfig(group: Int = -1, vip: Int = 0) async throws -> (json: String, fromRequest: Bool) {
        let resolved = try await resolveEncryptedConfig(group: group, vip: vip)
        guard let json = decryptConfig(resolved.encrypted) else {
            linkWarn("node config decrypt failed")
            throw NodeConfigError.decryptFailed
        }
        return (json, resolved.fromRequest)
    }
}
