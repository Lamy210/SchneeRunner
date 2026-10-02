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
    let isClickThroughEnabled: Bool
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
    var onResetPlacement: (() -> Void)?

    var configuration: DesktopCharacterMenuConfiguration {
        DesktopCharacterMenuConfiguration(
            isVisible: visibilityItem.state == .on,
            isAutonomousMovementEnabled: autonomousMovementItem.state == .on,
            isClickThroughEnabled: clickThroughItem.state == .on,
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
    private let clickThroughItem = NSMenuItem(
        title: "Click Through",
        action: nil,
        keyEquivalent: ""
    )
    private let resetPlacementItem = NSMenuItem(
        title: "Reset Position & Size",
        action: nil,
        keyEquivalent: ""
    )

    private let visibilityStore: DesktopCharacterVisibilityStore
    private let movementSpeedStore: DesktopMotionSpeedPreferenceStore
    private let clickThroughStore: DesktopClickThroughStore
    private var movementSpeed: DesktopMotionSpeedPreset

    init(
        visibilityStore: DesktopCharacterVisibilityStore = .init(),
        movementSpeedStore: DesktopMotionSpeedPreferenceStore = .init(),
        clickThroughStore: DesktopClickThroughStore = .init()
    ) {
        self.visibilityStore = visibilityStore
        self.movementSpeedStore = movementSpeedStore
        self.clickThroughStore = clickThroughStore
        movementSpeed = movementSpeedStore.preset()
        let isVisible = visibilityStore.isVisible()
        let isClickThroughEnabled = clickThroughStore.isEnabled()
        super.init()

        configureVisibilityItem(isVisible: isVisible)
        configureAutonomousMovementItem(isVisible: isVisible)
        configureMovementSpeedItem(isVisible: isVisible)
        configureClickThroughItem(
            isVisible: isVisible,
            isEnabled: isClickThroughEnabled
        )
        configureResetPlacementItem()

        let submenu = NSMenu(title: "Desktop Character")
        submenu.addItem(visibilityItem)
        submenu.addItem(autonomousMovementItem)
        submenu.addItem(movementSpeedItem)
        submenu.addItem(clickThroughItem)
        submenu.addItem(.separator())
        submenu.addItem(resetPlacementItem)
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

    private func configureClickThroughItem(
        isVisible: Bool,
        isEnabled: Bool
    ) {
        clickThroughItem.target = self
        clickThroughItem.action = #selector(toggleClickThrough)
        clickThroughItem.state = isEnabled ? .on : .off
        clickThroughItem.isEnabled = isVisible
    }

    private func configureResetPlacementItem() {
        resetPlacementItem.target = self
        resetPlacementItem.action = #selector(resetPlacement)
    }

    @objc
    private func toggleVisibility() {
        let isVisible = visibilityItem.state != .on
        visibilityItem.state = isVisible ? .on : .off
        autonomousMovementItem.isEnabled = isVisible
        movementSpeedItem.isEnabled = isVisible
        clickThroughItem.isEnabled = isVisible
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
    private func toggleClickThrough() {
        guard visibilityItem.state == .on else {
            return
        }

        let isEnabled = clickThroughItem.state != .on
        clickThroughItem.state = isEnabled ? .on : .off
        clickThroughStore.save(isEnabled)
        publishConfiguration()
    }

    @objc
    private func resetPlacement() {
        onResetPlacement?()
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
