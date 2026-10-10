import AppKit
import Foundation
import SchneeRunnerCore

@MainActor
final class ProductivityManagementWindowController: NSObject, NSWindowDelegate {
    var onPauseTimer: ((UUID) -> Void)?
    var onResumeTimer: ((UUID) -> Void)?
    var onCancelTimer: ((UUID) -> Void)?
    var onEditPomodoroSettings: ((PomodoroConfiguration) -> Void)?
    var onNewReminder: (() -> Void)?
    var onEditReminder: ((UUID) -> Void)?
    var onDeleteReminder: ((UUID) -> Void)?
    var onSetReminderEnabled: ((UUID, Bool) -> Void)?
    var onSnoozeReminder: ((UUID, ReminderSnoozeDuration) -> Void)?

    private(set) var timerIDs: [UUID] = []
    private(set) var reminderIDs: [UUID] = []
    private(set) var pomodoroConfiguration: PomodoroConfiguration?
    private(set) var historyCount = 0

    private let localization: AppLocalization
    private var timers: [ProductivityCountdownTimer] = []
    private var reminders: [ProductivityReminder] = []
    private var history = ProductivityHistory()
    private var panel: NSPanel?

    init(localization: AppLocalization = .current) {
        self.localization = localization
        super.init()
    }

    func setTimers(_ timers: [ProductivityCountdownTimer]) {
        self.timers = timers
        timerIDs = timers.map(\.id)
        rebuildContentIfVisible()
    }

    func setReminders(_ reminders: [ProductivityReminder]) {
        self.reminders = reminders
        reminderIDs = reminders.map(\.id)
        rebuildContentIfVisible()
    }

    func setPomodoroConfiguration(_ configuration: PomodoroConfiguration) {
        pomodoroConfiguration = configuration
        rebuildContentIfVisible()
    }

    func setHistory(_ history: ProductivityHistory) {
        self.history = history
        historyCount = history.entries.count
        rebuildContentIfVisible()
    }

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

    func requestPauseTimer(id: UUID) {
        onPauseTimer?(id)
    }

    func requestResumeTimer(id: UUID) {
        onResumeTimer?(id)
    }

    func requestCancelTimer(id: UUID) {
        onCancelTimer?(id)
    }

    func requestEditPomodoroSettings(_ configuration: PomodoroConfiguration) {
        onEditPomodoroSettings?(configuration)
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
    }
}

private extension ProductivityManagementWindowController {
    func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = localization.string("management.window.title")
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

        addTimerSection(to: stack)
        stack.addArrangedSubview(separator())
        addReminderSection(to: stack)
        stack.addArrangedSubview(separator())
        addPomodoroSection(to: stack)
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

    func addTimerSection(to stack: NSStackView) {
        stack.addArrangedSubview(
            sectionTitle(localization.string("menu.timers"))
        )
        let activeTimers = timers.filter {
            $0.state == .running || $0.state == .paused
        }
        guard !activeTimers.isEmpty else {
            stack.addArrangedSubview(
                NSTextField(
                    labelWithString: localization.string("timer.empty")
                )
            )
            return
        }

        for timer in activeTimers {
            stack.addArrangedSubview(timerRow(timer))
        }
    }

    func timerRow(_ timer: ProductivityCountdownTimer) -> NSView {
        let label = NSTextField(labelWithString: timerStatus(timer))
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let actionTitle = timer.state == .paused
            ? localization.string("action.resume")
            : localization.string("action.pause")
        let action = timer.state == .paused
            ? #selector(resumeTimer(_:))
            : #selector(pauseTimer(_:))
        let actionButton = timerButton(
            title: actionTitle,
            action: action,
            id: timer.id
        )
        let cancelButton = timerButton(
            title: localization.string("action.cancel"),
            action: #selector(cancelTimer(_:)),
            id: timer.id
        )
        let row = NSStackView(views: [label, actionButton, cancelButton])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    func timerButton(
        title: String,
        action: Selector,
        id: UUID
    ) -> NSButton {
        let button = NSButton(
            title: title,
            target: self,
            action: action
        )
        button.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        return button
    }

    func timerStatus(_ timer: ProductivityCountdownTimer) -> String {
        let stateKey = timer.state == .paused
            ? "timer.state.paused"
            : "timer.state.running"
        let state = localization.string(stateKey)
        let seconds = max(0, timer.remaining(at: Date()).rounded(.down))
        let minutes = floor(seconds / 60)
        let remainder = seconds.truncatingRemainder(dividingBy: 60)
        let time = String(format: "%.0f:%02.0f", minutes, remainder)
        return localization.string(
            "timer.management.statusFormat",
            arguments: timer.title, state, time
        )
    }

    func addReminderSection(to stack: NSStackView) {
        stack.addArrangedSubview(
            sectionTitle(localization.string("reminder.root"))
        )
        let newButton = NSButton(
            title: localization.string("reminder.new"),
            target: self,
            action: #selector(newReminder)
        )
        stack.addArrangedSubview(newButton)

        guard !reminders.isEmpty else {
            stack.addArrangedSubview(
                NSTextField(
                    labelWithString: localization.string(
                        "reminder.management.empty"
                    )
                )
            )
            return
        }

        for reminder in reminders {
            let row = ReminderManagementRowView(
                reminder: reminder,
                localization: localization
            )
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

    func addPomodoroSection(to stack: NSStackView) {
        stack.addArrangedSubview(
            sectionTitle(localization.string("pomodoro.root"))
        )
        guard let configuration = pomodoroConfiguration else {
            stack.addArrangedSubview(
                NSTextField(
                    labelWithString: localization.string(
                        "pomodoro.management.unavailable"
                    )
                )
            )
            return
        }

        let focusMinutes = Int(configuration.focusDuration / 60)
        let shortMinutes = Int(configuration.shortBreakDuration / 60)
        let longMinutes = Int(configuration.longBreakDuration / 60)
        let summary = localization.string(
            "pomodoro.management.summaryFormat",
            arguments: focusMinutes, shortMinutes, longMinutes
        )
        stack.addArrangedSubview(NSTextField(labelWithString: summary))
        let editButton = NSButton(
            title: localization.string("pomodoro.management.edit"),
            target: self,
            action: #selector(editPomodoroSettings)
        )
        stack.addArrangedSubview(editButton)
    }

    func addHistorySection(to stack: NSStackView) {
        stack.addArrangedSubview(
            sectionTitle(localization.string("management.history.title"))
        )
        let entries = history.entries.suffix(20).reversed()
        guard !entries.isEmpty else {
            stack.addArrangedSubview(
                NSTextField(
                    labelWithString: localization.string(
                        "management.history.empty"
                    )
                )
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

    func timerID(from button: NSButton) -> UUID? {
        guard let identifier = button.identifier?.rawValue else {
            return nil
        }
        return UUID(uuidString: identifier)
    }

    @objc
    func pauseTimer(_ sender: NSButton) {
        guard let id = timerID(from: sender) else {
            return
        }
        requestPauseTimer(id: id)
    }

    @objc
    func resumeTimer(_ sender: NSButton) {
        guard let id = timerID(from: sender) else {
            return
        }
        requestResumeTimer(id: id)
    }

    @objc
    func cancelTimer(_ sender: NSButton) {
        guard let id = timerID(from: sender) else {
            return
        }
        requestCancelTimer(id: id)
    }

    @objc
    func editPomodoroSettings() {
        guard let pomodoroConfiguration else {
            return
        }
        requestEditPomodoroSettings(pomodoroConfiguration)
    }

    @objc
    func newReminder() {
        onNewReminder?()
    }
}
