import Foundation

@MainActor
protocol HelperManaging: AnyObject {
    var isEnabled: Bool { get }
    var requiresApproval: Bool { get }

    func register() throws
    func unregister(completion: @escaping @MainActor @Sendable (String?) -> Void)
    func checkReachable(completion: @escaping @MainActor @Sendable (Bool) -> Void)
}

@MainActor
final class HelperLifecycleController {
    private let helper: HelperManaging
    private var usableBaseline = false

    private enum Timing {
        static let registrationReachabilityAttempts = 8
        static let registrationReachabilityRetryDelay: TimeInterval = 2
    }

    private(set) var installed = false
    private(set) var needsApproval = false
    private(set) var usingHelper = false

    init(helper: HelperManaging) {
        self.helper = helper
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
                completion(true)
            } else if attemptsRemaining > 1, self.installed, !self.needsApproval {
                self.retryRefreshUsability(
                    attemptsRemaining: attemptsRemaining - 1,
                    retryDelay: retryDelay,
                    completion: completion
                )
            } else {
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

    func recheckBecameUsable(maxAttempts: Int = 1,
                             retryDelay: TimeInterval = 1,
                             completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let wasUsable = usableBaseline
        refreshUsability(maxAttempts: maxAttempts, retryDelay: retryDelay) { [weak self] usable in
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
            }
            completion(errorMessage)
        }
    }
}
