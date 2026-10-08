import Foundation

enum LaunchTrace {
    private static let environmentKey = "SCHNEERUNNER_LAUNCH_TRACE"
    private static let fileEnvironmentKey = "SCHNEERUNNER_LAUNCH_TRACE_FILE"

    static func emit(_ message: @autoclosure () -> String) {
        let environment = ProcessInfo.processInfo.environment
        guard environment[environmentKey] == "1" else {
            return
        }

        let data = Data("[SchneeRunner launch] \(message())\n".utf8)
        FileHandle.standardError.write(data)

        guard
            let path = environment[fileEnvironmentKey],
            !path.isEmpty
        else {
            return
        }

        let url = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: url) else {
            return
        }
        defer {
            try? handle.close()
        }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            return
        }
    }
}
