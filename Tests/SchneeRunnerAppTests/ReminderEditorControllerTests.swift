import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ReminderEditorControllerTests: XCTestCase {
    func testRejectsEmptyTitle() {
        let controller = ReminderEditorController()

        XCTAssertThrowsError(
            try controller.makeRequest(
                title: "   ",
                body: nil,
                enabled: true,
                schedule: .daily(hour: 9, minute: 0)
            )
        ) { error in
            XCTAssertEqual(error as? ReminderEditorError, .emptyTitle)
        }
    }

    func testRejectsInvalidDailyHour() {
        let controller = ReminderEditorController()

        XCTAssertThrowsError(
            try controller.makeRequest(
                title: "Standup",
                body: nil,
                enabled: true,
                schedule: .daily(hour: 24, minute: 0)
            )
        ) { error in
            XCTAssertEqual(
                error as? ReminderScheduleError,
                .invalidHour(24)
            )
        }
    }

    func testRejectsInvalidMinute() {
        let controller = ReminderEditorController()

        XCTAssertThrowsError(
            try controller.makeRequest(
                title: "Standup",
                body: nil,
                enabled: true,
                schedule: .daily(hour: 9, minute: 60)
            )
        ) { error in
            XCTAssertEqual(
                error as? ReminderScheduleError,
                .invalidMinute(60)
            )
        }
    }

    func testRejectsEmptyWeekdays() {
        let controller = ReminderEditorController()

        XCTAssertThrowsError(
            try controller.makeRequest(
                title: "Standup",
                body: nil,
                enabled: true,
                schedule: .weekdays([], hour: 9, minute: 0)
            )
        ) { error in
            XCTAssertEqual(error as? ReminderScheduleError, .emptyWeekdays)
        }
    }

    func testRequestTrimsTitleAndBlankBody() throws {
        let controller = ReminderEditorController()

        let request = try controller.makeRequest(
            title: "  Standup  ",
            body: "   ",
            enabled: true,
            schedule: .daily(hour: 9, minute: 30)
        )

        XCTAssertEqual(request.title, "Standup")
        XCTAssertNil(request.body)
        XCTAssertEqual(request.schedule, .daily(hour: 9, minute: 30))
    }
}
