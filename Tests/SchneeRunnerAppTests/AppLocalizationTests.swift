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

    func testJapaneseProductivityAuxiliaryCopy() {
        let japanese = AppLocalization(localeIdentifier: "ja")

        XCTAssertEqual(japanese.string("timer.dialog.title"), "新しいタイマー")
        XCTAssertEqual(
            japanese.string("timer.dialog.prompt"),
            "分単位で時間を入力してください。"
        )
        XCTAssertEqual(japanese.string("timer.dialog.minutesPlaceholder"), "分")
        XCTAssertEqual(japanese.string("timer.defaultTitle"), "タイマー")
        XCTAssertEqual(
            japanese.string("timer.presetTitleFormat", arguments: 5),
            "5分タイマー"
        )
        XCTAssertEqual(japanese.string("action.start"), "開始")
        XCTAssertEqual(japanese.string("action.save"), "保存")

        XCTAssertEqual(japanese.string("pomodoro.settings.title"), "ポモドーロ設定")
        XCTAssertEqual(
            japanese.string("pomodoro.settings.description"),
            "集中時間と休憩時間を分単位で設定します。"
        )
        XCTAssertEqual(
            japanese.string("pomodoro.settings.autoStart"),
            "次のフェーズを自動的に開始"
        )
        XCTAssertEqual(japanese.string("pomodoro.settings.focusLabel"), "集中")
        XCTAssertEqual(japanese.string("pomodoro.settings.shortBreakLabel"), "短い休憩")
        XCTAssertEqual(japanese.string("pomodoro.settings.longBreakLabel"), "長い休憩")
        XCTAssertEqual(
            japanese.string("pomodoro.settings.longBreakAfterLabel"),
            "長い休憩までの集中回数"
        )

        XCTAssertEqual(japanese.string("reminder.editor.newTitle"), "新しいリマインダー")
        XCTAssertEqual(japanese.string("reminder.editor.editTitle"), "リマインダーを編集")
        XCTAssertEqual(
            japanese.string("reminder.editor.prompt"),
            "SchneeRunnerが通知する日時を設定します。"
        )
        XCTAssertEqual(japanese.string("reminder.editor.titlePlaceholder"), "リマインダーのタイトル")
        XCTAssertEqual(japanese.string("reminder.editor.bodyPlaceholder"), "メッセージ（任意）")
        XCTAssertEqual(japanese.string("reminder.schedule.once"), "1回")
        XCTAssertEqual(japanese.string("reminder.schedule.daily"), "毎日")
        XCTAssertEqual(japanese.string("reminder.schedule.weekdays"), "曜日指定")
        XCTAssertEqual(japanese.string("reminder.enabled"), "有効")

        XCTAssertEqual(japanese.string("management.window.title"), "SchneeRunner 生産性ツール")
        XCTAssertEqual(japanese.string("management.history.title"), "最近の履歴")
        XCTAssertEqual(japanese.string("management.history.empty"), "生産性の履歴はまだありません")
        XCTAssertEqual(japanese.string("reminder.management.edit"), "編集")
        XCTAssertEqual(japanese.string("reminder.management.delete"), "削除")
        XCTAssertEqual(japanese.string("reminder.management.snooze"), "スヌーズ…")
        XCTAssertEqual(
            japanese.string("duration.minutesFormat", arguments: 5),
            "5分"
        )

        XCTAssertEqual(japanese.string("notification.timerFinished"), "タイマーが終了しました")
        XCTAssertEqual(japanese.string("notification.reminderDefault"), "リマインダー")
        XCTAssertEqual(japanese.string("notification.pomodoroTitle"), "ポモドーロ")
        XCTAssertEqual(japanese.string("notification.pomodoroFocusFinished"), "集中が終了しました")
        XCTAssertEqual(
            japanese.string("notification.pomodoroShortBreakFinished"),
            "短い休憩が終了しました"
        )
        XCTAssertEqual(
            japanese.string("notification.pomodoroLongBreakFinished"),
            "長い休憩が終了しました"
        )
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
