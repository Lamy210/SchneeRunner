import SchneeRunnerCore

@MainActor
final class CharacterStateCoordinator {
    private static let cpuTriggerID = "cpu"
    private static let batteryWarningTriggerID = "battery-warning"
    private static let memoryPressureTriggerID = "memory-pressure"
    private static let buildTriggerID = "build"
    private static let localEventTriggerPrefix = "local-event:"
    private static let productivityTriggerID = "productivity"
    private static let manualTriggerID = "manual"

    private let playbackController: CharacterPlaybackController
    private let cpuStatePolicy = CharacterStatePolicy()
    private let batteryWarningPolicy = BatteryWarningStatePolicy()
    private let memoryPressurePolicy = MemoryPressureStatePolicy()
    private let buildStatePolicy = BuildStatePolicy()
    private let batteryWarningProvider: any MetricProvider<BatteryWarningLevel>
    private let buildEventProvider: any EventProvider<BuildLifecycleProviderEvent>
    private let localEventProvider: any EventProvider<LocalCharacterStateProviderEvent>
    private let memoryPressureProvider: any EventProvider<MemoryPressureLevel>

    private var triggerEngine = CharacterStateTriggerEngine()
    private var activeLocalEventChannels: Set<String> = []

    init(
        playbackController: CharacterPlaybackController,
        batteryWarningProvider: any MetricProvider<BatteryWarningLevel> = SystemBatteryWarningMonitor(),
        memoryPressureProvider: any EventProvider<MemoryPressureLevel> = SystemMemoryPressureMonitor(),
        buildEventProvider: any EventProvider<BuildLifecycleProviderEvent> = LocalBuildEventMonitor(),
        localEventProvider: any EventProvider<LocalCharacterStateProviderEvent> = LocalCharacterStateEventMonitor()
    ) {
        self.playbackController = playbackController
        self.batteryWarningProvider = batteryWarningProvider
        self.memoryPressureProvider = memoryPressureProvider
        self.buildEventProvider = buildEventProvider
        self.localEventProvider = localEventProvider

        self.batteryWarningProvider.onUpdate = { [weak self] level in
            self?.updateBatteryWarning(level)
        }
        self.memoryPressureProvider.onEvent = { [weak self] level in
            self?.updateMemoryPressure(level)
        }
        self.buildEventProvider.onEvent = { [weak self] event in
            self?.handleBuildProviderEvent(event)
        }
        self.localEventProvider.onEvent = { [weak self] event in
            self?.handleLocalProviderEvent(event)
        }
    }

    func start() {
        batteryWarningProvider.start()
        buildEventProvider.start()
        localEventProvider.start()
        memoryPressureProvider.start()
    }

    func stop() {
        batteryWarningProvider.stop()
        buildEventProvider.stop()
        localEventProvider.stop()
        memoryPressureProvider.stop()
        clearProviderOwnedState()
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

    func clearCPUState() {
        triggerEngine.remove(
            id: Self.cpuTriggerID
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
        activeLocalEventChannels.insert(channel)
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
        activeLocalEventChannels.remove(channel)
        triggerEngine.remove(
            id: Self.localEventTriggerID(for: channel)
        )
        applyResolvedState()
    }

    func setProductivityState(_ state: CharacterState?) {
        if let state {
            triggerEngine.set(
                CharacterStateTrigger(
                    id: Self.productivityTriggerID,
                    state: state,
                    priority: .event
                )
            )
        } else {
            triggerEngine.remove(
                id: Self.productivityTriggerID
            )
        }
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

    private func handleBuildProviderEvent(
        _ event: BuildLifecycleProviderEvent
    ) {
        switch event {
        case let .received(buildEvent):
            let effect = buildStatePolicy.effect(
                for: buildEvent.phase
            )
            if let state = effect.state {
                setBuildEvent(state)
            } else {
                clearBuildEvent()
            }

        case .expired:
            clearBuildEvent()
        }
    }

    private func handleLocalProviderEvent(
        _ event: LocalCharacterStateProviderEvent
    ) {
        switch event {
        case let .received(localEvent):
            switch localEvent.action {
            case .set:
                guard let state = localEvent.state else {
                    return
                }
                setLocalEvent(
                    state,
                    channel: localEvent.channel
                )

            case .clear:
                clearLocalEvent(
                    channel: localEvent.channel
                )
            }

        case let .expired(channel):
            clearLocalEvent(channel: channel)
        }
    }

    private func clearProviderOwnedState() {
        triggerEngine.remove(id: Self.batteryWarningTriggerID)
        triggerEngine.remove(id: Self.memoryPressureTriggerID)
        triggerEngine.remove(id: Self.buildTriggerID)

        for channel in activeLocalEventChannels {
            triggerEngine.remove(
                id: Self.localEventTriggerID(for: channel)
            )
        }
        activeLocalEventChannels.removeAll()
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
