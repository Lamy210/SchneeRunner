import Foundation
import SchneeRunnerCore
import XCTest

final class PomodoroSessionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_331_200)

    func testDefaultConfigurationMatchesProductivityPlan() {
        let configuration = PomodoroConfiguration()

        XCTAssertEqual(configuration.focusDuration, 25 * 60)
        XCTAssertEqual(configuration.shortBreakDuration, 5 * 60)
        XCTAssertEqual(configuration.longBreakDuration, 15 * 60)
        XCTAssertEqual(configuration.longBreakEvery, 4)
        XCTAssertFalse(configuration.autoStartNextPhase)
    }

    func testCompletedFocusAdvancesToShortBreakBeforeFourthFocus() throws {
        let session = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: start
        )

        let advanced = session.advancing(
            at: start.addingTimeInterval(25 * 60)
        )

        XCTAssertEqual(advanced.phase, .shortBreak)
        XCTAssertEqual(advanced.completedFocusCount, 1)
        XCTAssertEqual(advanced.state, .waiting)
        XCTAssertNil(advanced.phaseDeadline)
    }

    func testFourthCompletedFocusAdvancesToLongBreak() throws {
        let configuration = PomodoroConfiguration(autoStartNextPhase: true)
        var session = PomodoroSession(
            id: UUID(),
            configuration: configuration,
            startedAt: start
        )
        var now = start

        for _ in 0..<3 {
            now = try XCTUnwrap(session.phaseDeadline)
            session = session.advancing(at: now)
            now = try XCTUnwrap(session.phaseDeadline)
            session = session.advancing(at: now)
        }

        now = try XCTUnwrap(session.phaseDeadline)
        session = session.advancing(at: now)

        XCTAssertEqual(session.completedFocusCount, 4)
        XCTAssertEqual(session.phase, .longBreak)
        XCTAssertEqual(session.state, .running)
    }

    func testPauseAndResumeUseAuthoritativeRemainingTime() throws {
        let session = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: start
        )
        let paused = try session.pausing(
            at: start.addingTimeInterval(5 * 60)
        )

        XCTAssertEqual(paused.state, .paused)
        XCTAssertEqual(paused.pausedRemaining, 20 * 60)
        XCTAssertNil(paused.phaseDeadline)

        let resumeTime = start.addingTimeInterval(10 * 60)
        let resumed = try paused.resuming(at: resumeTime)

        XCTAssertEqual(resumed.state, .running)
        XCTAssertNil(resumed.pausedRemaining)
        XCTAssertEqual(
            resumed.phaseDeadline,
            resumeTime.addingTimeInterval(20 * 60)
        )
    }

    func testAutoStartOffWaitsForExplicitResumeOfNextPhase() throws {
        let session = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(autoStartNextPhase: false),
            startedAt: start
        )
        let advanced = session.advancing(
            at: start.addingTimeInterval(25 * 60)
        )

        XCTAssertEqual(advanced.phase, .shortBreak)
        XCTAssertEqual(advanced.state, .waiting)
        XCTAssertNil(advanced.phaseDeadline)

        let resumed = try advanced.resuming(
            at: start.addingTimeInterval(30 * 60)
        )
        XCTAssertEqual(resumed.state, .running)
        XCTAssertEqual(
            resumed.phaseDeadline,
            start.addingTimeInterval(35 * 60)
        )
    }

    func testAutoStartOnStartsNextPhaseFromPreviousDeadline() throws {
        let session = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(autoStartNextPhase: true),
            startedAt: start
        )
        let focusDeadline = try XCTUnwrap(session.phaseDeadline)

        let advanced = session.advancing(at: focusDeadline)

        XCTAssertEqual(advanced.phase, .shortBreak)
        XCTAssertEqual(advanced.state, .running)
        XCTAssertEqual(
            advanced.phaseDeadline,
            focusDeadline.addingTimeInterval(5 * 60)
        )
    }

    func testRepeatedOverdueReconciliationDoesNotDoubleAdvance() throws {
        let session = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(autoStartNextPhase: false),
            startedAt: start
        )
        let overdue = start.addingTimeInterval(60 * 60)

        let once = session.advancing(at: overdue)
        let twice = once.advancing(at: overdue)

        XCTAssertEqual(once, twice)
        XCTAssertEqual(once.completedFocusCount, 1)
        XCTAssertEqual(once.phase, .shortBreak)
        XCTAssertEqual(once.state, .waiting)
    }
}
