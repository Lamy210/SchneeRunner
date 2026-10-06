import Foundation
import SchneeRunnerCore
import UserNotifications

enum ProductivityNotificationAuthorizationState: Equatable, Sendable {
    case authorized
    case denied
    case notDetermined
}

enum ProductivityNotificationDeliveryStatus: Equatable, Sendable {
    case scheduled
    case disabled
}

struct ProductivityNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let timeInterval: TimeInterval
}

@MainActor
protocol ProductivityNotificationCenterClient: AnyObject {
    func currentAuthorizationState() async -> ProductivityNotificationAuthorizationState
    func requestAuthorization() async throws -> Bool
    func pendingIdentifiers() async -> Set<String>
    func add(_ request: ProductivityNotificationRequest) async throws
    func removePending(identifiers: Set<String>)
}

@MainActor
protocol ProductivityNotificationScheduling: AnyObject {
    func scheduleTimer(
        _ timer: ProductivityCountdownTimer,
        now: Date
    ) async throws -> ProductivityNotificationDeliveryStatus

    func cancelTimer(id: UUID) async

    func reconcileTimers(
        _ timers: [ProductivityCountdownTimer],
        now: Date
    ) async throws -> ProductivityNotificationDeliveryStatus
}

@MainActor
final class ProductivityNotificationScheduler: ProductivityNotificationScheduling {
    private static let timerPrefix = "schneerunner.timer."

    private let center: any ProductivityNotificationCenterClient

    convenience init() {
        self.init(center: SystemProductivityNotificationCenterClient())
    }

    init(center: any ProductivityNotificationCenterClient) {
        self.center = center
    }

    static func timerIdentifier(for id: UUID) -> String {
        timerPrefix + id.uuidString.lowercased()
    }

    func scheduleTimer(
        _ timer: ProductivityCountdownTimer,
        now: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        guard try await notificationsAreEnabled() else {
            return .disabled
        }

        guard
            timer.state == .running,
            let deadline = timer.deadline,
            deadline > now
        else {
            await cancelTimer(id: timer.id)
            return .scheduled
        }

        try await center.add(
            Self.request(for: timer, now: now, deadline: deadline)
        )
        return .scheduled
    }

    func cancelTimer(id: UUID) async {
        center.removePending(
            identifiers: [Self.timerIdentifier(for: id)]
        )
    }

    func reconcileTimers(
        _ timers: [ProductivityCountdownTimer],
        now: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        guard try await notificationsAreEnabled() else {
            return .disabled
        }

        let desiredTimers = timers.filter { timer in
            guard
                timer.state == .running,
                let deadline = timer.deadline
            else {
                return false
            }
            return deadline > now
        }
        let desiredIdentifiers = Set(
            desiredTimers.map { Self.timerIdentifier(for: $0.id) }
        )
        let pendingIdentifiers = await center.pendingIdentifiers()
        let obsoleteOwnedIdentifiers = Set(
            pendingIdentifiers.filter {
                $0.hasPrefix(Self.timerPrefix) && !desiredIdentifiers.contains($0)
            }
        )

        if !obsoleteOwnedIdentifiers.isEmpty {
            center.removePending(identifiers: obsoleteOwnedIdentifiers)
        }

        for timer in desiredTimers {
            guard let deadline = timer.deadline else {
                continue
            }
            try await center.add(
                Self.request(for: timer, now: now, deadline: deadline)
            )
        }

        return .scheduled
    }

    private func notificationsAreEnabled() async throws -> Bool {
        switch await center.currentAuthorizationState() {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization()
        }
    }

    private static func request(
        for timer: ProductivityCountdownTimer,
        now: Date,
        deadline: Date
    ) -> ProductivityNotificationRequest {
        ProductivityNotificationRequest(
            identifier: timerIdentifier(for: timer.id),
            title: timer.title,
            body: "Timer finished",
            timeInterval: deadline.timeIntervalSince(now)
        )
    }
}

@MainActor
private final class SystemProductivityNotificationCenterClient: ProductivityNotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func currentAuthorizationState() async -> ProductivityNotificationAuthorizationState {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                let state: ProductivityNotificationAuthorizationState = switch settings.authorizationStatus {
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
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: request.timeInterval,
                repeats: false
            )
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
}
