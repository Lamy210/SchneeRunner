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
}
