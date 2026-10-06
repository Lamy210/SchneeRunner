import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerCoordinatorRefreshTests: XCTestCase {
    func testRefreshTickPublishesWithoutResynchronizingNotifications() async throws {
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
        let reconcileExpectation = expectation(
            description: "display refresh must not reconcile notifications"
        )
        reconcileExpectation.isInverted = true
        scheduler.onReconcile = {
            reconcileExpectation.fulfill()
        }

        _ = coordinator.perform(NSSelectorFromString("refreshTick"))
        await fulfillment(
            of: [reconcileExpectation],
            timeout: 0.05
        )

        XCTAssertEqual(changeCount, 1)
        XCTAssertEqual(scheduler.reconcileCount, 0)
    }
}

@MainActor
private final class RefreshCountingNotificationScheduler: ProductivityNotificationScheduling {
    private(set) var reconcileCount = 0
    var onReconcile: (() -> Void)?

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
        onReconcile?()
        return .scheduled
    }
}
