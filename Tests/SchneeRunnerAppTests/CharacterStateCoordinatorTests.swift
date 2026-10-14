@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class CharacterStateCoordinatorTests: XCTestCase {
    func testInjectedProvidersFollowCoordinatorLifecycle() {
        let playbackController = makePlaybackController()
        let battery = FakeMetricProvider<BatteryWarningLevel>()
        let memory = FakeEventProvider<MemoryPressureLevel>()
        let build = FakeEventProvider<BuildLifecycleProviderEvent>()
        let local = FakeEventProvider<LocalCharacterStateProviderEvent>()
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController,
            batteryWarningProvider: battery,
            memoryPressureProvider: memory,
            buildEventProvider: build,
            localEventProvider: local
        )

        coordinator.start()
        coordinator.stop()

        XCTAssertEqual(battery.startCount, 1)
        XCTAssertEqual(battery.stopCount, 1)
        XCTAssertEqual(memory.startCount, 1)
        XCTAssertEqual(memory.stopCount, 1)
        XCTAssertEqual(build.startCount, 1)
        XCTAssertEqual(build.stopCount, 1)
        XCTAssertEqual(local.startCount, 1)
        XCTAssertEqual(local.stopCount, 1)
    }

    func testBatteryProviderPreservesAdvisoryPriorityAndFallback() {
        let playbackController = makePlaybackController()
        let battery = FakeMetricProvider<BatteryWarningLevel>()
        let coordinator = makeCoordinator(
            playbackController: playbackController,
            battery: battery
        )

        coordinator.updateCPUState(for: .sprint)
        battery.emit(.early)
        XCTAssertEqual(playbackController.requestedState, .walk)

        battery.emit(.none)
        XCTAssertEqual(playbackController.requestedState, .sprint)
    }

    func testMemoryProviderPreservesSystemEventPriorityAndFallback() {
        let playbackController = makePlaybackController()
        let memory = FakeEventProvider<MemoryPressureLevel>()
        let coordinator = makeCoordinator(
            playbackController: playbackController,
            memory: memory
        )

        coordinator.updateCPUState(for: .walk)
        memory.emit(.warning)
        XCTAssertEqual(playbackController.requestedState, .dash)

        memory.emit(.normal)
        XCTAssertEqual(playbackController.requestedState, .walk)
    }

    func testBuildProviderMapsLifecycleAndExpiryInCoordinator() {
        let playbackController = makePlaybackController()
        let build = FakeEventProvider<BuildLifecycleProviderEvent>()
        let coordinator = makeCoordinator(
            playbackController: playbackController,
            build: build
        )

        coordinator.updateCPUState(for: .walk)
        build.emit(.received(LocalBuildEvent(phase: .succeeded)))
        XCTAssertEqual(playbackController.requestedState, .sprint)

        build.emit(.expired)
        XCTAssertEqual(playbackController.requestedState, .walk)
    }

    func testBuildCancellationClearsOnlyBuildTrigger() {
        let playbackController = makePlaybackController()
        let build = FakeEventProvider<BuildLifecycleProviderEvent>()
        let coordinator = makeCoordinator(
            playbackController: playbackController,
            build: build
        )

        coordinator.updateCPUState(for: .walk)
        build.emit(.received(LocalBuildEvent(phase: .started)))
        XCTAssertEqual(playbackController.requestedState, .dash)

        build.emit(.received(LocalBuildEvent(phase: .cancelled)))
        XCTAssertEqual(playbackController.requestedState, .walk)
    }

    func testLocalProviderExpiryClearsOnlyAddressedChannel() throws {
        let playbackController = makePlaybackController()
        let local = FakeEventProvider<LocalCharacterStateProviderEvent>()
        let coordinator = makeCoordinator(
            playbackController: playbackController,
            local: local
        )
        let first = try LocalCharacterStateEvent.set(
            state: .dash,
            channel: "first"
        )
        let second = try LocalCharacterStateEvent.set(
            state: .sprint,
            channel: "second"
        )

        local.emit(.received(first))
        local.emit(.received(second))
        XCTAssertEqual(playbackController.requestedState, .sprint)

        local.emit(.expired(channel: "second"))
        XCTAssertEqual(playbackController.requestedState, .dash)

        local.emit(.expired(channel: "first"))
        XCTAssertEqual(playbackController.requestedState, .run)
    }

    func testLocalProviderClearUsesEventChannel() throws {
        let playbackController = makePlaybackController()
        let local = FakeEventProvider<LocalCharacterStateProviderEvent>()
        let coordinator = makeCoordinator(
            playbackController: playbackController,
            local: local
        )
        let first = try LocalCharacterStateEvent.set(
            state: .dash,
            channel: "first"
        )
        let second = try LocalCharacterStateEvent.set(
            state: .sprint,
            channel: "second"
        )

        local.emit(.received(first))
        local.emit(.received(second))
        local.emit(.received(try LocalCharacterStateEvent.clear(channel: "second")))

        XCTAssertEqual(playbackController.requestedState, .dash)
    }

    func testManualOverrideRemainsAuthoritativeWhileProvidersEmit() throws {
        let playbackController = makePlaybackController()
        let build = FakeEventProvider<BuildLifecycleProviderEvent>()
        let local = FakeEventProvider<LocalCharacterStateProviderEvent>()
        let coordinator = makeCoordinator(
            playbackController: playbackController,
            build: build,
            local: local
        )

        coordinator.setManualOverride(.idle)
        build.emit(.received(LocalBuildEvent(phase: .succeeded)))
        local.emit(
            .received(
                try LocalCharacterStateEvent.set(
                    state: .sprint,
                    channel: "automation"
                )
            )
        )

        XCTAssertEqual(playbackController.requestedState, .idle)

        coordinator.setManualOverride(nil)
        XCTAssertEqual(playbackController.requestedState, .sprint)
    }

    func testClearingCPUStateRestoresFallbackState() {
        let playbackController = makePlaybackController()
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.updateCPUState(for: .sprint)
        XCTAssertEqual(playbackController.requestedState, .sprint)

        coordinator.clearCPUState()

        XCTAssertEqual(playbackController.requestedState, .run)
    }

    func testClearingCPUStatePreservesHigherPriorityManualOverride() {
        let playbackController = makePlaybackController()
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.updateCPUState(for: .sprint)
        coordinator.setManualOverride(.idle)
        coordinator.clearCPUState()

        XCTAssertEqual(playbackController.requestedState, .idle)
    }

    func testProductivityStateUsesEventPriority() {
        let playbackController = makePlaybackController()
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.updateCPUState(for: .walk)
        coordinator.setProductivityState(.dash)

        XCTAssertEqual(playbackController.requestedState, .dash)
    }

    func testClearingProductivityStateRestoresLowerPriorityState() {
        let playbackController = makePlaybackController()
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.updateCPUState(for: .walk)
        coordinator.setProductivityState(.dash)
        coordinator.setProductivityState(nil)

        XCTAssertEqual(playbackController.requestedState, .walk)
    }

    func testManualOverrideStillWinsAfterProductivityUpdates() {
        let playbackController = makePlaybackController()
        let coordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )

        coordinator.setManualOverride(.idle)
        coordinator.setProductivityState(.sprint)

        XCTAssertEqual(playbackController.requestedState, .idle)
    }

    private func makeCoordinator(
        playbackController: CharacterPlaybackController,
        battery: FakeMetricProvider<BatteryWarningLevel> = .init(),
        memory: FakeEventProvider<MemoryPressureLevel> = .init(),
        build: FakeEventProvider<BuildLifecycleProviderEvent> = .init(),
        local: FakeEventProvider<LocalCharacterStateProviderEvent> = .init()
    ) -> CharacterStateCoordinator {
        CharacterStateCoordinator(
            playbackController: playbackController,
            batteryWarningProvider: battery,
            memoryPressureProvider: memory,
            buildEventProvider: build,
            localEventProvider: local
        )
    }

    private func makePlaybackController() -> CharacterPlaybackController {
        CharacterPlaybackController(
            animationController: AnimationController()
        )
    }
}

@MainActor
private final class FakeMetricProvider<Value>: MetricProvider {
    var onUpdate: ((Value) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func emit(_ value: Value) {
        onUpdate?(value)
    }
}

@MainActor
private final class FakeEventProvider<Value>: EventProvider {
    var onEvent: ((Value) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func emit(_ value: Value) {
        onEvent?(value)
    }
}
