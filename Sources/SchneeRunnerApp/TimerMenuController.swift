import AppKit
import Foundation
import SchneeRunnerCore

@MainActor
final class TimerMenuController: NSObject {
    let rootItem: NSMenuItem

    var onStartPreset: ((TimeInterval) -> Void)?
    var onStartCustomTimer: (() -> Void)?
    var onManageTimers: (() -> Void)?
    var onPauseTimer: ((UUID) -> Void)?
    var onResumeTimer: ((UUID) -> Void)?
    var onCancelTimer: ((UUID) -> Void)?

    private let localization: AppLocalization
    private let menu = NSMenu()
    private let newTimerMenu = NSMenu()
    private var timers: [ProductivityCountdownTimer] = []
    private var now = Date()

    init(localization: AppLocalization = .current) {
        self.localization = localization
        rootItem = NSMenuItem(
            title: localization.string("menu.timers"),
            action: nil,
            keyEquivalent: ""
        )
        super.init()
        rootItem.submenu = menu
        configureNewTimerMenu()
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
}

private extension TimerMenuController {
    func configureNewTimerMenu() {
        for minutes in [5, 10, 15, 25, 30, 60] {
            let item = NSMenuItem(
                title: localization.string(
                    "timer.presetMinutes",
                    arguments: minutes
                ),
                action: #selector(startPreset(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = minutes * 60
            newTimerMenu.addItem(item)
        }
        let customItem = NSMenuItem(
            title: localization.string("timer.custom"),
            action: #selector(startCustomTimer(_:)),
            keyEquivalent: ""
        )
        customItem.target = self
        newTimerMenu.addItem(customItem)
    }

    func rebuildActiveTimers() {
        menu.removeAllItems()

        let newTimerItem = NSMenuItem(
            title: localization.string("timer.new"),
            action: nil,
            keyEquivalent: ""
        )
        newTimerItem.submenu = newTimerMenu
        menu.addItem(newTimerItem)

        let manageItem = NSMenuItem(
            title: localization.string("timer.manage"),
            action: #selector(manageTimers(_:)),
            keyEquivalent: ""
        )
        manageItem.target = self
        menu.addItem(manageItem)
        menu.addItem(.separator())

        let activeTimers = timers.filter {
            $0.state == .running || $0.state == .paused
        }
        guard !activeTimers.isEmpty else {
            let emptyItem = NSMenuItem(
                title: localization.string("timer.empty"),
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

    func makeTimerItem(_ timer: ProductivityCountdownTimer) -> NSMenuItem {
        let item = NSMenuItem(
            title: timerTitle(timer),
            action: nil,
            keyEquivalent: ""
        )
        item.representedObject = timer.id.uuidString

        let actions = NSMenu()
        switch timer.state {
        case .running:
            actions.addItem(
                actionItem(
                    title: localization.string("action.pause"),
                    selector: #selector(pauseTimer(_:)),
                    timerID: timer.id
                )
            )
        case .paused:
            actions.addItem(
                actionItem(
                    title: localization.string("action.resume"),
                    selector: #selector(resumeTimer(_:)),
                    timerID: timer.id
                )
            )
        case .completed, .cancelled:
            break
        }
        actions.addItem(
            actionItem(
                title: localization.string("action.cancel"),
                selector: #selector(cancelTimer(_:)),
                timerID: timer.id
            )
        )
        item.submenu = actions
        return item
    }

    func actionItem(
        title: String,
        selector: Selector,
        timerID: UUID
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: selector,
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = timerID.uuidString
        return item
    }

    func timerTitle(_ timer: ProductivityCountdownTimer) -> String {
        let seconds = max(0, timer.remaining(at: now).rounded(.down))
        let minutes = floor(seconds / 60)
        let remainder = seconds.truncatingRemainder(dividingBy: 60)
        let time = String(format: "%02.0f:%02.0f", minutes, remainder)
        switch timer.state {
        case .paused:
            return localization.string(
                "timer.pausedFormat",
                arguments: timer.title,
                time
            )
        case .running, .completed, .cancelled:
            return "\(timer.title) · \(time)"
        }
    }

    @objc
    func startPreset(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int else {
            return
        }
        onStartPreset?(TimeInterval(seconds))
    }

    @objc
    func startCustomTimer(_: NSMenuItem) {
        onStartCustomTimer?()
    }

    @objc
    func manageTimers(_: NSMenuItem) {
        onManageTimers?()
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
