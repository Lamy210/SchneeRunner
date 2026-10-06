import Foundation
import SchneeRunnerCore
import UserNotifications

enum NotificationAuthorizationState: Equatable, Sendable {
    case authorized
    case denied
    case notDetermined
}

enum ProductivityNotificationDeliveryStatus: Equatable, Sendable {
    case scheduled
    case disabled
}

enum ProductivityNotificationTrigger: Equatable, Sendable {
    case timeInterval(TimeInterval)
    case calendar(hour: Int, minute: Int, weekday: Int?)
}

struct ProductivityNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let trigger: ProductivityNotificationTrigger

    init(
        identifier: String,
        title: String,
        body: String,
        timeInterval: TimeInterval
    ) {
        self.init(
            identifier: identifier,
            title: title,
            body: body,
            trigger: .timeInterval(timeInterval)
        )
    }

    init(
        identifier: String,
        title: String,
        body: String,
        trigger: ProductivityNotificationTrigger
    ) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.trigger = trigger
    }

    var timeInterval: TimeInterval? {
        guard case let .timeInterval(timeInterval) = trigger else {
            return nil
        }
        return timeInterval
    }
}

@MainActor
protocol ProductivityNotificationCenterClient: AnyObject {
    func currentAuthorizationState() async -> NotificationAuthorizationState
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
protocol ReminderNotificationScheduling: AnyObject {
    func reconcileReminders(
        _ reminders: [ProductivityReminder],
        snoozes: [ReminderSnooze],
        now: Date,
        calendar: Calendar
    ) async throws -> ProductivityNotificationDeliveryStatus
}

@MainActor
final class ProductivityNotificationScheduler: ProductivityNotificationScheduling, ReminderNotificationScheduling {
    private static let timerPrefix = "schneerunner.timer."
    private static let reminderPrefix = "schneerunner.reminder."
    private static let snoozePrefix = "schneerunner.snooze."

    private let center: any ProductivityNotificationCenterClient

    convenience init() {
        self.init(center: SystemProductivityNotificationClient())
    }

    init(center: any ProductivityNotificationCenterClient) {
        self.center = center
    }

    static func timerIdentifier(for id: UUID) -> String {
        timerPrefix + id.uuidString.lowercased()
    }

    static func reminderIdentifier(
        for id: UUID,
        occurrenceKey: String
    ) -> String {
        reminderPrefix + id.uuidString.lowercased() + "." + occurrenceKey
    }

    static func snoozeIdentifier(for id: UUID) -> String {
        snoozePrefix + id.uuidString.lowercased()
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

    func reconcileReminders(
        _ reminders: [ProductivityReminder],
        snoozes: [ReminderSnooze],
        now: Date,
        calendar: Calendar
    ) async throws -> ProductivityNotificationDeliveryStatus {
        guard try await notificationsAreEnabled() else {
            return .disabled
        }

        let requests = reminders.flatMap {
            Self.requests(for: $0, now: now, calendar: calendar)
        } + snoozes.compactMap {
            Self.request(for: $0, now: now)
        }
        let desiredIdentifiers = Set(requests.map(\.identifier))
        let pendingIdentifiers = await center.pendingIdentifiers()
        let obsoleteIdentifiers = Set(
            pendingIdentifiers.filter { identifier in
                Self.isReminderOwned(identifier)
                    && !desiredIdentifiers.contains(identifier)
            }
        )

        if !obsoleteIdentifiers.isEmpty {
            center.removePending(identifiers: obsoleteIdentifiers)
        }

        for request in requests {
            try await center.add(request)
        }

        return .scheduled
    }

    private func notificationsAreEnabled() async throws -> Bool {
        switch await center.currentAuthorizationState() {
        case .authorized:
            true
        case .denied:
            false
        case .notDetermined:
            try await center.requestAuthorization()
        }
    }
}

private extension ProductivityNotificationScheduler {
    static func isReminderOwned(_ identifier: String) -> Bool {
        identifier.hasPrefix(reminderPrefix)
            || identifier.hasPrefix(snoozePrefix)
    }

    static func request(
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

    static func requests(
        for reminder: ProductivityReminder,
        now: Date,
        calendar: Calendar
    ) -> [ProductivityNotificationRequest] {
        guard reminder.nextOccurrence(after: now, calendar: calendar) != nil else {
            return []
        }

        let body = reminder.body ?? "Reminder"
        switch reminder.schedule {
        case let .once(date):
            return [
                ProductivityNotificationRequest(
                    identifier: reminderIdentifier(
                        for: reminder.id,
                        occurrenceKey: "once"
                    ),
                    title: reminder.title,
                    body: body,
                    trigger: .timeInterval(date.timeIntervalSince(now))
                )
            ]
        case let .daily(hour, minute):
            return [
                ProductivityNotificationRequest(
                    identifier: reminderIdentifier(
                        for: reminder.id,
                        occurrenceKey: "daily"
                    ),
                    title: reminder.title,
                    body: body,
                    trigger: .calendar(
                        hour: hour,
                        minute: minute,
                        weekday: nil
                    )
                )
            ]
        case let .weekdays(weekdays, hour, minute):
            return weekdays
                .sorted { $0.rawValue < $1.rawValue }
                .map { weekday in
                    ProductivityNotificationRequest(
                        identifier: reminderIdentifier(
                            for: reminder.id,
                            occurrenceKey: "weekday.\(weekday.rawValue)"
                        ),
                        title: reminder.title,
                        body: body,
                        trigger: .calendar(
                            hour: hour,
                            minute: minute,
                            weekday: weekday.rawValue
                        )
                    )
                }
        }
    }

    static func request(
        for snooze: ReminderSnooze,
        now: Date
    ) -> ProductivityNotificationRequest? {
        guard snooze.fireDate > now else {
            return nil
        }

        return ProductivityNotificationRequest(
            identifier: snoozeIdentifier(for: snooze.id),
            title: snooze.title,
            body: snooze.body ?? "Reminder",
            trigger: .timeInterval(snooze.fireDate.timeIntervalSince(now))
        )
    }
}

@MainActor
private final class SystemProductivityNotificationClient: ProductivityNotificationCenterClient {
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
