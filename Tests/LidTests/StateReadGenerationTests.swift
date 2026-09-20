import XCTest

final class StateReadGenerationTests: XCTestCase {
    func testOlderRefreshCannotOverwriteNewerResult() {
        var reads = StateReadGeneration()
        let older = reads.beginRead()
        let newer = reads.beginRead()
        var shown = false

        if reads.isCurrent(newer) { shown = true }
        if reads.isCurrent(older) { shown = false }

        XCTAssertTrue(shown)
        XCTAssertFalse(reads.isCurrent(older))
    }

    func testReadStartedBeforeWriteStaysInvalidAfterWriteCompletes() {
        var reads = StateReadGeneration()
        let beforeWrite = reads.beginRead()
        reads.invalidate()
        // The write has completed; a busy flag would now permit the old result.
        var shown = true
        if reads.isCurrent(beforeWrite) { shown = false }
        XCTAssertTrue(shown)

        let afterWrite = reads.beginRead()
        XCTAssertTrue(reads.isCurrent(afterWrite))
        XCTAssertFalse(reads.isCurrent(beforeWrite))
    }

    func testReturningToSameStateDoesNotRevalidateOldRead() {
        var reads = StateReadGeneration()
        let beforeWrites = reads.beginRead()
        reads.invalidate() // Enable.
        reads.invalidate() // Disable again.
        XCTAssertFalse(reads.isCurrent(beforeWrites))
    }

    func testStaleReadFailureCannotReplaceNewerSuccess() {
        var reads = StateReadGeneration()
        let failingRead = reads.beginRead()
        let successfulRead = reads.beginRead()
        var error: String?
        XCTAssertTrue(reads.isCurrent(successfulRead))
        if reads.isCurrent(failingRead) { error = "Old read failed" }
        XCTAssertNil(error)
    }
}
