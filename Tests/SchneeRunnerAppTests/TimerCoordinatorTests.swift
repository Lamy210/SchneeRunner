import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerCoordinatorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_331_200)

    func testSupportsMultipleConcurrentTimersAndPersistsThem() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let scheduler = FakeProductivityNotificationScheduler()
        let coordinator = try TimerCoordinator(
            store: fixture.store,
            notificationScheduler: scheduler
        )

        let firstID = try await coordinator.start(
            title: "First",
            duration: 60,
            now: start
        )
        let secondID = try await coordinator.start(
            title: "Second",
            duration: 120,
            now: start
        )

        XCTAssertNotEqual(firstID, secondID)
        XCTAssertEqual(coordinator.timers.count, 2)
        XCTAssertEqual(try fixture.store.load().timers.count, 2)
        XCTAssertEqual(Set(scheduler.scheduledIDs), [firstID, secondID])
    }

    func testPauseAndResumePersistAuthoritativeTimingState() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let scheduler = FakeProductivityNotificationScheduler()
        let coordinator = try TimerCoordinator(
            store: fixture.store,
            notificationScheduler: scheduler
        )
        let id = try await coordinator.start(
            title: "Focus",
            duration: 120,
            now: start
        )

        try coordinator.pause(
            id: id,
            now: start.addingTimeInterval(30)
        )
        let paused = try timer(id: id, in: fixture.store.load())
        XCTAssertEqual(paused.state, .paused)
        XCTAssertEqual(paused.pausedRemaining, 90)
        XCTAssertTrue(scheduler.cancelledIDs.contains(id))

        try await coordinator.resume(
            id: id,
            now: start.addingTimeInterval(60)
        )
        let resumed = try timer(id: id, in: fixture.store.load())
        XCTAssertEqual(resumed.state, .running)
        XCTAssertEqual(resumed.deadline, start.addingTimeInterval(150))
        XCTAssertEqual(scheduler.scheduledIDs.filter { $0 == id }.count, 2)
    }

    func testReconcileCompletesOverdueTimerAndCancelsNotificationOnce() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let scheduler = FakeProductivityNotificationScheduler()
        let coordinator = try TimerCoordinator(
            store: fixture.store,
            notificationScheduler: scheduler
        )
        let id = try await coordinator.start(
            title: "Short",
            duration: 10,
            now: start
        )

        try coordinator.reconcile(now: start.addingTimeInterval(11))
        let completed = try timer(id: id, in: fixture.store.load())
        XCTAssertEqual(completed.state, .completed)
        XCTAssertEqual(completed.completedAt, start.addingTimeInterval(10))
        XCTAssertEqual(scheduler.cancelledIDs.filter { $0 == id }.count, 1)

        try coordinator.reconcile(now: start.addingTimeInterval(120))
        XCTAssertEqual(scheduler.cancelledIDs.filter { $0 == id }.count, 1)
    }

    func testCancelPersistsCancelledStateAndCancelsNotification() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let scheduler = FakeProductivityNotificationScheduler()
        let coordinator = try TimerCoordinator(
            store: fixture.store,
            notificationScheduler: scheduler
        )
        let id = try await coordinator.start(
            title: "Cancel me",
            duration: 60,
            now: start
        )

        try coordinator.cancel(id: id)

        let cancelled = try timer(id: id, in: fixture.store.load())
        XCTAssertEqual(cancelled.state, .cancelled)
        XCTAssertTrue(scheduler.cancelledIDs.contains(id))
    }

    func testRefreshPublishesWhileEventTrackingModeIsActive() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let scheduler = FakeProductivityNotificationScheduler()
        let coordinator = try TimerCoordinator(
            store: fixture.store,
            notificationScheduler: scheduler,
            refreshInterval: 0.01
        )
        var callbackCount = 0
        coordinator.onChange = { _ in
            callbackCount += 1
        }

        coordinator.startRefreshing()
        defer { coordinator.stopRefreshing() }

        let deadline = Date().addingTimeInterval(0.2)
        while callbackCount == 0, Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.01)
            )
        }

        XCTAssertGreaterThan(callbackCount, 0)
    }

    private func makeFixture() throws -> TimerCoordinatorFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        return TimerCoordinatorFixture(
            baseDirectory: baseDirectory,
            store: ProductivityStateStore(
                baseDirectory: baseDirectory,
                fileManager: FileManager.default
            )
        )
    }

    private func timer(
        id: UUID,
        in snapshot: ProductivitySnapshot
    ) throws -> ProductivityCountdownTimer {
        try XCTUnwrap(snapshot.timers.first { $0.id == id })
    }
}

@MainActor
private final class FakeProductivityNotificationScheduler: ProductivityNotificationScheduling {
    var result: ProductivityNotificationSchedulingResult = .scheduled
    var scheduledIDs: [UUID] = []
    var cancelledIDs: [UUID] = []

    func scheduleTimer(
        id: UUID,
        title _: String,
        deadline _: Date,
        now _: Date
    ) async -> ProductivityNotificationSchedulingResult {
        scheduledIDs.append(id)
        return result
    }

    func cancelTimer(id: UUID) {
        cancelledIDs.append(id)
    }
}

private struct TimerCoordinatorFixture {
    let baseDirectory: URL
    let store: ProductivityStateStore

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
