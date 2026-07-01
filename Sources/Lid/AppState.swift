import AppKit
import SwiftUI
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isEnabled = false
    @Published var helperInstalled = false
    @Published var helperNeedsApproval = false
    @Published var batteryDescription = ""
    /// Current battery charge (0–100) and whether on AC power. Drives the
    /// popover status strip (icon + "Battery 74%").
    @Published var batteryPercent = 0
    @Published var batteryOnAC = false
    @Published var lastError: String?

    /// True when using the privileged helper; false when on the M1 admin-prompt fallback.
    @Published var usingHelper = false

    /// User-tunable safety preferences (persisted).
    @Published var settings: SafetySettings = .default

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
    private let fallback = PowerManager()
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
    private var helperStatusTimer: Timer?
    private var heartbeatTimer: Timer?

    /// True while the onboarding window is open and not yet completed.
    private var onboardingActive = false
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var thermalObserver: NSObjectProtocol?

    init() {
        settings = store.load()
        onboardingComplete = store.loadOnboardingComplete()
        configureAutoOff()
        launchAtLogin = loginItem.isEnabled
        refreshHelperStatus()
        refreshHelperRegistrationIfUpdated()
        helperLifecycle.captureUsableBaseline()
        refreshState()
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
            Task { @MainActor in self?.recheckHelper() }
        }
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.evaluateSafety() }
        }
        // First launch shows onboarding once (persisted so closing it early won't
        // re-nag). A relaunch triggered mid-onboarding resumes the flow instead.
        if store.loadResumeOnboarding() {
            store.saveResumeOnboarding(false)
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        } else if !onboardingComplete {
            onboardingComplete = true
            store.saveOnboardingComplete(true)
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        }
    }

    deinit {
        helperStatusTimer?.invalidate()
        heartbeatTimer?.invalidate()
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let thermalObserver {
            NotificationCenter.default.removeObserver(thermalObserver)
        }
    }

    // MARK: Onboarding

    /// Present the first-run setup window (also reachable from Settings).
    func showOnboarding() {
        onboardingActive = true
        onboarding.show()
    }

    /// Mark onboarding done, persist it, and close the window.
    func completeOnboarding() {
        onboardingActive = false
        onboardingComplete = true
        store.saveOnboardingComplete(true)
        store.saveResumeOnboarding(false)
        onboarding.close()
    }

    // MARK: Settings

    func updateSettings(_ new: SafetySettings) {
        settings = new
        store.save(new)
        evaluateSafety()
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
            setEnabled(false, note: reason.message)
        }
    }

    // MARK: Helper lifecycle

    func refreshHelperStatus() {
        helperLifecycle.refreshStatus()
        syncHelperStatus()
    }

    /// After an app update the helper binary is re-signed and its launchd job can
    /// keep a stale launch record, so the daemon fails to start (EX_CONFIG) and
    /// XPC calls hang — the toggle then silently does nothing. On the first launch
    /// of a new build, probe the registered daemon; only if it's unreachable do we
    /// rebuild its registration (which may require re-approval). Healthy updates
    /// are left untouched, so they don't needlessly prompt for approval.
    private func refreshHelperRegistrationIfUpdated() {
        helperLifecycle.refreshRegistrationIfUpdated { [weak self] in
            self?.repairHelper()
        }
    }

    /// Re-read helper status; if it just became usable (the user approved it while
    /// the app was running), pick up its keep-awake state and prompt a restart so
    /// the app fully switches onto the privileged helper.
    func recheckHelper() {
        let becameUsable = helperLifecycle.recheckBecameUsable()
        syncHelperStatus()
        guard becameUsable else { return }
        refreshState()
        promptRestartAfterHelperEnabled()
    }

    /// Tell the user the helper is now active and offer to relaunch. The privileged
    /// XPC connection is most reliable from a fresh launch, so a restart is the
    /// simplest way to finish setup.
    private func promptRestartAfterHelperEnabled() {
        // If this happened mid-onboarding, resume the flow after the relaunch.
        if onboardingActive { store.saveResumeOnboarding(true) }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Background helper enabled"
        alert.informativeText = "Restart Lid to finish connecting to the background helper."
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            relaunch()
        }
    }

    /// Spawn a fresh instance of the app, then terminate this one.
    private func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
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
        do {
            let becameUsable = try helperLifecycle.register()
            syncHelperStatus()
            if helperLifecycle.needsApproval {
                lastError = "Approve Lid in System Settings ▸ Login Items."
                helper.openLoginItemsSettings()
            } else {
                lastError = nil
                // Rare: registered and immediately usable (already approved). Treat
                // it as the same enable transition the approval path would hit.
                if becameUsable {
                    refreshState()
                    promptRestartAfterHelperEnabled()
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Open System Settings ▸ Login Items so the user can approve the helper.
    /// Kept separate from `installHelper()` so re-registration can never swallow
    /// the open.
    func openLoginItems() {
        lastError = "Approve Lid in System Settings ▸ Login Items."
        helper.openLoginItemsSettings()
        refreshHelperStatus()
    }

    func uninstallHelper() {
        refreshHelperStatus()
        guard helperLifecycle.installed || helperLifecycle.needsApproval else {
            lastError = nil
            return
        }
        guard confirmUninstallHelper() else { return }

        restoreSleepBeforeHelperRemoval { [weak self] restored in
            guard let self, restored else { return }
            self.helperLifecycle.unregister { [weak self] error in
                guard let self else { return }
                self.syncHelperStatus()
                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                self.lastError = "Background helper removed. Lid will use the administrator prompt until you install it again."
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
                try self.fallback.setSleepDisabled(false)
                self.isEnabled = false
                self.lastError = nil
                self.manageHeartbeat()
                self.updateAutoOff(for: false)
                completion(true)
            } catch {
                self.lastError = error.localizedDescription
                self.presentHelperUninstallRestoreFailureAlert(message: error.localizedDescription)
                completion(false)
            }
        }
    }

    // MARK: State

    func refreshState() {
        if helperInstalled {
            helper.getState { [weak self] value in self?.isEnabled = value }
        } else {
            isEnabled = fallback.isSleepDisabled()
        }
    }

    /// User flipped the toggle: treat it as user-initiated so any failure or
    /// refusal surfaces a visible alert (not just the easy-to-miss inline note).
    func toggle() { setEnabled(!isEnabled, userInitiated: true) }

    /// Set keep-awake. `note` is shown to the user on a successful change
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
                lastError = blocker.message
                if userInitiated {
                    presentFailureAlert(target: target, message: blocker.blockedMessage)
                }
                completion?(false)
                return
            }
        }
        let resultMessage = note
        if helperInstalled {
            helper.setKeepAwake(target) { [weak self] ok, err in
                guard let self else { return }
                if ok {
                    self.isEnabled = target
                    self.lastError = resultMessage
                    self.manageHeartbeat()
                    self.updateAutoOff(for: target)
                    completion?(true)
                } else {
                    // The helper can fail without a message (e.g. a dropped XPC
                    // reply, or the daemon failing to launch after an update);
                    // surface it instead of letting the toggle silently no-op.
                    let message = err ?? "The background helper didn’t respond."
                    self.lastError = message
                    if userInitiated { self.presentHelperFailureAlert(message: message) }
                    self.refreshState()
                    completion?(false)
                }
            }
        } else {
            do {
                try fallback.setSleepDisabled(target)
                isEnabled = target
                lastError = resultMessage
                updateAutoOff(for: target)
                completion?(true)
            } catch {
                lastError = error.localizedDescription
                if userInitiated { presentFailureAlert(target: target, message: error.localizedDescription) }
                isEnabled = fallback.isSleepDisabled()
                completion?(false)
            }
        }
    }

    /// User-requested quit: clear the keep-awake flag first when it is active,
    /// then exit. If restore fails, make the user choose whether to quit anyway.
    func quit() {
        guard isEnabled else {
            NSApp.terminate(nil)
            return
        }

        setEnabled(false) { [weak self] ok in
            guard let self else { return }
            if ok {
                NSApp.terminate(nil)
            } else {
                self.presentQuitAfterRestoreFailureAlert()
            }
        }
    }

    private func presentQuitAfterRestoreFailureAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t turn keep-awake off"
        alert.informativeText = "Lid could not restore normal sleep before quitting. Quit anyway and let the background watchdog restore it shortly?"
        alert.addButton(withTitle: "Quit Anyway")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    private func confirmUninstallHelper() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove background helper?"
        alert.informativeText = "Lid will restore normal sleep first, then remove its privileged helper. Future toggles will use the administrator prompt until you install the helper again."
        alert.addButton(withTitle: "Remove Helper")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentHelperUninstallRestoreFailureAlert(message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t remove background helper"
        alert.informativeText = "Lid could not restore normal sleep, so the helper was left installed.\n\n\(message)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Pop a blocking alert when a user-initiated toggle can't be applied, so the
    /// reason is impossible to miss. The inline `lastError` note still persists in
    /// the popover after the alert is dismissed.
    private func presentFailureAlert(target: Bool, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = target ? "Couldn’t keep your Mac awake" : "Couldn’t turn keep-awake off"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// The helper is registered but didn't respond — almost always a stale
    /// registration after an app update (launchd refuses to launch the new
    /// binary). Offer a one-click reinstall, which re-registers and refreshes
    /// that record.
    private func presentHelperFailureAlert(message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t keep your Mac awake"
        alert.informativeText = "\(message)\n\nThis usually happens after an update. Reinstalling the background helper fixes it."
        alert.addButton(withTitle: "Reinstall Helper…")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            repairHelper()
        }
    }

    /// Re-register the privileged helper to refresh launchd's record, then report
    /// the outcome. Used both automatically (after a detected app update) and from
    /// the failure alert's "Reinstall Helper" action.
    func repairHelper() {
        helperLifecycle.repair { [weak self] error in
            guard let self else { return }
            self.syncHelperStatus()
            if let error {
                self.lastError = error.localizedDescription
            } else if self.helperLifecycle.needsApproval {
                self.lastError = "Approve Lid in System Settings ▸ Login Items, then try the switch again."
                self.helper.openLoginItemsSettings()
            } else {
                self.lastError = "Background helper reinstalled — try the switch again."
            }
        }
    }

    private func syncHelperStatus() {
        helperInstalled = helperLifecycle.installed
        helperNeedsApproval = helperLifecycle.needsApproval
        usingHelper = helperLifecycle.usingHelper
    }

    // MARK: Heartbeat (keeps the helper watchdog satisfied)

    private func manageHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        guard isEnabled, helperInstalled else { return }
        helper.heartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.helper.heartbeat() }
        }
    }

    // MARK: Auto-off timer

    private func configureAutoOff() {
        autoOff.onChange = { [weak self] in
            Task { @MainActor in self?.objectWillChange.send() }
        }
        autoOff.onExpired = { [weak self] note in
            Task { @MainActor in self?.setEnabled(false, note: note) }
        }
    }

    /// Arm when keep-awake turns on, cancel when it turns off.
    private func updateAutoOff(for enabled: Bool) {
        autoOff.update(for: enabled)
    }

    // MARK: Battery + safety guard

    func tick() {
        // Backstop for the didBecomeActive observer: catch a helper approval even
        // if the app never lost/regained active state.
        recheckHelper()
    }

    func refreshBattery() {
        applyBattery(battery.read())
    }

    private func applyBattery(_ info: BatteryInfo) {
        batteryPercent = info.percent
        batteryOnAC = info.onAC
        batteryDescription = "\(info.source) · \(info.percent)%"
    }
}
