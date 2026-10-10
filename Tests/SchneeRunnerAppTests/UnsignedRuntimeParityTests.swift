import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class UnsignedRuntimeParityTests: XCTestCase {
    func testUnsignedRuntimeKeepsProductivityFlowsUsableWithoutSystemNotifications() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.start()
        defer { fixture.stop() }

        fixture.menuController.onStartTimerPreset?(60)
        try await waitUntil {
            try fixture.stateStore.load().timers.count == 1
        }
        XCTAssertEqual(
            try fixture.stateStore.load().timers.first?.state,
            .running
        )

        let configuration = try PomodoroConfiguration(focusDuration: 60)
        fixture.menuController.onStartPomodoro?(configuration)
        try await waitUntil {
            try fixture.stateStore.load().pomodoro != nil
        }
        XCTAssertEqual(
            try fixture.stateStore.load().pomodoro?.state,
            .running
        )

        try await createDueReminder(in: fixture)
        try await waitUntil(timeout: 2) {
            fixture.presenter.events.contains(
                .reminderDue(title: "Stretch", body: "Stand up")
            )
        }

        let snapshot = try fixture.stateStore.load()
        XCTAssertEqual(snapshot.timers.count, 1)
        XCTAssertNotNil(snapshot.pomodoro)
        XCTAssertEqual(snapshot.reminders.map(\.title), ["Stretch"])
    }

    func testMissingBuiltInResourcesDoNotPreventMenuControllerStartup() {
        let capabilities = RuntimeCapabilities.detect(
            bundleIdentifier: nil,
            bundleURL: URL(fileURLWithPath: "/tmp/SchneeRunner"),
            notificationsEnabled: false,
            resourceURL: nil
        )

        XCTAssertFalse(capabilities.bundledResourcesAvailable)

        let menuController = StatusMenuController()
        XCTAssertFalse(menuController.menu.items.isEmpty)
        XCTAssertNotNil(menuController.menu.item(withTitle: "Timers"))
        XCTAssertNotNil(menuController.menu.item(withTitle: "Pomodoro"))
        XCTAssertNotNil(menuController.menu.item(withTitle: "Reminders"))
    }

    private func createDueReminder(
        in fixture: UnsignedRuntimeFixture
    ) async throws {
        let now = Date()
        let request = ReminderEditRequest(
            title: "Stretch",
            body: "Stand up",
            enabled: true,
            schedule: .once(now.addingTimeInterval(0.1))
        )
        _ = try await fixture.reminderController.createReminder(
            request,
            now: now
        )
    }

    private func makeFixture() throws -> UnsignedRuntimeFixture {
        let baseDirectory = try makeTemporaryDirectory()
        let suiteName = "UnsignedRuntimeParityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return UnsignedRuntimeFixture(
            baseDirectory: baseDirectory,
            suiteName: suiteName,
            defaults: defaults,
            calendar: try utcCalendar()
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
private final class UnsignedRuntimeFixture {
    let baseDirectory: URL
    let suiteName: String
    let defaults: UserDefaults
    let menuController: StatusMenuController
    let presenter: RecordingUnsignedRuntimeFallbackPresenter
    let stateStore: ProductivityStateStore
    let reminderController: ReminderApplicationController

    private let timerController: TimerApplicationController
    private let pomodoroController: PomodoroApplicationController

    init(
        baseDirectory: URL,
        suiteName: String,
        defaults: UserDefaults,
        calendar: Calendar
    ) {
        self.baseDirectory = baseDirectory
        self.suiteName = suiteName
        self.defaults = defaults

        let menuController = StatusMenuController()
        let presenter = RecordingUnsignedRuntimeFallbackPresenter()
        let scheduler = ProductivityNotificationScheduler(
            center: DisabledUnsignedRuntimeNotificationCenter()
        )
        let stateStore = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )
        self.menuController = menuController
        self.presenter = presenter
        self.stateStore = stateStore

        timerController = TimerApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            notificationScheduler: scheduler,
            fallbackPresenter: presenter
        )
        pomodoroController = PomodoroApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            defaults: defaults,
            refreshInterval: 3600,
            notificationScheduler: scheduler,
            fallbackPresenter: presenter
        )
        reminderController = ReminderApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            notificationScheduler: scheduler,
            calendar: calendar,
            fallbackPresenter: presenter,
            fallbackDeliveryDefaults: defaults,
            fallbackRefreshInterval: 0.01
        )
    }

    func start() {
        timerController.start()
        pomodoroController.start()
        reminderController.start()
    }

    func stop() {
        timerController.stop()
        pomodoroController.stop()
        reminderController.stop()
    }

    func cleanup() {
        stop()
        try? FileManager.default.removeItem(at: baseDirectory)
        defaults.removePersistentDomain(forName: suiteName)
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
