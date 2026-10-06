import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerCoordinatorReminderPreservationTests: XCTestCase {
    func testStartingTimerPreservesExistingReminders() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let now = Date(timeIntervalSince1970: 1_791_331_200)
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Standup",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: now,
            updatedAt: now
        )
        let store = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )
        let coordinator = TimerCoordinator(
            snapshot: ProductivitySnapshot(reminders: [reminder]),
            store: store,
            notificationScheduler: ReminderPreservationNotificationScheduler()
        )

        _ = try await coordinator.start(
            title: "Focus",
            duration: 300,
            now: now
        )

        XCTAssertEqual(
            try store.load().reminders,
            [reminder]
        )
    }
}

@MainActor
private final class ReminderPreservationNotificationScheduler: ProductivityNotificationScheduling {
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
