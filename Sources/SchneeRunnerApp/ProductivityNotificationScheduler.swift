import Foundation
import SchneeRunnerCore

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
final class ProductivityNotificationScheduler:
    ProductivityNotificationScheduling,
    ReminderNotificationScheduling,
    PomodoroNotificationScheduling
{
    private static let timerPrefix = "schneerunner.timer."
    private static let reminderPrefix = "schneerunner.reminder."
    private static let snoozePrefix = "schneerunner.snooze."
    private static let pomodoroPrefix = "schneerunner.pomodoro."

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

    static func pomodoroIdentifier(
        for id: UUID,
        phase: PomodoroPhase
    ) -> String {
        "\(pomodoroPrefix)\(id.uuidString.lowercased()).\(phase.rawValue)"
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

    func schedulePomodoro(
        _ session: PomodoroSession,
        now: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        guard try await notificationsAreEnabled() else {
            return .disabled
        }

        guard
            session.state == .running,
            let deadline = session.phaseDeadline,
            deadline > now
        else {
            await cancelPomodoro(id: session.id)
            return .scheduled
        }

        try await center.add(
            Self.request(for: session, now: now, deadline: deadline)
        )
        return .scheduled
    }

    func cancelPomodoro(id: UUID) async {
        let prefix = Self.pomodoroSessionPrefix(for: id)
        let pendingIdentifiers = await center.pendingIdentifiers()
        let ownedIdentifiers = Set(
            pendingIdentifiers.filter { $0.hasPrefix(prefix) }
        )
        if !ownedIdentifiers.isEmpty {
            center.removePending(identifiers: ownedIdentifiers)
        }
    }

    func reconcilePomodoro(
        _ session: PomodoroSession?,
        now: Date
    ) async throws -> ProductivityNotificationDeliveryStatus {
        guard try await notificationsAreEnabled() else {
            return .disabled
        }

        let desired = session.flatMap { session -> (PomodoroSession, Date)? in
            guard
                session.state == .running,
                let deadline = session.phaseDeadline,
                deadline > now
            else {
                return nil
            }
            return (session, deadline)
        }
        let desiredIdentifier = desired.map {
            Self.pomodoroIdentifier(
                for: $0.0.id,
                phase: $0.0.currentPhase
            )
        }
        let pendingIdentifiers = await center.pendingIdentifiers()
        let obsoleteOwnedIdentifiers = Set(
            pendingIdentifiers.filter { identifier in
                identifier.hasPrefix(Self.pomodoroPrefix)
                    && identifier != desiredIdentifier
            }
        )

        if !obsoleteOwnedIdentifiers.isEmpty {
            center.removePending(identifiers: obsoleteOwnedIdentifiers)
        }

        if let desired {
            try await center.add(
                Self.request(
                    for: desired.0,
                    now: now,
                    deadline: desired.1
                )
            )
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

    static func request(
        for session: PomodoroSession,
        now: Date,
        deadline: Date
    ) -> ProductivityNotificationRequest {
        ProductivityNotificationRequest(
            identifier: pomodoroIdentifier(
                for: session.id,
                phase: session.currentPhase
            ),
            title: "Pomodoro",
            body: "\(phaseTitle(session.currentPhase)) finished",
            trigger: .timeInterval(deadline.timeIntervalSince(now))
        )
    }

    static func pomodoroSessionPrefix(for id: UUID) -> String {
        "\(pomodoroPrefix)\(id.uuidString.lowercased())."
    }

    static func phaseTitle(_ phase: PomodoroPhase) -> String {
        switch phase {
        case .focus:
            "Focus"
        case .shortBreak:
            "Short break"
        case .longBreak:
            "Long break"
        }
    }
}
