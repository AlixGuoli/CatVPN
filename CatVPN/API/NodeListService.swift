import Foundation

enum NodeListService {
    static func fetchServers() async -> [VPNServer] {
        cvLog("node list start")
        guard let raw = await APIRequest.get(APIPaths.groupList),
              let servers = parseServers(from: raw),
              !servers.isEmpty else {
            cvWarn("node list failed, use defaults")
            return VPNServer.availableServers
        }

        let result = prependAutoIfNeeded(servers)
        cvLog("node list count=\(result.count)")
        return result
    }

    private static func parseServers(from raw: String) -> [VPNServer]? {
        do {
            guard let data = raw.data(using: .utf8),
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let categories = root["categories"] as? [[String: Any]] else {
                cvWarn("node list parse failed")
                return nil
            }

            let nodes = categories.flatMap { category -> [[String: Any]] in
                category["nodes"] as? [[String: Any]] ?? []
            }

            let servers = nodes.compactMap { node -> VPNServer? in
                guard let id = node["id"] as? Int,
                      let name = node["name"] as? String,
                      let country = node["country"] as? String else {
                    cvWarn("invalid node item")
                    return nil
                }

                return VPNServer(
                    id: id,
                    name: name,
                    country: country,
                    flagEmoji: flagEmoji(for: country),
                    ping: Int.random(in: 10...40)
                )
            }

            cvLog("node list parsed nodes=\(servers.count)")
            return servers
        } catch {
            cvWarn("node list parse error")
            return nil
        }
    }

    private static func prependAutoIfNeeded(_ servers: [VPNServer]) -> [VPNServer] {
        guard !servers.contains(where: { $0.id == -1 }) else { return servers }
        return [VPNServer(id: -1, name: "Auto", country: "AUTO", flagEmoji: "⚡️", ping: Int.random(in: 10...30))] + servers
    }

    private static func flagEmoji(for countryCode: String) -> String {
        let code = countryCode.uppercased()
        guard code.count == 2 else { return "🌐" }
        let base: UInt32 = 127397
        var scalarView = String.UnicodeScalarView()
        for scalar in code.unicodeScalars {
            guard let flagScalar = UnicodeScalar(base + scalar.value) else { return "🌐" }
            scalarView.append(flagScalar)
        }
        return String(scalarView)
    }
}
