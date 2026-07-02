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
}
