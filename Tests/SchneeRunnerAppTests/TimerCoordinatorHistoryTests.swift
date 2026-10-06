import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerCoordinatorHistoryTests: XCTestCase {
    func testHistoryFailureDoesNotRollBackCompletedTimer() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseDirectory) }
        let store = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: FileManager.default
        )
        let scheduler = HistoryTestNotificationScheduler()
        let historyRecorder = FailingHistoryRecorder()
        let start = Date(timeIntervalSince1970: 1_791_331_200)
        let coordinator = TimerCoordinator(
            snapshot: ProductivitySnapshot(),
            store: store,
            notificationScheduler: scheduler,
            historyRecorder: historyRecorder
        )
        var reportedError: Error?
        coordinator.onHistoryError = { error in
            reportedError = error
        }
        let id = try await coordinator.start(
            title: "Short",
            duration: 10,
            now: start
        )

        try await coordinator.reconcile(now: start.addingTimeInterval(11))

        let persisted = try XCTUnwrap(
            try store.load().timers.first { $0.id == id }
        )
        XCTAssertEqual(persisted.state, .completed)
        XCTAssertEqual(historyRecorder.entries.count, 1)
        XCTAssertEqual(
            historyRecorder.entries.first?.kind,
            .countdownCompleted
        )
        XCTAssertNotNil(reportedError as? HistoryRecordingFailure)
    }
}

@MainActor
private final class FailingHistoryRecorder: ProductivityHistoryRecording {
    var entries: [ProductivityHistoryEntry] = []

    func record(_ entry: ProductivityHistoryEntry) throws {
        entries.append(entry)
        throw HistoryRecordingFailure.expected
    }
}

private enum HistoryRecordingFailure: Error {
    case expected
}

@MainActor
private final class HistoryTestNotificationScheduler: ProductivityNotificationScheduling {
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
