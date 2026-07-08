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

    func testSetupCopyDescribesDirectAdministratorAuthorization() {
        let englishText = AppStrings(language: .english)
        let chineseText = AppStrings(language: .chinese)

        XCTAssertTrue(englishText.onboardingAuthorizationBullet.contains("administrator authorization"))
        XCTAssertTrue(englishText.onboardingPersistenceBullet.contains("macOS power settings"))
        XCTAssertFalse(englishText.onboardingDoneBody.contains("background process"))
        XCTAssertFalse(englishText.powerAuthorizationFailed("details").contains("background process"))

        XCTAssertTrue(chineseText.onboardingAuthorizationBullet.contains("管理员授权"))
        XCTAssertTrue(chineseText.onboardingPersistenceBullet.contains("macOS 电源设置"))
        XCTAssertFalse(chineseText.onboardingDoneBody.contains("后台进程"))
        XCTAssertFalse(chineseText.powerAuthorizationFailed("details").contains("后台进程"))
    }
}
