import Foundation
import Network

struct ProbeTarget: Hashable {
    let host: String
    let port: UInt16
    let path: String
    let useTLS: Bool
    
    static let defaultTargets: [ProbeTarget] = [
        ProbeTarget(host: "www.google.com", port: 80, path: "/generate_204", useTLS: false),
        ProbeTarget(host: "connectivitycheck.gstatic.com", port: 80, path: "/generate_204", useTLS: false),
        ProbeTarget(host: "cp.cloudflare.com", port: 80, path: "/generate_204", useTLS: false),
        ProbeTarget(host: "captive.apple.com", port: 80, path: "/hotspot-detect.html", useTLS: false),
        ProbeTarget(host: "www.msftconnecttest.com", port: 80, path: "/connecttest.txt", useTLS: false),
        ProbeTarget(host: "detectportal.firefox.com", port: 80, path: "/success.txt", useTLS: false)
    ]
    
    init(host: String, port: UInt16, path: String, useTLS: Bool) {
        self.host = host
        self.port = port
        self.path = path
        self.useTLS = useTLS
    }
    
    init?(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let normalized = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let components = URLComponents(string: normalized),
              let host = components.host,
              !host.isEmpty else {
            return nil
        }
        
        let scheme = components.scheme?.lowercased()
        let useTLS = scheme == "https"
        let defaultPort: UInt16 = useTLS ? 443 : 80
        let port = components.port.flatMap { UInt16(exactly: $0) } ?? defaultPort
        var path = components.path.isEmpty ? "/" : components.path
        if let query = components.query, !query.isEmpty {
            path += "?\(query)"
        }
        
        self.init(host: host, port: port, path: path, useTLS: useTLS)
    }
}

enum ProbeOutcome: String {
    case firstByte
    case reset
    case blackhole
    case connectFailed
}

enum ProbeVerdictReason: String {
    case alive
    case unreachable
    case likelyServerBlackhole
}

struct ProbeVerdict {
    let isAlive: Bool
    let reason: ProbeVerdictReason
}

protocol ProbeTransport {
    func probe(_ target: ProbeTarget, timeout: TimeInterval) async -> ProbeOutcome
}

final class NWProbeTransport: ProbeTransport {
    func probe(_ target: ProbeTarget, timeout: TimeInterval) async -> ProbeOutcome {
        let state = SingleProbeState()
        
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                state.start(target: target, timeout: timeout, continuation: continuation)
            }
        } onCancel: {
            state.cancel()
        }
    }
}

private final class SingleProbeState {
    private let lock = NSLock()
    private var connection: NWConnection?
    private var continuation: CheckedContinuation<ProbeOutcome, Never>?
    private var timeoutWorkItem: DispatchWorkItem?
    private var finished = false
    
    func start(target: ProbeTarget, timeout: TimeInterval, continuation: CheckedContinuation<ProbeOutcome, Never>) {
        let port = NWEndpoint.Port(rawValue: target.port) ?? .http
        let parameters = target.useTLS ? NWParameters.tls : NWParameters.tcp
        let connection = NWConnection(host: NWEndpoint.Host(target.host), port: port, using: parameters)
        let request = Self.httpRequest(for: target)
        let workItem = DispatchWorkItem { [weak self] in
            self?.finish(.blackhole)
        }
        
        lock.lock()
        if finished {
            // 取消发生在 start 之前：cancel() 已把 finished 置位，但当时还没有
            // continuation 可恢复。此处必须直接收尾（恰好一个结局），且不启动连接、
            // 不安排超时，避免悬挂的 continuation 拖住外层 task group 的 drain。
            lock.unlock()
            continuation.resume(returning: .blackhole)
            return
        }
        self.connection = connection
        self.continuation = continuation
        self.timeoutWorkItem = workItem
        lock.unlock()
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                connection.send(content: request, completion: .contentProcessed { error in
                    if let error = error {
                        self?.finish(Self.classify(error))
                        return
                    }
                    self?.receiveFirstByte(on: connection)
                })
            case .failed(let error):
                self?.finish(Self.classify(error))
            case .cancelled:
                self?.finish(.blackhole)
            default:
                break
            }
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + max(0.1, timeout), execute: workItem)
        connection.start(queue: .global())
    }
    
    func cancel() {
        finish(.blackhole)
    }
    
    private func receiveFirstByte(on connection: NWConnection) {
        // 设计：隧道内开的新连接只要收到任意一个回程字节，就证明
        // 本地→隧道加密→落地→目标→回程解密 整条链路是通的，即判活。
        // 不校验 HTTP 语义/状态码，避免目标返回 3xx/4xx/5xx 或分包导致的假阴性，
        // 并保留对 A 类（按连接命中）黑洞的逃逸能力。
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] data, _, _, error in
            if let data = data, !data.isEmpty {
                self?.finish(.firstByte)
                return
            }
            if let error = error {
                self?.finish(Self.classify(error))
                return
            }
            self?.finish(.connectFailed)
        }
    }
    
    private func finish(_ outcome: ProbeOutcome) {
        var continuationToResume: CheckedContinuation<ProbeOutcome, Never>?
        var connectionToCancel: NWConnection?
        var timeoutToCancel: DispatchWorkItem?
        
        lock.lock()
        if !finished {
            finished = true
            continuationToResume = continuation
            connectionToCancel = connection
            timeoutToCancel = timeoutWorkItem
            continuation = nil
            connection = nil
            timeoutWorkItem = nil
        }
        lock.unlock()
        
        timeoutToCancel?.cancel()
        connectionToCancel?.stateUpdateHandler = nil
        connectionToCancel?.cancel()
        continuationToResume?.resume(returning: outcome)
    }
    
    private static func httpRequest(for target: ProbeTarget) -> Data {
        let request = "GET \(target.path) HTTP/1.0\r\nHost: \(target.host)\r\nConnection: close\r\n\r\n"
        return Data(request.utf8)
    }
    
    private static func classify(_ error: NWError) -> ProbeOutcome {
        switch error {
        case .posix(let code) where code == .ECONNRESET:
            return .reset
        case .tls:
            return .reset
        default:
            return .connectFailed
        }
    }
}

final class ConnectivityProber {
    private enum Event {
        case outcome(ProbeOutcome)
        case hedge
        case cutoff
        case deadline
    }
    
    private let targets: [ProbeTarget]
    private let transport: ProbeTransport
    private let totalBudget: TimeInterval
    private let initialFanOut: Int
    private let hedgeInterval: TimeInterval
    private let tailMargin: TimeInterval
    private let maxProbes: Int
    
    init(
        targets: [ProbeTarget] = ProbeTarget.defaultTargets,
        transport: ProbeTransport = NWProbeTransport(),
        totalBudget: TimeInterval = 10,
        initialFanOut: Int = 3,
        hedgeInterval: TimeInterval = 1.5,
        tailMargin: TimeInterval = 2,
        maxProbes: Int = 40
    ) {
        self.targets = targets
        self.transport = transport
        self.totalBudget = totalBudget
        self.initialFanOut = initialFanOut
        self.hedgeInterval = hedgeInterval
        self.tailMargin = tailMargin
        self.maxProbes = maxProbes
    }
    
    func verify() async -> ProbeVerdict {
        guard !targets.isEmpty else {
            return ProbeVerdict(isAlive: false, reason: .unreachable)
        }
        
        let deadline = Date().addingTimeInterval(totalBudget)
        let cutoffDelay = max(0, totalBudget - tailMargin)
        var nextTargetIndex = 0
        var launchedProbes = 0
        var launchingAllowed = true
        var sawNonBlackholeFailure = false
        
        return await withTaskGroup(of: Event.self) { group in
            func remainingBudget() -> TimeInterval {
                max(0.1, deadline.timeIntervalSinceNow)
            }
            
            func launchProbe() {
                guard launchedProbes < maxProbes, !targets.isEmpty else { return }
                let target = targets[nextTargetIndex % targets.count]
                nextTargetIndex += 1
                launchedProbes += 1
                let timeout = remainingBudget()
                group.addTask {
                    let outcome = await self.transport.probe(target, timeout: timeout)
                    return .outcome(outcome)
                }
            }
            
            func scheduleHedge() {
                group.addTask {
                    await Self.sleep(seconds: self.hedgeInterval)
                    return .hedge
                }
            }
            
            for _ in 0..<min(initialFanOut, maxProbes) {
                launchProbe()
            }
            scheduleHedge()
            
            group.addTask {
                await Self.sleep(seconds: cutoffDelay)
                return .cutoff
            }
            group.addTask {
                await Self.sleep(seconds: self.totalBudget)
                return .deadline
            }
            
            while let event = await group.next() {
                switch event {
                case .outcome(.firstByte):
                    group.cancelAll()
                    return ProbeVerdict(isAlive: true, reason: .alive)
                case .outcome(.reset), .outcome(.connectFailed):
                    sawNonBlackholeFailure = true
                    if launchingAllowed {
                        launchProbe()
                    }
                case .outcome(.blackhole):
                    break
                case .hedge:
                    if launchingAllowed {
                        launchProbe()
                        if launchedProbes < maxProbes {
                            scheduleHedge()
                        }
                    }
                case .cutoff:
                    launchingAllowed = false
                case .deadline:
                    group.cancelAll()
                    let reason: ProbeVerdictReason = sawNonBlackholeFailure ? .unreachable : .likelyServerBlackhole
                    return ProbeVerdict(isAlive: false, reason: reason)
                }
            }
            
            let reason: ProbeVerdictReason = sawNonBlackholeFailure ? .unreachable : .likelyServerBlackhole
            return ProbeVerdict(isAlive: false, reason: reason)
        }
    }
    
    private static func sleep(seconds: TimeInterval) async {
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}
