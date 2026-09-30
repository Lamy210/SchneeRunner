import Darwin
import Foundation
import SchneeRunnerCore

private enum ControlCLIError: Error, LocalizedError {
    case invalidCommand
    case invalidState(String)
    case invalidDuration(String)

    var errorDescription: String? {
        switch self {
        case .invalidCommand:
            "Invalid command."
        case let .invalidState(value):
            "Unknown character state: \(value)."
        case let .invalidDuration(value):
            "Invalid duration: \(value)."
        }
    }
}

private func parseCommand(
    arguments: [String]
) throws -> LocalCharacterStateEvent {
    guard let command = arguments.first else {
        throw ControlCLIError.invalidCommand
    }

    switch command {
    case "clear":
        guard arguments.count == 1 else {
            throw ControlCLIError.invalidCommand
        }

        return LocalCharacterStateEvent.clear()

    case "state":
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
            return try LocalCharacterStateEvent.set(
                state: state
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

        return try LocalCharacterStateEvent.set(
            state: state,
            durationSeconds: duration
        )

    default:
        throw ControlCLIError.invalidCommand
    }
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

        """,
        stderr
    )
}

do {
    let event = try parseCommand(
        arguments: Array(
            CommandLine.arguments.dropFirst()
        )
    )
    let payload = try event.encodedJSON()

    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name(
            LocalCharacterStateEvent.notificationName
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
