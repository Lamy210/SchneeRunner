import Foundation

enum BuiltInCharacterResources {
    static let swiftPMResourceBundleName = "SchneeRunner_SchneeRunnerApp.bundle"

    private static let yukihanaLamyDirectory = "BuiltInCharacters/YukihanaLamy"

    static var moduleBundle: Bundle {
        .module
    }

    static func yukihanaLamyWalkCycle(resourceRoot: URL) -> [URL] {
        let directory = resourceRoot
            .appendingPathComponent(yukihanaLamyDirectory, isDirectory: true)

        return (1 ... 4).map { frame in
            directory.appendingPathComponent("walk_\(frame).png", isDirectory: false)
        }
    }

    static func yukihanaLamyWalkCycle(bundle: Bundle) -> [URL] {
        guard let resourceRoot = bundle.resourceURL else {
            return []
        }
        return yukihanaLamyWalkCycle(resourceRoot: resourceRoot)
    }

    static func runtimeBundle(mainBundle: Bundle = .main) -> Bundle {
        if hasReadableWalkCycle(in: mainBundle) {
            return mainBundle
        }

        if
            let resourceRoot = mainBundle.resourceURL,
            let packagedBundle = Bundle(
                url: resourceRoot.appendingPathComponent(
                    swiftPMResourceBundleName,
                    isDirectory: true
                )
            ),
            hasReadableWalkCycle(in: packagedBundle)
        {
            return packagedBundle
        }

        return .module
    }

    static func hasReadableWalkCycle(in bundle: Bundle) -> Bool {
        let urls = yukihanaLamyWalkCycle(bundle: bundle)
        return urls.count == 4 && urls.allSatisfy {
            FileManager.default.isReadableFile(atPath: $0.path)
        }
    }
}
