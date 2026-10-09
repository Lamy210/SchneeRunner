import AppKit
import SchneeRunnerCore

@MainActor
final class AppKitProductivityFallbackPresenter: NSObject, ProductivityFallbackPresenting, NSWindowDelegate {
    private var panels: [NSPanel] = []

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
            label.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
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

    private func presentationContent(
        for event: ProductivityFallbackEvent
    ) -> (title: String, message: String) {
        switch event {
        case let .timerCompleted(title):
            ("Timer finished", title)
        case let .pomodoroPhaseCompleted(phase):
            ("Pomodoro", pomodoroCompletionMessage(for: phase))
        case let .reminderDue(title, body):
            if let body, !body.isEmpty {
                ("Reminder", "\(title)\n\(body)")
            } else {
                ("Reminder", title)
            }
        }
    }

    private func pomodoroCompletionMessage(for phase: PomodoroPhase) -> String {
        switch phase {
        case .focus:
            "Focus finished"
        case .shortBreak:
            "Short break finished"
        case .longBreak:
            "Long break finished"
        }
    }
}
