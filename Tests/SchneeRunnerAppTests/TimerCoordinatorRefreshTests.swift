import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerCoordinatorRefreshTests: XCTestCase {
    func testDisplayRefreshDoesNotResynchronizeNotificationsWithoutStateChanges() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let store = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )
        let scheduler = RefreshCountingNotificationScheduler()
        let coordinator = TimerCoordinator(
            snapshot: ProductivitySnapshot(),
            store: store,
            notificationScheduler: scheduler,
            refreshInterval: 0.01
        )
        var changeCount = 0
        coordinator.onChange = { _ in
            changeCount += 1
        }

        coordinator.startRefreshing()
        defer { coordinator.stopRefreshing() }
        RunLoop.main.run(
            mode: .eventTracking,
            before: Date().addingTimeInterval(0.05)
        )
        await Task.yield()
        await Task.yield()

        XCTAssertGreaterThan(changeCount, 0)
        XCTAssertEqual(scheduler.reconcileCount, 0)
    }
}

@MainActor
private final class RefreshCountingNotificationScheduler: ProductivityNotificationScheduling {
    private(set) var reconcileCount = 0

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
        reconcileCount += 1
        return .scheduled
    }
}
