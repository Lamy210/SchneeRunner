import AppKit
import SchneeRunnerCore

enum CPUMonitorError: Error, Equatable, LocalizedError {
    case sampleUnavailable

    var errorDescription: String? {
        switch self {
        case .sampleUnavailable:
            "CPU utilization sample is temporarily unavailable."
        }
    }
}

@MainActor
final class CPUMonitor: NSObject {
    struct Update {
        let utilization: Double
        let pace: AnimationPace
    }

    private static let smoothingAlpha = 0.25

    private let snapshotProvider: () throws -> CPUTickSnapshot
    private var calculator = CPUUsageCalculator()
    private var smoother = ExponentialMovingAverage(
        alpha: CPUMonitor.smoothingAlpha
    )
    private var speedPolicy = AdaptiveAnimationSpeedPolicy()
    private var timer: Timer?
    private var hasProducedUpdate = false

    var onUpdate: ((Update) -> Void)?
    var onError: ((Error) -> Void)?

    init(
        snapshotProvider: @escaping () throws -> CPUTickSnapshot = {
            try SystemCPUUsageSampler().readSnapshot()
        }
    ) {
        self.snapshotProvider = snapshotProvider
        super.init()
    }

    func start() {
        guard timer == nil else {
            return
        }

        sampleNow()

        timer = CommonRunLoopTimerScheduler.schedule(
            timeInterval: 1,
            target: self,
            selector: #selector(sampleNow),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc
    func sampleNow() {
        do {
            let snapshot = try snapshotProvider()

            guard let utilization = calculator.utilization(for: snapshot) else {
                if hasProducedUpdate {
                    hasProducedUpdate = false
                    resetDerivedState()
                    onError?(CPUMonitorError.sampleUnavailable)
                }
                return
            }

            let smoothed = smoother.add(utilization)
            let pace = speedPolicy.pace(for: smoothed)
            hasProducedUpdate = true

            onUpdate?(
                Update(
                    utilization: smoothed,
                    pace: pace
                )
            )
        } catch {
            hasProducedUpdate = false
            resetDerivedState()
            onError?(error)
        }
    }

    private func resetDerivedState() {
        smoother = ExponentialMovingAverage(
            alpha: Self.smoothingAlpha
        )
        speedPolicy = AdaptiveAnimationSpeedPolicy()
    }
}
