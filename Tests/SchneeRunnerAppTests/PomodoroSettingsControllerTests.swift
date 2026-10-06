@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class PomodoroSettingsTests: XCTestCase {
    func testBuildsConfigurationFromMinuteInputs() throws {
        let controller = PomodoroSettingsController()

        let configuration = try controller.makeConfiguration(
            focusMinutes: 50,
            shortBreakMinutes: 10,
            longBreakMinutes: 30,
            focusPhasesBeforeLongBreak: 3,
            autoStartNextPhase: true
        )

        XCTAssertEqual(configuration.focusDuration, 50 * 60)
        XCTAssertEqual(configuration.shortBreakDuration, 10 * 60)
        XCTAssertEqual(configuration.longBreakDuration, 30 * 60)
        XCTAssertEqual(configuration.focusPhasesBeforeLongBreak, 3)
        XCTAssertTrue(configuration.autoStartNextPhase)
    }

    func testRejectsNonPositiveMinutes() {
        let controller = PomodoroSettingsController()

        XCTAssertThrowsError(
            try controller.makeConfiguration(
                focusMinutes: 0,
                shortBreakMinutes: 5,
                longBreakMinutes: 15,
                focusPhasesBeforeLongBreak: 4,
                autoStartNextPhase: false
            )
        )
    }

    func testRejectsOutOfRangeFocusPhaseCount() {
        let controller = PomodoroSettingsController()

        XCTAssertThrowsError(
            try controller.makeConfiguration(
                focusMinutes: 25,
                shortBreakMinutes: 5,
                longBreakMinutes: 15,
                focusPhasesBeforeLongBreak: 0,
                autoStartNextPhase: false
            )
        )
    }
}
