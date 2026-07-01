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
        usingHelper = installed
    }

    func captureUsableBaseline() {
        usableBaseline = usingHelper
    }

    func refreshRegistrationIfNeeded(onRepairNeeded: @escaping @MainActor @Sendable () -> Void) {
        let fingerprint = helperRegistrationFingerprint()
        guard store.loadLastHelperVersion() != fingerprint else { return }
        guard helper.isEnabled else { return }
        helper.checkReachable { [weak self] reachable in
            guard let self else { return }
            if reachable {
                self.storeCurrentHelperVersion()
                return
            }
            onRepairNeeded()
        }
    }

    func recheckBecameUsable() -> Bool {
        let wasUsable = usableBaseline
        refreshStatus()
        if usingHelper {
            storeCurrentHelperVersion()
        }
        usableBaseline = usingHelper
        return !wasUsable && usingHelper
    }

    func register() throws -> Bool {
        let wasUsable = usableBaseline
        try helper.register()
        refreshStatus()
        if usingHelper {
            storeCurrentHelperVersion()
        }
        usableBaseline = usingHelper
        return !wasUsable && usingHelper
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

    func repair(completion: @escaping @MainActor @Sendable (String?) -> Void) {
        helper.reregister { [weak self] errorMessage in
            guard let self else {
                completion(errorMessage)
                return
            }
            self.refreshStatus()
            if errorMessage == nil, self.usingHelper {
                self.storeCurrentHelperVersion()
            }
            completion(errorMessage)
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
