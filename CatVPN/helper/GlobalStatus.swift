//
//  GlobalStatus.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/2.
//

import Foundation
import NetworkExtension

class GlobalStatus {
    
    static let shared = GlobalStatus()
    
    private init() {}
    
    /// 全局当前连接状态
    var connectStatus: VPNConnectionStatus = .disconnected
   
}
