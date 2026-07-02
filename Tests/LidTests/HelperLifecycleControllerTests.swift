import XCTest

@MainActor
final class HelperLifecycleControllerTests: XCTestCase {
    func testRefreshStatusDoesNotTreatRegisteredHelperAsUsableUntilReachable() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: true, reachable: true)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        lifecycle.refreshStatus()

        XCTAssertTrue(lifecycle.installed)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 0)
    }

    func testRefreshUsabilityMarksReachableHelperUsable() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: true, reachable: true)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var usable = false
        lifecycle.refreshUsability { usable = $0 }

        XCTAssertTrue(usable)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRefreshUsabilityKeepsUnreachableHelperUnusable() {
        let store = makeStore()
        store.saveLastHelperVersion(expectedHelperVersion)
        let helper = FakeHelper(isEnabled: true, reachable: false)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var usable = true
        lifecycle.refreshUsability { usable = $0 }

        XCTAssertFalse(usable)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRefreshUsabilityRetriesUntilHelperBecomesReachable() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: true, reachableResponses: [false, true])
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var usable = false
        lifecycle.refreshUsability(maxAttempts: 2, retryDelay: 0) { usable = $0 }

        XCTAssertTrue(usable)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 2)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRefreshRegistrationStoresVersionAfterReachableCheck() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: true, reachable: true)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var repairRequested = false
        lifecycle.refreshRegistrationIfNeeded(maxAttempts: 1, retryDelay: 0) {
            repairRequested = true
        }

        XCTAssertFalse(repairRequested)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRefreshRegistrationRequestsRepairWithoutStoringWhenUnreachable() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: true, reachable: false)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var repairRequested = false
        lifecycle.refreshRegistrationIfNeeded(maxAttempts: 1, retryDelay: 0) {
            repairRequested = true
        }

        XCTAssertTrue(repairRequested)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRefreshRegistrationDoesNotStoreWhenHelperIsNotEnabled() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false, reachable: true)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        lifecycle.refreshRegistrationIfNeeded(maxAttempts: 1, retryDelay: 0) {
            XCTFail("Repair should not be requested for an unregistered helper.")
        }

        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRegisterStoresVersionWhenImmediatelyUsable() throws {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var becameUsable = false
        var errorMessage: String?
        lifecycle.register(maxAttempts: 1, retryDelay: 0) { becameUsable = $0; errorMessage = $1 }

        XCTAssertNil(errorMessage)
        XCTAssertTrue(becameUsable)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRegisterDoesNotStoreVersionWhenRegisteredButUnreachable() throws {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false, reachable: false)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var becameUsable = true
        var errorMessage: String?
        lifecycle.register(maxAttempts: 1, retryDelay: 0) { becameUsable = $0; errorMessage = $1 }

        XCTAssertNil(errorMessage)
        XCTAssertFalse(becameUsable)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRegisterTreatsApprovalRequiredErrorAsPendingState() throws {
        let store = makeStore()
        let helper = FakeHelper(
            isEnabled: false,
            registerError: "Operation not permitted",
            registerRequiresApproval: true
        )
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var becameUsable = true
        var errorMessage: String? = "stale"
        lifecycle.register(maxAttempts: 1, retryDelay: 0) { becameUsable = $0; errorMessage = $1 }

        XCTAssertFalse(becameUsable)
        XCTAssertNil(errorMessage)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertTrue(lifecycle.needsApproval)
        XCTAssertEqual(helper.checkReachableCalls, 0)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRecheckStoresVersionWhenHelperBecomesUsable() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        lifecycle.captureUsableBaseline()
        helper.isEnabled = true

        var becameUsable = false
        lifecycle.recheckBecameUsable { becameUsable = $0 }

        XCTAssertTrue(becameUsable)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRecheckDoesNotBecomeUsableWhenRegisteredHelperIsUnreachable() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false, reachable: false)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        lifecycle.captureUsableBaseline()
        helper.isEnabled = true

        var becameUsable = true
        lifecycle.recheckBecameUsable { becameUsable = $0 }

        XCTAssertFalse(becameUsable)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 1)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRepairStoresVersionOnlyAfterSuccessfulUsableRegistration() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var errorMessage: String?
        lifecycle.repair(maxAttempts: 1, retryDelay: 0) { errorMessage = $0 }

        XCTAssertNil(errorMessage)
        XCTAssertEqual(helper.checkReachableCalls, 1)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRepairRetriesUntilRegisteredHelperBecomesReachable() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false, reachableResponses: [false, true])
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var errorMessage: String?
        lifecycle.repair(maxAttempts: 2, retryDelay: 0) { errorMessage = $0 }

        XCTAssertNil(errorMessage)
        XCTAssertTrue(lifecycle.usingHelper)
        XCTAssertEqual(helper.checkReachableCalls, 2)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRepairRequiresReachableHelperBeforeStoringVersion() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false, reachable: false)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var errorMessage: String?
        lifecycle.repair(maxAttempts: 1, retryDelay: 0) { errorMessage = $0 }

        XCTAssertEqual(errorMessage, "The background helper isn’t responding.")
        XCTAssertEqual(helper.checkReachableCalls, 1)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRepairFailureDoesNotStoreVersion() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: true, reregisterError: "Registration failed")
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var errorMessage: String?
        lifecycle.repair(maxAttempts: 1, retryDelay: 0) { errorMessage = $0 }

        XCTAssertEqual(errorMessage, "Registration failed")
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRepairTreatsApprovalRequiredErrorAsPendingState() {
        let store = makeStore()
        let helper = FakeHelper(
            isEnabled: true,
            reregisterError: "Operation not permitted",
            reregisterRequiresApproval: true
        )
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var errorMessage: String? = "stale"
        lifecycle.repair(maxAttempts: 1, retryDelay: 0) { errorMessage = $0 }

        XCTAssertNil(errorMessage)
        XCTAssertFalse(lifecycle.usingHelper)
        XCTAssertTrue(lifecycle.needsApproval)
        XCTAssertEqual(helper.checkReachableCalls, 0)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testUnregisterSuccessClearsStoredVersion() {
        let store = makeStore()
        store.saveLastHelperVersion(expectedHelperVersion)
        let helper = FakeHelper(isEnabled: true)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        var errorMessage: String?
        lifecycle.unregister { errorMessage = $0 }

        XCTAssertNil(errorMessage)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRefreshRegistrationRechecksWhenFingerprintChanges() {
        let store = makeStore()
        store.saveLastHelperVersion("helper-1|version-old|build-old|cert-old")
        let helper = FakeHelper(isEnabled: true, reachable: true)
        let lifecycle = makeLifecycle(helper: helper, store: store)

        lifecycle.refreshRegistrationIfNeeded(maxAttempts: 1, retryDelay: 0) {
            XCTFail("Reachable helper should update the stored fingerprint without repair.")
        }

        XCTAssertEqual(helper.checkReachableCalls, 1)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    private var expectedHelperVersion: String {
        "helper-\(LidHelperIdentity.helperVersion)|version-test|build-test|cert-test"
    }

    private func makeLifecycle(helper: FakeHelper, store: SettingsStore) -> HelperLifecycleController {
        HelperLifecycleController(helper: helper, store: store) { self.expectedHelperVersion }
    }

    private func makeStore(function: StaticString = #function) -> SettingsStore {
        let suiteName = "lid.test.helper-lifecycle.\(function)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SettingsStore(defaults: defaults)
    }
}

@MainActor
private final class FakeHelper: HelperManaging {
    var isEnabled: Bool
    var requiresApproval: Bool
    var reachable: Bool
    var registerError: String?
    var registerRequiresApproval: Bool
    var reregisterError: String?
    var reregisterRequiresApproval: Bool
    var reachableResponses: [Bool]
    var checkReachableCalls = 0

    init(isEnabled: Bool,
         requiresApproval: Bool = false,
         reachable: Bool = true,
         reachableResponses: [Bool] = [],
         registerError: String? = nil,
         registerRequiresApproval: Bool = false,
         reregisterError: String? = nil,
         reregisterRequiresApproval: Bool = false) {
        self.isEnabled = isEnabled
        self.requiresApproval = requiresApproval
        self.reachable = reachable
        self.reachableResponses = reachableResponses
        self.registerError = registerError
        self.registerRequiresApproval = registerRequiresApproval
        self.reregisterError = reregisterError
        self.reregisterRequiresApproval = reregisterRequiresApproval
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
        isEnabled = false
        requiresApproval = false
        completion(nil)
    }

    func reregister(completion: @escaping @MainActor @Sendable (String?) -> Void) {
        if let reregisterError {
            if reregisterRequiresApproval {
                isEnabled = false
                requiresApproval = true
            }
            completion(reregisterError)
            return
        }
        isEnabled = true
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
