import XCTest

final class SleepRestorePolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testFirstLaunchDoesNotOverrideSystemSetting() {
        var policy = SleepRestorePolicy()
        XCTAssertNil(policy.nextRestore(observed: true, isChanging: false, now: start))
        policy.confirm(true)
        XCTAssertEqual(policy.nextRestore(observed: false, isChanging: false, now: start), true)
    }

    func testRestartRestoresPreviouslyConfirmedOffState() {
        var policy = SleepRestorePolicy(desired: false)
        XCTAssertEqual(policy.nextRestore(observed: true, isChanging: false, now: start), false)
    }

    func testCancelledOrFailedRestoreWaitsTenMinutes() {
        var policy = SleepRestorePolicy(desired: true)
        XCTAssertEqual(policy.nextRestore(observed: false, isChanging: false, now: start), true)
        // Failure/cancellation must not confirm the attempted state or clear cooldown.
        policy.observe(false)
        XCTAssertNil(policy.nextRestore(observed: false, isChanging: false, now: start.addingTimeInterval(30)))
        XCTAssertNil(policy.nextRestore(observed: false, isChanging: false, now: start.addingTimeInterval(599)))
        XCTAssertEqual(policy.nextRestore(observed: false, isChanging: false, now: start.addingTimeInterval(600)), true)
    }

    func testSuccessfulManualChangeReplacesOldRestoreTarget() {
        var policy = SleepRestorePolicy(desired: true)
        _ = policy.nextRestore(observed: false, isChanging: false, now: start)
        policy.confirm(false)
        XCTAssertNil(policy.nextRestore(observed: false, isChanging: false, now: start))
        XCTAssertEqual(policy.nextRestore(observed: true, isChanging: false, now: start), false)
    }

    func testMatchingObservationResetsCooldownForNewDrift() {
        var policy = SleepRestorePolicy(desired: true)
        _ = policy.nextRestore(observed: false, isChanging: false, now: start)
        policy.observe(true)
        XCTAssertEqual(policy.nextRestore(observed: false, isChanging: false, now: start.addingTimeInterval(10)), true)
    }

    func testInFlightWriteDoesNotStartRestoreOrConsumeRetry() {
        var policy = SleepRestorePolicy(desired: true)
        XCTAssertNil(policy.nextRestore(observed: false, isChanging: true, now: start))
        XCTAssertEqual(policy.nextRestore(observed: false, isChanging: false, now: start), true)
    }

    func testClockMovingBackwardsDoesNotTriggerImmediateRetry() {
        var policy = SleepRestorePolicy(desired: true)
        _ = policy.nextRestore(observed: false, isChanging: false, now: start)
        XCTAssertNil(policy.nextRestore(observed: false, isChanging: false, now: start.addingTimeInterval(-60)))
    }
}
