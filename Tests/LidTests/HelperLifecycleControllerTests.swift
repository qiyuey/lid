import XCTest

@MainActor
final class HelperLifecycleControllerTests: XCTestCase {
    func testRefreshStatusDoesNotTreatRegisteredHelperAsUsableUntilReachable() {
        let helper = FakeHelper(isEnabled: true, reachable: true)
        let lifecycle = makeLifecycle(helper: helper)

        lifecycle.refreshStatus()

        XCTAssertTrue(lifecycle.installed)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 0)
    }

    func testRefreshUsabilityMarksReachableHelperUsable() {
        let helper = FakeHelper(isEnabled: true, reachable: true)
        let lifecycle = makeLifecycle(helper: helper)

        var usable = false
        lifecycle.refreshUsability { usable = $0 }

        XCTAssertTrue(usable)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
    }

    func testRefreshUsabilityKeepsUnreachableHelperUnusable() {
        let helper = FakeHelper(isEnabled: true, reachable: false)
        let lifecycle = makeLifecycle(helper: helper)

        var usable = true
        lifecycle.refreshUsability { usable = $0 }

        XCTAssertFalse(usable)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
    }

    func testRefreshUsabilityRetriesUntilHelperBecomesReachable() {
        let helper = FakeHelper(isEnabled: true, reachableResponses: [false, true])
        let lifecycle = makeLifecycle(helper: helper)

        var usable = false
        lifecycle.refreshUsability(maxAttempts: 2, retryDelay: 0) { usable = $0 }

        XCTAssertTrue(usable)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 2)
    }

    func testRefreshUsabilityDoesNotProbeWhenApprovalRequired() {
        let helper = FakeHelper(isEnabled: false, requiresApproval: true, reachable: true)
        let lifecycle = makeLifecycle(helper: helper)

        var usable = true
        lifecycle.refreshUsability { usable = $0 }

        XCTAssertFalse(usable)
        XCTAssertFalse(lifecycle.installed)
        XCTAssertTrue(lifecycle.needsApproval)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 0)
    }

    func testRegisterMarksImmediatelyUsableHelper() {
        let helper = FakeHelper(isEnabled: false)
        let lifecycle = makeLifecycle(helper: helper)

        var becameUsable = false
        var errorMessage: String?
        lifecycle.register(maxAttempts: 1, retryDelay: 0) {
            becameUsable = $0
            errorMessage = $1
        }

        XCTAssertNil(errorMessage)
        XCTAssertTrue(becameUsable)
        XCTAssertTrue(lifecycle.installed)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
    }

    func testRegisterKeepsRegisteredButUnreachableHelperUnusable() {
        let helper = FakeHelper(isEnabled: false, reachable: false)
        let lifecycle = makeLifecycle(helper: helper)

        var becameUsable = true
        var errorMessage: String?
        lifecycle.register(maxAttempts: 1, retryDelay: 0) {
            becameUsable = $0
            errorMessage = $1
        }

        XCTAssertNil(errorMessage)
        XCTAssertFalse(becameUsable)
        XCTAssertTrue(lifecycle.installed)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
    }

    func testRegisterTreatsApprovalRequiredErrorAsPendingState() {
        let helper = FakeHelper(
            isEnabled: false,
            registerError: "Operation not permitted",
            registerRequiresApproval: true
        )
        let lifecycle = makeLifecycle(helper: helper)

        var becameUsable = true
        var errorMessage: String? = "stale"
        lifecycle.register(maxAttempts: 1, retryDelay: 0) {
            becameUsable = $0
            errorMessage = $1
        }

        XCTAssertFalse(becameUsable)
        XCTAssertNil(errorMessage)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertTrue(lifecycle.needsApproval)
        XCTAssertEqual(helper.checkReachableCalls, 0)
    }

    func testRegisterReportsNonApprovalError() {
        let helper = FakeHelper(isEnabled: false, registerError: "Registration failed")
        let lifecycle = makeLifecycle(helper: helper)

        var becameUsable = true
        var errorMessage: String?
        lifecycle.register(maxAttempts: 1, retryDelay: 0) {
            becameUsable = $0
            errorMessage = $1
        }

        XCTAssertFalse(becameUsable)
        XCTAssertEqual(errorMessage, "Registration failed")
        XCTAssertFalse(lifecycle.installed)
        XCTAssertFalse(lifecycle.needsApproval)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 0)
    }

    func testRecheckReportsWhenHelperBecomesUsable() {
        let helper = FakeHelper(isEnabled: false)
        let lifecycle = makeLifecycle(helper: helper)

        lifecycle.captureUsableBaseline()
        helper.isEnabled = true

        var becameUsable = false
        lifecycle.recheckBecameUsable { becameUsable = $0 }

        XCTAssertTrue(becameUsable)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
    }

    func testRecheckDoesNotBecomeUsableWhenRegisteredHelperIsUnreachable() {
        let helper = FakeHelper(isEnabled: false, reachable: false)
        let lifecycle = makeLifecycle(helper: helper)

        lifecycle.captureUsableBaseline()
        helper.isEnabled = true

        var becameUsable = true
        lifecycle.recheckBecameUsable { becameUsable = $0 }

        XCTAssertFalse(becameUsable)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
    }

    func testRecheckRetriesUntilRegisteredHelperBecomesReachable() {
        let helper = FakeHelper(isEnabled: false, reachableResponses: [false, true])
        let lifecycle = makeLifecycle(helper: helper)

        lifecycle.captureUsableBaseline()
        helper.isEnabled = true

        var becameUsable = false
        lifecycle.recheckBecameUsable(maxAttempts: 2, retryDelay: 0) {
            becameUsable = $0
        }

        XCTAssertTrue(becameUsable)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 2)
    }

    func testRecheckDoesNotReportTransitionWhenAlreadyUsable() {
        let helper = FakeHelper(isEnabled: true)
        let lifecycle = makeLifecycle(helper: helper)

        lifecycle.refreshUsability { _ in }
        lifecycle.captureUsableBaseline()

        var becameUsable = true
        lifecycle.recheckBecameUsable { becameUsable = $0 }

        XCTAssertFalse(becameUsable)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 2)
    }

    func testUnregisterSuccessResetsInstalledAndUsingState() {
        let helper = FakeHelper(isEnabled: false)
        let lifecycle = makeLifecycle(helper: helper)

        lifecycle.register(maxAttempts: 1, retryDelay: 0) { _, _ in }
        XCTAssertTrue(lifecycle.usingHelper)

        var errorMessage: String?
        lifecycle.unregister { errorMessage = $0 }

        XCTAssertNil(errorMessage)
        XCTAssertFalse(lifecycle.installed)
        XCTAssertFalse(lifecycle.needsApproval)
        XCTAssertFalse(lifecycle.usingHelper)
    }

    func testUnregisterFailureKeepsInstalledStatus() {
        let helper = FakeHelper(isEnabled: true, unregisterError: "Unregister failed")
        let lifecycle = makeLifecycle(helper: helper)

        lifecycle.refreshStatus()

        var errorMessage: String?
        lifecycle.unregister { errorMessage = $0 }

        XCTAssertEqual(errorMessage, "Unregister failed")
        XCTAssertTrue(lifecycle.installed)
    }

    private func makeLifecycle(helper: FakeHelper) -> HelperLifecycleController {
        HelperLifecycleController(helper: helper)
    }
}

@MainActor
private final class FakeHelper: HelperManaging {
    var isEnabled: Bool
    var requiresApproval: Bool
    var reachable: Bool
    var registerError: String?
    var registerRequiresApproval: Bool
    var unregisterError: String?
    var reachableResponses: [Bool]
    var checkReachableCalls = 0

    init(isEnabled: Bool,
         requiresApproval: Bool = false,
         reachable: Bool = true,
         reachableResponses: [Bool] = [],
         registerError: String? = nil,
         registerRequiresApproval: Bool = false,
         unregisterError: String? = nil) {
        self.isEnabled = isEnabled
        self.requiresApproval = requiresApproval
        self.reachable = reachable
        self.reachableResponses = reachableResponses
        self.registerError = registerError
        self.registerRequiresApproval = registerRequiresApproval
        self.unregisterError = unregisterError
    }

    func register() throws {
        if let registerError {
            if registerRequiresApproval {
                isEnabled = false
                requiresApproval = true
            }
            throw FakeHelperError(message: registerError)
        }
        isEnabled = true
        requiresApproval = false
    }

    func unregister(completion: @escaping @MainActor @Sendable (String?) -> Void) {
        if let unregisterError {
            completion(unregisterError)
            return
        }
        isEnabled = false
        requiresApproval = false
        completion(nil)
    }

    func checkReachable(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        checkReachableCalls += 1
        if !reachableResponses.isEmpty {
            completion(reachableResponses.removeFirst())
        } else {
            completion(reachable)
        }
    }
}

private struct FakeHelperError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}
