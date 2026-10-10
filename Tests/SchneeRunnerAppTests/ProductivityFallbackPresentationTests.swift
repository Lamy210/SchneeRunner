@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityFallbackPresentationTests: XCTestCase {
    func testEventsPreserveDomainPayloads() {
        XCTAssertEqual(
            ProductivityFallbackEvent.timerCompleted(title: "Tea"),
            .timerCompleted(title: "Tea")
        )
        XCTAssertEqual(
            ProductivityFallbackEvent.pomodoroPhaseCompleted(phase: .focus),
            .pomodoroPhaseCompleted(phase: .focus)
        )
        XCTAssertEqual(
            ProductivityFallbackEvent.reminderDue(title: "Stand", body: "Stretch"),
            .reminderDue(title: "Stand", body: "Stretch")
        )
    }

    func testPresenterAbstractionCanRecordMultipleFallbackEvents() {
        let presenter = RecordingFallbackPresenter()

        presenter.present(.timerCompleted(title: "Tea"))
        presenter.present(.pomodoroPhaseCompleted(phase: .shortBreak))
        presenter.present(.reminderDue(title: "Stand", body: nil))

        XCTAssertEqual(
            presenter.events,
            [
                .timerCompleted(title: "Tea"),
                .pomodoroPhaseCompleted(phase: .shortBreak),
                .reminderDue(title: "Stand", body: nil)
            ]
        )
    }
}

@MainActor
private final class RecordingFallbackPresenter: ProductivityFallbackPresenting {
    private(set) var events: [ProductivityFallbackEvent] = []

    func present(_ event: ProductivityFallbackEvent) {
        events.append(event)
    }
}
