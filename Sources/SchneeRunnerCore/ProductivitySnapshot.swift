import Foundation

public enum ProductivitySnapshotError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
}

public struct ProductivitySnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let timers: [ProductivityCountdownTimer]
    public let reminders: [ProductivityReminder]

    public init(
        timers: [ProductivityCountdownTimer] = [],
        reminders: [ProductivityReminder] = []
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.timers = timers
        self.reminders = reminders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ProductivitySnapshotError.unsupportedSchemaVersion(schemaVersion)
        }

        self.schemaVersion = schemaVersion
        timers = try container.decode([ProductivityCountdownTimer].self, forKey: .timers)
        reminders = try container.decodeIfPresent(
            [ProductivityReminder].self,
            forKey: .reminders
        ) ?? []
    }

    public func reconciling(at now: Date) -> ProductivitySnapshot {
        ProductivitySnapshot(
            timers: timers.map { $0.reconciling(at: now) },
            reminders: reminders
        )
    }
}
