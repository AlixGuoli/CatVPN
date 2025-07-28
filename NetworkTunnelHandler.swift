import Foundation
import NetworkExtension
import os
import CommonCrypto
import Network

/// 差异化VPN协议处理器，功能与原版一致
class NetworkTunnelHandler {
    // MARK: - 网络连接相关
    var tunnelConnection: NWConnection?
    var workQueue: DispatchQueue?
    
    // MARK: - 服务器配置
    var serverPort: String = "8443"
    var serverAddress: String = "5.102.100.100"
    
    // MARK: - 认证与加密参数
    var userRegion: String = "us"
    var userLocale: String = "en"
    var appBundleId: String = "vpn.demo.test"
    var version: String = "1.0.0"
    var aesKey: String = "3e027e48ec6f5a9c705dfe17bed37201"
    var xorKey: String = "hfor1"
    var maxPadding: Int = 128
    
    // MARK: - 数据缓冲区
    var recvBuffer = Data()
    var sendBuffer = Data()
    
    // MARK: - 回调与数据流
    var configCallback: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var packetFlow: NEPacketTunnelFlow
    
    // MARK: - 错误回调
    /// 错误回调，外部可选实现，不处理也不影响主流程
    var errorHandler: ((Error) -> Void)?
    
    // MARK: - 初始化
    /// 初始化方法，保存数据流引用
    init(flow: NEPacketTunnelFlow) {
        self.packetFlow = flow
    }
    
    // MARK: - 启动连接流程
    /// 启动与VPN服务器的连接流程
    func startConnectionProcess() {
        guard let port = NWEndpoint.Port(serverPort) else {
            let err = NSError(domain: "VPN", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid server port"])
            // 英文日志
            os_log("[VPN] Failed to parse server port: %{public}@", log: OSLog.default, type: .error, serverPort)
            // 中文日志
            os_log("[VPN] 解析服务器端口失败: %{public}@", log: OSLog.default, type: .error, serverPort)
            errorHandler?(err)
            return
        }
        let host = NWEndpoint.Host(serverAddress)
        tunnelConnection = NWConnection(host: host, port: port, using: .tcp)
        workQueue = DispatchQueue(label: "vpn.tunnel.queue")
        tunnelConnection?.stateUpdateHandler = self.connectionStateChanged(_ :)
        tunnelConnection?.start(queue: workQueue!)
        // 英文日志
        os_log("[VPN] Start connection to server: %{public}@:%{public}@", log: OSLog.default, type: .info, serverAddress, serverPort)
        // 中文日志
        os_log("[VPN] 开始连接服务器: %{public}@:%{public}@", log: OSLog.default, type: .info, serverAddress, serverPort)
    }
    
    // MARK: - 连接状态变化处理
    /// 处理TCP连接状态变化
    func connectionStateChanged(_ state: NWConnection.State) {
        switch state {
        case .ready:
            // 英文日志
            os_log("[VPN] TCP connection ready", log: OSLog.default, type: .info)
            // 中文日志
            os_log("[VPN] TCP连接已就绪", log: OSLog.default, type: .info)
            authenticateWithServer()
        case .failed(let error):
            // 英文日志
            os_log("[VPN] TCP connection failed: %{public}@", log: OSLog.default, type: .error, String(describing: error))
            // 中文日志
            os_log("[VPN] TCP连接失败: %{public}@", log: OSLog.default, type: .error, String(describing: error))
            errorHandler?(error)
        case .cancelled:
            // 英文日志
            os_log("[VPN] TCP connection cancelled", log: OSLog.default, type: .error)
            // 中文日志
            os_log("[VPN] TCP连接已取消", log: OSLog.default, type: .error)
            let err = NSError(domain: "VPN", code: 101, userInfo: [NSLocalizedDescriptionKey: "TCP connection cancelled"])
            errorHandler?(err)
        default:
            // 英文日志
            os_log("[VPN] TCP connection state: %{public}@", log: OSLog.default, type: .info, String(describing: state))
            // 中文日志
            os_log("[VPN] TCP连接状态: %{public}@", log: OSLog.default, type: .info, String(describing: state))
            break
        }
    }
    
    // MARK: - 认证流程
    /// 向服务器发送认证信息
    func authenticateWithServer() {
        guard let authPayload = makeAuthPayload() else {
            // 英文日志
            os_log("[VPN] Failed to create authentication payload", log: OSLog.default, type: .error)
            // 中文日志
            os_log("[VPN] 创建认证数据失败", log: OSLog.default, type: .error)
            let err = NSError(domain: "VPN", code: 102, userInfo: [NSLocalizedDescriptionKey: "Failed to create authentication payload"])
            errorHandler?(err)
            return
        }
        let obfuscated = xorObfuscate(data: authPayload, key: xorKey.data(using: .utf8)!)
        tunnelConnection?.send(content: obfuscated, completion: .contentProcessed({ [weak self] error in
            guard let self = self else { return }
            if let error = error {
                // 英文日志
                os_log("[VPN] Failed to send authentication data: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                // 中文日志
                os_log("[VPN] 发送认证数据失败: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                self.errorHandler?(error)
                return
            }
            self.receiveHeaderFromServer()
        }))
    }
    
    // MARK: - 接收服务器响应头
    /// 接收服务器返回的长度前缀
    private func receiveHeaderFromServer() {
        tunnelConnection?.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, error in
            guard let self = self else { return }
            if let error = error {
                // 英文日志
                os_log("[VPN] Failed to receive header: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                // 中文日志
                os_log("[VPN] 接收响应头失败: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                self.errorHandler?(error)
                return
            }
            guard let data = data else {
                // 英文日志
                os_log("[VPN] No data received for header", log: OSLog.default, type: .error)
                // 中文日志
                os_log("[VPN] 响应头未收到数据", log: OSLog.default, type: .error)
                let err = NSError(domain: "VPN", code: 103, userInfo: [NSLocalizedDescriptionKey: "No data received for header"])
                self.errorHandler?(err)
                return
            }
            self.recvBuffer.append(data)
            if self.recvBuffer.count >= 2 {
                let len = self.recvBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                self.recvBuffer.removeFirst(2)
                self.receiveBodyFromServer(expected: Int(len))
            } else {
                self.receiveHeaderFromServer()
            }
        }
    }
    
    // MARK: - 接收服务器响应体
    /// 按长度接收服务器返回的数据
    private func receiveBodyFromServer(expected: Int) {
        tunnelConnection?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, _, error in
            guard let self = self else { return }
            if let error = error {
                // 英文日志
                os_log("[VPN] Failed to receive body: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                // 中文日志
                os_log("[VPN] 接收响应体失败: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                self.errorHandler?(error)
                return
            }
            guard let data = data else {
                // 英文日志
                os_log("[VPN] No data received for body", log: OSLog.default, type: .error)
                // 中文日志
                os_log("[VPN] 响应体未收到数据", log: OSLog.default, type: .error)
                let err = NSError(domain: "VPN", code: 104, userInfo: [NSLocalizedDescriptionKey: "No data received for body"])
                self.errorHandler?(err)
                return
            }
            self.recvBuffer.append(data)
            if self.recvBuffer.count >= expected {
                let encrypted = self.recvBuffer.prefix(expected)
                self.recvBuffer.removeFirst(expected)
                let plain = self.xorDeobfuscate(data: encrypted, key: self.xorKey.data(using: .utf8)!)
                self.handleServerResponse(plain)
            } else {
                self.receiveBodyFromServer(expected: expected)
            }
        }
    }
    
    // MARK: - 处理服务器响应
    /// 解析服务器分配的IP并配置隧道
    private func handleServerResponse(_ response: Data) {
        let respStr = String(data: response, encoding: .utf8)
        let ip = extractIP(from: respStr ?? "")
        // 英文日志
        os_log("[VPN] Assigned IP from server: %{public}@", log: OSLog.default, type: .info, ip)
        // 中文日志
        os_log("[VPN] 服务器分配的IP: %{public}@", log: OSLog.default, type: .info, ip)
        setupTunnelNetwork(ip: ip)
    }
    
    // MARK: - 配置隧道网络参数
    /// 配置VPN隧道的网络设置
    func setupTunnelNetwork(ip: String) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.10.0.1")
        settings.mtu = 1400
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
        settings.ipv4Settings = {
            let ipv4 = NEIPv4Settings(addresses: [ip], subnetMasks: ["255.255.0.0"])
            ipv4.includedRoutes = [NEIPv4Route.default()]
            return ipv4
        }()
        configCallback?(settings) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                // 英文日志
                os_log("[VPN] Failed to apply tunnel settings: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                // 中文日志
                os_log("[VPN] 应用隧道网络设置失败: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                self.errorHandler?(error)
                return
            }
            self.startPacketForwarding()
        }
    }
    
    // MARK: - 启动数据转发
    /// 启动本地到远程、远程到本地的数据转发
    private func startPacketForwarding() {
        forwardLocalToRemote()
        forwardRemoteToLocal()
    }
    
    // MARK: - 本地到远程数据转发
    /// 读取本地数据包并发送到服务器
    func forwardLocalToRemote() {
        let key = xorKey.data(using: .utf8)!
        packetFlow.readPackets { [weak self] (packets, _) in
            guard let self = self else { return }
            for pkt in packets {
                let obf = self.xorObfuscate(data: pkt, key: key)
                self.tunnelConnection?.send(content: obf, completion: .contentProcessed({ error in
                    if let error = error {
                        // 英文日志
                        os_log("[VPN] Failed to send packet to server: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                        // 中文日志
                        os_log("[VPN] 发送数据包到服务器失败: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                        self.errorHandler?(error)
                    }
                }))
            }
            self.forwardLocalToRemote()
        }
    }
    
    // MARK: - 远程到本地数据转发
    /// 接收服务器数据并写入本地网络
    func forwardRemoteToLocal() {
        tunnelConnection?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] data, _, _, error in
            guard let self = self else { return }
            if let error = error {
                // 英文日志
                os_log("[VPN] Failed to receive packet from server: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                // 中文日志
                os_log("[VPN] 从服务器接收数据包失败: %{public}@", log: OSLog.default, type: .error, String(describing: error))
                self.errorHandler?(error)
                return
            }
            guard let data = data, !data.isEmpty else {
                // 英文日志
                os_log("[VPN] No data received from server", log: OSLog.default, type: .error)
                // 中文日志
                os_log("[VPN] 未收到服务器数据", log: OSLog.default, type: .error)
                let err = NSError(domain: "VPN", code: 105, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])
                self.errorHandler?(err)
                return
            }
            self.sendBuffer.append(data)
            self.processReceivedPackets()
            self.forwardRemoteToLocal()
        }
    }
    
    // MARK: - 处理接收到的数据包
    /// 解析数据包长度并写入本地网络
    private func processReceivedPackets() {
        let key = xorKey.data(using: .utf8)!
        while sendBuffer.count >= 2 {
            let pktLen = sendBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            sendBuffer.removeFirst(2)
            if sendBuffer.count >= pktLen {
                let obfPkt = sendBuffer.prefix(Int(pktLen))
                sendBuffer.removeFirst(Int(pktLen))
                let clearPkt = xorDeobfuscate(data: obfPkt, key: key)
                let proto = AF_INET as NSNumber
                packetFlow.writePackets([clearPkt], withProtocols: [proto])
            } else {
                sendBuffer.insert(contentsOf: withUnsafeBytes(of: pktLen.bigEndian, Array.init), at: 0)
                break
            }
        }
    }
    
    // MARK: - 数据混淆（XOR+填充+长度）
    /// 对数据进行XOR混淆并加上随机填充和长度前缀
    func xorObfuscate(data: Data, key: Data) -> Data {
        let padLen = UInt8(Int.random(in: 0...maxPadding))
        let padding = Data((0..<Int(padLen)).map { _ in UInt8.random(in: 0...255) })
        let padded = padding + data + Data([padLen])
        let obf = Data(padded.enumerated().map { idx, b in b ^ key[idx % key.count] })
        let lenPrefix = UInt16(obf.count).toBytes()
        return lenPrefix + obf
    }
    
    // MARK: - 数据反混淆
    /// 还原XOR混淆数据，去除填充
    func xorDeobfuscate(data: Data, key: Data) -> Data {
        let deobf = Data(data.enumerated().map { idx, b in b ^ key[idx % key.count] })
        if deobf.count > 0 {
            let padLen = Int(deobf.last!) // 最后一个字节是填充长度
            if padLen < deobf.count {
                return deobf.subdata(in: padLen..<(deobf.count - 1))
            }
        }
        return deobf
    }
    
    // MARK: - 解析服务器分配的IP
    /// 从服务器响应字符串中提取IP
    func extractIP(from str: String) -> String {
        let arr = str.split(separator: ",").map { String($0) }
        return arr.first ?? ""
    }
    
    // MARK: - 断开连接
    /// 主动断开与服务器的连接
    func disconnect() {
        tunnelConnection?.cancel()
        // 英文日志
        os_log("[VPN] Connection cancelled by user", log: OSLog.default, type: .info)
        // 中文日志
        os_log("[VPN] 用户主动断开连接", log: OSLog.default, type: .info)
    }
    
    // MARK: - 构造认证数据
    /// 构造认证数据并进行AES加密
    func makeAuthPayload() -> Data? {
        let params: [String: Any] = [
            "package": appBundleId,
            "version": version,
            "SDK": "7.0",
            "country": userRegion,
            "language": userLocale,
            "action": "new_connect"
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: params, options: []),
              let key = aesKey.data(using: .utf8) else {
            // 英文日志
            os_log("[VPN] Failed to serialize authentication JSON", log: OSLog.default, type: .error)
            // 中文日志
            os_log("[VPN] 认证JSON序列化失败", log: OSLog.default, type: .error)
            return nil
        }
        return aesEncrypt(data: json, key: key)
    }
    
    // MARK: - AES加密
    /// 使用AES对数据加密
    func aesEncrypt(data: Data, key: Data) -> Data? {
        let plain = [UInt8](data)
        let k = [UInt8](key)
        var out = [UInt8](repeating: 0, count: plain.count + kCCBlockSizeAES128)
        var outLen = 0
        let status = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode), k, key.count, nil, plain, plain.count, &out, out.count, &outLen)
        if status != kCCSuccess {
            // 英文日志
            os_log("[VPN] AES encryption failed, status: %{public}d", log: OSLog.default, type: .error, status)
            // 中文日志
            os_log("[VPN] AES加密失败, 状态码: %{public}d", log: OSLog.default, type: .error, status)
            return nil
        }
        return Data(bytes: out, count: outLen)
    }
}

// MARK: - UInt16扩展
extension UInt16 {
    /// 转换为2字节Data
    func toBytes() -> Data {
        return Data([UInt8(self >> 8), UInt8(self & 0xFF)])
    }
} 