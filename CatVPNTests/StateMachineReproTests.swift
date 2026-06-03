import XCTest

// =============================================================================
// Faithful, line-referenced model of MainViewmodel's VPN state machine.
//
// This is NOT a re-imagining — every method below mirrors the real production
// logic so the failing assertions point at real defects. Cross-check against:
//   CatVPN/vm/MainViewModal.swift
//     - updateConnectionStatusIfNeeded()         (lines 187-230)
//     - startConnectivityProbeIfNeeded()         (lines 249-271)
//     - handleProbeVerdict(_:generation:)        (lines 273-297)
//     - beginConnectAttempt / invalidateCurrentProbe (232-247)
//     - connectSuccessful()                      (656-690)
//     - handleConnectionFailure()                (703-725)
//     - startConnectionTimer() / startSpeedTimer()(498-534)
//
// The point of these tests is to reproduce, without a device, what a
// *connection-level ban* (tunnel collapses during the connect/disconnect
// window) does to the app's observable UI state.
// =============================================================================

enum NEStatus { case invalid, disconnected, connecting, connected, reasserting, disconnecting }
enum UIStatus { case disconnected, connecting, connected, failed }

final class VPNStateMachineModel {
    // Mirrors @Published vars that drive the UI
    var state: NEStatus = .disconnected { didSet { if oldValue != state { updateConnectionStatusIfNeeded() } } }
    var connectionStatus: UIStatus = .disconnected
    var showConnecting = false
    var showResult = false
    var resultStatus: UIStatus = .disconnected

    // Private bookkeeping (mirrors MainViewmodel privates)
    private var connectManual = false
    private var isProbingConnection = false
    private var connectGeneration = 0

    // Probe lifecycle modelled explicitly. `probeActive` == a probeTask exists
    // and is not cancelled. `probeCapturedGeneration` == the generation snapshot
    // taken in startConnectivityProbeIfNeeded (line 256).
    private var probeActive = false
    private var probeCapturedGeneration = 0

    // Leak / reset detectors (not in production, used only to assert)
    private(set) var connectionTimerStartCount = 0   // how many times startConnectionTimer ran without invalidate
    private(set) var connectionTimerInvalidateCount = 0
    private(set) var startTimeAssignments = 0          // how many times the elapsed clock was reset to "now"
    var liveConnectionTimers: Int { connectionTimerStartCount - connectionTimerInvalidateCount }

    // Disconnect / deferred-teardown bookkeeping (mirrors the onConfirm flow in
    // VPNMainView.swift lines 111-135 + stopConnect() at MainViewModal 449-463).
    private var pendingStopArmed = false
    private var pendingStopGeneration = 0
    private(set) var tunnelStopRequests = 0   // times stopConnect actually asked the tunnel to stop
    var probeActiveForTest: Bool { probeActive }
    // Toggle to model the production bug (no guard) vs the fix (generation guard).
    var deferredStopHasGenerationGuard = false

    // --- §3-7-A: action dispatch source vs UI render source ---
    enum ButtonIntent { case start, busy, stop }   // what the LABEL promises
    enum TapAction: Equatable { case startConnection, showDisconnect, ignored }

    // mirrors buttonText/statusText (MainViewModal 92-118) — the RENDER source.
    // FIX (§3-7-A): now reads `connectionStatus`, the same source as dispatch.
    var buttonIntent: ButtonIntent {
        switch connectionStatus {
        case .disconnected, .failed: return .start
        case .connecting:            return .busy
        case .connected:             return .stop
        }
    }

    // mirrors handleButtonAction (MainViewModal 489-519) — the DISPATCH source.
    func tapMainButton() -> TapAction {
        switch connectionStatus {                  // <- reads derived `connectionStatus`
        case .disconnected, .failed: return .startConnection
        case .connected:             return .showDisconnect
        default:                     return .ignored
        }
    }

    // The invariant we want: what the label promises == what tapping does.
    var labelMatchesDispatch: Bool {
        switch buttonIntent {
        case .start: return tapMainButton() == .startConnection
        case .stop:  return tapMainButton() == .showDisconnect
        case .busy:  return tapMainButton() == .ignored
        }
    }

    // MARK: prepare() -> beginConnectAttempt() (232-239, 311-313)
    func prepare() {
        connectManual = true
        beginConnectAttempt()
    }

    private func beginConnectAttempt() {
        connectGeneration += 1
        probeActive = false              // probeTask?.cancel()
        isProbingConnection = false
        connectionStatus = .connecting
        showResult = false               // FIX (§3-7-B): clear stale result flag at new-attempt entry
    }

    private func invalidateCurrentProbe() {
        connectGeneration += 1
        probeActive = false
        isProbingConnection = false
    }

    // MARK: updateConnectionStatusIfNeeded() (187-230)
    private func updateConnectionStatusIfNeeded() {
        switch state {
        case .connected:
            if connectManual {
                startConnectivityProbeIfNeeded()
            } else {
                connectManual = false
                connectionStatus = .connected
                startConnectionTimer()
                startSpeedTimer()
            }
        case .disconnected, .invalid:
            if isProbingConnection { invalidateCurrentProbe() }
            connectManual = false
            connectionStatus = .disconnected
            stopConnectionTimer()
            stopSpeedTimer()
            // FIX (Bug #1): disconnected inside the connect window -> failure terminal.
            if showConnecting && !showResult {
                handleConnectionFailure()
            }
        case .connecting:
            connectionStatus = .connecting
        case .disconnecting, .reasserting:
            if isProbingConnection { invalidateCurrentProbe() }
            connectManual = false
            connectionStatus = .connecting   // deliberately kept as .connecting
        }
    }

    // MARK: startConnectivityProbeIfNeeded() (249-271)
    private func startConnectivityProbeIfNeeded() {
        guard !isProbingConnection else { return }
        isProbingConnection = true
        probeActive = true
        probeCapturedGeneration = connectGeneration
    }

    // Simulates the probeTask completing and delivering a verdict.
    // Mirrors the `guard !Task.isCancelled` (260) + handleProbeVerdict (273-297).
    func deliverProbeVerdict(isAlive: Bool) {
        // guard !Task.isCancelled  -> if the probe was cancelled, the closure
        // returns early and NOTHING happens. This is the crux of Bug #1.
        guard probeActive else { return }
        handleProbeVerdict(isAlive: isAlive, generation: probeCapturedGeneration)
    }

    private func handleProbeVerdict(isAlive: Bool, generation: Int) {
        guard generation == connectGeneration else { return }        // 274
        guard state == .connected else { invalidateCurrentProbe(); return } // 279
        isProbingConnection = false
        probeActive = false
        if isAlive {
            connectSuccessful()
        } else {
            handleConnectionFailure()
        }
    }

    // MARK: connectSuccessful() (656-690)
    private func connectSuccessful() {
        guard state == .connected else { return }
        isProbingConnection = false
        connectManual = false
        probeActive = false
        resultStatus = .connected
        connectionStatus = .connected
        startConnectionTimer()
        startSpeedTimer()
        showResult = true
        showConnecting = false
    }

    // MARK: handleConnectionFailure(stopTunnel:reportResult:) (703-725)
    private func handleConnectionFailure() {
        invalidateCurrentProbe()
        connectManual = false
        connectionStatus = .failed
        resultStatus = .failed
        showResult = true
        showConnecting = false
    }

    // MARK: timers (498-540) — reflects the FIX in startConnectionTimer()
    private var hasStartTime = false
    private func startConnectionTimer() {
        // FIX (Bug #2): invalidate any existing timer, and only set the start
        // time when there isn't one (so a reasserting bounce doesn't reset it).
        if liveConnectionTimers > 0 { connectionTimerInvalidateCount = connectionTimerStartCount } // connectionTimer?.invalidate()
        if !hasStartTime {                 // if startTime == nil
            hasStartTime = true
            startTimeAssignments += 1       // startTime = Date()
        }
        connectionTimerStartCount += 1     // connectionTimer = Timer.scheduled...
    }
    private func stopConnectionTimer() {
        if liveConnectionTimers > 0 { connectionTimerInvalidateCount = connectionTimerStartCount }
        hasStartTime = false               // startTime = nil
    }
    private var speedTimerRunning = false
    private func startSpeedTimer() {
        guard !speedTimerRunning else { return }  // production HAS this guard (525)
        speedTimerRunning = true
    }
    private func stopSpeedTimer() { speedTimerRunning = false }

    // MARK: stopConnect() (MainViewModal 449-463)
    func stopConnect() {
        invalidateCurrentProbe()
        stopConnectionTimer()
        stopSpeedTimer()
        connectManual = false
        // manager.stopVpnConnection(): only tears the tunnel down when it is up.
        if state == .connected || state == .connecting || state == .reasserting {
            tunnelStopRequests += 1
        }
    }

    // MARK: disconnect confirm flow (VPNMainView onConfirm, non-rating branch).
    // When an ad is ready, production schedules stopConnect() 3s later via
    // DispatchQueue.main.asyncAfter — with NO generation guard today.
    func requestDisconnect(adReady: Bool) {
        resultStatus = .disconnected
        showResult = true                 // disconnected result page shown immediately
        if adReady {
            pendingStopArmed = true        // scheduled for +3s
            pendingStopGeneration = connectGeneration
        } else {
            stopConnect()
        }
    }

    // Simulates the 3s timer firing.
    func firePendingStopConnect() {
        guard pendingStopArmed else { return }
        pendingStopArmed = false
        // FIX (Bug #3): skip the stale teardown if a new connect attempt has
        // advanced the generation in the meantime. Production today has no such
        // guard, so set `deferredStopHasGenerationGuard = false` to reproduce.
        if deferredStopHasGenerationGuard && pendingStopGeneration != connectGeneration {
            return
        }
        stopConnect()
    }
}

final class StateMachineReproTests: XCTestCase {

    // -------------------------------------------------------------------------
    // BUG #1 — Connection-level ban during the post-connect probe window
    //          leaves the app stuck on the "Connecting…" page forever.
    //
    // Sequence:
    //   1. User taps Start -> showConnecting = true, prepare() (manual connect).
    //   2. System reaches .connected -> connectivity probe starts (up to ~10s).
    //   3. The connection-level ban tears the tunnel down mid-probe:
    //      system goes .disconnecting -> .disconnected.
    //   4. .disconnecting/.disconnected cancels the probe (invalidateCurrentProbe),
    //      so the probe verdict is NEVER delivered (guard !Task.isCancelled).
    //   5. => connectionStatus becomes .disconnected, BUT showConnecting stays
    //         true and showResult stays false. No terminal/result page.
    //
    // After the FIX this is a regression test: the app must reach a failure
    // terminal (showConnecting == false, showResult == true) instead of hanging.
    // -------------------------------------------------------------------------
    func testBug1_BanDuringProbe_reachesFailureTerminal() {
        let vm = VPNStateMachineModel()

        // 1. tap Start
        vm.showConnecting = true
        vm.prepare()

        // 2. system connects -> probe starts
        vm.state = .connecting
        vm.state = .connected

        // 3. connection-level ban collapses the tunnel during the probe
        vm.state = .disconnecting
        vm.state = .disconnected

        // 4. the (cancelled) probe tries to deliver — but it was cancelled
        vm.deliverProbeVerdict(isAlive: false)

        // After the fix the app leaves the Connecting page and shows a terminal:
        XCTAssertFalse(vm.showConnecting,
            "BUG #1 regression: must leave the Connecting page after a ban during the probe")
        XCTAssertTrue(vm.showResult,
            "BUG #1 regression: a terminal/result page must be shown after a ban during the probe")
        XCTAssertEqual(vm.resultStatus, .failed)
    }

    // Guard against the fix over-firing: a NORMAL user-initiated stop *after* a
    // successful connect must NOT pop a failure page. (showConnecting is already
    // false and showResult is already true by then, so the new branch stays off.)
    func testBug1_fix_doesNotFalseTriggerOnNormalStop() {
        let vm = VPNStateMachineModel()
        vm.showConnecting = true
        vm.prepare()
        vm.state = .connecting
        vm.state = .connected
        vm.deliverProbeVerdict(isAlive: true)   // success page shown
        XCTAssertEqual(vm.resultStatus, .connected)

        // user taps Stop -> tunnel tears down
        vm.state = .disconnecting
        vm.state = .disconnected

        XCTAssertEqual(vm.connectionStatus, .disconnected)
        XCTAssertEqual(vm.resultStatus, .connected,
            "Normal stop must NOT be rewritten into a .failed result")
    }

    // -------------------------------------------------------------------------
    // BUG #2 — A reasserting bounce (network churn / partial ban) on an already
    //          connected tunnel leaks a connection timer and resets the elapsed
    //          time to 00:00:00 each time.
    //
    // Sequence:
    //   1. Normal successful connect -> 1 connection timer, 1 start-time set.
    //   2. Network churn: .connected -> .reasserting -> .connected.
    //   3. On the bounce back to .connected, connectManual is false, so the
    //      else-branch runs startConnectionTimer() again — but that method has
    //      no guard / invalidate (unlike startSpeedTimer), so a second timer is
    //      created and startTime is reset.
    // -------------------------------------------------------------------------
    func testBug2_reassertingBounce_leaksTimerAndResetsClock() {
        let vm = VPNStateMachineModel()

        // 1. successful connect
        vm.showConnecting = true
        vm.prepare()
        vm.state = .connecting
        vm.state = .connected
        vm.deliverProbeVerdict(isAlive: true)
        XCTAssertEqual(vm.liveConnectionTimers, 1)
        XCTAssertEqual(vm.startTimeAssignments, 1)

        // 2. one reasserting bounce
        vm.state = .reasserting
        vm.state = .connected

        // Correct behaviour: still exactly one timer, clock not reset.
        XCTAssertEqual(vm.liveConnectionTimers, 1,
            "BUG #2: reasserting bounce leaks a connection timer (no invalidate in startConnectionTimer)")
        XCTAssertEqual(vm.startTimeAssignments, 1,
            "BUG #2: reasserting bounce resets the connection duration clock to 00:00:00")
    }

    // Multiple bounces compound the leak — shows it scales with churn.
    func testBug2_multipleBounces_compoundTheLeak() {
        let vm = VPNStateMachineModel()
        vm.showConnecting = true
        vm.prepare()
        vm.state = .connecting
        vm.state = .connected
        vm.deliverProbeVerdict(isAlive: true)

        for _ in 0..<5 {
            vm.state = .reasserting
            vm.state = .connected
        }

        XCTAssertEqual(vm.liveConnectionTimers, 1,
            "BUG #2: each reasserting bounce leaks another live timer (got \(vm.liveConnectionTimers))")
    }

    // -------------------------------------------------------------------------
    // BUG #3 — "dead IP -> disconnect -> reconnect for a fresh IP" race.
    //
    // User flow (exactly the reported scenario):
    //   1. Connected and in use; the server IP gets permanently banned while the
    //      app is backgrounded.
    //   2. User foregrounds, taps Disconnect. An ad is ready, so production defers
    //      stopConnect() by 3s (VPNMainView onConfirm) and shows the disconnected
    //      page right away — but the tunnel is still up.
    //   3. Because the IP is dead, the packet tunnel self-terminates within those
    //      3s -> system reaches .disconnected -> connectionStatus == .disconnected.
    //   4. User immediately taps Connect to get a fresh IP; a new connect attempt
    //      starts and reaches .connected with its own probe running.
    //   5. The stale 3s timer from step 2 now fires stopConnect() — with no
    //      generation guard it tears down the BRAND-NEW tunnel and cancels its
    //      probe. => state confusion / the fresh connection dies for no reason.
    // -------------------------------------------------------------------------

    /// Drives the full reported sequence and returns the model right after the
    /// stale deferred stopConnect fires during the fresh connection.
    private func runDeadIPReconnectRace(withGuard: Bool) -> VPNStateMachineModel {
        let vm = VPNStateMachineModel()
        vm.deferredStopHasGenerationGuard = withGuard

        // 1-2. connect #1 succeeds (dead IP), user dismisses success page
        vm.showConnecting = true
        vm.prepare(); vm.state = .connecting; vm.state = .connected
        vm.deliverProbeVerdict(isAlive: true)
        vm.showResult = false

        // user taps Disconnect with an ad ready -> stopConnect deferred 3s
        vm.requestDisconnect(adReady: true)

        // 3. dead server: tunnel self-terminates within the 3s window
        vm.state = .disconnecting; vm.state = .disconnected

        // 4. user dismisses the disconnected page and reconnects for a fresh IP
        vm.showResult = false
        vm.showConnecting = true
        vm.prepare(); vm.state = .connecting; vm.state = .connected
        XCTAssertTrue(vm.probeActiveForTest, "precondition: fresh connection's probe is running")

        // 5. the stale 3s timer from the OLD disconnect fires
        vm.firePendingStopConnect()
        return vm
    }

    /// Characterizes CURRENT production (no generation guard): the stale teardown
    /// kills the fresh connection. Documents the defect; passes today.
    func testBug3_characterization_withoutGuard_killsFreshReconnect() {
        let vm = runDeadIPReconnectRace(withGuard: false)
        XCTAssertEqual(vm.tunnelStopRequests, 1,
            "Without a guard, the stale deferred stopConnect tears down the fresh tunnel")
        XCTAssertFalse(vm.probeActiveForTest,
            "Without a guard, the stale deferred stopConnect cancels the fresh probe")
    }

    /// Regression for the FIX: a generation-guarded deferred stop ignores the
    /// stale timer once a new connect attempt has started.
    func testBug3_fix_guardedDeferredStop_leavesFreshReconnectAlone() {
        let vm = runDeadIPReconnectRace(withGuard: true)
        XCTAssertEqual(vm.tunnelStopRequests, 0,
            "BUG #3 regression: stale deferred stopConnect must NOT tear down the fresh tunnel")
        XCTAssertTrue(vm.probeActiveForTest,
            "BUG #3 regression: stale deferred stopConnect must NOT cancel the fresh probe")
    }

    /// The straightforward path (disconnect with no ad delay, then reconnect)
    /// must be clean: generations advance and the fresh probe is honored.
    func testDeadIP_immediateDisconnectThenReconnect_isRobust() {
        let vm = VPNStateMachineModel()
        vm.showConnecting = true
        vm.prepare(); vm.state = .connecting; vm.state = .connected
        vm.deliverProbeVerdict(isAlive: true)
        vm.showResult = false

        // disconnect immediately (no ad) -> tunnel torn down now
        vm.requestDisconnect(adReady: false)
        vm.state = .disconnecting; vm.state = .disconnected
        XCTAssertEqual(vm.connectionStatus, .disconnected)

        // reconnect for a fresh IP
        vm.showResult = false
        vm.showConnecting = true
        vm.prepare(); vm.state = .connecting; vm.state = .connected
        XCTAssertTrue(vm.probeActiveForTest, "fresh connection probe must run")

        // fresh probe succeeds -> connected, no leftover stale teardown
        vm.deliverProbeVerdict(isAlive: true)
        XCTAssertEqual(vm.connectionStatus, .connected)
        XCTAssertTrue(vm.showResult)
        XCTAssertEqual(vm.resultStatus, .connected)
        XCTAssertFalse(vm.showConnecting)
    }

    // -------------------------------------------------------------------------
    // BUG #4 (guideline §3-7-A) — the button LABEL and the tap DISPATCH read
    // different truth sources: buttonText/statusText read `state` (NEVPNStatus),
    // handleButtonAction reads `connectionStatus`. When they diverge, the button
    // says one thing but does another.
    // -------------------------------------------------------------------------

    /// Probe/ad window: system is .connected but connectionStatus is still
    /// .connecting. Label reads "Stop" (from state) yet a tap is ignored.
    func testBug4_labelMatchesDispatch_duringProbeWindow() {
        let vm = VPNStateMachineModel()
        vm.showConnecting = true
        vm.prepare(); vm.state = .connecting; vm.state = .connected
        // precondition: the two sources are in the divergence window
        XCTAssertEqual(vm.state, .connected)
        XCTAssertEqual(vm.connectionStatus, .connecting)
        XCTAssertTrue(vm.labelMatchesDispatch,
            "BUG #4: 探测窗口内标签(读 state→Stop)与点击分发(读 connectionStatus→ignored)背离")
    }

    /// Failed window: probe fails -> connectionStatus == .failed while the system
    /// is momentarily still .connected. Label says "Stop" but a tap would START
    /// a brand-new connection.
    func testBug4_labelMatchesDispatch_failedWhileSystemConnected() {
        let vm = VPNStateMachineModel()
        vm.showConnecting = true
        vm.prepare(); vm.state = .connecting; vm.state = .connected
        vm.deliverProbeVerdict(isAlive: false)     // -> connectionStatus = .failed, state stays .connected
        XCTAssertEqual(vm.state, .connected)
        XCTAssertEqual(vm.connectionStatus, .failed)
        XCTAssertTrue(vm.labelMatchesDispatch,
            "BUG #4: failed 态下标签显示 Stop(读 state) 但点击会 START(读 connectionStatus)")
    }

    /// Sanity: on the steady states the two sources already agree (so the fix
    /// must not regress these).
    func testBug4_labelMatchesDispatch_onSteadyStates() {
        let vm = VPNStateMachineModel()
        XCTAssertTrue(vm.labelMatchesDispatch, "disconnected steady state")
        vm.showConnecting = true
        vm.prepare(); vm.state = .connecting; vm.state = .connected
        vm.deliverProbeVerdict(isAlive: true)       // fully connected
        XCTAssertTrue(vm.labelMatchesDispatch, "connected steady state")
    }

    // -------------------------------------------------------------------------
    // BUG #5 (guideline §3-7-B) — a stale "previous result" flag (showResult)
    // is only cleared by async navigation, not at the synchronous entry of a new
    // connect attempt. If a new attempt starts while it is still set, the new
    // round begins carrying the stale flag (two navigationDestinations active).
    // -------------------------------------------------------------------------
    func testBug5_newConnectAttempt_clearsStaleResultFlag() {
        let vm = VPNStateMachineModel()
        // a previous session left a result page flagged on
        vm.resultStatus = .connected
        vm.showResult = true

        // user starts a new connect attempt
        vm.showConnecting = true
        vm.prepare()   // beginConnectAttempt should clear the stale flag synchronously

        XCTAssertFalse(vm.showResult,
            "BUG #5: 新连接尝试开始时未同步清除上一轮的结果页标志(只靠异步导航清除)")
    }
}
