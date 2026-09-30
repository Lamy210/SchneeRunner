// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SchneeRunner",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SchneeRunner",
            targets: ["SchneeRunnerApp"]
        ),
        .executable(
            name: "schneerunnerctl",
            targets: ["SchneeRunnerCtl"]
        )
    ],
    targets: [
        .target(
            name: "SchneeRunnerCore"
        ),
        .executableTarget(
            name: "SchneeRunnerApp",
            dependencies: ["SchneeRunnerCore"]
        ),
        .executableTarget(
            name: "SchneeRunnerCtl",
            dependencies: ["SchneeRunnerCore"]
        ),
        .testTarget(
            name: "SchneeRunnerCoreTests",
            dependencies: ["SchneeRunnerCore"]
        )
    ]
)
