@testable import SchneeRunnerCore
import XCTest

final class ProductivityReminderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testEnabledReminderComputesNextOccurrence() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Standup",
            body: "Join call",
            enabled: true,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: now,
            updatedAt: now
        )

        XCTAssertNotNil(
            reminder.nextOccurrence(after: now, calendar: calendar)
        )
    }

    func testDisabledReminderHasNoNextOccurrence() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Standup",
            body: nil,
            enabled: false,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: now,
            updatedAt: now
        )

        XCTAssertNil(
            reminder.nextOccurrence(after: now, calendar: calendar)
        )
    }

    func testConstructionRejectsInvalidSchedule() {
        XCTAssertThrowsError(
            try ProductivityReminder(
                id: UUID(),
                title: "Invalid",
                body: nil,
                enabled: true,
                schedule: .daily(hour: 25, minute: 0),
                createdAt: now,
                updatedAt: now
            )
        )
    }

    func testDecodingRejectsInvalidSchedule() throws {
        let data = Data("""
        {
          "id":"33333333-3333-3333-3333-333333333333",
          "title":"Invalid",
          "enabled":true,
          "schedule":{"kind":"daily","hour":25,"minute":0},
          "createdAt":0,
          "updatedAt":0
        }
        """.utf8)

        XCTAssertThrowsError(
            try JSONDecoder().decode(ProductivityReminder.self, from: data)
        )
    }
}
