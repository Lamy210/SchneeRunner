import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityHistoryCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testTimerCompletionRecordsHistory() async throws {
        let fixture = try makeTimerFixture()
        defer { fixture.cleanup() }
        let id = try await fixture.coordinator.start(
            title: "Focus",
            duration: 10,
            now: now
        )

        try await fixture.coordinator.reconcile(
            now: now.addingTimeInterval(11)
        )

        XCTAssertEqual(fixture.history.entries.count, 1)
        let entry = try XCTUnwrap(fixture.history.entries.first)
        XCTAssertEqual(entry.kind, .countdownCompleted)
        XCTAssertEqual(entry.sourceID, id)
        XCTAssertEqual(entry.title, "Focus")
        XCTAssertEqual(entry.occurredAt, now.addingTimeInterval(10))
    }

    func testHistoryFailureDoesNotRollbackTimerCompletion() async throws {
        let history = RecordingHistoryRecorder(error: HistoryRecordingFailure.expected)
        let fixture = try makeTimerFixture(history: history)
        defer { fixture.cleanup() }
        let id = try await fixture.coordinator.start(
            title: "Focus",
            duration: 10,
            now: now
        )
        var errors: [Error] = []
        fixture.coordinator.onHistoryError = { errors.append($0) }

        try await fixture.coordinator.reconcile(
            now: now.addingTimeInterval(11)
        )

        let persisted = try XCTUnwrap(
            try fixture.store.load().timers.first { $0.id == id }
        )
        XCTAssertEqual(persisted.state, .completed)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first as? HistoryRecordingFailure, .expected)
    }

    func testPomodoroRecordsFocusAndBreakCompletions() async throws {
        let baseDirectory = try makeBaseDirectory()
        defer { try? FileManager.default.removeItem(at: baseDirectory) }
        let store = ProductivityStateStore(baseDirectory: baseDirectory)
        try store.save(ProductivitySnapshot())
        let history = RecordingHistoryRecorder()
        let scheduler = HistoryPomodoroScheduler()
        let coordinator = PomodoroCoordinator(
            snapshot: ProductivitySnapshot(),
            store: store,
            notificationScheduler: scheduler,
            historyRecorder: history
        )
        let id = try await coordinator.start(
            configuration: PomodoroConfiguration(),
            now: now
        )

        try await coordinator.reconcile(
            now: now.addingTimeInterval(25 * 60)
        )
        try await coordinator.startCurrentPhase(
            now: now.addingTimeInterval(25 * 60)
        )
        try await coordinator.reconcile(
            now: now.addingTimeInterval(30 * 60)
        )

        XCTAssertEqual(history.entries.map(\.kind), [
            .pomodoroFocusCompleted,
            .pomodoroBreakCompleted
        ])
        XCTAssertTrue(history.entries.allSatisfy { $0.sourceID == id })
    }

    func testSnoozeRecordsObservableReminderAcknowledgement() async throws {
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Standup",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: now,
            updatedAt: now
        )
        let snapshot = ProductivitySnapshot(reminders: [reminder])
        let baseDirectory = try makeBaseDirectory()
        defer { try? FileManager.default.removeItem(at: baseDirectory) }
        let store = ProductivityStateStore(baseDirectory: baseDirectory)
        try store.save(snapshot)
        let history = RecordingHistoryRecorder()
        let coordinator = ReminderCoordinator(
            snapshot: snapshot,
            store: store,
            notificationScheduler: HistoryReminderScheduler(),
            historyRecorder: history,
            calendar: Calendar(identifier: .gregorian)
        )

        _ = try await coordinator.snooze(
            id: reminder.id,
            duration: .fiveMinutes,
            now: now
        )

        let entry = try XCTUnwrap(history.entries.first)
        XCTAssertEqual(entry.kind, .reminderAcknowledged)
        XCTAssertEqual(entry.sourceID, reminder.id)
        XCTAssertEqual(entry.title, reminder.title)
        XCTAssertEqual(entry.occurredAt, now)
    }

    private func makeTimerFixture(
        history: RecordingHistoryRecorder = RecordingHistoryRecorder()
    ) throws -> HistoryTimerFixture {
        let baseDirectory = try makeBaseDirectory()
        let store = ProductivityStateStore(baseDirectory: baseDirectory)
        let snapshot = ProductivitySnapshot()
        try store.save(snapshot)
        let scheduler = HistoryTimerScheduler()
        let coordinator = TimerCoordinator(
            snapshot: snapshot,
            store: store,
            notificationScheduler: scheduler,
            historyRecorder: history
        )
        return HistoryTimerFixture(
            baseDirectory: baseDirectory,
            store: store,
            history: history,
            coordinator: coordinator
        )
    }

    private func makeBaseDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}

@MainActor
private final class RecordingHistoryRecorder: ProductivityHistoryRecording {
    private(set) var entries: [ProductivityHistoryEntry] = []
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func record(_ entry: ProductivityHistoryEntry) throws {
        if let error {
            throw error
        }
        entries.append(entry)
    }
}

private enum HistoryRecordingFailure: Error, Equatable {
    case expected
}

@MainActor
private final class HistoryTimerScheduler: ProductivityNotificationScheduling {
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

@MainActor
private final class HistoryPomodoroScheduler: PomodoroNotificationScheduling {
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

@MainActor
private final class HistoryReminderScheduler: ReminderNotificationScheduling {
    func reconcileReminders(
        _: [ProductivityReminder],
        snoozes _: [ReminderSnooze],
        now _: Date,
        calendar _: Calendar
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .scheduled
    }
}

@MainActor
private struct HistoryTimerFixture {
    let baseDirectory: URL
    let store: ProductivityStateStore
    let history: RecordingHistoryRecorder
    let coordinator: TimerCoordinator

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
