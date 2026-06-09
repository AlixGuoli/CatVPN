import Foundation

enum ConnectionRuntimeStore {
    private static var currentIP: String?
    private static var currentSID: String?
    private static var currentEncryptedConfig: String?
    private static var remoteConfigSource = true

    static var ip: String? {
        get { currentIP }
        set { currentIP = newValue }
    }

    static var sid: String? {
        get { currentSID }
        set { currentSID = newValue }
    }

    static var encryptedConfig: String? {
        get { currentEncryptedConfig }
        set { currentEncryptedConfig = newValue }
    }

    static var isFromRequest: Bool {
        get { remoteConfigSource }
        set { remoteConfigSource = newValue }
    }

    static func resetForNewConnection() {
        currentIP = nil
        currentSID = FlowReport.makeSID()
        currentEncryptedConfig = nil
        remoteConfigSource = true
    }
}
