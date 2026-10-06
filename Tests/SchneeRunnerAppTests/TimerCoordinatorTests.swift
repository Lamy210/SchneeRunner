import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerCoordinatorTests: XCTestCase {
    func testStartsMultipleConcurrentTimersAndPersistsThem() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        _ = try await fixture.coordinator.start(
            title: "Focus",
            duration: 1_500,
            now: fixture.start
        )
        _ = try await fixture.coordinator.start(
            title: "Build",
            duration: 600,
            now: fixture.start
        )

        XCTAssertEqual(fixture.coordinator.timers.count, 2)
        XCTAssertEqual(try fixture.store.load().timers.count, 2)
        XCTAssertEqual(fixture.scheduler.scheduledTimerIDs.count, 2)
    }

    func testPauseAndResumePersistAuthoritativeTimingState() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let id = try await fixture.coordinator.start(
            title: "Focus",
            duration: 1_500,
            now: fixture.start
        )

        try await fixture.coordinator.pause(
            id: id,
            now: fixture.start.addingTimeInterval(300)
        )
        var persisted = try XCTUnwrap(
            try fixture.store.load().timers.first { $0.id == id }
        )
        XCTAssertEqual(persisted.state, .paused)
        XCTAssertEqual(persisted.pausedRemaining, 1_200)
        XCTAssertNil(persisted.deadline)
        XCTAssertTrue(fixture.scheduler.cancelledTimerIDs.contains(id))

        try await fixture.coordinator.resume(
            id: id,
            now: fixture.start.addingTimeInterval(600)
        )
        persisted = try XCTUnwrap(
            try fixture.store.load().timers.first { $0.id == id }
        )
        XCTAssertEqual(persisted.state, .running)
        XCTAssertEqual(
            persisted.deadline,
            fixture.start.addingTimeInterval(1_800)
        )
    }

    func testReconcileCompletesOverdueTimerOnce() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let id = try await fixture.coordinator.start(
            title: "Short",
            duration: 10,
            now: fixture.start
        )
        let overdue = fixture.start.addingTimeInterval(11)

        try await fixture.coordinator.reconcile(now: overdue)
        let once = try fixture.store.load()
        try await fixture.coordinator.reconcile(
            now: overdue.addingTimeInterval(60)
        )
        let twice = try fixture.store.load()

        XCTAssertEqual(once, twice)
        XCTAssertEqual(
            try XCTUnwrap(once.timers.first { $0.id == id }).state,
            .completed
        )
        XCTAssertEqual(
            fixture.scheduler.cancelledTimerIDs.filter { $0 == id }.count,
            1
        )
    }

    func testCancelPersistsAndCancelsNotification() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let id = try await fixture.coordinator.start(
            title: "Focus",
            duration: 60,
            now: fixture.start
        )

        try await fixture.coordinator.cancel(id: id)

        XCTAssertEqual(
            try XCTUnwrap(
                try fixture.store.load().timers.first { $0.id == id }
            ).state,
            .cancelled
        )
        XCTAssertTrue(fixture.scheduler.cancelledTimerIDs.contains(id))
    }

    func testRefreshCallbackContinuesDuringEventTrackingMode() throws {
        let fixture = try makeFixture(refreshInterval: 0.01)
        defer { fixture.cleanup() }
        var callbackCount = 0
        fixture.coordinator.onChange = { _ in
            callbackCount += 1
        }

        fixture.coordinator.startRefreshing()
        defer { fixture.coordinator.stopRefreshing() }
        RunLoop.main.run(
            mode: .eventTracking,
            before: Date().addingTimeInterval(0.05)
        )

        XCTAssertGreaterThan(callbackCount, 0)
    }

    private func makeFixture(
        refreshInterval: TimeInterval = 1
    ) throws -> TimerCoordinatorFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let store = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: FileManager.default
        )
        let scheduler = FakeProductivityNotificationScheduler()
        let snapshot = ProductivitySnapshot()
        return TimerCoordinatorFixture(
            baseDirectory: baseDirectory,
            start: Date(timeIntervalSince1970: 1_791_331_200),
            store: store,
            scheduler: scheduler,
            coordinator: TimerCoordinator(
                snapshot: snapshot,
                store: store,
                notificationScheduler: scheduler,
                refreshInterval: refreshInterval
            )
        )
    }
}

@MainActor
private final class FakeProductivityNotificationScheduler: ProductivityNotificationScheduling {
    var scheduledTimerIDs: [UUID] = []
    var cancelledTimerIDs: [UUID] = []

    func scheduleTimer(
        _ timer: ProductivityCountdownTimer,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        scheduledTimerIDs.append(timer.id)
        return .scheduled
    }

    func cancelTimer(id: UUID) async {
        cancelledTimerIDs.append(id)
    }

    func reconcileTimers(
        _ timers: [ProductivityCountdownTimer],
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        scheduledTimerIDs.append(contentsOf: timers.filter { $0.state == .running }.map(\.id))
        return .scheduled
    }
}

private struct TimerCoordinatorFixture {
    let baseDirectory: URL
    let start: Date
    let store: ProductivityStateStore
    let scheduler: FakeProductivityNotificationScheduler
    let coordinator: TimerCoordinator

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
