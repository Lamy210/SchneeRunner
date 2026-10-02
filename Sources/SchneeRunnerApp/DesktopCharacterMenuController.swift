import AppKit
import SchneeRunnerCore

private extension DesktopMotionSpeedPreset {
    var menuTitle: String {
        switch self {
        case .slow:
            "Slow"
        case .normal:
            "Normal"
        case .fast:
            "Fast"
        }
    }
}

struct DesktopCharacterMenuConfiguration: Equatable {
    let isVisible: Bool
    let isAutonomousMovementEnabled: Bool
    let movementSpeed: DesktopMotionSpeedPreset
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
    private let movementSpeedItem = NSMenuItem(
        title: "Movement Speed",
        action: nil,
        keyEquivalent: ""
    )

    private let movementSpeedStore: DesktopMotionSpeedPreferenceStore
    private var movementSpeed: DesktopMotionSpeedPreset

    init(
        movementSpeedStore: DesktopMotionSpeedPreferenceStore = .init()
    ) {
        self.movementSpeedStore = movementSpeedStore
        movementSpeed = movementSpeedStore.preset()
        super.init()

        configureVisibilityItem()
        configureAutonomousMovementItem()
        configureMovementSpeedItem()

        let submenu = NSMenu(title: "Desktop Character")
        submenu.addItem(visibilityItem)
        submenu.addItem(autonomousMovementItem)
        submenu.addItem(movementSpeedItem)
        item.submenu = submenu
    }

    private func configureVisibilityItem() {
        visibilityItem.target = self
        visibilityItem.action = #selector(toggleVisibility)
        visibilityItem.state = .off
    }

    private func configureAutonomousMovementItem() {
        autonomousMovementItem.target = self
        autonomousMovementItem.action = #selector(toggleAutonomousMovement)
        autonomousMovementItem.state = .off
        autonomousMovementItem.isEnabled = false
    }

    private func configureMovementSpeedItem() {
        let speedMenu = NSMenu(title: "Movement Speed")

        for speed in DesktopMotionSpeedPreset.allCases {
            let speedItem = NSMenuItem(
                title: speed.menuTitle,
                action: #selector(selectMovementSpeed(_:)),
                keyEquivalent: ""
            )
            speedItem.target = self
            speedItem.representedObject = speed.rawValue
            speedItem.state = speed == movementSpeed ? .on : .off
            speedMenu.addItem(speedItem)
        }

        movementSpeedItem.submenu = speedMenu
        movementSpeedItem.isEnabled = false
    }

    @objc
    private func toggleVisibility() {
        let isVisible = visibilityItem.state != .on
        visibilityItem.state = isVisible ? .on : .off
        autonomousMovementItem.isEnabled = isVisible
        movementSpeedItem.isEnabled = isVisible

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

    @objc
    private func selectMovementSpeed(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let speed = DesktopMotionSpeedPreset(rawValue: rawValue)
        else {
            return
        }

        movementSpeed = speed
        movementSpeedStore.save(speed)
        refreshMovementSpeedSelection()
        publishConfiguration()
    }

    private func refreshMovementSpeedSelection() {
        for item in movementSpeedItem.submenu?.items ?? [] {
            let isSelected = item.representedObject as? String == movementSpeed.rawValue
            item.state = isSelected ? .on : .off
        }
    }

    private func publishConfiguration() {
        onConfigurationChanged?(
            DesktopCharacterMenuConfiguration(
                isVisible: visibilityItem.state == .on,
                isAutonomousMovementEnabled: autonomousMovementItem.state == .on,
                movementSpeed: movementSpeed
            )
        )
    }
}
