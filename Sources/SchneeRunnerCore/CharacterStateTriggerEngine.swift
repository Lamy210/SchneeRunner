import Foundation

public struct CharacterStateTriggerPriority: RawRepresentable, Comparable, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let metric = CharacterStateTriggerPriority(
        rawValue: 100
    )
    public static let systemAdvisory = CharacterStateTriggerPriority(
        rawValue: 300
    )
    public static let systemEvent = CharacterStateTriggerPriority(
        rawValue: 400
    )
    public static let event = CharacterStateTriggerPriority(
        rawValue: 500
    )
    public static let manual = CharacterStateTriggerPriority(
        rawValue: 1000
    )

    public static func < (
        lhs: CharacterStateTriggerPriority,
        rhs: CharacterStateTriggerPriority
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct CharacterStateTrigger: Equatable, Sendable {
    public let id: String
    public let state: CharacterState
    public let priority: CharacterStateTriggerPriority

    public init(
        id: String,
        state: CharacterState,
        priority: CharacterStateTriggerPriority
    ) {
        self.id = id
        self.state = state
        self.priority = priority
    }
}

public struct CharacterStateTriggerResolution: Equatable, Sendable {
    public let state: CharacterState
    public let trigger: CharacterStateTrigger?

    public var isFallback: Bool {
        trigger == nil
    }
}

public struct CharacterStateTriggerEngine: Sendable {
    private struct Entry: Sendable {
        let trigger: CharacterStateTrigger
        let generation: UInt64
    }

    public let fallbackState: CharacterState

    private var entries: [String: Entry] = [:]
    private var generation: UInt64 = 0

    public init(fallbackState: CharacterState = .run) {
        self.fallbackState = fallbackState
    }

    public mutating func set(_ trigger: CharacterStateTrigger) {
        generation &+= 1
        entries[trigger.id] = Entry(
            trigger: trigger,
            generation: generation
        )
    }

    public mutating func remove(id: String) {
        entries.removeValue(forKey: id)
    }

    public mutating func removeAll() {
        entries.removeAll()
    }

    public var resolution: CharacterStateTriggerResolution {
        guard let entry = winningEntry else {
            return CharacterStateTriggerResolution(
                state: fallbackState,
                trigger: nil
            )
        }

        return CharacterStateTriggerResolution(
            state: entry.trigger.state,
            trigger: entry.trigger
        )
    }

    private var winningEntry: Entry? {
        entries.values.max { lhs, rhs in
            if lhs.trigger.priority != rhs.trigger.priority {
                return lhs.trigger.priority < rhs.trigger.priority
            }

            return lhs.generation < rhs.generation
        }
    }
}
