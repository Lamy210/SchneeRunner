import Foundation
import UserNotifications

@MainActor
final class ProductivityNotificationDeliveryMonitor: NSObject, UNUserNotificationCenterDelegate {
    var onReminderFired: (() -> Void)?

    private weak var center: UNUserNotificationCenter?

    @discardableResult
    func start(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        bundleURL: URL = Bundle.main.bundleURL,
        center: UNUserNotificationCenter? = nil
    ) -> Bool {
        LaunchTrace.emit("ProductivityNotificationDeliveryMonitor.start begin")
        guard SystemNotificationRuntime.isAvailable(
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundleURL
        ) else {
            LaunchTrace.emit("ProductivityNotificationDeliveryMonitor disabled by runtime policy")
            stop()
            return false
        }

        let resolvedCenter: UNUserNotificationCenter
        if let center {
            LaunchTrace.emit("ProductivityNotificationDeliveryMonitor using injected center")
            resolvedCenter = center
        } else {
            LaunchTrace.emit("ProductivityNotificationDeliveryMonitor before UNUserNotificationCenter.current")
            resolvedCenter = .current()
            LaunchTrace.emit("ProductivityNotificationDeliveryMonitor after UNUserNotificationCenter.current")
        }
        self.center = resolvedCenter
        LaunchTrace.emit("ProductivityNotificationDeliveryMonitor before delegate assignment")
        resolvedCenter.delegate = self
        LaunchTrace.emit("ProductivityNotificationDeliveryMonitor after delegate assignment")
        return true
    }

    func stop() {
        if center?.delegate === self {
            center?.delegate = nil
        }
        center = nil
    }

    static func isReminderNotification(identifier: String) -> Bool {
        identifier.hasPrefix("schneerunner.reminder.") ||
            identifier.hasPrefix("schneerunner.snooze.")
    }

    func handleDeliveredNotification(identifier: String) {
        guard Self.isReminderNotification(identifier: identifier) else {
            return
        }
        onReminderFired?()
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let identifier = notification.request.identifier
        completionHandler([.banner, .sound])
        Task { @MainActor [weak self] in
            self?.handleDeliveredNotification(identifier: identifier)
        }
    }
}
