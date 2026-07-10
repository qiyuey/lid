import XCTest

final class SharedLogicTests: XCTestCase {

    // MARK: PowerParsers.sleepDisabledValue

    func testSleepDisabledTrue() {
        let out = """
        System-wide power settings:
         SleepDisabled        1
        Currently in use:
         standby              1
        """
        XCTAssertEqual(PowerParsers.sleepDisabledValue(pmsetG: out), true)
    }

    func testSleepDisabledFalse() {
        let out = """
        System-wide power settings:
         SleepDisabled        0
        """
        XCTAssertEqual(PowerParsers.sleepDisabledValue(pmsetG: out), false)
    }

    func testSleepDisabledMissing() {
        XCTAssertNil(PowerParsers.sleepDisabledValue(pmsetG: "Currently in use:\n standby 1"))
    }

    func testSleepDisabledRejectsUnrecognizedValue() {
        let ioreg = """
            "AppleClamshellCausesSleep" = No
            "SleepDisabled" = No
        """

        XCTAssertNil(PowerParsers.sleepDisabledValue(pmsetG: ioreg))
        XCTAssertNil(PowerParsers.sleepDisabledValue(pmsetG: "SleepDisabled unknown"))
    }

    func testSleepDisabledRejectsDuplicateValues() {
        XCTAssertNil(PowerParsers.sleepDisabledValue(pmsetG: "SleepDisabled 1\nSleepDisabled 1"))
    }

    // MARK: PowerController

    func testPowerControllerAdminScriptEnablesSleepPrevention() {
        XCTAssertEqual(
            PowerController.adminScript(enabled: true),
            "do shell script \"/usr/bin/pmset -a disablesleep 1\" with administrator privileges"
        )
    }

    func testPowerControllerAdminScriptDisablesSleepPrevention() {
        XCTAssertEqual(
            PowerController.adminScript(enabled: false),
            "do shell script \"/usr/bin/pmset -a disablesleep 0\" with administrator privileges"
        )
    }

    func testPowerControllerReadsExplicitState() throws {
        let runner = StubProcessRunner([
            Self.result(stdout: "SleepDisabled 1\n")
        ])

        XCTAssertTrue(try PowerController(runner: runner).isSleepPreventionEnabled())
    }

    func testPowerControllerRejectsUnreadableState() {
        let runner = StubProcessRunner([
            Self.result(stdout: "Currently in use:\n standby 1\n")
        ])

        XCTAssertThrowsError(try PowerController(runner: runner).isSleepPreventionEnabled()) { error in
            guard case PowerControllerError.readFailed = error else {
                return XCTFail("Expected readFailed, got \(error)")
            }
        }
    }

    func testPowerControllerReportsReadCommandFailure() {
        let runner = StubProcessRunner([
            Self.result(exitCode: 1, stderr: "pmset failed")
        ])

        XCTAssertThrowsError(try PowerController(runner: runner).isSleepPreventionEnabled()) { error in
            XCTAssertEqual(error as? PowerControllerError, .readFailed("pmset failed"))
        }
    }

    func testPowerControllerSetsAndVerifiesState() throws {
        let runner = StubProcessRunner([
            Self.result(),
            Self.result(stdout: "SleepDisabled 1\n")
        ])

        try PowerController(runner: runner).setSleepPrevention(true)
        XCTAssertEqual(
            runner.invocations.map { $0.path },
            ["/usr/bin/osascript", "/usr/bin/pmset"]
        )
    }

    func testPowerControllerRejectsStateMismatch() {
        let runner = StubProcessRunner([
            Self.result(),
            Self.result(stdout: "SleepDisabled 0\n")
        ])

        XCTAssertThrowsError(try PowerController(runner: runner).setSleepPrevention(true)) { error in
            XCTAssertEqual(
                error as? PowerControllerError,
                .verificationFailed(target: true, actual: false)
            )
        }
    }

    func testPowerControllerRejectsUnreadableVerification() {
        let runner = StubProcessRunner([
            Self.result(),
            Self.result(stdout: "Currently in use:\n standby 1\n")
        ])

        XCTAssertThrowsError(try PowerController(runner: runner).setSleepPrevention(false)) { error in
            guard case PowerControllerError.readFailed = error else {
                return XCTFail("Expected readFailed, got \(error)")
            }
        }
    }

    func testPowerControllerReportsAuthorizationCancellation() {
        let runner = StubProcessRunner([
            Self.result(exitCode: 1, stderr: "User canceled.")
        ])

        XCTAssertThrowsError(try PowerController(runner: runner).setSleepPrevention(true)) { error in
            XCTAssertEqual(error as? PowerControllerError, .commandFailed("User canceled."))
        }
    }

    func testPowerControllerReportsCommandTimeout() {
        let runner = StubProcessRunner([
            Self.result(exitCode: -1, timedOut: true)
        ])

        XCTAssertThrowsError(try PowerController(runner: runner).setSleepPrevention(true)) { error in
            XCTAssertEqual(error as? PowerControllerError, .commandFailed("The command timed out."))
        }
    }

    // MARK: ProcessRunner

    func testProcessRunnerCapturesStdout() {
        let out = ProcessRunner.capture("/bin/echo", ["hello"])
        XCTAssertEqual(out, "hello\n")
    }

    func testProcessRunnerReportsNonZeroExit() {
        let result = ProcessRunner.run("/bin/sh", ["-c", "echo nope >&2; exit 7"])
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.exitCode, 7)
        XCTAssertTrue(result.stderr.contains("nope"))
    }

    func testProcessRunnerTimesOut() {
        let result = ProcessRunner.run("/bin/sh", ["-c", "sleep 2"], timeout: 0.1)
        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(result.timedOut)
    }

    // MARK: SettingsStore onboarding flag

    func testOnboardingDefaultsToIncomplete() {
        let defaults = UserDefaults(suiteName: "lid.test.onboarding.default")!
        defaults.removePersistentDomain(forName: "lid.test.onboarding.default")
        let store = SettingsStore(defaults: defaults)
        XCTAssertFalse(store.loadOnboardingComplete())
    }

    func testOnboardingCompletePersists() {
        let defaults = UserDefaults(suiteName: "lid.test.onboarding.persist")!
        defaults.removePersistentDomain(forName: "lid.test.onboarding.persist")
        let store = SettingsStore(defaults: defaults)
        store.saveOnboardingComplete(true)
        XCTAssertTrue(SettingsStore(defaults: defaults).loadOnboardingComplete())
    }

    func testLanguagePreferencePersists() {
        let defaults = UserDefaults(suiteName: "lid.test.language.persist")!
        defaults.removePersistentDomain(forName: "lid.test.language.persist")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.loadLanguagePreference(), "")
        store.saveLanguagePreference("chinese")
        XCTAssertEqual(SettingsStore(defaults: defaults).loadLanguagePreference(), "chinese")
    }

    func testDesiredSleepPreventionStatePersists() {
        let defaults = UserDefaults(suiteName: "lid.test.desired-state.persist")!
        defaults.removePersistentDomain(forName: "lid.test.desired-state.persist")
        let store = SettingsStore(defaults: defaults)
        XCTAssertNil(store.loadDesiredSleepPreventionEnabled())
        store.saveDesiredSleepPreventionEnabled(true)
        XCTAssertEqual(SettingsStore(defaults: defaults).loadDesiredSleepPreventionEnabled(), true)
        store.saveDesiredSleepPreventionEnabled(false)
        XCTAssertEqual(SettingsStore(defaults: defaults).loadDesiredSleepPreventionEnabled(), false)
    }
}

private extension SharedLogicTests {
    static func result(
        exitCode: Int32 = 0,
        stdout: String = "",
        stderr: String = "",
        timedOut: Bool = false
    ) -> ProcessRunResult {
        ProcessRunResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            timedOut: timedOut
        )
    }
}

private final class StubProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Invocation: Equatable {
        let path: String
        let arguments: [String]
        let timeout: TimeInterval
    }

    private let lock = NSLock()
    private var results: [ProcessRunResult]
    private var recordedInvocations: [Invocation] = []

    init(_ results: [ProcessRunResult]) {
        self.results = results
    }

    var invocations: [Invocation] {
        lock.withLock { recordedInvocations }
    }

    func run(_ path: String, _ arguments: [String], timeout: TimeInterval) -> ProcessRunResult {
        lock.withLock {
            recordedInvocations.append(Invocation(path: path, arguments: arguments, timeout: timeout))
            guard !results.isEmpty else {
                return ProcessRunResult(
                    exitCode: -1,
                    stdout: "",
                    stderr: "No stubbed result available.",
                    timedOut: false
                )
            }
            return results.removeFirst()
        }
    }
}
