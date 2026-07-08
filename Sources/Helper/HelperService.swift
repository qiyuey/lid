import Foundation
import OSLog

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service: HelperService
    private let clientRequirement: String

    init(clientRequirement: String, helperLabel: String) {
        self.clientRequirement = clientRequirement
        self.service = HelperService(helperLabel: helperLabel)
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
/// with no admin prompt. Owns and persists the user's sleep-prevention state.
final class HelperService: NSObject, LidHelperProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "top.qiyuey.lid.helper.state")
    private let logger = Logger(subsystem: "top.qiyuey.lid", category: "helper-service")
    private let stateURL: URL
    private let stateLoadError: String?
    private var controlState: HelperSleepState
    private var watchdogTimer: DispatchSourceTimer?

    private enum Verification {
        static let attempts = 5
        static let retryDelay: TimeInterval = 0.1
    }

    private enum Watchdog {
        static let interval: DispatchTimeInterval = .seconds(60)
        static let leeway: DispatchTimeInterval = .seconds(5)
    }

    init(helperLabel: String = LidHelperIdentity.fallbackLabel) {
        let stateURL = Self.stateURL(helperLabel: helperLabel)
        let loaded = Self.loadState(from: stateURL)
        self.stateURL = stateURL
        self.stateLoadError = loaded.error
        self.controlState = loaded.state
        super.init()
        if let stateLoadError {
            logger.error("Failed to load helper state, using defaults: \(stateLoadError, privacy: .public)")
        }
        logger.info("Helper service initialized")
        queue.async { [weak self] in
            guard let self else { return }
            self.applyPersistedSleepState(reason: "startup")
            self.startWatchdog()
        }
    }

    // MARK: LidHelperProtocol

    func setKeepAwake(_ enabled: Bool, withReply reply: @escaping @Sendable (Bool, String?) -> Void) {
        queue.async {
            let previous = self.controlState
            let result = self.runPmset(disableSleep: enabled)
            if result.ok {
                self.logger.info("Set SleepDisabled to \(enabled, privacy: .public)")
                self.controlState.sleepPreventionEnabled = enabled
                if let persistError = self.persistControlState() {
                    self.logger.error("Failed to persist SleepDisabled \(enabled, privacy: .public): \(persistError, privacy: .public)")
                    self.controlState = previous
                    let rollback = self.runPmset(disableSleep: previous.sleepPreventionEnabled)
                    if !rollback.ok {
                        self.logger.error("Failed to roll back SleepDisabled after persistence failure: \(rollback.error ?? "unknown", privacy: .public)")
                    }
                    reply(false, "Couldn’t save helper state: \(persistError)")
                    return
                }
            } else {
                self.logger.error("Failed to set SleepDisabled to \(enabled, privacy: .public): \(result.error ?? "unknown", privacy: .public)")
            }
            reply(result.ok, result.error)
        }
    }

    func getState(withReply reply: @escaping @Sendable (Bool) -> Void) {
        queue.async {
            // The helper-owned persisted state is the authority. External
            // `pmset` changes are not synced back into Lid state; if they drift
            // away from the persisted preference, re-apply the persisted value.
            self.verifyPersistedSleepState(reason: "state read")
            reply(self.controlState.sleepPreventionEnabled)
        }
    }

    func version(withReply reply: @escaping @Sendable (String) -> Void) {
        reply(LidHelperIdentity.versionString(bundle: .main))
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

    private func applyPersistedSleepState(reason: String) {
        let target = controlState.sleepPreventionEnabled
        let result = runPmset(disableSleep: target)
        if result.ok {
            logger.info("Applied persisted SleepDisabled \(target, privacy: .public) during \(reason, privacy: .public)")
            return
        }

        logger.error("Failed to apply persisted SleepDisabled \(target, privacy: .public) during \(reason, privacy: .public): \(result.error ?? "unknown", privacy: .public)")
    }

    private func startWatchdog() {
        guard watchdogTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Watchdog.interval,
                       repeating: Watchdog.interval,
                       leeway: Watchdog.leeway)
        timer.setEventHandler { [weak self] in
            self?.verifyPersistedSleepState()
        }
        watchdogTimer = timer
        timer.resume()
        logger.info("Started SleepDisabled watchdog")
    }

    private func verifyPersistedSleepState(reason: String = "watchdog") {
        let target = controlState.sleepPreventionEnabled
        guard let actual = Self.currentSleepDisabled() else {
            logger.error("SleepDisabled verification could not read pmset state during \(reason, privacy: .public)")
            return
        }

        guard actual != target else { return }

        logger.error("SleepDisabled verification found mismatch during \(reason, privacy: .public): persisted \(target, privacy: .public), actual \(actual, privacy: .public)")
        applyPersistedSleepState(reason: reason)
    }

    private func persistControlState() -> String? {
        do {
            let directory = stateURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(controlState)
            try data.write(to: stateURL, options: [.atomic])
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private static func stateURL(helperLabel: String) -> URL {
        URL(fileURLWithPath: "/Library/Application Support", isDirectory: true)
            .appendingPathComponent("Lid", isDirectory: true)
            .appendingPathComponent(helperLabel, isDirectory: true)
            .appendingPathComponent("helper-state.json")
    }

    private static func loadState(from url: URL) -> (state: HelperSleepState, error: String?) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (.default, nil)
        }

        do {
            let data = try Data(contentsOf: url)
            let state = try JSONDecoder().decode(HelperSleepState.self, from: data)
            return (state, nil)
        } catch {
            return (.default, error.localizedDescription)
        }
    }

    private static func capture(_ path: String, _ args: [String]) -> String? {
        ProcessRunner.capture(path, args)
    }

    private static func currentSleepDisabled() -> Bool? {
        guard let out = capture("/usr/bin/pmset", ["-g"]) else { return nil }
        return PowerParsers.sleepDisabledValue(pmsetG: out)
    }
}
