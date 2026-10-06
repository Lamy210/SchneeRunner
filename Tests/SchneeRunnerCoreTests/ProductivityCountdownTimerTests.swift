@testable import SchneeRunnerCore
import XCTest

final class ProductivityCountdownTimerTests: XCTestCase {
    // Fixed UTC reference keeps deadline behavior deterministic.
    private let start = Date(timeIntervalSince1970: 1_791_331_200)

    func testRunningTimerDerivesRemainingFromDeadline() throws {
        let timer = try ProductivityCountdownTimer(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Focus",
            duration: 1_500,
            startedAt: start
        )
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.startedAt, start)
        XCTAssertEqual(timer.deadline, start.addingTimeInterval(1_500))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(600)), 900, accuracy: 0.001)
    }

    func testPauseStoresRemainingAndClearsDeadline() throws {
        let timer = try makeTimer()
        let paused = try timer.pausing(at: start.addingTimeInterval(600))
        XCTAssertEqual(paused.state, .paused)
        XCTAssertNil(paused.deadline)
        XCTAssertEqual(try XCTUnwrap(paused.pausedRemaining), 900, accuracy: 0.001)
        XCTAssertEqual(paused.remaining(at: start.addingTimeInterval(1_200)), 900, accuracy: 0.001)
    }

    func testResumeCreatesFreshDeadlineFromPausedRemaining() throws {
        let paused = try makeTimer().pausing(at: start.addingTimeInterval(600))
        let resumeTime = start.addingTimeInterval(3_600)
        let resumed = try paused.resuming(at: resumeTime)
        XCTAssertEqual(resumed.state, .running)
        XCTAssertEqual(resumed.startedAt, resumeTime)
        XCTAssertNil(resumed.pausedRemaining)
        XCTAssertEqual(resumed.deadline, resumeTime.addingTimeInterval(900))
    }

    func testReconcileCompletesOverdueTimerExactlyOnce() throws {
        let timer = try makeTimer()
        let completionTime = start.addingTimeInterval(1_501)
        let completed = timer.reconciling(at: completionTime)
        let reconciledAgain = completed.reconciling(at: completionTime.addingTimeInterval(100))
        XCTAssertEqual(completed.state, .completed)
        XCTAssertEqual(completed.completedAt, completionTime)
        XCTAssertEqual(completed.remaining(at: completionTime), 0, accuracy: 0.001)
        XCTAssertEqual(reconciledAgain, completed)
    }

    func testRejectsNonPositiveDuration() {
        XCTAssertThrowsError(
            try ProductivityCountdownTimer(
                id: UUID(),
                title: "Invalid",
                duration: 0,
                startedAt: start
            )
        )
    }

    func testClockJumpUsesDeadlineRatherThanTickCount() throws {
        let timer = try makeTimer()
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(300)), 1_200, accuracy: 0.001)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(1_200)), 300, accuracy: 0.001)
    }

    func testCancelClearsActiveTimingAndIsIdempotent() throws {
        let timer = try makeTimer()

        let cancelled = timer.cancelling()
        let cancelledAgain = cancelled.cancelling()

        XCTAssertEqual(cancelled.state, .cancelled)
        XCTAssertNil(cancelled.deadline)
        XCTAssertNil(cancelled.pausedRemaining)
        XCTAssertEqual(cancelled.remaining(at: start.addingTimeInterval(300)), 0, accuracy: 0.001)
        XCTAssertEqual(cancelledAgain, cancelled)
    }

    func testDecodingRejectsInvalidRunningStateWithoutDeadline() throws {
        let timer = try makeTimer()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(timer)) as? [String: Any]
        )
        object.removeValue(forKey: "deadline")
        let invalidData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try JSONDecoder().decode(ProductivityCountdownTimer.self, from: invalidData))
    }

    private func makeTimer() throws -> ProductivityCountdownTimer {
        try ProductivityCountdownTimer(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Focus",
            duration: 1_500,
            startedAt: start
        )
    }
}
