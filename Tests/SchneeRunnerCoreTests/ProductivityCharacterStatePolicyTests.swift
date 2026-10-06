import SchneeRunnerCore
import XCTest

final class ProductivityCharacterStatePolicyTests: XCTestCase {
    private let policy = ProductivityCharacterStatePolicy()

    func testNoSignalsProduceNoCharacterState() {
        XCTAssertNil(policy.state(for: []))
    }

    func testEachSignalMapsToApprovedCharacterState() {
        XCTAssertEqual(policy.state(for: [.breakPhase]), .idle)
        XCTAssertEqual(policy.state(for: [.activeCountdown]), .walk)
        XCTAssertEqual(policy.state(for: [.pomodoroFocus]), .dash)
        XCTAssertEqual(policy.state(for: [.finalMinute]), .sprint)
        XCTAssertEqual(policy.state(for: [.timerCompleted]), .sprint)
        XCTAssertEqual(policy.state(for: [.reminderFired]), .idle)
    }

    func testReminderFiredWinsEveryLowerPrioritySignal() {
        XCTAssertEqual(
            policy.state(
                for: [
                    .breakPhase,
                    .activeCountdown,
                    .pomodoroFocus,
                    .finalMinute,
                    .timerCompleted,
                    .reminderFired
                ]
            ),
            .idle
        )
    }

    func testTimerCompletedWinsFinalMinuteAndSteadyStates() {
        XCTAssertEqual(
            policy.state(
                for: [
                    .breakPhase,
                    .activeCountdown,
                    .pomodoroFocus,
                    .finalMinute,
                    .timerCompleted
                ]
            ),
            .sprint
        )
    }

    func testFinalMinuteWinsPomodoroFocusAndLowerPriorityStates() {
        XCTAssertEqual(
            policy.state(
                for: [
                    .breakPhase,
                    .activeCountdown,
                    .pomodoroFocus,
                    .finalMinute
                ]
            ),
            .sprint
        )
    }

    func testPomodoroFocusWinsActiveCountdownAndBreak() {
        XCTAssertEqual(
            policy.state(
                for: [.breakPhase, .activeCountdown, .pomodoroFocus]
            ),
            .dash
        )
    }

    func testActiveCountdownWinsBreak() {
        XCTAssertEqual(
            policy.state(for: [.breakPhase, .activeCountdown]),
            .walk
        )
    }
}
