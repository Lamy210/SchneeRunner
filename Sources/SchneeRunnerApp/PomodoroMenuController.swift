import AppKit
import Foundation
import SchneeRunnerCore

@MainActor
final class PomodoroMenuController: NSObject {
    let rootItem: NSMenuItem

    var onStart: ((PomodoroConfiguration) -> Void)?
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    var onStartCurrentPhase: (() -> Void)?
    var onStop: (() -> Void)?
    var onSettings: (() -> Void)?

    private let localization: AppLocalization
    private let menu: NSMenu
    private var session: PomodoroSession?
    private var configuration: PomodoroConfiguration? = try? PomodoroConfiguration()
    private var now = Date()

    init(localization: AppLocalization = .current) {
        self.localization = localization
        let rootTitle = localization.string("pomodoro.root")
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

    func setSession(
        _ session: PomodoroSession?,
        now: Date
    ) {
        self.session = session
        self.now = now
        rebuild()
    }

    func setConfiguration(_ configuration: PomodoroConfiguration) {
        self.configuration = configuration
        rebuild()
    }

    func refresh(now: Date) {
        self.now = now
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()

        guard let session else {
            addStartItem()
            addSettingsItem()
            return
        }

        let statusItem = NSMenuItem(
            title: sessionTitle(session),
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        switch session.state {
        case .running:
            addActionItem(
                title: localization.string("action.pause"),
                action: #selector(pause)
            )
        case .paused:
            addActionItem(
                title: localization.string("action.resume"),
                action: #selector(resume)
            )
        case .waiting:
            addActionItem(
                title: localization.string(
                    session.currentPhase == .focus
                        ? "pomodoro.startFocus"
                        : "pomodoro.startBreak"
                ),
                action: #selector(startCurrentPhase)
            )
        }

        addActionItem(
            title: localization.string("action.stop"),
            action: #selector(stop)
        )
        addSettingsItem()
    }

    private func addStartItem() {
        addActionItem(
            title: localization.string("pomodoro.start"),
            action: #selector(startDefault)
        )
    }

    private func addSettingsItem() {
        menu.addItem(.separator())
        addActionItem(
            title: localization.string("pomodoro.settings"),
            action: #selector(openSettings)
        )
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

    private func sessionTitle(_ session: PomodoroSession) -> String {
        let phase = phaseTitle(session.currentPhase)

        switch session.state {
        case .running:
            return "\(phase) · \(format(session.remaining(at: now)))"
        case .paused:
            return localization.string(
                "pomodoro.pausedFormat",
                arguments: phase,
                format(session.remaining(at: now))
            )
        case .waiting:
            return localization.string(
                "pomodoro.readyFormat",
                arguments: phase
            )
        }
    }

    private func phaseTitle(_ phase: PomodoroPhase) -> String {
        switch phase {
        case .focus:
            localization.string("pomodoro.focus")
        case .shortBreak:
            localization.string("pomodoro.shortBreak")
        case .longBreak:
            localization.string("pomodoro.longBreak")
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

private extension PomodoroMenuController {
    @objc
    func startDefault() {
        guard let configuration else {
            return
        }
        onStart?(configuration)
    }

    @objc
    func pause() {
        onPause?()
    }

    @objc
    func resume() {
        onResume?()
    }

    @objc
    func startCurrentPhase() {
        onStartCurrentPhase?()
    }

    @objc
    func stop() {
        onStop?()
    }

    @objc
    func openSettings() {
        onSettings?()
    }
}
