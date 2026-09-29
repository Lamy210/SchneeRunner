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
        .testTarget(
            name: "SchneeRunnerCoreTests",
            dependencies: ["SchneeRunnerCore"]
        )
    ]
)
