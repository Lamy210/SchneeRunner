import AppKit
import Foundation
import SchneeRunnerCore

@MainActor
final class ReminderMenuController: NSObject {
    let rootItem = NSMenuItem(
        title: "Reminders",
        action: nil,
        keyEquivalent: ""
    )

    var onNewReminder: (() -> Void)?
    var onManageReminders: (() -> Void)?

    private let menu = NSMenu(title: "Reminders")
    private var reminders: [ProductivityReminder] = []
    private var now = Date()
    private var calendar = Calendar.current

    override init() {
        super.init()
        rootItem.submenu = menu
        rebuild()
    }

    func setReminders(
        _ reminders: [ProductivityReminder],
        now: Date,
        calendar: Calendar = .current
    ) {
        self.reminders = reminders
        self.now = now
        self.calendar = calendar
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()
        addSummaryItem()
        menu.addItem(.separator())
        addActionItem(
            title: "New Reminder…",
            action: #selector(newReminder)
        )
        addActionItem(
            title: "Manage Reminders…",
            action: #selector(manageReminders)
        )
    }

    private func addSummaryItem() {
        guard let next = nextReminder() else {
            let item = NSMenuItem(
                title: "No upcoming reminders",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.calendar = calendar
        let item = NSMenuItem(
            title: "Next: \(next.reminder.title) · \(formatter.string(from: next.date))",
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = false
        menu.addItem(item)
    }

    private func nextReminder() -> (
        reminder: ProductivityReminder,
        date: Date
    )? {
        reminders.compactMap { reminder in
            guard let date = reminder.nextOccurrence(
                after: now,
                calendar: calendar
            ) else {
                return nil
            }
            return (reminder, date)
        }.min { lhs, rhs in
            lhs.1 < rhs.1
        }
    }

    private func addActionItem(
        title: String,
        action: Selector
    ) {
        let item = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
    }
}

private extension ReminderMenuController {
    @objc
    func newReminder() {
        onNewReminder?()
    }

    @objc
    func manageReminders() {
        onManageReminders?()
    }
}
