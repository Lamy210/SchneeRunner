import Foundation

enum BuiltInCharacterResources {
    private static let yukihanaLamyDirectory = "BuiltInCharacters/YukihanaLamy"

    static func yukihanaLamyWalkCycle(resourceRoot: URL) -> [URL] {
        let directory = resourceRoot
            .appendingPathComponent(yukihanaLamyDirectory, isDirectory: true)

        return (1 ... 4).map { frame in
            directory.appendingPathComponent("walk_\(frame).png", isDirectory: false)
        }
    }
}
