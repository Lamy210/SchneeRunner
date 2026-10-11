import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class JapaneseProductivityPresentationTests: XCTestCase {
    private let localization = AppLocalization(localeIdentifier: "ja")
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testJapaneseTimerMenuLocalizesChromeAndPreservesUserTitle() throws {
        let controller = TimerMenuController(localization: localization)
        let menu = try XCTUnwrap(controller.rootItem.submenu)

        XCTAssertEqual(controller.rootItem.title, "タイマー")
        XCTAssertNotNil(menu.item(withTitle: "新しいタイマー"))
        XCTAssertNotNil(menu.item(withTitle: "タイマーを管理…"))
        XCTAssertNotNil(menu.item(withTitle: "実行中のタイマーはありません"))

        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Deep Work",
            duration: 600,
            startedAt: now
        ).pausing(at: now.addingTimeInterval(120))
        controller.setTimers([timer], now: now.addingTimeInterval(300))

        let row = try XCTUnwrap(menu.items.first {
            $0.representedObject as? String == timer.id.uuidString
        })
        XCTAssertEqual(row.title, "Deep Work · 一時停止 08:00")
        XCTAssertNotNil(row.submenu?.item(withTitle: "再開"))
        XCTAssertNotNil(row.submenu?.item(withTitle: "キャンセル"))
    }

    func testJapanesePomodoroAndReminderMenusLocalizeChrome() throws {
        let pomodoro = PomodoroMenuController(localization: localization)
        let pomodoroMenu = try XCTUnwrap(pomodoro.rootItem.submenu)
        XCTAssertEqual(pomodoro.rootItem.title, "ポモドーロ")
        XCTAssertNotNil(pomodoroMenu.item(withTitle: "ポモドーロを開始"))
        XCTAssertNotNil(pomodoroMenu.item(withTitle: "設定…"))

        let reminder = ReminderMenuController(localization: localization)
        let reminderMenu = try XCTUnwrap(reminder.rootItem.submenu)
        XCTAssertEqual(reminder.rootItem.title, "リマインダー")
        XCTAssertNotNil(reminderMenu.item(withTitle: "今後のリマインダーはありません"))
        XCTAssertNotNil(reminderMenu.item(withTitle: "新しいリマインダー…"))
        XCTAssertNotNil(reminderMenu.item(withTitle: "リマインダーを管理…"))
    }

    func testJapaneseStatusMenuUsesLocalizedProductivityItems() {
        let controller = StatusMenuController(localization: localization)

        XCTAssertNotNil(controller.menu.item(withTitle: "タイマー"))
        XCTAssertNotNil(controller.menu.item(withTitle: "ポモドーロ"))
        XCTAssertNotNil(controller.menu.item(withTitle: "リマインダー"))
        XCTAssertNotNil(controller.menu.item(withTitle: "生産性通知: 無効"))
        XCTAssertNotNil(controller.menu.item(withTitle: "生産性キャラクター連動"))
    }
}
