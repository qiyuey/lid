import Foundation

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = HelperService()
    private let clientRequirement: String

    init(clientRequirement: String) {
        self.clientRequirement = clientRequirement
    }

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.setCodeSigningRequirement(clientRequirement)
        newConnection.exportedInterface = NSXPCInterface(with: LidHelperProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}

/// The actual privileged work. Runs as root, so it can call `pmset` directly
/// with no admin prompt. Guards against a stuck-awake state with a watchdog.
final class HelperService: NSObject, LidHelperProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "top.qiyuey.lid.helper.state")
    private var lastHeartbeat = Date()
    private var keepAwake = false
    private var watchdogEnabled = true
    private let watchdogTimeout: TimeInterval = 90
    private var watchdogTimer: DispatchSourceTimer?

    private enum Verification {
        static let attempts = 5
        static let retryDelay: TimeInterval = 0.1
    }

    override init() {
        super.init()
        startWatchdog()
    }

    // MARK: LidHelperProtocol

    func setKeepAwake(_ enabled: Bool, withReply reply: @escaping @Sendable (Bool, String?) -> Void) {
        queue.async {
            let result = self.runPmset(disableSleep: enabled)
            if result.ok {
                self.keepAwake = enabled
                self.lastHeartbeat = Date()
                if enabled {
                    self.watchdogEnabled = true
                }
            }
            reply(result.ok, result.error)
        }
    }

    func setWatchdogEnabled(_ enabled: Bool, withReply reply: @escaping @Sendable (Bool, String?) -> Void) {
        queue.async {
            self.watchdogEnabled = enabled
            if enabled {
                self.lastHeartbeat = Date()
            }
            reply(true, nil)
        }
    }

    func getState(withReply reply: @escaping @Sendable (Bool) -> Void) {
        queue.async {
            reply(self.syncRuntimeStateFromSystem() ?? false)
        }
    }

    func heartbeat(withReply reply: @escaping @Sendable (Bool) -> Void) {
        queue.async {
            self.syncRuntimeStateFromSystem()
            self.lastHeartbeat = Date()
            reply(true)
        }
    }

    func version(withReply reply: @escaping @Sendable (String) -> Void) {
        reply(LidHelperIdentity.versionString(bundle: .main))
    }

    // MARK: Watchdog

    private func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.keepAwake, self.watchdogEnabled else { return }
            if Watchdog.shouldAutoRestore(lastHeartbeat: self.lastHeartbeat,
                                          now: Date(),
                                          timeout: self.watchdogTimeout) {
                let result = self.runPmset(disableSleep: false)
                if result.ok || Self.currentSleepDisabled() == false {
                    self.keepAwake = false
                }
            }
        }
        timer.resume()
        watchdogTimer = timer
    }

    // MARK: Shell

    @discardableResult
    private func runPmset(disableSleep: Bool) -> (ok: Bool, error: String?) {
        if Self.currentSleepDisabled() == disableSleep {
            return (true, nil)
        }

        let result = ProcessRunner.run("/usr/bin/pmset",
                                       ["-a", "disablesleep", disableSleep ? "1" : "0"],
                                       timeout: 10)
        if !result.succeeded {
            let msg = result.timedOut
                ? "pmset timed out"
                : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return (false, msg.isEmpty ? "pmset exited \(result.exitCode)" : msg)
        }

        var observed: Bool?
        for attempt in 1...Verification.attempts {
            observed = Self.currentSleepDisabled()
            if observed == disableSleep {
                return (true, nil)
            }
            if attempt < Verification.attempts {
                Thread.sleep(forTimeInterval: Verification.retryDelay)
            }
        }

        let requested = disableSleep ? "1" : "0"
        let actual = observed.map { $0 ? "1" : "0" } ?? "unavailable"
        return (false, "pmset reported success, but SleepDisabled is \(actual) after requesting \(requested)")
    }

    @discardableResult
    private func syncRuntimeStateFromSystem() -> Bool? {
        guard let actual = Self.currentSleepDisabled() else { return nil }
        keepAwake = actual
        return actual
    }

    private static func capture(_ path: String, _ args: [String]) -> String? {
        ProcessRunner.capture(path, args)
    }

    private static func currentSleepDisabled() -> Bool? {
        guard let out = capture("/usr/bin/pmset", ["-g"]) else { return nil }
        return PowerParsers.sleepDisabledValue(pmsetG: out)
    }
}
