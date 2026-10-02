import AppKit
import SchneeRunnerCore

@MainActor
struct DesktopWindowPlacementController {
    private static let defaultWindowSize = NSSize(
        width: 128,
        height: 128
    )

    let minimumWindowSize = NSSize(
        width: CGFloat(DesktopCharacterPlacement.minimumDimension),
        height: CGFloat(DesktopCharacterPlacement.minimumDimension)
    )
    let maximumWindowSize = NSSize(
        width: CGFloat(DesktopCharacterPlacement.maximumDimension),
        height: CGFloat(DesktopCharacterPlacement.maximumDimension)
    )

    private let placementStore: DesktopCharacterPlacementStore

    init(
        placementStore: DesktopCharacterPlacementStore = .init()
    ) {
        self.placementStore = placementStore
    }

    func restoredFrame() -> NSRect? {
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

        return constrain(
            storedFrame,
            to: screen.visibleFrame
        )
    }

    func defaultFrame() -> NSRect {
        let size = Self.defaultWindowSize
        let origin = Self.initialOrigin(
            windowSize: size
        )

        return NSRect(
            origin: origin,
            size: size
        )
    }

    func persist(_ frame: NSRect) {
        placementStore.save(
            DesktopCharacterPlacement(
                x: Double(frame.origin.x),
                y: Double(frame.origin.y),
                width: Double(frame.width),
                height: Double(frame.height)
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

    private func constrain(
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
