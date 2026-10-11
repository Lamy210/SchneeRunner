import Foundation
import SchneeRunnerCore

enum CPUStatusValue: Equatable {
    case sampling
    case unavailable
    case utilization(Double)
}

enum CPUStatusFormatter {
    static func title(
        status: CPUStatusValue,
        requestedState: CharacterState,
        resolvedState: CharacterState?,
        playbackRate: Double,
        isAdaptiveSpeedEnabled: Bool,
        localization: AppLocalization = .current
    ) -> String {
        let cpuLabel = switch status {
        case .sampling:
            localization.string("status.cpuSampling")
        case .unavailable:
            localization.string("status.cpuUnavailable")
        case let .utilization(value):
            localization.string(
                "status.cpuUtilizationFormat",
                arguments: Int((value * 100).rounded())
            )
        }

        let stateLabel = CharacterStateStatusFormatter.label(
            requestedState: requestedState,
            resolvedState: resolvedState,
            localization: localization
        )
        let playbackRateLabel = String(
            format: "%.2g×",
            playbackRate
        )
        let playbackLabel = isAdaptiveSpeedEnabled
            ? playbackRateLabel
            : localization.string(
                "status.manualPlaybackFormat",
                arguments: playbackRateLabel
            )

        return "\(cpuLabel) · \(stateLabel) · \(playbackLabel)"
    }
}
