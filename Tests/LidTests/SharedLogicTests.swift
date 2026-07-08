import XCTest

final class SharedLogicTests: XCTestCase {

    // MARK: PowerParsers.isSleepDisabled

    func testSleepDisabledTrue() {
        let out = """
        System-wide power settings:
         SleepDisabled        1
        Currently in use:
         standby              1
        """
        XCTAssertTrue(PowerParsers.isSleepDisabled(pmsetG: out))
    }

    func testSleepDisabledFalse() {
        let out = """
        System-wide power settings:
         SleepDisabled        0
        """
        XCTAssertFalse(PowerParsers.isSleepDisabled(pmsetG: out))
    }

    func testSleepDisabledMissing() {
        XCTAssertFalse(PowerParsers.isSleepDisabled(pmsetG: "Currently in use:\n standby 1"))
        XCTAssertNil(PowerParsers.sleepDisabledValue(pmsetG: "Currently in use:\n standby 1"))
    }

    func testSleepDisabledDoesNotTrustClamshellCausesSleep() {
        let out = """
        System-wide power settings:
         SleepDisabled        0
        """
        let ioreg = """
            "AppleClamshellCausesSleep" = No
            "SleepDisabled" = No
        """

        XCTAssertFalse(PowerParsers.isSleepDisabled(pmsetG: out))
        XCTAssertFalse(PowerParsers.isSleepDisabled(pmsetG: ioreg))
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
