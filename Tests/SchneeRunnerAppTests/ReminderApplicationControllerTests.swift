import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ReminderApplicationControllerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testStartRestoresSavedRemindersIntoStatusMenu() throws {
        let fixture = try makeFixture(
            reminders: [makeReminder(title: "Standup")]
        )
        defer { fixture.cleanup() }

        fixture.controller.start(now: now)

        let menu = try XCTUnwrap(
            fixture.menuController.menu.item(withTitle: "Reminders")?.submenu
        )
        XCTAssertTrue(
            menu.items.contains { $0.title.hasPrefix("Next: Standup · ") }
        )
    }

    func testCreateReminderPersistsAndRefreshesMenu() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.controller.start(now: now)
        let request = ReminderEditRequest(
            title: "Deploy",
            body: "Check production",
            enabled: true,
            schedule: .once(now.addingTimeInterval(3600))
        )

        _ = try await fixture.controller.createReminder(
            request,
            now: now
        )

        let persisted = try fixture.stateStore.load().reminders
        XCTAssertEqual(persisted.map(\.title), ["Deploy"])
        let menu = try XCTUnwrap(
            fixture.menuController.menu.item(withTitle: "Reminders")?.submenu
        )
        XCTAssertTrue(
            menu.items.contains { $0.title.hasPrefix("Next: Deploy · ") }
        )
    }

    private func makeFixture(
        reminders: [ProductivityReminder] = []
    ) throws -> ReminderApplicationFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let stateStore = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )
        try stateStore.save(ProductivitySnapshot(reminders: reminders))
        let menuController = StatusMenuController()
        let scheduler = ReminderApplicationScheduler()
        let controller = ReminderApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            fileManager: .default,
            notificationScheduler: scheduler,
            calendar: try utcCalendar()
        )
        return ReminderApplicationFixture(
            baseDirectory: baseDirectory,
            stateStore: stateStore,
            menuController: menuController,
            controller: controller
        )
    }

    private func makeReminder(
        title: String
    ) throws -> ProductivityReminder {
        try ProductivityReminder(
            id: UUID(),
            title: title,
            body: nil,
            enabled: true,
            schedule: .once(now.addingTimeInterval(3600)),
            createdAt: now,
            updatedAt: now
        )
    }

    private func utcCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        return calendar
    }
}

@MainActor
private final class ReminderApplicationScheduler: ReminderNotificationScheduling {
    func reconcileReminders(
        _: [ProductivityReminder],
        snoozes _: [ReminderSnooze],
        now _: Date,
        calendar _: Calendar
    ) async throws -> ProductivityNotificationDeliveryStatus {
        .scheduled
    }
}

private struct ReminderApplicationFixture {
    let baseDirectory: URL
    let stateStore: ProductivityStateStore
    let menuController: StatusMenuController
    let controller: ReminderApplicationController

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
