import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ReminderNotificationSchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testReconcilePreservesForeignNotificationsAndRemovesObsoleteReminderRequests() async throws {
        let reminderID = UUID()
        let obsoleteID = "schneerunner.reminder.\(reminderID.uuidString.lowercased()).obsolete"
        let foreignID = "com.example.foreign"
        let center = ReminderNotificationCenterFake(
            pending: [obsoleteID, foreignID]
        )
        let scheduler = ProductivityNotificationScheduler(center: center)
        let reminder = try ProductivityReminder(
            id: reminderID,
            title: "Daily",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 9, minute: 30),
            createdAt: now,
            updatedAt: now
        )

        _ = try await scheduler.reconcileReminders(
            [reminder],
            snoozes: [],
            now: now,
            calendar: utcCalendar()
        )

        XCTAssertTrue(center.pending.contains(foreignID))
        XCTAssertFalse(center.removedIdentifiers.contains(foreignID))
        XCTAssertTrue(center.removedIdentifiers.contains(obsoleteID))
        XCTAssertNotNil(
            center.addedRequests[
                "schneerunner.reminder.\(reminderID.uuidString.lowercased()).daily"
            ]
        )
    }

    func testDailyReminderUsesRepeatingCalendarTrigger() async throws {
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Daily",
            body: "At nine thirty",
            enabled: true,
            schedule: .daily(hour: 9, minute: 30),
            createdAt: now,
            updatedAt: now
        )
        let center = ReminderNotificationCenterFake()
        let scheduler = ProductivityNotificationScheduler(center: center)

        _ = try await scheduler.reconcileReminders(
            [reminder],
            snoozes: [],
            now: now,
            calendar: utcCalendar()
        )

        let identifier = "schneerunner.reminder.\(reminder.id.uuidString.lowercased()).daily"
        XCTAssertEqual(
            center.addedRequests[identifier]?.trigger,
            .calendar(hour: 9, minute: 30, weekday: nil)
        )
    }

    func testWeekdayReminderCreatesOneStableRepeatingRequestPerWeekday() async throws {
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Weekdays",
            body: nil,
            enabled: true,
            schedule: .weekdays([.monday, .friday], hour: 8, minute: 15),
            createdAt: now,
            updatedAt: now
        )
        let center = ReminderNotificationCenterFake()
        let scheduler = ProductivityNotificationScheduler(center: center)

        _ = try await scheduler.reconcileReminders(
            [reminder],
            snoozes: [],
            now: now,
            calendar: utcCalendar()
        )

        let prefix = "schneerunner.reminder.\(reminder.id.uuidString.lowercased()).weekday."
        XCTAssertEqual(
            center.addedRequests[prefix + "2"]?.trigger,
            .calendar(hour: 8, minute: 15, weekday: Weekday.monday.rawValue)
        )
        XCTAssertEqual(
            center.addedRequests[prefix + "6"]?.trigger,
            .calendar(hour: 8, minute: 15, weekday: Weekday.friday.rawValue)
        )
    }

    func testSnoozeUsesStableOneShotRequest() async throws {
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Reminder",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: now,
            updatedAt: now
        )
        let snooze = ReminderSnooze(
            id: UUID(),
            reminder: reminder,
            duration: .tenMinutes,
            now: now
        )
        let center = ReminderNotificationCenterFake()
        let scheduler = ProductivityNotificationScheduler(center: center)

        _ = try await scheduler.reconcileReminders(
            [reminder],
            snoozes: [snooze],
            now: now,
            calendar: utcCalendar()
        )

        let identifier = "schneerunner.snooze.\(snooze.id.uuidString.lowercased())"
        XCTAssertEqual(
            center.addedRequests[identifier]?.trigger,
            .timeInterval(10 * 60)
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}

@MainActor
private final class ReminderNotificationCenterFake: ProductivityNotificationCenterClient {
    private(set) var pending: Set<String>
    private(set) var addedRequests: [String: ProductivityNotificationRequest] = [:]
    private(set) var removedIdentifiers: Set<String> = []

    init(pending: Set<String> = []) {
        self.pending = pending
    }

    func currentAuthorizationState() async -> NotificationAuthorizationState {
        .authorized
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func pendingIdentifiers() async -> Set<String> {
        pending
    }

    func add(_ request: ProductivityNotificationRequest) async throws {
        addedRequests[request.identifier] = request
        pending.insert(request.identifier)
    }

    func removePending(identifiers: Set<String>) {
        removedIdentifiers.formUnion(identifiers)
        pending.subtract(identifiers)
    }
}
