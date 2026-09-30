public enum BatteryWarningLevel: Equatable, Sendable {
    case none
    case early
    case final
}

public struct BatteryWarningStatePolicy: Sendable {
    public init() {}

    public func state(
        for level: BatteryWarningLevel
    ) -> CharacterState? {
        switch level {
        case .none:
            nil
        case .early:
            .walk
        case .final:
            .idle
        }
    }
}
