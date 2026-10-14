@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class CharacterStateCoordinatorRestartTests: XCTestCase {
    func testStopClearsProviderOwnedTriggersAndPreservesExternalTriggers() throws {
        let playbackController = CharacterPlaybackController(
            animationController: AnimationController()
        )
        let battery = RestartFakeMetricProvider<BatteryWarningLevel>()
        let memory = RestartFakeEventProvider<MemoryPressureLevel>()
        let build = RestartFakeEventProvider<BuildLifecycleProviderEvent>()
        let local = RestartFakeEventProvider<LocalCharacterStateProviderEvent>()
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController,
            batteryWarningProvider: battery,
            memoryPressureProvider: memory,
            buildEventProvider: build,
            localEventProvider: local
        )
        let localEvent = try LocalCharacterStateEvent.set(
            state: .sprint,
            channel: "restart"
        )

        coordinator.updateCPUState(for: .walk)
        coordinator.setProductivityState(.idle)
        coordinator.start()
        battery.emit(.final)
        memory.emit(.critical)
        build.emit(.received(LocalBuildEvent(phase: .started)))
        local.emit(.received(localEvent))
        XCTAssertEqual(playbackController.requestedState, .sprint)

        coordinator.stop()
        XCTAssertEqual(playbackController.requestedState, .idle)

        coordinator.setProductivityState(nil)
        XCTAssertEqual(playbackController.requestedState, .walk)
    }
}

@MainActor
private final class RestartFakeMetricProvider<Value>: MetricProvider {
    var onUpdate: ((Value) -> Void)?

    func start() {}

    func stop() {}

    func emit(_ value: Value) {
        onUpdate?(value)
    }
}

@MainActor
private final class RestartFakeEventProvider<Value>: EventProvider {
    var onEvent: ((Value) -> Void)?

    func start() {}

    func stop() {}

    func emit(_ value: Value) {
        onEvent?(value)
    }
}
