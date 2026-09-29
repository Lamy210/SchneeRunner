import Foundation

public struct CPUTickSnapshot: Equatable, Sendable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public struct CPUUsageCalculator: Sendable {
    private var previous: CPUTickSnapshot?

    public init() {}

    public mutating func utilization(for current: CPUTickSnapshot) -> Double? {
        defer {
            previous = current
        }

        guard let previous else {
            return nil
        }

        guard
            current.user >= previous.user,
            current.system >= previous.system,
            current.idle >= previous.idle,
            current.nice >= previous.nice
        else {
            return nil
        }

        let userDelta = current.user - previous.user
        let systemDelta = current.system - previous.system
        let idleDelta = current.idle - previous.idle
        let niceDelta = current.nice - previous.nice
        let busyDelta = userDelta + systemDelta + niceDelta
        let totalDelta = busyDelta + idleDelta

        guard totalDelta > 0 else {
            return nil
        }

        return Double(busyDelta) / Double(totalDelta)
    }
}
