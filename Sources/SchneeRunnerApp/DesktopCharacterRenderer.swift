import AppKit
import SchneeRunnerCore

private final class DesktopCharacterPanel: NSPanel {
    var onPointerInteractionChanged: ((Bool) -> Void)?

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            onPointerInteractionChanged?(true)
        case .leftMouseUp:
            onPointerInteractionChanged?(false)
        default:
            break
        }

        super.sendEvent(event)
    }
}

private final class DesktopCharacterImageView: NSImageView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}

struct DesktopCharacterMotionGeometry: Equatable {
    let originX: Double
    let windowWidth: Double
    let visibleMinX: Double
    let visibleMaxX: Double
}

@MainActor
final class DesktopCharacterRenderer: NSObject, NSWindowDelegate {
    private let imageView = DesktopCharacterImageView()
    private let placementController: DesktopWindowPlacementController

    private var panel: NSPanel?
    private var latestImage: NSImage?
    private var isAutonomousMovementActive = false
    private var isApplyingManagedFrame = false
    private var isClickThroughEnabled = false
    private var isLiveResizing = false
    private var isMovePersistenceDeferred = false

    private(set) var isVisible = false
    private(set) var isUserInteracting = false

    init(
        placementStore: DesktopCharacterPlacementStore = .init()
    ) {
        placementController = DesktopWindowPlacementController(
            placementStore: placementStore
        )
        super.init()

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [
            .width,
            .height
        ]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func render(_ image: NSImage) {
        latestImage = image
        imageView.image = image
    }

    func setClickThrough(_ isEnabled: Bool) {
        isClickThroughEnabled = isEnabled
        if isEnabled {
            setUserInteracting(false)
        }
        panel?.ignoresMouseEvents = isEnabled
    }

    func resetPlacement() {
        let frame = placementController.defaultFrame()

        isApplyingManagedFrame = true
        panel?.setFrame(
            frame,
            display: true
        )
        isApplyingManagedFrame = false
        placementController.persist(frame)
    }

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible

        if isVisible {
            let panel = panel ?? makePanel()
            panel.orderFrontRegardless()
        } else {
            setUserInteracting(false)
            isLiveResizing = false
            isMovePersistenceDeferred = false
            panel?.orderOut(nil)
        }
    }

    var motionGeometry: DesktopCharacterMotionGeometry? {
        guard
            let panel,
            let screen = panel.screen ?? NSScreen.main
        else {
            return nil
        }

        return DesktopCharacterMotionGeometry(
            originX: Double(panel.frame.minX),
            windowWidth: Double(panel.frame.width),
            visibleMinX: Double(screen.visibleFrame.minX),
            visibleMaxX: Double(screen.visibleFrame.maxX)
        )
    }

    func moveHorizontally(to x: Double) {
        guard let panel else {
            return
        }

        panel.setFrameOrigin(
            NSPoint(
                x: CGFloat(x),
                y: panel.frame.minY
            )
        )
    }

    func setMotionDirection(_ direction: DesktopMotionDirection) {
        imageView.wantsLayer = true
        let transform: CGAffineTransform = switch direction {
        case .left:
            CGAffineTransform(scaleX: -1, y: 1)
        case .right:
            .identity
        }
        imageView.layer?.setAffineTransform(transform)
    }

    func setAutonomousMovementActive(_ isActive: Bool) {
        isAutonomousMovementActive = isActive

        if !isActive {
            persistCurrentFrame()
        }
    }

    func stop() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        isAutonomousMovementActive = false
        isUserInteracting = false
        isLiveResizing = false
        isMovePersistenceDeferred = false
        persistCurrentFrame()
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        isVisible = false
    }

    func windowDidMove(_ notification: Notification) {
        guard
            !isAutonomousMovementActive,
            !isApplyingManagedFrame
        else {
            return
        }

        if isUserInteracting {
            isMovePersistenceDeferred = true
            return
        }

        persistFrame(from: notification)
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        guard isPanelNotification(notification) else {
            return
        }

        isLiveResizing = true
    }

    func windowDidResize(_ notification: Notification) {
        guard
            !isApplyingManagedFrame,
            !isLiveResizing
        else {
            return
        }

        persistFrame(from: notification)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard
            let window = panelWindow(from: notification)
        else {
            return
        }

        isLiveResizing = false
        isMovePersistenceDeferred = false
        persistFrame(window.frame)
    }

    @objc
    private func screenParametersDidChange(_: Notification) {
        guard
            let panel,
            let recoveredFrame = placementController.recoveredFrame(panel.frame),
            recoveredFrame != panel.frame
        else {
            return
        }

        isApplyingManagedFrame = true
        panel.setFrame(
            recoveredFrame,
            display: true
        )
        isApplyingManagedFrame = false
        placementController.persist(recoveredFrame)
    }

    private func makePanel() -> NSPanel {
        let frame = placementController.restoredFrame()
            ?? placementController.defaultFrame()
        let panel = DesktopCharacterPanel(
            contentRect: frame,
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        panel.onPointerInteractionChanged = { [weak self] isInteracting in
            self?.setUserInteracting(isInteracting)
        }
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
        panel.ignoresMouseEvents = isClickThroughEnabled
        panel.minSize = placementController.minimumWindowSize
        panel.maxSize = placementController.maximumWindowSize
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

    private func setUserInteracting(_ isInteracting: Bool) {
        let wasInteracting = isUserInteracting
        isUserInteracting = isInteracting

        let shouldPersistDeferredMove =
            wasInteracting
                && !isInteracting
                && isMovePersistenceDeferred
                && !isLiveResizing
                && !isAutonomousMovementActive

        if shouldPersistDeferredMove {
            isMovePersistenceDeferred = false
            persistCurrentFrame()
        }
    }

    private func isPanelNotification(_ notification: Notification) -> Bool {
        panelWindow(from: notification) != nil
    }

    private func panelWindow(
        from notification: Notification
    ) -> NSWindow? {
        guard
            let window = notification.object as? NSWindow,
            window === panel
        else {
            return nil
        }

        return window
    }

    private func persistFrame(from notification: Notification) {
        guard let window = panelWindow(from: notification) else {
            return
        }

        persistFrame(window.frame)
    }

    private func persistCurrentFrame() {
        guard let panel else {
            return
        }

        persistFrame(panel.frame)
    }

    private func persistFrame(_ frame: NSRect) {
        placementController.persist(frame)
    }
}
