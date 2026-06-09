import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Nuts track
    //private var networkHandler: NetworkProtocolHandler?

    // MARK: - Lane track
    private var laneHost: LaneHost?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Nuts: startSecureTunnelManager()

        guard LaunchGate.permits() else {
            cancelTunnelWithError(LaunchGate.denial())
            return
        }

        let host = LaneHost()
        host.bind(on: self)
        host.start()
        laneHost = host

        completionHandler(nil)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Nuts: networkHandler?.terminatePacketTunnelConnection()
        laneHost?.teardown()
        laneHost = nil
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {
    }

    // MARK: - Nuts track
//    func startSecureTunnelManager() {
//        if networkHandler == nil {
//            networkHandler = NetworkProtocolHandler(packetFlow: packetFlow)
//        }
//        networkHandler?.networkConfigurationHandler = { [weak self] settings, completion in
//            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
//        }
//        networkHandler?.initializeConnectionSequence()
//    }
}

// MARK: - Cold-start window (shared by lane track; reuse for Nuts if needed)

private enum LaunchGate {

    static func permits() -> Bool {
        guard let suite = UserDefaults(suiteName: ServiceDefaults.targetGroup),
              let anchor = suite.object(forKey: ServiceDefaults.targetDate) as? Date else {
            return false
        }
        return Date().timeIntervalSince(anchor) < 10
    }

    static func denial() -> NSError {
        NSError(
            domain: "com.cat.extension.gate",
            code: 1,
            userInfo: ["reason": "window elapsed"]
        )
    }
}
