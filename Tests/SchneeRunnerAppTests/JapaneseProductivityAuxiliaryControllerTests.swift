import AppKit
import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class JapaneseAuxiliaryControllerTests: XCTestCase {
    private let localization = AppLocalization(localeIdentifier: "ja")
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testProductivityControllersAcceptOneLocalizationContext() {
        let menu = StatusMenuController(localization: localization)
        let management = ProductivityManagementWindowController(
            localization: localization
        )
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        _ = TimerApplicationController(
            menuController: menu,
            managementWindow: management,
            baseDirectory: baseDirectory,
            localization: localization
        )
        _ = PomodoroApplicationController(
            menuController: menu,
            managementWindow: management,
            baseDirectory: baseDirectory,
            localization: localization
        )
        _ = ReminderApplicationController(
            menuController: menu,
            baseDirectory: baseDirectory,
            managementWindow: management,
            localization: localization
        )
    }

    func testJapaneseReminderManagementRowLocalizesActions() throws {
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: "Standup",
            body: nil,
            enabled: true,
            schedule: .once(now.addingTimeInterval(600)),
            createdAt: now,
            updatedAt: now
        )
        let row = ReminderManagementRowView(
            reminder: reminder,
            localization: localization
        )

        let buttonTitles = row.arrangedSubviews
            .compactMap { $0 as? NSButton }
            .map(\.title)
        XCTAssertTrue(buttonTitles.contains("有効"))
        XCTAssertTrue(buttonTitles.contains("編集"))
        XCTAssertTrue(buttonTitles.contains("削除"))

        let snooze = try XCTUnwrap(
            row.arrangedSubviews.compactMap { $0 as? NSPopUpButton }.first
        )
        XCTAssertEqual(snooze.item(at: 0)?.title, "スヌーズ…")
        XCTAssertEqual(snooze.item(at: 1)?.title, "5分")
    }
}
