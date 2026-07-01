import Foundation

/// Persists SafetySettings in UserDefaults. Returns `.default` until the user
/// has saved at least once (so first launch uses sane defaults, not zeros).
public struct SettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let lowBattery   = "lowBatteryThreshold"
        static let onlyCharging = "onlyWhileCharging"
        static let pauseThermal = "pauseOnHighThermal"
        static let continueAfterQuit = "continueAfterQuit"
        static let seeded       = "settingsSeeded"
        static let autoOff      = "autoOffMinutes"
        static let language     = "languagePreference"
        static let onboarded    = "onboardingComplete"
        static let helperVersion = "lastRegisteredHelperVersion"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SafetySettings {
        guard defaults.bool(forKey: Key.seeded) else { return .default }
        return SafetySettings(
            lowBatteryThreshold: defaults.integer(forKey: Key.lowBattery),
            onlyWhileCharging: defaults.bool(forKey: Key.onlyCharging),
            pauseOnHighThermal: defaults.bool(forKey: Key.pauseThermal),
            continueAfterQuit: defaults.bool(forKey: Key.continueAfterQuit)
        )
    }

    public func save(_ settings: SafetySettings) {
        defaults.set(settings.lowBatteryThreshold, forKey: Key.lowBattery)
        defaults.set(settings.onlyWhileCharging, forKey: Key.onlyCharging)
        defaults.set(settings.pauseOnHighThermal, forKey: Key.pauseThermal)
        defaults.set(settings.continueAfterQuit, forKey: Key.continueAfterQuit)
        defaults.set(true, forKey: Key.seeded)
    }

    /// Auto-off duration in minutes (`0` = no auto-off). Defaults to 0.
    public func loadAutoOffMinutes() -> Int {
        defaults.integer(forKey: Key.autoOff)
    }

    public func saveAutoOffMinutes(_ minutes: Int) {
        defaults.set(minutes, forKey: Key.autoOff)
    }

    /// App UI language preference. Empty means "follow system".
    public func loadLanguagePreference() -> String {
        defaults.string(forKey: Key.language) ?? ""
    }

    public func saveLanguagePreference(_ rawValue: String) {
        defaults.set(rawValue, forKey: Key.language)
    }

    /// Whether the user has been through first-run onboarding. Defaults to false.
    public func loadOnboardingComplete() -> Bool {
        defaults.bool(forKey: Key.onboarded)
    }

    public func saveOnboardingComplete(_ complete: Bool) {
        defaults.set(complete, forKey: Key.onboarded)
    }

    /// The helper version for which the privileged helper was last
    /// (re-)registered. Empty until the first registration.
    public func loadLastHelperVersion() -> String {
        defaults.string(forKey: Key.helperVersion) ?? ""
    }

    public func saveLastHelperVersion(_ version: String) {
        defaults.set(version, forKey: Key.helperVersion)
    }

    public func clearLastHelperVersion() {
        defaults.removeObject(forKey: Key.helperVersion)
    }
}
