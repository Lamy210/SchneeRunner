import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class JapaneseDeliveryPresentationTests: XCTestCase {
    private let localization = AppLocalization(localeIdentifier: "ja")
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testJapaneseTimerNotificationLocalizesChromeAndPreservesTitle() async throws {
        let center = JapaneseRecordingNotificationCenter()
        center.authorizationState = .authorized
        let scheduler = ProductivityNotificationScheduler(
            center: center,
            localization: localization
        )
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Deep Work",
            duration: 300,
            startedAt: now
        )

        _ = try await scheduler.scheduleTimer(timer, now: now)

        let request = try XCTUnwrap(center.addedRequests.last)
        XCTAssertEqual(request.title, "Deep Work")
        XCTAssertEqual(request.body, "タイマーが終了しました")
    }

    func testJapanesePomodoroNotificationLocalizesCompletionCopy() async throws {
        let center = JapaneseRecordingNotificationCenter()
        center.authorizationState = .authorized
        let scheduler = ProductivityNotificationScheduler(
            center: center,
            localization: localization
        )
        let session = try PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: now
        )

        _ = try await scheduler.schedulePomodoro(session, now: now)

        let request = try XCTUnwrap(center.addedRequests.last)
        XCTAssertEqual(request.title, "ポモドーロ")
        XCTAssertEqual(request.body, "集中が終了しました")
    }

    func testJapaneseReminderNotificationUsesLocalizedDefaultBody() async throws {
        let center = JapaneseRecordingNotificationCenter()
        center.authorizationState = .authorized
        let scheduler = ProductivityNotificationScheduler(
            center: center,
            localization: localization
        )
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Standup",
            body: nil,
            enabled: true,
            schedule: .once(now.addingTimeInterval(300)),
            createdAt: now,
            updatedAt: now
        )

        _ = try await scheduler.reconcileReminders(
            [reminder],
            snoozes: [],
            now: now,
            calendar: .current
        )

        let request = try XCTUnwrap(center.addedRequests.last)
        XCTAssertEqual(request.title, "Standup")
        XCTAssertEqual(request.body, "リマインダー")
    }

    func testJapaneseFallbackPresenterLocalizesChromeAndPreservesUserContent() {
        let presenter = AppKitProductivityFallbackPresenter(
            localization: localization
        )

        let timer = presenter.presentationContent(
            for: .timerCompleted(title: "Deep Work")
        )
        XCTAssertEqual(timer.title, "タイマーが終了しました")
        XCTAssertEqual(timer.message, "Deep Work")

        let pomodoro = presenter.presentationContent(
            for: .pomodoroPhaseCompleted(phase: .shortBreak)
        )
        XCTAssertEqual(pomodoro.title, "ポモドーロ")
        XCTAssertEqual(pomodoro.message, "短い休憩が終了しました")

        let reminder = presenter.presentationContent(
            for: .reminderDue(title: "Standup", body: "Stretch")
        )
        XCTAssertEqual(reminder.title, "リマインダー")
        XCTAssertEqual(reminder.message, "Standup\nStretch")
    }
}

@MainActor
private final class JapaneseRecordingNotificationCenter: ProductivityNotificationCenterClient {
    var authorizationState: NotificationAuthorizationState = .notDetermined
    var addedRequests: [ProductivityNotificationRequest] = []
    private var pending: Set<String> = []

    func currentAuthorizationState() async -> NotificationAuthorizationState {
        authorizationState
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func pendingIdentifiers() async -> Set<String> {
        pending
    }

    func add(_ request: ProductivityNotificationRequest) async throws {
        addedRequests.append(request)
        pending.insert(request.identifier)
    }

    func removePending(identifiers: Set<String>) {
        pending.subtract(identifiers)
    }
}
