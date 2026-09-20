import XCTest

@MainActor
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

    func testPowerControllerReadsExplicitState() async throws {
        let runner = StubProcessRunner([
            Self.result(stdout: "SleepDisabled 1\n")
        ])

        let enabled = try await PowerController(runner: runner).isSleepPreventionEnabled()
        XCTAssertTrue(enabled)
    }

    func testPowerControllerRejectsUnreadableState() async throws {
        let runner = StubProcessRunner([
            Self.result(stdout: "Currently in use:\n standby 1\n")
        ])

        await assertThrows({ try await PowerController(runner: runner).isSleepPreventionEnabled() }) { error in
            guard case PowerControllerError.readFailed = error else {
                return XCTFail("Expected readFailed, got \(error)")
            }
        }
    }

    func testPowerControllerReportsReadCommandFailure() async throws {
        let runner = StubProcessRunner([
            Self.result(exitCode: 1, stderr: "pmset failed")
        ])

        await assertThrows({ try await PowerController(runner: runner).isSleepPreventionEnabled() }) { error in
            XCTAssertEqual(error as? PowerControllerError, .readFailed("pmset failed"))
        }
    }

    func testPowerControllerSetsAndVerifiesState() async throws {
        let runner = StubProcessRunner([
            Self.result(),
            Self.result(stdout: "SleepDisabled 1\n")
        ])

        try await PowerController(runner: runner).setSleepPrevention(true)
        XCTAssertEqual(
            runner.invocations.map { $0.path },
            ["/usr/bin/osascript", "/usr/bin/pmset"]
        )
        XCTAssertEqual(runner.invocations.map { $0.timeout }, [120, 5])
    }

    func testPowerControllerRejectsStateMismatch() async throws {
        let runner = StubProcessRunner([
            Self.result(),
            Self.result(stdout: "SleepDisabled 0\n")
        ])

        await assertThrows({ try await PowerController(runner: runner).setSleepPrevention(true) }) { error in
            XCTAssertEqual(
                error as? PowerControllerError,
                .verificationFailed(target: true, actual: false)
            )
        }
    }

    func testPowerControllerRejectsUnreadableVerification() async throws {
        let runner = StubProcessRunner([
            Self.result(),
            Self.result(stdout: "Currently in use:\n standby 1\n")
        ])

        await assertThrows({ try await PowerController(runner: runner).setSleepPrevention(false) }) { error in
            guard case PowerControllerError.readFailed = error else {
                return XCTFail("Expected readFailed, got \(error)")
            }
        }
    }

    func testPowerControllerReportsAuthorizationCancellation() async throws {
        let runner = StubProcessRunner([
            Self.result(exitCode: 1, stderr: "User canceled.")
        ])

        await assertThrows({ try await PowerController(runner: runner).setSleepPrevention(true) }) { error in
            XCTAssertEqual(error as? PowerControllerError, .commandFailed("User canceled."))
        }
    }

    func testPowerControllerReportsCommandTimeout() async throws {
        let runner = StubProcessRunner([
            Self.result(exitCode: -1, timedOut: true)
        ])

        await assertThrows({ try await PowerController(runner: runner).setSleepPrevention(true) }) { error in
            XCTAssertEqual(error as? PowerControllerError, .commandFailed("The command timed out."))
        }
    }

    // MARK: ProcessRunner

    func testProcessRunnerCapturesStdout() async throws {
        let result = try await ProcessRunner.run("/bin/echo", ["hello"])
        let out = result.stdout
        XCTAssertEqual(out, "hello\n")
    }

    func testProcessRunnerReportsNonZeroExit() async throws {
        let result = try await ProcessRunner.run("/bin/sh", ["-c", "echo nope >&2; exit 7"])
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.exitCode, 7)
        XCTAssertTrue(result.stderr.contains("nope"))
    }

    func testProcessRunnerTimesOut() async throws {
        let result = try await ProcessRunner.run("/bin/sh", ["-c", "sleep 2"], timeout: 0.1)
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
    func assertThrows<T>(_ operation: () async throws -> T,
                         check: (Error) -> Void) async {
        do {
            _ = try await operation()
            XCTFail("Expected an error")
        } catch {
            check(error)
        }
    }

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

    func run(_ path: String, _ arguments: [String], timeout: TimeInterval) async throws -> ProcessRunResult {
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
