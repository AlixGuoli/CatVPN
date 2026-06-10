import Foundation

/// Release track switch — keep in sync with `PacketTunnelProvider` (nuts vs lane).
enum TunnelTrack {
    static let usesNutsTunnel = false

    static var requiresLinkProbe: Bool { !usesNutsTunnel }
}
