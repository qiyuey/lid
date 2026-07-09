import AppKit
import SwiftUI
import Foundation
import OSLog

@MainActor
final class AppState: ObservableObject {
    @Published var isEnabled = false
    @Published var lastError: String?
    @Published var isChanging = false

    /// App UI language preference (persisted). Defaults to following macOS.
    @Published var languagePreference: AppLanguagePreference = .system

    /// Launch-at-login state (the app itself).
    @Published var launchAtLogin = false

    var showsActiveMenuBarIcon: Bool { isEnabled }

    /// Whether the user has finished first-run onboarding (persisted).
    @Published var onboardingComplete = false

    private let logger = Logger(subsystem: "top.qiyuey.lid", category: "app-state")
    private let power = PowerController()
    private let store = SettingsStore()
    private let loginItem = LoginItemManager()
    private lazy var onboarding = OnboardingController(state: self)
    private let automaticRestoreRetryInterval: TimeInterval = 10 * 60

    /// Marketing version shown in the menu.
    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    var text: AppStrings {
        AppStrings(language: languagePreference.effectiveLanguage)
    }

    private var alerts: AlertPresenter {
        AlertPresenter(text: text)
    }

    private var stateRefreshTimer: Timer?
    private var stateChangeRequestID = 0
    @Published private var authorizationRetryTarget: Bool?
    private var desiredSleepPreventionEnabled: Bool?
    private var lastAutomaticRestoreAttempt: Date?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var localeObserver: NSObjectProtocol?

    init() {
        languagePreference = AppLanguagePreference(rawValue: store.loadLanguagePreference()) ?? .system
        onboardingComplete = store.loadOnboardingComplete()
        desiredSleepPreventionEnabled = store.loadDesiredSleepPreventionEnabled()
        launchAtLogin = loginItem.isEnabled
        refreshState()
        stateRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshState() }
        }
        localeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if self?.languagePreference == .system {
                    self?.objectWillChange.send()
                }
            }
        }
        // First launch shows onboarding once (persisted so closing it early won't
        // re-nag).
        if !onboardingComplete {
            onboardingComplete = true
            store.saveOnboardingComplete(true)
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        }
    }

    deinit {
        MainActor.assumeIsolated {
            stateRefreshTimer?.invalidate()
            if let didBecomeActiveObserver {
                NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            }
            if let localeObserver {
                NotificationCenter.default.removeObserver(localeObserver)
            }
        }
    }

    // MARK: Onboarding

    /// Present the first-run setup window (also reachable from the menu).
    func showOnboarding() {
        onboarding.show()
    }

    /// Mark onboarding done, persist it, and close the window.
    func completeOnboarding() {
        onboardingComplete = true
        store.saveOnboardingComplete(true)
        onboarding.close()
    }

    /// Close the setup window without changing any persisted setup state.
    func closeOnboarding() {
        onboarding.close()
    }

    // MARK: Settings

    func setLanguagePreference(_ preference: AppLanguagePreference) {
        languagePreference = preference
        store.saveLanguagePreference(preference.rawValue)
        objectWillChange.send()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if let err = loginItem.setEnabled(enabled) {
            lastError = err
            launchAtLogin = loginItem.isEnabled
        } else {
            // status can lag right after register/unregister; trust the action.
            launchAtLogin = enabled
        }
    }

    // MARK: State

    func refreshState() {
        guard !isChanging else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let enabled = try await self.power.isSleepPreventionEnabledAsync()
                guard !self.isChanging else { return }
                self.applyObservedEnabledState(enabled)
                self.restoreObservedStateIfNeeded(enabled)
            } catch {
                self.lastError = self.text.powerReadFailed(self.powerErrorDetails(error))
                self.logger.error("Refresh state failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// User flipped the toggle: treat it as user-initiated so any failure
    /// surfaces a visible alert, not just the inline note.
    func toggle() { setEnabled(!isEnabled, userInitiated: true) }

    func setEnabled(_ target: Bool,
                    userInitiated: Bool = false,
                    completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        let requestID = beginStateChange()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.power.setSleepPreventionAsync(target)
                let actual = try await self.power.isSleepPreventionEnabledAsync()
                guard self.isCurrentStateChange(requestID) else { return }

                self.applyObservedEnabledState(actual)
                guard actual == target else {
                    self.authorizationRetryTarget = target
                    let message = self.text.sleepStateMismatch(target: target, actual: actual)
                    self.lastError = message
                    if userInitiated {
                        self.alerts.presentToggleFailure(target: target, message: message)
                    }
                    self.finishStateChange(requestID)
                    completion?(false)
                    return
                }

                self.lastError = nil
                self.authorizationRetryTarget = nil
                self.rememberDesiredSleepPreventionState(target)
                self.finishStateChange(requestID)
                completion?(true)
            } catch {
                guard self.isCurrentStateChange(requestID) else { return }
                if let observed = try? await self.power.isSleepPreventionEnabledAsync() {
                    self.applyObservedEnabledState(observed)
                }
                self.authorizationRetryTarget = target
                let message = self.userMessage(for: error, target: target)
                self.lastError = message
                self.logger.error("Set SleepDisabled failed: \(error.localizedDescription, privacy: .public)")
                if userInitiated {
                    self.alerts.presentToggleFailure(target: target, message: message)
                }
                self.finishStateChange(requestID)
                completion?(false)
            }
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func tick() {
        refreshState()
    }

    func menuDidAppear() {
        refreshState()
    }

    var canRetryPowerAuthorization: Bool {
        authorizationRetryTarget != nil
    }

    func retryPowerAuthorization() {
        guard let target = authorizationRetryTarget else { return }
        setEnabled(target, userInitiated: true)
    }

    private func beginStateChange() -> Int {
        stateChangeRequestID += 1
        isChanging = true
        return stateChangeRequestID
    }

    private func isCurrentStateChange(_ requestID: Int) -> Bool {
        requestID == stateChangeRequestID
    }

    private func finishStateChange(_ requestID: Int) {
        guard isCurrentStateChange(requestID) else { return }
        isChanging = false
    }

    private func applyObservedEnabledState(_ value: Bool) {
        isEnabled = value
        if desiredSleepPreventionEnabled == nil {
            rememberDesiredSleepPreventionState(value)
        }
        if desiredSleepPreventionEnabled == value {
            lastAutomaticRestoreAttempt = nil
            authorizationRetryTarget = nil
        }
    }

    private func rememberDesiredSleepPreventionState(_ value: Bool) {
        desiredSleepPreventionEnabled = value
        store.saveDesiredSleepPreventionEnabled(value)
    }

    private func restoreObservedStateIfNeeded(_ observed: Bool) {
        guard let desired = desiredSleepPreventionEnabled else { return }
        guard desired != observed else { return }
        guard shouldAttemptAutomaticRestore() else { return }

        lastAutomaticRestoreAttempt = Date()
        logger.info("Restoring SleepDisabled drift. desired=\(desired, privacy: .public) observed=\(observed, privacy: .public)")
        setEnabled(desired, userInitiated: false)
    }

    private func shouldAttemptAutomaticRestore(now: Date = Date()) -> Bool {
        guard let lastAutomaticRestoreAttempt else { return true }
        return now.timeIntervalSince(lastAutomaticRestoreAttempt) >= automaticRestoreRetryInterval
    }

    private func userMessage(for error: Error, target: Bool) -> String {
        if case let PowerControllerError.verificationFailed(_, actual) = error {
            return text.sleepStateMismatch(target: target, actual: actual)
        }
        if case PowerControllerError.readFailed = error {
            return text.powerReadFailed(powerErrorDetails(error))
        }
        return text.powerAuthorizationFailed(powerErrorDetails(error))
    }

    private func powerErrorDetails(_ error: Error) -> String {
        if let error = error as? PowerControllerError {
            return error.userDetails
        }
        return error.localizedDescription
    }
}
