import SchneeRunnerCore

enum CPUAdaptivePlaybackPolicy {
    static func framesPerSecond(
        for pace: AnimationPace?
    ) -> Double {
        (pace ?? .run).framesPerSecond
    }
}
