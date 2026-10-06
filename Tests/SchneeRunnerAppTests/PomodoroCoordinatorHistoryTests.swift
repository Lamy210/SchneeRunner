import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class PomodoroCoordinatorHistoryTests: XCTestCase {
    func testHistoryFailureDoesNotRollBackCompletedFocusPhase() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseDirectory) }
        let store = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: FileManager.default
        )
        let scheduler = PomodoroHistoryNotificationScheduler()
        let historyRecorder = FailingPomodoroHistoryRecorder()
        let start = Date(timeIntervalSince1970: 1_791_331_200)
        let coordinator = PomodoroCoordinator(
            snapshot: ProductivitySnapshot(),
            store: store,
            notificationScheduler: scheduler,
            historyRecorder: historyRecorder
        )
        var reportedError: Error?
        coordinator.onHistoryError = { error in
            reportedError = error
        }
        let configuration = try PomodoroConfiguration(
            focusDuration: 10,
            shortBreakDuration: 5,
            longBreakDuration: 15,
            focusPhasesBeforeLongBreak: 4,
            autoStartNextPhase: false
        )
        _ = try await coordinator.start(
            configuration: configuration,
            now: start
        )

        try await coordinator.reconcile(now: start.addingTimeInterval(11))

        let persisted = try XCTUnwrap(try store.load().pomodoro)
        XCTAssertEqual(persisted.currentPhase, .shortBreak)
        XCTAssertEqual(persisted.state, .waiting)
        XCTAssertEqual(historyRecorder.entries.count, 1)
        XCTAssertEqual(
            historyRecorder.entries.first?.kind,
            .pomodoroFocusCompleted
        )
        XCTAssertNotNil(reportedError as? PomodoroHistoryFailure)
    }
}

@MainActor
private final class FailingPomodoroHistoryRecorder: ProductivityHistoryRecording {
    var entries: [ProductivityHistoryEntry] = []

    func record(_ entry: ProductivityHistoryEntry) throws {
        entries.append(entry)
        throw PomodoroHistoryFailure.expected
    }
}

private enum PomodoroHistoryFailure: Error {
    case expected
}

@MainActor
private final class PomodoroHistoryNotificationScheduler: PomodoroNotificationScheduling {
    func schedulePomodoro(
        _: PomodoroSession,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .scheduled
    }

    func cancelPomodoro(id _: UUID) async {}

    func reconcilePomodoro(
        _: PomodoroSession?,
        now _: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .scheduled
    }
}
