import Foundation

enum LaunchTrace {
    private static let environmentKey = "SCHNEERUNNER_LAUNCH_TRACE"

    static func emit(_ message: @autoclosure () -> String) {
        guard ProcessInfo.processInfo.environment[environmentKey] == "1" else {
            return
        }

        let line = "[SchneeRunner launch] \(message())\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
