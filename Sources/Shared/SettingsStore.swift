import Foundation

/// Persists small app preferences in UserDefaults.
public struct SettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let language     = "languagePreference"
        static let onboarded    = "onboardingComplete"
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

    /// Whether the user has been through first-run onboarding. Defaults to false.
    public func loadOnboardingComplete() -> Bool {
        defaults.bool(forKey: Key.onboarded)
    }

    public func saveOnboardingComplete(_ complete: Bool) {
        defaults.set(complete, forKey: Key.onboarded)
    }
}
