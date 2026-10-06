import AppKit
import SchneeRunnerCore

@MainActor
final class ReminderManagementRowView: NSStackView {
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSetEnabled: ((Bool) -> Void)?
    var onSnooze: ((ReminderSnoozeDuration) -> Void)?

    private let enabledButton: NSButton
    private let snoozePopUp = NSPopUpButton(
        frame: .zero,
        pullsDown: false
    )

    init(reminder: ProductivityReminder) {
        enabledButton = NSButton(
            checkboxWithTitle: "Enabled",
            target: nil,
            action: nil
        )
        enabledButton.state = reminder.enabled ? .on : .off
        super.init(frame: .zero)

        orientation = .horizontal
        alignment = .centerY
        spacing = 8

        let title = NSTextField(labelWithString: reminder.title)
        title.lineBreakMode = .byTruncatingTail
        title.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        addArrangedSubview(title)

        enabledButton.target = self
        enabledButton.action = #selector(toggleEnabled)
        addArrangedSubview(enabledButton)

        configureSnoozePopUp()
        addArrangedSubview(snoozePopUp)

        addArrangedSubview(
            actionButton(
                title: "Edit",
                action: #selector(edit)
            )
        )
        addArrangedSubview(
            actionButton(
                title: "Delete",
                action: #selector(deleteReminder)
            )
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}

private extension ReminderManagementRowView {
    func configureSnoozePopUp() {
        snoozePopUp.addItem(withTitle: "Snooze…")
        for duration in ReminderSnoozeDuration.allCases {
            let item = NSMenuItem(
                title: "\(duration.rawValue) min",
                action: nil,
                keyEquivalent: ""
            )
            item.representedObject = duration.rawValue
            snoozePopUp.menu?.addItem(item)
        }
        snoozePopUp.target = self
        snoozePopUp.action = #selector(snoozeChanged)
    }

    func actionButton(
        title: String,
        action: Selector
    ) -> NSButton {
        NSButton(
            title: title,
            target: self,
            action: action
        )
    }

    @objc
    func toggleEnabled() {
        onSetEnabled?(enabledButton.state == .on)
    }

    @objc
    func snoozeChanged() {
        guard
            let value = snoozePopUp.selectedItem?.representedObject as? Int,
            let duration = ReminderSnoozeDuration(rawValue: value)
        else {
            return
        }
        onSnooze?(duration)
        snoozePopUp.selectItem(at: 0)
    }

    @objc
    func edit() {
        onEdit?()
    }

    @objc
    func deleteReminder() {
        onDelete?()
    }
}
