//
//  LinkStatus.swift
//  CatVPN
//

import Foundation
import NetworkExtension

final class LinkStatus {

    private weak var owner: MainViewmodel?
    private var vpnObserver: NSObjectProtocol?

    var connectManual = false
    private(set) var isProbing = false

    init(owner: MainViewmodel) {
        self.owner = owner
    }

    func install() {
        vpnObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleVPNStatusChange()
        }
    }

    func uninstall() {
        if let vpnObserver {
            NotificationCenter.default.removeObserver(vpnObserver)
            self.vpnObserver = nil
        }
    }

    func regainVPN() {
        guard let owner else { return }
        owner.manager.restoreExistingManagerIfAny { [weak self] status in
            guard let self, let owner = self.owner, let status else {
                cvLog("restore skip no profile")
                return
            }
            cvLog("restore status=\(status)")
            DispatchQueue.main.async {
                owner.state = status
            }
        }
    }

    func updateConnectionStatusIfNeeded() {
        guard let owner else { return }

        switch owner.state {
        case .connected:
            linkLog("connected manual=\(connectManual) probing=\(isProbing) probeRequired=\(TunnelTrack.requiresLinkProbe)")
            if connectManual {
                if TunnelTrack.requiresLinkProbe {
                    guard beginProbeIfNeeded() else { return }
                    owner.checkGG()
                } else {
                    connectManual = false
                    owner.connectSuccessful()
                }
            } else {
                connectManual = false
                owner.connectionStatus = .connected
                owner.beginConnectionTiming()
            }
        case .disconnected, .invalid:
            linkLog("disconnected")
            finishProbe()
            owner.connectionStatus = .disconnected
            owner.endConnectionTiming()
        case .connecting:
            linkLog("connecting")
            owner.connectionStatus = .connecting
        case .disconnecting, .reasserting:
            linkLog("disconnecting")
            owner.connectionStatus = .connecting
        @unknown default:
            linkWarn("unknown status")
            owner.connectionStatus = .failed
        }
    }

    private func handleVPNStatusChange() {
        guard let owner else { return }
        owner.state = VPNConnectionManager.instance().connectionManager.connection.status
        linkLog("NEVPN status=\(owner.state) ui=\(owner.connectionStatus)")
    }

    /// Returns false when a probe is already running (avoids duplicate checks on repeated `.connected` callbacks).
    func beginProbeIfNeeded() -> Bool {
        guard !isProbing else {
            linkLog("probe skip already in flight")
            return false
        }
        isProbing = true
        return true
    }

    func finishProbe() {
        isProbing = false
    }
}
