// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SchneeRunner",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "SchneeRunner",
            targets: ["SchneeRunnerApp"]
        ),
        .executable(
            name: "schneerunnerctl",
            targets: ["SchneeRunnerCtl"]
        ),
    ],
    targets: [
        .target(
            name: "SchneeRunnerCore"
        ),
        .executableTarget(
            name: "SchneeRunnerApp",
            dependencies: ["SchneeRunnerCore"],
            resources: [
                .copy("Resources/BuiltInCharacters"),
                .process("Resources/en.lproj"),
                .process("Resources/ja.lproj"),
            ]
        ),
        .executableTarget(
            name: "SchneeRunnerCtl",
            dependencies: ["SchneeRunnerCore"]
        ),
        .testTarget(
            name: "SchneeRunnerCoreTests",
            dependencies: ["SchneeRunnerCore"]
        ),
        .testTarget(
            name: "SchneeRunnerAppTests",
            dependencies: ["SchneeRunnerApp", "SchneeRunnerCore"]
        ),
    ]
)
