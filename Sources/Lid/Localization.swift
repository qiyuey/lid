import Foundation

enum AppLanguagePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case chinese

    var id: String { rawValue }

    var effectiveLanguage: AppLanguage {
        switch self {
        case .system:
            return .systemDefault
        case .english:
            return .english
        case .chinese:
            return .chinese
        }
    }

    func displayName(using text: AppStrings) -> String {
        switch self {
        case .system:  return text.languageFollowSystem
        case .english: return text.languageEnglish
        case .chinese: return text.languageChinese
        }
    }
}

enum AppLanguage: Sendable {
    case english
    case chinese

    static var systemDefault: AppLanguage {
        let language = Locale.preferredLanguages.first?.lowercased() ?? ""
        return language.hasPrefix("zh") ? .chinese : .english
    }
}

struct AppStrings: Sendable {
    let language: AppLanguage

    init(language: AppLanguage) {
        self.language = language
    }

    // MARK: Shared controls

    var ok: String { pick("OK", "好的") }
    var cancel: String { pick("Cancel", "取消") }
    var skip: String { pick("Skip", "跳过") }
    var done: String { pick("Done", "完成") }
    var `continue`: String { pick("Continue", "继续") }
    var back: String { pick("Back", "返回") }

    // MARK: Language

    var languageFollowSystem: String { pick("System", "系统") }
    var languageEnglish: String { pick("English", "English") }
    var languageChinese: String { "中文" }

    // MARK: Menu

    var primaryTitle: String { pick("Lid sleep prevention", "合盖防睡眠") }
    var primaryToggleLabel: String { pick("Enable lid sleep prevention", "开启合盖防睡眠") }
    var quitLid: String { pick("Quit Lid", "退出 Lid") }

    // MARK: Menu settings

    var sectionControls: String { pick("Controls", "控制") }
    var sectionApp: String { pick("App", "应用") }
    var launchAtLoginTitle: String { pick("Launch at login", "登录时启动") }
    var languageTitle: String { pick("Language", "语言") }
    var setupGuideTitle: String { pick("Setup Guide", "设置向导") }
    var checkAutomaticallyTitle: String { pick("Check automatically", "自动检查") }
    var checkNowTitle: String { pick("Check now", "立即检查") }
    var authorizeAgainTitle: String { pick("Authorize Again", "重新授权") }

    // MARK: Onboarding

    var onboardingWindowTitle: String { pick("Lid Setup", "Lid 设置") }
    var onboardingWelcomeTitle: String { pick("Welcome to Lid", "欢迎使用 Lid") }
    var onboardingWelcomeSubtitle: String { pick("Keep your Mac awake even with the lid closed.", "合盖后也让 Mac 持续运行。") }
    var onboardingWelcomeBody: String { pick("Use Lid when coding agents, downloads, or long builds need to keep running while your MacBook is closed.", "当编码助手、下载任务或长时间构建需要在 MacBook 合盖后继续运行时，可以使用 Lid。") }
    var onboardingMenuBullet: String { pick("Control everything from the menu bar.", "从菜单栏快速控制所有核心功能。") }
    var onboardingSleepBullet: String { pick("Return to normal sleep behavior whenever you turn Lid off.", "关闭 Lid 功能后会恢复正常睡眠行为。") }
    var onboardingHowTitle: String { pick("How it works", "工作方式") }
    var onboardingHowSubtitle: String { pick("Lid changes the macOS power setting directly.", "Lid 会直接修改 macOS 电源设置。") }
    var onboardingOverrideBullet: String { pick("Overrides the lid-close sleep that normally stops everything when you shut the lid.", "覆盖合盖时通常会中断任务的睡眠行为。") }
    var onboardingAuthorizationBullet: String { pick("macOS asks for administrator authorization when you turn the setting on or off.", "开启或关闭时，macOS 会要求管理员授权。") }
    var onboardingPersistenceBullet: String { pick("The selected state stays in macOS power settings until you turn it off.", "选定状态会保留在 macOS 电源设置中，直到你手动关闭。") }
    var onboardingDoneTitle: String { pick("You're all set", "设置完成") }
    var onboardingDoneSubtitle: String { pick("Lid is ready from the menu bar.", "Lid 已可从菜单栏使用。") }
    var onboardingDoneBody: String { pick("Enable lid sleep prevention when you need it. macOS will ask for administrator authorization for each change.", "需要时开启合盖防睡眠。每次更改时，macOS 都会要求管理员授权。") }
    var onboardingLaunchAtLogin: String { pick("Launch Lid at login", "登录时启动 Lid") }

    func stepLabel(step: Int, total: Int) -> String {
        pick("Step \(step) of \(total)", "第 \(step) / \(total) 步")
    }

    // MARK: Alerts and status

    var turnOffFailedTitle: String { pick("Couldn’t turn lid sleep prevention off", "无法关闭合盖防睡眠") }
    var turnOnFailedTitle: String { pick("Couldn’t turn lid sleep prevention on", "无法开启合盖防睡眠") }
    func sleepStateMismatch(target: Bool, actual: Bool? = nil) -> String {
        switch (language, target, actual) {
        case (.english, true, .some(false)):
            return "macOS accepted the request, but SleepDisabled is still off."
        case (.english, false, .some(true)):
            return "macOS accepted the request, but SleepDisabled is still on."
        case (.english, true, _):
            return "macOS accepted the request, but Lid could not confirm SleepDisabled is on."
        case (.english, false, _):
            return "macOS accepted the request, but Lid could not confirm SleepDisabled is off."
        case (.chinese, true, .some(false)):
            return "macOS 已接受请求，但 SleepDisabled 仍未开启。"
        case (.chinese, false, .some(true)):
            return "macOS 已接受请求，但 SleepDisabled 仍未关闭。"
        case (.chinese, true, _):
            return "macOS 已接受请求，但 Lid 无法确认 SleepDisabled 已开启。"
        case (.chinese, false, _):
            return "macOS 已接受请求，但 Lid 无法确认 SleepDisabled 已关闭。"
        }
    }

    func powerReadFailed(_ details: String) -> String {
        pick("Lid could not read the current macOS power setting.\n\n\(details)",
             "Lid 无法读取当前 macOS 电源设置。\n\n\(details)")
    }

    func powerAuthorizationFailed(_ details: String) -> String {
        pick("macOS did not authorize the power setting change. Click Authorize Again and approve the administrator prompt.\n\n\(details)",
             "macOS 未授权这次电源设置更改。请点“重新授权”，并批准管理员提示。\n\n\(details)")
    }

    func toggleFailedTitle(target: Bool) -> String {
        target ? turnOnFailedTitle : turnOffFailedTitle
    }

    private func pick(_ english: String, _ chinese: String) -> String {
        language == .chinese ? chinese : english
    }
}
