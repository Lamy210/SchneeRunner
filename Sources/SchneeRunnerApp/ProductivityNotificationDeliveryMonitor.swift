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
        guard SystemNotificationRuntime.isAvailable(
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundleURL
        ) else {
            stop()
            return false
        }

        let resolvedCenter = center ?? .current()
        self.center = resolvedCenter
        resolvedCenter.delegate = self
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
