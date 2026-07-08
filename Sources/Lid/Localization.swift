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
    var languageChinese: String { "中文" }

    // MARK: Menu

    var primaryTitle: String { pick("Lid sleep prevention", "合盖防睡眠") }
    var primaryToggleLabel: String { pick("Enable lid sleep prevention", "开启合盖防睡眠") }
    var installHelperRequiredMessage: String { pick("Install the background helper before enabling lid sleep prevention.", "请先安装后台 Helper，再开启合盖防睡眠。") }
    var safetyTitle: String { pick("Safety", "安全保护") }
    var onlyWhileCharging: String { pick("Only while charging", "仅充电时开启") }
    var pauseWhenHot: String { pick("Pause when running hot", "温度过高时暂停") }
    var lowBatteryCutoff: String { pick("Low-battery cutoff", "低电量阈值") }
    var quitLid: String { pick("Quit Lid", "退出 Lid") }

    // MARK: Menu settings

    var sectionControls: String { pick("Controls", "控制") }
    var sectionApp: String { pick("App", "应用") }
    var launchAtLoginTitle: String { pick("Launch at login", "登录时启动") }
    var languageTitle: String { pick("Language", "语言") }
    var setupGuideTitle: String { pick("Setup Guide", "设置向导") }
    var helperTitle: String { pick("Background helper", "后台 Helper") }
    var pendingHelperTitle: String { pick("Pending helper", "待批准 Helper") }
    var helperRequiredTitle: String { pick("Helper required", "需要安装 Helper") }
    var helperApprovalRequiredTitle: String { pick("Helper needs approval", "需要批准 Helper") }
    var helperUnavailableTitle: String { pick("Helper unavailable", "Helper 不可用") }
    var helperRequiredBody: String { pick("Install and approve the helper before using lid sleep prevention.", "安装并批准 Helper 后，才能使用合盖防睡眠。") }
    var helperApprovalRequiredBody: String { pick("Open Login Items and allow Lid's background helper.", "打开登录项并允许 Lid 的后台 Helper。") }
    var helperUnavailableBody: String { pick("Check that Lid is enabled in System Settings > Login Items. If it still doesn’t respond, remove the helper and install it again.", "请检查系统设置 > 登录项中是否已启用 Lid。若仍无响应，请移除 Helper 后重新安装。") }
    var turnOffAfterTitle: String { pick("Turn off after", "自动关闭") }
    var turningOffInTitle: String { pick("Turning off in", "剩余时间") }
    var checkAutomaticallyTitle: String { pick("Check automatically", "自动检查") }
    var checkNowTitle: String { pick("Check now", "立即检查") }
    var versionTitle: String { pick("Version", "版本") }

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
    var onboardingPersistenceBullet: String { pick("The helper keeps the selected sleep-prevention state until you turn it off.", "Helper 会保持选定的防睡眠状态，直到你手动关闭。") }
    var onboardingVentilationNote: String { pick("Keep your Mac plugged in and ventilated under heavy use.", "高负载时请接入电源，并保持散热通畅。") }
    var onboardingHelperTitle: String { pick("Install the background helper", "安装后台 Helper") }
    var onboardingHelperSubtitle: String { pick("The helper controls and persists lid sleep prevention.", "Helper 用于控制并持久化合盖防睡眠。") }
    var onboardingHelperBody: String { pick("Install a small background helper before using lid sleep prevention.", "使用合盖防睡眠前，请先安装一个小型后台 Helper。") }
    var onboardingHelperRequired: String { pick("Required. Lid cannot change lid sleep prevention until the helper is installed and approved.", "必需。安装并批准 Helper 后，Lid 才能更改合盖防睡眠。") }
    var onboardingHelperActive: String { pick("Background helper installed and active.", "后台 Helper 已安装并启用。") }
    var onboardingHelperApproval: String { pick("Approve Lid under System Settings > Login Items, then come back here.", "请在系统设置 > 登录项中批准 Lid，然后回到这里。") }
    var onboardingOpenLoginItems: String { pick("Open Login Items", "打开登录项") }
    var onboardingInstallHelper: String { pick("Install Background Helper", "安装后台 Helper") }
    var onboardingDoneTitle: String { pick("You're all set", "设置完成") }
    var onboardingDoneSubtitle: String { pick("Lid is ready from the menu bar.", "Lid 已可从菜单栏使用。") }
    var onboardingDoneBody: String { pick("Choose the defaults Lid should apply after setup.", "选择 Lid 在设置完成后应用的默认状态。") }
    var onboardingLaunchAtLogin: String { pick("Launch Lid at login", "登录时启动 Lid") }

    func stepLabel(step: Int, total: Int) -> String {
        pick("Step \(step) of \(total)", "第 \(step) / \(total) 步")
    }

    // MARK: Alerts and status

    var approveHelperPrompt: String { pick("Approve Lid in System Settings > Login Items.", "请在系统设置 > 登录项中批准 Lid。") }
    var approveHelperThenTry: String { pick("Approve Lid in System Settings > Login Items, then try the switch again.", "请在系统设置 > 登录项中批准 Lid，然后再次尝试开关。") }
    var helperRemovedMessage: String { pick("Background helper removed. Install it again before using lid sleep prevention.", "后台 Helper 已移除。使用合盖防睡眠前，请重新安装 Helper。") }
    var helperNoResponse: String { pick("The background helper didn’t respond. Check System Settings > Login Items, or remove and install the helper again.", "后台 Helper 没有响应。请检查系统设置 > 登录项，或移除后重新安装 Helper。") }
    func helperStateMismatch(target: Bool) -> String {
        target
            ? pick("The background helper reported success, but SleepDisabled is still off.", "后台 Helper 返回成功，但 SleepDisabled 仍未开启。")
            : pick("The background helper reported success, but SleepDisabled is still on.", "后台 Helper 返回成功，但 SleepDisabled 仍未关闭。")
    }
    var turnOffFailedTitle: String { pick("Couldn’t turn lid sleep prevention off", "无法关闭合盖防睡眠") }
    var turnOnFailedTitle: String { pick("Couldn’t turn lid sleep prevention on", "无法开启合盖防睡眠") }
    var removeHelperTitle: String { pick("Remove background helper?", "移除后台 Helper？") }
    var removeHelperText: String { pick("Lid will restore normal sleep first, then remove its privileged helper. You will need to install the helper again before using lid sleep prevention.", "Lid 会先恢复正常睡眠，然后移除特权 Helper。之后如需使用合盖防睡眠，需要重新安装 Helper。") }
    var removeHelperButton: String { pick("Remove Helper", "移除 Helper") }
    var removeHelperFailedTitle: String { pick("Couldn’t remove background helper", "无法移除后台 Helper") }
    func removeHelperFailedText(_ message: String) -> String {
        pick("Lid could not restore normal sleep, so the helper was left installed.\n\n\(message)",
             "Lid 无法恢复正常睡眠，因此保留了后台 Helper。\n\n\(message)")
    }
    func helperFailureText(_ message: String) -> String {
        pick("\(message)\n\nOpen Login Items and make sure Lid's background helper is enabled. If it still doesn’t respond, remove the helper and install it again.",
             "\(message)\n\n请打开登录项，确认 Lid 的后台 Helper 已启用。若仍无响应，请移除 Helper 后重新安装。")
    }

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
