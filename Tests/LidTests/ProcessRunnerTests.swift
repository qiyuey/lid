import Darwin
import Foundation
import XCTest

@MainActor
final class ProcessRunnerTests: XCTestCase {
    func testCapturesBothStreamsBeyondPipeCapacity() async throws {
        let result = try await ProcessRunner.run("/bin/sh", ["-c", "i=0; while [ $i -lt 10000 ]; do echo stdout-line; echo stderr-line >&2; i=$((i+1)); done"])
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stdout, String(repeating: "stdout-line\n", count: 10000))
        XCTAssertEqual(result.stderr, String(repeating: "stderr-line\n", count: 10000))
    }

    func testMissingExecutableReportsFailure() async throws {
        let result = try await ProcessRunner.run("/no/such/lid-executable", [])
        XCTAssertFalse(result.succeeded)
        XCTAssertFalse(result.timedOut)
        XCTAssertFalse(result.stderr.isEmpty)
    }

    func testSignalTerminationIsNotSuccess() async throws {
        let result = try await ProcessRunner.run("/bin/sh", ["-c", "kill -TERM $$"])
        XCTAssertEqual(result.exitCode, -SIGTERM)
        XCTAssertFalse(result.succeeded)
    }

    func testTimeoutKillsAndReapsChildIgnoringTerminate() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let start = ContinuousClock.now
        let result = try await ProcessRunner.run("/bin/sh", stubbornChildArguments(file), timeout: 0.5)
        XCTAssertTrue(result.timedOut)
        XCTAssertFalse(result.succeeded)
        XCTAssertLessThan(start.duration(to: .now), .seconds(4))
        try assertChildExited(file)
    }

    func testCancellationKillsAndReapsChildWithoutWaitingForDeadline() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let task = Task {
            try await ProcessRunner.run("/bin/sh", stubbornChildArguments(file), timeout: 30)
        }
        defer { task.cancel() }
        // Wait for the child to install its signal handler before cancelling.
        for _ in 0..<200 {
            if let pid = try? String(contentsOf: file, encoding: .utf8), Int32(pid.trimmingCharacters(in: .whitespacesAndNewlines)) != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let start = ContinuousClock.now
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Caller cancellation must propagate")
        } catch is CancellationError {
            // Expected, after process teardown.
        }
        XCTAssertLessThan(start.duration(to: .now), .seconds(4))
        try assertChildExited(file)
    }

    private func stubbornChildArguments(_ file: URL) -> [String] {
        ["-c", "trap '' TERM; echo $$ > \"$1\"; while :; do :; done", "lid-test", file.path]
    }

    private func assertChildExited(_ file: URL, line: UInt = #line) throws {
        let text = try String(contentsOf: file, encoding: .utf8)
        let pid = try XCTUnwrap(Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertEqual(kill(pid, 0), -1, "Child must be gone before returning", line: line)
        XCTAssertEqual(errno, ESRCH, line: line)
    }
}
