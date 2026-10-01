import AppKit

@MainActor
final class CharacterFrameRendererCoordinator {
    private let desktopRenderer = DesktopCharacterRenderer()

    private weak var statusButton: NSStatusBarButton?

    func bind(statusItem: NSStatusItem) {
        statusButton = statusItem.button
    }

    func render(_ image: NSImage) {
        statusButton?.image = Self.menuBarImage(
            from: image
        )
        desktopRenderer.render(image)
    }

    func setDesktopVisible(_ isVisible: Bool) {
        desktopRenderer.setVisible(isVisible)
    }

    func stop() {
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
