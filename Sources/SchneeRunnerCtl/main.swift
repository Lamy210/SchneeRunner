import Darwin
import Foundation
import SchneeRunnerCore

private enum ControlCLIError: Error, LocalizedError {
    case invalidCommand
    case invalidState(String)
    case invalidDuration(String)
    case invalidBuildPhase(String)

    var errorDescription: String? {
        switch self {
        case .invalidCommand:
            "Invalid command."
        case let .invalidState(value):
            "Unknown character state: \(value)."
        case let .invalidDuration(value):
            "Invalid duration: \(value)."
        case let .invalidBuildPhase(value):
            "Unknown build phase: \(value)."
        }
    }
}

private enum ControlPayload {
    case characterState(LocalCharacterStateEvent)
    case build(LocalBuildEvent)

    var notificationName: String {
        switch self {
        case .characterState:
            LocalCharacterStateEvent.notificationName
        case .build:
            LocalBuildEvent.notificationName
        }
    }

    func encodedJSON() throws -> String {
        switch self {
        case let .characterState(event):
            try event.encodedJSON()
        case let .build(event):
            try event.encodedJSON()
        }
    }
}

private func parseCommand(
    arguments: [String]
) throws -> ControlPayload {
    guard let command = arguments.first else {
        throw ControlCLIError.invalidCommand
    }

    switch command {
    case "clear":
        guard arguments.count == 1 else {
            throw ControlCLIError.invalidCommand
        }

        return .characterState(
            LocalCharacterStateEvent.clear()
        )

    case "state":
        return try parseStateCommand(arguments)

    case "build":
        return try parseBuildCommand(arguments)

    default:
        throw ControlCLIError.invalidCommand
    }
}

private func parseStateCommand(
    _ arguments: [String]
) throws -> ControlPayload {
    guard
        arguments.count == 2 || arguments.count == 4
    else {
        throw ControlCLIError.invalidCommand
    }

    let rawState = arguments[1]
    guard let state = CharacterState(rawValue: rawState) else {
        throw ControlCLIError.invalidState(rawState)
    }

    if arguments.count == 2 {
        return try .characterState(
            LocalCharacterStateEvent.set(
                state: state
            )
        )
    }

    guard arguments[2] == "--seconds" else {
        throw ControlCLIError.invalidCommand
    }
    guard let duration = Double(arguments[3]) else {
        throw ControlCLIError.invalidDuration(
            arguments[3]
        )
    }

    return try .characterState(
        LocalCharacterStateEvent.set(
            state: state,
            durationSeconds: duration
        )
    )
}

private func parseBuildCommand(
    _ arguments: [String]
) throws -> ControlPayload {
    guard arguments.count == 2 else {
        throw ControlCLIError.invalidCommand
    }

    let phase: BuildLifecyclePhase = switch arguments[1] {
    case "start":
        .started
    case "success":
        .succeeded
    case "failure":
        .failed
    case "cancel":
        .cancelled
    default:
        throw ControlCLIError.invalidBuildPhase(
            arguments[1]
        )
    }

    return .build(
        LocalBuildEvent(phase: phase)
    )
}

private func printUsage() {
    let states = CharacterState.allCases
        .map(\.rawValue)
        .joined(separator: "|")

    fputs(
        """
        Usage:
          schneerunnerctl state <\(states)> [--seconds <0.1...3600>]
          schneerunnerctl clear
          schneerunnerctl build <start|success|failure|cancel>

        """,
        stderr
    )
}

do {
    let command = try parseCommand(
        arguments: Array(
            CommandLine.arguments.dropFirst()
        )
    )
    let payload = try command.encodedJSON()

    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name(
            command.notificationName
        ),
        object: payload,
        userInfo: nil,
        deliverImmediately: true
    )
} catch {
    fputs(
        "schneerunnerctl: \(error.localizedDescription)\n",
        stderr
    )
    printUsage()
    exit(EXIT_FAILURE)
}
