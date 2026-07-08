import Foundation

/// Persists small app preferences in UserDefaults.
public struct SettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let language                     = "languagePreference"
        static let onboarded                    = "onboardingComplete"
        static let desiredSleepPrevention       = "desiredSleepPreventionEnabled"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// App UI language preference. Empty means "follow system".
    public func loadLanguagePreference() -> String {
        defaults.string(forKey: Key.language) ?? ""
    }

    public func saveLanguagePreference(_ rawValue: String) {
        defaults.set(rawValue, forKey: Key.language)
    }

    /// Last successfully verified Lid sleep-prevention state. Nil means the app
    /// should adopt the next observed system state as its baseline.
    public func loadDesiredSleepPreventionEnabled() -> Bool? {
        guard defaults.object(forKey: Key.desiredSleepPrevention) != nil else {
            return nil
        }
        return defaults.bool(forKey: Key.desiredSleepPrevention)
    }

    public func saveDesiredSleepPreventionEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.desiredSleepPrevention)
    }

    /// Whether the user has been through first-run onboarding. Defaults to false.
    public func loadOnboardingComplete() -> Bool {
        defaults.bool(forKey: Key.onboarded)
    }

    public func saveOnboardingComplete(_ complete: Bool) {
        defaults.set(complete, forKey: Key.onboarded)
    }
}
