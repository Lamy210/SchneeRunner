import Foundation

public enum PomodoroConfigurationError: Error, Equatable, Sendable {
    case invalidDuration
    case invalidFocusPhaseCount
}

public struct PomodoroConfiguration: Codable, Equatable, Sendable {
    public static let maximumDuration: TimeInterval = 24 * 60 * 60
    public static let maximumFocusPhasesBeforeLongBreak = 100

    public let focusDuration: TimeInterval
    public let shortBreakDuration: TimeInterval
    public let longBreakDuration: TimeInterval
    public let focusPhasesBeforeLongBreak: Int
    public let autoStartNextPhase: Bool

    public init(
        focusDuration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        focusPhasesBeforeLongBreak: Int = 4,
        autoStartNextPhase: Bool = false
    ) throws {
        guard Self.isValidDuration(focusDuration),
              Self.isValidDuration(shortBreakDuration),
              Self.isValidDuration(longBreakDuration)
        else {
            throw PomodoroConfigurationError.invalidDuration
        }
        guard (1 ... Self.maximumFocusPhasesBeforeLongBreak).contains(
            focusPhasesBeforeLongBreak
        ) else {
            throw PomodoroConfigurationError.invalidFocusPhaseCount
        }

        self.focusDuration = focusDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.focusPhasesBeforeLongBreak = focusPhasesBeforeLongBreak
        self.autoStartNextPhase = autoStartNextPhase
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            focusDuration: container.decode(TimeInterval.self, forKey: .focusDuration),
            shortBreakDuration: container.decode(TimeInterval.self, forKey: .shortBreakDuration),
            longBreakDuration: container.decode(TimeInterval.self, forKey: .longBreakDuration),
            focusPhasesBeforeLongBreak: container.decode(
                Int.self,
                forKey: .focusPhasesBeforeLongBreak
            ),
            autoStartNextPhase: container.decode(Bool.self, forKey: .autoStartNextPhase)
        )
    }

    public func duration(for phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus:
            focusDuration
        case .shortBreak:
            shortBreakDuration
        case .longBreak:
            longBreakDuration
        }
    }

    private static func isValidDuration(_ duration: TimeInterval) -> Bool {
        duration.isFinite && duration > 0 && duration <= maximumDuration
    }
}

public enum PomodoroPhase: String, Codable, Equatable, Sendable {
    case focus
    case shortBreak
    case longBreak
}

public enum PomodoroSessionState: String, Codable, Equatable, Sendable {
    case running
    case paused
    case waiting
}

public enum PomodoroSessionError: Error, Equatable, Sendable {
    case invalidPersistedState
    case invalidTransition(from: PomodoroSessionState, to: PomodoroSessionState)
    case noRemainingTime
}

public struct PomodoroSession: Codable, Equatable, Sendable {
    public let id: UUID
    public let configuration: PomodoroConfiguration
    public let currentPhase: PomodoroPhase
    public let completedFocusCount: Int
    public let phaseStartedAt: Date?
    public let phaseDeadline: Date?
    public let pausedRemaining: TimeInterval?
    public let state: PomodoroSessionState

    public init(
        id: UUID,
        configuration: PomodoroConfiguration,
        startedAt: Date
    ) throws {
        self.init(
            fields: Fields(
                id: id,
                configuration: configuration,
                currentPhase: .focus,
                completedFocusCount: 0,
                phaseStartedAt: startedAt,
                phaseDeadline: startedAt.addingTimeInterval(configuration.focusDuration),
                pausedRemaining: nil,
                state: .running
            )
        )
    }

    public func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .running:
            guard let phaseDeadline else {
                return 0
            }
            return max(0, phaseDeadline.timeIntervalSince(now))
        case .paused:
            return max(0, pausedRemaining ?? 0)
        case .waiting:
            return 0
        }
    }

    public func pausing(at now: Date) throws -> PomodoroSession {
        guard state == .running else {
            throw PomodoroSessionError.invalidTransition(from: state, to: .paused)
        }

        let remaining = remaining(at: now)
        guard remaining > 0 else {
            return advancing(at: now)
        }

        return replacingTiming(
            startedAt: phaseStartedAt,
            deadline: nil,
            pausedRemaining: remaining,
            state: .paused
        )
    }

    public func resuming(at now: Date) throws -> PomodoroSession {
        guard state == .paused else {
            throw PomodoroSessionError.invalidTransition(from: state, to: .running)
        }
        guard let pausedRemaining, pausedRemaining > 0 else {
            throw PomodoroSessionError.noRemainingTime
        }

        return replacingTiming(
            startedAt: now,
            deadline: now.addingTimeInterval(pausedRemaining),
            pausedRemaining: nil,
            state: .running
        )
    }

    public func startingCurrentPhase(at now: Date) throws -> PomodoroSession {
        guard state == .waiting else {
            throw PomodoroSessionError.invalidTransition(from: state, to: .running)
        }

        let duration = configuration.duration(for: currentPhase)
        return replacingTiming(
            startedAt: now,
            deadline: now.addingTimeInterval(duration),
            pausedRemaining: nil,
            state: .running
        )
    }

    public func advancing(at now: Date) -> PomodoroSession {
        var session = self

        while session.state == .running,
              let deadline = session.phaseDeadline,
              now >= deadline
        {
            session = session.advancingOnePhase(at: deadline)
        }

        return session
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fields = try Fields(
            id: container.decode(UUID.self, forKey: .id),
            configuration: container.decode(
                PomodoroConfiguration.self,
                forKey: .configuration
            ),
            currentPhase: container.decode(PomodoroPhase.self, forKey: .currentPhase),
            completedFocusCount: container.decode(Int.self, forKey: .completedFocusCount),
            phaseStartedAt: container.decodeIfPresent(Date.self, forKey: .phaseStartedAt),
            phaseDeadline: container.decodeIfPresent(Date.self, forKey: .phaseDeadline),
            pausedRemaining: container.decodeIfPresent(
                TimeInterval.self,
                forKey: .pausedRemaining
            ),
            state: container.decode(PomodoroSessionState.self, forKey: .state)
        )

        guard Self.isValid(fields) else {
            throw PomodoroSessionError.invalidPersistedState
        }
        self.init(fields: fields)
    }
}

private extension PomodoroSession {
    struct Fields {
        let id: UUID
        let configuration: PomodoroConfiguration
        let currentPhase: PomodoroPhase
        let completedFocusCount: Int
        let phaseStartedAt: Date?
        let phaseDeadline: Date?
        let pausedRemaining: TimeInterval?
        let state: PomodoroSessionState
    }

    init(fields: Fields) {
        id = fields.id
        configuration = fields.configuration
        currentPhase = fields.currentPhase
        completedFocusCount = fields.completedFocusCount
        phaseStartedAt = fields.phaseStartedAt
        phaseDeadline = fields.phaseDeadline
        pausedRemaining = fields.pausedRemaining
        state = fields.state
    }

    func replacingTiming(
        startedAt: Date?,
        deadline: Date?,
        pausedRemaining: TimeInterval?,
        state: PomodoroSessionState
    ) -> PomodoroSession {
        PomodoroSession(
            fields: Fields(
                id: id,
                configuration: configuration,
                currentPhase: currentPhase,
                completedFocusCount: completedFocusCount,
                phaseStartedAt: startedAt,
                phaseDeadline: deadline,
                pausedRemaining: pausedRemaining,
                state: state
            )
        )
    }

    func advancingOnePhase(at transitionTime: Date) -> PomodoroSession {
        let nextFocusCount = currentPhase == .focus
            ? completedFocusCount + 1
            : completedFocusCount
        let nextPhase = nextPhase(completedFocusCount: nextFocusCount)
        let nextState: PomodoroSessionState = configuration.autoStartNextPhase
            ? .running
            : .waiting
        let nextDuration = configuration.duration(for: nextPhase)

        return PomodoroSession(
            fields: Fields(
                id: id,
                configuration: configuration,
                currentPhase: nextPhase,
                completedFocusCount: nextFocusCount,
                phaseStartedAt: nextState == .running ? transitionTime : nil,
                phaseDeadline: nextState == .running
                    ? transitionTime.addingTimeInterval(nextDuration)
                    : nil,
                pausedRemaining: nil,
                state: nextState
            )
        )
    }

    func nextPhase(completedFocusCount: Int) -> PomodoroPhase {
        switch currentPhase {
        case .focus:
            if completedFocusCount.isMultiple(
                of: configuration.focusPhasesBeforeLongBreak
            ) {
                return .longBreak
            }
            return .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }

    static func isValid(_ fields: Fields) -> Bool {
        guard fields.completedFocusCount >= 0 else {
            return false
        }

        switch fields.state {
        case .running:
            guard let startedAt = fields.phaseStartedAt,
                  let deadline = fields.phaseDeadline
            else {
                return false
            }
            return deadline > startedAt && fields.pausedRemaining == nil
        case .paused:
            guard fields.phaseStartedAt != nil,
                  let pausedRemaining = fields.pausedRemaining
            else {
                return false
            }
            return pausedRemaining.isFinite
                && pausedRemaining > 0
                && fields.phaseDeadline == nil
        case .waiting:
            return fields.phaseStartedAt == nil
                && fields.phaseDeadline == nil
                && fields.pausedRemaining == nil
        }
    }
}
