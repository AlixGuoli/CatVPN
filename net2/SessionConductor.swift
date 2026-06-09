//
//  SessionConductor.swift
//  net2
//

import Foundation
import NetworkExtension

final class SessionConductor {

  /// Bound by LaneHost to call setTunnelNetworkSettings.
  var stackBinder: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?

  func begin() async throws {
    try await applyStack()
    try igniteServices()
  }

  func halt() {
    CoreEngine.stop()
  }

  // MARK: - Stack

  private func applyStack() async throws {
    let profile = StackBlueprint.make()
    stackBinder?(profile) { _ in }
  }

  private func igniteServices() throws {
    try RelayLane.ignite()
    try CoreEngine.ignite()
  }
}

// MARK: - Tunnel network profile

private enum StackBlueprint {

  static func make() -> NEPacketTunnelNetworkSettings {
    let profile = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
    profile.mtu = 9000
    profile.ipv4Settings = v4Slice()
    profile.dnsSettings = resolverSlice()
    return profile
  }

  private static func v4Slice() -> NEIPv4Settings {
    let slice = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
    slice.includedRoutes = [NEIPv4Route.default()]
    return slice
  }

  private static func resolverSlice() -> NEDNSSettings {
    NEDNSSettings(servers: ["8.8.8.8", "114.114.114.114"])
  }
}

// MARK: - Relay lane (background, blocking)

private enum RelayLane {

  static func ignite() throws {
    let location = ProfileLedger.relayProfileLocation()
    DispatchQueue.global(qos: .userInitiated).async {
      RelayGuard.runBlocking(at: location)
    }
  }
}

// MARK: - Core engine (CGo)

private enum CoreEngine {

  static func ignite() throws {
    let manifest = ProfileLedger.composeManifest()
    let encoded = Data(manifest.utf8).base64EncodedString()
    try launch(encoded)
  }

  static func stop() {
    CGoStopCatCatV()
  }

  private static func launch(_ base64Payload: String) throws {
    let cString = strdup(base64Payload)
    defer { free(cString) }

    guard let cString else {
      throw NSError(
        domain: "com.cat.session.conductor",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "buffer allocation failed"]
      )
    }

    CGoRunCatCatV(UnsafeMutablePointer(mutating: cString))
  }
}
