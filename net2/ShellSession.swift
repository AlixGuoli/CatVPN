//
//  ShellSession.swift
//  net2
//

import Foundation
import Network
import NetworkExtension

final class ShellSession {

  var stackBinder: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?

  private let packetFlow: NEPacketTunnelFlow
  private var tcpLink: NWConnection?
  private var workQueue: DispatchQueue?
  private var ingressBuffer = Data()
  private var egressBuffer = Data()

  init(packetFlow: NEPacketTunnelFlow) {
    self.packetFlow = packetFlow
  }

  func begin() {
    let host = ShellEndpoint.relayHost
    let portText = ShellEndpoint.relayPort
    guard let port = NWEndpoint.Port(portText) else { return }

    let endpoint = NWEndpoint.Host(host)
    tcpLink = NWConnection(host: endpoint, port: port, using: .tcp)
    workQueue = .global()
    tcpLink?.stateUpdateHandler = { [weak self] state in
      self?.handleLinkState(state)
    }
    tcpLink?.start(queue: workQueue!)
  }

  func halt() {
    tcpLink?.cancel()
    tcpLink = nil
  }

  // MARK: - Link state

  private func handleLinkState(_ state: NWConnection.State) {
    switch state {
    case .ready:
      sendAuthHandshake()
    case .failed, .cancelled:
      break
    default:
      break
    }
  }

  // MARK: - Handshake

  private func sendAuthHandshake() {
    guard let authBlob = buildAuthBlob() else { return }
    let mixKey = ShellEndpoint.streamMixKey
    let framed = ShellCipher.wrapFrame(authBlob, key: mixKey, paddingCap: ShellEndpoint.paddingCap)
    tcpLink?.send(content: framed, completion: .contentProcessed { [weak self] error in
      guard let self, error == nil else { return }
      self.readAuthHeader()
    })
  }

  private func buildAuthBlob() -> Data? {
    let body: [String: Any] = [
      "package": ShellIdentity.bundleID,
      "version": ShellIdentity.appVersion,
      "SDK": "7.0",
      "country": ShellIdentity.regionCode,
      "language": ShellIdentity.languageCode,
      "action": "new_connect",
    ]
    guard let json = try? JSONSerialization.data(withJSONObject: body, options: []),
          let keyMaterial = ShellEndpoint.authKeyMaterial.data(using: .utf8) else {
      return nil
    }
    return ShellCipher.encryptAuthBlob(json, keyMaterial: keyMaterial)
  }

  private func readAuthHeader() {
    tcpLink?.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, error in
      guard let self, let data, error == nil else { return }
      self.ingressBuffer.append(data)
      if self.ingressBuffer.count >= 2 {
        let frameLength = self.ingressBuffer.prefix(2).withUnsafeBytes {
          $0.load(as: UInt16.self).bigEndian
        }
        self.ingressBuffer.removeFirst(2)
        self.readAuthBody(Int(frameLength))
      } else {
        self.readAuthHeader()
      }
    }
  }

  private func readAuthBody(_ expectedLength: Int) {
    tcpLink?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, _, error in
      guard let self, let data, error == nil else { return }
      self.ingressBuffer.append(data)
      if self.ingressBuffer.count >= expectedLength {
        let frame = self.ingressBuffer.prefix(expectedLength)
        self.ingressBuffer.removeFirst(expectedLength)
        let mixKey = ShellEndpoint.streamMixKey
        let clear = ShellCipher.unwrapFrame(frame, key: mixKey)
        self.applyAssignedAddress(clear)
      } else {
        self.readAuthBody(expectedLength)
      }
    }
  }

  private func applyAssignedAddress(_ responseData: Data) {
    guard let text = String(data: responseData, encoding: .utf8) else { return }
    let assignedIP = text.split(separator: ",").map(String.init).first ?? ""
    guard !assignedIP.isEmpty else { return }
    applyTunnelProfile(intranetIP: assignedIP)
  }

  // MARK: - Tunnel profile

  private func applyTunnelProfile(intranetIP: String) {
    let profile = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.10.0.1")
    profile.mtu = 1400
    profile.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
    let ipv4 = NEIPv4Settings(addresses: [intranetIP], subnetMasks: ["255.255.0.0"])
    ipv4.includedRoutes = [NEIPv4Route.default()]
    profile.ipv4Settings = ipv4
    stackBinder?(profile) { [weak self] error in
      guard let self, error == nil else { return }
      self.pumpOutbound()
      self.pumpInbound()
    }
  }

  // MARK: - Packet pump

  private func pumpOutbound() {
    let mixKey = ShellEndpoint.streamMixKey
    packetFlow.readPackets { [weak self] packets, _ in
      guard let self else { return }
      for packet in packets {
        let framed = ShellCipher.wrapFrame(packet, key: mixKey, paddingCap: ShellEndpoint.paddingCap)
        self.tcpLink?.send(content: framed, completion: .contentProcessed { _ in })
      }
      self.pumpOutbound()
    }
  }

  private func pumpInbound() {
    tcpLink?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] data, _, _, error in
      guard let self, let data, !data.isEmpty, error == nil else { return }
      self.egressBuffer.append(data)
      self.drainEgressFrames()
      self.pumpInbound()
    }
  }

  private func drainEgressFrames() {
    let mixKey = ShellEndpoint.streamMixKey
    while egressBuffer.count >= 2 {
      let frameLength = egressBuffer.prefix(2).withUnsafeBytes {
        $0.load(as: UInt16.self).bigEndian
      }
      egressBuffer.removeSubrange(0..<2)
      if egressBuffer.count >= frameLength {
        let frame = egressBuffer.prefix(Int(frameLength))
        egressBuffer.removeSubrange(0..<Int(frameLength))
        let clear = ShellCipher.unwrapFrame(frame, key: mixKey)
        packetFlow.writePackets([clear], withProtocols: [AF_INET as NSNumber])
      } else {
        egressBuffer.insert(contentsOf: withUnsafeBytes(of: frameLength.bigEndian, Array.init), at: 0)
        break
      }
    }
  }
}
