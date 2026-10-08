import AppKit
import Foundation

func fail(_ message: String, application: NSRunningApplication? = nil) -> Never {
    if let application, !application.isTerminated {
        _ = application.forceTerminate()
    }
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard CommandLine.arguments.count == 3 else {
    fail("Usage: smoke-launch-app.swift <app-path> <seconds>")
}

let appURL = URL(
    fileURLWithPath: CommandLine.arguments[1],
    isDirectory: true
).standardizedFileURL

guard
    let smokeSeconds = Int(CommandLine.arguments[2]),
    (1 ... 10).contains(smokeSeconds)
else {
    fail("Smoke duration must be an integer between 1 and 10 seconds.")
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.createsNewApplicationInstance = true
configuration.allowsRunningApplicationSubstitution = false
configuration.arguments = ["schneerunner-launch-smoke-\(UUID().uuidString)"]

let application: NSRunningApplication
do {
    application = try await NSWorkspace.shared.openApplication(
        at: appURL,
        configuration: configuration
    )
} catch {
    fail("SchneeRunner launch smoke could not open the application: \(error)")
}

guard application.processIdentifier > 0 else {
    fail("SchneeRunner launch smoke received an invalid process identifier.", application: application)
}

let launchedURL = application.bundleURL?.standardizedFileURL
if let launchedURL, launchedURL.path != appURL.path {
    fail(
        "SchneeRunner launch smoke opened an unexpected application: \(launchedURL.path)",
        application: application
    )
}

do {
    try await Task.sleep(nanoseconds: UInt64(smokeSeconds) * 1_000_000_000)
} catch {
    fail("SchneeRunner launch smoke wait was interrupted: \(error)", application: application)
}

guard !application.isTerminated else {
    fail("SchneeRunner exited during launch smoke.")
}

print("Packaged application survived \(smokeSeconds)s launch smoke: \(appURL.path)")

if !application.terminate() {
    _ = application.forceTerminate()
}
