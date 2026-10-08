import Foundation
import UserNotifications

@MainActor
final class SystemProductivityNotificationClient: ProductivityNotificationCenterClient {
    private let center: UNUserNotificationCenter?

    init(
        center: UNUserNotificationCenter? = nil,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        bundleURL: URL = Bundle.main.bundleURL
    ) {
        LaunchTrace.emit(
            "SystemProductivityNotificationClient init bundleURL=\(bundleURL.path) bundleIdentifier=\(bundleIdentifier ?? "nil")"
        )
        guard SystemNotificationRuntime.isAvailable(
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundleURL
        ) else {
            LaunchTrace.emit("SystemProductivityNotificationClient disabled by runtime policy")
            self.center = nil
            return
        }

        if let center {
            LaunchTrace.emit("SystemProductivityNotificationClient using injected center")
            self.center = center
        } else {
            LaunchTrace.emit("before UNUserNotificationCenter.current")
            self.center = .current()
            LaunchTrace.emit("after UNUserNotificationCenter.current")
        }
    }

    func currentAuthorizationState() async -> NotificationAuthorizationState {
        guard let center else {
            LaunchTrace.emit("currentAuthorizationState disabled: no notification center")
            return .denied
        }

        LaunchTrace.emit("currentAuthorizationState before getNotificationSettings")
        return await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                LaunchTrace.emit("currentAuthorizationState getNotificationSettings callback")
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
        guard let center else {
            return false
        }

        return try await withCheckedThrowingContinuation { continuation in
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
        guard let center else {
            return []
        }

        return await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: Set(requests.map(\.identifier))
                )
            }
        }
    }

    func add(_ request: ProductivityNotificationRequest) async throws {
        guard let center else {
            return
        }

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
        center?.removePendingNotificationRequests(
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
