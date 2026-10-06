import Foundation
@testable import SchneeRunnerApp
import XCTest

@MainActor
final class ProductivityDeliveryMonitorTests: XCTestCase {
    func testOwnedReminderIdentifiersAreRecognized() {
        XCTAssertTrue(
            ProductivityNotificationDeliveryMonitor.isReminderNotification(
                identifier: "schneerunner.reminder.abc.daily"
            )
        )
        XCTAssertTrue(
            ProductivityNotificationDeliveryMonitor.isReminderNotification(
                identifier: "schneerunner.snooze.abc"
            )
        )
        XCTAssertFalse(
            ProductivityNotificationDeliveryMonitor.isReminderNotification(
                identifier: "schneerunner.timer.abc"
            )
        )
        XCTAssertFalse(
            ProductivityNotificationDeliveryMonitor.isReminderNotification(
                identifier: "com.example.foreign"
            )
        )
    }

    func testDeliveredReminderInvokesCallbackOnlyForOwnedReminder() {
        let monitor = ProductivityNotificationDeliveryMonitor()
        var firedCount = 0
        monitor.onReminderFired = {
            firedCount += 1
        }

        monitor.handleDeliveredNotification(
            identifier: "schneerunner.timer.abc"
        )
        XCTAssertEqual(firedCount, 0)

        monitor.handleDeliveredNotification(
            identifier: "schneerunner.reminder.abc.daily"
        )
        XCTAssertEqual(firedCount, 1)
    }
}
