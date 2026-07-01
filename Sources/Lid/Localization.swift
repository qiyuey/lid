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
    var open: String { pick("Open", "打开") }
    var install: String { pick("Install", "安装") }
    var remove: String { pick("Remove", "移除") }
    var check: String { pick("Check", "检查") }
    var done: String { pick("Done", "完成") }
    var `continue`: String { pick("Continue", "继续") }
    var back: String { pick("Back", "返回") }
    var never: String { pick("Never", "永不") }

    // MARK: Language

    var languageFollowSystem: String { pick("System", "系统") }
    var languageEnglish: String { pick("English", "English") }
    var languageChinese: String { pick("Chinese", "中文") }

    // MARK: Menu

    var primaryTitle: String { pick("Lid sleep prevention", "合盖防睡眠") }
    var primaryOnSubtitle: String { pick("On: lid-close sleep is disabled", "已开启：合盖后仍保持运行") }
    var primaryOffSubtitle: String { pick("Off: lid-close sleep is normal", "已关闭：合盖后正常睡眠") }
    var primaryToggleLabel: String { pick("Enable lid sleep prevention", "开启合盖防睡眠") }
    var continueAfterQuitTitle: String { pick("Continue after quit", "退出后继续生效") }
    var continueAfterQuitOnSubtitle: String { pick("Stays on after Lid exits", "退出 Lid 后仍保持开启") }
    var continueAfterQuitOffSubtitle: String { pick("Turns off when Lid quits", "退出 Lid 时自动关闭") }
    var continueAfterQuitHelp: String { pick("When enabled, quitting Lid leaves lid sleep prevention active.", "开启后，退出 Lid 不会恢复正常合盖睡眠。") }
    var helperNotice: String { pick("Install helper", "安装 Helper") }
    var helperNeedsApprovalNotice: String { pick("Helper needs approval", "Helper 等待批准") }
    var installHelperRequiredMessage: String { pick("Install the background helper before enabling lid sleep prevention.", "请先安装后台 Helper，再开启合盖防睡眠。") }
    var safetyTitle: String { pick("Safety", "安全保护") }
    var onlyWhileCharging: String { pick("Only while charging", "仅充电时开启") }
    var pauseWhenHot: String { pick("Pause when running hot", "温度过高时暂停") }
    var lowBatteryCutoff: String { pick("Low-battery cutoff", "低电量阈值") }
    var quitLid: String { pick("Quit Lid", "退出 Lid") }
    var settings: String { pick("Settings", "设置") }

    func batteryAccessibility(percent: Int, onAC: Bool) -> String {
        switch language {
        case .english:
            return "Battery \(percent) percent\(onAC ? ", on power" : "")"
        case .chinese:
            return "电量 \(percent)%\(onAC ? "，已接电源" : "")"
        }
    }

    // MARK: Settings window

    var settingsWindowTitle: String { pick("Lid Settings", "Lid 设置") }
    var sectionGeneral: String { pick("General", "通用") }
    var launchAtLoginTitle: String { pick("Launch at login", "登录时启动") }
    var launchAtLoginSubtitle: String { pick("Open Lid automatically when you sign in.", "登录 macOS 后自动打开 Lid。") }
    var languageTitle: String { pick("Language", "语言") }
    var languageSubtitle: String { pick("Use system language, or choose English / Chinese.", "默认跟随系统，也可以手动选择中文或英文。") }
    var setupGuideTitle: String { pick("Setup Guide", "设置向导") }
    var continueAfterQuitSettingsSubtitle: String { pick("Keep lid sleep prevention active after Lid exits.", "退出 Lid 后仍保持合盖防睡眠开启。") }
    var sectionHelper: String { pick("Background Helper", "后台 Helper") }
    var helperTitle: String { pick("Background helper", "后台 Helper") }
    var helperActiveSubtitle: String { pick("Active. Removes password prompts and supports the watchdog.", "已启用。减少密码提示，并支持看门狗保护。") }
    var helperPendingSubtitle: String { pick("Waiting for approval in System Settings > Login Items.", "等待在系统设置 > 登录项中批准。") }
    var helperInstallSubtitle: String { pick("Required for lid sleep prevention and the safety watchdog.", "用于开启合盖防睡眠和安全看门狗。") }
    var pendingHelperTitle: String { pick("Pending helper", "待批准 Helper") }
    var pendingHelperSubtitle: String { pick("Remove the unapproved helper registration.", "移除尚未批准的 Helper 注册。") }
    var sectionAutoOff: String { pick("Auto-off Timer", "自动关闭计时器") }
    var turnOffAfterTitle: String { pick("Turn off after", "自动关闭") }
    var turnOffAfterSubtitle: String { pick("Return to normal lid-close sleep automatically.", "到时自动恢复正常合盖睡眠。") }
    var turningOffInTitle: String { pick("Turning off in", "剩余时间") }
    var turningOffInSubtitle: String { pick("The current session has an auto-off timer.", "当前合盖防睡眠会按计时器自动关闭。") }
    var sectionUpdates: String { pick("Updates", "更新") }
    var checkAutomaticallyTitle: String { pick("Check automatically", "自动检查") }
    var checkAutomaticallySubtitle: String { pick("Let Sparkle look for new releases in the background.", "让 Sparkle 在后台检查新版本。") }
    var checkNowTitle: String { pick("Check now", "立即检查") }
    var checkNowSubtitle: String { pick("Manually check whether a newer version is available.", "手动检查是否有新版本。") }
    var sectionAbout: String { pick("About", "关于") }
    var versionTitle: String { pick("Version", "版本") }
    var versionSubtitle: String { pick("Marketing and build versions are kept in sync.", "营销版本和构建版本保持一致。") }
    var sourceTitle: String { pick("Source", "源码") }
    var sourceSubtitle: String { pick("Includes MIT-licensed upstream work by Nghia Luong.", "包含 Nghia Luong 的 MIT 授权上游工作。") }

    // MARK: Onboarding

    var onboardingWindowTitle: String { pick("Lid Setup", "Lid 设置") }
    var onboardingWelcomeTitle: String { pick("Welcome to Lid", "欢迎使用 Lid") }
    var onboardingWelcomeSubtitle: String { pick("Keep your Mac awake even with the lid closed.", "合盖后也让 Mac 持续运行。") }
    var onboardingWelcomeBody: String { pick("Use Lid when coding agents, downloads, or long builds need to keep running while your MacBook is closed.", "当编码助手、下载任务或长时间构建需要在 MacBook 合盖后继续运行时，可以使用 Lid。") }
    var onboardingMenuBullet: String { pick("Control everything from the menu bar.", "从菜单栏快速控制所有核心功能。") }
    var onboardingSleepBullet: String { pick("Return to normal sleep behavior whenever you turn Lid off.", "关闭 Lid 功能后会恢复正常睡眠行为。") }
    var onboardingHowTitle: String { pick("How it works", "工作方式") }
    var onboardingHowSubtitle: String { pick("Lid changes only the behavior it needs to, then restores it.", "Lid 只修改必要的睡眠行为，并在关闭时恢复。") }
    var onboardingOverrideBullet: String { pick("Overrides the lid-close sleep that normally stops everything when you shut the lid.", "覆盖合盖时通常会中断任务的睡眠行为。") }
    var onboardingSafetyBullet: String { pick("Auto-pauses if the Mac runs hot or the battery runs low, so it stays safe unattended.", "温度过高或电量过低时自动暂停，降低无人看管时的风险。") }
    var onboardingWatchdogBullet: String { pick("By default, a watchdog restores normal sleep if Lid ever quits or crashes.", "默认情况下，如果 Lid 退出或崩溃，看门狗会恢复正常睡眠。") }
    var onboardingVentilationNote: String { pick("Keep your Mac plugged in and ventilated under heavy use.", "高负载时请接入电源，并保持散热通畅。") }
    var onboardingHelperTitle: String { pick("Skip the password prompts", "减少密码提示") }
    var onboardingHelperSubtitle: String { pick("The helper keeps toggling quick and lets the watchdog run.", "Helper 让开关更快，也能运行看门狗。") }
    var onboardingHelperBody: String { pick("Install a small background helper so turning lid sleep prevention on and off never asks for your admin password, and the safety watchdog can run.", "安装一个小型后台 Helper 后，开关合盖防睡眠不再每次要求管理员密码，安全看门狗也可以运行。") }
    var onboardingHelperOptional: String { pick("Optional. Lid still works without it; it'll just ask for your password each time you toggle.", "这是可选项。不安装也能使用 Lid，只是每次开关时需要输入密码。") }
    var onboardingHelperActive: String { pick("Background helper installed and active.", "后台 Helper 已安装并启用。") }
    var onboardingHelperApproval: String { pick("Approve Lid under System Settings > Login Items, then come back here.", "请在系统设置 > 登录项中批准 Lid，然后回到这里。") }
    var onboardingOpenLoginItems: String { pick("Open Login Items", "打开登录项") }
    var onboardingInstallHelper: String { pick("Install Background Helper", "安装后台 Helper") }
    var onboardingDoneTitle: String { pick("You're all set", "设置完成") }
    var onboardingDoneSubtitle: String { pick("Lid is ready from the menu bar.", "Lid 已可从菜单栏使用。") }
    var onboardingDoneBody: String { pick("Click the Lid icon and turn **Lid sleep prevention** on whenever you need long-running work to continue with the lid closed.", "需要长时间任务在合盖后继续运行时，点击菜单栏里的 Lid 图标并开启 **合盖防睡眠**。") }
    var onboardingLaunchAtLogin: String { pick("Launch Lid at login", "登录时启动 Lid") }

    func stepLabel(step: Int, total: Int) -> String {
        pick("Step \(step) of \(total)", "第 \(step) / \(total) 步")
    }

    // MARK: Alerts and status

    var approveHelperPrompt: String { pick("Approve Lid in System Settings > Login Items.", "请在系统设置 > 登录项中批准 Lid。") }
    var approveHelperThenTry: String { pick("Approve Lid in System Settings > Login Items, then try the switch again.", "请在系统设置 > 登录项中批准 Lid，然后再次尝试开关。") }
    var helperRemovedMessage: String { pick("Background helper removed. Lid will use the administrator prompt until you install it again.", "后台 Helper 已移除。重新安装前，Lid 会使用管理员密码提示。") }
    var helperNoResponse: String { pick("The background helper didn’t respond.", "后台 Helper 没有响应。") }
    var continueAfterQuitHelperError: String { pick("Couldn’t tell the background helper to continue after quit.", "无法通知后台 Helper 在退出后继续生效。") }
    var turnOffFailedTitle: String { pick("Couldn’t turn lid sleep prevention off", "无法关闭合盖防睡眠") }
    var turnOnFailedTitle: String { pick("Couldn’t turn lid sleep prevention on", "无法开启合盖防睡眠") }
    var quitRestoreFailedText: String { pick("Lid could not restore normal sleep before quitting. Quit anyway and let the background watchdog restore it shortly?", "Lid 退出前无法恢复正常睡眠。仍要退出，并让后台看门狗稍后恢复吗？") }
    var quitAnyway: String { pick("Quit Anyway", "仍然退出") }
    var removeHelperTitle: String { pick("Remove background helper?", "移除后台 Helper？") }
    var removeHelperText: String { pick("Lid will restore normal sleep first, then remove its privileged helper. Future toggles will use the administrator prompt until you install the helper again.", "Lid 会先恢复正常睡眠，然后移除特权 Helper。重新安装前，之后的开关会使用管理员密码提示。") }
    var removeHelperButton: String { pick("Remove Helper", "移除 Helper") }
    var removeHelperFailedTitle: String { pick("Couldn’t remove background helper", "无法移除后台 Helper") }
    func removeHelperFailedText(_ message: String) -> String {
        pick("Lid could not restore normal sleep, so the helper was left installed.\n\n\(message)",
             "Lid 无法恢复正常睡眠，因此保留了后台 Helper。\n\n\(message)")
    }
    func helperFailureText(_ message: String) -> String {
        pick("\(message)\n\nThis usually happens after an update. Reinstalling the background helper fixes it.",
             "\(message)\n\n这通常发生在更新后。重新安装后台 Helper 即可修复。")
    }
    var reinstallHelper: String { pick("Reinstall Helper...", "重新安装 Helper...") }
    var helperReinstalledMessage: String { pick("Background helper reinstalled. Try the switch again.", "后台 Helper 已重新安装，请再次尝试开关。") }
    var watchdogPolicyError: String { pick("The background helper couldn’t update its watchdog policy.", "后台 Helper 无法更新看门狗策略。") }

    func toggleFailedTitle(target: Bool) -> String {
        target ? turnOnFailedTitle : turnOffFailedTitle
    }

    func safetyAutoPaused(_ reason: SafetyReason) -> String {
        switch (language, reason) {
        case (.english, .highThermal):
            return "Auto-paused: the Mac is running hot."
        case (.english, .notCharging):
            return "Auto-paused: not on charger."
        case (.english, .lowBattery(let percent)):
            return "Auto-paused: battery \(percent)% on battery power."
        case (.chinese, .highThermal):
            return "已自动暂停：Mac 温度过高。"
        case (.chinese, .notCharging):
            return "已自动暂停：未连接电源。"
        case (.chinese, .lowBattery(let percent)):
            return "已自动暂停：使用电池供电，电量 \(percent)%。"
        }
    }

    func safetyBlocked(_ reason: SafetyReason) -> String {
        switch (language, reason) {
        case (.english, .highThermal):
            return "Your Mac is running hot, so lid sleep prevention is paused. It will be available again once the Mac cools down."
        case (.english, .notCharging):
            return "\"Only while charging\" is on, so connect your Mac to power to enable lid sleep prevention."
        case (.english, .lowBattery(let percent)):
            return "Battery is at \(percent)%. Charge above the low-battery cutoff to enable lid sleep prevention."
        case (.chinese, .highThermal):
            return "Mac 温度过高，合盖防睡眠已暂停。冷却后可以再次开启。"
        case (.chinese, .notCharging):
            return "已开启“仅充电时开启”，请先连接电源再开启合盖防睡眠。"
        case (.chinese, .lowBattery(let percent)):
            return "当前电量为 \(percent)%。请充到高于低电量阈值后再开启合盖防睡眠。"
        }
    }

    func autoOffOptionLabel(minutes: Int) -> String {
        switch language {
        case .english:
            return AutoOff.optionLabel(minutes: minutes)
        case .chinese:
            guard minutes % 60 == 0 else { return "\(minutes) 分钟" }
            let hours = minutes / 60
            return "\(hours) 小时"
        }
    }

    func autoOffExpired(minutes: Int) -> String {
        pick("Auto-off: \(autoOffOptionLabel(minutes: minutes)) elapsed.",
             "已自动关闭：\(autoOffOptionLabel(minutes: minutes)) 已到。")
    }

    private func pick(_ english: String, _ chinese: String) -> String {
        language == .chinese ? chinese : english
    }
}
