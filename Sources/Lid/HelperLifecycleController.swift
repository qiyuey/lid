import Foundation

@MainActor
protocol HelperManaging: AnyObject {
    var isEnabled: Bool { get }
    var requiresApproval: Bool { get }

    func register() throws
    func unregister(completion: @escaping @MainActor @Sendable (String?) -> Void)
    func reregister(completion: @escaping @MainActor @Sendable (String?) -> Void)
    func checkReachable(completion: @escaping @MainActor @Sendable (Bool) -> Void)
}

@MainActor
final class HelperLifecycleController {
    private let helper: HelperManaging
    private let store: SettingsStore
    private let registrationFingerprint: @MainActor () -> String
    private var usableBaseline = false

    private enum Timing {
        static let registrationReachabilityAttempts = 8
        static let registrationReachabilityRetryDelay: TimeInterval = 2
        static let statusReachabilityAttempts = 2
        static let statusReachabilityRetryDelay: TimeInterval = 1
    }

    private(set) var installed = false
    private(set) var needsApproval = false
    private(set) var usingHelper = false

    init(helper: HelperManaging,
         store: SettingsStore,
         registrationFingerprint: @escaping @MainActor () -> String = HelperLifecycleController.defaultRegistrationFingerprint) {
        self.helper = helper
        self.store = store
        self.registrationFingerprint = registrationFingerprint
    }

    func refreshStatus() {
        installed = helper.isEnabled
        needsApproval = helper.requiresApproval
        if !installed || needsApproval {
            usingHelper = false
        }
    }

    func captureUsableBaseline() {
        usableBaseline = usingHelper
    }

    func markUnusable() {
        usingHelper = false
        usableBaseline = false
    }

    func refreshUsability(maxAttempts: Int = 1,
                          retryDelay: TimeInterval = 1,
                          completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        refreshUsabilityAttempt(
            attemptsRemaining: max(1, maxAttempts),
            retryDelay: retryDelay,
            completion: completion
        )
    }

    private func refreshUsabilityAttempt(attemptsRemaining: Int,
                                         retryDelay: TimeInterval,
                                         completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        refreshStatus()
        guard installed, !needsApproval else {
            completion(false)
            return
        }

        helper.checkReachable { [weak self] reachable in
            guard let self else {
                completion(false)
                return
            }

            self.refreshStatus()
            self.usingHelper = self.installed && !self.needsApproval && reachable
            if self.usingHelper {
                self.storeCurrentHelperVersion()
                completion(true)
            } else if attemptsRemaining > 1, self.installed, !self.needsApproval {
                self.retryRefreshUsability(
                    attemptsRemaining: attemptsRemaining - 1,
                    retryDelay: retryDelay,
                    completion: completion
                )
            } else {
                self.clearStoredHelperVersion()
                completion(false)
            }
        }
    }

    private func retryRefreshUsability(attemptsRemaining: Int,
                                       retryDelay: TimeInterval,
                                       completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard retryDelay > 0 else {
            refreshUsabilityAttempt(
                attemptsRemaining: attemptsRemaining,
                retryDelay: retryDelay,
                completion: completion
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            Task { @MainActor in
                self?.refreshUsabilityAttempt(
                    attemptsRemaining: attemptsRemaining,
                    retryDelay: retryDelay,
                    completion: completion
                )
            }
        }
    }

    func refreshRegistrationIfNeeded(
        maxAttempts: Int = Timing.statusReachabilityAttempts,
        retryDelay: TimeInterval = Timing.statusReachabilityRetryDelay,
        onRepairNeeded: @escaping @MainActor @Sendable () -> Void
    ) {
        let fingerprint = helperRegistrationFingerprint()
        guard store.loadLastHelperVersion() != fingerprint else { return }
        guard helper.isEnabled else { return }
        refreshUsability(
            maxAttempts: maxAttempts,
            retryDelay: retryDelay
        ) { usable in
            guard !usable else { return }
            onRepairNeeded()
        }
    }

    func recheckBecameUsable(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let wasUsable = usableBaseline
        refreshUsability { [weak self] usable in
            guard let self else {
                completion(false)
                return
            }
            self.usableBaseline = usable
            completion(!wasUsable && usable)
        }
    }

    func register(maxAttempts: Int = Timing.registrationReachabilityAttempts,
                  retryDelay: TimeInterval = Timing.registrationReachabilityRetryDelay,
                  completion: @escaping @MainActor @Sendable (Bool, String?) -> Void) {
        let wasUsable = usableBaseline
        do {
            try helper.register()
        } catch {
            refreshStatus()
            if needsApproval {
                usableBaseline = false
                completion(false, nil)
            } else {
                completion(false, error.localizedDescription)
            }
            return
        }

        refreshUsability(maxAttempts: maxAttempts, retryDelay: retryDelay) { [weak self] usable in
            guard let self else {
                completion(false, nil)
                return
            }
            self.usableBaseline = usable
            completion(!wasUsable && usable, nil)
        }
    }

    func unregister(completion: @escaping @MainActor @Sendable (String?) -> Void) {
        helper.unregister { [weak self] errorMessage in
            guard let self else {
                completion(errorMessage)
                return
            }
            self.refreshStatus()
            if errorMessage == nil {
                self.usableBaseline = false
                self.clearStoredHelperVersion()
            }
            completion(errorMessage)
        }
    }

    func repair(maxAttempts: Int = Timing.registrationReachabilityAttempts,
                retryDelay: TimeInterval = Timing.registrationReachabilityRetryDelay,
                completion: @escaping @MainActor @Sendable (String?) -> Void) {
        helper.reregister { [weak self] errorMessage in
            guard let self else {
                completion(errorMessage)
                return
            }
            self.refreshStatus()
            guard errorMessage == nil else {
                if self.needsApproval {
                    self.usableBaseline = false
                    completion(nil)
                } else {
                    completion(errorMessage)
                }
                return
            }

            guard self.installed, !self.needsApproval else {
                self.usableBaseline = false
                completion(nil)
                return
            }

            self.refreshUsability(maxAttempts: maxAttempts, retryDelay: retryDelay) { [weak self] usable in
                guard let self else {
                    completion(nil)
                    return
                }
                self.usableBaseline = usable
                if usable {
                    completion(nil)
                } else {
                    completion("The background helper isn’t responding.")
                }
            }
        }
    }

    func storeCurrentHelperVersion() {
        store.saveLastHelperVersion(helperRegistrationFingerprint())
    }

    private func clearStoredHelperVersion() {
        store.clearLastHelperVersion()
    }

    private func helperRegistrationFingerprint() -> String {
        registrationFingerprint()
    }

    private static func defaultRegistrationFingerprint() -> String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let certificateSHA1 = bundledHelperEnvironmentValue(
            LidHelperIdentity.allowedClientCertificateSHA1EnvKey,
            bundle: bundle
        ) ?? "none"
        return "helper-\(LidHelperIdentity.helperVersion)|version-\(version)|build-\(build)|cert-\(certificateSHA1)"
    }

    private static func bundledHelperEnvironmentValue(_ key: String, bundle: Bundle) -> String? {
        guard let appBundleID = bundle.bundleIdentifier else { return nil }
        let helperLabel = LidHelperIdentity.label(appBundleID: appBundleID)
        let plistURL = bundle.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons")
            .appendingPathComponent("\(helperLabel).plist")
        guard let plist = NSDictionary(contentsOf: plistURL),
              let environment = plist["EnvironmentVariables"] as? [String: String],
              let value = environment[key],
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
