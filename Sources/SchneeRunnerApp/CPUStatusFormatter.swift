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
        isAdaptiveSpeedEnabled: Bool
    ) -> String {
        let cpuLabel = switch status {
        case .sampling:
            "CPU: sampling…"
        case .unavailable:
            "CPU: unavailable"
        case let .utilization(value):
            "CPU: \(Int((value * 100).rounded()))%"
        }

        let stateLabel = CharacterStateStatusFormatter.label(
            requestedState: requestedState,
            resolvedState: resolvedState
        )
        let playbackRateLabel = String(
            format: "%.2g×",
            playbackRate
        )
        let playbackLabel = isAdaptiveSpeedEnabled
            ? playbackRateLabel
            : "Manual \(playbackRateLabel)"

        return "\(cpuLabel) · \(stateLabel) · \(playbackLabel)"
    }
}
