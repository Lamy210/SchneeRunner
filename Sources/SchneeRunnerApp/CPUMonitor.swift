import AppKit
import SchneeRunnerCore

@MainActor
final class CPUMonitor: NSObject {
    struct Update {
        let utilization: Double
        let pace: AnimationPace
    }

    private let sampler = SystemCPUUsageSampler()
    private var calculator = CPUUsageCalculator()
    private var smoother = ExponentialMovingAverage(alpha: 0.25)
    private var speedPolicy = AdaptiveAnimationSpeedPolicy()
    private var timer: Timer?

    var onUpdate: ((Update) -> Void)?
    var onError: ((Error) -> Void)?

    func start() {
        guard timer == nil else {
            return
        }

        sample()

        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(sample),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc
    private func sample() {
        do {
            let snapshot = try sampler.readSnapshot()

            guard let utilization = calculator.utilization(for: snapshot) else {
                return
            }

            let smoothed = smoother.add(utilization)
            let pace = speedPolicy.pace(for: smoothed)

            onUpdate?(
                Update(
                    utilization: smoothed,
                    pace: pace
                )
            )
        } catch {
            onError?(error)
        }
    }
}
