//
//  ShellHost.swift
//  net2
//

import NetworkExtension

/// Nuts track: binds stack settings on the provider and drives ShellSession.
final class ShellHost {

  private var session: ShellSession?

  func bind(on provider: NEPacketTunnelProvider, packetFlow: NEPacketTunnelFlow) {
    if session == nil {
      session = ShellSession(packetFlow: packetFlow)
    }
    session?.stackBinder = { [weak provider] settings, completion in
      provider?.setTunnelNetworkSettings(settings, completionHandler: completion)
    }
  }

  func start() {
    session?.begin()
  }

  func teardown() {
    session?.halt()
    session = nil
  }
}
