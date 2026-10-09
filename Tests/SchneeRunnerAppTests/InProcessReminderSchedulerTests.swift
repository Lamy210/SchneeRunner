import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class InProcessReminderSchedulerTests: XCTestCase {
    func testOneShotReminderDeliversOnlyWhenIntervalCrossesFireDate() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let fireDate = date(2026, 10, 9, 10, 0)
        let reminder = try makeReminder(
            title: "Stand",
            schedule: .once(fireDate)
        )
        try fixture.stateStore.save(
            ProductivitySnapshot(reminders: [reminder])
        )

        fixture.scheduler.start(now: fireDate.addingTimeInterval(-60))
        try fixture.scheduler.evaluate(now: fireDate.addingTimeInterval(-1))
        XCTAssertEqual(fixture.presenter.events, [])

        try fixture.scheduler.evaluate(now: fireDate)
        XCTAssertEqual(
            fixture.presenter.events,
            [.reminderDue(title: "Stand", body: "Stretch")]
        )
    }

    func testDisabledReminderDoesNotDeliver() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let fireDate = date(2026, 10, 9, 10, 0)
        let reminder = try makeReminder(
            title: "Disabled",
            schedule: .once(fireDate),
            enabled: false
        )
        try fixture.stateStore.save(
            ProductivitySnapshot(reminders: [reminder])
        )

        fixture.scheduler.start(now: fireDate.addingTimeInterval(-60))
        try fixture.scheduler.evaluate(now: fireDate.addingTimeInterval(60))

        XCTAssertEqual(fixture.presenter.events, [])
    }

    func testDailyReminderSuppressesDuplicateOccurrenceButAllowsNextDay() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let reminder = try makeReminder(
            title: "Daily",
            schedule: .daily(hour: 9, minute: 0)
        )
        try fixture.stateStore.save(
            ProductivitySnapshot(reminders: [reminder])
        )

        fixture.scheduler.start(now: date(2026, 10, 9, 8, 0))
        try fixture.scheduler.evaluate(now: date(2026, 10, 9, 9, 30))
        try fixture.scheduler.evaluate(now: date(2026, 10, 9, 9, 30))
        try fixture.scheduler.evaluate(now: date(2026, 10, 10, 9, 30))

        XCTAssertEqual(
            fixture.presenter.events,
            [
                .reminderDue(title: "Daily", body: "Stretch"),
                .reminderDue(title: "Daily", body: "Stretch")
            ]
        )
    }

    func testWeekdayAndSnoozeOccurrencesUseExistingScheduleSemantics() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let reminder = try makeReminder(
            title: "Weekday",
            schedule: .weekdays([.friday], hour: 9, minute: 0)
        )
        let snooze = ReminderSnooze(
            id: UUID(),
            reminderID: reminder.id,
            title: "Snoozed",
            body: nil,
            fireDate: date(2026, 10, 9, 9, 15)
        )
        try fixture.stateStore.save(
            ProductivitySnapshot(
                reminders: [reminder],
                snoozes: [snooze]
            )
        )

        fixture.scheduler.start(now: date(2026, 10, 9, 8, 0))
        try fixture.scheduler.evaluate(now: date(2026, 10, 9, 9, 30))

        XCTAssertEqual(
            fixture.presenter.events,
            [
                .reminderDue(title: "Weekday", body: "Stretch"),
                .reminderDue(title: "Snoozed", body: nil)
            ]
        )
    }

    private func makeFixture() throws -> ReminderSchedulerFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let suiteName = "InProcessReminderSchedulerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let stateStore = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )
        let presenter = RecordingReminderFallbackPresenter()
        let deliveryStore = ReminderFallbackDeliveryStore(
            defaults: defaults,
            key: "delivered"
        )
        let scheduler = InProcessReminderScheduler(
            stateStore: stateStore,
            presenter: presenter,
            deliveryStore: deliveryStore,
            calendar: calendar,
            refreshInterval: 3600
        )
        return ReminderSchedulerFixture(
            baseDirectory: baseDirectory,
            defaults: defaults,
            defaultsSuiteName: suiteName,
            stateStore: stateStore,
            presenter: presenter,
            scheduler: scheduler
        )
    }

    private func makeReminder(
        title: String,
        schedule: ReminderSchedule,
        enabled: Bool = true
    ) throws -> ProductivityReminder {
        try ProductivityReminder(
            id: UUID(),
            title: title,
            body: "Stretch",
            enabled: enabled,
            schedule: schedule,
            createdAt: date(2026, 10, 1, 0, 0),
            updatedAt: date(2026, 10, 1, 0, 0)
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}

@MainActor
private final class RecordingReminderFallbackPresenter: ProductivityFallbackPresenting {
    private(set) var events: [ProductivityFallbackEvent] = []

    func present(_ event: ProductivityFallbackEvent) {
        events.append(event)
    }
}

private struct ReminderSchedulerFixture {
    let baseDirectory: URL
    let defaults: UserDefaults
    let defaultsSuiteName: String
    let stateStore: ProductivityStateStore
    let presenter: RecordingReminderFallbackPresenter
    let scheduler: InProcessReminderScheduler

    func cleanup() {
        scheduler.stop()
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
