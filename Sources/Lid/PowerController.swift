import Foundation

protocol ProcessRunning: Sendable {
    func run(_ path: String, _ arguments: [String], timeout: TimeInterval) async throws -> ProcessRunResult
}

struct SystemProcessRunner: ProcessRunning {
    func run(_ path: String, _ arguments: [String], timeout: TimeInterval) async throws -> ProcessRunResult {
        try await ProcessRunner.run(path, arguments, timeout: timeout)
    }
}

enum PowerControllerError: Error, Equatable, Sendable {
    case readFailed(String)
    case commandFailed(String)
    case verificationFailed(target: Bool, actual: Bool?)

    var userDetails: String {
        switch self {
        case .readFailed(let details), .commandFailed(let details):
            return details
        case .verificationFailed(let target, let actual):
            let requested = target ? "on" : "off"
            let observed = actual.map { $0 ? "on" : "off" } ?? "unreadable"
            return "requested \(requested), observed \(observed)"
        }
    }
}

struct PowerController: Sendable {
    private let runner: any ProcessRunning

    init(runner: any ProcessRunning = SystemProcessRunner()) {
        self.runner = runner
    }

    func isSleepPreventionEnabled() async throws -> Bool {
        let result = try await runner.run("/usr/bin/pmset", ["-g"], timeout: 5)
        guard result.succeeded else {
            throw PowerControllerError.readFailed(Self.describe(result))
        }
        guard let enabled = PowerParsers.sleepDisabledValue(pmsetG: result.stdout) else {
            throw PowerControllerError.readFailed("Could not read a valid SleepDisabled value from pmset.")
        }
        return enabled
    }

    func setSleepPrevention(_ enabled: Bool) async throws {
        let result = try await runner.run(
            "/usr/bin/osascript",
            ["-e", Self.adminScript(enabled: enabled)],
            timeout: 120
        )
        guard result.succeeded else {
            throw PowerControllerError.commandFailed(Self.describe(result))
        }

        let actual = try await isSleepPreventionEnabled()
        guard actual == enabled else {
            throw PowerControllerError.verificationFailed(target: enabled, actual: actual)
        }
    }

    static func adminScript(enabled: Bool) -> String {
        let value = enabled ? "1" : "0"
        return "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
    }

    private static func describe(_ result: ProcessRunResult) -> String {
        if result.timedOut {
            return "The command timed out."
        }

        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            return stderr
        }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty {
            return stdout
        }

        return "Command exited with status \(result.exitCode)."
    }
}
