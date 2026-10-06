import Foundation
import UserNotifications

@MainActor
final class SystemProductivityNotificationClient: ProductivityNotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func currentAuthorizationState() async -> NotificationAuthorizationState {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                let state: NotificationAuthorizationState = switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    .authorized
                case .denied:
                    .denied
                case .notDetermined:
                    .notDetermined
                @unknown default:
                    .denied
                }
                continuation.resume(returning: state)
            }
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(
                options: [.alert, .sound]
            ) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func pendingIdentifiers() async -> Set<String> {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: Set(requests.map(\.identifier))
                )
            }
        }
    }

    func add(_ request: ProductivityNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: Self.systemTrigger(for: request.trigger)
        )
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            center.add(notificationRequest) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func removePending(identifiers: Set<String>) {
        center.removePendingNotificationRequests(
            withIdentifiers: Array(identifiers)
        )
    }

    private static func systemTrigger(
        for trigger: ProductivityNotificationTrigger
    ) -> UNNotificationTrigger {
        switch trigger {
        case let .timeInterval(timeInterval):
            UNTimeIntervalNotificationTrigger(
                timeInterval: timeInterval,
                repeats: false
            )
        case let .calendar(hour, minute, weekday):
            UNCalendarNotificationTrigger(
                dateMatching: DateComponents(
                    hour: hour,
                    minute: minute,
                    weekday: weekday
                ),
                repeats: true
            )
        }
    }
}
