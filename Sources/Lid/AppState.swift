import AppKit
import SwiftUI
import Foundation
import OSLog

@MainActor
final class AppState: ObservableObject {
    @Published var isEnabled = false
    @Published var helperInstalled = false
    @Published var helperNeedsApproval = false
    /// Current battery charge (0–100) and whether on AC power. Drives safety
    /// evaluation without showing live battery status in the menu.
    @Published var batteryPercent = 0
    @Published var batteryOnAC = false
    @Published var lastError: String?
    @Published var isChanging = false

    /// True when the privileged helper is installed and usable.
    @Published var usingHelper = false

    /// User-tunable safety preferences (persisted).
    @Published var settings: SafetySettings = .default

    /// App UI language preference (persisted). Defaults to following macOS.
    @Published var languagePreference: AppLanguagePreference = .system

    /// Launch-at-login state (the app itself).
    @Published var launchAtLogin = false

    /// Auto-off timer: minutes after which keep-awake turns itself off
    /// (`0` = never). Persisted.
    var autoOffMinutes: Int { autoOff.minutes }
    /// When the active auto-off timer will fire; nil when not counting down.
    var autoOffDeadline: Date? { autoOff.deadline }
    /// Human countdown (e.g. `1:05:09`) shown while a timer is active.
    var autoOffRemaining: String { autoOff.remaining }

    /// Whether the user has finished first-run onboarding (persisted).
    @Published var onboardingComplete = false

    private let helper = HelperManager()
    private let logger = Logger(subsystem: "top.qiyuey.lid", category: "app-state")
    private let emergencyRestorer = EmergencySleepRestorer()
    private let battery = BatteryMonitor()
    private let store = SettingsStore()
    private let loginItem = LoginItemManager()
    private lazy var safety = SafetyMonitor(battery: battery)
    private lazy var autoOff = AutoOffController(store: store)
    private lazy var helperLifecycle = HelperLifecycleController(helper: helper, store: store)
    private lazy var onboarding = OnboardingController(state: self)

    /// Marketing version shown in the menu.
    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var text: AppStrings {
        AppStrings(language: languagePreference.effectiveLanguage)
    }

    var helperUnavailableText: String {
        if helperNeedsApproval {
            return text.approveHelperThenTry
        }
        if helperInstalled {
            return text.helperNoResponse
        }
        return text.installHelperRequiredMessage
    }

    private var alerts: AlertPresenter {
        AlertPresenter(text: text)
    }

    private var helperStatusTimer: Timer?
    private var helperApprovalPollTimer: Timer?
    private var helperApprovalPollDeadline: Date?
    private var helperRecheckInProgress = false
    private var heartbeatTimer: Timer?
    private var lastRequestedHelperWatchdogEnabled: Bool?
    private var automaticHelperRepairGate = AutomaticHelperRepairGate(
        cooldown: Timing.automaticHelperRepairCooldown
    )
    private var stateChangeRequestID = 0

    private enum Timing {
        static let automaticHelperRepairCooldown: TimeInterval = 60
        static let helperReadinessAttempts = 2
        static let helperReadinessRetryDelay: TimeInterval = 1
        static let helperApprovalPollInterval: TimeInterval = 1
        static let helperApprovalPollDuration: TimeInterval = 20
    }

    private var didBecomeActiveObserver: NSObjectProtocol?
    private var localeObserver: NSObjectProtocol?
    private var thermalObserver: NSObjectProtocol?

    init() {
        settings = store.load()
        languagePreference = AppLanguagePreference(rawValue: store.loadLanguagePreference()) ?? .system
        onboardingComplete = store.loadOnboardingComplete()
        configureAutoOff()
        launchAtLogin = loginItem.isEnabled
        refreshHelperStatus()
        helperLifecycle.captureUsableBaseline()
        refreshState()
        refreshHelperUsability(repairIfUnavailable: true, refreshStateWhenUsable: true)
        refreshHelperRegistrationIfNeeded()
        refreshBattery()
        battery.start { [weak self] info in
            Task { @MainActor in
                self?.applyBattery(info)
                self?.evaluateSafety()
            }
        }
        helperStatusTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // Re-check the helper whenever the app comes forward — e.g. when the user
        // returns from approving it in System Settings — so we notice it being
        // enabled without requiring a manual restart.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.recheckHelper(startApprovalPolling: true) }
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
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.evaluateSafety() }
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
            helperStatusTimer?.invalidate()
            helperApprovalPollTimer?.invalidate()
            heartbeatTimer?.invalidate()
            if let didBecomeActiveObserver {
                NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            }
            if let localeObserver {
                NotificationCenter.default.removeObserver(localeObserver)
            }
            if let thermalObserver {
                NotificationCenter.default.removeObserver(thermalObserver)
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

    func updateSettings(_ new: SafetySettings) {
        settings = new
        store.save(new)
        if isEnabled {
            ensureHelperWatchdogEnabled(force: true)
        }
        evaluateSafety()
    }

    func setLanguagePreference(_ preference: AppLanguagePreference) {
        languagePreference = preference
        store.saveLanguagePreference(preference.rawValue)
        objectWillChange.send()
    }

    /// Change the auto-off duration. Re-arms (or cancels) the live timer when
    /// keep-awake is currently on.
    func setAutoOffMinutes(_ minutes: Int) {
        autoOff.setMinutes(minutes, isEnabled: isEnabled)
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

    /// Auto-disable keep-awake if current conditions violate the safety policy.
    func evaluateSafety() {
        guard isEnabled else { return }
        if let reason = safety.reasonToDisable(settings: settings) {
            // Pass the message through so it survives the async helper callback
            // (which would otherwise clear lastError on success).
            setEnabled(false, note: text.safetyAutoPaused(reason))
        }
    }

    // MARK: Helper lifecycle

    func refreshHelperStatus() {
        helperLifecycle.refreshStatus()
        syncHelperStatus()
    }

    /// When the bundled helper version changes, probe the registered daemon and
    /// rebuild launchd's registration if the running helper is missing, stale, or
    /// unreachable. Healthy helpers are left untouched, so app-only updates don't
    /// needlessly prompt for approval.
    private func refreshHelperRegistrationIfNeeded() {
        helperLifecycle.refreshRegistrationIfNeeded { [weak self] in
            self?.repairHelper()
        }
    }

    /// Re-read helper status; if it just became usable (the user approved it while
    /// the app was running), pick up its keep-awake state without interrupting the
    /// current flow.
    func recheckHelper(startApprovalPolling: Bool = false) {
        guard !helperRecheckInProgress else {
            if startApprovalPolling, helperNeedsApproval {
                startHelperApprovalPolling()
            }
            return
        }
        helperRecheckInProgress = true
        helperLifecycle.recheckBecameUsable { [weak self] becameUsable in
            guard let self else { return }
            self.helperRecheckInProgress = false
            self.syncHelperStatus()
            if self.usingHelper {
                self.stopHelperApprovalPolling()
                if becameUsable {
                    self.ensureHelperWatchdogEnabled(force: true)
                }
                self.refreshState()
            } else {
                self.refreshState()
                if self.helperNeedsApproval {
                    self.lastError = self.text.approveHelperPrompt
                    if startApprovalPolling {
                        self.startHelperApprovalPolling()
                    }
                    return
                }
                self.stopHelperApprovalPolling()
                if self.helperInstalled, !self.helperNeedsApproval {
                    self.lastError = self.text.helperNoResponse
                    self.repairHelperAutomatically { [weak self] in
                        self?.refreshHelperUsability(refreshStateWhenUsable: true)
                    }
                }
            }
        }
    }

    func installHelper() {
        // If the daemon is already registered and just awaiting approval, don't
        // re-register (that throws once pending and would swallow the open) —
        // just take the user to Login Items.
        refreshHelperStatus()
        if helperLifecycle.needsApproval {
            openLoginItems()
            return
        }
        if helperLifecycle.installed {
            if helperLifecycle.usingHelper {
                lastError = nil
            } else {
                lastError = text.helperNoResponse
                repairHelper()
            }
            return
        }
        helperLifecycle.register { [weak self] becameUsable, errorMessage in
            guard let self else { return }
            syncHelperStatus()
            if helperLifecycle.needsApproval {
                lastError = text.approveHelperPrompt
                helper.openLoginItemsSettings()
                startHelperApprovalPolling()
                return
            }
            if let errorMessage {
                lastError = errorMessage
                return
            }
            lastError = nil
            ensureHelperWatchdogEnabled(force: true)
            // Rare: registered and immediately usable (already approved). Treat
            // it as the same enable transition the approval path would hit.
            if becameUsable {
                refreshState()
            }
        }
    }

    /// Open System Settings ▸ Login Items so the user can approve the helper.
    /// Kept separate from `installHelper()` so re-registration can never swallow
    /// the open.
    func openLoginItems() {
        lastError = text.approveHelperPrompt
        helper.openLoginItemsSettings()
        refreshHelperStatus()
        startHelperApprovalPolling()
    }

    func uninstallHelper() {
        refreshHelperStatus()
        guard helperLifecycle.installed || helperLifecycle.needsApproval else {
            lastError = nil
            return
        }
        guard alerts.confirmUninstallHelper() else { return }

        restoreSleepBeforeHelperRemoval { [weak self] restored in
            guard let self, restored else { return }
            self.helperLifecycle.unregister { [weak self] errorMessage in
                guard let self else { return }
                self.syncHelperStatus()
                if let errorMessage {
                    self.lastError = errorMessage
                    return
                }
                self.lastError = self.text.helperRemovedMessage
                self.refreshState()
                self.manageHeartbeat()
            }
        }
    }

    private func restoreSleepBeforeHelperRemoval(completion: @escaping (Bool) -> Void) {
        guard isEnabled else {
            completion(true)
            return
        }

        setEnabled(false) { [weak self] ok in
            guard let self else { return }
            if ok {
                completion(true)
                return
            }

            do {
                try self.emergencyRestorer.restoreNormalSleep()
                self.applyObservedEnabledState(false)
                self.lastError = nil
                completion(true)
            } catch {
                self.lastError = error.localizedDescription
                self.alerts.presentHelperUninstallRestoreFailure(message: error.localizedDescription)
                completion(false)
            }
        }
    }

    // MARK: State

    func refreshState() {
        if usingHelper {
            helper.getStateResult { [weak self] value, err in
                guard let self else { return }
                if let err {
                    self.lastError = err
                    self.logger.error("Refresh state failed through helper: \(err, privacy: .public)")
                    self.helperLifecycle.markUnusable()
                    self.syncHelperStatus()
                    self.repairHelperAutomatically { [weak self] in
                        self?.refreshHelperUsability(refreshStateWhenUsable: true)
                    }
                    return
                }
                self.clearHelperAvailabilityMessage()
                self.applyObservedEnabledState(value)
                if value {
                    self.ensureHelperWatchdogEnabled()
                }
            }
        } else {
            let actual = emergencyRestorer.isSleepDisabled()
            applyObservedEnabledState(actual)
            if helperNeedsApproval {
                lastError = text.approveHelperPrompt
            } else if actual {
                lastError = helperUnavailableText
            }
        }
    }

    /// User flipped the toggle: treat it as user-initiated so any failure or
    /// refusal surfaces a visible alert (not just the easy-to-miss inline note).
    func toggle() { setEnabled(!isEnabled, userInitiated: true) }

    /// Set lid sleep prevention. `note` is shown to the user on a successful change
    /// (used when an auto-pause or the auto-off timer disables it); nil clears
    /// any prior message. When `userInitiated` is true (the user flipped the
    /// toggle), a failure or policy refusal also pops a blocking alert so it
    /// can't go unnoticed; background callers leave it false to stay quiet.
    func setEnabled(_ target: Bool,
                    note: String? = nil,
                    userInitiated: Bool = false,
                    completion: ((Bool) -> Void)? = nil) {
        // Refuse to enable if it would immediately violate the safety policy.
        if target {
            if let blocker = safety.reasonToDisable(settings: settings) {
                lastError = text.safetyAutoPaused(blocker)
                if userInitiated {
                    alerts.presentToggleFailure(target: target, message: text.safetyBlocked(blocker))
                }
                completion?(false)
                return
            }
        }
        let resultMessage = note
        if usingHelper {
            let requestID = beginStateChange()
            helper.setKeepAwake(target) { [weak self] ok, err in
                guard let self, self.isCurrentStateChange(requestID) else { return }
                if ok {
                    self.confirmHelperState(
                        target: target,
                        resultMessage: resultMessage,
                        userInitiated: userInitiated,
                        requestID: requestID,
                        completion: completion
                    )
                } else {
                    // The helper can fail without a message (e.g. a dropped XPC
                    // reply, or the daemon failing to launch after an update);
                    // surface it instead of letting the toggle silently no-op.
                    let message = err ?? self.text.helperNoResponse
                    self.lastError = message
                    self.helperLifecycle.markUnusable()
                    self.syncHelperStatus()
                    if userInitiated {
                        self.alerts.presentHelperFailure(message: message) { [weak self] in
                            self?.repairHelper()
                        }
                    }
                    self.finishStateChange(requestID)
                    self.refreshState()
                    completion?(false)
                }
            }
        } else {
            let actual = emergencyRestorer.isSleepDisabled()
            applyObservedEnabledState(actual)
            if !target, !actual {
                lastError = resultMessage
                completion?(true)
                return
            }

            let message = helperUnavailableText
            lastError = message
            if userInitiated {
                alerts.presentToggleFailure(target: target, message: message)
            }
            completion?(false)
        }
    }

    /// User-requested quit: clear the keep-awake flag first when it is active,
    /// then exit. If restore fails, make the user choose whether to quit anyway.
    func quit() {
        guard isEnabled else {
            NSApp.terminate(nil)
            return
        }

        if settings.continueAfterQuit {
            continueAwakeAfterQuit()
            return
        }

        setEnabled(false) { [weak self] ok in
            guard let self else { return }
            if ok {
                NSApp.terminate(nil)
            } else {
                self.alerts.presentQuitAfterRestoreFailure {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func continueAwakeAfterQuit() {
        guard usingHelper else {
            NSApp.terminate(nil)
            return
        }

        helper.setWatchdogEnabled(false) { [weak self] ok, err in
            guard let self else { return }
            if !ok {
                self.lastError = err ?? self.text.continueAfterQuitHelperError
            }
            NSApp.terminate(nil)
        }
    }

    /// Re-register the privileged helper to refresh launchd's record, then report
    /// the outcome. Used both automatically after a helper-version mismatch and
    /// from the failure alert's "Reinstall Helper" action.
    func repairHelper() {
        repairHelper(showSuccessMessage: true)
    }

    private func repairHelper(showSuccessMessage: Bool,
                              afterRepair: (() -> Void)? = nil,
                              completion: (() -> Void)? = nil) {
        helperLifecycle.repair { [weak self] errorMessage in
            guard let self else { return }
            self.syncHelperStatus()
            if self.helperLifecycle.needsApproval {
                self.logger.info("Helper repair completed but approval is required")
                self.lastError = self.text.approveHelperThenTry
                if showSuccessMessage {
                    self.helper.openLoginItemsSettings()
                }
                self.startHelperApprovalPolling()
                completion?()
            } else if let errorMessage {
                self.logger.error("Helper repair failed: \(errorMessage, privacy: .public)")
                self.lastError = errorMessage
                completion?()
            } else {
                self.logger.info("Helper repair completed")
                self.ensureHelperWatchdogEnabled(force: true)
                self.lastError = showSuccessMessage ? self.text.helperReinstalledMessage : nil
                afterRepair?()
                completion?()
            }
        }
    }

    private func repairHelperAutomatically(afterRepair: (() -> Void)? = nil) {
        if automaticHelperRepairGate.isRepairInProgress {
            logger.info("Skipping automatic helper repair because repair is already running")
            return
        }

        refreshHelperStatus()
        guard helperInstalled else {
            logger.info("Skipping automatic helper repair because helper is not installed")
            lastError = helperNeedsApproval ? text.approveHelperThenTry : text.installHelperRequiredMessage
            return
        }

        guard automaticHelperRepairGate.beginIfAllowed(
            now: Date(),
            helperInstalled: helperInstalled,
            helperNeedsApproval: helperNeedsApproval
        ) else {
            logger.info("Skipping automatic helper repair")
            return
        }

        logger.info("Starting automatic helper repair")
        repairHelper(showSuccessMessage: false,
                     afterRepair: afterRepair) { [weak self] in
            self?.automaticHelperRepairGate.finish()
        }
    }

    private func refreshHelperUsability(repairIfUnavailable: Bool = false,
                                        refreshStateWhenUsable: Bool = false) {
        let maxAttempts = repairIfUnavailable ? Timing.helperReadinessAttempts : 1
        helperLifecycle.refreshUsability(
            maxAttempts: maxAttempts,
            retryDelay: Timing.helperReadinessRetryDelay
        ) { [weak self] usable in
            guard let self else { return }
            self.syncHelperStatus()
            if usable {
                self.ensureHelperWatchdogEnabled()
                if refreshStateWhenUsable {
                    self.refreshState()
                }
                return
            }

            self.refreshState()
            if self.helperNeedsApproval {
                self.lastError = self.text.approveHelperPrompt
                self.startHelperApprovalPolling()
                return
            }
            self.stopHelperApprovalPolling()
            guard repairIfUnavailable, self.helperInstalled, !self.helperNeedsApproval else {
                return
            }

            self.lastError = self.text.helperNoResponse
            self.repairHelperAutomatically { [weak self] in
                self?.refreshHelperUsability(refreshStateWhenUsable: true)
            }
        }
    }

    private func syncHelperStatus() {
        helperInstalled = helperLifecycle.installed
        helperNeedsApproval = helperLifecycle.needsApproval
        usingHelper = helperLifecycle.usingHelper
    }

    private func clearHelperAvailabilityMessage() {
        guard let lastError else { return }
        let helperAvailabilityMessages = [
            text.approveHelperPrompt,
            text.approveHelperThenTry,
            text.helperNoResponse,
            text.installHelperRequiredMessage
        ]
        if helperAvailabilityMessages.contains(lastError) {
            self.lastError = nil
        }
    }

    private func startHelperApprovalPolling() {
        helperApprovalPollDeadline = Date().addingTimeInterval(Timing.helperApprovalPollDuration)
        guard helperApprovalPollTimer == nil else { return }
        helperApprovalPollTimer = Timer.scheduledTimer(
            withTimeInterval: Timing.helperApprovalPollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.pollHelperApproval() }
        }
    }

    private func pollHelperApproval() {
        if usingHelper || !helperNeedsApproval {
            stopHelperApprovalPolling()
            return
        }

        guard let deadline = helperApprovalPollDeadline, Date() <= deadline else {
            stopHelperApprovalPolling()
            return
        }

        recheckHelper()
    }

    private func stopHelperApprovalPolling() {
        helperApprovalPollTimer?.invalidate()
        helperApprovalPollTimer = nil
        helperApprovalPollDeadline = nil
    }

    private func ensureHelperWatchdogEnabled(force: Bool = false) {
        guard usingHelper else {
            lastRequestedHelperWatchdogEnabled = nil
            return
        }

        let watchdogEnabled = true
        guard force || lastRequestedHelperWatchdogEnabled != watchdogEnabled else { return }
        lastRequestedHelperWatchdogEnabled = watchdogEnabled
        helper.setWatchdogEnabled(watchdogEnabled) { [weak self] ok, err in
            guard let self else { return }
            if !ok {
                self.lastRequestedHelperWatchdogEnabled = nil
                self.lastError = err ?? self.text.watchdogPolicyError
                self.logger.error("Failed to update helper watchdog policy: \(self.lastError ?? "unknown", privacy: .public)")
                self.repairHelperAutomatically()
            }
        }
    }

    // MARK: Heartbeat (keeps the helper watchdog satisfied)

    private func manageHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        guard isEnabled, usingHelper else { return }
        helper.heartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.helper.heartbeat() }
        }
    }

    // MARK: Auto-off timer

    private func configureAutoOff() {
        autoOff.onChange = { [weak self] in
            self?.objectWillChange.send()
        }
        autoOff.onExpired = { [weak self] minutes in
            guard let self else { return }
            self.setEnabled(false, note: self.text.autoOffExpired(minutes: minutes))
        }
    }

    /// Arm when lid sleep prevention turns on, cancel when it turns off.
    private func updateAutoOff(for enabled: Bool) {
        autoOff.update(for: enabled)
    }

    // MARK: Battery + safety guard

    func tick() {
        // Backstop for the didBecomeActive observer: catch a helper approval even
        // if the app never lost/regained active state.
        recheckHelper()
    }

    func menuDidAppear() {
        recheckHelper(startApprovalPolling: true)
    }

    func refreshBattery() {
        applyBattery(battery.read())
    }

    private func applyBattery(_ info: BatteryInfo) {
        batteryPercent = info.percent
        batteryOnAC = info.onAC
    }

    private func confirmHelperState(target: Bool,
                                    resultMessage: String?,
                                    userInitiated: Bool,
                                    requestID: Int,
                                    completion: ((Bool) -> Void)?) {
        helper.getStateResult { [weak self] actual, err in
            guard let self, self.isCurrentStateChange(requestID) else { return }

            if let err {
                self.lastError = err
                self.logger.error("Confirm helper state failed: \(err, privacy: .public)")
                self.helperLifecycle.markUnusable()
                self.syncHelperStatus()
                if userInitiated {
                    self.alerts.presentHelperFailure(message: err) { [weak self] in
                        self?.repairHelper()
                    }
                } else {
                    self.repairHelperAutomatically {
                        self.refreshState()
                    }
                }
                self.finishStateChange(requestID)
                completion?(false)
                return
            }

            self.applyObservedEnabledState(actual)

            guard actual == target else {
                let message = self.text.helperStateMismatch(target: target)
                self.lastError = message
                if userInitiated {
                    self.alerts.presentHelperFailure(message: message) { [weak self] in
                        self?.repairHelper()
                    }
                }
                self.finishStateChange(requestID)
                completion?(false)
                return
            }

            self.lastError = resultMessage
            if actual {
                self.ensureHelperWatchdogEnabled(force: true)
            }
            self.finishStateChange(requestID)
            completion?(true)
        }
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
        let changed = isEnabled != value
        isEnabled = value

        if changed {
            manageHeartbeat()
            updateAutoOff(for: value)
        } else if value, usingHelper, heartbeatTimer == nil {
            manageHeartbeat()
        }
    }
}
