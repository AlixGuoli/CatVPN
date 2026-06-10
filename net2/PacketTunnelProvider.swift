import NetworkExtension

// Track: lane (xray) — set `TunnelTrack.usesNutsTunnel = false` in main app.

class PacketTunnelProvider: NEPacketTunnelProvider {

  // MARK: - Nuts track
  //private var shellHost: ShellHost?

  // MARK: - Lane track
  private var laneHost: LaneHost?

  override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
    guard LaunchGate.permits() else {
      cancelTunnelWithError(LaunchGate.denial())
      return
    }

    let host = LaneHost()
    host.bind(on: self)
    host.start()
    laneHost = host
    completionHandler(nil)

    // Nuts track:
    //let host = ShellHost()
    //host.bind(on: self, packetFlow: packetFlow)
    //host.start()
    //shellHost = host
    //completionHandler(nil)
  }

  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    laneHost?.teardown()
    laneHost = nil
    completionHandler()

    // Nuts: shellHost?.teardown(); shellHost = nil
  }

  override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
    completionHandler?(messageData)
  }

  override func sleep(completionHandler: @escaping () -> Void) {
    completionHandler()
  }

  override func wake() {
  }
}

// MARK: - Cold-start window (lane track only)

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
