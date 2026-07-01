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
    private var usableBaseline = false

    private(set) var installed = false
    private(set) var needsApproval = false
    private(set) var usingHelper = false

    init(helper: HelperManaging, store: SettingsStore) {
        self.helper = helper
        self.store = store
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
        "helper-\(LidHelperIdentity.helperVersion)"
    }
}
