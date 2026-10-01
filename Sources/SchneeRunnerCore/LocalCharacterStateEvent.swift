import Foundation

public enum LocalCharacterStateEventAction: String, Codable, Sendable {
    case set
    case clear
}

public enum LocalCharacterStateEventError: Error, Equatable, LocalizedError {
    case stateRequired
    case clearPayloadMustBeEmpty
    case invalidDuration(Double)
    case invalidChannel(String)
    case invalidUTF8

    public var errorDescription: String? {
        switch self {
        case .stateRequired:
            "A local state event requires a character state."
        case .clearPayloadMustBeEmpty:
            "A clear event must not include state or duration."
        case let .invalidDuration(value):
            "Local state event duration \(value) is outside the supported range."
        case let .invalidChannel(value):
            "Local state event channel \(value) is invalid."
        case .invalidUTF8:
            "The local state event payload is not valid UTF-8."
        }
    }
}

public struct LocalCharacterStateEvent: Codable, Equatable, Sendable {
    public static let notificationName = "com.schneerunner.character-state-event.v1"
    public static let defaultChannel = "default"
    public static let minimumDurationSeconds = 0.1
    public static let maximumDurationSeconds = 3600.0
    public static let maximumChannelLength = 64

    public let action: LocalCharacterStateEventAction
    public let state: CharacterState?
    public let durationSeconds: Double?
    public let channel: String

    private static let allowedChannelCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "._-"))

    private enum CodingKeys: String, CodingKey {
        case action
        case state
        case durationSeconds
        case channel
    }

    private init(
        action: LocalCharacterStateEventAction,
        state: CharacterState?,
        durationSeconds: Double?,
        channel: String
    ) {
        self.action = action
        self.state = state
        self.durationSeconds = durationSeconds
        self.channel = channel
    }

    public static func set(
        state: CharacterState,
        durationSeconds: Double? = nil,
        channel: String = defaultChannel
    ) throws -> LocalCharacterStateEvent {
        try validate(
            action: .set,
            state: state,
            durationSeconds: durationSeconds,
            channel: channel
        )

        return LocalCharacterStateEvent(
            action: .set,
            state: state,
            durationSeconds: durationSeconds,
            channel: channel
        )
    }

    public static func clear() -> LocalCharacterStateEvent {
        LocalCharacterStateEvent(
            action: .clear,
            state: nil,
            durationSeconds: nil,
            channel: defaultChannel
        )
    }

    public static func clear(
        channel: String
    ) throws -> LocalCharacterStateEvent {
        try validate(
            action: .clear,
            state: nil,
            durationSeconds: nil,
            channel: channel
        )

        return LocalCharacterStateEvent(
            action: .clear,
            state: nil,
            durationSeconds: nil,
            channel: channel
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
        let channel = try container.decodeIfPresent(
            String.self,
            forKey: .channel
        ) ?? Self.defaultChannel

        try Self.validate(
            action: action,
            state: state,
            durationSeconds: durationSeconds,
            channel: channel
        )

        self.action = action
        self.state = state
        self.durationSeconds = durationSeconds
        self.channel = channel
    }

    private static func validate(
        action: LocalCharacterStateEventAction,
        state: CharacterState?,
        durationSeconds: Double?,
        channel: String
    ) throws {
        try validateChannel(channel)

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

    private static func validateChannel(
        _ channel: String
    ) throws {
        guard
            !channel.isEmpty,
            channel.utf8.count <= maximumChannelLength,
            channel.unicodeScalars.allSatisfy(
                allowedChannelCharacters.contains
            )
        else {
            throw LocalCharacterStateEventError.invalidChannel(
                channel
            )
        }
    }
}
