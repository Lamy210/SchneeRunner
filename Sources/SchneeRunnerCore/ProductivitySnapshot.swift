import Foundation

public enum ProductivitySnapshotError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
}

public struct ProductivitySnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let timers: [ProductivityCountdownTimer]
    public let reminders: [ProductivityReminder]
    public let pomodoro: PomodoroSession?
    public let snoozes: [ReminderSnooze]

    public init(
        timers: [ProductivityCountdownTimer] = [],
        reminders: [ProductivityReminder] = [],
        pomodoro: PomodoroSession? = nil,
        snoozes: [ReminderSnooze] = []
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.timers = timers
        self.reminders = reminders
        self.pomodoro = pomodoro
        self.snoozes = snoozes
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
        pomodoro = try container.decodeIfPresent(
            PomodoroSession.self,
            forKey: .pomodoro
        )
        snoozes = try container.decodeIfPresent(
            [ReminderSnooze].self,
            forKey: .snoozes
        ) ?? []
    }

    public func replacingTimers(
        _ timers: [ProductivityCountdownTimer]
    ) -> ProductivitySnapshot {
        ProductivitySnapshot(
            timers: timers,
            reminders: reminders,
            pomodoro: pomodoro,
            snoozes: snoozes
        )
    }

    public func replacingPomodoro(
        _ pomodoro: PomodoroSession?
    ) -> ProductivitySnapshot {
        ProductivitySnapshot(
            timers: timers,
            reminders: reminders,
            pomodoro: pomodoro,
            snoozes: snoozes
        )
    }

    public func reconciling(at now: Date) -> ProductivitySnapshot {
        ProductivitySnapshot(
            timers: timers.map { $0.reconciling(at: now) },
            reminders: reminders,
            pomodoro: pomodoro?.advancing(at: now),
            snoozes: snoozes.filter { $0.fireDate > now }
        )
    }
}
