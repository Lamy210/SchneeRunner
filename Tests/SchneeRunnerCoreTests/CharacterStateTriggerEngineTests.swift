@testable import SchneeRunnerCore
import XCTest

final class CharacterStateTriggerEngineTests: XCTestCase {
    func testUsesFallbackWhenNoTriggersExist() {
        let engine = CharacterStateTriggerEngine(
            fallbackState: .run
        )

        XCTAssertEqual(
            engine.resolution,
            CharacterStateTriggerResolution(
                state: .run,
                trigger: nil
            )
        )
        XCTAssertTrue(engine.resolution.isFallback)
    }

    func testHigherPriorityTriggerWins() {
        var engine = CharacterStateTriggerEngine()

        engine.set(
            CharacterStateTrigger(
                id: "cpu",
                state: .walk,
                priority: .metric
            )
        )
        engine.set(
            CharacterStateTrigger(
                id: "manual",
                state: .sprint,
                priority: .manual
            )
        )

        XCTAssertEqual(engine.resolution.state, .sprint)
        XCTAssertEqual(engine.resolution.trigger?.id, "manual")
    }

    func testSystemEventPrioritySitsBetweenMetricAndEvent() {
        var engine = CharacterStateTriggerEngine()

        engine.set(
            CharacterStateTrigger(
                id: "cpu",
                state: .walk,
                priority: .metric
            )
        )
        engine.set(
            CharacterStateTrigger(
                id: "memory-pressure",
                state: .sprint,
                priority: .systemEvent
            )
        )

        XCTAssertEqual(engine.resolution.state, .sprint)

        engine.set(
            CharacterStateTrigger(
                id: "local-event",
                state: .idle,
                priority: .event
            )
        )

        XCTAssertEqual(engine.resolution.state, .idle)
    }

    func testEventPrioritySitsBetweenMetricAndManual() {
        var engine = CharacterStateTriggerEngine()

        engine.set(
            CharacterStateTrigger(
                id: "cpu",
                state: .walk,
                priority: .metric
            )
        )
        engine.set(
            CharacterStateTrigger(
                id: "local-event",
                state: .dash,
                priority: .event
            )
        )

        XCTAssertEqual(engine.resolution.state, .dash)

        engine.set(
            CharacterStateTrigger(
                id: "manual",
                state: .idle,
                priority: .manual
            )
        )

        XCTAssertEqual(engine.resolution.state, .idle)
    }

    func testNewestTriggerWinsAtSamePriority() {
        var engine = CharacterStateTriggerEngine()

        engine.set(
            CharacterStateTrigger(
                id: "build-a",
                state: .walk,
                priority: .event
            )
        )
        engine.set(
            CharacterStateTrigger(
                id: "build-b",
                state: .dash,
                priority: .event
            )
        )

        XCTAssertEqual(engine.resolution.state, .dash)
        XCTAssertEqual(engine.resolution.trigger?.id, "build-b")
    }

    func testUpdatingExistingTriggerMakesItNewest() {
        var engine = CharacterStateTriggerEngine()

        engine.set(
            CharacterStateTrigger(
                id: "event-a",
                state: .walk,
                priority: .event
            )
        )
        engine.set(
            CharacterStateTrigger(
                id: "event-b",
                state: .dash,
                priority: .event
            )
        )
        engine.set(
            CharacterStateTrigger(
                id: "event-a",
                state: .idle,
                priority: .event
            )
        )

        XCTAssertEqual(engine.resolution.state, .idle)
        XCTAssertEqual(engine.resolution.trigger?.id, "event-a")
    }

    func testRemovingWinnerFallsBackToNextTrigger() {
        var engine = CharacterStateTriggerEngine()

        engine.set(
            CharacterStateTrigger(
                id: "cpu",
                state: .walk,
                priority: .metric
            )
        )
        engine.set(
            CharacterStateTrigger(
                id: "manual",
                state: .sprint,
                priority: .manual
            )
        )

        engine.remove(id: "manual")

        XCTAssertEqual(engine.resolution.state, .walk)
        XCTAssertEqual(engine.resolution.trigger?.id, "cpu")
    }

    func testRemoveAllReturnsToFallback() {
        var engine = CharacterStateTriggerEngine()

        engine.set(
            CharacterStateTrigger(
                id: "manual",
                state: .idle,
                priority: .manual
            )
        )
        engine.removeAll()

        XCTAssertEqual(engine.resolution.state, .run)
        XCTAssertTrue(engine.resolution.isFallback)
    }
}
