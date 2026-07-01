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
    }

    // MARK: BatteryParsers

    func testBatteryOnAC() {
        let out = "Now drawing from 'AC Power'\n -InternalBattery-0 (id=123)\t87%; charging; 0:42 remaining present: true"
        let info = BatteryParsers.parse(pmsetBatt: out)
        XCTAssertEqual(info.percent, 87)
        XCTAssertTrue(info.onAC)
        XCTAssertEqual(info.source, "AC")
    }

    func testBatteryOnBattery() {
        let out = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=123)\t19%; discharging; 1:05 remaining present: true"
        let info = BatteryParsers.parse(pmsetBatt: out)
        XCTAssertEqual(info.percent, 19)
        XCTAssertFalse(info.onAC)
        XCTAssertEqual(info.source, "Battery")
    }

    // MARK: Watchdog

    func testWatchdogFiresAfterTimeout() {
        let last = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1100) // 100s later
        XCTAssertTrue(Watchdog.shouldAutoRestore(lastHeartbeat: last, now: now, timeout: 90))
    }

    func testWatchdogQuietWithinTimeout() {
        let last = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1060) // 60s later
        XCTAssertFalse(Watchdog.shouldAutoRestore(lastHeartbeat: last, now: now, timeout: 90))
    }

    // MARK: SafetyPolicy

    func testSafetyDisablesOnLowBattery() {
        let info = BatteryInfo(percent: 15, onAC: false)
        XCTAssertTrue(SafetyPolicy.shouldDisableForBattery(info, threshold: 20))
    }

    func testSafetyAllowsOnAC() {
        let info = BatteryInfo(percent: 5, onAC: true)
        XCTAssertFalse(SafetyPolicy.shouldDisableForBattery(info, threshold: 20))
    }

    func testSafetyAllowsAboveThreshold() {
        let info = BatteryInfo(percent: 80, onAC: false)
        XCTAssertFalse(SafetyPolicy.shouldDisableForBattery(info, threshold: 20))
    }

    // MARK: AutoOff

    func testAutoOffDeadlineIsStartPlusMinutes() {
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(AutoOff.deadline(from: start, minutes: 30),
                       Date(timeIntervalSince1970: 1000 + 1800))
    }

    func testAutoOffRemainingClampsToZero() {
        let deadline = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1100) // already past
        XCTAssertEqual(AutoOff.remaining(deadline: deadline, now: now), 0)
    }

    func testAutoOffRemainingCountsDown() {
        let deadline = Date(timeIntervalSince1970: 1100)
        let now = Date(timeIntervalSince1970: 1040)
        XCTAssertEqual(AutoOff.remaining(deadline: deadline, now: now), 60)
    }

    func testAutoOffExpiry() {
        let deadline = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(AutoOff.isExpired(deadline: deadline, now: deadline))
        XCTAssertTrue(AutoOff.isExpired(deadline: deadline, now: Date(timeIntervalSince1970: 1001)))
        XCTAssertFalse(AutoOff.isExpired(deadline: deadline, now: Date(timeIntervalSince1970: 999)))
    }

    func testAutoOffCountdownFormatting() {
        XCTAssertEqual(AutoOff.formatCountdown(30), "0:30")
        XCTAssertEqual(AutoOff.formatCountdown(582), "9:42")
        XCTAssertEqual(AutoOff.formatCountdown(3909), "1:05:09")
        XCTAssertEqual(AutoOff.formatCountdown(0), "0:00")
    }

    func testAutoOffOptionLabels() {
        XCTAssertEqual(AutoOff.optionLabel(minutes: 15), "15 min")
        XCTAssertEqual(AutoOff.optionLabel(minutes: 30), "30 min")
        XCTAssertEqual(AutoOff.optionLabel(minutes: 60), "1 hour")
        XCTAssertEqual(AutoOff.optionLabel(minutes: 120), "2 hours")
        XCTAssertEqual(AutoOff.optionLabel(minutes: 240), "4 hours")
    }

    // MARK: Helper identity

    func testHelperLabelTracksAppBundleID() {
        XCTAssertEqual(LidHelperIdentity.label(appBundleID: "com.example.App"), "com.example.App.helper")
        XCTAssertEqual(LidHelperIdentity.appBundleID(helperLabel: "com.example.App.helper"), "com.example.App")
        XCTAssertEqual(LidHelperIdentity.fallbackLabel, "top.qiyuey.lid.helper")
        XCTAssertEqual(LidHelperIdentity.appBundleID(helperLabel: "invalid"), "top.qiyuey.lid")
    }

    func testHelperClientCodeSigningRequirementIncludesBundleAndTeam() {
        let requirement = LidHelperIdentity.clientCodeSigningRequirement(appBundleID: "com.example.App",
                                                                     teamID: "TEAM123456")
        XCTAssertTrue(requirement.contains(#"identifier "com.example.App""#))
        XCTAssertTrue(requirement.contains(#"certificate leaf[subject.OU] = "TEAM123456""#))
    }

    func testHelperClientCodeSigningRequirementCanAllowSelfSignedCertificate() {
        let requirement = LidHelperIdentity.clientCodeSigningRequirement(
            appBundleID: "com.example.App",
            teamID: "TEAM123456",
            certificateCommonName: #"Lid "Local" Self-Signed"#
        )

        XCTAssertTrue(requirement.contains(#"certificate leaf[subject.OU] = "TEAM123456""#))
        XCTAssertTrue(requirement.contains(#"certificate leaf[subject.CN] = "Lid \"Local\" Self-Signed""#))
        XCTAssertTrue(requirement.contains(" or "))
    }

    func testHelperClientCodeSigningRequirementPrefersSelfSignedCertificateHash() {
        let requirement = LidHelperIdentity.clientCodeSigningRequirement(
            appBundleID: "com.example.App",
            teamID: "TEAM123456",
            certificateCommonName: "Lid Local Self-Signed",
            certificateSHA1: "c0538f1e:36192006:9cd31f92:2a1a69ee:36f36c90"
        )

        XCTAssertTrue(requirement.contains(#"certificate leaf = H"C0538F1E361920069CD31F922A1A69EE36F36C90""#))
        XCTAssertFalse(requirement.contains("certificate leaf[subject.CN]"))
        XCTAssertTrue(requirement.contains(" or "))
    }

    func testHelperVersionStringContainsHelperVersion() {
        let version = LidHelperIdentity.versionString(
            bundle: .main,
            environment: [
                LidHelperIdentity.appVersionEnvKey: "1.2.3",
                LidHelperIdentity.appBuildEnvKey: "45"
            ]
        )
        XCTAssertEqual(version, "helper-\(LidHelperIdentity.helperVersion) version-1.2.3 build-45")
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
}
