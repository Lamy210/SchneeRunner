import AppKit
import Foundation
import SchneeRunnerCore

@MainActor
final class TimerMenuController: NSObject {
    let rootItem = NSMenuItem(
        title: "Timers",
        action: nil,
        keyEquivalent: ""
    )

    var onStartPreset: ((TimeInterval) -> Void)?
    var onStartCustomTimer: (() -> Void)?
    var onPauseTimer: ((UUID) -> Void)?
    var onResumeTimer: ((UUID) -> Void)?
    var onCancelTimer: ((UUID) -> Void)?

    private let menu = NSMenu(title: "Timers")
    private let newTimerMenu = NSMenu(title: "New Timer")
    private var timers: [ProductivityCountdownTimer] = []
    private var now = Date()

    override init() {
        super.init()
        rootItem.submenu = menu
        buildNewTimerMenu()
        rebuildActiveTimers()
    }

    func setTimers(
        _ timers: [ProductivityCountdownTimer],
        now: Date
    ) {
        self.timers = timers
        self.now = now
        rebuildActiveTimers()
    }

    private func buildNewTimerMenu() {
        let presets: [(title: String, duration: TimeInterval)] = [
            ("5 min", 5 * 60),
            ("10 min", 10 * 60),
            ("15 min", 15 * 60),
            ("25 min", 25 * 60),
            ("30 min", 30 * 60),
            ("60 min", 60 * 60)
        ]

        for preset in presets {
            let item = NSMenuItem(
                title: preset.title,
                action: #selector(startPreset(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.duration
            newTimerMenu.addItem(item)
        }

        let customItem = NSMenuItem(
            title: "Custom…",
            action: #selector(startCustomTimer),
            keyEquivalent: ""
        )
        customItem.target = self
        newTimerMenu.addItem(customItem)
    }

    private func rebuildActiveTimers() {
        menu.removeAllItems()

        let newTimerItem = NSMenuItem(
            title: "New Timer",
            action: nil,
            keyEquivalent: ""
        )
        newTimerItem.submenu = newTimerMenu
        menu.addItem(newTimerItem)
        menu.addItem(.separator())

        let activeTimers = timers.filter {
            $0.state == .running || $0.state == .paused
        }

        guard !activeTimers.isEmpty else {
            let emptyItem = NSMenuItem(
                title: "No active timers",
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        for timer in activeTimers {
            menu.addItem(makeTimerItem(timer))
        }
    }

    private func makeTimerItem(
        _ timer: ProductivityCountdownTimer
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: timerTitle(timer),
            action: nil,
            keyEquivalent: ""
        )
        item.representedObject = timer.id.uuidString
        item.submenu = makeActionsMenu(timer)
        return item
    }

    private func makeActionsMenu(
        _ timer: ProductivityCountdownTimer
    ) -> NSMenu {
        let actions = NSMenu(title: timer.title)
        let stateActionTitle = timer.state == .running ? "Pause" : "Resume"
        let stateAction = NSMenuItem(
            title: stateActionTitle,
            action: timer.state == .running
                ? #selector(pauseTimer(_:))
                : #selector(resumeTimer(_:)),
            keyEquivalent: ""
        )
        stateAction.target = self
        stateAction.representedObject = timer.id.uuidString
        actions.addItem(stateAction)

        let cancelItem = NSMenuItem(
            title: "Cancel",
            action: #selector(cancelTimer(_:)),
            keyEquivalent: ""
        )
        cancelItem.target = self
        cancelItem.representedObject = timer.id.uuidString
        actions.addItem(cancelItem)
        return actions
    }

    private func timerTitle(
        _ timer: ProductivityCountdownTimer
    ) -> String {
        let remaining = format(timer.remaining(at: now))
        switch timer.state {
        case .running:
            return "\(timer.title) · \(remaining)"
        case .paused:
            return "\(timer.title) · Paused \(remaining)"
        case .completed, .cancelled:
            return timer.title
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, interval.rounded(.down))
        let minutes = (totalSeconds / 60).rounded(.down)
        let seconds = totalSeconds.truncatingRemainder(dividingBy: 60)
        return String(
            format: "%02.0f:%02.0f",
            minutes,
            seconds
        )
    }
}

private extension TimerMenuController {
    @objc
    func startPreset(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TimeInterval else {
            return
        }
        onStartPreset?(duration)
    }

    @objc
    func startCustomTimer() {
        onStartCustomTimer?()
    }

    @objc
    func pauseTimer(_ sender: NSMenuItem) {
        guard let id = timerID(from: sender) else {
            return
        }
        onPauseTimer?(id)
    }

    @objc
    func resumeTimer(_ sender: NSMenuItem) {
        guard let id = timerID(from: sender) else {
            return
        }
        onResumeTimer?(id)
    }

    @objc
    func cancelTimer(_ sender: NSMenuItem) {
        guard let id = timerID(from: sender) else {
            return
        }
        onCancelTimer?(id)
    }

    func timerID(from sender: NSMenuItem) -> UUID? {
        guard let rawID = sender.representedObject as? String else {
            return nil
        }
        return UUID(uuidString: rawID)
    }
}
