import AppKit
import SchneeRunnerCore

private final class DesktopCharacterImageView: NSImageView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}

@MainActor
final class DesktopCharacterRenderer: NSObject, NSWindowDelegate {
    private static let defaultWindowSize = NSSize(
        width: 128,
        height: 128
    )
    private static let minimumWindowSize = NSSize(
        width: DesktopCharacterPlacement.minimumDimension,
        height: DesktopCharacterPlacement.minimumDimension
    )
    private static let maximumWindowSize = NSSize(
        width: DesktopCharacterPlacement.maximumDimension,
        height: DesktopCharacterPlacement.maximumDimension
    )

    private let imageView = DesktopCharacterImageView()
    private let placementStore: DesktopCharacterPlacementStore

    private var panel: NSPanel?
    private var latestImage: NSImage?

    private(set) var isVisible = false

    init(
        placementStore: DesktopCharacterPlacementStore = .init()
    ) {
        self.placementStore = placementStore
        super.init()

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
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        isVisible = false
    }

    func windowDidMove(_ notification: Notification) {
        persistFrame(from: notification)
    }

    func windowDidResize(_ notification: Notification) {
        persistFrame(from: notification)
    }

    private func makePanel() -> NSPanel {
        let frame = restoredFrame() ?? defaultFrame()
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .resizable
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
        panel.minSize = Self.minimumWindowSize
        panel.maxSize = Self.maximumWindowSize
        panel.contentAspectRatio = NSSize(
            width: 1,
            height: 1
        )
        panel.delegate = self

        imageView.frame = NSRect(
            origin: .zero,
            size: frame.size
        )
        imageView.image = latestImage
        panel.contentView = imageView

        self.panel = panel
        return panel
    }

    private func restoredFrame() -> NSRect? {
        guard let placement = placementStore.placement() else {
            return nil
        }

        let storedFrame = NSRect(
            x: placement.x,
            y: placement.y,
            width: placement.width,
            height: placement.height
        )
        guard let screen = Self.bestScreen(for: storedFrame) else {
            return nil
        }

        return Self.constrain(
            storedFrame,
            to: screen.visibleFrame
        )
    }

    private func defaultFrame() -> NSRect {
        let size = Self.defaultWindowSize
        let origin = Self.initialOrigin(
            windowSize: size
        )

        return NSRect(
            origin: origin,
            size: size
        )
    }

    private func persistFrame(from notification: Notification) {
        guard
            let window = notification.object as? NSWindow,
            window === panel
        else {
            return
        }

        let frame = window.frame
        placementStore.save(
            DesktopCharacterPlacement(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.width,
                height: frame.height
            )
        )
    }

    private static func bestScreen(
        for frame: NSRect
    ) -> NSScreen? {
        let candidates = NSScreen.screens
            .map { screen in
                (
                    screen: screen,
                    area: intersectionArea(
                        frame,
                        screen.visibleFrame
                    )
                )
            }
            .filter { $0.area > 0 }

        return candidates.max { lhs, rhs in
            lhs.area < rhs.area
        }?.screen
    }

    private static func intersectionArea(
        _ lhs: NSRect,
        _ rhs: NSRect
    ) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else {
            return 0
        }

        return intersection.width * intersection.height
    }

    private static func constrain(
        _ frame: NSRect,
        to visibleFrame: NSRect
    ) -> NSRect {
        let maximumWidth = min(
            maximumWindowSize.width,
            visibleFrame.width
        )
        let maximumHeight = min(
            maximumWindowSize.height,
            visibleFrame.height
        )
        let width = min(
            max(frame.width, minimumWindowSize.width),
            maximumWidth
        )
        let height = min(
            max(frame.height, minimumWindowSize.height),
            maximumHeight
        )
        let x = min(
            max(frame.minX, visibleFrame.minX),
            visibleFrame.maxX - width
        )
        let y = min(
            max(frame.minY, visibleFrame.minY),
            visibleFrame.maxY - height
        )

        return NSRect(
            x: x,
            y: y,
            width: width,
            height: height
        )
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
