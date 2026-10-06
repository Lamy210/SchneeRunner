import AppKit
import Foundation
import SchneeRunnerCore

enum ReminderEditorError: Error, Equatable {
    case emptyTitle
}

struct ReminderEditRequest: Equatable {
    let title: String
    let body: String?
    let enabled: Bool
    let schedule: ReminderSchedule
}

@MainActor
final class ReminderEditorController {
    private struct Form {
        let titleField: NSTextField
        let bodyField: NSTextField
        let schedulePopUp: NSPopUpButton
        let datePicker: NSDatePicker
        let enabledButton: NSButton
        let weekdayButtons: [Weekday: NSButton]
        let view: NSView
    }

    func makeRequest(
        title: String,
        body: String?,
        enabled: Bool,
        schedule: ReminderSchedule
    ) throws -> ReminderEditRequest {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw ReminderEditorError.emptyTitle
        }
        try schedule.validate()

        let normalizedBody = body?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ReminderEditRequest(
            title: normalizedTitle,
            body: normalizedBody?.isEmpty == true ? nil : normalizedBody,
            enabled: enabled,
            schedule: schedule
        )
    }

    func present(
        existing reminder: ProductivityReminder? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReminderEditRequest? {
        let form = makeForm(
            existing: reminder,
            now: now,
            calendar: calendar
        )
        let alert = makeAlert(
            title: reminder == nil ? "New Reminder" : "Edit Reminder",
            form: form
        )

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        do {
            return try makeRequest(
                title: form.titleField.stringValue,
                body: form.bodyField.stringValue,
                enabled: form.enabledButton.state == .on,
                schedule: schedule(from: form, calendar: calendar)
            )
        } catch {
            presentValidationError(error)
            return nil
        }
    }
}

private extension ReminderEditorController {
    func makeAlert(
        title: String,
        form: Form
    ) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Choose when SchneeRunner should notify you."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = form.view
        return alert
    }

    func makeForm(
        existing reminder: ProductivityReminder?,
        now: Date,
        calendar: Calendar
    ) -> Form {
        let titleField = NSTextField(string: reminder?.title ?? "")
        titleField.placeholderString = "Reminder title"
        let bodyField = NSTextField(string: reminder?.body ?? "")
        bodyField.placeholderString = "Optional message"

        let schedulePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        schedulePopUp.addItems(withTitles: ["Once", "Daily", "Weekdays"])

        let datePicker = NSDatePicker()
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.dateValue = initialDate(
            for: reminder,
            now: now,
            calendar: calendar
        )

        let enabledButton = NSButton(
            checkboxWithTitle: "Enabled",
            target: nil,
            action: nil
        )
        enabledButton.state = reminder?.enabled == false ? .off : .on

        let weekdayButtons = makeWeekdayButtons(reminder: reminder)
        configureScheduleSelection(
            schedulePopUp,
            reminder: reminder
        )

        let stack = makeFormStack(
            titleField: titleField,
            bodyField: bodyField,
            schedulePopUp: schedulePopUp,
            datePicker: datePicker,
            enabledButton: enabledButton,
            weekdayButtons: weekdayButtons
        )
        return Form(
            titleField: titleField,
            bodyField: bodyField,
            schedulePopUp: schedulePopUp,
            datePicker: datePicker,
            enabledButton: enabledButton,
            weekdayButtons: weekdayButtons,
            view: stack
        )
    }

    func makeFormStack(
        titleField: NSTextField,
        bodyField: NSTextField,
        schedulePopUp: NSPopUpButton,
        datePicker: NSDatePicker,
        enabledButton: NSButton,
        weekdayButtons: [Weekday: NSButton]
    ) -> NSView {
        let weekdayStack = NSStackView(
            views: Weekday.allCases.compactMap { weekdayButtons[$0] }
        )
        weekdayStack.orientation = .horizontal
        weekdayStack.spacing = 4

        let stack = NSStackView(
            views: [
                labeled("Title", control: titleField),
                labeled("Message", control: bodyField),
                labeled("Schedule", control: schedulePopUp),
                labeled("Date / Time", control: datePicker),
                labeled("Weekdays", control: weekdayStack),
                enabledButton
            ]
        )
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 420, height: 190)
        return stack
    }

    func labeled(
        _ title: String,
        control: NSView
    ) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let stack = NSStackView(views: [label, control])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    func makeWeekdayButtons(
        reminder: ProductivityReminder?
    ) -> [Weekday: NSButton] {
        let selected = selectedWeekdays(reminder)
        return Dictionary(
            uniqueKeysWithValues: Weekday.allCases.map { weekday in
                let button = NSButton(
                    checkboxWithTitle: shortTitle(for: weekday),
                    target: nil,
                    action: nil
                )
                button.state = selected.contains(weekday) ? .on : .off
                return (weekday, button)
            }
        )
    }

    func selectedWeekdays(
        _ reminder: ProductivityReminder?
    ) -> Set<Weekday> {
        guard
            let reminder,
            case let .weekdays(weekdays, _, _) = reminder.schedule
        else {
            return []
        }
        return weekdays
    }

    func configureScheduleSelection(
        _ popUp: NSPopUpButton,
        reminder: ProductivityReminder?
    ) {
        switch reminder?.schedule {
        case .daily:
            popUp.selectItem(at: 1)
        case .weekdays:
            popUp.selectItem(at: 2)
        case .once, .none:
            popUp.selectItem(at: 0)
        }
    }

    func initialDate(
        for reminder: ProductivityReminder?,
        now: Date,
        calendar: Calendar
    ) -> Date {
        guard let reminder else {
            return now.addingTimeInterval(60 * 60)
        }
        switch reminder.schedule {
        case let .once(date):
            return date
        case let .daily(hour, minute),
             let .weekdays(_, hour, minute):
            return calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: now
            ) ?? now
        }
    }

    func schedule(
        from form: Form,
        calendar: Calendar
    ) -> ReminderSchedule {
        let components = calendar.dateComponents(
            [.hour, .minute],
            from: form.datePicker.dateValue
        )
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        switch form.schedulePopUp.indexOfSelectedItem {
        case 1:
            return .daily(hour: hour, minute: minute)
        case 2:
            let weekdays = Set(
                form.weekdayButtons.compactMap { weekday, button in
                    button.state == .on ? weekday : nil
                }
            )
            return .weekdays(weekdays, hour: hour, minute: minute)
        default:
            return .once(form.datePicker.dateValue)
        }
    }

    func shortTitle(for weekday: Weekday) -> String {
        switch weekday {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    func presentValidationError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Invalid Reminder"
        alert.informativeText = String(describing: error)
        alert.runModal()
    }
}
