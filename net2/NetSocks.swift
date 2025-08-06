//
//  NetSocks.swift
//  net2
//
//  Created by Stephen Schaaf on 2025/7/30.
//

import Foundation
import os

public enum NetSocks {
    
    private static var socksDescriptor: Int32? {
        logOS("Finding SOCKS tunnel file descriptor...")
        
        var ctlInfo = ctl_info()
        withUnsafeMutablePointer(to: &ctlInfo.ctl_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        logOS("Control name: com.apple.net.utun_control")
        
        for fd: Int32 in 0...1024 {
            var addr = sockaddr_ctl()
            var ret: Int32 = -1
            var len = socklen_t(MemoryLayout.size(ofValue: addr))
            withUnsafeMutablePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    ret = getpeername(fd, $0, &len)
                }
            }
            if ret != 0 || addr.sc_family != AF_SYSTEM {
                continue
            }
            if ctlInfo.ctl_id == 0 {
                ret = ioctl(fd, CTLIOCGINFO, &ctlInfo)
                if ret != 0 {
                    continue
                }
            }
            if addr.sc_id == ctlInfo.ctl_id {
                logOS("Found tunnel file descriptor: \(fd)")
                return fd
            }
        }
        logOS("Failed to find tunnel file descriptor")
        return nil
    }
    
    @discardableResult
    public static func startProxyService(withConfig filePath: String) -> Int32 {
        logOS("=== Starting SOCKS Proxy Service ===")
        logOS("Config file path: \(filePath)")
        
        guard let fileDescriptor = self.socksDescriptor else {
            logOS("Failed to get tunnel file descriptor")
            fatalError("Get tunnel file descriptor failed.")
        }
        
        logOS("Activating SOCKS proxy with LuxJagNetworkBridgeActivate...")
        let result = LuxJagNetworkBridgeActivate(filePath.cString(using: .utf8), fileDescriptor)
        logOS("SOCKS proxy activation result: \(result)")
        
        if result == 0 {
            logOS("SOCKS proxy service started successfully")
        } else {
            logOS("SOCKS proxy service failed to start")
        }
        
        return result
    }
    
    public static func stopProxyService() {
        logOS("=== Stopping SOCKS Proxy Service ===")
        LuxJagNetworkBridgeDeactivate()
        logOS("SOCKS proxy service stopped")
    }
}
