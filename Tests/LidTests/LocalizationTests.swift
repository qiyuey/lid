import XCTest

final class LocalizationTests: XCTestCase {

    func testLanguageNamesUseNativeNames() {
        let englishText = AppStrings(language: .english)
        let chineseText = AppStrings(language: .chinese)

        XCTAssertEqual(AppLanguagePreference.english.displayName(using: englishText), "English")
        XCTAssertEqual(AppLanguagePreference.english.displayName(using: chineseText), "English")
        XCTAssertEqual(AppLanguagePreference.chinese.displayName(using: englishText), "中文")
        XCTAssertEqual(AppLanguagePreference.chinese.displayName(using: chineseText), "中文")
    }

    func testHelperCopyRequiresInstallationInsteadOfPasswordFallback() {
        let englishText = AppStrings(language: .english)
        let chineseText = AppStrings(language: .chinese)

        XCTAssertTrue(englishText.helperRemovedMessage.contains("Install it again"))
        XCTAssertFalse(englishText.helperRemovedMessage.contains("administrator prompt"))
        XCTAssertTrue(chineseText.helperRemovedMessage.contains("重新安装 Helper"))
        XCTAssertFalse(chineseText.helperRemovedMessage.contains("管理员密码提示"))

        XCTAssertTrue(englishText.onboardingHelperRequired.contains("Required"))
        XCTAssertFalse(englishText.onboardingHelperRequired.contains("Optional"))
        XCTAssertTrue(chineseText.onboardingHelperRequired.contains("必需"))
        XCTAssertFalse(chineseText.onboardingHelperRequired.contains("可选"))
    }

    func testSafetyReasonMessagesAreLocalizedInAppStrings() {
        let englishText = AppStrings(language: .english)
        let chineseText = AppStrings(language: .chinese)

        XCTAssertEqual(englishText.safetyAutoPaused(.highThermal), "Auto-paused: the Mac is running hot.")
        XCTAssertEqual(englishText.safetyAutoPaused(.notCharging), "Auto-paused: not on charger.")
        XCTAssertEqual(englishText.safetyAutoPaused(.lowBattery(12)), "Auto-paused: battery 12% on battery power.")
        XCTAssertEqual(
            englishText.safetyBlocked(.lowBattery(12)),
            "Battery is at 12%. Charge above the low-battery cutoff to enable lid sleep prevention."
        )

        XCTAssertEqual(chineseText.safetyAutoPaused(.highThermal), "已自动暂停：Mac 温度过高。")
        XCTAssertEqual(chineseText.safetyAutoPaused(.notCharging), "已自动暂停：未连接电源。")
        XCTAssertEqual(chineseText.safetyAutoPaused(.lowBattery(12)), "已自动暂停：使用电池供电，电量 12%。")
        XCTAssertEqual(
            chineseText.safetyBlocked(.lowBattery(12)),
            "当前电量为 12%。请充到高于低电量阈值后再开启合盖防睡眠。"
        )
    }
}
