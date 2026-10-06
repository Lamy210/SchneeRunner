import Foundation

public enum ProductivityTimerState: String, Codable, Equatable, Sendable {
    case running
    case paused
    case completed
    case cancelled
}

public enum ProductivityCountdownTimerError: Error, Equatable, Sendable {
    case nonPositiveDuration
    case invalidPersistedState
    case invalidTransition(from: ProductivityTimerState, to: ProductivityTimerState)
    case noRemainingTime
}

public struct ProductivityCountdownTimer: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let originalDuration: TimeInterval
    public let startedAt: Date?
    public let deadline: Date?
    public let pausedRemaining: TimeInterval?
    public let state: ProductivityTimerState
    public let completedAt: Date?

    public init(
        id: UUID,
        title: String,
        duration: TimeInterval,
        startedAt: Date
    ) throws {
        guard duration.isFinite, duration > 0 else {
            throw ProductivityCountdownTimerError.nonPositiveDuration
        }

        self.init(
            fields: Fields(
                id: id,
                title: title,
                originalDuration: duration,
                startedAt: startedAt,
                deadline: startedAt.addingTimeInterval(duration),
                pausedRemaining: nil,
                state: .running,
                completedAt: nil
            )
        )
    }

    public func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .running:
            guard let deadline else {
                return 0
            }
            return max(0, deadline.timeIntervalSince(now))
        case .paused:
            return max(0, pausedRemaining ?? 0)
        case .completed, .cancelled:
            return 0
        }
    }

    public func pausing(at now: Date) throws -> ProductivityCountdownTimer {
        guard state == .running else {
            throw ProductivityCountdownTimerError.invalidTransition(
                from: state,
                to: .paused
            )
        }

        let remaining = remaining(at: now)
        guard remaining > 0 else {
            throw ProductivityCountdownTimerError.noRemainingTime
        }

        return ProductivityCountdownTimer(
            fields: Fields(
                id: id,
                title: title,
                originalDuration: originalDuration,
                startedAt: startedAt,
                deadline: nil,
                pausedRemaining: remaining,
                state: .paused,
                completedAt: nil
            )
        )
    }

    public func resuming(at now: Date) throws -> ProductivityCountdownTimer {
        guard state == .paused else {
            throw ProductivityCountdownTimerError.invalidTransition(
                from: state,
                to: .running
            )
        }
        guard let pausedRemaining, pausedRemaining > 0 else {
            throw ProductivityCountdownTimerError.noRemainingTime
        }

        return ProductivityCountdownTimer(
            fields: Fields(
                id: id,
                title: title,
                originalDuration: originalDuration,
                startedAt: now,
                deadline: now.addingTimeInterval(pausedRemaining),
                pausedRemaining: nil,
                state: .running,
                completedAt: nil
            )
        )
    }

    public func cancelling() -> ProductivityCountdownTimer {
        guard state == .running || state == .paused else {
            return self
        }

        return ProductivityCountdownTimer(
            fields: Fields(
                id: id,
                title: title,
                originalDuration: originalDuration,
                startedAt: startedAt,
                deadline: nil,
                pausedRemaining: nil,
                state: .cancelled,
                completedAt: nil
            )
        )
    }

    public func reconciling(at now: Date) -> ProductivityCountdownTimer {
        guard state == .running, remaining(at: now) == 0, let deadline else {
            return self
        }

        return ProductivityCountdownTimer(
            fields: Fields(
                id: id,
                title: title,
                originalDuration: originalDuration,
                startedAt: startedAt,
                deadline: nil,
                pausedRemaining: nil,
                state: .completed,
                completedAt: deadline
            )
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fields = Fields(
            id: try container.decode(UUID.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            originalDuration: try container.decode(
                TimeInterval.self,
                forKey: .originalDuration
            ),
            startedAt: try container.decodeIfPresent(Date.self, forKey: .startedAt),
            deadline: try container.decodeIfPresent(Date.self, forKey: .deadline),
            pausedRemaining: try container.decodeIfPresent(
                TimeInterval.self,
                forKey: .pausedRemaining
            ),
            state: try container.decode(ProductivityTimerState.self, forKey: .state),
            completedAt: try container.decodeIfPresent(Date.self, forKey: .completedAt)
        )

        guard Self.isValid(fields) else {
            throw ProductivityCountdownTimerError.invalidPersistedState
        }

        self.init(fields: fields)
    }
}

private extension ProductivityCountdownTimer {
    struct Fields {
        let id: UUID
        let title: String
        let originalDuration: TimeInterval
        let startedAt: Date?
        let deadline: Date?
        let pausedRemaining: TimeInterval?
        let state: ProductivityTimerState
        let completedAt: Date?
    }

    init(fields: Fields) {
        id = fields.id
        title = fields.title
        originalDuration = fields.originalDuration
        startedAt = fields.startedAt
        deadline = fields.deadline
        pausedRemaining = fields.pausedRemaining
        state = fields.state
        completedAt = fields.completedAt
    }

    static func isValid(_ fields: Fields) -> Bool {
        guard fields.originalDuration.isFinite, fields.originalDuration > 0 else {
            return false
        }

        switch fields.state {
        case .running:
            guard let startedAt = fields.startedAt, let deadline = fields.deadline else {
                return false
            }
            return deadline > startedAt && fields.pausedRemaining == nil && fields.completedAt == nil
        case .paused:
            guard fields.startedAt != nil, let pausedRemaining = fields.pausedRemaining else {
                return false
            }
            return pausedRemaining.isFinite
                && pausedRemaining > 0
                && fields.deadline == nil
                && fields.completedAt == nil
        case .completed:
            return fields.startedAt != nil
                && fields.deadline == nil
                && fields.pausedRemaining == nil
                && fields.completedAt != nil
        case .cancelled:
            return fields.startedAt != nil
                && fields.deadline == nil
                && fields.pausedRemaining == nil
                && fields.completedAt == nil
        }
    }
}
