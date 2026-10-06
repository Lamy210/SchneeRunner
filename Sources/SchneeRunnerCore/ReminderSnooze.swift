import Foundation

public enum ReminderSnoozeDuration: Int, Codable, CaseIterable, Sendable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case sixtyMinutes = 60

    public var timeInterval: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}

public struct ReminderSnooze: Codable, Equatable, Sendable {
    public let id: UUID
    public let reminderID: UUID
    public let title: String
    public let body: String?
    public let fireDate: Date

    public init(
        id: UUID,
        reminderID: UUID,
        title: String,
        body: String?,
        fireDate: Date
    ) {
        self.id = id
        self.reminderID = reminderID
        self.title = title
        self.body = body
        self.fireDate = fireDate
    }

    public init(
        id: UUID,
        reminder: ProductivityReminder,
        duration: ReminderSnoozeDuration,
        now: Date
    ) {
        self.init(
            id: id,
            reminderID: reminder.id,
            title: reminder.title,
            body: reminder.body,
            fireDate: now.addingTimeInterval(duration.timeInterval)
        )
    }
}
