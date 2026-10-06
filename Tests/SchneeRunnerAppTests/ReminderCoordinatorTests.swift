import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ReminderCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testCreatePreservesTimerAndPomodoroSlices() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        _ = try await fixture.coordinator.create(
            title: "Standup",
            body: "Join call",
            schedule: .daily(hour: 9, minute: 0),
            enabled: true,
            now: now
        )

        let persisted = try fixture.store.load()
        XCTAssertEqual(persisted.timers, [fixture.timer])
        XCTAssertEqual(persisted.pomodoro, fixture.pomodoro)
        XCTAssertEqual(persisted.reminders.count, 1)
        XCTAssertEqual(fixture.scheduler.reconcileCount, 1)
    }

    func testCreatePreservesSlicesWrittenAfterCoordinatorInitialization() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let replacementTimer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Newer timer",
            duration: 600,
            startedAt: now
        )
        let replacementPomodoro = try PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: now.addingTimeInterval(60)
        )
        try fixture.store.save(
            ProductivitySnapshot(
                timers: [replacementTimer],
                pomodoro: replacementPomodoro
            )
        )

        _ = try await fixture.coordinator.create(
            title: "Reminder",
            body: nil,
            schedule: .daily(hour: 10, minute: 0),
            enabled: true,
            now: now
        )

        let persisted = try fixture.store.load()
        XCTAssertEqual(persisted.timers, [replacementTimer])
        XCTAssertEqual(persisted.pomodoro, replacementPomodoro)
        XCTAssertEqual(persisted.reminders.count, 1)
    }

    func testSnoozePersistsTemporaryOccurrenceWithoutChangingRecurrence() async throws {
        let reminder = try makeReminder()
        let fixture = try makeFixture(reminders: [reminder])
        defer { fixture.cleanup() }
        let originalSchedule = reminder.schedule

        _ = try await fixture.coordinator.snooze(
            id: reminder.id,
            duration: .fifteenMinutes,
            now: now
        )

        let persisted = try fixture.store.load()
        XCTAssertEqual(persisted.reminders.first?.schedule, originalSchedule)
        XCTAssertEqual(persisted.snoozes.count, 1)
        XCTAssertEqual(persisted.snoozes.first?.reminderID, reminder.id)
        XCTAssertEqual(
            persisted.snoozes.first?.fireDate,
            now.addingTimeInterval(15 * 60)
        )
    }

    func testDisablingReminderPersistsAndReconcilesNotifications() async throws {
        let reminder = try makeReminder()
        let fixture = try makeFixture(reminders: [reminder])
        defer { fixture.cleanup() }

        try await fixture.coordinator.setEnabled(
            id: reminder.id,
            enabled: false,
            now: now.addingTimeInterval(30)
        )

        let persisted = try fixture.store.load()
        XCTAssertEqual(persisted.reminders.first?.enabled, false)
        XCTAssertEqual(fixture.scheduler.reconcileCount, 1)
        XCTAssertEqual(fixture.scheduler.lastReminders.first?.enabled, false)
    }

    func testDeleteRemovesReminderAndAssociatedSnoozes() async throws {
        let reminder = try makeReminder()
        let snooze = ReminderSnooze(
            id: UUID(),
            reminder: reminder,
            duration: .tenMinutes,
            now: now
        )
        let fixture = try makeFixture(
            reminders: [reminder],
            snoozes: [snooze]
        )
        defer { fixture.cleanup() }

        try await fixture.coordinator.delete(id: reminder.id, now: now)

        let persisted = try fixture.store.load()
        XCTAssertTrue(persisted.reminders.isEmpty)
        XCTAssertTrue(persisted.snoozes.isEmpty)
        XCTAssertEqual(fixture.scheduler.reconcileCount, 1)
    }

    func testReconcileDropsExpiredSnoozeAndPreservesOtherSlices() async throws {
        let reminder = try makeReminder()
        let expired = ReminderSnooze(
            id: UUID(),
            reminderID: reminder.id,
            title: reminder.title,
            body: reminder.body,
            fireDate: now.addingTimeInterval(-1)
        )
        let fixture = try makeFixture(
            reminders: [reminder],
            snoozes: [expired]
        )
        defer { fixture.cleanup() }

        try await fixture.coordinator.reconcile(now: now)

        let persisted = try fixture.store.load()
        XCTAssertTrue(persisted.snoozes.isEmpty)
        XCTAssertEqual(persisted.timers, [fixture.timer])
        XCTAssertEqual(persisted.pomodoro, fixture.pomodoro)
        XCTAssertEqual(fixture.scheduler.reconcileCount, 1)
    }

    private func makeFixture(
        reminders: [ProductivityReminder] = [],
        snoozes: [ReminderSnooze] = []
    ) throws -> ReminderCoordinatorFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Timer",
            duration: 60 * 60,
            startedAt: now
        )
        let pomodoro = try PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: now
        )
        let snapshot = ProductivitySnapshot(
            timers: [timer],
            reminders: reminders,
            pomodoro: pomodoro,
            snoozes: snoozes
        )
        let store = ProductivityStateStore(baseDirectory: baseDirectory)
        try store.save(snapshot)
        let scheduler = ReminderNotificationSchedulerSpy()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let coordinator = ReminderCoordinator(
            snapshot: snapshot,
            store: store,
            notificationScheduler: scheduler,
            calendar: calendar
        )

        return ReminderCoordinatorFixture(
            baseDirectory: baseDirectory,
            timer: timer,
            pomodoro: pomodoro,
            store: store,
            scheduler: scheduler,
            coordinator: coordinator
        )
    }

    private func makeReminder() throws -> ProductivityReminder {
        try ProductivityReminder(
            id: UUID(),
            title: "Standup",
            body: nil,
            enabled: true,
            schedule: .weekdays([.monday, .friday], hour: 9, minute: 0),
            createdAt: now,
            updatedAt: now
        )
    }
}

@MainActor
private final class ReminderNotificationSchedulerSpy: ProductivityReminderNotificationScheduling {
    private(set) var reconcileCount = 0
    private(set) var lastReminders: [ProductivityReminder] = []
    private(set) var lastSnoozes: [ReminderSnooze] = []

    func reconcileReminders(
        _ reminders: [ProductivityReminder],
        snoozes: [ReminderSnooze],
        now _: Date,
        calendar _: Calendar
    ) async throws -> ProductivityNotificationDeliveryStatus {
        reconcileCount += 1
        lastReminders = reminders
        lastSnoozes = snoozes
        return .scheduled
    }
}

@MainActor
private struct ReminderCoordinatorFixture {
    let baseDirectory: URL
    let timer: ProductivityCountdownTimer
    let pomodoro: PomodoroSession
    let store: ProductivityStateStore
    let scheduler: ReminderNotificationSchedulerSpy
    let coordinator: ReminderCoordinator

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
