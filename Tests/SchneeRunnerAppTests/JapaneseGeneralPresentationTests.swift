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

    func testJapaneseDesktopCharacterMenuLocalizesActionsAndSpeedPresets() throws {
        let controller = StatusMenuController(
            localization: AppLocalization(localeIdentifier: "ja")
        )
        let desktopMenu = try XCTUnwrap(
            controller.menu.items.first(where: { $0.title == "デスクトップキャラクター" })?.submenu
        )

        XCTAssertNotNil(desktopMenu.item(withTitle: "デスクトップに表示"))
        XCTAssertNotNil(desktopMenu.item(withTitle: "自動で移動"))
        XCTAssertNotNil(desktopMenu.item(withTitle: "クリックを透過"))
        XCTAssertNotNil(desktopMenu.item(withTitle: "位置とサイズをリセット"))

        let speedMenu = try XCTUnwrap(
            desktopMenu.item(withTitle: "移動速度")?.submenu
        )
        XCTAssertNotNil(speedMenu.item(withTitle: "遅い"))
        XCTAssertNotNil(speedMenu.item(withTitle: "標準"))
        XCTAssertNotNil(speedMenu.item(withTitle: "速い"))
    }

    func testJapaneseLaunchAtLoginLocalizesApprovalAndUnavailableStates() {
        let localization = AppLocalization(localeIdentifier: "ja")

        let approvalController = LaunchAtLoginMenuController(
            service: JapaneseLaunchAtLoginService(status: .requiresApproval),
            isAvailable: true,
            localization: localization
        )
        XCTAssertEqual(
            approvalController.item.title,
            "ログイン時に起動（承認が必要）"
        )

        let unavailableController = LaunchAtLoginMenuController(
            service: JapaneseLaunchAtLoginService(status: .notRegistered),
            isAvailable: false,
            localization: localization
        )
        XCTAssertEqual(
            unavailableController.item.title,
            "ログイン時に起動（利用不可）"
        )
    }
}

@MainActor
private final class JapaneseLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginServiceStatus {
        storedStatus
    }

    private let storedStatus: LaunchAtLoginServiceStatus

    init(status: LaunchAtLoginServiceStatus) {
        storedStatus = status
    }

    func register() throws {}
    func unregister() throws {}
    func openSystemSettingsLoginItems() {}
}
