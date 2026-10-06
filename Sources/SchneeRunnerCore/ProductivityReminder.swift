import Foundation

public struct ProductivityReminder: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let body: String?
    public let enabled: Bool
    public let schedule: ReminderSchedule
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        title: String,
        body: String?,
        enabled: Bool,
        schedule: ReminderSchedule,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        try schedule.validate()
        self.id = id
        self.title = title
        self.body = body
        self.enabled = enabled
        self.schedule = schedule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func nextOccurrence(
        after now: Date,
        calendar: Calendar
    ) -> Date? {
        guard enabled else {
            return nil
        }
        return schedule.nextOccurrence(after: now, calendar: calendar)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            body: container.decodeIfPresent(String.self, forKey: .body),
            enabled: container.decode(Bool.self, forKey: .enabled),
            schedule: container.decode(ReminderSchedule.self, forKey: .schedule),
            createdAt: container.decode(Date.self, forKey: .createdAt),
            updatedAt: container.decode(Date.self, forKey: .updatedAt)
        )
    }
}
