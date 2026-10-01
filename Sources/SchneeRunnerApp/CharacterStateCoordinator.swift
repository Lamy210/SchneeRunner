import SchneeRunnerCore

@MainActor
final class CharacterStateCoordinator {
    private static let cpuTriggerID = "cpu"
    private static let batteryWarningTriggerID = "battery-warning"
    private static let memoryPressureTriggerID = "memory-pressure"
    private static let buildTriggerID = "build"
    private static let localEventTriggerPrefix = "local-event:"
    private static let manualTriggerID = "manual"

    private let playbackController: CharacterPlaybackController
    private let cpuStatePolicy = CharacterStatePolicy()
    private let batteryWarningPolicy = BatteryWarningStatePolicy()
    private let memoryPressurePolicy = MemoryPressureStatePolicy()
    private let batteryWarningMonitor = SystemBatteryWarningMonitor()
    private let buildEventMonitor = LocalBuildEventMonitor()
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
        buildEventMonitor.onSet = { [weak self] state in
            self?.setBuildEvent(state)
        }
        buildEventMonitor.onClear = { [weak self] in
            self?.clearBuildEvent()
        }
        localEventMonitor.onSet = { [weak self] channel, state in
            self?.setLocalEvent(
                state,
                channel: channel
            )
        }
        localEventMonitor.onClear = { [weak self] channel in
            self?.clearLocalEvent(channel: channel)
        }
        memoryPressureMonitor.onChange = { [weak self] level in
            self?.updateMemoryPressure(level)
        }
    }

    func start() {
        batteryWarningMonitor.start()
        buildEventMonitor.start()
        localEventMonitor.start()
        memoryPressureMonitor.start()
    }

    func stop() {
        batteryWarningMonitor.stop()
        buildEventMonitor.stop()
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

    func setBuildEvent(_ state: CharacterState) {
        triggerEngine.set(
            CharacterStateTrigger(
                id: Self.buildTriggerID,
                state: state,
                priority: .event
            )
        )
        applyResolvedState()
    }

    func clearBuildEvent() {
        triggerEngine.remove(
            id: Self.buildTriggerID
        )
        applyResolvedState()
    }

    func setLocalEvent(
        _ state: CharacterState,
        channel: String = LocalCharacterStateEvent.defaultChannel
    ) {
        triggerEngine.set(
            CharacterStateTrigger(
                id: Self.localEventTriggerID(for: channel),
                state: state,
                priority: .event
            )
        )
        applyResolvedState()
    }

    func clearLocalEvent(
        channel: String = LocalCharacterStateEvent.defaultChannel
    ) {
        triggerEngine.remove(
            id: Self.localEventTriggerID(for: channel)
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

    private static func localEventTriggerID(
        for channel: String
    ) -> String {
        "\(localEventTriggerPrefix)\(channel)"
    }

    private func applyResolvedState() {
        playbackController.requestState(
            triggerEngine.resolution.state
        )
    }
}
