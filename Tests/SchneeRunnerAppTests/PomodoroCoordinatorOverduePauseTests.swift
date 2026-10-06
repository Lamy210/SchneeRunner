import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class PomodoroCoordinatorOverduePauseTests: XCTestCase {
    func testPauseAfterExpiredPhaseSchedulesAutoStartedNextPhase() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let now = Date(timeIntervalSince1970: 1_791_331_200)
        let store = ProductivityStateStore(baseDirectory: baseDirectory)
        try store.save(ProductivitySnapshot())
        let scheduler = OverduePauseScheduler()
        let coordinator = PomodoroCoordinator(
            snapshot: ProductivitySnapshot(),
            store: store,
            notificationScheduler: scheduler
        )
        let configuration = try PomodoroConfiguration(
            autoStartNextPhase: true
        )

        let id = try await coordinator.start(
            configuration: configuration,
            now: now
        )
        try await coordinator.pause(
            now: now.addingTimeInterval(26 * 60)
        )

        let persisted = try store.load()
        XCTAssertEqual(persisted.pomodoro?.currentPhase, .shortBreak)
        XCTAssertEqual(persisted.pomodoro?.state, .running)
        XCTAssertEqual(scheduler.scheduledSessionIDs, [id, id])
        XCTAssertTrue(scheduler.cancelledSessionIDs.isEmpty)
    }
}

@MainActor
private final class OverduePauseScheduler: PomodoroNotificationScheduling {
    private(set) var scheduledSessionIDs: [UUID] = []
    private(set) var cancelledSessionIDs: [UUID] = []

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
        _: PomodoroSession?,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .scheduled
    }
}
