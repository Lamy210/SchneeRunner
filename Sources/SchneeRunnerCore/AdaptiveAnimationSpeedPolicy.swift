import Foundation

public enum AnimationPace: Int, CaseIterable, Equatable, Sendable {
    case idle
    case walk
    case run
    case dash
    case sprint

    public var framesPerSecond: Double {
        switch self {
        case .idle:
            6
        case .walk:
            8
        case .run:
            12
        case .dash:
            18
        case .sprint:
            24
        }
    }
}

public struct AdaptiveAnimationSpeedPolicy: Sendable {
    private static let thresholds = [0.15, 0.40, 0.70, 0.90]

    public let hysteresis: Double
    public private(set) var currentPace: AnimationPace

    public init(
        hysteresis: Double = 0.03,
        initialPace: AnimationPace = .idle
    ) {
        self.hysteresis = min(max(hysteresis, 0), 0.10)
        currentPace = initialPace
    }

    @discardableResult
    public mutating func pace(for utilization: Double) -> AnimationPace {
        let utilization = min(max(utilization, 0), 1)
        var index = currentPace.rawValue

        while index < Self.thresholds.count,
              utilization >= Self.thresholds[index] + hysteresis {
            index += 1
        }

        while index > 0,
              utilization < Self.thresholds[index - 1] - hysteresis {
            index -= 1
        }

        currentPace = AnimationPace.allCases[index]
        return currentPace
    }
}
