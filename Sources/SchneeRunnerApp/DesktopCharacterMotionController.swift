import Foundation
import SchneeRunnerCore

@MainActor
final class DesktopCharacterMotionController: NSObject {
    private static let timerInterval = 1.0 / 30.0

    private let renderer: DesktopCharacterRenderer
    private let policy: DesktopMotionPolicy

    private var timer: Timer?
    private var direction: DesktopMotionDirection = .right
    private var lastTimestamp: TimeInterval?

    private(set) var isEnabled = false

    init(
        renderer: DesktopCharacterRenderer,
        policy: DesktopMotionPolicy = .init()
    ) {
        self.renderer = renderer
        self.policy = policy
        super.init()
    }

    func setEnabled(_ isEnabled: Bool) {
        guard self.isEnabled != isEnabled else {
            return
        }

        self.isEnabled = isEnabled

        if isEnabled {
            start()
        } else {
            stop()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastTimestamp = nil
        renderer.setAutonomousMovementActive(false)
        isEnabled = false
    }

    private func start() {
        guard
            timer == nil,
            renderer.motionGeometry != nil
        else {
            isEnabled = false
            return
        }

        renderer.setAutonomousMovementActive(true)
        renderer.setMotionDirection(direction)
        lastTimestamp = ProcessInfo.processInfo.systemUptime

        let timer = Timer.scheduledTimer(
            timeInterval: Self.timerInterval,
            target: self,
            selector: #selector(advance),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = Self.timerInterval * 0.2
        self.timer = timer
    }

    @objc
    private func advance() {
        guard
            isEnabled,
            let geometry = renderer.motionGeometry
        else {
            return
        }

        let timestamp = ProcessInfo.processInfo.systemUptime
        let elapsed = lastTimestamp.map {
            timestamp - $0
        } ?? 0
        lastTimestamp = timestamp

        let nextState = policy.advance(
            state: DesktopMotionState(
                x: geometry.originX,
                direction: direction
            ),
            windowWidth: geometry.windowWidth,
            visibleMinX: geometry.visibleMinX,
            visibleMaxX: geometry.visibleMaxX,
            elapsedSeconds: elapsed
        )

        if nextState.direction != direction {
            renderer.setMotionDirection(nextState.direction)
        }
        direction = nextState.direction
        renderer.moveHorizontally(
            to: nextState.x
        )
    }
}
