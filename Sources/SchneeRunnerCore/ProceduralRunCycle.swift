import Foundation

struct ProceduralMotionFrame: Equatable, Sendable {
    let lift: CGFloat
    let rotationDegrees: CGFloat
    let horizontalScale: CGFloat
    let verticalScale: CGFloat
}

enum ProceduralRunCycle {
    static let frames: [ProceduralMotionFrame] = [
        ProceduralMotionFrame(
            lift: 0,
            rotationDegrees: -1.5,
            horizontalScale: 1.02,
            verticalScale: 0.98
        ),
        ProceduralMotionFrame(
            lift: -0.015,
            rotationDegrees: -2.5,
            horizontalScale: 1.04,
            verticalScale: 0.94
        ),
        ProceduralMotionFrame(
            lift: 0.035,
            rotationDegrees: 0.5,
            horizontalScale: 0.99,
            verticalScale: 1.02
        ),
        ProceduralMotionFrame(
            lift: 0.075,
            rotationDegrees: 1.8,
            horizontalScale: 0.97,
            verticalScale: 1.04
        ),
        ProceduralMotionFrame(
            lift: 0,
            rotationDegrees: 1.5,
            horizontalScale: 1.02,
            verticalScale: 0.98
        ),
        ProceduralMotionFrame(
            lift: -0.015,
            rotationDegrees: 2.5,
            horizontalScale: 1.04,
            verticalScale: 0.94
        ),
        ProceduralMotionFrame(
            lift: 0.035,
            rotationDegrees: -0.5,
            horizontalScale: 0.99,
            verticalScale: 1.02
        ),
        ProceduralMotionFrame(
            lift: 0.075,
            rotationDegrees: -1.8,
            horizontalScale: 0.97,
            verticalScale: 1.04
        )
    ]
}
