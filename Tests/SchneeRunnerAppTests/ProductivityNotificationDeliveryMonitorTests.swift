import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
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

    func testProductivityApplicationBridgesDeliveredReminderIntoCharacterReaction() throws {
        let suiteName = "SchneeRunnerAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let reactionStore = ProductivityCharacterReactionStore(
            defaults: defaults,
            key: "productivity-reactions"
        )
        let playbackController = CharacterPlaybackController(
            animationController: AnimationController()
        )
        let characterStateCoordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )
        let monitor = ProductivityNotificationDeliveryMonitor()
        let controller = ProductivityApplicationController(
            menuController: StatusMenuController(),
            characterStateCoordinator: characterStateCoordinator,
            reactionStore: reactionStore,
            notificationDeliveryMonitor: monitor
        )

        monitor.handleDeliveredNotification(
            identifier: "schneerunner.reminder.abc.daily"
        )

        XCTAssertEqual(playbackController.requestedState, .idle)
        _ = controller
    }
}
