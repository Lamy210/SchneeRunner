import Foundation

public enum CharacterAnimationLibraryError: Error, Equatable, LocalizedError {
    case emptyLibrary
    case defaultStateMissing(CharacterState)

    public var errorDescription: String? {
        switch self {
        case .emptyLibrary:
            "Character animation libraries require at least one animation."
        case let .defaultStateMissing(state):
            "The default character state \(state.rawValue) does not have an animation."
        }
    }
}

public struct CharacterAnimationResolution {
    public let requestedState: CharacterState
    public let resolvedState: CharacterState
    public let animation: LoadedAnimation

    public var usedFallback: Bool {
        requestedState != resolvedState
    }
}

public struct CharacterAnimationLibrary {
    public let defaultState: CharacterState

    private let animations: [CharacterState: LoadedAnimation]
    private let defaultAnimation: LoadedAnimation

    public init(
        animations: [CharacterState: LoadedAnimation],
        defaultState: CharacterState
    ) throws {
        guard !animations.isEmpty else {
            throw CharacterAnimationLibraryError.emptyLibrary
        }
        guard let defaultAnimation = animations[defaultState] else {
            throw CharacterAnimationLibraryError.defaultStateMissing(
                defaultState
            )
        }

        self.animations = animations
        self.defaultState = defaultState
        self.defaultAnimation = defaultAnimation
    }

    public static func single(
        animation: LoadedAnimation,
        state: CharacterState = .run
    ) throws -> CharacterAnimationLibrary {
        try CharacterAnimationLibrary(
            animations: [state: animation],
            defaultState: state
        )
    }

    public var availableStates: [CharacterState] {
        CharacterState.allCases.filter {
            animations[$0] != nil
        }
    }

    public func resolve(
        requestedState: CharacterState
    ) -> CharacterAnimationResolution {
        if let animation = animations[requestedState] {
            return CharacterAnimationResolution(
                requestedState: requestedState,
                resolvedState: requestedState,
                animation: animation
            )
        }

        return CharacterAnimationResolution(
            requestedState: requestedState,
            resolvedState: defaultState,
            animation: defaultAnimation
        )
    }
}
