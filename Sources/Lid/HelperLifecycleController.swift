import Foundation

protocol HelperManaging: AnyObject {
    var isEnabled: Bool { get }
    var requiresApproval: Bool { get }

    func register() throws
    func unregister(completion: @escaping (Error?) -> Void)
    func reregister(completion: @escaping (Error?) -> Void)
    func checkReachable(completion: @escaping (Bool) -> Void)
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

    func refreshRegistrationIfUpdated(onRepairNeeded: @escaping () -> Void) {
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

    func unregister(completion: @escaping (Error?) -> Void) {
        helper.unregister { [weak self] error in
            guard let self else {
                completion(error)
                return
            }
            self.refreshStatus()
            if error == nil {
                self.usableBaseline = false
            }
            completion(error)
        }
    }

    func repair(completion: @escaping (Error?) -> Void) {
        helper.reregister { [weak self] error in
            guard let self else {
                completion(error)
                return
            }
            self.refreshStatus()
            self.storeCurrentBuild()
            completion(error)
        }
    }

    func storeCurrentBuild() {
        store.saveLastHelperBuild(currentBuild())
    }
}
