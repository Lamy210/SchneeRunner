import UserNotifications

@MainActor
final class ProductivityNotificationDeliveryMonitor: NSObject, UNUserNotificationCenterDelegate {
    var onReminderFired: (() -> Void)?

    private weak var center: UNUserNotificationCenter?

    func start(center: UNUserNotificationCenter = .current()) {
        self.center = center
        center.delegate = self
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
        Task { @MainActor [weak self] in
            self?.handleDeliveredNotification(identifier: identifier)
            completionHandler([.banner, .sound])
        }
    }
}
