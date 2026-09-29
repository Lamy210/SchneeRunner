import AppKit

public enum LoadedAnimationError: Error, Equatable, LocalizedError {
    case frameCountMismatch(images: Int, schedule: Int)

    public var errorDescription: String? {
        switch self {
        case let .frameCountMismatch(images, schedule):
            "Animation has \(images) images but \(schedule) scheduled frames."
        }
    }
}

public struct LoadedAnimation {
    public let frames: [NSImage]
    public let schedule: AnimationSchedule

    public init(
        frames: [NSImage],
        schedule: AnimationSchedule
    ) throws {
        guard frames.count == schedule.frameCount else {
            throw LoadedAnimationError.frameCountMismatch(
                images: frames.count,
                schedule: schedule.frameCount
            )
        }

        self.frames = frames
        self.schedule = schedule
    }

    public static func uniform(
        frames: [NSImage],
        framesPerSecond: Double = 12
    ) throws -> LoadedAnimation {
        let schedule = try AnimationSchedule.uniform(
            frameCount: frames.count,
            framesPerSecond: framesPerSecond
        )

        return try LoadedAnimation(
            frames: frames,
            schedule: schedule
        )
    }
}
