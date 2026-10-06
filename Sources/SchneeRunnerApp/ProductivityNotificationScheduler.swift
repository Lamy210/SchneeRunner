import Foundation
import UserNotifications

public enum ProductivityNotificationSchedulingResult: Equatable, Sendable {
    case scheduled
    case authorizationDenied
    case schedulingFailed
}

@MainActor
protocol ProductivityNotificationScheduling: AnyObject {
    func scheduleTimer(
        id: UUID,
        title: String,
        deadline: Date,
        now: Date
    ) async -> ProductivityNotificationSchedulingResult

    func cancelTimer(id: UUID)
}

@MainActor
protocol ProductivityUserNotificationCenter: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

@MainActor
final class ProductivityNotificationScheduler: ProductivityNotificationScheduling {
    private let center: any ProductivityUserNotificationCenter

    init(center: any ProductivityUserNotificationCenter = SystemProductivityUserNotificationCenter()) {
        self.center = center
    }

    static func timerIdentifier(for id: UUID) -> String {
        "schneerunner.timer.\(id.uuidString.lowercased())"
    }

    func scheduleTimer(
        id: UUID,
        title: String,
        deadline: Date,
        now: Date
    ) async -> ProductivityNotificationSchedulingResult {
        let remaining = deadline.timeIntervalSince(now)
        guard remaining > 0 else {
            return .schedulingFailed
        }

        switch await authorizationResult() {
        case .authorized:
            break
        case .denied:
            return .authorizationDenied
        case .failed:
            return .schedulingFailed
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Timer complete"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(remaining, 1),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.timerIdentifier(for: id),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return .scheduled
        } catch {
            return .schedulingFailed
        }
    }

    func cancelTimer(id: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.timerIdentifier(for: id)]
        )
    }

    private func authorizationResult() async -> AuthorizationResult {
        let status = await center.authorizationStatus()
        switch status {
        case .denied:
            return .denied
        case .notDetermined:
            do {
                return try await center.requestAuthorization() ? .authorized : .denied
            } catch {
                return .failed
            }
        default:
            return .authorized
        }
    }
}

private enum AuthorizationResult {
    case authorized
    case denied
    case failed
}

@MainActor
private final class SystemProductivityUserNotificationCenter: ProductivityUserNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }
}
