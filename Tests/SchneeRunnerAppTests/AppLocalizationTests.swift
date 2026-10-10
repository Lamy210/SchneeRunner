@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

final class AppLocalizationTests: XCTestCase {
    func testEnglishAndJapaneseRepresentativeStrings() {
        let english = AppLocalization(localeIdentifier: "en")
        let japanese = AppLocalization(localeIdentifier: "ja")

        XCTAssertEqual(english.string("menu.timers"), "Timers")
        XCTAssertEqual(japanese.string("menu.timers"), "タイマー")
        XCTAssertEqual(english.string("timer.new"), "New Timer")
        XCTAssertEqual(japanese.string("timer.new"), "新しいタイマー")
        XCTAssertEqual(english.string("action.pause"), "Pause")
        XCTAssertEqual(japanese.string("action.pause"), "一時停止")
        XCTAssertEqual(english.string("pomodoro.focus"), "Focus")
        XCTAssertEqual(japanese.string("pomodoro.focus"), "集中")
        XCTAssertEqual(english.string("reminder.root"), "Reminders")
        XCTAssertEqual(japanese.string("reminder.root"), "リマインダー")
        XCTAssertEqual(english.string("launchAtLogin.title"), "Launch at Login")
        XCTAssertEqual(japanese.string("launchAtLogin.title"), "ログイン時に起動")
    }

    func testMissingJapaneseKeyFallsBackToEnglish() {
        let japanese = AppLocalization(localeIdentifier: "ja")

        XCTAssertEqual(
            japanese.string("localization.englishFallbackProbe"),
            "English fallback"
        )
    }

    func testCharacterStatePresentationDoesNotChangeRawValue() {
        let english = AppLocalization(localeIdentifier: "en")
        let japanese = AppLocalization(localeIdentifier: "ja")

        XCTAssertEqual(CharacterState.idle.rawValue, "idle")
        XCTAssertEqual(english.characterState(.idle), "Idle")
        XCTAssertEqual(japanese.characterState(.idle), "待機")
        XCTAssertEqual(japanese.characterState(.walk), "歩行")
        XCTAssertEqual(japanese.characterState(.run), "走行")
        XCTAssertEqual(japanese.characterState(.dash), "ダッシュ")
        XCTAssertEqual(japanese.characterState(.sprint), "全力疾走")
    }
}
