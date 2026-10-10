import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class UnsignedRuntimeParityTests: XCTestCase {
    func testUnsignedRuntimeKeepsProductivityFlowsUsableWithoutSystemNotifications() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let suiteName = "UnsignedRuntimeParityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let menuController = StatusMenuController()
        let presenter = RecordingUnsignedRuntimeFallbackPresenter()
        let scheduler = ProductivityNotificationScheduler(
            center: DisabledUnsignedRuntimeNotificationCenter()
        )
        let stateStore = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )

        let timerController = TimerApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            fileManager: .default,
            notificationScheduler: scheduler,
            fallbackPresenter: presenter
        )
        let pomodoroController = PomodoroApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            fileManager: .default,
            defaults: defaults,
            refreshInterval: 3600,
            notificationScheduler: scheduler,
            fallbackPresenter: presenter
        )
        let reminderController = ReminderApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            fileManager: .default,
            notificationScheduler: scheduler,
            calendar: utcCalendar(),
            fallbackPresenter: presenter,
            fallbackDeliveryDefaults: defaults,
            fallbackRefreshInterval: 0.01
        )

        timerController.start()
        pomodoroController.start()
        reminderController.start()
        defer {
            timerController.stop()
            pomodoroController.stop()
            reminderController.stop()
        }

        menuController.onStartTimerPreset?(60)
        try await waitUntil {
            try stateStore.load().timers.count == 1
        }
        XCTAssertEqual(try stateStore.load().timers.first?.state, .running)

        let configuration = try PomodoroConfiguration(focusDuration: 60)
        menuController.onStartPomodoro?(configuration)
        try await waitUntil {
            try stateStore.load().pomodoro != nil
        }
        XCTAssertEqual(try stateStore.load().pomodoro?.state, .running)

        let reminderNow = Date()
        let request = ReminderEditRequest(
            title: "Stretch",
            body: "Stand up",
            enabled: true,
            schedule: .once(reminderNow.addingTimeInterval(0.1))
        )
        _ = try await reminderController.createReminder(
            request,
            now: reminderNow
        )

        try await waitUntil(timeout: 2) {
            presenter.events.contains(
                .reminderDue(title: "Stretch", body: "Stand up")
            )
        }

        let snapshot = try stateStore.load()
        XCTAssertEqual(snapshot.timers.count, 1)
        XCTAssertNotNil(snapshot.pomodoro)
        XCTAssertEqual(snapshot.reminders.map(\.title), ["Stretch"])
    }

    func testMissingBuiltInResourcesDoNotPreventMenuControllerStartup() {
        let capabilities = RuntimeCapabilities(
            bundleIdentifier: nil,
            bundleURL: URL(fileURLWithPath: "/tmp/SchneeRunner"),
            resourceURL: nil,
            systemNotificationsEnabled: false
        )

        XCTAssertFalse(capabilities.bundledResourcesAvailable)

        let menuController = StatusMenuController()
        XCTAssertFalse(menuController.menu.items.isEmpty)
        XCTAssertNotNil(menuController.menu.item(withTitle: "Timers"))
        XCTAssertNotNil(menuController.menu.item(withTitle: "Pomodoro"))
        XCTAssertNotNil(menuController.menu.item(withTitle: "Reminders"))
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

    private func utcCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        return calendar
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () throws -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if try condition() {
                return
            }
            try await Task<Never, Never>.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("condition was not satisfied before timeout")
    }
}

@MainActor
private final class RecordingUnsignedRuntimeFallbackPresenter: ProductivityFallbackPresenting {
    private(set) var events: [ProductivityFallbackEvent] = []

    func present(_ event: ProductivityFallbackEvent) {
        events.append(event)
    }
}

@MainActor
private final class DisabledUnsignedRuntimeNotificationCenter: ProductivityNotificationCenterClient {
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
        XCTFail("unsigned-runtime fixture must not schedule system notifications")
    }

    func removePending(identifiers _: Set<String>) {}
}
