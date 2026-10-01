import AppKit

@MainActor
final class DesktopCharacterMenuController: NSObject {
    let item = NSMenuItem(
        title: "Show Desktop Character",
        action: nil,
        keyEquivalent: ""
    )

    var onVisibilityChanged: ((Bool) -> Void)?

    override init() {
        super.init()

        item.target = self
        item.action = #selector(toggleVisibility)
        item.state = .off
    }

    @objc
    private func toggleVisibility() {
        let isVisible = item.state != .on
        item.state = isVisible ? .on : .off
        onVisibilityChanged?(isVisible)
    }
}
