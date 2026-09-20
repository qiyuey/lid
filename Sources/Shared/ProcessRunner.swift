import Foundation
import OSLog
import Subprocess

public struct ProcessRunResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let timedOut: Bool

    public var succeeded: Bool { exitCode == 0 && !timedOut }
}

public enum ProcessRunner {
    private static let logger = Logger(subsystem: "top.qiyuey.lid", category: "process")
    private struct Timeout: Error {}

    /// Cancellation propagates only after Subprocess has torn down and reaped
    /// the child. A deadline is reported separately from caller cancellation.
    public static func run(_ path: String,
                           _ arguments: [String],
                           timeout: TimeInterval = 10) async throws -> ProcessRunResult {
        try Task.checkCancellation()
        do {
            return try await withThrowingTaskGroup(of: ProcessRunResult.self) { group in
                group.addTask {
                    var options = PlatformOptions()
                    options.teardownSequence = [.gracefulShutDown(allowedDurationToNextStep: .seconds(1))]
                    let result = try await Subprocess.run(
                        .path(.init(path)),
                        arguments: .init(arguments),
                        platformOptions: options,
                        output: .string(limit: 1_048_576),
                        error: .string(limit: 1_048_576)
                    )
                    try Task.checkCancellation()
                    let exitCode: Int32
                    switch result.terminationStatus {
                    case .exited(let code): exitCode = code
                    case .signaled(let signal): exitCode = -signal
                    }
                    return ProcessRunResult(exitCode: exitCode,
                                            stdout: result.standardOutput,
                                            stderr: result.standardError,
                                            timedOut: false)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    throw Timeout()
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
        } catch {
            try Task.checkCancellation()
            let timedOut = error is Timeout
            logger.error("Command failed \(path, privacy: .public): \(String(describing: error), privacy: .public)")
            return ProcessRunResult(exitCode: -1, stdout: "",
                                    stderr: timedOut ? "The command timed out." : error.localizedDescription,
                                    timedOut: timedOut)
        }
    }
}
