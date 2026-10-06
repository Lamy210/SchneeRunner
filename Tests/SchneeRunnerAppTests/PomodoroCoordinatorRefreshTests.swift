import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class PomodoroCoordinatorRefreshTests: XCTestCase {
    func testRefreshPublishesClockWithoutReschedulingUntilPhaseChanges() async throws {
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
        let scheduler = RefreshRecordingPomodoroScheduler()
        let coordinator = try PomodoroCoordinator(
            store: store,
            notificationScheduler: scheduler
        )
        var publishedStates: [PomodoroSessionState?] = []
        coordinator.onChange = { session in
            publishedStates.append(session?.state)
        }

        _ = try await coordinator.start(
            configuration: PomodoroConfiguration(),
            now: now
        )
        scheduler.reconciledSessions.removeAll()
        publishedStates.removeAll()

        try await coordinator.refresh(
            now: now.addingTimeInterval(60)
        )

        XCTAssertEqual(publishedStates, [.running])
        XCTAssertTrue(scheduler.reconciledSessions.isEmpty)

        try await coordinator.refresh(
            now: now.addingTimeInterval(25 * 60)
        )

        XCTAssertEqual(coordinator.session?.currentPhase, .shortBreak)
        XCTAssertEqual(coordinator.session?.state, .waiting)
        XCTAssertEqual(scheduler.reconciledSessions.count, 1)
        XCTAssertEqual(
            scheduler.reconciledSessions.last??.currentPhase,
            .shortBreak
        )
    }
}

@MainActor
private final class RefreshRecordingPomodoroScheduler: PomodoroNotificationScheduling {
    var reconciledSessions: [PomodoroSession?] = []

    func schedulePomodoro(
        _: PomodoroSession,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .scheduled
    }

    func cancelPomodoro(id _: UUID) async {}

    func reconcilePomodoro(
        _ session: PomodoroSession?,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        reconciledSessions.append(session)
        return .scheduled
    }
}
