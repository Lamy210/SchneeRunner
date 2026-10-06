import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerCoordinatorSnapshotIsolationTests: XCTestCase {
    func testStartingTimerPreservesReminderAndPomodoroSlices() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        _ = try await fixture.coordinator.start(
            title: "Timer",
            duration: 300,
            now: fixture.now
        )

        let persisted = try fixture.store.load()
        XCTAssertEqual(persisted.reminders, [fixture.reminder])
        XCTAssertEqual(persisted.pomodoro, fixture.pomodoro)
        XCTAssertEqual(persisted.timers.count, 1)
    }

    func testTimerReconciliationDoesNotAdvancePomodoro() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let overduePomodoroTime = fixture.now.addingTimeInterval(25 * 60)

        try await fixture.coordinator.reconcile(now: overduePomodoroTime)

        let persisted = try fixture.store.load()
        XCTAssertEqual(persisted.pomodoro, fixture.pomodoro)
        XCTAssertEqual(persisted.reminders, [fixture.reminder])
    }

    private func makeFixture() throws -> SnapshotIsolationFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )

        let now = Date(timeIntervalSince1970: 1_791_331_200)
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Reminder",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: now,
            updatedAt: now
        )
        let pomodoro = try PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: now
        )
        let initial = ProductivitySnapshot(
            reminders: [reminder],
            pomodoro: pomodoro
        )
        let store = ProductivityStateStore(baseDirectory: baseDirectory)
        try store.save(initial)
        let scheduler = SnapshotIsolationNotificationScheduler()
        let coordinator = TimerCoordinator(
            snapshot: initial,
            store: store,
            notificationScheduler: scheduler
        )

        return SnapshotIsolationFixture(
            baseDirectory: baseDirectory,
            now: now,
            reminder: reminder,
            pomodoro: pomodoro,
            store: store,
            coordinator: coordinator
        )
    }
}

@MainActor
private final class SnapshotIsolationNotificationScheduler: ProductivityNotificationScheduling {
    func scheduleTimer(
        _: ProductivityCountdownTimer,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .scheduled
    }

    func cancelTimer(id _: UUID) async {}

    func reconcileTimers(
        _: [ProductivityCountdownTimer],
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .scheduled
    }
}

@MainActor
private struct SnapshotIsolationFixture {
    let baseDirectory: URL
    let now: Date
    let reminder: ProductivityReminder
    let pomodoro: PomodoroSession
    let store: ProductivityStateStore
    let coordinator: TimerCoordinator

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
