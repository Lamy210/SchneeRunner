import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityCharacterCoordinatorTests: XCTestCase {
    func testRunningCountdownPublishesWalk() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1000)
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Build",
            duration: 5 * 60,
            startedAt: now
        )

        fixture.coordinator.updateTimers([timer], now: now)

        XCTAssertEqual(fixture.playbackController.requestedState, .walk)
    }

    func testFinalMinutePublishesSprint() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1000)
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Build",
            duration: 45,
            startedAt: now
        )

        fixture.coordinator.updateTimers([timer], now: now)

        XCTAssertEqual(fixture.playbackController.requestedState, .sprint)
    }

    func testPomodoroFocusWinsOrdinaryCountdown() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1000)
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Build",
            duration: 5 * 60,
            startedAt: now
        )
        let session = try PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: now
        )

        fixture.coordinator.updateTimers([timer], now: now)
        fixture.coordinator.updatePomodoro(session, now: now)

        XCTAssertEqual(fixture.playbackController.requestedState, .dash)
    }

    func testTimerCompletionTransitionPublishesTransientSprint() throws {
        let fixture = try makeFixture(transientReactionDuration: 2)
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1000)
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Build",
            duration: 5 * 60,
            startedAt: now
        )
        fixture.coordinator.updateTimers([timer], now: now)
        let completedAt = now.addingTimeInterval(301)
        let completed = timer.reconciling(at: completedAt)

        fixture.coordinator.updateTimers([completed], now: completedAt)
        XCTAssertEqual(fixture.playbackController.requestedState, .sprint)

        fixture.coordinator.refresh(now: completedAt.addingTimeInterval(3))
        XCTAssertEqual(fixture.playbackController.requestedState, .run)
    }

    func testTimerCompletionTransientWinsFocusThenExpires() throws {
        let fixture = try makeFixture(transientReactionDuration: 2)
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1000)
        let session = try PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: now
        )
        fixture.coordinator.updatePomodoro(session, now: now)

        fixture.coordinator.recordTimerCompletion(at: now)
        XCTAssertEqual(fixture.playbackController.requestedState, .sprint)

        fixture.coordinator.refresh(now: now.addingTimeInterval(3))
        XCTAssertEqual(fixture.playbackController.requestedState, .dash)
    }

    func testReminderTransientWinsTimerCompletion() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1000)

        fixture.coordinator.recordTimerCompletion(at: now)
        fixture.coordinator.recordReminderFired(at: now)

        XCTAssertEqual(fixture.playbackController.requestedState, .idle)
    }

    func testReminderTransientExpiresWithoutExternalRefresh() throws {
        let fixture = try makeFixture(transientReactionDuration: 0.02)
        defer { fixture.cleanup() }

        fixture.coordinator.recordReminderFired()
        XCTAssertEqual(fixture.playbackController.requestedState, .idle)

        let deadline = Date().addingTimeInterval(0.25)
        while fixture.playbackController.requestedState == .idle, Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.01)
            )
        }

        XCTAssertEqual(fixture.playbackController.requestedState, .run)
    }

    func testDisablingReactionsClearsProductivityTriggerAndPersistsPreference() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1000)
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Build",
            duration: 5 * 60,
            startedAt: now
        )
        fixture.coordinator.updateTimers([timer], now: now)
        XCTAssertEqual(fixture.playbackController.requestedState, .walk)

        fixture.coordinator.setReactionsEnabled(false, now: now)

        XCTAssertFalse(fixture.reactionStore.isEnabled)
        XCTAssertEqual(fixture.playbackController.requestedState, .run)
    }
}

private extension ProductivityCharacterCoordinatorTests {
    struct Fixture {
        let playbackController: CharacterPlaybackController
        let coordinator: ProductivityCharacterStateCoordinator
        let reactionStore: ProductivityCharacterReactionStore
        let defaults: UserDefaults
        let suiteName: String

        func cleanup() {
            coordinator.stop()
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    func makeFixture(
        transientReactionDuration: TimeInterval = 3
    ) throws -> Fixture {
        let suiteName = "SchneeRunnerAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let reactionStore = ProductivityCharacterReactionStore(
            defaults: defaults,
            key: "productivity-reactions"
        )
        let playbackController = CharacterPlaybackController(
            animationController: AnimationController()
        )
        let characterStateCoordinator = CharacterStateCoordinator(
            playbackController: playbackController
        )
        let coordinator = ProductivityCharacterStateCoordinator(
            characterStateCoordinator: characterStateCoordinator,
            reactionStore: reactionStore,
            transientReactionDuration: transientReactionDuration
        )
        return Fixture(
            playbackController: playbackController,
            coordinator: coordinator,
            reactionStore: reactionStore,
            defaults: defaults,
            suiteName: suiteName
        )
    }
}
