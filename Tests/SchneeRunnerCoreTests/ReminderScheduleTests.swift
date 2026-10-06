@testable import SchneeRunnerCore
import XCTest

final class ReminderScheduleTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testFutureOneShotReturnsOccurrence() {
        let now = Date(timeIntervalSince1970: 1_791_331_200)
        let fireDate = now.addingTimeInterval(600)
        let schedule = ReminderSchedule.once(fireDate)

        XCTAssertEqual(
            schedule.nextOccurrence(after: now, calendar: utcCalendar),
            fireDate
        )
    }

    func testExpiredOneShotReturnsNil() {
        let now = Date(timeIntervalSince1970: 1_791_331_200)
        let schedule = ReminderSchedule.once(now.addingTimeInterval(-1))

        XCTAssertNil(
            schedule.nextOccurrence(after: now, calendar: utcCalendar)
        )
    }

    func testDailyUsesSameDayThenNextDay() {
        let calendar = utcCalendar
        let now = date("2026-10-07 08:30", calendar: calendar)
        let schedule = ReminderSchedule.daily(hour: 9, minute: 15)

        XCTAssertEqual(
            schedule.nextOccurrence(after: now, calendar: calendar),
            date("2026-10-07 09:15", calendar: calendar)
        )

        let later = date("2026-10-07 09:16", calendar: calendar)
        XCTAssertEqual(
            schedule.nextOccurrence(after: later, calendar: calendar),
            date("2026-10-08 09:15", calendar: calendar)
        )
    }

    func testWeekdaysSelectNextAllowedDay() {
        let calendar = utcCalendar
        let now = date("2026-10-07 10:00", calendar: calendar)
        let schedule = ReminderSchedule.weekdays(
            [.monday, .friday],
            hour: 9,
            minute: 0
        )

        XCTAssertEqual(
            schedule.nextOccurrence(after: now, calendar: calendar),
            date("2026-10-09 09:00", calendar: calendar)
        )
    }

    func testSpringForwardMissingDailyTimeUsesNextValidTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = date("2026-03-08 00:00", calendar: calendar)
        let schedule = ReminderSchedule.daily(hour: 2, minute: 30)

        XCTAssertEqual(
            schedule.nextOccurrence(after: now, calendar: calendar),
            date("2026-03-08 03:00", calendar: calendar)
        )
    }

    func testRejectsInvalidDailyTimeAndEmptyWeekdays() {
        XCTAssertThrowsError(
            try ReminderSchedule.daily(hour: 24, minute: 0).validate()
        )
        XCTAssertThrowsError(
            try ReminderSchedule.daily(hour: 9, minute: 60).validate()
        )
        XCTAssertThrowsError(
            try ReminderSchedule.weekdays([], hour: 9, minute: 0).validate()
        )
    }

    private func date(
        _ value: String,
        calendar: Calendar
    ) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value)!
    }
}
