import AppKit

struct DesktopCharacterMenuConfiguration: Equatable {
    let isVisible: Bool
    let isAutonomousMovementEnabled: Bool
}

@MainActor
final class DesktopCharacterMenuController: NSObject {
    let item = NSMenuItem(
        title: "Desktop Character",
        action: nil,
        keyEquivalent: ""
    )

    var onConfigurationChanged: ((DesktopCharacterMenuConfiguration) -> Void)?

    private let visibilityItem = NSMenuItem(
        title: "Show on Desktop",
        action: nil,
        keyEquivalent: ""
    )
    private let autonomousMovementItem = NSMenuItem(
        title: "Move Automatically",
        action: nil,
        keyEquivalent: ""
    )

    override init() {
        super.init()

        visibilityItem.target = self
        visibilityItem.action = #selector(toggleVisibility)
        visibilityItem.state = .off

        autonomousMovementItem.target = self
        autonomousMovementItem.action = #selector(toggleAutonomousMovement)
        autonomousMovementItem.state = .off
        autonomousMovementItem.isEnabled = false

        let submenu = NSMenu(title: "Desktop Character")
        submenu.addItem(visibilityItem)
        submenu.addItem(autonomousMovementItem)
        item.submenu = submenu
    }

    @objc
    private func toggleVisibility() {
        let isVisible = visibilityItem.state != .on
        visibilityItem.state = isVisible ? .on : .off
        autonomousMovementItem.isEnabled = isVisible

        if !isVisible {
            autonomousMovementItem.state = .off
        }

        publishConfiguration()
    }

    @objc
    private func toggleAutonomousMovement() {
        guard visibilityItem.state == .on else {
            return
        }

        let isEnabled = autonomousMovementItem.state != .on
        autonomousMovementItem.state = isEnabled ? .on : .off
        publishConfiguration()
    }

    private func publishConfiguration() {
        onConfigurationChanged?(
            DesktopCharacterMenuConfiguration(
                isVisible: visibilityItem.state == .on,
                isAutonomousMovementEnabled: autonomousMovementItem.state == .on
            )
        )
    }
}
