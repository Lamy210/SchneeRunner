import Foundation

public enum DesktopMotionDirection: Equatable, Sendable {
    case left
    case right
}

public struct DesktopMotionState: Equatable, Sendable {
    public let x: Double
    public let direction: DesktopMotionDirection

    public init(
        x: Double,
        direction: DesktopMotionDirection
    ) {
        self.x = x
        self.direction = direction
    }
}

public struct DesktopMotionPolicy: Sendable {
    public static let defaultSpeedPointsPerSecond = 72.0
    public static let maximumElapsedSeconds = 0.1

    private let speedPointsPerSecond: Double

    public init(
        speedPointsPerSecond: Double = Self.defaultSpeedPointsPerSecond
    ) {
        let isValidSpeed =
            speedPointsPerSecond.isFinite
                && speedPointsPerSecond > 0

        if isValidSpeed {
            self.speedPointsPerSecond = speedPointsPerSecond
        } else {
            self.speedPointsPerSecond = Self.defaultSpeedPointsPerSecond
        }
    }

    public func advance(
        state: DesktopMotionState,
        windowWidth: Double,
        visibleMinX: Double,
        visibleMaxX: Double,
        elapsedSeconds: Double
    ) -> DesktopMotionState {
        guard
            state.x.isFinite,
            windowWidth.isFinite,
            windowWidth > 0,
            visibleMinX.isFinite,
            visibleMaxX.isFinite,
            visibleMaxX > visibleMinX,
            elapsedSeconds.isFinite
        else {
            return state
        }

        let minimumX = visibleMinX
        let maximumX = max(
            minimumX,
            visibleMaxX - windowWidth
        )
        let clampedX = min(
            max(state.x, minimumX),
            maximumX
        )
        let range = maximumX - minimumX

        guard range > 0 else {
            return DesktopMotionState(
                x: minimumX,
                direction: state.direction
            )
        }

        let elapsed = min(
            max(elapsedSeconds, 0),
            Self.maximumElapsedSeconds
        )
        let distance = speedPointsPerSecond * elapsed
        let relativeX = clampedX - minimumX
        let cycleLength = range * 2
        let phase = switch state.direction {
        case .right:
            relativeX
        case .left:
            cycleLength - relativeX
        }
        let nextPhase = (phase + distance)
            .truncatingRemainder(
                dividingBy: cycleLength
            )

        if nextPhase < range {
            return DesktopMotionState(
                x: minimumX + nextPhase,
                direction: .right
            )
        }

        return DesktopMotionState(
            x: minimumX + cycleLength - nextPhase,
            direction: .left
        )
    }
}
