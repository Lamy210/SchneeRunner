import AppKit
import Foundation

func fail(
    _ message: String,
    application: NSRunningApplication? = nil,
    traceURL: URL? = nil
) -> Never {
    if let application, !application.isTerminated {
        _ = application.forceTerminate()
    }
    FileHandle.standardError.write(Data((message + "\n").utf8))

    if let traceURL,
       let trace = try? String(contentsOf: traceURL, encoding: .utf8),
       !trace.isEmpty
    {
        FileHandle.standardError.write(Data("Launch trace:\n\(trace)".utf8))
    }
    if let traceURL {
        try? FileManager.default.removeItem(at: traceURL)
    }
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

let traceURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("schneerunner-launch-\(UUID().uuidString).log")
FileManager.default.createFile(atPath: traceURL.path, contents: nil)

let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.createsNewApplicationInstance = true
configuration.allowsRunningApplicationSubstitution = false
configuration.arguments = ["schneerunner-launch-smoke-\(UUID().uuidString)"]
configuration.environment["SCHNEERUNNER_LAUNCH_TRACE"] = "1"
configuration.environment["SCHNEERUNNER_LAUNCH_TRACE_FILE"] = traceURL.path

let application: NSRunningApplication
do {
    application = try await NSWorkspace.shared.openApplication(
        at: appURL,
        configuration: configuration
    )
} catch {
    fail(
        "SchneeRunner launch smoke could not open the application: \(error)",
        traceURL: traceURL
    )
}

guard application.processIdentifier > 0 else {
    fail(
        "SchneeRunner launch smoke received an invalid process identifier.",
        application: application,
        traceURL: traceURL
    )
}

let launchedURL = application.bundleURL?.standardizedFileURL
if let launchedURL, launchedURL.path != appURL.path {
    fail(
        "SchneeRunner launch smoke opened an unexpected application: \(launchedURL.path)",
        application: application,
        traceURL: traceURL
    )
}

do {
    try await Task.sleep(nanoseconds: UInt64(smokeSeconds) * 1_000_000_000)
} catch {
    fail(
        "SchneeRunner launch smoke wait was interrupted: \(error)",
        application: application,
        traceURL: traceURL
    )
}

guard !application.isTerminated else {
    fail("SchneeRunner exited during launch smoke.", traceURL: traceURL)
}

print("Packaged application survived \(smokeSeconds)s launch smoke: \(appURL.path)")

if !application.terminate() {
    _ = application.forceTerminate()
}
try? FileManager.default.removeItem(at: traceURL)
