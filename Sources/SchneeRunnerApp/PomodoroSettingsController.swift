import AppKit
import SchneeRunnerCore

@MainActor
final class PomodoroSettingsController {
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
            checkboxWithTitle: "Automatically start the next phase",
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
        alert.messageText = "Pomodoro Settings"
        alert.informativeText = "Configure focus and break durations in minutes."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
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
                labeled("Focus", control: focusField),
                labeled("Short break", control: shortBreakField),
                labeled("Long break", control: longBreakField),
                labeled("Long break after", control: phaseCountField),
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
        alert.messageText = "Invalid Pomodoro Settings"
        alert.informativeText = "Use positive durations and a valid focus phase count."
        alert.runModal()
    }
}
