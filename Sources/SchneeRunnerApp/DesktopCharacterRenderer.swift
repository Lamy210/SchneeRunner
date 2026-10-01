import AppKit

@MainActor
final class DesktopCharacterRenderer {
    private static let windowSize = NSSize(
        width: 128,
        height: 128
    )

    private let imageView = NSImageView()
    private var panel: NSPanel?
    private var latestImage: NSImage?

    private(set) var isVisible = false

    init() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [
            .width,
            .height
        ]
    }

    func render(_ image: NSImage) {
        latestImage = image
        imageView.image = image
    }

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible

        if isVisible {
            let panel = panel ?? makePanel()
            panel.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
    }

    func stop() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        isVisible = false
    }

    private func makePanel() -> NSPanel {
        let origin = Self.initialOrigin(
            windowSize: Self.windowSize
        )
        let frame = NSRect(
            origin: origin,
            size: Self.windowSize
        )
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [
                .borderless,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]
        panel.isReleasedWhenClosed = false

        imageView.frame = NSRect(
            origin: .zero,
            size: Self.windowSize
        )
        imageView.image = latestImage
        panel.contentView = imageView

        self.panel = panel
        return panel
    }

    private static func initialOrigin(
        windowSize: NSSize
    ) -> NSPoint {
        guard let screen = NSScreen.main else {
            return NSPoint(
                x: 24,
                y: 24
            )
        }

        let visibleFrame = screen.visibleFrame
        return NSPoint(
            x: visibleFrame.maxX - windowSize.width - 24,
            y: visibleFrame.minY + 24
        )
    }
}
