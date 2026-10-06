import AppKit
import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ReminderMenuControllerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testEmptyMenuShowsCreationAndManagementActions() throws {
        let controller = ReminderMenuController()
        let menu = try XCTUnwrap(controller.rootItem.submenu)

        XCTAssertNotNil(menu.item(withTitle: "No upcoming reminders"))
        XCTAssertNotNil(menu.item(withTitle: "New Reminder…"))
        XCTAssertNotNil(menu.item(withTitle: "Manage Reminders…"))
    }

    func testActionsDispatchCallbacks() throws {
        let controller = ReminderMenuController()
        var newCount = 0
        var manageCount = 0
        controller.onNewReminder = { newCount += 1 }
        controller.onManageReminders = { manageCount += 1 }
        let menu = try XCTUnwrap(controller.rootItem.submenu)

        try perform(XCTUnwrap(menu.item(withTitle: "New Reminder…")))
        try perform(XCTUnwrap(menu.item(withTitle: "Manage Reminders…")))

        XCTAssertEqual(newCount, 1)
        XCTAssertEqual(manageCount, 1)
    }

    func testShowsEarliestEnabledReminder() throws {
        let controller = ReminderMenuController()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let later = try reminder(
            title: "Later",
            schedule: .once(now.addingTimeInterval(7200))
        )
        let sooner = try reminder(
            title: "Sooner",
            schedule: .once(now.addingTimeInterval(3600))
        )
        let disabled = try ProductivityReminder(
            id: UUID(),
            title: "Disabled",
            body: nil,
            enabled: false,
            schedule: .once(now.addingTimeInterval(60)),
            createdAt: now,
            updatedAt: now
        )

        controller.setReminders(
            [later, disabled, sooner],
            now: now,
            calendar: calendar
        )

        let menu = try XCTUnwrap(controller.rootItem.submenu)
        XCTAssertTrue(
            menu.items.contains { $0.title.hasPrefix("Next: Sooner · ") }
        )
        XCTAssertFalse(
            menu.items.contains { $0.title.contains("Disabled") }
        )
    }

    private func reminder(
        title: String,
        schedule: ReminderSchedule
    ) throws -> ProductivityReminder {
        try ProductivityReminder(
            id: UUID(),
            title: title,
            body: nil,
            enabled: true,
            schedule: schedule,
            createdAt: now,
            updatedAt: now
        )
    }

    private func perform(_ item: NSMenuItem) {
        guard
            let action = item.action,
            let target = item.target as? NSObject
        else {
            XCTFail("Menu item has no target/action")
            return
        }
        _ = target.perform(action, with: item)
    }
}
