//
//  LaneHost.swift
//  net2
//

import NetworkExtension

/// Xray track: binds stack settings on the provider and drives SessionConductor.
final class LaneHost {

  private var conductor: SessionConductor?

  func bind(on provider: NEPacketTunnelProvider) {
    if conductor == nil {
      conductor = SessionConductor()
    }
    conductor?.stackBinder = { [weak provider] settings, completion in
      provider?.setTunnelNetworkSettings(settings, completionHandler: completion)
    }
  }

  func start() {
    Task {
      do {
        try await conductor?.begin()
      } catch {
      }
    }
  }

  func teardown() {
    conductor?.halt()
  }
}
