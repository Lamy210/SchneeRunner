import AppKit
import SchneeRunnerCore

@MainActor
final class TimerManagementRowView: NSStackView {
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    var onCancel: (() -> Void)?

    init(timer: ProductivityCountdownTimer) {
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = 8

        let title = NSTextField(labelWithString: timer.title)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addArrangedSubview(title)

        let stateTitle = switch timer.state {
        case .running:
            "Running"
        case .paused:
            "Paused"
        case .completed:
            "Completed"
        case .cancelled:
            "Cancelled"
        }
        let state = NSTextField(labelWithString: stateTitle)
        state.textColor = .secondaryLabelColor
        addArrangedSubview(state)

        switch timer.state {
        case .running:
            addArrangedSubview(
                button(title: "Pause", action: #selector(pause))
            )
        case .paused:
            addArrangedSubview(
                button(title: "Resume", action: #selector(resume))
            )
        case .completed, .cancelled:
            break
        }

        if timer.state == .running || timer.state == .paused {
            addArrangedSubview(
                button(title: "Cancel", action: #selector(cancel))
            )
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func button(
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
    private func pause() {
        onPause?()
    }

    @objc
    private func resume() {
        onResume?()
    }

    @objc
    private func cancel() {
        onCancel?()
    }
}
