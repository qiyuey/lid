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
final class HelperService: NSObject, LidHelperProtocol {
    private let queue = DispatchQueue(label: "com.qiyuey.lid.helper.state")
    private var lastHeartbeat = Date()
    private var keepAwake = false
    private let watchdogTimeout: TimeInterval = 90
    private var watchdogTimer: DispatchSourceTimer?

    override init() {
        super.init()
        startWatchdog()
    }

    // MARK: LidHelperProtocol

    func setKeepAwake(_ enabled: Bool, withReply reply: @escaping (Bool, String?) -> Void) {
        queue.async {
            let result = self.runPmset(disableSleep: enabled)
            if result.ok {
                self.keepAwake = enabled
                self.lastHeartbeat = Date()
            }
            reply(result.ok, result.error)
        }
    }

    func getState(withReply reply: @escaping (Bool) -> Void) {
        let out = Self.capture("/usr/bin/pmset", ["-g"]) ?? ""
        reply(PowerParsers.isSleepDisabled(pmsetG: out))
    }

    func heartbeat(withReply reply: @escaping (Bool) -> Void) {
        queue.async {
            self.lastHeartbeat = Date()
            reply(true)
        }
    }

    func version(withReply reply: @escaping (String) -> Void) {
        reply(LidHelperIdentity.versionString(bundle: .main))
    }

    // MARK: Watchdog

    private func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.keepAwake else { return }
            if Watchdog.shouldAutoRestore(lastHeartbeat: self.lastHeartbeat,
                                          now: Date(),
                                          timeout: self.watchdogTimeout) {
                _ = self.runPmset(disableSleep: false)
                self.keepAwake = false
            }
        }
        timer.resume()
        watchdogTimer = timer
    }

    // MARK: Shell

    @discardableResult
    private func runPmset(disableSleep: Bool) -> (ok: Bool, error: String?) {
        let result = ProcessRunner.run("/usr/bin/pmset",
                                       ["-a", "disablesleep", disableSleep ? "1" : "0"],
                                       timeout: 10)
        if !result.succeeded {
            let msg = result.timedOut
                ? "pmset timed out"
                : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return (false, msg.isEmpty ? "pmset exited \(result.exitCode)" : msg)
        }
        return (true, nil)
    }

    private static func capture(_ path: String, _ args: [String]) -> String? {
        ProcessRunner.capture(path, args)
    }
}
