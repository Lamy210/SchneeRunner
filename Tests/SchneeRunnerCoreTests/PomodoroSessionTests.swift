@testable import SchneeRunnerCore
import XCTest

final class PomodoroSessionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_331_200)

    func testDefaultConfigurationUsesApprovedDurations() throws {
        let configuration = try PomodoroConfiguration()

        XCTAssertEqual(configuration.focusDuration, 25 * 60)
        XCTAssertEqual(configuration.shortBreakDuration, 5 * 60)
        XCTAssertEqual(configuration.longBreakDuration, 15 * 60)
        XCTAssertEqual(configuration.focusPhasesBeforeLongBreak, 4)
        XCTAssertFalse(configuration.autoStartNextPhase)
    }

    func testCompletedFocusAdvancesToWaitingShortBreak() throws {
        let session = try makeSession()
        let transitionTime = start.addingTimeInterval(25 * 60)

        let advanced = session.advancing(at: transitionTime)

        XCTAssertEqual(advanced.currentPhase, .shortBreak)
        XCTAssertEqual(advanced.completedFocusCount, 1)
        XCTAssertEqual(advanced.state, .waiting)
        XCTAssertNil(advanced.phaseStartedAt)
        XCTAssertNil(advanced.phaseDeadline)
    }

    func testFourthCompletedFocusAdvancesToLongBreak() throws {
        var session = try makeSession()
        var now = start

        for focusNumber in 1 ... 4 {
            now = try XCTUnwrap(session.phaseDeadline)
            session = session.advancing(at: now)
            if focusNumber < 4 {
                XCTAssertEqual(session.currentPhase, .shortBreak)
                session = try session.startingCurrentPhase(at: now)
                now = try XCTUnwrap(session.phaseDeadline)
                session = session.advancing(at: now)
                XCTAssertEqual(session.currentPhase, .focus)
                session = try session.startingCurrentPhase(at: now)
            }
        }

        XCTAssertEqual(session.currentPhase, .longBreak)
        XCTAssertEqual(session.completedFocusCount, 4)
        XCTAssertEqual(session.state, .waiting)
    }

    func testPauseAndResumeUseRemainingDuration() throws {
        let session = try makeSession()
        let paused = try session.pausing(at: start.addingTimeInterval(10 * 60))

        XCTAssertEqual(paused.state, .paused)
        XCTAssertNil(paused.phaseDeadline)
        XCTAssertEqual(try XCTUnwrap(paused.pausedRemaining), 15 * 60, accuracy: 0.001)

        let resumeTime = start.addingTimeInterval(60 * 60)
        let resumed = try paused.resuming(at: resumeTime)
        XCTAssertEqual(resumed.state, .running)
        XCTAssertNil(resumed.pausedRemaining)
        XCTAssertEqual(resumed.phaseStartedAt, resumeTime)
        XCTAssertEqual(resumed.phaseDeadline, resumeTime.addingTimeInterval(15 * 60))
    }

    func testAutoStartOffLeavesNextPhaseWaiting() throws {
        let session = try makeSession(autoStartNextPhase: false)
        let now = try XCTUnwrap(session.phaseDeadline)

        let advanced = session.advancing(at: now)

        XCTAssertEqual(advanced.state, .waiting)
        XCTAssertEqual(advanced.currentPhase, .shortBreak)
        XCTAssertNil(advanced.phaseDeadline)
    }

    func testAutoStartOnPreservesPreviousPhaseBoundaryWhenLate() throws {
        let session = try makeSession(autoStartNextPhase: true)
        let focusDeadline = try XCTUnwrap(session.phaseDeadline)
        let reconciliationTime = focusDeadline.addingTimeInterval(120)

        let advanced = session.advancing(at: reconciliationTime)

        XCTAssertEqual(advanced.state, .running)
        XCTAssertEqual(advanced.currentPhase, .shortBreak)
        XCTAssertEqual(advanced.phaseStartedAt, focusDeadline)
        XCTAssertEqual(
            advanced.phaseDeadline,
            focusDeadline.addingTimeInterval(5 * 60)
        )
    }

    func testRepeatedOverdueReconciliationDoesNotDoubleAdvance() throws {
        let session = try makeSession(autoStartNextPhase: true)
        let reconciliationTime = try XCTUnwrap(session.phaseDeadline).addingTimeInterval(120)
        let advanced = session.advancing(at: reconciliationTime)

        let advancedAgain = advanced.advancing(at: reconciliationTime)

        XCTAssertEqual(advancedAgain, advanced)
        XCTAssertEqual(advancedAgain.currentPhase, .shortBreak)
        XCTAssertEqual(advancedAgain.completedFocusCount, 1)
    }

    func testAutoStartCatchesUpAcrossMultipleElapsedPhases() throws {
        let configuration = try PomodoroConfiguration(
            focusDuration: 10,
            shortBreakDuration: 5,
            longBreakDuration: 15,
            focusPhasesBeforeLongBreak: 2,
            autoStartNextPhase: true
        )
        let session = try PomodoroSession(
            id: UUID(),
            configuration: configuration,
            startedAt: start
        )

        let reconciled = session.advancing(
            at: start.addingTimeInterval(31)
        )

        XCTAssertEqual(reconciled.currentPhase, .longBreak)
        XCTAssertEqual(reconciled.completedFocusCount, 2)
        XCTAssertEqual(reconciled.state, .running)
        XCTAssertEqual(
            reconciled.phaseStartedAt,
            start.addingTimeInterval(25)
        )
        XCTAssertEqual(
            reconciled.phaseDeadline,
            start.addingTimeInterval(40)
        )
    }

    func testRejectsInvalidConfiguration() {
        XCTAssertThrowsError(
            try PomodoroConfiguration(focusDuration: 0)
        )
        XCTAssertThrowsError(
            try PomodoroConfiguration(focusPhasesBeforeLongBreak: 0)
        )
    }

    private func makeSession(
        autoStartNextPhase: Bool = false
    ) throws -> PomodoroSession {
        let configuration = try PomodoroConfiguration(
            autoStartNextPhase: autoStartNextPhase
        )
        return try PomodoroSession(
            id: UUID(),
            configuration: configuration,
            startedAt: start
        )
    }
}
