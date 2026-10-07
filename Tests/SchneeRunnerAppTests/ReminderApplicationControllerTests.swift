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
        let operationNow = Date()
        fixture.controller.start(now: operationNow)
        let request = ReminderEditRequest(
            title: "Deploy",
            body: "Check production",
            enabled: true,
            schedule: .once(operationNow.addingTimeInterval(3600))
        )

        _ = try await fixture.controller.createReminder(
            request,
            now: operationNow
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

    func testStopCancelsInFlightLaunchReconciliation() async throws {
        let scheduler = ReminderApplicationScheduler(
            reconcileDelayNanoseconds: 100_000_000
        )
        let fixture = try makeFixture(notificationScheduler: scheduler)
        defer { fixture.cleanup() }

        fixture.controller.start(now: now)
        for _ in 0 ..< 100 where !scheduler.reconcileStarted {
            await Task.yield()
        }
        XCTAssertTrue(scheduler.reconcileStarted)

        fixture.controller.stop()
        try await Task<Never, Never>.sleep(nanoseconds: 150_000_000)

        XCTAssertTrue(scheduler.reconcileWasCancelled)
        XCTAssertFalse(scheduler.reconcileCompleted)
    }

    private func makeFixture(
        reminders: [ProductivityReminder] = [],
        notificationScheduler: ReminderApplicationScheduler = .init()
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
        let controller = try ReminderApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            fileManager: .default,
            notificationScheduler: notificationScheduler,
            calendar: utcCalendar()
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
    private let reconcileDelayNanoseconds: UInt64

    private(set) var reconcileStarted = false
    private(set) var reconcileCompleted = false
    private(set) var reconcileWasCancelled = false

    init(reconcileDelayNanoseconds: UInt64 = 0) {
        self.reconcileDelayNanoseconds = reconcileDelayNanoseconds
    }

    func reconcileReminders(
        _: [ProductivityReminder],
        snoozes _: [ReminderSnooze],
        now _: Date,
        calendar _: Calendar
    ) async throws -> ProductivityNotificationDeliveryStatus {
        reconcileStarted = true
        do {
            if reconcileDelayNanoseconds > 0 {
                try await Task<Never, Never>.sleep(
                    nanoseconds: reconcileDelayNanoseconds
                )
            }
        } catch {
            if error is CancellationError {
                reconcileWasCancelled = true
            }
            throw error
        }
        reconcileCompleted = true
        return .scheduled
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
