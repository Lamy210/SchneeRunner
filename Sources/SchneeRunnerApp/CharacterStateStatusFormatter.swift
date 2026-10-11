import SchneeRunnerCore

enum CharacterStateStatusFormatter {
    static func label(
        requestedState: CharacterState,
        resolvedState: CharacterState?,
        localization: AppLocalization = .current
    ) -> String {
        let requestedLabel = localization.characterState(requestedState)
        guard
            let resolvedState,
            resolvedState != requestedState
        else {
            return requestedLabel
        }

        return "\(requestedLabel) → \(localization.characterState(resolvedState))"
    }
}
