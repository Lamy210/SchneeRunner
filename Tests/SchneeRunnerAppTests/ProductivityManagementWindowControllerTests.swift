import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityManagementTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testContentTracksTimersRemindersPomodoroAndHistory() throws {
        let controller = ProductivityManagementWindowController()
        let timer = try makeTimer()
        let reminder = try makeReminder()
        let configuration = try PomodoroConfiguration(
            focusDuration: 50 * 60,
            shortBreakDuration: 10 * 60,
            longBreakDuration: 30 * 60,
            focusPhasesBeforeLongBreak: 3,
            autoStartNextPhase: true
        )
        let history = ProductivityHistory().appending(
            ProductivityHistoryEntry(
                id: UUID(),
                kind: .reminderAcknowledged,
                sourceID: reminder.id,
                title: reminder.title,
                occurredAt: now
            )
        )

        controller.setTimers([timer])
        controller.setReminders([reminder])
        controller.setPomodoroConfiguration(configuration)
        controller.setHistory(history)

        XCTAssertEqual(controller.timerIDs, [timer.id])
        XCTAssertEqual(controller.reminderIDs, [reminder.id])
        XCTAssertEqual(controller.pomodoroConfiguration, configuration)
        XCTAssertEqual(controller.historyCount, 1)
    }

    func testTimerActionsDispatchCallbacks() throws {
        let controller = ProductivityManagementWindowController()
        let timer = try makeTimer()
        var paused: UUID?
        var resumed: UUID?
        var cancelled: UUID?
        controller.onPauseTimer = { paused = $0 }
        controller.onResumeTimer = { resumed = $0 }
        controller.onCancelTimer = { cancelled = $0 }

        controller.requestPauseTimer(id: timer.id)
        controller.requestResumeTimer(id: timer.id)
        controller.requestCancelTimer(id: timer.id)

        XCTAssertEqual(paused, timer.id)
        XCTAssertEqual(resumed, timer.id)
        XCTAssertEqual(cancelled, timer.id)
    }

    func testPomodoroSettingsDispatchCallback() throws {
        let controller = ProductivityManagementWindowController()
        let configuration = try PomodoroConfiguration()
        var settings: PomodoroConfiguration?
        controller.onEditPomodoroSettings = { settings = $0 }

        controller.requestEditPomodoroSettings(configuration)

        XCTAssertEqual(settings, configuration)
    }

    func testReminderActionsDispatchCallbacks() throws {
        let controller = ProductivityManagementWindowController()
        let reminder = try makeReminder()
        var edited: UUID?
        var deleted: UUID?
        var toggled: (UUID, Bool)?
        var snoozed: (UUID, ReminderSnoozeDuration)?
        controller.onEditReminder = { edited = $0 }
        controller.onDeleteReminder = { deleted = $0 }
        controller.onSetReminderEnabled = { toggled = ($0, $1) }
        controller.onSnoozeReminder = { snoozed = ($0, $1) }

        controller.requestEditReminder(id: reminder.id)
        controller.requestDeleteReminder(id: reminder.id)
        controller.requestSetReminderEnabled(id: reminder.id, enabled: false)
        controller.requestSnoozeReminder(
            id: reminder.id,
            duration: .thirtyMinutes
        )

        XCTAssertEqual(edited, reminder.id)
        XCTAssertEqual(deleted, reminder.id)
        XCTAssertEqual(toggled?.0, reminder.id)
        XCTAssertEqual(toggled?.1, false)
        XCTAssertEqual(snoozed?.0, reminder.id)
        XCTAssertEqual(snoozed?.1, .thirtyMinutes)
    }

    private func makeTimer() throws -> ProductivityCountdownTimer {
        try ProductivityCountdownTimer(
            id: UUID(),
            title: "Focus",
            duration: 25 * 60,
            startedAt: now
        )
    }

    private func makeReminder() throws -> ProductivityReminder {
        try ProductivityReminder(
            id: UUID(),
            title: "Standup",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: now,
            updatedAt: now
        )
    }
}
