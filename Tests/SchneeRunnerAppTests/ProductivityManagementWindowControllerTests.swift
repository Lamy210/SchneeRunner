import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityManagementWindowControllerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testContentTracksReminderAndHistoryCounts() throws {
        let controller = ProductivityManagementWindowController()
        let reminder = try makeReminder()
        let history = ProductivityHistory().appending(
            ProductivityHistoryEntry(
                id: UUID(),
                kind: .reminderAcknowledged,
                sourceID: reminder.id,
                title: reminder.title,
                occurredAt: now
            )
        )

        controller.setContent(
            reminders: [reminder],
            history: history
        )

        XCTAssertEqual(controller.reminderIDs, [reminder.id])
        XCTAssertEqual(controller.historyCount, 1)
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
