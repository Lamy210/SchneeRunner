import AppKit
import SchneeRunnerCore

@MainActor
final class PomodoroSettingsController {
    private let localization: AppLocalization

    init(localization: AppLocalization = .current) {
        self.localization = localization
    }

    func makeConfiguration(
        focusMinutes: Double,
        shortBreakMinutes: Double,
        longBreakMinutes: Double,
        focusPhasesBeforeLongBreak: Int,
        autoStartNextPhase: Bool
    ) throws -> PomodoroConfiguration {
        try PomodoroConfiguration(
            focusDuration: focusMinutes * 60,
            shortBreakDuration: shortBreakMinutes * 60,
            longBreakDuration: longBreakMinutes * 60,
            focusPhasesBeforeLongBreak: focusPhasesBeforeLongBreak,
            autoStartNextPhase: autoStartNextPhase
        )
    }

    func present(
        configuration: PomodoroConfiguration
    ) -> PomodoroConfiguration? {
        let focusField = NSTextField(
            string: Self.minutesString(configuration.focusDuration)
        )
        let shortBreakField = NSTextField(
            string: Self.minutesString(configuration.shortBreakDuration)
        )
        let longBreakField = NSTextField(
            string: Self.minutesString(configuration.longBreakDuration)
        )
        let phaseCountField = NSTextField(
            string: String(configuration.focusPhasesBeforeLongBreak)
        )
        let autoStartButton = NSButton(
            checkboxWithTitle: localization.string("pomodoro.settings.autoStart"),
            target: nil,
            action: nil
        )
        autoStartButton.state = configuration.autoStartNextPhase ? .on : .off

        let form = makeForm(
            focusField: focusField,
            shortBreakField: shortBreakField,
            longBreakField: longBreakField,
            phaseCountField: phaseCountField,
            autoStartButton: autoStartButton
        )
        let alert = NSAlert()
        alert.messageText = localization.string("pomodoro.settings.title")
        alert.informativeText = localization.string(
            "pomodoro.settings.description"
        )
        alert.addButton(withTitle: localization.string("action.save"))
        alert.addButton(withTitle: localization.string("action.cancel"))
        alert.accessoryView = form

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        guard
            let focusMinutes = Double(focusField.stringValue),
            let shortBreakMinutes = Double(shortBreakField.stringValue),
            let longBreakMinutes = Double(longBreakField.stringValue),
            let phaseCount = Int(phaseCountField.stringValue)
        else {
            presentValidationError()
            return nil
        }

        do {
            return try makeConfiguration(
                focusMinutes: focusMinutes,
                shortBreakMinutes: shortBreakMinutes,
                longBreakMinutes: longBreakMinutes,
                focusPhasesBeforeLongBreak: phaseCount,
                autoStartNextPhase: autoStartButton.state == .on
            )
        } catch {
            presentValidationError()
            return nil
        }
    }
}

private extension PomodoroSettingsController {
    static func minutesString(_ duration: TimeInterval) -> String {
        String(format: "%g", duration / 60)
    }

    func makeForm(
        focusField: NSTextField,
        shortBreakField: NSTextField,
        longBreakField: NSTextField,
        phaseCountField: NSTextField,
        autoStartButton: NSButton
    ) -> NSView {
        let stack = NSStackView(
            views: [
                labeled(
                    localization.string("pomodoro.settings.focusLabel"),
                    control: focusField
                ),
                labeled(
                    localization.string("pomodoro.settings.shortBreakLabel"),
                    control: shortBreakField
                ),
                labeled(
                    localization.string("pomodoro.settings.longBreakLabel"),
                    control: longBreakField
                ),
                labeled(
                    localization.string("pomodoro.settings.longBreakAfterLabel"),
                    control: phaseCountField
                ),
                autoStartButton
            ]
        )
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 360, height: 145)
        return stack
    }

    func labeled(
        _ title: String,
        control: NSView
    ) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 120).isActive = true
        control.widthAnchor.constraint(equalToConstant: 180).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    func presentValidationError() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localization.string(
            "pomodoro.settings.invalidTitle"
        )
        alert.informativeText = localization.string(
            "pomodoro.settings.invalidDetail"
        )
        alert.runModal()
    }
}
