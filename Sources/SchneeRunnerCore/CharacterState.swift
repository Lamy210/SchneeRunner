import Foundation

public enum CharacterState: String, CaseIterable, Codable, Hashable, Sendable {
    case idle
    case walk
    case run
    case dash
    case sprint

    public var displayName: String {
        switch self {
        case .idle:
            "Idle"
        case .walk:
            "Walk"
        case .run:
            "Run"
        case .dash:
            "Dash"
        case .sprint:
            "Sprint"
        }
    }
}

public struct CharacterStatePolicy: Sendable {
    public init() {}

    public func state(for pace: AnimationPace) -> CharacterState {
        switch pace {
        case .idle:
            .idle
        case .walk:
            .walk
        case .run:
            .run
        case .dash:
            .dash
        case .sprint:
            .sprint
        }
    }
}
