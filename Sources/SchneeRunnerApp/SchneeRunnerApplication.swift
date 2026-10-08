import AppKit

@main
@MainActor
struct SchneeRunnerApplication {
    static func main() {
        LaunchTrace.emit(
            "main begin bundleURL=\(Bundle.main.bundleURL.path) bundleIdentifier=\(Bundle.main.bundleIdentifier ?? "nil")"
        )
        LaunchTrace.emit("before NSApplication.shared")
        let application = NSApplication.shared
        LaunchTrace.emit("after NSApplication.shared")
        LaunchTrace.emit("before AppDelegate init")
        let delegate = AppDelegate()
        LaunchTrace.emit("after AppDelegate init")
        application.delegate = delegate
        LaunchTrace.emit("after delegate assignment")

        withExtendedLifetime(delegate) {
            LaunchTrace.emit("before application.run")
            application.run()
            LaunchTrace.emit("after application.run")
        }
    }
}
