import AppKit

@MainActor
final class CharacterFrameRendererCoordinator {
    private let desktopRenderer: DesktopCharacterRenderer
    private let desktopMotionController: DesktopCharacterMotionController

    private weak var statusButton: NSStatusBarButton?

    init() {
        let desktopRenderer = DesktopCharacterRenderer()
        self.desktopRenderer = desktopRenderer
        desktopMotionController = DesktopCharacterMotionController(
            renderer: desktopRenderer
        )
    }

    func bind(statusItem: NSStatusItem) {
        statusButton = statusItem.button
    }

    func render(_ image: NSImage) {
        statusButton?.image = Self.menuBarImage(
            from: image
        )
        desktopRenderer.render(image)
    }

    func setDesktopConfiguration(
        _ configuration: DesktopCharacterMenuConfiguration
    ) {
        desktopMotionController.setSpeedPointsPerSecond(
            configuration.movementSpeed.pointsPerSecond
        )
        desktopRenderer.setClickThrough(
            configuration.isClickThroughEnabled
        )

        if configuration.isVisible {
            desktopRenderer.setVisible(true)
            desktopMotionController.setEnabled(
                configuration.isAutonomousMovementEnabled
            )
        } else {
            desktopMotionController.setEnabled(false)
            desktopRenderer.setVisible(false)
        }
    }

    func resetDesktopPlacement() {
        desktopRenderer.resetPlacement()
    }

    func stop() {
        desktopMotionController.stop()
        desktopRenderer.stop()
    }

    private static func menuBarImage(
        from source: NSImage
    ) -> NSImage {
        let image = source.copy() as? NSImage ?? source
        let sourceWidth = max(source.size.width, 1)
        let sourceHeight = max(source.size.height, 1)
        let maximumWidth: CGFloat = 36
        let maximumHeight: CGFloat = 22
        let scale = min(
            maximumWidth / sourceWidth,
            maximumHeight / sourceHeight
        )

        image.size = NSSize(
            width: sourceWidth * scale,
            height: sourceHeight * scale
        )
        image.isTemplate = false
        return image
    }
}
