import AppKit
import Foundation
import SchneeRunnerCore

@MainActor
final class ReminderMenuController: NSObject {
    let rootItem: NSMenuItem

    var onNewReminder: (() -> Void)?
    var onManageReminders: (() -> Void)?

    private let localization: AppLocalization
    private let menu: NSMenu
    private var reminders: [ProductivityReminder] = []
    private var now = Date()
    private var calendar = Calendar.current

    init(localization: AppLocalization = .current) {
        self.localization = localization
        let rootTitle = localization.string("reminder.root")
        rootItem = NSMenuItem(
            title: rootTitle,
            action: nil,
            keyEquivalent: ""
        )
        menu = NSMenu(title: rootTitle)
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
            title: localization.string("reminder.new"),
            action: #selector(newReminder)
        )
        addActionItem(
            title: localization.string("reminder.manage"),
            action: #selector(manageReminders)
        )
    }

    private func addSummaryItem() {
        guard let next = nextReminder() else {
            let item = NSMenuItem(
                title: localization.string("reminder.empty"),
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
            title: localization.string(
                "reminder.nextFormat",
                arguments: next.reminder.title,
                formatter.string(from: next.date)
            ),
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
