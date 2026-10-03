import SchneeRunnerCore

@MainActor
final class CharacterPlaybackController {
    private let animationController: AnimationController

    private var library: CharacterAnimationLibrary?

    private(set) var requestedState: CharacterState = .run
    private(set) var resolvedState: CharacterState?

    var onStateChange: (() -> Void)?

    init(animationController: AnimationController) {
        self.animationController = animationController
    }

    var isUsingFallback: Bool {
        guard let resolvedState else {
            return false
        }

        return requestedState != resolvedState
    }

    func install(_ library: CharacterAnimationLibrary) {
        let previousRequestedState = requestedState
        let previousResolvedState = resolvedState

        self.library = library
        resolvedState = nil
        applyRequestedState()
        notifyStateChangeIfNeeded(
            previousRequestedState: previousRequestedState,
            previousResolvedState: previousResolvedState
        )
    }

    func requestState(_ state: CharacterState) {
        let previousRequestedState = requestedState
        let previousResolvedState = resolvedState

        requestedState = state
        applyRequestedState()
        notifyStateChangeIfNeeded(
            previousRequestedState: previousRequestedState,
            previousResolvedState: previousResolvedState
        )
    }

    private func applyRequestedState() {
        guard let library else {
            return
        }

        let resolution = library.resolve(
            requestedState: requestedState
        )
        guard resolution.resolvedState != resolvedState else {
            return
        }

        animationController.replaceAnimation(
            resolution.animation
        )
        resolvedState = resolution.resolvedState
    }

    private func notifyStateChangeIfNeeded(
        previousRequestedState: CharacterState,
        previousResolvedState: CharacterState?
    ) {
        guard
            previousRequestedState != requestedState
            || previousResolvedState != resolvedState
        else {
            return
        }

        onStateChange?()
    }
}
