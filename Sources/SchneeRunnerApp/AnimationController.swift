import AppKit
import SchneeRunnerCore

enum AnimationControllerError: Error, Equatable, LocalizedError {
    case frameCountMismatch(images: Int, schedule: Int)

    var errorDescription: String? {
        switch self {
        case let .frameCountMismatch(images, schedule):
            "Animation has \(images) images but \(schedule) scheduled frames."
        }
    }
}

@MainActor
final class AnimationController: NSObject {
    private static let referenceFramesPerSecond: Double = 12

    private var frames: [NSImage] = []
    private var frameIndex = 0
    private var baseSchedule: AnimationSchedule?
    private var timer: Timer?

    private(set) var framesPerSecond: Double = AnimationController.referenceFramesPerSecond

    var onFrame: ((NSImage) -> Void)?

    func replaceFrames(_ newFrames: [NSImage]) {
        stop()

        guard !newFrames.isEmpty else {
            frames = []
            baseSchedule = nil
            frameIndex = 0
            return
        }

        guard let schedule = try? AnimationSchedule.uniform(
            frameCount: newFrames.count,
            framesPerSecond: Self.referenceFramesPerSecond
        ) else {
            return
        }

        install(
            frames: newFrames,
            schedule: schedule
        )
    }

    func replaceFrames(
        _ newFrames: [NSImage],
        schedule: AnimationSchedule
    ) throws {
        guard newFrames.count == schedule.frameCount else {
            throw AnimationControllerError.frameCountMismatch(
                images: newFrames.count,
                schedule: schedule.frameCount
            )
        }

        stop()
        install(
            frames: newFrames,
            schedule: schedule
        )
    }

    func setFramesPerSecond(_ value: Double) {
        guard
            value.isFinite,
            value > 0,
            value != framesPerSecond
        else {
            return
        }

        framesPerSecond = value

        if timer != nil {
            stop()
            start()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func install(
        frames newFrames: [NSImage],
        schedule: AnimationSchedule
    ) {
        frames = newFrames
        baseSchedule = schedule
        frameIndex = 0

        guard let firstFrame = frames.first else {
            return
        }

        onFrame?(firstFrame)
        start()
    }

    private func start() {
        guard
            frames.count > 1,
            baseSchedule?.frameCount == frames.count
        else {
            return
        }

        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        guard
            let baseDuration = baseSchedule?.duration(at: frameIndex),
            playbackRate > 0
        else {
            return
        }

        timer = Timer.scheduledTimer(
            timeInterval: baseDuration / playbackRate,
            target: self,
            selector: #selector(advanceFrame),
            userInfo: nil,
            repeats: false
        )
    }

    private var playbackRate: Double {
        framesPerSecond / Self.referenceFramesPerSecond
    }

    @objc
    private func advanceFrame() {
        timer = nil

        guard !frames.isEmpty else {
            return
        }

        frameIndex = (frameIndex + 1) % frames.count
        onFrame?(frames[frameIndex])
        scheduleNextFrame()
    }
}
