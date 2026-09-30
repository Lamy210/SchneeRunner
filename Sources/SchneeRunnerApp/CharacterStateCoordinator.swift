import SchneeRunnerCore

@MainActor
final class CharacterStateCoordinator {
    private static let cpuTriggerID = "cpu"
    private static let localEventTriggerID = "local-event"
    private static let manualTriggerID = "manual"

    private let playbackController: CharacterPlaybackController
    private let statePolicy = CharacterStatePolicy()
    private let localEventMonitor = LocalCharacterStateEventMonitor()

    private var triggerEngine = CharacterStateTriggerEngine()

    init(
        playbackController: CharacterPlaybackController
    ) {
        self.playbackController = playbackController

        localEventMonitor.onSet = { [weak self] state in
            self?.setLocalEvent(state)
        }
        localEventMonitor.onClear = { [weak self] in
            self?.clearLocalEvent()
        }
    }

    func start() {
        localEventMonitor.start()
    }

    func stop() {
        localEventMonitor.stop()
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

    func setLocalEvent(_ state: CharacterState) {
        triggerEngine.set(
            CharacterStateTrigger(
                id: Self.localEventTriggerID,
                state: state,
                priority: .event
            )
        )
        applyResolvedState()
    }

    func clearLocalEvent() {
        triggerEngine.remove(
            id: Self.localEventTriggerID
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
