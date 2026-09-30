public enum MemoryPressureLevel: Equatable, Sendable {
    case normal
    case warning
    case critical
}

public struct MemoryPressureStatePolicy: Sendable {
    public init() {}

    public func state(
        for level: MemoryPressureLevel
    ) -> CharacterState? {
        switch level {
        case .normal:
            nil
        case .warning:
            .dash
        case .critical:
            .sprint
        }
    }
}
