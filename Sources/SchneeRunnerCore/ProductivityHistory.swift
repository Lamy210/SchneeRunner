import Foundation

public enum ProductivityHistoryKind: String, Codable, Equatable, Sendable {
    case countdownCompleted
    case pomodoroFocusCompleted
    case pomodoroBreakCompleted
    case reminderDelivered
}

public struct ProductivityHistoryEntry: Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: ProductivityHistoryKind
    public let sourceID: UUID
    public let title: String
    public let occurredAt: Date

    public init(
        id: UUID,
        kind: ProductivityHistoryKind,
        sourceID: UUID,
        title: String,
        occurredAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.sourceID = sourceID
        self.title = title
        self.occurredAt = occurredAt
    }
}

public enum ProductivityHistoryError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
}

public struct ProductivityHistory: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let maximumEntryCount = 500

    public let schemaVersion: Int
    public let entries: [ProductivityHistoryEntry]

    public init(entries: [ProductivityHistoryEntry] = []) {
        schemaVersion = Self.currentSchemaVersion
        self.entries = Array(entries.suffix(Self.maximumEntryCount))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ProductivityHistoryError.unsupportedSchemaVersion(schemaVersion)
        }

        let entries = try container.decode(
            [ProductivityHistoryEntry].self,
            forKey: .entries
        )
        self.schemaVersion = schemaVersion
        self.entries = Array(entries.suffix(Self.maximumEntryCount))
    }

    public func appending(
        _ entry: ProductivityHistoryEntry
    ) -> ProductivityHistory {
        ProductivityHistory(entries: entries + [entry])
    }
}
