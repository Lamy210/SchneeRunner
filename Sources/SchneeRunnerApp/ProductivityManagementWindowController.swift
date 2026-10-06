import AppKit
import SchneeRunnerCore

@MainActor
final class ProductivityManagementWindowController: NSObject, NSWindowDelegate {
    var onNewReminder: (() -> Void)?
    var onEditReminder: ((UUID) -> Void)?
    var onDeleteReminder: ((UUID) -> Void)?
    var onSetReminderEnabled: ((UUID, Bool) -> Void)?
    var onSnoozeReminder: ((UUID, ReminderSnoozeDuration) -> Void)?

    private(set) var reminderIDs: [UUID] = []
    private(set) var historyCount = 0

    private var reminders: [ProductivityReminder] = []
    private var history = ProductivityHistory()
    private var panel: NSPanel?
    private var contentStack: NSStackView?

    func setContent(
        reminders: [ProductivityReminder],
        history: ProductivityHistory
    ) {
        self.reminders = reminders
        self.history = history
        reminderIDs = reminders.map(\.id)
        historyCount = history.entries.count
        rebuildContentIfVisible()
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        rebuildContent(in: panel)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func requestEditReminder(id: UUID) {
        onEditReminder?(id)
    }

    func requestDeleteReminder(id: UUID) {
        onDeleteReminder?(id)
    }

    func requestSetReminderEnabled(
        id: UUID,
        enabled: Bool
    ) {
        onSetReminderEnabled?(id, enabled)
    }

    func requestSnoozeReminder(
        id: UUID,
        duration: ReminderSnoozeDuration
    ) {
        onSnoozeReminder?(id, duration)
    }

    func windowWillClose(_: Notification) {
        panel = nil
        contentStack = nil
    }
}

private extension ProductivityManagementWindowController {
    func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "SchneeRunner Productivity"
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        return panel
    }

    func rebuildContentIfVisible() {
        guard let panel else {
            return
        }
        rebuildContent(in: panel)
    }

    func rebuildContent(in panel: NSPanel) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentStack = stack

        addReminderSection(to: stack)
        stack.addArrangedSubview(separator())
        addHistorySection(to: stack)
        documentView.addSubview(stack)
        scrollView.documentView = documentView

        let content = NSView()
        content.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        panel.contentView = content
    }

    func addReminderSection(to stack: NSStackView) {
        stack.addArrangedSubview(sectionTitle("Reminders"))
        let newButton = NSButton(
            title: "New Reminder…",
            target: self,
            action: #selector(newReminder)
        )
        stack.addArrangedSubview(newButton)

        guard !reminders.isEmpty else {
            stack.addArrangedSubview(
                NSTextField(labelWithString: "No reminders configured")
            )
            return
        }

        for reminder in reminders {
            let row = ReminderManagementRowView(reminder: reminder)
            row.onEdit = { [weak self] in
                self?.requestEditReminder(id: reminder.id)
            }
            row.onDelete = { [weak self] in
                self?.requestDeleteReminder(id: reminder.id)
            }
            row.onSetEnabled = { [weak self] enabled in
                self?.requestSetReminderEnabled(
                    id: reminder.id,
                    enabled: enabled
                )
            }
            row.onSnooze = { [weak self] duration in
                self?.requestSnoozeReminder(
                    id: reminder.id,
                    duration: duration
                )
            }
            stack.addArrangedSubview(row)
        }
    }

    func addHistorySection(to stack: NSStackView) {
        stack.addArrangedSubview(sectionTitle("Recent History"))
        let entries = history.entries.suffix(20).reversed()
        guard !entries.isEmpty else {
            stack.addArrangedSubview(
                NSTextField(labelWithString: "No productivity history yet")
            )
            return
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        for entry in entries {
            let text = "\(formatter.string(from: entry.occurredAt)) · \(entry.title)"
            stack.addArrangedSubview(NSTextField(labelWithString: text))
        }
    }

    func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(
            ofSize: NSFont.systemFontSize + 2,
            weight: .semibold
        )
        return label
    }

    func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    @objc
    func newReminder() {
        onNewReminder?()
    }
}
