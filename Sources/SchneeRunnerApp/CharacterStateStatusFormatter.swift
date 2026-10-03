import SchneeRunnerCore

enum CharacterStateStatusFormatter {
    static func label(
        requestedState: CharacterState,
        resolvedState: CharacterState?
    ) -> String {
        guard
            let resolvedState,
            resolvedState != requestedState
        else {
            return requestedState.displayName
        }

        return "\(requestedState.displayName) → \(resolvedState.displayName)"
    }
}
