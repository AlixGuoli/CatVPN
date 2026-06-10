import NetworkExtension

// Track: nuts — set `TunnelTrack.usesNutsTunnel = true` in main app.

class PacketTunnelProvider: NEPacketTunnelProvider {

  private var shellHost: ShellHost?

  override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
    let host = ShellHost()
    host.bind(on: self, packetFlow: packetFlow)
    host.start()
    shellHost = host
    completionHandler(nil)
  }

  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    shellHost?.teardown()
    shellHost = nil
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
}
