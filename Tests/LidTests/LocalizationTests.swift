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
}
