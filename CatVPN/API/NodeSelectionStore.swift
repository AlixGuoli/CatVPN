import Foundation

enum NodeSelectionStore {
    private static let selectedServerIDKey = "SelectedServerID"

    static var currentServerID: Int {
        get {
            let savedID = UserDefaults.standard.integer(forKey: selectedServerIDKey)
            return savedID != 0 ? savedID : -1
        }
        set {
            UserDefaults.standard.set(newValue, forKey: selectedServerIDKey)
            UserDefaults.standard.synchronize()
        }
    }

    static func save(_ server: VPNServer) {
        currentServerID = server.id
        cvLog("server selected id=\(server.id) \(server.name)")
    }

    static func selectedServer(from servers: [VPNServer]) -> VPNServer {
        let savedID = currentServerID
        if let savedServer = servers.first(where: { $0.id == savedID }) {
            cvLog("server restored id=\(savedServer.id)")
            return savedServer
        }

        if savedID != -1 {
            cvWarn("saved server id=\(savedID) missing")
        }

        return servers.first(where: { $0.id == -1 })
            ?? VPNServer(id: -1, name: "Auto", country: "AUTO", flagEmoji: "⚡️", ping: 18)
    }
}
