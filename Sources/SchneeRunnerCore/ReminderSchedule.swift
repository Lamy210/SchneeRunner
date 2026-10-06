import Foundation

public enum Weekday: Int, Codable, CaseIterable, Sendable, Hashable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

public enum ReminderScheduleError: Error, Equatable, Sendable {
    case invalidHour(Int)
    case invalidMinute(Int)
    case emptyWeekdays
}

public enum ReminderSchedule: Codable, Equatable, Sendable {
    case once(Date)
    case daily(hour: Int, minute: Int)
    case weekdays(Set<Weekday>, hour: Int, minute: Int)

    public func validate() throws {
        switch self {
        case .once:
            return
        case let .daily(hour, minute):
            try Self.validateTime(hour: hour, minute: minute)
        case let .weekdays(weekdays, hour, minute):
            guard !weekdays.isEmpty else {
                throw ReminderScheduleError.emptyWeekdays
            }
            try Self.validateTime(hour: hour, minute: minute)
        }
    }

    public func nextOccurrence(
        after now: Date,
        calendar: Calendar
    ) -> Date? {
        guard (try? validate()) != nil else {
            return nil
        }

        switch self {
        case let .once(date):
            return date > now ? date : nil
        case let .daily(hour, minute):
            return nextDate(
                after: now,
                calendar: calendar,
                weekday: nil,
                hour: hour,
                minute: minute
            )
        case let .weekdays(weekdays, hour, minute):
            return weekdays.compactMap { weekday in
                nextDate(
                    after: now,
                    calendar: calendar,
                    weekday: weekday,
                    hour: hour,
                    minute: minute
                )
            }.min()
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .once:
            let date = try container.decode(Date.self, forKey: .date)
            self = .once(date)
        case .daily:
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decode(Int.self, forKey: .minute)
            self = .daily(hour: hour, minute: minute)
        case .weekdays:
            let weekdays = try Set(
                container.decode([Weekday].self, forKey: .weekdays)
            )
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decode(Int.self, forKey: .minute)
            self = .weekdays(weekdays, hour: hour, minute: minute)
        }

        try validate()
    }

    public func encode(to encoder: Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .once(date):
            try container.encode(Kind.once, forKey: .kind)
            try container.encode(date, forKey: .date)
        case let .daily(hour, minute):
            try container.encode(Kind.daily, forKey: .kind)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
        case let .weekdays(weekdays, hour, minute):
            try container.encode(Kind.weekdays, forKey: .kind)
            try container.encode(
                weekdays.sorted { $0.rawValue < $1.rawValue },
                forKey: .weekdays
            )
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
        }
    }
}

private extension ReminderSchedule {
    enum Kind: String, Codable {
        case once
        case daily
        case weekdays
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case date
        case hour
        case minute
        case weekdays
    }

    static func validateTime(hour: Int, minute: Int) throws {
        guard (0 ... 23).contains(hour) else {
            throw ReminderScheduleError.invalidHour(hour)
        }
        guard (0 ... 59).contains(minute) else {
            throw ReminderScheduleError.invalidMinute(minute)
        }
    }

    func nextDate(
        after now: Date,
        calendar: Calendar,
        weekday: Weekday?,
        hour: Int,
        minute: Int
    ) -> Date? {
        var components = DateComponents()
        components.weekday = weekday?.rawValue
        components.hour = hour
        components.minute = minute

        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }
}
