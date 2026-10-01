import SchneeRunnerCore

@MainActor
final class CharacterStateCoordinator {
    private static let cpuTriggerID = "cpu"
    private static let batteryWarningTriggerID = "battery-warning"
    private static let memoryPressureTriggerID = "memory-pressure"
    private static let localEventTriggerID = "local-event"
    private static let manualTriggerID = "manual"

    private let playbackController: CharacterPlaybackController
    private let cpuStatePolicy = CharacterStatePolicy()
    private let batteryWarningPolicy = BatteryWarningStatePolicy()
    private let memoryPressurePolicy = MemoryPressureStatePolicy()
    private let batteryWarningMonitor = SystemBatteryWarningMonitor()
    private let localEventMonitor = LocalCharacterStateEventMonitor()
    private let memoryPressureMonitor = SystemMemoryPressureMonitor()

    private var triggerEngine = CharacterStateTriggerEngine()

    init(
        playbackController: CharacterPlaybackController
    ) {
        self.playbackController = playbackController

        batteryWarningMonitor.onChange = { [weak self] level in
            self?.updateBatteryWarning(level)
        }
        localEventMonitor.onSet = { [weak self] state in
            self?.setLocalEvent(state)
        }
        localEventMonitor.onClear = { [weak self] in
            self?.clearLocalEvent()
        }
        memoryPressureMonitor.onChange = { [weak self] level in
            self?.updateMemoryPressure(level)
        }
    }

    func start() {
        batteryWarningMonitor.start()
        localEventMonitor.start()
        memoryPressureMonitor.start()
    }

    func stop() {
        batteryWarningMonitor.stop()
        localEventMonitor.stop()
        memoryPressureMonitor.stop()
    }

    func updateCPUState(for pace: AnimationPace) {
        triggerEngine.set(
            CharacterStateTrigger(
                id: Self.cpuTriggerID,
                state: cpuStatePolicy.state(for: pace),
                priority: .metric
            )
        )
        applyResolvedState()
    }

    func updateBatteryWarning(_ level: BatteryWarningLevel) {
        if let state = batteryWarningPolicy.state(for: level) {
            triggerEngine.set(
                CharacterStateTrigger(
                    id: Self.batteryWarningTriggerID,
                    state: state,
                    priority: .systemAdvisory
                )
            )
        } else {
            triggerEngine.remove(
                id: Self.batteryWarningTriggerID
            )
        }

        applyResolvedState()
    }

    func updateMemoryPressure(_ level: MemoryPressureLevel) {
        if let state = memoryPressurePolicy.state(for: level) {
            triggerEngine.set(
                CharacterStateTrigger(
                    id: Self.memoryPressureTriggerID,
                    state: state,
                    priority: .systemEvent
                )
            )
        } else {
            triggerEngine.remove(
                id: Self.memoryPressureTriggerID
            )
        }

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
