import Foundation

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
}
