import Foundation
@testable import SchneeRunnerCore
import XCTest

final class PomodoroSessionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_331_200)

    func testDefaultConfigurationMatchesProductivityPlan() {
        let configuration = PomodoroConfiguration()

        XCTAssertEqual(configuration.focusDuration, 25 * 60)
        XCTAssertEqual(configuration.shortBreakDuration, 5 * 60)
        XCTAssertEqual(configuration.longBreakDuration, 15 * 60)
        XCTAssertEqual(configuration.focusPhasesBeforeLongBreak, 4)
        XCTAssertFalse(configuration.autoStartNextPhase)
    }

    func testCompletedFocusAdvancesToShortBreakBeforeFourthFocus() {
        let session = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: start
        )

        let advanced = session.advancing(
            at: start.addingTimeInterval(25 * 60)
        )

        XCTAssertEqual(advanced.currentPhase, .shortBreak)
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

        for _ in 0 ..< 3 {
            session = session.advancing(
                at: try XCTUnwrap(session.phaseDeadline)
            )
            session = session.advancing(
                at: try XCTUnwrap(session.phaseDeadline)
            )
        }
        session = session.advancing(
            at: try XCTUnwrap(session.phaseDeadline)
        )

        XCTAssertEqual(session.completedFocusCount, 4)
        XCTAssertEqual(session.currentPhase, .longBreak)
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

        XCTAssertEqual(advanced.currentPhase, .shortBreak)
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

        XCTAssertEqual(advanced.currentPhase, .shortBreak)
        XCTAssertEqual(advanced.state, .running)
        XCTAssertEqual(
            advanced.phaseDeadline,
            focusDeadline.addingTimeInterval(5 * 60)
        )
    }

    func testRepeatedOverdueReconciliationDoesNotDoubleAdvance() {
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
        XCTAssertEqual(once.currentPhase, .shortBreak)
        XCTAssertEqual(once.state, .waiting)
    }

    func testAutoStartCatchesUpAcrossMultipleElapsedPhases() throws {
        let configuration = try PomodoroConfiguration(
            focusDuration: 10,
            shortBreakDuration: 5,
            longBreakDuration: 15,
            focusPhasesBeforeLongBreak: 2,
            autoStartNextPhase: true
        )
        let session = PomodoroSession(
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
            reconciled.phaseDeadline,
            start.addingTimeInterval(40)
        )
    }

    func testDecodeRejectsRunningSessionWithoutDeadline() throws {
        let session = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: start
        )
        let encoded = try JSONEncoder().encode(session)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["phaseDeadline"] = NSNull()
        let invalid = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(
            try JSONDecoder().decode(PomodoroSession.self, from: invalid)
        ) { error in
            XCTAssertEqual(
                error as? PomodoroSessionError,
                .invalidStoredState
            )
        }
    }

    func testConfigurationRejectsNonFiniteAndOutOfRangeDurations() {
        XCTAssertThrowsError(
            try PomodoroConfiguration(
                focusDuration: .infinity,
                shortBreakDuration: 300,
                longBreakDuration: 900,
                focusPhasesBeforeLongBreak: 4,
                autoStartNextPhase: false
            )
        ) { error in
            XCTAssertEqual(
                error as? PomodoroConfigurationError,
                .invalidDuration
            )
        }

        XCTAssertThrowsError(
            try PomodoroConfiguration(
                focusDuration: 0,
                shortBreakDuration: 300,
                longBreakDuration: 900,
                focusPhasesBeforeLongBreak: 4,
                autoStartNextPhase: false
            )
        ) { error in
            XCTAssertEqual(
                error as? PomodoroConfigurationError,
                .invalidDuration
            )
        }
    }

    func testConfigurationRejectsInvalidLongBreakCadence() {
        XCTAssertThrowsError(
            try PomodoroConfiguration(
                focusDuration: 1500,
                shortBreakDuration: 300,
                longBreakDuration: 900,
                focusPhasesBeforeLongBreak: 0,
                autoStartNextPhase: false
            )
        ) { error in
            XCTAssertEqual(
                error as? PomodoroConfigurationError,
                .invalidFocusPhaseCadence
            )
        }
    }

    func testPauseAfterDeadlineWithAutoStartOffReconcilesToWaitingBreak() throws {
        let session = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(autoStartNextPhase: false),
            startedAt: start
        )

        let reconciled = try session.pausing(
            at: start.addingTimeInterval(1501)
        )

        XCTAssertEqual(reconciled.currentPhase, .shortBreak)
        XCTAssertEqual(reconciled.completedFocusCount, 1)
        XCTAssertEqual(reconciled.state, .waiting)
    }
}
