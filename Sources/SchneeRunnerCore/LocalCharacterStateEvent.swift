import Foundation

public enum LocalCharacterStateEventAction: String, Codable, Sendable {
    case set
    case clear
}

public enum LocalCharacterStateEventError: Error, Equatable, LocalizedError {
    case stateRequired
    case clearPayloadMustBeEmpty
    case invalidDuration(Double)
    case invalidUTF8

    public var errorDescription: String? {
        switch self {
        case .stateRequired:
            "A local state event requires a character state."
        case .clearPayloadMustBeEmpty:
            "A clear event must not include state or duration."
        case let .invalidDuration(value):
            "Local state event duration \(value) is outside the supported range."
        case .invalidUTF8:
            "The local state event payload is not valid UTF-8."
        }
    }
}

public struct LocalCharacterStateEvent: Codable, Equatable, Sendable {
    public static let notificationName = "com.schneerunner.character-state-event.v1"
    public static let minimumDurationSeconds = 0.1
    public static let maximumDurationSeconds = 3600.0

    public let action: LocalCharacterStateEventAction
    public let state: CharacterState?
    public let durationSeconds: Double?

    private enum CodingKeys: String, CodingKey {
        case action
        case state
        case durationSeconds
    }

    private init(
        action: LocalCharacterStateEventAction,
        state: CharacterState?,
        durationSeconds: Double?
    ) throws {
        try Self.validate(
            action: action,
            state: state,
            durationSeconds: durationSeconds
        )

        self.action = action
        self.state = state
        self.durationSeconds = durationSeconds
    }

    public static func set(
        state: CharacterState,
        durationSeconds: Double? = nil
    ) throws -> LocalCharacterStateEvent {
        try LocalCharacterStateEvent(
            action: .set,
            state: state,
            durationSeconds: durationSeconds
        )
    }

    public static func clear() -> LocalCharacterStateEvent {
        try! LocalCharacterStateEvent(
            action: .clear,
            state: nil,
            durationSeconds: nil
        )
    }

    public func encodedJSON() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let value = String(
            data: data,
            encoding: .utf8
        ) else {
            throw LocalCharacterStateEventError.invalidUTF8
        }

        return value
    }

    public static func decodeJSON(
        _ value: String
    ) throws -> LocalCharacterStateEvent {
        try JSONDecoder().decode(
            LocalCharacterStateEvent.self,
            from: Data(value.utf8)
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let action = try container.decode(
            LocalCharacterStateEventAction.self,
            forKey: .action
        )
        let state = try container.decodeIfPresent(
            CharacterState.self,
            forKey: .state
        )
        let durationSeconds = try container.decodeIfPresent(
            Double.self,
            forKey: .durationSeconds
        )

        try Self.validate(
            action: action,
            state: state,
            durationSeconds: durationSeconds
        )

        self.action = action
        self.state = state
        self.durationSeconds = durationSeconds
    }

    private static func validate(
        action: LocalCharacterStateEventAction,
        state: CharacterState?,
        durationSeconds: Double?
    ) throws {
        switch action {
        case .set:
            guard state != nil else {
                throw LocalCharacterStateEventError.stateRequired
            }

            if let durationSeconds {
                guard
                    durationSeconds.isFinite,
                    durationSeconds >= minimumDurationSeconds,
                    durationSeconds <= maximumDurationSeconds
                else {
                    throw LocalCharacterStateEventError.invalidDuration(
                        durationSeconds
                    )
                }
            }

        case .clear:
            guard
                state == nil,
                durationSeconds == nil
            else {
                throw LocalCharacterStateEventError.clearPayloadMustBeEmpty
            }
        }
    }
}
