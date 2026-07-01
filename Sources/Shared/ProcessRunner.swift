import Foundation
import OSLog
import Darwin

public struct ProcessRunResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let timedOut: Bool

    public var succeeded: Bool { exitCode == 0 && !timedOut }
}

public enum ProcessRunner {
    private static let logger = Logger(subsystem: "com.qiyuey.lid", category: "process")

    public static func run(_ path: String,
                           _ arguments: [String],
                           timeout: TimeInterval = 10) -> ProcessRunResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr

        let finished = DispatchSemaphore(value: 0)
        let outputGroup = DispatchGroup()
        let stdoutData = LockedData()
        let stderrData = LockedData()

        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutData.store(stdout.fileHandleForReading.readDataToEndOfFile())
            outputGroup.leave()
        }
        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData.store(stderr.fileHandleForReading.readDataToEndOfFile())
            outputGroup.leave()
        }

        proc.terminationHandler = { _ in finished.signal() }

        do {
            try proc.run()
        } catch {
            logger.error("Failed to launch \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return ProcessRunResult(exitCode: -1, stdout: "", stderr: error.localizedDescription, timedOut: false)
        }

        var timedOut = false
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            proc.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut, proc.isRunning {
                Darwin.kill(proc.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + 1)
            }
        }

        _ = outputGroup.wait(timeout: .now() + 1)
        let out = String(data: stdoutData.load(), encoding: .utf8) ?? ""
        let err = String(data: stderrData.load(), encoding: .utf8) ?? ""
        let result = ProcessRunResult(
            exitCode: proc.isRunning ? -1 : proc.terminationStatus,
            stdout: out,
            stderr: err,
            timedOut: timedOut
        )

        if timedOut {
            logger.error("Timed out running \(path, privacy: .public) \(arguments.joined(separator: " "), privacy: .public)")
        } else if result.exitCode != 0 {
            logger.error("Command failed \(path, privacy: .public) exit=\(result.exitCode)")
        }

        return result
    }

    public static func capture(_ path: String,
                               _ arguments: [String],
                               timeout: TimeInterval = 10) -> String? {
        let result = run(path, arguments, timeout: timeout)
        return result.succeeded ? result.stdout : nil
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Data()

    func store(_ data: Data) {
        lock.lock()
        value = data
        lock.unlock()
    }

    func load() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
