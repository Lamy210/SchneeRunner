import AppKit
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class JapaneseGeneralPresentationTests: XCTestCase {
    func testStatusMenuLocalizesGeneralCharacterAndDesktopChrome() {
        let controller = StatusMenuController(
            localization: AppLocalization(localeIdentifier: "ja")
        )

        let titles = controller.menu.items.map(\.title)

        XCTAssertTrue(titles.contains("最近のキャラクター"))
        XCTAssertTrue(titles.contains("キャラクター状態"))
        XCTAssertTrue(titles.contains("デスクトップキャラクター"))
        XCTAssertTrue(titles.contains(where: { $0.contains("ログイン時に起動") }))
        XCTAssertTrue(titles.contains("SchneeRunnerを終了"))
    }

    func testJapaneseRecentCharacterEmptyAndUnavailableStates() {
        let controller = StatusMenuController(
            localization: AppLocalization(localeIdentifier: "ja")
        )

        controller.setRecentCharacters([])
        var recentMenu = try? XCTUnwrap(
            controller.menu.items.first(where: { $0.title == "最近のキャラクター" })?.submenu
        )
        XCTAssertEqual(recentMenu?.items.first?.title, "保存済みキャラクターはありません")

        controller.setRecentCharactersUnavailable()
        recentMenu = controller.menu.items.first(where: { $0.title == "最近のキャラクター" })?.submenu
        XCTAssertEqual(recentMenu?.items.first?.title, "キャラクターライブラリを利用できません")
    }

    func testJapaneseCharacterStateMenuUsesLocalizedPresentationWithoutChangingRawValues() throws {
        let controller = StatusMenuController(
            localization: AppLocalization(localeIdentifier: "ja")
        )
        let stateMenu = try XCTUnwrap(
            controller.menu.items.first(where: { $0.title == "キャラクター状態" })?.submenu
        )

        XCTAssertEqual(stateMenu.items.first?.title, "自動")
        XCTAssertTrue(stateMenu.items.contains(where: { $0.title == "待機" }))
        XCTAssertTrue(stateMenu.items.contains(where: { $0.title == "歩行" }))
        XCTAssertTrue(stateMenu.items.contains(where: { $0.title == "走行" }))
        XCTAssertTrue(stateMenu.items.contains(where: { $0.title == "ダッシュ" }))
        XCTAssertTrue(stateMenu.items.contains(where: { $0.title == "全力疾走" }))

        XCTAssertEqual(CharacterState.idle.rawValue, "idle")
        XCTAssertEqual(CharacterState.run.rawValue, "run")
    }
}
