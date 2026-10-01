import Foundation

public enum BuildLifecyclePhase: String, CaseIterable, Codable, Sendable {
    case started
    case succeeded
    case failed
    case cancelled
}

public struct LocalBuildEvent: Codable, Equatable, Sendable {
    public static let notificationName = "com.schneerunner.build-event.v1"

    public let phase: BuildLifecyclePhase

    public init(phase: BuildLifecyclePhase) {
        self.phase = phase
    }

    public func encodedJSON() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let value = String(
            data: data,
            encoding: .utf8
        ) else {
            throw LocalBuildEventError.invalidUTF8
        }

        return value
    }

    public static func decodeJSON(
        _ value: String
    ) throws -> LocalBuildEvent {
        try JSONDecoder().decode(
            LocalBuildEvent.self,
            from: Data(value.utf8)
        )
    }
}

public enum LocalBuildEventError: Error, Equatable, LocalizedError {
    case invalidUTF8

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            "The local build event payload is not valid UTF-8."
        }
    }
}

public struct BuildTriggerEffect: Equatable, Sendable {
    public let state: CharacterState?
    public let durationSeconds: Double?

    public init(
        state: CharacterState?,
        durationSeconds: Double?
    ) {
        self.state = state
        self.durationSeconds = durationSeconds
    }
}

public struct BuildStatePolicy: Sendable {
    public init() {}

    public func effect(
        for phase: BuildLifecyclePhase
    ) -> BuildTriggerEffect {
        switch phase {
        case .started:
            BuildTriggerEffect(
                state: .dash,
                durationSeconds: nil
            )
        case .succeeded:
            BuildTriggerEffect(
                state: .sprint,
                durationSeconds: 2
            )
        case .failed:
            BuildTriggerEffect(
                state: .idle,
                durationSeconds: 5
            )
        case .cancelled:
            BuildTriggerEffect(
                state: nil,
                durationSeconds: nil
            )
        }
    }
}
