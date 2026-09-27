import AppKit

@MainActor
final class AnimationController: NSObject {
    private var frames: [NSImage] = []
    private var frameIndex = 0
    private var timer: Timer?
    private(set) var framesPerSecond: Double = 12

    var onFrame: ((NSImage) -> Void)?

    func replaceFrames(_ newFrames: [NSImage]) {
        stop()
        frames = newFrames
        frameIndex = 0

        guard let firstFrame = frames.first else {
            return
        }

        onFrame?(firstFrame)
        start()
    }

    func setFramesPerSecond(_ value: Double) {
        guard value > 0, value != framesPerSecond else {
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

    private func start() {
        guard frames.count > 1 else {
            return
        }

        timer = Timer.scheduledTimer(
            timeInterval: 1 / framesPerSecond,
            target: self,
            selector: #selector(advanceFrame),
            userInfo: nil,
            repeats: true
        )
    }

    @objc
    private func advanceFrame() {
        guard !frames.isEmpty else {
            return
        }

        frameIndex = (frameIndex + 1) % frames.count
        onFrame?(frames[frameIndex])
    }
}
