import XCTest
// ConnectivityProber.swift (the real app source at CatVPN/utils/) is compiled
// directly into this logic-test target, so its internal types are visible here
// without importing/hosting the full app module.

/// Scriptable transport so we can simulate connection-level bans without real sockets.
/// `outcomeFor` decides what each probe to a given host returns, and `delay` lets us
/// emulate slow RST / blackhole timing.
final class MockTransport: ProbeTransport {
    let outcomeFor: (ProbeTarget) -> ProbeOutcome
    let delay: TimeInterval
    private let lock = NSLock()
    private(set) var probeCount = 0
    private(set) var probedHosts: [String] = []

    init(delay: TimeInterval = 0, outcomeFor: @escaping (ProbeTarget) -> ProbeOutcome) {
        self.delay = delay
        self.outcomeFor = outcomeFor
    }

    func probe(_ target: ProbeTarget, timeout: TimeInterval) async -> ProbeOutcome {
        lock.lock(); probeCount += 1; probedHosts.append(target.host); lock.unlock()
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return outcomeFor(target)
    }
}

final class ConnectivityProberTests: XCTestCase {

    private func targets(_ hosts: [String]) -> [ProbeTarget] {
        hosts.map { ProbeTarget(host: $0, port: 80, path: "/generate_204", useTLS: false) }
    }

    /// Fast timing so the whole suite runs in a few seconds.
    private func makeProber(targets: [ProbeTarget], transport: ProbeTransport, maxProbes: Int = 12) -> ConnectivityProber {
        ConnectivityProber(
            targets: targets,
            transport: transport,
            totalBudget: 1.0,
            initialFanOut: 3,
            hedgeInterval: 0.2,
            tailMargin: 0.3,
            maxProbes: maxProbes
        )
    }

    // MARK: - Connection-level ban scenarios (IP reachable, connection killed)

    /// Classic GFW-style RST injection on every probe: TCP resets, host not dead.
    func testAllResetsReportsUnreachable() async {
        let transport = MockTransport { _ in .reset }
        let verdict = await makeProber(targets: targets(["a.com", "b.com", "c.com"]), transport: transport).verify()
        XCTAssertFalse(verdict.isAlive, "All-reset (connection ban) must NOT be reported as alive")
        XCTAssertEqual(verdict.reason, .unreachable)
    }

    /// Silent drop / blackhole: SYN gets no answer, probe times out.
    func testAllBlackholeReportsServerBlackhole() async {
        let transport = MockTransport { _ in .blackhole }
        let verdict = await makeProber(targets: targets(["a.com", "b.com", "c.com"]), transport: transport).verify()
        XCTAssertFalse(verdict.isAlive)
        XCTAssertEqual(verdict.reason, .likelyServerBlackhole,
                       "Pure blackhole should be classified as likely server blackhole, not generic unreachable")
    }

    /// Connection refused on every probe.
    func testAllConnectFailedReportsUnreachable() async {
        let transport = MockTransport { _ in .connectFailed }
        let verdict = await makeProber(targets: targets(["a.com", "b.com", "c.com"]), transport: transport).verify()
        XCTAssertFalse(verdict.isAlive)
        XCTAssertEqual(verdict.reason, .unreachable)
    }

    /// Mixed reset + blackhole: any non-blackhole failure should win the reason.
    func testMixedResetAndBlackholeReportsUnreachable() async {
        let transport = MockTransport { t in t.host == "a.com" ? .reset : .blackhole }
        let verdict = await makeProber(targets: targets(["a.com", "b.com", "c.com"]), transport: transport).verify()
        XCTAssertFalse(verdict.isAlive)
        XCTAssertEqual(verdict.reason, .unreachable)
    }

    // MARK: - Must NOT false-positive when the tunnel actually works

    /// Even if some targets are banned, a single real success must report alive,
    /// otherwise the app would tear down a perfectly working VPN.
    func testOneSuccessAmongBansReportsAlive() async {
        let transport = MockTransport(delay: 0.05) { t in t.host == "good.com" ? .firstByte : .reset }
        let verdict = await makeProber(targets: targets(["bad1.com", "bad2.com", "good.com"]), transport: transport).verify()
        XCTAssertTrue(verdict.isAlive, "A genuine success must override banned targets")
        XCTAssertEqual(verdict.reason, .alive)
    }

    /// A clean all-good connection.
    func testAllValidReportsAlive() async {
        let transport = MockTransport(delay: 0.05) { _ in .firstByte }
        let verdict = await makeProber(targets: targets(["a.com", "b.com"]), transport: transport).verify()
        XCTAssertTrue(verdict.isAlive)
        XCTAssertEqual(verdict.reason, .alive)
    }

    // MARK: - Termination / robustness

    /// The prober must always terminate within roughly the total budget, even when
    /// every probe is an instant reset (worst case for the relaunch loop).
    func testTerminatesUnderBudgetOnInstantResetStorm() async {
        let transport = MockTransport { _ in .reset }
        let start = Date()
        let verdict = await makeProber(targets: targets(["a.com"]), transport: transport, maxProbes: 40).verify()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertFalse(verdict.isAlive)
        XCTAssertLessThan(elapsed, 3.0, "verify() should not hang on an instant-reset storm")
    }

    /// Empty target list is a degenerate config that must fail closed, not crash.
    func testEmptyTargetsReportsUnreachable() async {
        let transport = MockTransport { _ in .firstByte }
        let verdict = await makeProber(targets: [], transport: transport).verify()
        XCTAssertFalse(verdict.isAlive)
        XCTAssertEqual(verdict.reason, .unreachable)
    }

    /// Probe count must be bounded by maxProbes even under a reset storm.
    func testRespectsMaxProbesCeiling() async {
        let transport = MockTransport { _ in .reset }
        _ = await makeProber(targets: targets(["a.com"]), transport: transport, maxProbes: 8).verify()
        XCTAssertLessThanOrEqual(transport.probeCount, 8, "Should never launch more than maxProbes probes")
    }
}
