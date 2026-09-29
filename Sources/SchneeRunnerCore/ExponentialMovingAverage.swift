import Foundation

public struct ExponentialMovingAverage: Sendable {
    public let alpha: Double
    public private(set) var value: Double?

    public init(alpha: Double = 0.25) {
        self.alpha = min(max(alpha, 0), 1)
    }

    @discardableResult
    public mutating func add(_ sample: Double) -> Double {
        let nextValue = if let value {
            alpha * sample + (1 - alpha) * value
        } else {
            sample
        }

        value = nextValue
        return nextValue
    }

    public mutating func reset() {
        value = nil
    }
}
