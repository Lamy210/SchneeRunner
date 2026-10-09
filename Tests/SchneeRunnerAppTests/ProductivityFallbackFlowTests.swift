import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityFallbackFlowTests: XCTestCase {
    func testTimerCompletionCallbackFiresExactlyOnceAcrossRepeatedReconciliation() async throws {
        let fixture = try makeTimerFixture()
        defer { fixture.cleanup() }
        let timerID = try await fixture.coordinator.start(
            title: "Tea",
            duration: 10,
            now: fixture.now
        )
        var completions: [ProductivityCountdownTimer] = []
        fixture.coordinator.onTimerCompleted = { timer in
            completions.append(timer)
        }

        try await fixture.coordinator.reconcile(
            now: fixture.now.addingTimeInterval(11)
        )
        try await fixture.coordinator.reconcile(
            now: fixture.now.addingTimeInterval(30)
        )

        XCTAssertEqual(completions.map(\.id), [timerID])
        XCTAssertEqual(completions.first?.state, .completed)
    }

    func testPomodoroPhaseCompletionCallbackFiresExactlyOnceAcrossRepeatedReconciliation() async throws {
        let fixture = try makePomodoroFixture()
        defer { fixture.cleanup() }
        _ = try await fixture.coordinator.start(
            configuration: PomodoroConfiguration(),
            now: fixture.now
        )
        var completions: [(PomodoroSession, Date)] = []
        fixture.coordinator.onPhaseCompleted = { session, completedAt in
            completions.append((session, completedAt))
        }

        try await fixture.coordinator.reconcile(
            now: fixture.now.addingTimeInterval(30 * 60)
        )
        try await fixture.coordinator.reconcile(
            now: fixture.now.addingTimeInterval(30 * 60 + 1)
        )

        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.0.currentPhase, .focus)
        XCTAssertEqual(
            completions.first?.1,
            fixture.now.addingTimeInterval(25 * 60)
        )
    }

    func testFallbackRouterQueuesUntilDisabledStatusThenFlushesOnce() {
        let presenter = RecordingFlowFallbackPresenter()
        let router = ProductivityFallbackRouter(presenter: presenter)

        router.enqueue(.timerCompleted(title: "Tea"))
        XCTAssertEqual(presenter.events, [])

        router.updateNotificationStatus(.disabled)
        XCTAssertEqual(presenter.events, [.timerCompleted(title: "Tea")])

        router.updateNotificationStatus(.disabled)
        XCTAssertEqual(presenter.events, [.timerCompleted(title: "Tea")])
    }

    func testFallbackRouterDiscardsPendingEventsWhenSystemNotificationIsScheduled() {
        let presenter = RecordingFlowFallbackPresenter()
        let router = ProductivityFallbackRouter(presenter: presenter)

        router.enqueue(.pomodoroPhaseCompleted(phase: .focus))
        router.updateNotificationStatus(.scheduled)
        router.updateNotificationStatus(.disabled)

        XCTAssertEqual(presenter.events, [])
    }

    func testFallbackRouterPresentsImmediatelyWhenRuntimeStartsDisabled() {
        let presenter = RecordingFlowFallbackPresenter()
        let router = ProductivityFallbackRouter(
            presenter: presenter,
            initialNotificationStatus: .disabled
        )

        router.enqueue(.reminderDue(title: "Stand", body: nil))

        XCTAssertEqual(
            presenter.events,
            [.reminderDue(title: "Stand", body: nil)]
        )
    }

    private func makeTimerFixture() throws -> TimerFallbackFixture {
        let baseDirectory = try makeBaseDirectory()
        let store = ProductivityStateStore(baseDirectory: baseDirectory)
        let scheduler = DisabledTimerNotificationScheduler()
        let snapshot = ProductivitySnapshot()
        try store.save(snapshot)
        return TimerFallbackFixture(
            baseDirectory: baseDirectory,
            now: Date(timeIntervalSince1970: 1_791_331_200),
            coordinator: TimerCoordinator(
                snapshot: snapshot,
                store: store,
                notificationScheduler: scheduler
            )
        )
    }

    private func makePomodoroFixture() throws -> PomodoroFallbackFixture {
        let baseDirectory = try makeBaseDirectory()
        let store = ProductivityStateStore(baseDirectory: baseDirectory)
        let scheduler = DisabledPomodoroNotificationScheduler()
        let snapshot = ProductivitySnapshot()
        try store.save(snapshot)
        return PomodoroFallbackFixture(
            baseDirectory: baseDirectory,
            now: Date(timeIntervalSince1970: 1_791_331_200),
            coordinator: PomodoroCoordinator(
                snapshot: snapshot,
                store: store,
                notificationScheduler: scheduler
            )
        )
    }

    private func makeBaseDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}

@MainActor
private final class RecordingFlowFallbackPresenter: ProductivityFallbackPresenting {
    private(set) var events: [ProductivityFallbackEvent] = []

    func present(_ event: ProductivityFallbackEvent) {
        events.append(event)
    }
}

@MainActor
private final class DisabledTimerNotificationScheduler: ProductivityNotificationScheduling {
    func scheduleTimer(
        _: ProductivityCountdownTimer,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .disabled
    }

    func cancelTimer(id _: UUID) async {}

    func reconcileTimers(
        _: [ProductivityCountdownTimer],
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .disabled
    }
}

@MainActor
private final class DisabledPomodoroNotificationScheduler: PomodoroNotificationScheduling {
    func schedulePomodoro(
        _: PomodoroSession,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .disabled
    }

    func cancelPomodoro(id _: UUID) async {}

    func reconcilePomodoro(
        _: PomodoroSession?,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .disabled
    }
}

private struct TimerFallbackFixture {
    let baseDirectory: URL
    let now: Date
    let coordinator: TimerCoordinator

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}

private struct PomodoroFallbackFixture {
    let baseDirectory: URL
    let now: Date
    let coordinator: PomodoroCoordinator

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
