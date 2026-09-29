import SchneeRunnerCore

@MainActor
final class CharacterPlaybackController {
    private let animationController: AnimationController

    private var library: CharacterAnimationLibrary?

    private(set) var requestedState: CharacterState = .run
    private(set) var resolvedState: CharacterState?

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
        self.library = library
        resolvedState = nil
        applyRequestedState()
    }

    func requestState(_ state: CharacterState) {
        requestedState = state
        applyRequestedState()
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
}
