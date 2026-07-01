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

extension HelperManager: HelperManaging {}

@MainActor
final class HelperLifecycleController {
    private let helper: HelperManaging
    private let store: SettingsStore
    private let currentBuild: () -> String
    private var usableBaseline = false

    private(set) var installed = false
    private(set) var needsApproval = false
    private(set) var usingHelper = false

    init(helper: HelperManaging,
         store: SettingsStore,
         currentBuild: @escaping () -> String = {
             Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
         }) {
        self.helper = helper
        self.store = store
        self.currentBuild = currentBuild
    }

    func refreshStatus() {
        installed = helper.isEnabled
        needsApproval = helper.requiresApproval
        usingHelper = installed
    }

    func captureUsableBaseline() {
        usableBaseline = usingHelper
    }

    func refreshRegistrationIfUpdated(onRepairNeeded: @escaping @MainActor @Sendable () -> Void) {
        let build = currentBuild()
        guard !build.isEmpty else { return }
        guard store.loadLastHelperBuild() != build else { return }
        storeCurrentBuild()
        guard helper.isEnabled else { return }
        helper.checkReachable { reachable in
            guard !reachable else { return }
            onRepairNeeded()
        }
    }

    func recheckBecameUsable() -> Bool {
        let wasUsable = usableBaseline
        refreshStatus()
        usableBaseline = usingHelper
        return !wasUsable && usingHelper
    }

    func register() throws -> Bool {
        let wasUsable = usableBaseline
        try helper.register()
        refreshStatus()
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
            self.storeCurrentBuild()
            completion(errorMessage)
        }
    }

    func storeCurrentBuild() {
        store.saveLastHelperBuild(currentBuild())
    }
}
