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

    var configuration: DesktopCharacterMenuConfiguration {
        DesktopCharacterMenuConfiguration(
            isVisible: visibilityItem.state == .on,
            isAutonomousMovementEnabled: autonomousMovementItem.state == .on,
            movementSpeed: movementSpeed
        )
    }

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

    private let visibilityStore: DesktopCharacterVisibilityPreferenceStore
    private let movementSpeedStore: DesktopMotionSpeedPreferenceStore
    private var movementSpeed: DesktopMotionSpeedPreset

    init(
        visibilityStore: DesktopCharacterVisibilityPreferenceStore = .init(),
        movementSpeedStore: DesktopMotionSpeedPreferenceStore = .init()
    ) {
        self.visibilityStore = visibilityStore
        self.movementSpeedStore = movementSpeedStore
        movementSpeed = movementSpeedStore.preset()
        let isVisible = visibilityStore.isVisible()
        super.init()

        configureVisibilityItem(isVisible: isVisible)
        configureAutonomousMovementItem(isVisible: isVisible)
        configureMovementSpeedItem(isVisible: isVisible)

        let submenu = NSMenu(title: "Desktop Character")
        submenu.addItem(visibilityItem)
        submenu.addItem(autonomousMovementItem)
        submenu.addItem(movementSpeedItem)
        item.submenu = submenu
    }

    private func configureVisibilityItem(isVisible: Bool) {
        visibilityItem.target = self
        visibilityItem.action = #selector(toggleVisibility)
        visibilityItem.state = isVisible ? .on : .off
    }

    private func configureAutonomousMovementItem(isVisible: Bool) {
        autonomousMovementItem.target = self
        autonomousMovementItem.action = #selector(toggleAutonomousMovement)
        autonomousMovementItem.state = .off
        autonomousMovementItem.isEnabled = isVisible
    }

    private func configureMovementSpeedItem(isVisible: Bool) {
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
        movementSpeedItem.isEnabled = isVisible
    }

    @objc
    private func toggleVisibility() {
        let isVisible = visibilityItem.state != .on
        visibilityItem.state = isVisible ? .on : .off
        autonomousMovementItem.isEnabled = isVisible
        movementSpeedItem.isEnabled = isVisible
        visibilityStore.save(isVisible)

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
        onConfigurationChanged?(configuration)
    }
}
