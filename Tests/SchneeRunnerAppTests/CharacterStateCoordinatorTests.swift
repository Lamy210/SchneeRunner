@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class CharacterStateCoordinatorTests: XCTestCase {
    func testClearingCPUStateRestoresFallbackState() {
        let playbackController = CharacterPlaybackController(
            animationController: AnimationController()
        )
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.updateCPUState(for: .sprint)
        XCTAssertEqual(playbackController.requestedState, .sprint)

        coordinator.clearCPUState()

        XCTAssertEqual(playbackController.requestedState, .run)
    }

    func testClearingCPUStatePreservesHigherPriorityManualOverride() {
        let playbackController = CharacterPlaybackController(
            animationController: AnimationController()
        )
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.updateCPUState(for: .sprint)
        coordinator.setManualOverride(.idle)
        coordinator.clearCPUState()

        XCTAssertEqual(playbackController.requestedState, .idle)
    }

    func testProductivityStateUsesEventPriority() {
        let playbackController = CharacterPlaybackController(
            animationController: AnimationController()
        )
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.updateCPUState(for: .walk)
        coordinator.setProductivityState(.dash)

        XCTAssertEqual(playbackController.requestedState, .dash)
    }

    func testClearingProductivityStateRestoresLowerPriorityState() {
        let playbackController = CharacterPlaybackController(
            animationController: AnimationController()
        )
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.updateCPUState(for: .walk)
        coordinator.setProductivityState(.dash)
        coordinator.setProductivityState(nil)

        XCTAssertEqual(playbackController.requestedState, .walk)
    }

    func testManualOverrideStillWinsAfterProductivityUpdates() {
        let playbackController = CharacterPlaybackController(
            animationController: AnimationController()
        )
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.setManualOverride(.idle)
        coordinator.setProductivityState(.sprint)

        XCTAssertEqual(playbackController.requestedState, .idle)
    }
}
