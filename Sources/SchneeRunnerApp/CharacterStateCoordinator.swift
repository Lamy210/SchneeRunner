import SchneeRunnerCore

@MainActor
final class CharacterStateCoordinator {
    private static let cpuTriggerID = "cpu"
    private static let manualTriggerID = "manual"

    private let playbackController: CharacterPlaybackController
    private let statePolicy = CharacterStatePolicy()

    private var triggerEngine = CharacterStateTriggerEngine()

    init(
        playbackController: CharacterPlaybackController
    ) {
        self.playbackController = playbackController
    }

    func updateCPUState(for pace: AnimationPace) {
        triggerEngine.set(
            CharacterStateTrigger(
                id: Self.cpuTriggerID,
                state: statePolicy.state(for: pace),
                priority: .metric
            )
        )
        applyResolvedState()
    }

    func setManualOverride(_ state: CharacterState?) {
        if let state {
            triggerEngine.set(
                CharacterStateTrigger(
                    id: Self.manualTriggerID,
                    state: state,
                    priority: .manual
                )
            )
        } else {
            triggerEngine.remove(
                id: Self.manualTriggerID
            )
        }

        applyResolvedState()
    }

    private func applyResolvedState() {
        playbackController.requestState(
            triggerEngine.resolution.state
        )
    }
}
