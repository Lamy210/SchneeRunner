import Foundation

public enum AnimationScheduleError: Error, Equatable, LocalizedError {
    case invalidFrameCount(Int)
    case invalidFramesPerSecond(Double)
    case invalidPlaybackRate(Double)
    case invalidFrameDuration(index: Int, duration: Double)

    public var errorDescription: String? {
        switch self {
        case let .invalidFrameCount(count):
            "Animation schedules require at least one frame. Received \(count)."
        case let .invalidFramesPerSecond(value):
            "Animation FPS must be finite and greater than zero. Received \(value)."
        case let .invalidPlaybackRate(value):
            "Animation playback rate must be finite and greater than zero. Received \(value)."
        case let .invalidFrameDuration(index, duration):
            "Animation frame \(index) has invalid duration \(duration)."
        }
    }
}

public struct AnimationSchedule: Equatable, Sendable {
    public let frameDurations: [Double]

    public var frameCount: Int {
        frameDurations.count
    }

    public var totalDuration: Double {
        frameDurations.reduce(0, +)
    }

    public init(frameDurations: [Double]) throws {
        guard !frameDurations.isEmpty else {
            throw AnimationScheduleError.invalidFrameCount(0)
        }

        for (index, duration) in frameDurations.enumerated() {
            guard duration.isFinite, duration > 0 else {
                throw AnimationScheduleError.invalidFrameDuration(
                    index: index,
                    duration: duration
                )
            }
        }

        self.frameDurations = frameDurations
    }

    public static func uniform(
        frameCount: Int,
        framesPerSecond: Double
    ) throws -> AnimationSchedule {
        guard frameCount > 0 else {
            throw AnimationScheduleError.invalidFrameCount(frameCount)
        }
        guard
            framesPerSecond.isFinite,
            framesPerSecond > 0
        else {
            throw AnimationScheduleError.invalidFramesPerSecond(
                framesPerSecond
            )
        }

        return try AnimationSchedule(
            frameDurations: Array(
                repeating: 1 / framesPerSecond,
                count: frameCount
            )
        )
    }

    public func scaled(
        by playbackRate: Double
    ) throws -> AnimationSchedule {
        guard
            playbackRate.isFinite,
            playbackRate > 0
        else {
            throw AnimationScheduleError.invalidPlaybackRate(
                playbackRate
            )
        }

        return try AnimationSchedule(
            frameDurations: frameDurations.map {
                $0 / playbackRate
            }
        )
    }

    public func duration(at index: Int) -> Double? {
        guard frameDurations.indices.contains(index) else {
            return nil
        }

        return frameDurations[index]
    }
}
