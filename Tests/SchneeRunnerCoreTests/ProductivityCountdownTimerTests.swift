import Foundation
@testable import SchneeRunnerCore
import XCTest

final class ProductivityCountdownTimerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_331_200)

    func testRunningTimerDerivesRemainingFromDeadline() throws {
        let id = try timerID()
        let timer = try ProductivityCountdownTimer(
            id: id,
            title: "Focus",
            duration: 1500,
            startedAt: start
        )

        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.originalDuration, 1500)
        XCTAssertEqual(timer.startedAt, start)
        XCTAssertEqual(timer.deadline, start.addingTimeInterval(1500))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(300)), 1200)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(1501)), 0)
    }

    func testPauseStoresRemainingAndClearsDeadline() throws {
        let timer = try makeTimer()
        let paused = try timer.pausing(at: start.addingTimeInterval(600))

        XCTAssertEqual(paused.state, .paused)
        XCTAssertNil(paused.deadline)
        XCTAssertEqual(paused.pausedRemaining, 900)
        XCTAssertEqual(paused.remaining(at: start.addingTimeInterval(900)), 900)
    }

    func testPauseAfterDeadlineCompletesTimer() throws {
        let timer = try makeTimer()
        let completed = try timer.pausing(
            at: start.addingTimeInterval(1501)
        )

        XCTAssertEqual(completed.state, .completed)
        XCTAssertEqual(
            completed.completedAt,
            start.addingTimeInterval(1500)
        )
        XCTAssertNil(completed.deadline)
        XCTAssertNil(completed.pausedRemaining)
    }

    func testResumeCreatesFreshDeadlineFromPausedRemaining() throws {
        let timer = try makeTimer()
        let paused = try timer.pausing(at: start.addingTimeInterval(600))
        let resumeTime = start.addingTimeInterval(1200)
        let resumed = try paused.resuming(at: resumeTime)

        XCTAssertEqual(resumed.state, .running)
        XCTAssertEqual(resumed.deadline, resumeTime.addingTimeInterval(900))
        XCTAssertNil(resumed.pausedRemaining)
        XCTAssertEqual(resumed.remaining(at: resumeTime), 900)
    }

    func testCancelClearsActiveTimingState() throws {
        let timer = try makeTimer()
        let cancelled = timer.cancelling()

        XCTAssertEqual(cancelled.state, .cancelled)
        XCTAssertNil(cancelled.deadline)
        XCTAssertNil(cancelled.pausedRemaining)
        XCTAssertNil(cancelled.completedAt)
        XCTAssertEqual(cancelled.remaining(at: start), 0)
    }

    func testReconcileCompletesOverdueTimerExactlyOnce() throws {
        let timer = try makeTimer()
        let overdue = start.addingTimeInterval(1501)

        let completed = timer.reconciling(at: overdue)
        let reconciledAgain = completed.reconciling(at: overdue.addingTimeInterval(100))

        XCTAssertEqual(completed.state, .completed)
        XCTAssertEqual(completed.completedAt, start.addingTimeInterval(1500))
        XCTAssertNil(completed.deadline)
        XCTAssertEqual(completed.remaining(at: overdue), 0)
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
        ) { error in
            XCTAssertEqual(
                error as? ProductivityCountdownTimerError,
                .invalidDuration
            )
        }
    }

    func testDecodeRejectsRunningTimerWithoutDeadline() throws {
        let timer = try makeTimer()
        let encoded = try JSONEncoder().encode(timer)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["deadline"] = NSNull()
        let invalid = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                ProductivityCountdownTimer.self,
                from: invalid
            )
        ) { error in
            XCTAssertEqual(
                error as? ProductivityCountdownTimerError,
                .invalidStoredState
            )
        }
    }

    func testClockJumpUsesDeadlineRatherThanTickCount() throws {
        let timer = try makeTimer()

        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(1490)), 10)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(60)), 1440)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(1200)), 300)
    }

    private func makeTimer() throws -> ProductivityCountdownTimer {
        let id = try timerID()
        return try ProductivityCountdownTimer(
            id: id,
            title: "Focus",
            duration: 1500,
            startedAt: start
        )
    }

    private func timerID() throws -> UUID {
        try XCTUnwrap(
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        )
    }
}
