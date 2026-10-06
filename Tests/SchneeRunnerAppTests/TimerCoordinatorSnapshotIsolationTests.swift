import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerCoordinatorSnapshotIsolationTests: XCTestCase {
    func testStartingTimerPreservesReminderAndPomodoroSlices() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

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

        _ = try await coordinator.start(
            title: "Timer",
            duration: 300,
            now: now
        )

        let persisted = try store.load()
        XCTAssertEqual(persisted.reminders, [reminder])
        XCTAssertEqual(persisted.pomodoro, pomodoro)
        XCTAssertEqual(persisted.timers.count, 1)
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
