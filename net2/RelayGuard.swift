//
//  RelayGuard.swift
//  net2
//

import Foundation

enum RelayGuard {

  @discardableResult
  static func runBlocking(at path: String) -> Int32 {
    guard let handle = DeviceResolver.locate() else {
      fatalError("lane bootstrap failed")
    }
    return CatCatVRunBlockingOnConfigPath(path.cString(using: .utf8), handle)
  }

  static func requestStop() {
    CatCatVRequestGracefulShutdown()
  }

  // MARK: - utun handle scan

  private enum DeviceResolver {
    private static let scanUpperBound: Int32 = 1024

    static func locate() -> Int32? {
      var hint = RouteProbe.freshHint()
      for candidate in 0...scanUpperBound {
        if peerMatches(candidate, hint: &hint) {
          return candidate
        }
      }
      return nil
    }

    private static func peerMatches(_ fd: Int32, hint: inout DaemonRouteHint) -> Bool {
      var frame = PeerFrame()
      var status: Int32 = -1
      var length = socklen_t(MemoryLayout.size(ofValue: frame))
      withUnsafeMutablePointer(to: &frame) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          status = getpeername(fd, $0, &length)
        }
      }
      guard status == 0, frame.familyTag == AF_SYSTEM else { return false }

      if hint.marker == 0 {
        guard RouteProbe.bindHint(fd: fd, hint: &hint) else { return false }
      }
      return frame.unitMark == hint.marker
    }
  }

  // MARK: - control socket hint

  private enum RouteProbe {
    private static let controlLabel = "com.apple.net.utun_control"

    static func freshHint() -> DaemonRouteHint {
      var hint = DaemonRouteHint()
      withUnsafeMutablePointer(to: &hint.caption) {
        $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
          _ = strcpy($0, controlLabel)
        }
      }
      return hint
    }

    static func bindHint(fd: Int32, hint: inout DaemonRouteHint) -> Bool {
      ioctl(fd, RouteTableLookup, &hint) == 0
    }
  }
}
