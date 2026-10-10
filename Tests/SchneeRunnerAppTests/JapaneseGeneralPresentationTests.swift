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

    func testJapaneseStatusMenuLocalizesImportExportAndPlaybackChrome() {
        let controller = StatusMenuController(
            localization: AppLocalization(localeIdentifier: "ja")
        )
        let titles = controller.menu.items.map(\.title)

        XCTAssertTrue(titles.contains("単一画像を読み込む…"))
        XCTAssertTrue(titles.contains("4x2スプライトシートを読み込む…"))
        XCTAssertTrue(titles.contains("PNGシーケンスを読み込む…"))
        XCTAssertTrue(titles.contains("GIFを読み込む…"))
        XCTAssertTrue(titles.contains("APNGを読み込む…"))
        XCTAssertTrue(titles.contains("WebPを読み込む…"))
        XCTAssertTrue(titles.contains("キャラクターパックを読み込む…"))
        XCTAssertTrue(titles.contains("キャラクターパックを作成…"))
        XCTAssertTrue(titles.contains("現在のキャラクターパックを書き出す…"))
        XCTAssertTrue(titles.contains("CPU適応速度"))
        XCTAssertTrue(titles.contains("再生速度"))
    }

    func testJapaneseRecentCharacterEmptyAndUnavailableStates() throws {
        let controller = StatusMenuController(
            localization: AppLocalization(localeIdentifier: "ja")
        )

        controller.setRecentCharacters([])
        let recentMenu = try XCTUnwrap(
            controller.menu.items.first(where: { $0.title == "最近のキャラクター" })?.submenu
        )
        XCTAssertEqual(recentMenu.items.first?.title, "保存済みキャラクターはありません")

        controller.setRecentCharactersUnavailable()
        let unavailableMenu = try XCTUnwrap(
            controller.menu.items.first(where: { $0.title == "最近のキャラクター" })?.submenu
        )
        XCTAssertEqual(unavailableMenu.items.first?.title, "キャラクターライブラリを利用できません")
    }

    func testJapaneseRecentCharacterKindIsLocalizedWithoutChangingStoredProtocolValue() throws {
        let controller = StatusMenuController(
            localization: AppLocalization(localeIdentifier: "ja")
        )
        let assetID = try XCTUnwrap(
            UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        )
        let asset = StoredCharacterAsset(
            id: assetID,
            displayName: "Snow",
            kind: .characterPack,
            createdAt: Date(timeIntervalSince1970: 0)
        )

        controller.setRecentCharacters([asset])

        let recentMenu = try XCTUnwrap(
            controller.menu.items.first(where: { $0.title == "最近のキャラクター" })?.submenu
        )
        XCTAssertEqual(recentMenu.items.first?.title, "Snow · キャラクターパック")
        XCTAssertEqual(CharacterAssetKind.characterPack.rawValue, "characterPack")
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

    func testJapaneseCharacterPackAndImportVocabulary() {
        let localization = AppLocalization(localeIdentifier: "ja")

        XCTAssertEqual(localization.string("import.prompt.load"), "読み込む")
        XCTAssertEqual(localization.string("import.panel.singleImage"), "画像を選択")
        XCTAssertEqual(localization.string("import.panel.pngSequence"), "PNGシーケンスのフレームを選択")
        XCTAssertEqual(localization.string("characterPack.builder.title"), "キャラクターパックを作成")
        XCTAssertEqual(localization.string("characterPack.builder.defaultState"), "デフォルト状態")
        XCTAssertEqual(localization.string("characterPack.builder.noSource"), "ソース未選択")
        XCTAssertEqual(localization.string("characterPack.builder.choose"), "選択…")
        XCTAssertEqual(localization.string("characterPack.builder.clear"), "クリア")
        XCTAssertEqual(localization.string("characterPack.builder.incomplete"), "キャラクターパックが未完成です")
        XCTAssertEqual(CharacterPackClipKind.spriteSheet4x2.rawValue, "spriteSheet4x2")
        XCTAssertEqual(CharacterPackClipKind.webP.rawValue, "webP")
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
