import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class PomodoroCoordinatorTests: XCTestCase {
    func testStartPersistsOneSessionAndSchedulesCurrentPhase() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let configuration = try PomodoroConfiguration()

        let id = try await fixture.coordinator.start(
            configuration: configuration,
            now: fixture.now
        )

        let persisted = try fixture.store.load()
        XCTAssertEqual(persisted.pomodoro?.id, id)
        XCTAssertEqual(persisted.pomodoro?.currentPhase, .focus)
        XCTAssertEqual(persisted.pomodoro?.state, .running)
        XCTAssertEqual(fixture.scheduler.scheduledSessionIDs, [id])
    }

    func testStartingSecondSessionIsRejectedWithoutReplacingFirst() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let configuration = try PomodoroConfiguration()
        let firstID = try await fixture.coordinator.start(
            configuration: configuration,
            now: fixture.now
        )

        do {
            _ = try await fixture.coordinator.start(
                configuration: configuration,
                now: fixture.now.addingTimeInterval(10)
            )
            XCTFail("Expected a second active Pomodoro to be rejected")
        } catch let error as PomodoroCoordinatorError {
            XCTAssertEqual(error, .sessionAlreadyActive(firstID))
        }

        XCTAssertEqual(try fixture.store.load().pomodoro?.id, firstID)
    }

    func testPauseAndResumePersistAuthoritativeTimingAndNotificationState() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let configuration = try PomodoroConfiguration()
        let id = try await fixture.coordinator.start(
            configuration: configuration,
            now: fixture.now
        )
        let pauseTime = fixture.now.addingTimeInterval(300)

        try await fixture.coordinator.pause(now: pauseTime)

        var persisted = try fixture.store.load()
        XCTAssertEqual(persisted.pomodoro?.state, .paused)
        XCTAssertEqual(persisted.pomodoro?.pausedRemaining, 20 * 60)
        XCTAssertEqual(fixture.scheduler.cancelledSessionIDs, [id])

        let resumeTime = pauseTime.addingTimeInterval(60)
        try await fixture.coordinator.resume(now: resumeTime)

        persisted = try fixture.store.load()
        XCTAssertEqual(persisted.pomodoro?.state, .running)
        XCTAssertEqual(
            persisted.pomodoro?.phaseDeadline,
            resumeTime.addingTimeInterval(20 * 60)
        )
        XCTAssertEqual(fixture.scheduler.scheduledSessionIDs, [id, id])
    }

    func testReconcileAdvancesExactlyOneOverduePhaseAndPreservesOtherSlices() async throws {
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Timer",
            duration: 60 * 60,
            startedAt: Date(timeIntervalSince1970: 1_791_331_200)
        )
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Reminder",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: Date(timeIntervalSince1970: 1_791_331_200),
            updatedAt: Date(timeIntervalSince1970: 1_791_331_200)
        )
        let fixture = try makeFixture(
            snapshot: ProductivitySnapshot(
                timers: [timer],
                reminders: [reminder]
            )
        )
        defer { fixture.cleanup() }
        let configuration = try PomodoroConfiguration()
        _ = try await fixture.coordinator.start(
            configuration: configuration,
            now: fixture.now
        )

        try await fixture.coordinator.reconcile(
            now: fixture.now.addingTimeInterval(30 * 60)
        )

        let persisted = try fixture.store.load()
        XCTAssertEqual(persisted.pomodoro?.currentPhase, .shortBreak)
        XCTAssertEqual(persisted.pomodoro?.completedFocusCount, 1)
        XCTAssertEqual(persisted.pomodoro?.state, .waiting)
        XCTAssertEqual(persisted.timers, [timer])
        XCTAssertEqual(persisted.reminders, [reminder])
        XCTAssertEqual(fixture.scheduler.reconciledSessions.last??.currentPhase, .shortBreak)
    }

    func testCoordinatorRestoresPersistedSessionOnInitialization() throws {
        let now = Date(timeIntervalSince1970: 1_791_331_200)
        let session = try PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: now
        )
        let snapshot = ProductivitySnapshot(pomodoro: session)
        let fixture = try makeFixture(snapshot: snapshot)
        defer { fixture.cleanup() }

        XCTAssertEqual(fixture.coordinator.session, session)
    }

    func testStartPreservesSlicesWrittenAfterCoordinatorInitialization() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Latest Reminder",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 10, minute: 0),
            createdAt: fixture.now,
            updatedAt: fixture.now
        )
        try fixture.store.save(
            ProductivitySnapshot(reminders: [reminder])
        )

        _ = try await fixture.coordinator.start(
            configuration: PomodoroConfiguration(),
            now: fixture.now
        )

        let persisted = try fixture.store.load()
        XCTAssertEqual(persisted.reminders, [reminder])
        XCTAssertNotNil(persisted.pomodoro)
    }

    private func makeFixture(
        snapshot: ProductivitySnapshot = ProductivitySnapshot()
    ) throws -> PomodoroCoordinatorFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let store = ProductivityStateStore(baseDirectory: baseDirectory)
        try store.save(snapshot)
        let scheduler = RecordingPomodoroNotificationScheduler()
        let coordinator = PomodoroCoordinator(
            snapshot: snapshot,
            store: store,
            notificationScheduler: scheduler
        )
        return PomodoroCoordinatorFixture(
            baseDirectory: baseDirectory,
            now: Date(timeIntervalSince1970: 1_791_331_200),
            store: store,
            scheduler: scheduler,
            coordinator: coordinator
        )
    }
}

@MainActor
private final class RecordingPomodoroNotificationScheduler: PomodoroNotificationScheduling {
    private(set) var scheduledSessionIDs: [UUID] = []
    private(set) var cancelledSessionIDs: [UUID] = []
    private(set) var reconciledSessions: [PomodoroSession?] = []

    func schedulePomodoro(
        _ session: PomodoroSession,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        scheduledSessionIDs.append(session.id)
        return .scheduled
    }

    func cancelPomodoro(id: UUID) async {
        cancelledSessionIDs.append(id)
    }

    func reconcilePomodoro(
        _ session: PomodoroSession?,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        reconciledSessions.append(session)
        return .scheduled
    }
}

@MainActor
private struct PomodoroCoordinatorFixture {
    let baseDirectory: URL
    let now: Date
    let store: ProductivityStateStore
    let scheduler: RecordingPomodoroNotificationScheduler
    let coordinator: PomodoroCoordinator

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
