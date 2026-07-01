import XCTest

@MainActor
final class HelperLifecycleControllerTests: XCTestCase {
    func testRefreshRegistrationStoresVersionAfterReachableCheck() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: true, reachable: true)
        let lifecycle = HelperLifecycleController(helper: helper, store: store)

        var repairRequested = false
        lifecycle.refreshRegistrationIfNeeded {
            repairRequested = true
        }

        XCTAssertFalse(repairRequested)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRefreshRegistrationRequestsRepairWithoutStoringWhenUnreachable() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: true, reachable: false)
        let lifecycle = HelperLifecycleController(helper: helper, store: store)

        var repairRequested = false
        lifecycle.refreshRegistrationIfNeeded {
            repairRequested = true
        }

        XCTAssertTrue(repairRequested)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRefreshRegistrationDoesNotStoreWhenHelperIsNotEnabled() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false, reachable: true)
        let lifecycle = HelperLifecycleController(helper: helper, store: store)

        lifecycle.refreshRegistrationIfNeeded {
            XCTFail("Repair should not be requested for an unregistered helper.")
        }

        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testRegisterStoresVersionWhenImmediatelyUsable() throws {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false)
        let lifecycle = HelperLifecycleController(helper: helper, store: store)

        let becameUsable = try lifecycle.register()

        XCTAssertTrue(becameUsable)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRecheckStoresVersionWhenHelperBecomesUsable() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false)
        let lifecycle = HelperLifecycleController(helper: helper, store: store)

        lifecycle.captureUsableBaseline()
        helper.isEnabled = true

        XCTAssertTrue(lifecycle.recheckBecameUsable())
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRepairStoresVersionOnlyAfterSuccessfulUsableRegistration() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: false)
        let lifecycle = HelperLifecycleController(helper: helper, store: store)

        var errorMessage: String?
        lifecycle.repair { errorMessage = $0 }

        XCTAssertNil(errorMessage)
        XCTAssertEqual(store.loadLastHelperVersion(), expectedHelperVersion)
    }

    func testRepairFailureDoesNotStoreVersion() {
        let store = makeStore()
        let helper = FakeHelper(isEnabled: true, reregisterError: "Registration failed")
        let lifecycle = HelperLifecycleController(helper: helper, store: store)

        var errorMessage: String?
        lifecycle.repair { errorMessage = $0 }

        XCTAssertEqual(errorMessage, "Registration failed")
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    func testUnregisterSuccessClearsStoredVersion() {
        let store = makeStore()
        store.saveLastHelperVersion(expectedHelperVersion)
        let helper = FakeHelper(isEnabled: true)
        let lifecycle = HelperLifecycleController(helper: helper, store: store)

        var errorMessage: String?
        lifecycle.unregister { errorMessage = $0 }

        XCTAssertNil(errorMessage)
        XCTAssertEqual(store.loadLastHelperVersion(), "")
    }

    private var expectedHelperVersion: String {
        "helper-\(LidHelperIdentity.helperVersion)"
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
    var reregisterError: String?

    init(isEnabled: Bool,
         requiresApproval: Bool = false,
         reachable: Bool = true,
         reregisterError: String? = nil) {
        self.isEnabled = isEnabled
        self.requiresApproval = requiresApproval
        self.reachable = reachable
        self.reregisterError = reregisterError
    }

    func register() throws {
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
            completion(reregisterError)
            return
        }
        isEnabled = true
        requiresApproval = false
        completion(nil)
    }

    func checkReachable(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        completion(reachable)
    }
}
