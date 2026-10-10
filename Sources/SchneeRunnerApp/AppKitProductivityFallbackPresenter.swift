import AppKit
import SchneeRunnerCore

@MainActor
final class AppKitProductivityFallbackPresenter: NSObject, ProductivityFallbackPresenting, NSWindowDelegate {
    private let localization: AppLocalization
    private var panels: [NSPanel] = []

    init(localization: AppLocalization = .current) {
        self.localization = localization
        super.init()
    }

    func present(_ event: ProductivityFallbackEvent) {
        let content = presentationContent(for: event)
        NSSound.beep()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = content.title
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let label = NSTextField(wrappingLabelWithString: content.message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.maximumNumberOfLines = 0

        let contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            label.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
        panel.contentView = contentView

        panels.append(panel)
        panel.center()
        panel.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else {
            return
        }
        panels.removeAll { $0 === panel }
    }

    func presentationContent(
        for event: ProductivityFallbackEvent
    ) -> (title: String, message: String) {
        switch event {
        case let .timerCompleted(title):
            (
                localization.string("notification.timerFinished"),
                title
            )
        case let .pomodoroPhaseCompleted(phase):
            (
                localization.string("notification.pomodoroTitle"),
                pomodoroCompletionMessage(for: phase)
            )
        case let .reminderDue(title, body):
            let reminderTitle = localization.string("notification.reminderDefault")
            if let body, !body.isEmpty {
                (reminderTitle, "\(title)\n\(body)")
            } else {
                (reminderTitle, title)
            }
        }
    }

    private func pomodoroCompletionMessage(for phase: PomodoroPhase) -> String {
        switch phase {
        case .focus:
            localization.string("notification.pomodoroFocusFinished")
        case .shortBreak:
            localization.string("notification.pomodoroShortBreakFinished")
        case .longBreak:
            localization.string("notification.pomodoroLongBreakFinished")
        }
    }
}
