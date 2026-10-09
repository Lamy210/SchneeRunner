import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityFallbackApplicationControllerTests: XCTestCase {
    func testOverdueTimerUsesFallbackWhenSystemNotificationsAreDisabled() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let now = Date()
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Tea",
            duration: 1,
            startedAt: now.addingTimeInterval(-10)
        )
        let store = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )
        try store.save(ProductivitySnapshot(timers: [timer]))

        let presenter = RecordingApplicationFallbackPresenter()
        let scheduler = ProductivityNotificationScheduler(
            center: DisabledApplicationNotificationCenter()
        )
        let controller = TimerApplicationController(
            menuController: StatusMenuController(),
            baseDirectory: baseDirectory,
            fileManager: .default,
            notificationScheduler: scheduler,
            fallbackPresenter: presenter
        )

        controller.start()
        await waitForFallbackEvent(in: presenter)
        controller.stop()

        XCTAssertEqual(
            presenter.events,
            [.timerCompleted(title: "Tea")]
        )
    }

    func testOverduePomodoroUsesFallbackWhenSystemNotificationsAreDisabled() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let configuration = try PomodoroConfiguration(focusDuration: 1)
        let session = try PomodoroSession(
            id: UUID(),
            configuration: configuration,
            startedAt: Date().addingTimeInterval(-10)
        )
        let store = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )
        try store.save(ProductivitySnapshot(pomodoro: session))

        let suiteName = "ProductivityFallbackApplicationControllerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)

        let presenter = RecordingApplicationFallbackPresenter()
        let scheduler = ProductivityNotificationScheduler(
            center: DisabledApplicationNotificationCenter()
        )
        let controller = PomodoroApplicationController(
            menuController: StatusMenuController(),
            baseDirectory: baseDirectory,
            fileManager: .default,
            defaults: defaults,
            refreshInterval: 3600,
            notificationScheduler: scheduler,
            fallbackPresenter: presenter
        )

        controller.start()
        await waitForFallbackEvent(in: presenter)
        controller.stop()

        XCTAssertEqual(
            presenter.events,
            [.pomodoroPhaseCompleted(phase: .focus)]
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    private func waitForFallbackEvent(
        in presenter: RecordingApplicationFallbackPresenter
    ) async {
        for _ in 0 ..< 1000 {
            if !presenter.events.isEmpty {
                return
            }
            await Task.yield()
        }
    }
}

@MainActor
private final class RecordingApplicationFallbackPresenter: ProductivityFallbackPresenting {
    private(set) var events: [ProductivityFallbackEvent] = []

    func present(_ event: ProductivityFallbackEvent) {
        events.append(event)
    }
}

@MainActor
private final class DisabledApplicationNotificationCenter: ProductivityNotificationCenterClient {
    func currentAuthorizationState() async -> NotificationAuthorizationState {
        .denied
    }

    func requestAuthorization() async throws -> Bool {
        false
    }

    func pendingIdentifiers() async -> Set<String> {
        []
    }

    func add(_: ProductivityNotificationRequest) async throws {
        XCTFail("disabled notification center must not schedule requests")
    }

    func removePending(identifiers _: Set<String>) {}
}
